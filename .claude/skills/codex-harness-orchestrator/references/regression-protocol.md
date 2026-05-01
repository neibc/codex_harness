# Regression Protocol

Phase D QA에서 블로킹 이슈가 발견되었을 때.

## 1. 책임 소재 분류

QA 보고서에서 각 버그를 다음 중 하나로 분류:

- **Translation gap** — 번역 테이블이 매핑을 빠뜨렸거나 잘못함 → Phase B 회귀
- **Build defect** — 번역은 옳지만 빌더가 잘못 구현 → Phase C 회귀
- **Codex limitation** — 우회 불가능한 Codex 자체 한계 → 번역 테이블 "변환 불가" 섹션에 기록 + README LIMITATIONS.md 갱신, 회귀 없음
- **Analyst miss** — 분석 에이전트가 잘못된 사실 보고 → Phase A 부분 재실행

## 2. 회귀 흐름

```
QA blocking issue
   ↓
분류
   ├── Translation gap   → Phase B 부분 재실행 (translator만)
   ├── Build defect      → Phase C 부분 재실행 (builder만)
   ├── Codex limitation  → 문서화로 종료
   └── Analyst miss      → Phase A 부분 재실행 → Phase B → C → D
```

## 3. 회귀 시 보존

- 회귀 대상 산출물만 `_archive/`로 이동
- 회귀 비대상 산출물은 그대로 유지
- 회귀 후 QA 재실행 시 **이전 QA 보고서를 입력으로 제공** — "X는 이미 검증됨, Y만 재검증" 안내

## 4. 사용자 승인

회귀는 시간이 걸리므로 Auto 모드라도 한 번은 사용자에게 "회귀 진행 OK?" 확인 권장.
단, 명백한 typo/경로 오류 등 1분 이내 수정 가능한 항목은 자동 회귀 가능 (보고서에 기록).

## 5. 무한 회귀 방지

- 같은 phase에 3회 이상 회귀하면 중단하고 사용자에게 인간 개입 요청
- 회귀 횟수는 `_workspace/_regression_counter.txt`에 기록 (성공 시 리셋)

## 6. 변경 이력 갱신

회귀 발생 시 CLAUDE.md 변경 이력 테이블에:
```
| 2026-MM-DD | Phase B 회귀 — translation gap (subagent_type=Plan 매핑 누락) | _workspace/03_translation_table.md | QA 보고 |
```
