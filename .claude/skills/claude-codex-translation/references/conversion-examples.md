# Conversion Examples — Before / After

실제 변환 예시. Claude 코드 좌측, Codex 우측.

## 예시 1 — 슬래시 커맨드 트리거

**Before (Claude Code SKILL.md 일부):**
```markdown
사용자가 `/harness` 입력 시 이 스킬을 호출하라.
```

**After (Codex prompt):**
```markdown
**트리거:**
- 인터랙티브: `codex` 진입 후 `/harness` (Codex 슬래시 트리거 지원 시)
- 비대화형: `codex exec --prompt-file prompts/harness.md "<요청내용>"`
```

## 예시 2 — Agent 도구 호출

**Before (Claude Code orchestrator):**
```
Agent({
  description: "Codex 분석",
  subagent_type: "general-purpose",
  prompt: "Codex CLI를 분석하여 _workspace/01_codex_primitives.md를 생성"
})
```

**After (Codex prompt):**
````markdown
다음 명령으로 분석 에이전트를 호출한다:

```bash
codex exec \
  --prompt-file agents/codex-internals-analyst.md \
  --working-dir _workspace/agent-internals-analyst/ \
  "Codex CLI를 분석하여 _workspace/01_codex_primitives.md를 생성"
```

완료 후 `_workspace/01_codex_primitives.md` 존재를 확인.
````

## 예시 3 — TeamCreate / SendMessage

**Before:**
```
TeamCreate({
  team_name: "design-team",
  members: ["primitive-translator", "claude-harness-cartographer"]
})

SendMessage({ to: "primitive-translator", content: "테이블 초안 검토 부탁" })
```

**After (Codex prompt + MCP 팀 서버 도구 호출):**
```markdown
MCP 팀 서버의 도구를 다음 순서로 호출한다:

1. `team_create({ team_name: "design-team", members: ["primitive-translator", "claude-harness-cartographer"] })`
2. 팀원 prompt 호출 시 `--mcp-tool team_send_message` 사용 가능 상태 보장
3. 메시지 전송: `send_message({ team_name: "design-team", to: "primitive-translator", content: "..." })`
4. 메시지 수신: `recv_messages({ team_name: "design-team", as: "primitive-translator", since: <timestamp> })`

> Codex prompt는 동기 응답이 아니므로, 송신자는 `recv_messages` 폴링을 명시적으로 수행해야 함.
```

## 예시 4 — CLAUDE.md → AGENTS.md

**Before (CLAUDE.md):**
```markdown
## 하네스: codex-harness
**트리거:** codex 포팅 작업 시 `codex-harness-orchestrator` 스킬을 사용하라.
```

**After (AGENTS.md):**
```markdown
## 하네스: codex-harness
**트리거:** codex 포팅 작업 시 다음 중 하나 사용:
- `codex` 진입 후 `/codex-harness-orchestrator`
- `codex exec --prompt-file prompts/codex-harness-orchestrator.md "<요청>"`
```

## 예시 5 — 빌트인 subagent_type=Explore

**Before:**
```
Agent({ subagent_type: "Explore", prompt: "코드베이스에서 X 정의 위치 찾기" })
```

**After:**
```markdown
다음 명령으로 읽기 전용 분석을 수행한다:

```bash
codex exec \
  --prompt-file agents/read-only-explorer.md \
  --sandbox readonly \
  "코드베이스에서 X 정의 위치 찾기"
```

> `agents/read-only-explorer.md`에 "수정 도구를 호출하지 말 것" 지시 명시. `--sandbox readonly`로 Codex가 쓰기 도구를 차단.
```
