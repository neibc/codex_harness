# Example: Node.js Express CLI — before / after

이 예시는 빈 Express 백엔드 프로젝트에 `codex_harness`로 하네스를 구성했을 때 어떤 산출물이 생기는지 보여줍니다.

> **주의**: `after/` 의 파일들은 본 플러그인이 실제 환경에서 생성하는 **대표적 형태의 시연용 샘플**입니다. 실제 Codex가 만드는 산출물은 도메인 분석 결과·모델 자율 판단·사용자 추가 요청에 따라 달라집니다. 이 예시는 "**무엇이 생성될 수 있는지**" 멘탈 모델을 잡기 위한 것이지, 정확한 출력 명세가 아닙니다.

## 흐름

### 1. 시작 상태 — `before/`

빈 Express 프로젝트:

```
before/
├── package.json
└── src/
    └── index.js
```

3 파일, ~30줄. 라우트도 1개(헬로 월드). 이 상태로 codex_harness 설치 후 cwd 진입:

```bash
cd before/
codex
> 하네스를 구성해줘
```

### 2. 7-Phase 워크플로우

`harness:harness` 스킬이 활성화되어 다음을 수행:

- **Phase 1 — 도메인 분석**: package.json + src/index.js 검사 → "Express 백엔드 + 단일 파일 구조 + 테스트 부재" 식별
- **Phase 2 — 팀 아키텍처 설계**: 어떤 에이전트가 필요한지 사용자와 합의
- **Phase 3 — 에이전트 정의**: `agents/*.md` 작성
- **Phase 4 — 스킬 생성**: `skills/*/SKILL.md` 작성
- **Phase 5 — AGENTS.md 통합**: 라우팅 표 + MCP 도구 표 등록
- **Phase 6 — 검증**: 구조 정합성 점검
- **Phase 7 — 트리거링 안내 출력**: 어떤 자연어로 후속 요청을 트리거하는지 사용자에게 안내

### 3. 결과 — `after/`

```
after/
├── agents/
│   ├── backend-architect.md     ← API 스펙·라우팅·DB 설계
│   ├── api-tester.md            ← Vitest 통합 테스트
│   └── docs-maintainer.md       ← README/OpenAPI 갱신
├── skills/
│   ├── api-change/SKILL.md      ← 라우트 추가/변경 워크플로우
│   └── test-generation/SKILL.md ← 테스트 자동 생성 패턴
└── AGENTS.md                    ← 도메인 트리거 + 에이전트 라우팅 표 + MCP 도구 표
```

(`before/`의 package.json, src/는 그대로 유지, 위 파일만 추가)

### 4. 후속 사용

같은 cwd에서 다시 codex 진입:

```
> POST /users 엔드포인트 추가해줘
```

활성화된 흐름:
1. AGENTS.md의 description 매칭 → `api-change` 스킬 활성화
2. 스킬 본문이 `backend-architect`(스펙) → `api-tester`(테스트 추가) → `docs-maintainer`(OpenAPI/README 갱신) 순서를 안내
3. MCP 팀 서버 도구로 `task_create` → 각 에이전트가 `recv_messages` 폴링하여 작업 인계
4. 최종 산출물: `src/users.js`, `tests/users.test.js`, README 갱신

## 정량 비교 (대표적 패턴)

| 항목 | before | after | with harness 활용 |
|---|---|---|---|
| 파일 수 | 3 | 9 (+6) | — |
| 매번 컨텍스트 재제공 필요? | 예 | 아니오 (AGENTS.md로 영속화) | 큼 |
| 새 라우트 추가 시 잊기 쉬운 단계 | 테스트, 문서 | 자동 라우팅으로 누락 방지 | 큼 |
| 팀원 onboarding 자료 | 없음 | AGENTS.md가 도메인 가이드 역할 | 중간 |

## 한계

- 본 예시는 **간단한 도메인** 기준입니다. 작은 프로젝트(1~2 파일)에서는 하네스 구성이 과할 수 있습니다 — "단일 스킬로 만들어줘" 명시 권장.
- 외부 자료 수집이 필요한 도메인(학술 조사, 사이트 탐색 등)에서는 `WebSearch`/`WebFetch` MCP 별도 등록 필요. 자세히는 [`../../LIMITATIONS.md`](../../LIMITATIONS.md) #3, #11 참조.
