# Comparison Metrics — 8축 정의

격차 측정 기준. output-comparator가 모든 비교에 동일하게 적용.

## 8개 축

| 차원 | 메트릭 | 측정 명령 | 격차 등급 임계 |
|---|---|---|---|
| 1. 분량 (줄/바이트/단어) | `wc -l/-c/-w` | `wc -l output.md` | ≥3× = 큼, ≥5× = 매우 큼 |
| 2. 구조 깊이 | h1+h2+h3 + 표 행 + 코드 블록 | `grep -c '^#'`, `grep -c '^|'`, `grep -c '^\`\`\`'` | ≥2× = 큼 |
| 3. 추론 깊이 | 인과/조건 키워드 빈도 | `grep -ic '왜냐하면\|because\|however\|therefore\|근거\|전제'` | ≥3× = 큼 |
| 4. 인용 / 근거 | URL + 인용문(`>`) + 출처 라벨 | `grep -c 'https\?://'`, `grep -c '^>'` | ≥3× = 큼 |
| 5. 도구 호출 | `tool_use` / `command_execution` 이벤트 수 | `jq '[.[] \| select(.item.type=="command_execution")] \| length' events.jsonl` | ≥3× = 큼 |
| 6. 검증 / QA | 검증 키워드 빈도 | `grep -ic '검증\|verify\|test\|assert\|체크\|확인'` | ≥3× = 큼 |
| 7. 변증법 / 대안 | 대안 키워드 빈도 | `grep -ic '그러나\|however\|alternative\|반대로\|한편\|반면'` | ≥5× = 매우 큼 |
| 8. 토큰 사용량 | input + output | metrics.json | 정보용 (격차 등급 부여 안 함) |

추가:
- 시간 (wall-clock 초): metrics.json. 정보용.
- 파일 생성 수 (task가 파일 산출 도메인일 때): `find files/ -type f \| wc -l`.

## 측정 스크립트 표준

`scripts/measure.sh` (모든 측정에 사용):

```bash
#!/usr/bin/env bash
# Usage: measure.sh <output-dir>  →  prints metrics.json line
set -euo pipefail
DIR="$1"
OUT="$DIR/output.md"
[ -f "$OUT" ] || OUT="$DIR/stdout.txt"

LINES=$(wc -l < "$OUT" 2>/dev/null || echo 0)
BYTES=$(wc -c < "$OUT" 2>/dev/null || echo 0)
WORDS=$(wc -w < "$OUT" 2>/dev/null || echo 0)
HEADERS=$(grep -cE '^#{1,3} ' "$OUT" 2>/dev/null || echo 0)
TABLES=$(grep -c '^|' "$OUT" 2>/dev/null || echo 0)
CODE=$(grep -c '^```' "$OUT" 2>/dev/null || echo 0)
URLS=$(grep -cE 'https?://' "$OUT" 2>/dev/null || echo 0)
QUOTES=$(grep -c '^>' "$OUT" 2>/dev/null || echo 0)
REASONING=$(grep -icE '왜냐하면|because|however|therefore|근거|전제' "$OUT" 2>/dev/null || echo 0)
DIALECTIC=$(grep -icE '그러나|however|alternative|반대로|한편|반면' "$OUT" 2>/dev/null || echo 0)
VERIFICATION=$(grep -icE '검증|verify|test|assert|체크|확인' "$OUT" 2>/dev/null || echo 0)

EVENTS="$DIR/events.jsonl"
TOOL_CALLS=0
[ -f "$EVENTS" ] && TOOL_CALLS=$(jq '[.[] | select(.item.type=="command_execution")] | length' "$EVENTS" 2>/dev/null || echo 0)

cat <<JSON
{"lines":$LINES,"bytes":$BYTES,"words":$WORDS,"headers":$HEADERS,"tables":$TABLES,"code":$CODE,"urls":$URLS,"quotes":$QUOTES,"reasoning":$REASONING,"dialectic":$DIALECTIC,"verification":$VERIFICATION,"tool_calls":$TOOL_CALLS}
JSON
```

## 비교 표 형식

```markdown
| 차원 | claude | codex | ratio | 등급 |
|---|---|---|---|---|
| 줄 | 455 | 57 | 8.0× | ⚠️ 매우 큼 |
| 헤더 | 11 | 6 | 1.83× | 큼 |
| ... | ... | ... | ... | ... |
```

ratio = claude / codex (claude가 더 많을 때 양수). 등급:
- < 1.5× → "—" (격차 없음, noise)
- 1.5~3× → "큼"
- ≥ 3× → "⚠️ 매우 큼"

## 정성 노트 가이드

메트릭만으로 못 잡는 패턴 식별:
- "헤더 충실, 살 부족" — 구조는 같은데 본문 줄 수만 다른 경우
- "도구 호출 횟수는 비슷하나 품질 다름" — 같은 grep을 둘 다 했지만 codex는 한 번만 보고 끝, claude는 결과를 다음 호출 input으로 활용
- "Codex만 누락된 phase" — 검증/회고 같은 메타 phase가 본문에 없음
