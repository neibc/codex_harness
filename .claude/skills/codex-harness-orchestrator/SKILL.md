---
name: codex-harness-orchestrator
description: revfactory의 Claude Code harness 플러그인을 OpenAI Codex CLI 호환 플러그인으로 포팅하는 전체 워크플로우를 조율하는 오케스트레이터. Codex 분석 → revfactory 인벤토리 → 매핑 설계 → MCP 팀 서버 + 프롬프트 빌드 → QA 검증을 자동화한다. "codex 하네스 포팅", "harness를 codex로 변환", "codex용 plugin 빌드", "MCP 팀 서버 만들기", 또는 프로젝트 루트의 Codex 플러그인 트리(skills/, mcp-team-server/, .codex-plugin/, AGENTS.md 등)를 다시 실행/업데이트/수정/보완/재빌드하는 모든 후속 요청에서 반드시 사용. 부분 재실행, 결과 개선, 새 입력 기반 재빌드까지 처리.
---

# Codex Harness Orchestrator

revfactory의 Claude Code 하네스 플러그인을 Codex CLI 호환으로 변환하는 **하이브리드 파이프라인** 오케스트레이터.

## 워크플로우 한눈에

```
Phase A: Discovery (서브 에이전트 병렬)
  ├─ codex-internals-analyst      → _workspace/01_codex_primitives.md
  └─ claude-harness-cartographer  → _workspace/02_claude_primitives.md

Phase B: Design (에이전트 팀)
  └─ primitive-translator (+ A의 두 에이전트가 팀 멤버로 잔류)
                                  → _workspace/03_translation_table.md

Phase C: Build (에이전트 팀)
  └─ codex-plugin-builder (+ primitive-translator가 팀 멤버)
                                  → 프로젝트 루트의 Codex 플러그인 트리 + _workspace/04_build_log.md

Phase D: Validate (서브 에이전트)
  └─ codex-harness-qa             → _workspace/05_qa_report.md
```

## Phase 0: 컨텍스트 확인 (필수 — 후속 작업 처리)

워크플로우 시작 시 다음 분기를 먼저 결정한다:

1. `_workspace/` 디렉토리 존재 여부 확인
2. 사용자 발화 분석:
   - **부분 재실행** 요청 ("번역 테이블만 다시", "QA만 재실행", "빌더만 재호출"): 해당 phase의 에이전트만 호출
   - **새 입력으로 재실행** ("새 버전 codex로 다시", "다른 플러그인 경로로"): 기존 `_workspace/`를 `_workspace_prev_<ts>/`로 이동, 처음부터 실행
   - **개선 요청** ("이전 결과 개선", "X를 추가해서 다시"): 해당 산출물 파일을 입력으로 두고 영향 범위만 재실행
   - **초기 실행** (`_workspace/` 없음): 처음부터 전체 실행

3. 결정한 모드를 사용자에게 한 줄로 보고 후 진행 (Auto 모드면 보고 후 즉시 진행).

## Phase A: Discovery (서브 에이전트 병렬)

**실행 모드: 서브 에이전트** — 두 분석가는 서로 통신할 필요 없음. `Agent` 도구로 병렬 호출(`run_in_background: true`).

```
Agent({
  description: "Analyze Codex CLI primitives",
  subagent_type: "general-purpose",
  prompt: <codex-internals-analyst.md 본문 요약 + 작업 지시>,
  model: "opus",
  run_in_background: true
})

Agent({
  description: "Catalogue revfactory harness plugin",
  subagent_type: "general-purpose",
  prompt: <claude-harness-cartographer.md 본문 요약 + 작업 지시>,
  model: "opus",
  run_in_background: true
})
```

두 에이전트 완료 대기 → 산출물(`01_codex_primitives.md`, `02_claude_primitives.md`) 존재 확인 → Phase B로.

**Acceptance:** 두 보고서 모두 "Open questions" 섹션을 포함하고, codex 버전과 플러그인 버전이 명시되어 있어야 한다.

## Phase B: Design (에이전트 팀)

**실행 모드: 에이전트 팀** — 번역가가 두 분석가에게 모호한 항목을 재질의해야 함.

```
TeamCreate({
  team_name: "design-team",
  members: ["primitive-translator", "codex-internals-analyst", "claude-harness-cartographer"],
  leader: "orchestrator"
})

TaskCreate({
  subject: "Build translation table",
  description: "primitive-translator는 _workspace/03_translation_table.md를 작성. 분석가 두 명은 질의 응답만 수행.",
  owner: "primitive-translator"
})
```

번역가가 SendMessage로 분석가에게 질의 → 분석가가 응답 → 번역 테이블 완성 → `task_update(completed)` → Phase C로.

**Acceptance:** `_workspace/03_translation_table.md`에 마스터 매핑 표 + Agent Team 에뮬레이션 채택 안 + 거절된 대안 2개 + 변환 불가 항목이 모두 존재.

팀 정리: `TeamDelete({team_name: "design-team"})`.

## Phase C: Build (에이전트 팀)

**실행 모드: 에이전트 팀** — 빌더와 번역가가 모호점을 즉시 해소.

```
TeamCreate({
  team_name: "build-team",
  members: ["codex-plugin-builder", "primitive-translator"],
  leader: "orchestrator"
})

TaskCreate({ subject: "Populate Codex plugin tree at project root", owner: "codex-plugin-builder" })
```

빌더가 모호점 발견 시 SendMessage로 번역가에게 질의 → 빌더가 산출물 생성 → `_workspace/04_build_log.md`에 stub/TODO 목록 명시.

**Acceptance:**
- 루트 `skills/harness/SKILL.md` + `references/` 6종 존재 (placeholder 아님)
- 루트 `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json` 존재 및 상호 동조 (이름/버전/포지셔닝)
- 루트 `mcp-team-server/`에 `package.json` + `src/` + tsconfig 등 빌드 가능한 코드 존재 (`npm run build` 통과)
- 루트 `tests/smoke.sh`가 placeholder 아닌 실제 검증 로직 (실행 PASS)
- 루트 `AGENTS.md`, `install.sh`, `bin/update.sh`가 현행 설치 절차(심링크 canonical, marketplace는 `--marketplace` 옵트인)와 일치

팀 정리: `TeamDelete({team_name: "build-team"})`.

## Phase D: Validate (서브 에이전트)

**실행 모드: 서브 에이전트** — QA는 단독 실행, 결과만 메인에 반환.

```
Agent({
  description: "QA codex-harness build",
  subagent_type: "general-purpose",   // Explore 아님 — Bash 필요
  prompt: <codex-harness-qa.md 본문 + 작업 지시>,
  model: "opus"
})
```

QA가 `_workspace/05_qa_report.md` 생성. 블로킹 이슈 발견 시 오케스트레이터가 사용자에게 보고하고 Phase B 또는 C로 회귀(사용자 승인 필요).

## 데이터 전달 프로토콜

- **파일 기반** (주력): 중간 산출물은 `_workspace/<phase>_<artifact>.md`, 최종 산출물은 프로젝트 루트의 Codex 플러그인 파일들 (`prompts/`, `agents/`, `mcp-team-server/`, `tests/`, `AGENTS.md`, `plugin.toml`, `LIMITATIONS.md`)
- **메시지 기반** (Phase B, C 팀 모드): MCP 팀 서버를 시뮬레이션하지 않고 Claude Code의 SendMessage 1차 primitive 사용
- **태스크 기반** (Phase B, C): TaskCreate/TaskUpdate로 작업 상태 추적

> 본 오케스트레이터는 Claude Code 측에서 실행되므로 1차 primitive를 그대로 사용한다. 빌드 산출물(루트 Codex 플러그인 트리)은 Codex 측에서 별도 작동하며, 같은 git 저장소를 두 환경이 공유한다.

## 에러 핸들링

- **Phase A 분석가 실패** → 1회 재시도 → 재실패 시 보고서 누락 표시하고 Phase B로 진행, 번역 테이블에 "Unknown — needs verification" 다수 발생 예상
- **Phase B 모호점 누적** → Phase A를 부분 재실행 (해당 분석가만)
- **Phase C 빌드 실패** → 빌드 로그를 사용자에게 보여주고 진행/중단 결정
- **Phase D QA 실패 (블로킹)** → 사용자 승인 후 Phase B/C 회귀 (회귀 사유를 변경 이력에 기록)
- 모든 실패는 `_workspace/_errors/<ts>_<phase>.md`에 stderr 캡처 보존

## 산출물 체크리스트

워크플로우 종료 시 확인:

- [ ] `_workspace/01_codex_primitives.md`
- [ ] `_workspace/02_claude_primitives.md`
- [ ] `_workspace/03_translation_table.md`
- [ ] `_workspace/04_build_log.md`
- [ ] `_workspace/05_qa_report.md`
- [ ] 루트 `README.md` (설치 절차 갱신됨, placeholder 아님)
- [ ] 루트 `AGENTS.md` (placeholder 아님)
- [ ] 루트 `.codex-plugin/plugin.json` (실측 schema 반영) + `.agents/plugins/marketplace.json` (동조)
- [ ] 루트 `LIMITATIONS.md` (lossy-conversions 결과)
- [ ] 루트 `skills/harness/` (SKILL.md + references/ 6종)
- [ ] 루트 `install.sh` + `bin/update.sh` (심링크 canonical, marketplace `--marketplace` 옵트인)
- [ ] 루트 `mcp-team-server/` (`package.json`, `src/`, `tsconfig.json` 등)
- [ ] 루트 `tests/smoke.sh` (실제 검증) + `tests/mcp_guard.mjs`

## 테스트 시나리오

### 시나리오 1: 정상 흐름 (초기 실행)

입력: 사용자가 "/codex-harness-orchestrator codex용 하네스 빌드해줘"
기대: 4개 phase 순차 진행, 모든 산출물 생성, smoke.sh 통과 보고.

### 시나리오 2: 부분 재실행

입력: 빌드 후 "QA만 다시 돌려줘"
기대: Phase 0에서 부분 재실행 감지 → Phase D만 재호출 → 새 `_workspace/05_qa_report.md` 생성. 다른 산출물 보존.

### 시나리오 3: 분석가 실패 폴백

입력: 정상 호출
조건: WebFetch가 GitHub 차단으로 실패
기대: 분석가가 로컬 실측치만으로 보고서 작성, "remote source unavailable" 표시. Phase B 진행.

### 시나리오 4: 새 codex 버전으로 재실행

입력: codex 0.130 설치 후 "새 codex 버전으로 다시"
기대: Phase 0에서 새 입력 모드 감지 → 기존 `_workspace/`를 `_workspace_prev_<ts>/`로 이동 → 전체 재실행.

## 참조

- `references/agent-call-templates.md` — 각 phase의 정확한 Agent/Team 호출 코드 템플릿
- `references/workspace-conventions.md` — `_workspace/` 디렉토리 규칙, 아카이브 정책
- `references/regression-protocol.md` — Phase D 실패 시 회귀 절차
