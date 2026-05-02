---
name: dual-runtime-comparison
description: Claude Code(`claude` CLI)와 OpenAI Codex CLI(`codex exec`) 양 환경에서 동일 task를 병렬 실행하고 산출물을 동등 비교 가능한 형태로 캡처하는 방법론. 호출 옵션, 출력 캡처, metrics.json 표준, 격리 cwd 컨벤션을 정의한다. dual-environment-runner 에이전트가 사용.
---

# Dual Runtime Comparison

claude / codex 양쪽에서 같은 task를 실행해 동등 비교 가능한 산출물을 만드는 방법론.

## 동등성 보장 4원칙

1. **동일 input** — task prompt, 작업 디렉토리 상태, sandbox 정책 모두 일치
2. **격리** — 각 환경은 별도 임시 cwd 사용, 한쪽이 만든 파일이 다른 쪽에 보이지 않음
3. **병렬 실행** — shell `&` + `wait`. 직렬 실행은 시간 비교를 무의미하게 함
4. **동일 측정** — 둘 다 같은 metrics.json 형식 (`scripts/measure.sh` 참조)

## 출력 디렉토리 표준

```
<output-root>/
├── input.md             # task 명세 (domain, request, files-included)
├── claude/
│   ├── stdout.txt
│   ├── transcript.json  # claude --output-format=stream-json (있으면)
│   ├── files/           # task가 파일 생성이면
│   ├── metrics.json
│   └── stderr.log
└── codex/
    ├── events.jsonl     # codex exec --json
    ├── stdout.txt       # 마지막 agent_message
    ├── files/
    ├── metrics.json
    └── stderr.log
```

## Claude 측 호출 패턴

```bash
CLAUDE_OUT="<output-root>/claude"
mkdir -p "$CLAUDE_OUT/cwd" "$CLAUDE_OUT/files"
cp -R input-files/. "$CLAUDE_OUT/cwd/" 2>/dev/null || true

cd "$CLAUDE_OUT/cwd" && \
  claude --print --output-format=stream-json \
    "$(cat ../../input.md)" \
    > "../transcript.json" 2> "../stderr.log" &
CLAUDE_PID=$!
```

**옵션 실측 필요:** `claude --help` 결과로 정확한 옵션을 확인. `--print`, `--output-format`, `--working-directory` 같은 플래그가 버전마다 다를 수 있음. 실측 후 호출 패턴을 이 reference에 갱신.

## Codex 측 호출 패턴

```bash
CODEX_OUT="<output-root>/codex"
mkdir -p "$CODEX_OUT/cwd" "$CODEX_OUT/files"
cp -R input-files/. "$CODEX_OUT/cwd/" 2>/dev/null || true

codex exec --json --skip-git-repo-check \
  --sandbox workspace-write \
  -C "$CODEX_OUT/cwd" \
  -m gpt-5.5 \
  "$(cat <output-root>/input.md)" \
  > "$CODEX_OUT/events.jsonl" 2> "$CODEX_OUT/stderr.log" &
CODEX_PID=$!
```

## 양쪽 동시 대기

```bash
wait $CLAUDE_PID
CLAUDE_EXIT=$?
wait $CODEX_PID
CODEX_EXIT=$?

# stdout.txt 추출 (Codex)
python3 -c "
import json
events = [json.loads(l) for l in open('$CODEX_OUT/events.jsonl')]
last_msg = next((e['item']['text'] for e in reversed(events) if e.get('item',{}).get('type')=='agent_message'), '')
print(last_msg)
" > "$CODEX_OUT/stdout.txt"

# stdout.txt 추출 (Claude — transcript.json에서)
# 옵션 형식 실측 후 작성
```

## metrics.json 표준

```json
{
  "duration_s": 51,
  "exit_code": 0,
  "input_tokens": 4521,
  "output_tokens": 3812,
  "cached_input_tokens": 0,
  "tool_calls": 7,
  "files_created": 0,
  "model": "gpt-5.5"
}
```

claude 측 token 정보는 stream-json transcript에서 추출, 없으면 `null`.

## 측정 스크립트 호출

각 환경 실행 끝나고:
```bash
bash scripts/measure.sh "$CLAUDE_OUT" >> "$CLAUDE_OUT/metrics.json"
bash scripts/measure.sh "$CODEX_OUT" >> "$CODEX_OUT/metrics.json"
```

`scripts/measure.sh`는 `comparison-metrics.md`의 표준 메트릭을 계산.

## 타임아웃 처리

기본 환경당 15분. 초과 시:
```bash
timeout 900 codex exec ... &
```
Linux는 `timeout`, macOS는 `gtimeout` 또는 별도 wrapper.

타임아웃 시 metrics.json에 `timeout: true`, exit_code 124 기록. 부분 산출물은 그대로 보존.

## 모델 선택

| 환경 | 권장 기본 | 사용자 옵션 |
|---|---|---|
| Claude | `claude-sonnet-4-6` 또는 사용자 default | `--model claude-opus-4-7` |
| Codex | `gpt-5.5` | `-m gpt-5.4-mini` 등 |

비교의 공정성: 양쪽 모두 "최상위 등급"으로 고정해 모델 capability 차이 중 환경 격차만 분리하는 것을 권장. 다만 사용자가 다른 의도(예: claude-opus vs gpt-5-mini 비용비교)면 선택 가능.

## 에러 패턴

- claude CLI 부재: `claude/unavailable.txt` 생성, codex 단일 실행으로 진행
- 양쪽 모두 실패: 즉시 fail 보고
- 부분 산출물만 있음: metrics.json에 partial 표시 + 비교 가능한 차원만 측정
