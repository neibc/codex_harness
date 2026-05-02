---
name: dual-environment-runner
description: 동일 task를 Claude Code(`claude` CLI) + Codex CLI(`codex exec`) 양 환경에서 병렬 실행하고 산출물·메트릭(토큰/시간/도구 호출)을 표준 컨벤션으로 캡처한다.
model: opus
tools: Bash, Read, Write, Glob
---

# Dual Environment Runner

격차 측정의 첫 단계 — 같은 input을 두 환경에 던지고 결과를 동등 비교 가능한 형태로 회수한다.

## 핵심 역할

각 task에 대해 다음 산출물을 동일 디렉토리 컨벤션으로 생성:
```
_workspace/quality/<ts>/01_runs/<task-id>/
├── input.md             # task 명세
├── claude/
│   ├── stdout.txt       # claude --print 출력
│   ├── transcript.json  # 가능 시
│   ├── files/           # task가 파일 생성 작업이면
│   └── metrics.json     # {duration_s, total_tokens?, tool_calls?, files_created}
└── codex/
    ├── events.jsonl     # codex exec --json 이벤트 스트림
    ├── stdout.txt       # 마지막 agent_message
    ├── files/
    └── metrics.json     # {duration_s, input_tokens, output_tokens, tool_calls, files_created}
```

## 작업 원칙

- **동일 input**: 두 환경에 정확히 같은 prompt + 같은 working dir 상태 + 같은 sandbox 정책.
- **격리**: 각 환경 실행은 별도 임시 디렉토리(`_workspace/quality/<ts>/01_runs/<task-id>/<env>/cwd/`)에서. 한쪽이 만든 파일이 다른 쪽에 보이지 않게.
- **병렬 실행**: shell `&` + `wait`로 동시 시작. 직렬 실행은 시간 비교를 무의미하게 만듦.
- **모델 명시**: 양쪽 모두 권장 모델 `-m`으로 명시. claude는 sonnet/opus 선택 옵션 (사용자가 정한 것), codex는 `gpt-5.5` 기본.
- **타임아웃**: 환경당 최대 N분(기본 15). 초과 시 결과를 "timeout" 표기 + 부분 산출물 보존.

## 호출 형식

### claude 측
```bash
# 비대화형, --print + JSON 출력
claude --print --output-format=stream-json \
  --working-directory _workspace/quality/<ts>/01_runs/<id>/claude/cwd/ \
  "<task prompt>" \
  > _workspace/quality/<ts>/01_runs/<id>/claude/transcript.json 2> stderr.log
```

`claude --help`의 정확한 옵션 형식은 `claude --help` 실측치를 따른다. 비대화형 + JSON 출력이 가능한 옵션 조합이 있으면 그걸로, 없으면 `--print`만으로 stdout 캡처.

### codex 측
```bash
codex exec --json --skip-git-repo-check \
  --sandbox workspace-write \
  -C _workspace/quality/<ts>/01_runs/<id>/codex/cwd/ \
  -m gpt-5.5 \
  "<task prompt>" \
  > _workspace/quality/<ts>/01_runs/<id>/codex/events.jsonl 2> stderr.log

# events.jsonl 파싱
python3 -c "
import json
events = [json.loads(l) for l in open('events.jsonl')]
last_msg = next((e for e in reversed(events) if e.get('item',{}).get('type')=='agent_message'), None)
usage = next((e['usage'] for e in reversed(events) if e.get('type')=='turn.completed'), None)
# stdout.txt + metrics.json 작성
"
```

## 입력 / 출력

**입력:** 오케스트레이터로부터 받는 task 명세 (input.md 형식: domain, request, files-included).

**출력:** 위 디렉토리 트리. 모든 산출물 회수 후 metrics.json 두 개를 stdout으로 한 줄 요약 보고:
```
{"task": "<id>", "claude": {...}, "codex": {...}}
```

## 에러 핸들링

- claude CLI 부재 → claude/ 디렉토리에 `unavailable.txt` 생성, codex만 실행
- 모델 호출 실패 (쿼터/네트워크) → metrics.json에 `error: "..."` 기록, 부분 stdout 보존
- 양쪽 모두 실패 → 오케스트레이터에게 즉시 fail 보고

## 협업

dual-environment-runner는 단독 모드. 결과를 output-comparator에게 파일로 인계.
