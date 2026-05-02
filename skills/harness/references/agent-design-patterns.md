# Agent Team Design Patterns (Codex port)

> Codex CLI 환경의 1차 primitive 부재(Agent / TeamCreate / SendMessage / TaskCreate)를 외부 메커니즘으로 우회한 버전. 본문 의미는 revfactory 원본과 동일하되 호출 형태만 치환했다.

## 실행 모드: 에이전트 팀 vs 서브 에이전트

두 가지 실행 모드의 핵심 차이를 이해하고 적합한 모드를 선택한다.

### 에이전트 팀 (Agent Teams) — 기본 모드

팀 리더가 MCP team server의 `team_create({team_name, members, leader})`를 호출하여 팀을 등록한다. 팀원들은 별도의 Codex 세션(`codex exec ...`) 또는 같은 세션 내 turn으로 동작하며, MCP 도구 `send_message`로 메시지를 큐에 푸시하고 `recv_messages`로 폴링한다. 공유 작업 목록은 `task_create`/`task_update`로 관리한다.

```
[리더] ←(MCP)→ [팀원A] ←(MCP)→ [팀원B]
  ↕              ↕               ↕
  └──── 공유 작업 목록 (task_*) ────┘
```

**핵심 도구 (모두 MCP team server):**
- `team_create({team_name, members, leader?})`: 팀 등록 + sqlite 행 생성
- `send_message({team_id, from, to, content})`: 특정 팀원에게 메시지(`to: "name"` 또는 `"*"` 브로드캐스트)
- `recv_messages({team_id, as, since?})`: 폴링으로 수신 (반드시 매 turn 시작 시 호출)
- `task_create`/`task_update`/`task_list`/`task_get_output`: 공유 작업 목록 관리

**특징:**
- 팀원끼리 직접 메시지 교환, 도전, 검증 가능
- 리더가 거치지 않고 팀원 간 정보 교환
- 공유 작업 목록으로 자체 조율
- 영속 sqlite 저장소(`~/.codex/teams.sqlite`)에 모든 메시지/작업 기록 남음 (감사 추적 가능)

**제약:**
- **메시지는 push 후 polling이 필요** — Claude의 동기 도착 통지 없음. 폴링 인터벌 1~10초.
- **세션 자체에 팀 한계 없음** (sqlite 단일 파일 공유) — 단, 다중 머신 협업은 사용자가 경로 공유 책임
- 토큰 비용은 폴링이 추가되어 Claude 동등 시나리오 대비 약간 증가

**팀 재구성 패턴:**
Phase별로 다른 전문가 조합이 필요하면, 이전 팀의 산출물을 파일로 저장 → `team_destroy({archive:true})` → 새 `team_create` 순서로 진행한다.

### 서브 에이전트 (Sub-agents) — 경량 모드

부모 prompt가 자식 `codex exec` 서브프로세스를 직접 fork한다. 서브 에이전트는 stdout JSONL로 결과를 보고한다.

```
[부모] → codex exec ... -C _workspace/a/ → events.jsonl (결과)
       → codex exec ... -C _workspace/b/ → events.jsonl
       → codex exec ... -C _workspace/c/ → events.jsonl
```

**핵심 호출:**
```bash
codex exec \
  --json --ephemeral --skip-git-repo-check \
  -C _workspace/<role>/ \
  --add-dir _workspace/ \
  -s workspace-write \
  -o _workspace/<role>/last.txt \
  --prompt-file agents/<role>.md \
  "<task>"
```

이벤트 형식 (실측):
```jsonl
{"type":"thread.started","thread_id":"019..."}
{"type":"turn.started"}
{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"..."}}
{"type":"turn.completed","usage":{"input_tokens":...,"output_tokens":...}}
```

**특징:**
- 가볍고 빠름 (MCP 폴링 오버헤드 없음)
- 결과가 JSONL로 표준화되어 wrapper 스크립트로 회수 용이
- 토큰 효율적

**제약:**
- 서브 에이전트 간 통신 불가 (메시지 전달은 파일 또는 별도 MCP 호출)
- 부모가 모든 조율 담당
- 실시간 협업/도전 불가

### 모드 선택 의사결정 트리

```
에이전트가 2개 이상인가?
├── Yes → 에이전트 간 통신이 필요한가?
│         ├── Yes → 에이전트 팀 (MCP team server, 기본값)
│         │         교차 검증·발견 공유·실시간 피드백으로 품질 향상.
│         │
│         └── No → 서브 에이전트 (codex exec) 도 가능
│                  결과 전달만 필요한 생성-검증, 전문가 풀 등.
│
└── No (1개) → 서브 에이전트
              단일 에이전트는 팀 구성 불필요.
```

> **핵심 원칙:** 에이전트 팀이 기본이다. 서브 에이전트를 선택할 때는 "팀원 간 통신이 정말 불필요한가?"를 자문한다.

---

## 에이전트 팀 아키텍처 유형

### 1. 파이프라인 (Pipeline)
순차적 작업 흐름. 이전 에이전트의 출력이 다음 에이전트의 입력.

```
[분석] → [설계] → [구현] → [검증]
```

**적합한 경우:** 각 단계가 이전 단계의 산출물에 강하게 의존
**예시:** 소설 집필 — 세계관 → 캐릭터 → 플롯 → 집필 → 편집
**팀 모드 적합성:** 순차 의존이 강해 팀 모드의 이점이 제한적. 단, 파이프라인 내 병렬 구간이 있으면 팀 모드 유용.

### 2. 팬아웃/팬인 (Fan-out/Fan-in)
병렬 처리 후 결과 통합.

```
         ┌→ [전문가A] ─┐
[분배] → ├→ [전문가B] ─┼→ [통합]
         └→ [전문가C] ─┘
```

**적합한 경우:** 동일 입력에 대해 서로 다른 관점/영역의 분석이 필요
**예시:** 종합 리서치 — 공식/미디어/커뮤니티/배경 동시 조사 → 통합 보고
**팀 모드 적합성:** 에이전트 팀의 가장 자연스러운 패턴. **반드시 에이전트 팀으로 구성해야 한다.** 팀원들이 서로 발견을 공유하고(`send_message`) 도전하며, 한 에이전트의 발견이 다른 에이전트의 조사 방향을 실시간으로 수정할 수 있다.

### 3. 전문가 풀 (Expert Pool)
상황에 따라 적절한 전문가를 선택 호출.

```
[라우터] → { 전문가A | 전문가B | 전문가C }
```

**적합한 경우:** 입력 유형에 따라 다른 처리가 필요
**예시:** 코드 리뷰 — 보안/성능/아키텍처 전문가 중 해당 영역만 호출
**팀 모드 적합성:** 서브 에이전트가 더 적합. `codex exec - < agents/<expert>.md` 한 번 호출.

### 4. 생성-검증 (Producer-Reviewer)

```
[생성] → [검증] → (문제시) → [생성] 재실행
```

**적합한 경우:** 산출물의 품질 보장이 중요하고 객관적 검증 기준이 존재
**주의:** 무한 루프 방지를 위해 최대 재시도 횟수(2~3회) 설정 필수.
**팀 모드 적합성:** 에이전트 팀이 유용. `send_message`로 생성자↔검증자 간 실시간 피드백 교환.

### 5. 감독자 (Supervisor)

```
         ┌→ [워커A]
[감독자] ─┼→ [워커B]    ← 감독자가 task_list 결과를 보고 동적 분배
         └→ [워커C]
```

**적합한 경우:** 작업량이 가변적이거나 런타임에 작업 분배를 결정해야 할 때
**팀 모드 적합성:** `task_create`로 감독자가 작업 등록, 워커가 `task_list({owner:null, status:"pending"})`로 자체 요청.

### 6. 계층적 위임 (Hierarchical Delegation)

```
[총괄] → [팀장A] → [실무자A1, A2]
       → [팀장B] → [실무자B1]
```

**팀 모드 적합성:** Codex MCP team server는 중첩 팀에 제약이 없다(다른 team_id로 새 팀 생성 가능). 다만 깊이 3단계 이상은 메시지 폴링/태스크 추적 오버헤드가 누적되므로 2단계 이내 권장.

## 복합 패턴

| 복합 패턴 | 구성 | 예시 |
|----------|------|------|
| **팬아웃 + 생성-검증** | 병렬 생성 후 각각 검증 | 다국어 번역 — 4개 언어 병렬 번역 → 각각 네이티브 리뷰어 검수 |
| **파이프라인 + 팬아웃** | 순차 단계 중 일부를 병렬화 | 분석(순차) → 구현(병렬) → 통합 테스트(순차) |
| **감독자 + 전문가 풀** | 감독자가 전문가를 동적 호출 | 고객 문의 처리 — 감독자가 분류 후 적합한 전문가 할당 |

### 복합 패턴에서의 실행 모드

**기본적으로 모든 복합 패턴에 에이전트 팀을 사용한다.** 팀원 간 활발한 커뮤니케이션이 결과 품질의 핵심 동력이다.

| 시나리오 | 권장 모드 | 이유 |
|---------|----------|------|
| **리서치 + 분석** | 에이전트 팀 | 조사자 간 발견 공유, 상충 정보 실시간 토론 |
| **설계 + 구현 + 검증** | 에이전트 팀 | 설계자↔구현자↔검증자 간 피드백 루프 |
| **감독자 + 워커** | 에이전트 팀 | 공유 작업 목록으로 동적 할당 |
| **생성 + 검증** | 에이전트 팀 | 생성자↔검증자 간 실시간 피드백으로 재작업 최소화 |

> 서브 에이전트로의 혼합은 단일 에이전트가 완전히 격리된 단발성 작업을 수행할 때만 고려한다.

## 에이전트 타입 선택 (Codex 등가)

Codex에는 Claude의 빌트인 `subagent_type`(general-purpose / Explore / Plan)이 없다. 대신:

| Claude 빌트인 타입 | Codex 등가 | 강제 메커니즘 |
|---|---|---|
| `general-purpose` | 기본 `codex exec` | 옵션 없음. 모든 도구 접근 가능 |
| `Explore` (읽기 전용) | `codex exec -s read-only` | sandbox 정책으로 쓰기 도구 차단 + 네트워크 차단 |
| `Plan` (설계 전용) | `codex exec` + prompt 본문에 "산출물은 설계 문서만, 코드 수정 금지" 지시 | sandbox 강제 없음. 모델 컴플라이언스에 의존 |

### 커스텀 타입

`agents/{name}.md`에 에이전트를 정의하면 `codex exec - < agents/{name}.md`로 호출 가능. 커스텀 에이전트는 sandbox 옵션을 호출 시점에 지정해야 한다.

### 선택 기준

| 상황 | 권장 | 이유 |
|------|------|------|
| 역할이 복잡하고 여러 세션에서 재사용 | **커스텀 타입** (`agents/`) | 페르소나와 작업 원칙을 파일로 관리 |
| 단순 조사/수집이고 프롬프트만으로 충분 | **`codex exec` + 상세 프롬프트** | 에이전트 파일 불필요 |
| 코드 읽기만 필요 (분석/리뷰) | **`-s read-only`** | 실수로 파일 수정하는 것을 sandbox가 차단 |
| 설계/계획만 필요 | **agents/planner.md + 본문 지시** | sandbox 강제 불가 — 본문에 명시 |
| 파일 수정이 필요한 구현 작업 | **커스텀 타입 + `-s workspace-write`** | 전체 도구 접근 + 전문 지시 |

**원칙:** 모든 에이전트는 반드시 `agents/{name}.md` 파일로 정의한다. 빌트인 카테고리가 없는 Codex에서는 sandbox 모드가 유일한 행동 강제 메커니즘이며, 그 밖의 행동 원칙은 모두 prompt 본문에 명시되어야 한다.

**모델:** 권장 모델 등급은 "최고 추론 등급"(예: `gpt-5.4`). `codex exec -m <model>` 또는 `--profile <p>`로 명시.

## 에이전트 정의 구조

```markdown
---
name: agent-name
description: "1-2문장 역할 설명. 트리거 키워드 나열."
---

# Agent Name — 역할 한줄 요약

당신은 [도메인]의 [역할] 전문가입니다.

## 핵심 역할
1. 역할1
2. 역할2

## 작업 원칙
- 원칙1
- 원칙2

## 입력/출력 프로토콜
- 입력: [어디서 무엇을 받는지]
- 출력: [어디에 무엇을 쓰는지]
- 형식: [파일 포맷, 구조]

## 팀 통신 프로토콜 (에이전트 팀 모드 — MCP team server)
- 메시지 수신: 매 turn 시작 시 `recv_messages({team_id, as: "<my-name>", since: <cursor>})` 호출
- 메시지 발신: `send_message({team_id, from: "<my-name>", to: "<target>", content})`
- 작업 요청: `task_create({team_id, subject, description, owner: null})` — pending 상태로 등록 후 다른 팀원이 자체 take

## 에러 핸들링
- [실패 시 행동]
- [타임아웃 시 행동]

## 협업
- 다른 에이전트와의 관계
```

## 에이전트 분리 기준

| 기준 | 분리 | 통합 |
|------|------|------|
| 전문성 | 영역이 다르면 분리 | 영역이 겹치면 통합 |
| 병렬성 | 독립 실행 가능하면 분리 | 순차 종속이면 통합 고려 |
| 컨텍스트 | 컨텍스트 부담이 크면 분리 | 가볍고 빠르면 통합 |
| 재사용성 | 다른 팀에서도 쓰면 분리 | 이 팀에서만 쓰면 통합 고려 |

## 스킬 vs 에이전트 구분

| 구분 | 스킬 (Skill) | 에이전트 (Agent) |
|------|-------------|-----------------|
| 정의 | 절차적 지식 + 도구 번들 | 전문가 페르소나 + 행동 원칙 |
| 위치 | `skills/` (Codex 자동 주입 디렉토리) | `agents/` (codex exec stdin 주입 대상: `- "<task>" < agents/<name>.md`) |
| 트리거 | 사용자 요청 키워드 매칭 (Codex `<skills_instructions>` 자동 주입) | `codex exec - < agents/<name>.md` 명시 호출 |
| 크기 | 작은~큰 (워크플로우) | 작은 (역할 정의) |
| 용도 | "어떻게 하는가" | "누가 하는가" |

## 스킬 ↔ 에이전트 연결 방식

Codex에는 별도 `Skill` invocation 도구가 없다 — 모델이 SKILL.md를 직접 read 한다. 따라서:

| 방식 | 구현 | 적합한 경우 |
|------|------|-----------|
| **SKILL.md 직접 read** | 에이전트 prompt 본문에 "다음 SKILL.md를 read하여 적용한다: `<plugin-root>/skills/<X>/SKILL.md`" 명시 | 스킬이 독립 워크플로우 |
| **프롬프트 내 인라인** | 에이전트 정의 내에 스킬 내용을 직접 포함 | 스킬이 짧고(50줄 이하) 이 에이전트 전용 |
| **레퍼런스 로드** | `Read`로 스킬의 references/ 파일을 필요 시 로드 | 스킬 내용이 크고 조건부로만 필요 |

권장: 재사용성이 높으면 SKILL.md 직접 read, 전용이면 인라인, 대용량이면 레퍼런스 로드.
