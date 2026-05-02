# Agent Team Examples (Codex port)

> Claude의 1차 primitive 호출은 모두 Codex 등가로 치환했다(`Agent` → `codex exec`, `TeamCreate/SendMessage/TaskCreate/...` → MCP team server 도구). 본문 의미는 원본과 동일.

---

## 예시 1: 리서치 팀 (에이전트 팀 모드)

### 팀 아키텍처: 팬아웃/팬인
### 실행 모드: 에이전트 팀

```
[리더/오케스트레이터]
    ├── team_create({team_name: "research-team", members: [...]})
    ├── task_create × 4 (조사 작업)
    ├── 팀원 spawn (codex exec × 4 in background)
    ├── 팀원들이 자체 조율 (send_message + recv_messages)
    ├── 결과 수집 (task_get_output 또는 Read)
    └── 종합 보고서 생성
```

### 에이전트 구성

| 팀원 | sandbox | 역할 | 출력 |
|------|---------|------|------|
| official-researcher | workspace-write | 공식 문서/블로그 | research_official.md |
| media-researcher | workspace-write | 미디어/투자 | research_media.md |
| community-researcher | workspace-write | 커뮤니티/SNS | research_community.md |
| background-researcher | workspace-write | 배경/경쟁/학술 | research_background.md |
| (리더 = 오케스트레이터) | — | 통합 보고서 | 종합보고서.md |

> 리서치 에이전트는 모두 일반 모드(sandbox `workspace-write`). 반드시 `agents/{name}.md` 파일로 정의한다. 파일에는 역할·조사 범위·팀 통신 프로토콜을 명시.

### 오케스트레이터 워크플로우 (에이전트 팀)

```
Phase 1: 준비
  - 사용자 입력 분석 (주제, 조사 모드 파악)
  - _workspace/ 생성

Phase 2: 팀 구성
  - team_create({
      team_name: "research-team",
      members: ["official", "media", "community", "background"],
      leader: "orchestrator"
    })
    → { team_id }
  - task_create × 4:
      task_create({ team_id, subject: "공식 채널 조사", owner: "official" })
      task_create({ team_id, subject: "미디어 동향 조사", owner: "media" })
      task_create({ team_id, subject: "커뮤니티 반응 조사", owner: "community" })
      task_create({ team_id, subject: "배경 환경 조사", owner: "background" })

Phase 3: 조사 수행
  - 4개 codex exec 서브프로세스 spawn (background, &)
    각 팀원 prompt 본문에 TEAM_ID 주입 + recv_messages 폴링 지시
  - 흥미로운 발견이 있으면 send_message로 공유
    (예: media가 발견한 투자 뉴스를 background에게 전달)
  - 상충 정보 발견 시 send_message로 직접 토론
  - 각 팀원은 완료 시 파일 저장 + task_update({status: "completed", metadata: {output}})

Phase 4: 통합
  - 리더가 task_list({team_id, status: ["pending","in_progress"]}) 빈 배열 대기
  - 각 task_get_output로 결과 회수 또는 4개 산출물 Read
  - 종합 보고서 생성, 상충 정보는 출처 병기

Phase 5: 정리
  - send_message({team_id, from: "orchestrator", to: "*", content: "<TEAM_DONE>"})
  - team_destroy({team_id, archive: true})
  - _workspace/ 보존
```

### 팀 통신 패턴

```
official ──send_message──→ background  (관련 공식 발표 공유)
media ────send_message──→ background  (투자/인수 정보 공유)
community ─send_message──→ media       (커뮤니티 반응 중 미디어 관련 정보)
모든 팀원 ──task_update──→ 공유 작업 목록  (진행률 업데이트)
리더 ←──── task_list 폴링 ──── 완료된 팀원   (sqlite 기반)
```

---

## 예시 2: SF 소설 집필 팀 (에이전트 팀 모드)

### 팀 아키텍처: 파이프라인 + 팬아웃
### 실행 모드: 에이전트 팀

```
Phase 1 (병렬 — 에이전트 팀): worldbuilder + character-designer + plot-architect
  → 서로 send_message로 일관성 조율
Phase 2 (순차): prose-stylist (집필) — 서브 에이전트 (codex exec)
Phase 3 (병렬 — 에이전트 팀): science-consultant + continuity-manager (리뷰)
  → 서로 send_message로 발견 공유
Phase 4 (순차): prose-stylist (리뷰 반영 수정) — 서브 에이전트
```

### 에이전트 구성

| 팀원 | sandbox | 역할 | 스킬 |
|------|---------|------|------|
| worldbuilder | workspace-write | 세계관 구축 | world-setting |
| character-designer | workspace-write | 캐릭터 설계 | character-profile |
| plot-architect | workspace-write | 플롯 구조 | outline |
| prose-stylist | workspace-write | 문체 편집 + 집필 | write-scene, review-chapter |
| science-consultant | read-only | 과학 검증 | science-check |
| continuity-manager | read-only | 일관성 검증 | consistency-check |

### 에이전트 파일 전문 예시: `agents/worldbuilder.md`

```markdown
---
name: worldbuilder
description: "SF 소설의 세계관을 구축하는 전문가. 물리 법칙, 사회 구조, 기술 수준, 역사를 설계한다."
---

# Worldbuilder — SF 세계관 설계 전문가

당신은 SF 소설의 세계관 설계 전문가입니다. 과학적 사실에 기반하되 상상력을 확장하여, 이야기가 펼쳐질 세계의 물리적·사회적·기술적 토대를 구축합니다.

## 핵심 역할
1. 세계의 물리 법칙과 기술 수준 정의
2. 사회 구조, 정치 체계, 경제 시스템 설계
3. 역사적 맥락과 현재 갈등 구조 수립
4. 장소별 환경과 분위기 묘사

## 작업 원칙
- 내적 일관성 최우선 — 설정 간 모순이 없어야 한다
- "만약 이 기술이 있다면?" 연쇄 질문으로 세계의 파급 효과를 추론
- 이야기에 봉사하는 세계관 — 플롯을 방해하는 과도한 설정은 지양

## 입력/출력 프로토콜
- 입력: 사용자의 세계관 컨셉, 장르 요구사항
- 출력: `_workspace/01_worldbuilder_setting.md`
- 형식: 마크다운. 섹션별 (물리/사회/기술/역사/장소)

## 팀 통신 프로토콜 (MCP team server)
- 매 turn 시작 시 recv_messages({team_id, as: "worldbuilder", since: <cursor>}) 호출
- character-designer에게: send_message({to: "character-designer", content: "사회 구조, 계급 시스템, 직업군 정보"})
- plot-architect에게: send_message({to: "plot-architect", content: "세계의 주요 갈등 구조, 위기 요소"})
- science-consultant로부터 피드백 수신 시 → 설정 수정 후 task_update
- 세계관 변경 시 send_message({to: "*", content: "..."}) 브로드캐스트

## 에러 핸들링
- 컨셉이 모호하면 3가지 방향을 제안하고 선택 요청
- 과학적 오류 발견 시 대안을 함께 제시

## 협업
- character-designer에게 사회 구조 정보 제공
- plot-architect에게 갈등 구조 정보 제공
- science-consultant의 피드백을 반영하여 설정 수정
```

### 팀 워크플로우 상세

```
Phase 1: team_create({team_name: "novel-team", members: ["worldbuilder","character-designer","plot-architect"]})
         task_create × 3 (세계관 구축, 캐릭터 설계, 플롯 구조)
         3개 codex exec 서브프로세스 spawn → 자체 조율 병렬 작업
         → worldbuilder가 사회 구조 완성 시 send_message → character-designer
         → character-designer가 주인공 설정 시 send_message → plot-architect

Phase 2: team_destroy({team_id, archive: true})  → 팀 정리
         prose-stylist를 codex exec 서브프로세스로 호출 (단독 집필이므로 팀 불필요)
         prose-stylist가 _workspace/의 3개 산출물을 Read하여 집필
         → _workspace/02_prose_draft.md 저장

Phase 3: 새 팀 생성 — team_create({team_name: "review-team", members: ["science-consultant","continuity-manager"]})
         (sqlite는 별도 team_id로 격리되므로 새 팀 생성에 제약 없음)
         → 두 리뷰어 codex exec 서브프로세스 spawn (sandbox: read-only)
         → science-consultant가 물리 오류 발견 시 send_message → continuity-manager
         → 리뷰 완료 후 team_destroy

Phase 4: prose-stylist를 codex exec 서브프로세스로 호출, 리뷰 결과 반영하여 최종 수정
```

---

## 예시 3: 웹툰 제작 팀 (서브 에이전트 모드)

### 팀 아키텍처: 생성-검증
### 실행 모드: 서브 에이전트

> 생성-검증 패턴에서 에이전트가 2개뿐이고, 통신보다는 결과 전달이 핵심이므로 서브 에이전트가 적합. MCP 팀 서버 오버헤드 회피.

```
Phase 1: codex exec - < agents/webtoon-artist.md → 패널 생성
Phase 2: codex exec - < agents/webtoon-reviewer.md → 검수
Phase 3: codex exec - < agents/webtoon-artist.md → 문제 패널 재생성 (최대 2회)
```

### 에이전트 구성

| 에이전트 | sandbox | 역할 | 스킬 |
|---------|---------|------|------|
| webtoon-artist | workspace-write | 패널 이미지 생성 | generate-webtoon |
| webtoon-reviewer | read-only | 품질 검수 | review-webtoon, fix-webtoon-panel |

### 에이전트 파일 전문 예시: `agents/webtoon-reviewer.md`

```markdown
---
name: webtoon-reviewer
description: "웹툰 패널의 품질을 검수하는 전문가. 구도, 캐릭터 일관성, 텍스트 가독성, 연출을 평가한다."
---

# Webtoon Reviewer — 웹툰 품질 검수 전문가

당신은 웹툰 패널의 품질을 검수하는 전문가입니다. 시각적 완성도, 스토리 전달력, 캐릭터 일관성을 기준으로 패널을 평가합니다.

## 핵심 역할
1. 각 패널의 구도와 시각적 완성도 평가
2. 캐릭터 외형의 패널 간 일관성 검증
3. 말풍선 텍스트의 가독성과 배치 평가
4. 전체 에피소드의 연출 흐름과 페이싱 검토

## 작업 원칙
- PASS/FIX/REDO 3단계로 명확히 판정
- FIX는 부분 수정으로 해결 가능한 경우, REDO는 전면 재생성 필요
- 주관적 취향이 아닌 객관적 기준(일관성, 가독성, 구도)으로 판단

## 입력/출력 프로토콜
- 입력: `_workspace/panels/` 디렉토리의 패널 이미지들
- 출력: `_workspace/review_report.md`
- 형식:
  ```
  ## Panel {N}
  - 판정: PASS | FIX | REDO
  - 사유: [구체적 이유]
  - 수정 지시: [FIX/REDO인 경우 구체적 수정 방향]
  ```

## 에러 핸들링
- 이미지 로드 실패 시 해당 패널을 REDO로 판정
- 2회 재생성 후에도 REDO인 패널은 경고와 함께 PASS 처리

## 협업
- webtoon-artist에게 수정 지시서 전달 (결과 파일 기반)
- 재생성된 패널을 다시 검수 (최대 2회 루프)
```

### 에러 핸들링

```
재시도 정책:
- REDO 판정 패널 → artist에게 재생성 요청 (구체적 수정 지시 포함)
- 최대 2회 루프 후 강제 PASS
- 전체 패널의 50% 이상이 REDO면 사용자에게 prompt 수정 제안
```

---

## 예시 4: 코드 리뷰 팀 (에이전트 팀 모드)

### 팀 아키텍처: 팬아웃/팬인 + 토론
### 실행 모드: 에이전트 팀

> 코드 리뷰는 에이전트 팀이 빛나는 대표적 사례. 서로 다른 관점의 리뷰어들이 발견을 공유하고 도전하면서 더 깊은 리뷰가 가능.

```
[리더] → team_create({team_name: "review-team", members: ["security","performance","test"]})
    ├── security-reviewer: 보안 취약점 점검
    ├── performance-reviewer: 성능 영향 분석
    └── test-reviewer: 테스트 커버리지 검증
    → 리뷰어들이 서로 발견 공유 (send_message)
    → 리더가 task_get_output로 결과 종합
```

### 팀 통신 패턴

```
security ──send_message──→ performance  ("이 SQL 쿼리 주입 가능, 성능 측면에서도 확인 필요")
performance ──send_message──→ test      ("N+1 쿼리 발견, 관련 테스트 있는지 확인 부탁")
test ────send_message──→ security      ("인증 모듈 테스트 없음, 보안 관점에서 우선순위 의견?")
```

핵심: 리뷰어들이 **리더를 거치지 않고** 직접 소통(`send_message`)하여 교차 영역 이슈를 빠르게 포착.

---

## 예시 5: 감독자 패턴 — 코드 마이그레이션 팀 (에이전트 팀 모드)

### 팀 아키텍처: 감독자
### 실행 모드: 에이전트 팀

```
[supervisor/리더] → 파일 목록 분석 → task_create × N (배치 작업)
    ├→ [migrator-1] (codex exec + recv_messages 폴링)
    ├→ [migrator-2]
    └→ [migrator-3]
    ← task_update 수신 → 추가 task_create 또는 owner 변경 (재할당)
```

### 에이전트 구성

| 팀원 | 역할 |
|------|------|
| (리더 = migration-supervisor) | 파일 분석, 배치 분배, 진행 관리 |
| migrator-1~3 | 할당된 파일 배치를 마이그레이션 (codex exec, sandbox: workspace-write) |

### 감독자의 동적 분배 로직 (에이전트 팀 활용)

```
1. 전체 대상 파일 목록 수집
2. 복잡도 추정 (파일 크기, import 수, 의존성)
3. task_create로 파일 배치를 작업으로 등록 (의존성은 blocked_by)
4. 팀원들이 task_list({owner: null, status: "pending"}) 폴링으로 자체 claim → task_update({owner: "self", status: "in_progress"})
5. 팀원이 task_update({status: "completed"})로 완료 보고 시:
   - 성공 → 다음 작업 자동 요청 (task_list)
   - 실패(status: "blocked") → 리더가 send_message로 원인 확인 → task_update({owner: <other>}) 재할당
6. 모든 작업 완료 → 리더가 통합 테스트 실행 (codex exec - < agents/test-runner.md)
```

팬아웃과의 차이: 작업이 사전 고정이 아니라 **런타임에 동적으로 할당**된다. 공유 작업 목록의 자체 요청(claim) 기능이 감독자 패턴과 자연스럽게 매칭.

---

## 산출물 패턴 요약

### 에이전트 정의 파일
위치: `프로젝트/agents/{agent-name}.md`
필수 섹션: 핵심 역할, 작업 원칙, 입력/출력 프로토콜, 에러 핸들링, 협업
팀 모드 추가 섹션: **팀 통신 프로토콜** (recv_messages 폴링 + send_message + task_*)

### 스킬 파일 구조
위치: `프로젝트/skills/{skill-name}/SKILL.md` (프로젝트 레벨, plugin manifest의 `skills` 키로 등록)
또는: `~/.codex/skills/{skill-name}/SKILL.md` (글로벌 레벨)

### 통합 스킬 (오케스트레이터)
팀 전체를 조율하는 상위 스킬. 시나리오별 에이전트 구성과 워크플로우를 정의.
템플릿: `references/orchestrator-template.md` 참조.
**실행 모드를 반드시 명시** — 에이전트 팀(기본) 또는 서브 에이전트.
