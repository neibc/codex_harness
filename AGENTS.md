# AGENTS.md — codex_harness

이 저장소는 Codex CLI 0.125.0+ 환경에서 동작하는 하네스 메타-스킬이다. Codex는 cwd의 `AGENTS.md` 한 개만 자동 로드하므로(upward search 없음), 본 파일에 트리거 + MCP 도구 표를 집약한다.

## 트리거 — 자연어 발화가 가장 확실

**스킬 활성화의 1차 트리거는 자연어 문구**다. Codex 인터랙티브에서 `/harness` 슬래시가 항상 표시되지는 않지만, 다음 발화로 동일하게 활성화된다:

- "**하네스를 구성해줘**" / "하네스 구축해줘" / "하네스 설계해줘"
- "하네스를 점검해줘" / "하네스 감사해줘" / "에이전트와 스킬을 동기화해줘"
- "build a harness for ..." / "design an agent team for ..."

진입 후 `skills/harness/SKILL.md` (메인 스킬, `~/.codex/skills/harness/`에 활성화됨)이 모델 컨텍스트에 자동 주입되며, 본문의 7-Phase 워크플로우(도메인 분석 → 팀 설계 → 에이전트/스킬 생성 → 검증 → 진화)를 따른다.

비대화형 진입:

```bash
codex exec --prompt-file skills/harness/SKILL.md "<요청>"
```

## MCP 도구 (Team 에뮬레이션)

`mcp-team-server`가 stdio MCP로 8개 도구를 제공한다. Claude Code의 `TeamCreate`/`SendMessage`/`Task*` 1차 primitive 대체.

| 도구 | 인자 | 출력 |
|---|---|---|
| `team_create` | `{team_name, members[], leader?}` | `{team_id}` |
| `send_message` | `{team_id, from, to, content, tags?}` (`to:"*"` 브로드캐스트) | `{message_id, ts}` |
| `recv_messages` | `{team_id, as, since?, limit?}` | `{messages[]}` (폴링) |
| `task_create` | `{team_id, subject, description?, owner?, blocked_by?}` | `{task_id}` |
| `task_update` | `{team_id, task_id, status?, owner?, metadata?}` | `{ok}` |
| `task_list` | `{team_id, status?, owner?}` | `{tasks[]}` |
| `task_get_output` | `{team_id, task_id}` | `{output, status, updated_at}` |
| `team_destroy` | `{team_id, archive?}` | `{ok, archived}` |

저장소: `~/.codex/teams.sqlite` (WAL). 환경변수 `TEAM_STORAGE_PATH`로 override.

상세 schema와 폴링 패턴은 `skills/harness/references/orchestrator-template.md` 참조.

## 알려진 손실 / 한계

Claude Code 원본의 일부 primitive는 Codex 등가로 대체되었다. 10개 손실 항목 — [`LIMITATIONS.md`](LIMITATIONS.md).

핵심 요지:
- `SendMessage` 동기 도착 통지 → polling
- `subagent_type=Explore/Plan` → `--sandbox read-only` + prompt 지시문
- `WebFetch`/`WebSearch` 빌트인 → 외부 MCP 서버
- `PreToolUse`/`PostToolUse` hook 이벤트 → `--ask-for-approval` 정책 (Codex 0.125.0 기준 미실측)

## 변경 이력

| 날짜 | 변경 내용 |
|------|----------|
| 2026-05-02 | 초기 구성 (revfactory/harness 1.2.0에서 fork) |
| 2026-05-02 | dev-time 페르소나 5개 + hooks/ 제거 — ship surface slim down |
