---
name: output-quality-metrics
description: Codex와 Claude 산출물의 품질을 8축(분량/구조/추론/인용/도구/검증/변증법/토큰)으로 정량 측정하고 격차 표를 생성하는 방법론. output-comparator 에이전트가 사용. measure.sh 표준 스크립트와 격차 등급 임계값을 제공.
---

# Output Quality Metrics

격차의 차원을 분리하기 위한 8축 정량 측정 + 정성 보완 방법론.

## 8축 카탈로그

`codex-quality-orchestrator/references/comparison-metrics.md` 참조 (단일 진실 원천).

요약:
1. **분량** (lines, bytes, words)
2. **구조 깊이** (headers, tables, code blocks)
3. **추론 깊이** (인과/조건 키워드)
4. **인용 / 근거** (URL, quote, source labels)
5. **도구 호출** (events.jsonl 카운트)
6. **검증 / QA** (verify/test/assert)
7. **변증법 / 대안** (however/alternative/반대)
8. **토큰 사용량** (input + output)

## 측정 흐름

```
양 환경 산출물 (output-root)
    ↓
scripts/measure.sh <env-dir>  →  metrics.json 보강
    ↓
양쪽 metrics.json 차이 계산  →  ratio 표
    ↓
ratio + 임계값 → 격차 등급 부여
    ↓
정성 노트 (메트릭이 못 잡는 패턴)
    ↓
02_comparison.md 생성
```

## 격차 등급

| ratio (claude/codex) | 등급 | 의미 |
|---|---|---|
| < 1.5× | — | 격차 없음 (noise 수준) |
| 1.5~3× | "큼" | 주목할 만한 격차 |
| ≥ 3× | "⚠️ 매우 큼" | 정비 우선 대상 |

## 정성 보완 패턴

메트릭만으로 못 잡는 격차 패턴:
- **헤더 충실, 살 부족** — 구조는 같은데 본문 줄 수만 짧음
- **도구 호출 횟수 vs 활용도** — 같은 grep을 둘 다 했지만 codex는 결과를 다음 호출 input으로 안 씀
- **누락된 메타 phase** — 검증/회고/대안 같은 phase 자체가 본문에 없음
- **외부 자료 vs 내부 추론** — claude는 WebFetch 빌트인으로 출처 풍부, codex는 내부 추론에 의존해 인용 빈약

이런 패턴은 정성 노트에 짧게 기록 (메트릭 표 아래 1~2 문단).

## 비교 대상의 페어링

같은 task를 하나의 환경에서 여러 번 돌려 비교하는 것이 아니라, **같은 task를 양 환경에서 1회씩** 돌려 비교한다. 이유:
- 모델 비결정성에 의한 회당 변동은 체계적 환경 차이보다 작은 경우가 많음 (단, 신뢰성 필요 시 N=3 옵션 가능)
- 비용 관리

신뢰도 향상이 필요한 경우(예: 정비안 적용 후 효과 측정):
- regression-tester가 N=3 회 옵션으로 측정 후 평균/중앙값 표기

## 회귀 검사

정비안 적용 후 측정 시:
- 의도한 차원이 격차 축소 (≥10%)인가?
- 다른 차원이 악화되지 않았는가? (≥30% 악화 시 회귀)
- 비용/시간이 합리적인가? (예: 분량 2× 증가했지만 시간 5× = trade-off 경계)

## 표준 출력 형식

```markdown
# Comparison: <task-id>

## 정량 표

| 차원 | claude | codex | ratio | 등급 |
|---|---|---|---|---|
| 줄 | 455 | 57 | 8.0× | ⚠️ 매우 큼 |
| ...

## 격차 차원 우선순위

1. <차원> (<ratio>) — <짧은 분석>
2. ...

## 정성 노트

- <메트릭이 못 잡는 패턴 1>
- ...

## 핸드오프

prompt-engineer에게 ↑ 우선순위 ≥3 차원 + 정성 노트 인계.
```
