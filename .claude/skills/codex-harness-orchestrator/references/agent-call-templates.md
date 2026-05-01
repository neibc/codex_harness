# Agent / Team 호출 템플릿

오케스트레이터가 각 phase에서 사용할 정확한 도구 호출 형태.

## Phase A — 병렬 서브 에이전트

```
# 두 호출을 같은 메시지에서 병렬 실행
Agent({
  description: "Codex CLI 분석",
  subagent_type: "general-purpose",
  model: "opus",
  prompt: """
  너의 역할은 .claude/agents/codex-internals-analyst.md에 정의되어 있다. 그 파일을 먼저 읽고 행동 원칙을 내재화한 뒤 작업하라.

  작업: codex CLI 0.125.0(또는 현재 설치된 버전)을 분석하여 _workspace/01_codex_primitives.md 생성.
  - 사용 가능 도구: Bash, Read, Glob, Grep, WebFetch, Write
  - 참조 스킬: .claude/skills/codex-internals-map/ (analyst-checklist.md를 따를 것)
  - 출력 위치: _workspace/01_codex_primitives.md

  완료 후 출력 파일 경로 한 줄만 회신.
  """,
  run_in_background: true
})

Agent({
  description: "revfactory harness 인벤토리",
  subagent_type: "general-purpose",
  model: "opus",
  prompt: """
  너의 역할은 .claude/agents/claude-harness-cartographer.md에 정의되어 있다. 먼저 읽고 작업하라.

  작업: /Users/neibc/.claude/plugins/cache/harness-marketplace/harness/1.2.0/ 전수 조사.
  - 출력: _workspace/02_claude_primitives.md
  - 사용 도구: Read, Glob, Grep, Bash, Write

  완료 후 출력 파일 경로 한 줄만 회신.
  """,
  run_in_background: true
})
```

## Phase B — 에이전트 팀 (Design)

```
TeamCreate({
  team_name: "design-team",
  members: ["primitive-translator", "codex-internals-analyst", "claude-harness-cartographer"]
})

TaskCreate({
  subject: "Build translation table",
  description: "_workspace/03_translation_table.md 작성. claude-codex-translation, codex-internals-map, team-emulation-mcp 스킬을 참조.",
  owner: "primitive-translator"
})

# primitive-translator 호출 시 prompt에 다음을 포함:
# "팀 멤버 codex-internals-analyst, claude-harness-cartographer에게 SendMessage로 모호점 질의 가능."
```

팀 정리:
```
TeamDelete({ team_name: "design-team" })
```

## Phase C — 에이전트 팀 (Build)

```
TeamCreate({
  team_name: "build-team",
  members: ["codex-plugin-builder", "primitive-translator"]
})

TaskCreate({
  subject: "Populate Codex plugin tree at project root",
  description: "_workspace/03_translation_table.md를 명세로 사용하여 프로젝트 루트의 prompts/, agents/, mcp-team-server/, tests/, AGENTS.md, plugin.toml, LIMITATIONS.md를 채움 (placeholder 덮어쓰기). 빌드 로그를 _workspace/04_build_log.md에.",
  owner: "codex-plugin-builder"
})
```

빌더에게 보낼 prompt 핵심:
```
참조 스킬: codex-plugin-packaging, team-emulation-mcp, claude-codex-translation
주의: README에 Known limitations 섹션 필수. 매핑 거절된 항목은 명시.
모호점 발견 시 SendMessage로 primitive-translator에게 즉시 질의.
```

## Phase D — 단일 서브 에이전트

```
Agent({
  description: "Codex 하네스 QA",
  subagent_type: "general-purpose",   # Explore 절대 금지 (Bash 필요)
  model: "opus",
  prompt: """
  너의 역할은 .claude/agents/codex-harness-qa.md에 정의. 먼저 읽고 작업하라.

  작업: 프로젝트 루트의 README.md 설치 절차로 codex plugin install . 까지 실행한 뒤 _workspace/05_qa_report.md 작성.
  특히 경계면 검증(MCP↔prompt↔파일 IPC)에 집중.
  - tests/smoke.sh 실행
  - codex exec --prompt-file prompts/harness.md 시험
  - 발견 버그는 책임 소재(번역 테이블 vs 빌더 vs Codex 한계) 분류

  완료 후 보고서 경로 + 블로킹/비블로킹 결론 한 줄 회신.
  """
})
```
