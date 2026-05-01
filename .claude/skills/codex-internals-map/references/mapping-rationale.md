# Mapping Rationale — Claude → Codex

각 매핑 결정의 **근거**와 **거절된 대안**.

## SKILL.md → Codex prompt 파일

**1순위:** `prompts/<name>.md` (Codex가 슬래시 커맨드 또는 명시적 호출로 트리거)
- 이유: 사용자 진입점이 동일(`/<name>`), frontmatter는 Codex 측 무시되더라도 사람이 읽을 수 있음.
- 거절: AGENTS.md 한 파일에 모두 합치기 → 본문이 거대해지고 컨텍스트 낭비.
- 위험: Codex가 슬래시 트리거를 지원하지 않는 버전이면 사용자가 `codex exec --prompt-file ...`로 명시 호출해야 함. README에 명시.

## 에이전트 정의 → agents/<name>.md + AGENTS.md 등록

**1순위:** 별도 마크다운 파일 + AGENTS.md에 "어떤 에이전트가 있고 언제 호출하는지" 한 줄씩.
- 이유: Codex는 페르소나를 prompt 텍스트로 전달해야 함. 파일 분리하면 재사용/유지보수 용이.
- 거절: 모든 에이전트 정의를 `codex exec --instructions @file` 형식으로만 노출 → AGENTS.md에 어떤 에이전트가 존재하는지 단서가 없어 발견 불가.

## TeamCreate/SendMessage → MCP 팀 서버

**1순위:** 자체 구현 MCP 서버가 `team_create`, `send_message`, `task_create`, `task_update`, `task_list` 도구를 제공.
- 이유: Codex가 MCP 클라이언트로서 도구 호출 패턴을 표준 지원. 메시지/작업 상태를 외부 프로세스에서 영속화 가능 → 다중 Codex 세션이 같은 팀 컨텍스트 공유 가능.
- 거절 1: 파일 IPC만 사용 (메시지를 디스크에 직접 쓰기) — Codex prompt가 매번 파일을 읽어야 하므로 컨텍스트 낭비, 동시성 락이 어려움.
- 거절 2: 단일 컨텍스트에서 직렬 시뮬레이션 (한 prompt 안에 "에이전트1: ..." "에이전트2: ..." 식) — 실제 다른 모델 호출이 아니므로 다양성 없음, 컨텍스트 한계.

## Agent 도구 (subagent) → `codex exec` 서브프로세스

**1순위:** 오케스트레이터 prompt가 `codex exec --working-dir <isolated> --prompt-file <agent>.md` 형식으로 자식 호출.
- 이유: 진짜 다른 컨텍스트가 생성됨. Claude Code의 `Agent` 도구와 의미적으로 가장 근접.
- 위험: `codex exec`는 신규 세션을 만들므로 `~/.codex/` 인증/설정 공유 필요. README에 환경변수 가이드 명시.

## CLAUDE.md → AGENTS.md

**1순위:** 그대로 옮기되, Claude 전용 표현(예: "/skill-name 호출")을 Codex 표현(예: "`codex exec --prompt-file ...`")으로 치환.
- 거절: 이름 유지(CLAUDE.md를 그대로 둠) — Codex는 AGENTS.md를 읽지 CLAUDE.md를 읽지 않으므로 효과 없음.

## settings.json hooks → ?

**미결정.** Codex hooks 지원 여부는 분석 에이전트가 확인해야 함. 미지원 시 폴백:
- shell wrapper (`hooks.sh`)로 사용자가 codex 호출을 감싸도록 유도. README에 한계 표시.
- `codex exec` 전후에 자체 스크립트를 묶는 별도 entrypoint 제공.
