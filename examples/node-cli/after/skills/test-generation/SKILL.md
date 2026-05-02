---
name: test-generation
description: 기존 라우트/모듈에 대해 누락된 테스트를 분석·작성한다. "테스트 보강", "테스트 자동 생성", "커버리지 채워줘" 발화 시 사용.
---

# Test Generation

기존 코드의 테스트 공백을 메운다. `api-change`와 달리 신규 라우트가 아닌 **기존 자산의 테스트 보강**이 주 사용처.

## Phase 1 — 갭 분석

```bash
npm run coverage 2>/dev/null || npx vitest run --coverage
```

또는 정적 분석:
- `src/`의 export된 함수 vs `tests/`에서 import되는 항목 diff
- 라우트별 happy/에러/경계 매트릭스 검사

## Phase 2 — 우선순위 결정

다음 순서:
1. 비즈니스 로직 (services/) 단위 테스트
2. API 라우트 통합 테스트
3. 미들웨어 단위 테스트
4. 유틸 함수

각 항목에 대해 `task_create({subject: "test for <module>", owner: "api-tester"})`.

## Phase 3 — 작성 (api-tester)

`agents/api-tester.md` 호출 시 입력으로 갭 분석 결과를 전달.

## 검증

- `npm test` 통과
- `npx vitest run --coverage` — 핵심 모듈 커버리지 임계 (예: ≥ 80%)
- CI에 테스트 추가되어 있는지 확인 (`.github/workflows/`)

## 트리거 매칭

`테스트 보강`, `커버리지`, `누락 테스트`, `add tests`, `improve coverage`, `generate tests`.
