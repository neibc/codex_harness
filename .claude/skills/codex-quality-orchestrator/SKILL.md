---
name: codex-quality-orchestrator
description: Codex CLI의 산출물 품질이 Claude Code 대비 짧거나 얕을 때, 동일 task를 양 환경에서 실측 비교하고 격차 차원을 진단해 codex_harness의 SKILL.md/agents 프롬프트를 비침습적으로 정비한 뒤 재측정으로 검증하는 사이클을 자동화한다. "Codex 품질 정비", "claude 대비 codex 격차 측정", "프롬프트 튜닝", "Codex 보고서 길이/깊이 개선", "비교 실험 돌려줘", "정비안 다시 검증" 등 모든 정비-회귀 사이클 요청에 사용.
---

# Codex Quality Orchestrator

Codex 산출물의 분량·구조·깊이 격차를 Claude 기준으로 측정·진단·정비·검증하는 7단계 사이클. **revfactory 원본 추상화 보존 원칙**(LIMITATIONS.md #11) 안에서만 정비.

## 트리거

다음 발화 중 하나로 활성화 (description 자연어 매칭):
- "**Codex 품질 정비해줘**" / "claude 대비 codex 격차 측정해줘"
- "프롬프트 튜닝 / 정비 / 다시 검증해줘"
- "비교 실험 돌려줘 / 회귀 측정해줘"

비대화형:
```bash
codex exec - "<task pool 명세>" < .claude/skills/codex-quality-orchestrator/SKILL.md
```

## Phase 0 — 컨텍스트 확인

`_workspace/quality/` 존재 여부 확인:
- `_workspace/quality/<prev-ts>/` 존재 + 사용자 "재측정" 요청 → **회귀 검증 모드** (이전 baseline 그대로 두고 정비안만 재실행)
- 존재 + "다음 사이클" 요청 → **신규 사이클** (새 가설 도출)
- 미존재 → **초기 사이클**

본 디렉토리에 `_workspace/quality/<ts>/`(현재 사이클)을 생성한다.

## Phase 1 — 입력 정규화

사용자에게서 task pool 1~3개를 받거나 디폴트 사용:
- 디폴트: `~/codexwork/leehongjang/_workspace/00_input/request.md` (외부 자료 수집 도메인) + `~/claudework/saju/_workspace/00_research_scope.md` (학술 검토 도메인)
- 또는 사용자 지정 task

각 task의 `_workspace/quality/<ts>/00_input/<task-id>.md`에 명세 작성:
- domain
- request prompt
- 산출물 기대 (보고서? 코드? 분석?)
- input files (있으면)

## Phase 2 — 양 환경 실행 (병렬 서브 에이전트)

각 task에 대해 dual-environment-runner를 호출:

```
Agent({
  description: "Run task on both Claude and Codex",
  subagent_type: "general-purpose",
  model: "opus",
  prompt: "<dual-environment-runner.md 본문 + task 명세 + 출력 디렉토리>"
})
```

dual-environment-runner는 내부에서 `claude` + `codex exec`를 shell `&` + `wait`로 병렬 실행. 산출물:
```
01_runs/<task-id>/{claude,codex}/{stdout.txt|events.jsonl, files/, metrics.json}
```

**Phase 2 완료 조건:** 모든 task에 대해 양쪽 metrics.json + stdout 산출물 존재 (또는 명시된 unavailable 플래그).

## Phase 3 — 격차 분석

output-comparator를 호출:

```
Agent({
  description: "Compare claude vs codex outputs",
  subagent_type: "general-purpose",
  model: "opus",
  prompt: "<output-comparator.md 본문 + 01_runs 디렉토리 경로>"
})
```

산출물: `02_comparison.md` — 8축 정량 표 + 격차 차원별 우선순위 + 정성 노트.

**Phase 3 완료 조건:** 격차 차원 ≥3개 식별 (1.5× 이상). 식별 안 되면 정비 사이클 무의미 → 사용자에게 보고 후 종료.

## Phase 4 — 가설 + 정비안

prompt-engineer를 호출:

```
Agent({
  description: "Diagnose Codex-specific causes and design patches",
  subagent_type: "general-purpose",
  model: "opus",
  prompt: "<prompt-engineer.md 본문 + 02_comparison.md 경로>"
})
```

산출물: `03_hypotheses.md` — 격차 차원별 Codex-특성 가설 + 4가지 정비 표면 중 하나로 매핑 + 사용자 승인 필요 항목.

**Phase 4 완료 조건:** 가설 ≥1개 + 정비안 ≥1개 + 검증 가능한 형태 (regression-tester가 측정 가능).

## Phase 5 — 사용자 승인 (오케스트레이터)

오케스트레이터가 03_hypotheses.md를 사용자에게 요약 보고:
- 격차 차원 → 가설 → 변경 위치 → 예상 효과
- 사용자가 변경 동의 여부 결정
- "사용자 승인 필요 항목"(revfactory 추상화 변형 가능)은 별도 결정

승인된 정비안만 Phase 6에서 적용.

## Phase 6 — 정비 적용

prompt-engineer를 다시 호출하되 `apply` 모드로:

```
Agent({
  description: "Apply approved patches",
  subagent_type: "general-purpose",
  model: "opus",
  prompt: "<prompt-engineer.md 본문 + 03_hypotheses.md + 승인된 항목 목록 + apply 모드>"
})
```

각 변경 후 즉시 smoke test 1회 실행 (`tests/smoke.sh`). 실패 시 revert.

산출물: `04_changes/` — 변경 전/후 파일 + git diff.

## Phase 7 — 회귀 측정

regression-tester를 호출:

```
Agent({
  description: "Measure post-patch gap reduction",
  subagent_type: "general-purpose",
  model: "opus",
  prompt: "<regression-tester.md 본문 + baseline 02_comparison.md + 변경된 SKILL.md + 동일 task>"
})
```

산출물: `05_regression.md` — 3-way 메트릭 표 (claude/codex-before/codex-after) + 차원별 격차 축소율 + 회귀 여부.

**Phase 7 완료 조건:** 모든 변경된 차원에 대해 측정 결과 존재.

## Phase 8 — 사이클 요약 + 진화

`06_summary.md` 작성:
- 이번 사이클의 가설/정비/효과 요약
- 다음 사이클 권장 (효과 있는 가설은 유지, 무효는 폐기, 새 가설 후보)
- CLAUDE.md 변경 이력에 기록

사용자에게 다음 액션 제안:
- "효과 충분 → 사이클 종료"
- "더 정밀한 측정 위해 task pool 확장"
- "남은 차원 가설 추가"
- "MCP web-fetch 등록 후 인용 차원 재시도"

## 정비 표면 (4가지만 허용)

prompt-engineer는 다음 4가지 외 표면을 건드리지 않는다 (revfactory 보존):

1. **frontmatter 강화**: description 트리거/후속 키워드, tools, metadata
2. **Codex 환경 박스**: 본문 옆 "> Codex 환경 안내: ..." 추가 (본문 자체 변경 X)
3. **호출 wrapper 가이드**: `codex exec -m -s ...` 패턴 예시
4. **AGENTS.md 라우팅/도구 표 정밀화**

거부 표면(요청 받아도 사용자 승인 없이 변경 금지):
- ❌ Phase 갯수/순서 변경
- ❌ "에이전트 팀 기본값" 같은 정책 변경
- ❌ 변증법/methodology critique 본문 강제 주입

## 산출물 체크리스트

- [ ] `_workspace/quality/<ts>/00_input/<task-id>.md` 모든 task
- [ ] `_workspace/quality/<ts>/01_runs/<task-id>/{claude,codex}/` 모두
- [ ] `02_comparison.md` (격차 차원 ≥3 식별)
- [ ] `03_hypotheses.md` (가설/정비안 ≥1)
- [ ] 사용자 승인 기록
- [ ] `04_changes/` (변경 전/후 + diff)
- [ ] `05_regression.md` (3-way 표)
- [ ] `06_summary.md`
- [ ] CLAUDE.md 변경 이력 1행 추가

## 테스트 시나리오

### 정상 흐름
1. 사용자 "Codex 품질 정비해줘" → 디폴트 task pool 사용 → Phase 1~8 완주.
2. 격차 차원 4개 식별, 그 중 2개 정비안 사용자 승인, 적용 후 격차 50% 축소 확인.

### 회귀 흐름
1. 정비안 적용 후 smoke test 실패 → 즉시 revert.
2. regression-tester가 다른 차원 악화(≥30%) 발견 → quality-evaluator가 변경 revert.

### 측정 실패 흐름
1. claude CLI 부재 → claude 측 산출물 없이 진행, 상대 비교 불가 표시 + 정비 사이클 중단 권장.

## 참조

- `references/comparison-metrics.md` — 8축 메트릭 정의 + 측정 스크립트
- `references/codex-pattern-catalog.md` — Codex-특성 가설 카탈로그 (사이클 돌면서 누적)
- `references/patch-surface-rules.md` — 4가지 정비 표면의 정확한 경계
