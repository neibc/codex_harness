---
name: api-change
description: Express 라우트 추가/변경/삭제를 architect → tester → docs-maintainer 순서로 일관되게 처리한다. "엔드포인트 추가/변경", "라우트 추가/수정", "POST/GET/PUT/DELETE /xxx 만들어줘" 발화 시 사용.
---

# API Change Workflow

Express 백엔드에서 라우트 변경을 누락 없이 처리한다. 새 라우트, 시그니처 변경, 삭제 모두 같은 흐름.

## Phase 1 — 사양 결정 (backend-architect)

`agents/backend-architect.md` 호출:
- 라우트 메서드, 경로, 요청 body schema, 응답 body schema, 가능한 에러 코드 정리
- 산출물: `src/routes/<resource>.js` + (필요 시) `src/services/`, `src/models/`

## Phase 2 — 테스트 (api-tester)

`agents/api-tester.md` 호출:
- happy + 에러 + 경계 3축 커버
- 산출물: `tests/<resource>.test.js`
- 통과 확인: `npm test` 1회 실행

## Phase 3 — 문서 동기화 (docs-maintainer)

`agents/docs-maintainer.md` 호출:
- README의 API 섹션 갱신, openapi.yaml/Swagger 동기화
- 변경 한 줄 요약 → CHANGELOG.md (있으면)

## 협업 모드

위 3단계는 직렬이지만 **MCP 팀 서버**로 작업 큐를 영속화하면 부분 재실행이 쉽다:

```
team_create({team_name: "api-change-<resource>", members: ["backend-architect", "api-tester", "docs-maintainer"]})
task_create({subject: "spec", owner: "backend-architect"})
task_create({subject: "tests", owner: "api-tester", blocked_by: ["spec"]})
task_create({subject: "docs", owner: "docs-maintainer", blocked_by: ["tests"]})
```

각 에이전트가 자기 task를 polling하여 완료 → 다음 task가 unblock.

## 검증 체크리스트

- [ ] 새 라우트가 `npm test`에서 통과
- [ ] README의 API 표/예제에 새 라우트 반영
- [ ] openapi.yaml에 새 path 항목 추가 (있는 경우)
- [ ] CHANGELOG에 한 줄 요약 (있는 경우)
- [ ] 기존 테스트 깨지지 않음

## 트리거 매칭 (description 강화 키워드)

`엔드포인트`, `라우트`, `POST/GET/PUT/DELETE/PATCH`, `add API`, `change API`, `remove route`, `API 추가/변경/삭제`.
