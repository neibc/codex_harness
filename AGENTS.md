# codex_harness — AGENTS.md (Codex 진입 지침)

> **Status:** placeholder. Phase C 빌더가 번역 테이블에 따라 이 파일을 채웁니다.

## 하네스: codex-harness

**목표:** revfactory의 Claude Code `harness` 플러그인과 동등한 Agent Team & Skill Architect 메타 기능을 Codex CLI에서 제공.

**트리거:** 다음 요청 시 `prompts/harness.md`(또는 `prompts/codex-harness-orchestrator.md`)를 실행.
- "하네스 구성", "하네스 빌드", "에이전트 팀 만들기", "스킬 작성"
- "harness", "agent team", "skill architect"

호출 방법:
- 인터랙티브: `codex` 진입 후 `/harness` (Codex 슬래시 트리거 지원 시)
- 비대화형: `codex exec --prompt-file prompts/harness.md "<요청>"`

## 에이전트 페르소나

`agents/` 디렉토리에 다음 페르소나가 정의됩니다 (Phase C 빌드 후):
- (placeholder) — 빌더가 번역 테이블에서 가져옴

## MCP 팀 서버

Agent Team 에뮬레이션은 `mcp-team-server/`의 MCP 서버가 제공합니다. 등록:

```bash
codex mcp add team --command node --args "$(pwd)/mcp-team-server/dist/index.js"
```

도구:
- `team_create`, `team_destroy`
- `send_message`, `recv_messages`
- `task_create`, `task_update`, `task_list`, `task_get_output`

## Known Limitations

이 파일은 빌더가 채울 때 `LIMITATIONS.md`로 분리됩니다. 그 전까지는 README의 "무엇이 손실되는가" 섹션 참조.

## 변경 이력

| 날짜 | 변경 내용 |
|------|----------|
| 2026-05-02 | placeholder 생성 (빌더 미실행 상태) |
