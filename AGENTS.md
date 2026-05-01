# AGENTS.md — codex_harness

이 저장소는 Codex CLI 0.125.0+ 환경에서 동작하는 하네스 플러그인이다. Codex는 cwd의 `AGENTS.md` 한 개만 자동 로드하므로(upward search 없음), 본 파일에 도메인 트리거 + 에이전트 라우팅 표 + MCP 도구 표를 모두 집약한다.

## 하네스: codex-harness

**목표:** revfactory의 Claude Code `harness` 1.2.0 플러그인을 Codex CLI로 포팅한 메타-스킬. 도메인/프로젝트에 맞는 에이전트 팀과 스킬을 설계·생성·점검한다.

**트리거:** "하네스 구성", "하네스 구축", "하네스 설계", "하네스 엔지니어링", "하네스 점검", "하네스 감사", "에이전트/스킬 동기화", "harness", "agent team", "skill architect" 요청 시 다음 중 하나:

- 인터랙티브: `codex` 진입 후 `/harness`
- 비대화형: `codex exec --prompt-file skills/harness/SKILL.md "<요청>"`

진입 후 `skills/harness/SKILL.md` (메인 스킬)이 자동 주입되며, 본문의 7-Phase 워크플로우를 따라 도메인 분석 → 팀 설계 → 에이전트/스킬 생성 → 검증을 수행한다.

## 에이전트 호출 라우팅

본 플러그인은 메타-하네스 자체를 빌드한 5개 페르소나를 동봉한다 (사용자가 자기 도메인용 새 에이전트를 만들 때는 이 5개를 덮어쓰지 말고 자신의 cwd에 새로 작성한다 — `agents/` 디렉토리 참조).

| 작업 의도 | 호출 명령 |
|---|---|
| Codex CLI 내부 primitive 분석 | `codex exec --json --ephemeral -C _workspace/internals/ -s read-only --prompt-file agents/codex-internals-analyst.md "<요청>"` |
| Claude 측 자산 인벤토리 작성 | `codex exec --json --ephemeral -C _workspace/cartographer/ -s read-only --prompt-file agents/claude-harness-cartographer.md "<요청>"` |
| 번역 테이블 작성 | `codex exec --json --ephemeral -C _workspace/translator/ --add-dir _workspace/ -s workspace-write --prompt-file agents/primitive-translator.md "<요청>"` |
| 플러그인 빌드 | `codex exec --json --ephemeral -C . --add-dir _workspace/ -s workspace-write --prompt-file agents/codex-plugin-builder.md "<요청>"` |
| 컴플라이언스 QA | `codex exec --json --ephemeral -C _workspace/qa/ --add-dir _workspace/ --add-dir . -s workspace-write --prompt-file agents/codex-harness-qa.md "<요청>"` |

각 호출은 `-C <iso-dir>`로 작업 디렉토리를 격리한다. 산출물은 `_workspace/` 하위에 phase별 파일로 떨어진다.

## MCP 도구 호출 (Team 에뮬레이션)

플러그인 매니페스트(`.codex-plugin/plugin.json`)가 `mcpServers: "./.mcp.json"`을 통해 `mcp-team-server/dist/index.js`를 자동 등록한다(stdio). 8개 도구를 제공:

| 도구 | 인자 (요지) | 출력 (요지) |
|---|---|---|
| `team_create` | `{team_name, members[], leader?}` | `{team_id}` |
| `send_message` | `{team_id, from, to, content, tags?}` (`to:"*"` 브로드캐스트) | `{message_id, ts}` |
| `recv_messages` | `{team_id, as, since?, limit?}` | `{messages[]}` (폴링) |
| `task_create` | `{team_id, subject, description?, owner?, blocked_by?}` | `{task_id}` (status=pending) |
| `task_update` | `{team_id, task_id, status?, owner?, metadata?}` | `{ok}` (history 자동 기록) |
| `task_list` | `{team_id, status?, owner?}` | `{tasks[]}` |
| `task_get_output` | `{team_id, task_id}` | `{output, status, updated_at}` |
| `team_destroy` | `{team_id, archive?}` | `{ok, archived}` |

저장소: `~/.codex/teams.sqlite` (WAL 모드, 단일 파일). 환경변수 `TEAM_STORAGE_PATH`로 override.

상세 schema와 폴링 패턴은 `skills/harness/SKILL.md` 본문 + `skills/harness/references/orchestrator-template.md` 참조.

## 알려진 손실 / 한계

본 플러그인은 Claude Code 원본의 일부 primitive를 Codex 등가로 대체하지만 완전 무손실은 아니다. 10개 손실 항목과 완화 방법은 [`LIMITATIONS.md`](LIMITATIONS.md) 참조.

핵심 손실 요지:
- `SendMessage` 동기 도착 통지 → polling
- `subagent_type=Explore/Plan/general-purpose` 카테고리 → sandbox + prompt 지시문
- `WebFetch`/`WebSearch` 빌트인 → 외부 MCP 서버
- `PreToolUse`/`PostToolUse` hook 이벤트 → `--ask-for-approval` 정책

## 변경 이력

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-05-02 | 초기 구성 (Codex 포팅) | 전체 | revfactory/harness 1.2.0에서 fork |
