# AGENTS.md — node-cli-example

## 하네스: Node.js Express 백엔드 개발

**목표:** 단일 Express 서버에서 새 라우트 추가, 테스트 작성, 문서 갱신을 일관된 워크플로우로 처리.

**트리거:** 다음 자연어 발화로 활성화:
- "**API 추가해줘**" / "**엔드포인트 만들어줘**" / "라우트 추가" / "POST/GET /xxx 만들어줘"
- "테스트 자동화", "테스트 보강", "vitest 추가"
- "OpenAPI 갱신", "API 문서 다시"

스킬 자동 라우팅:

| 발화 패턴 | 스킬 |
|---|---|
| "엔드포인트/라우트 추가/변경" | `skills/api-change/SKILL.md` |
| "테스트 추가/생성/보강" | `skills/test-generation/SKILL.md` |

## 에이전트 라우팅

| 작업 단계 | 호출 에이전트 |
|---|---|
| API 스펙 설계 / 라우팅 / DB 모델 | `codex exec - "<task>" < agents/backend-architect.md` |
| 통합 테스트 시나리오 + Vitest 구현 | `codex exec - "<task>" < agents/api-tester.md` |
| README / OpenAPI / inline JSDoc 갱신 | `codex exec - "<task>" < agents/docs-maintainer.md` |

## MCP 팀 도구 (위임이 필요한 경우)

| 도구 | 용도 |
|---|---|
| `team_create` | 라우트 1개당 팀 생성 (architect → tester → docs) |
| `task_create` | "POST /users 추가" 같은 단위 작업 등록 |
| `task_update` | 각 에이전트가 완료 시 metadata에 산출물 경로 기록 |
| `recv_messages` | 다음 단계 에이전트가 매 turn 폴링 |
| `team_destroy` | 라우트 추가 완료 후 archive |

저장소: `~/.codex/teams.sqlite` (또는 `TEAM_STORAGE_PATH`).

## 변경 이력

| 날짜 | 변경 |
|---|---|
| (예시) 2026-05-02 | 초기 하네스 구성 (Express 백엔드) |
