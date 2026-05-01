# codex_harness — 프로젝트 지침 (Claude Code)

이 저장소는 **두 환경이 공유하는 듀얼-네이처 프로젝트**다:

1. **Codex 플러그인** — 저장소 루트가 곧 Codex CLI 플러그인. `codex plugin install .` 또는 git URL로 직접 설치.
   - 사용자 진입: `prompts/`, `agents/`, `mcp-team-server/`, `AGENTS.md`, `plugin.toml`
2. **Claude Code 개발 하네스** — 위 플러그인을 빌드/유지보수하는 메타-하네스가 `.claude/` 아래에 있다.
   - 진입점: `.claude/skills/codex-harness-orchestrator/SKILL.md`

Claude Code에서는 `.claude/`만 활성화되고, Codex에서는 루트의 plugin 트리만 활성화된다. 양쪽 모두 같은 git 저장소에 커밋된다.

## 하네스: codex-harness

**목표:** revfactory의 Claude Code `harness` 플러그인을 OpenAI Codex CLI 호환 플러그인으로 포팅한다. Codex가 1차 primitive로 제공하지 않는 Agent Team(`TeamCreate`/`SendMessage`/`TaskCreate`)을 MCP 서버(`mcp-team-server/`)로 에뮬레이션하여, Claude Code 사용자와 Codex 사용자가 같은 하네스 효과를 얻게 한다.

**트리거:** 다음 요청에 `codex-harness-orchestrator` 스킬을 사용하라.
- "codex 하네스 빌드/포팅", "harness를 codex로 변환", "codex용 plugin 만들기"
- "MCP 팀 서버 작성", "Agent Team 에뮬레이션 설계"
- 기존 빌드 결과물(`prompts/`, `agents/`, `mcp-team-server/`, `AGENTS.md`, `plugin.toml`, `tests/`) 재실행/수정/보완/업데이트/재빌드/부분 재실행
- `_workspace/` 또는 루트 Codex 플러그인 트리 변경 요청

단순 질문(예: "codex CLI가 무엇인가요?")은 직접 응답 가능. 하네스 호출이 필요한지 판단 기준: **분석/설계/빌드/검증 중 2개 이상의 단계가 필요한가?** 그렇다면 오케스트레이터.

## 작업 디렉토리 규칙

- 중간 산출물: `_workspace/<NN>_<artifact>.md` (gitignored, 사후 감사용)
- **최종 산출물: 프로젝트 루트의 Codex 플러그인 파일들** (`prompts/`, `agents/`, `mcp-team-server/`, `tests/`, `AGENTS.md`, `plugin.toml`, `LIMITATIONS.md`) — git 커밋 대상
- 이전 버전 보관: `_workspace/_archive/` (gitignored)
- `dist/` 서브디렉토리에 빌드 출력하지 **않는다** — 저장소 루트가 곧 설치 가능한 Codex 플러그인이다.
- 디렉토리 규약 상세: `.claude/skills/codex-harness-orchestrator/references/workspace-conventions.md`

## 빌더의 영역 / 보호 파일

빌더(`codex-plugin-builder`)가 갱신/생성하는 파일:
- `prompts/*.md`, `agents/*.md`, `mcp-team-server/{src,package.json,tsconfig.json}`, `tests/smoke.sh`
- `AGENTS.md`, `plugin.toml`, `LIMITATIONS.md` (placeholder 덮어쓰기)
- 루트 `README.md`의 "Codex 사용자용 빠른 설치", "Known limitations" 섹션만 갱신

빌더가 함부로 손대지 않는 파일:
- `CLAUDE.md` (이 파일), `LICENSE`, `.gitignore`, `.claude/` 전체
- 사용자 수동 수정 흔적이 있는 파일 — 사용자 확인 후 진행

## 변경 이력

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-05-02 | 초기 하네스 구성 (5 에이전트 + 5 스킬 + 오케스트레이터) | 전체 | - |
| 2026-05-02 | 빌드 출력 경로를 `dist/codex-harness/` → 프로젝트 루트로 재배선 | 오케스트레이터, 패키징 스킬, 빌더 에이전트, workspace 규약, CLAUDE.md | 저장소 자체가 git에 push되어 codex plugin install . 으로 직접 설치되는 듀얼-네이처 구조로 통합 |
| 2026-05-02 | 루트 Codex 플러그인 스캐폴딩 (README, LICENSE, .gitignore, AGENTS.md/plugin.toml placeholder, prompts/agents/mcp-team-server/tests 빈 트리) | 루트 | 빌드 전에도 git 저장소가 일관된 Codex 플러그인 형상을 유지하도록 |
