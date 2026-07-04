# 오케스트레이터 스킬 템플릿 (Codex port)

오케스트레이터는 팀 전체를 조율하는 상위 스킬이다. 실행 모드별로 3가지 템플릿을 제공한다:

- **템플릿 A: 에이전트 팀 모드 (기본)** — 2명 이상 협업 시 최우선 선택. MCP team server 도구 사용.
- **템플릿 B: 서브 에이전트 모드 (대안)** — 팀 통신이 불필요한 경우. `codex exec` 서브프로세스.
- **템플릿 C: 하이브리드 모드** — Phase마다 모드를 섞어 구성.

> Codex 환경 안내: Claude의 `Agent`/`TeamCreate`/`SendMessage`/`TaskCreate` 도구는 부재한다. 각각 `codex exec` 서브프로세스 + MCP team server 도구로 치환했다.

---

## 템플릿 A: 에이전트 팀 모드 (기본 · 최우선 선택)

2명 이상의 에이전트가 협업할 때 **가장 먼저 검토하는 기본 모드**. MCP team server의 `team_create`로 팀을 구성하고, 공유 작업 목록(`task_*`)과 메시지(`send_message`/`recv_messages`)로 조율한다.

```markdown
---
name: {domain}-orchestrator
description: "{도메인} 에이전트 팀을 조율하는 오케스트레이터. {초기 실행 키워드}. 후속 작업: {도메인} 결과 수정, 부분 재실행, 업데이트, 보완, 다시 실행, 이전 결과 개선 요청 시에도 반드시 이 스킬을 사용."
---

# {Domain} Orchestrator

{도메인}의 에이전트 팀을 조율하여 {최종 산출물}을 생성하는 통합 스킬.

## 실행 모드: 에이전트 팀

## 에이전트 구성

| 팀원 | 에이전트 정의 파일 | 역할 | 호출 sandbox | 출력 |
|------|------------------|------|-------------|------|
| {teammate-1} | `agents/{teammate-1}.md` | {역할} | `workspace-write` | `_workspace/{phase}_{teammate-1}_{artifact}.md` |
| {teammate-2} | `agents/{teammate-2}.md` | {역할} | `read-only` (Explore 등가 시) | `_workspace/{phase}_{teammate-2}_{artifact}.md` |

## 워크플로우

### Phase 0: 컨텍스트 확인 (후속 작업 지원)

기존 산출물 존재 여부를 확인하여 실행 모드를 결정한다:

1. `_workspace/` 디렉토리 존재 여부 확인
2. 실행 모드 결정:
   - **`_workspace/` 미존재** → 초기 실행. Phase 1로 진행
   - **`_workspace/` 존재 + 사용자가 부분 수정 요청** → 부분 재실행
   - **`_workspace/` 존재 + 새 입력 제공** → 새 실행. 기존 `_workspace/`를 `_workspace_{YYYYMMDD_HHMMSS}/`로 이동한 뒤 Phase 1 진행
3. 부분 재실행 시: 이전 산출물 경로를 에이전트 prompt에 포함

### Phase 1: 준비
1. 사용자 입력 분석
2. `_workspace/` 생성 (초기 실행 시)
3. 입력 데이터를 `_workspace/00_input/`에 저장

### Phase 2: 팀 구성

1. 팀 생성 (MCP 도구 호출):
   ```
   team_create({
     team_name: "{domain}-team",
     members: ["{teammate-1}", "{teammate-2}", ...],
     leader: "orchestrator"
   })
   → 응답: { team_id }
   ```
   `team_id`를 변수로 보관 (이후 모든 호출에 사용).

2. 작업 등록:
   ```
   task_create({ team_id, subject: "{작업1}", description: "{상세}", owner: "{teammate-1}" })
   task_create({ team_id, subject: "{작업2}", description: "{상세}", owner: "{teammate-2}" })
   task_create({ team_id, subject: "{작업3}", description: "{상세}", owner: "{teammate-1}", blocked_by: ["{작업1-id}"] })
   ```

   > 팀원당 5~6개 작업이 적정. 의존성은 `blocked_by`로 명시.

### Phase 3: 팀원 spawn — codex exec 서브프로세스

각 팀원을 `codex exec`로 호출. 팀원 prompt는 `agents/<name>.md` + 다음 지시문을 합쳐서 전달:

```
TEAM_ID={team_id}
당신의 이름: {teammate-1}
- 매 turn 시작 시 recv_messages({team_id, as: "{teammate-1}", since: <last_cursor>}) 호출
- task_list({team_id, owner: "{teammate-1}", status: ["pending","in_progress"]}) 폴링
- 작업 완료 시 task_update({task_id, status: "completed", metadata: {output: <path>}})
- 다른 팀원에게 정보 필요 시 send_message({team_id, from: "{teammate-1}", to: "{target}", content: "..."})
- 종료 신호 수신 시 turn 종료
```

각 팀원 호출 (병렬):
```bash
codex exec --json --ephemeral --skip-git-repo-check \
  -C _workspace/{teammate-1}/ --add-dir _workspace/ \
  -s workspace-write \
  -o _workspace/{teammate-1}/last.txt \
  --prompt-file agents/{teammate-1}.md \
  "TEAM_ID={team_id}; 첫 작업: task_list 후 처리" > _workspace/{teammate-1}/events.jsonl &
codex exec --json --ephemeral --skip-git-repo-check \
  -C _workspace/{teammate-2}/ --add-dir _workspace/ \
  -s workspace-write \
  -o _workspace/{teammate-2}/last.txt \
  --prompt-file agents/{teammate-2}.md \
  "TEAM_ID={team_id}; 첫 작업: task_list 후 처리" > _workspace/{teammate-2}/events.jsonl &
wait
```

**팀원 간 통신 규칙:**
- {teammate-1}은 {teammate-2}에게 `send_message`로 {어떤 정보} 전달
- {teammate-2}는 작업 완료 시 결과를 파일로 저장하고 `send_message`로 알림
- 다른 팀원의 결과가 필요하면 `send_message`로 요청

**리더 모니터링 (오케스트레이터):**
- 주기적으로 `task_list({team_id, status: ["pending","in_progress"]})` 폴링 (5~10초 인터벌)
- 특정 팀원이 막혔을 때 `send_message`로 지시 또는 작업 재할당(`task_update`로 owner 변경)

### Phase 4: {후속 작업 — 예: 검증/통합}
1. `task_list({team_id, status: ["pending","in_progress"]})`이 빈 배열 반환할 때까지 대기 (timeout 적용)
2. 각 팀원의 산출물을 `task_get_output({task_id})` 또는 직접 Read로 수집
3. 통합/검증 로직
4. 최종 산출물 생성: `{output-path}/{filename}`

### Phase 5: 정리
1. 모든 팀원에게 종료 신호: `send_message({team_id, from: "orchestrator", to: "*", content: "<TEAM_DONE>"})`
2. 팀 정리: `team_destroy({team_id, archive: true})` (sqlite는 status=archived로 마킹, 실제 삭제는 GC가 처리)
3. `_workspace/` 디렉토리 보존
4. 사용자에게 결과 요약 보고

> **팀 재구성이 필요한 경우:** Phase별로 다른 전문가 조합이 필요하면, 현재 팀을 `team_destroy`로 정리한 뒤 새 `team_create`로 다음 Phase의 팀을 구성한다. 이전 팀의 산출물은 `_workspace/`에 보존되므로 새 팀이 Read로 접근 가능.

## 데이터 흐름

```
[리더] → team_create → [teammate-1] ←send_message→ [teammate-2]
                          │              (sqlite)         │
                          ↓                                ↓
                    artifact-1.md                   artifact-2.md
                          │                                │
                          └───────── Read ─────────────────┘
                                     ↓
                              [리더: 통합]
                                     ↓
                              최종 산출물
```

## 에러 핸들링

| 상황 | 전략 |
|------|------|
| 팀원 1명 실패/중지 | 리더가 `task_list`로 감지 → `send_message`로 상태 확인 → 재시작(codex exec resume) 또는 대체 팀원 spawn |
| 팀원 과반 실패 | 사용자에게 알리고 진행 여부 확인 |
| 타임아웃 | 현재까지 수집된 부분 결과 사용, 미완료 task는 status=`timed_out` |
| 팀원 간 데이터 충돌 | 출처 명시 후 병기, 삭제하지 않음 |
| 작업 상태 지연 | 리더가 `task_update`로 강제 재할당 |
| 메시지 폴링 무한 대기 | 폴링 인터벌 지수 증가(1s→2s→4s, max 30s), N회 연속 빈 결과면 watchdog 발동 |

## 테스트 시나리오

### 정상 흐름
1. 사용자가 {입력}을 제공
2. Phase 1에서 {분석 결과} 도출
3. Phase 2에서 `team_create` + `task_create` × N
4. Phase 3에서 팀원들이 자체 조율 (`recv_messages` 폴링 + `task_*` 처리)
5. Phase 4에서 산출물 통합
6. Phase 5에서 `team_destroy`
7. 예상 결과: `{output-path}/{filename}` 생성

### 에러 흐름
1. Phase 3에서 {teammate-2}가 에러로 중지
2. 리더가 `task_list` 폴링 결과로 감지
3. `send_message`로 상태 확인 → 재시작 시도(`codex exec resume`)
4. 재시작 실패 시 task의 owner를 {teammate-1}로 변경(`task_update`)
5. 나머지 결과로 Phase 4 진행
6. 최종 보고서에 "{teammate-2} 영역 일부 미수집" 명시
```

---

## 템플릿 B: 서브 에이전트 모드 (대안)

팀 통신 오버헤드가 불필요한 경우. `codex exec` 서브프로세스로 직접 호출하고 JSONL 이벤트로 결과를 수집한다.

```markdown
---
name: {domain}-orchestrator
description: "{도메인} 에이전트를 조율하는 오케스트레이터. {초기 실행 키워드}. 후속 작업 키워드 포함."
---

## 실행 모드: 서브 에이전트

## 에이전트 구성

| 에이전트 | 정의 파일 | 역할 | sandbox | 출력 |
|---------|----------|------|---------|------|
| {agent-1} | `agents/{agent-1}.md` | {역할} | `workspace-write` | `_workspace/{phase}_{agent}.md` |
| {agent-2} | `agents/{agent-2}.md` | {역할} | `read-only` | `_workspace/{phase}_{agent}.md` |

## 워크플로우

### Phase 0: 컨텍스트 확인
(템플릿 A와 동일)

### Phase 1: 준비
1. 입력 분석
2. `_workspace/` 생성

### Phase 2: 병렬 실행

shell 백그라운드로 N개 codex exec 동시 fork:

```bash
codex exec --json --ephemeral --skip-git-repo-check \
  -C _workspace/{agent-1}/ --add-dir _workspace/ \
  -s workspace-write \
  -o _workspace/{agent-1}/last.txt \
  --prompt-file agents/{agent-1}.md "<task>" \
  > _workspace/{agent-1}/events.jsonl &
PID_1=$!

codex exec --json --ephemeral --skip-git-repo-check \
  -C _workspace/{agent-2}/ --add-dir _workspace/ \
  -s workspace-write \
  -o _workspace/{agent-2}/last.txt \
  --prompt-file agents/{agent-2}.md "<task>" \
  > _workspace/{agent-2}/events.jsonl &
PID_2=$!

wait $PID_1 $PID_2
```

### Phase 3: 통합
1. `_workspace/{agent}/last.txt`에서 마지막 메시지 회수
2. 또는 `events.jsonl`에서 `item.completed.item.type=="agent_message"` 누적
   - stdout 각 라인을 파싱하기 전 `{`로 시작하는지 확인하고, 아니면 skip한다(등록된 다른 MCP 서버의 auth 실패 로그 등이 stream 중간에 섞여 나올 수 있음 — 01 §1.1 실측).
3. 통합 로직 적용 → 최종 산출물

### Phase 4: 정리
1. `_workspace/` 보존
2. 결과 요약 보고

## 에러 핸들링
- 에이전트 1개 실패(exit code != 0): 1회 재시도(`codex exec resume`). 재실패 시 누락 명시
- 과반 실패: 사용자에게 알리고 진행 여부 확인
- 타임아웃: shell `timeout` 명령으로 강제 종료 후 부분 결과 사용
```

---

## 템플릿 C: 하이브리드 모드

Phase마다 다른 실행 모드를 사용한다. 각 Phase 상단에 `**실행 모드:** {팀 | 서브}`를 명시한다.

```markdown
---
name: {domain}-orchestrator
description: "{도메인} 오케스트레이터 (하이브리드). {키워드}. 후속 작업 키워드 포함."
---

## 실행 모드: 하이브리드

| Phase | 모드 | 이유 |
|-------|------|------|
| Phase 2 (병렬 수집) | 서브 에이전트 | 독립 자료 수집, 팀 통신 불필요 |
| Phase 3 (합의 통합) | 에이전트 팀 | 상충 데이터 토론·합의 필요 |
| Phase 4 (독립 검증) | 서브 에이전트 | QA 에이전트 1명이 객관 검증 |

## 워크플로우

### Phase 2: 병렬 자료 수집
**실행 모드:** 서브 에이전트

shell 백그라운드로 N개 `codex exec` 병렬 호출.
각 결과는 `_workspace/02_{agent}_raw.md`에 저장.

### Phase 3: 합의 기반 통합
**실행 모드:** 에이전트 팀

1. `team_create({team_name: "integration", members: ["editor","fact-checker","synthesizer"]})`
2. `task_create` × N — 모두 Phase 2의 `_workspace/02_*` 파일을 Read 인풋으로
3. 팀원들이 `send_message`로 상충 데이터를 논의, 파일 기반으로 합의안 도출
4. 최종 통합본 `_workspace/03_integrated.md` 생성
5. `team_destroy({team_id, archive: true})`

### Phase 4: 독립 검증
**실행 모드:** 서브 에이전트

단일 QA 서브 에이전트가 `_workspace/03_integrated.md`를 입력으로 받아 검증 보고서 생성.
```

**하이브리드 전환 규칙:**
- 팀 → 서브: 팀을 반드시 `team_destroy`로 정리한 후 `codex exec` 호출
- 서브 → 팀: 서브 에이전트의 파일 산출물을 팀원들에게 Read 경로로 전달
- 팀 → 팀: 이전 팀을 정리한 후 새 `team_create` (sqlite는 별도 team_id로 격리)

---

## 작성 원칙

1. **실행 모드를 먼저 명시** — 오케스트레이터 상단에 "에이전트 팀" / "서브 에이전트" / "하이브리드" 중 하나 명시. 하이브리드면 Phase별 모드 표 필수
2. **팀 모드는 MCP 도구 호출(team_create/send_message/task_create)을 구체적으로** — 팀 구성, 작업 등록, 통신 규칙
3. **서브 모드는 codex exec 옵션을 완전히 명시** — `--json`, `--ephemeral`, `-C`, `-s`, `-o`. 페르소나는 stdin 주입(`- "<task>" < agents/<name>.md`)
4. **파일 경로는 절대적으로** — 상대 경로 금지, `_workspace/` 기준 명확한 경로
5. **Phase 간 의존성 명시** — 어떤 Phase가 어떤 Phase의 결과에 의존하는지. 하이브리드는 모드 전환 지점을 특히 강조
6. **에러 핸들링은 현실적으로** — "모든 것이 성공한다"고 가정하지 않음
7. **테스트 시나리오 필수** — 정상 1 + 에러 1 이상

## description 작성 시 후속 작업 키워드

오케스트레이터 description은 초기 실행 키워드만으로는 부족하다. 다음 후속 작업 표현을 반드시 포함하라:

- 재실행/다시 실행/업데이트/수정/보완
- "{도메인}의 {부분}만 다시"
- "이전 결과 기반으로", "결과 개선"
- 도메인 관련 일상적 요청

후속 키워드가 없으면 첫 실행 후 하네스가 사실상 죽은 코드가 된다. (Codex의 description 매칭 강도는 Claude 대비 Unknown — `codex exec - < <skill-or-agent>.md` 명시 호출 경로도 README에 동시에 안내하라.)

## 실제 오케스트레이터 참고

팬아웃/팬인 패턴의 오케스트레이터 기본 구조:
준비 → Phase 0(컨텍스트 확인) → `team_create` + `task_create` × N → N개 팀원 병렬 `codex exec` → `task_list` 폴링 → Read + 통합 → `team_destroy`.
`references/team-examples.md`의 리서치 팀 예시를 참조.
