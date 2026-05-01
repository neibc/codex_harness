# codex_harness

**Agent Team & Skill Architect — Codex CLI port of [revfactory/harness](https://github.com/revfactory/harness)**

이 저장소는 **두 가지 역할**을 동시에 수행합니다:

1. **Codex 플러그인** — `codex` CLI 사용자가 설치하면 동작하는 하네스 메타-스킬
2. **Claude Code 개발 하네스** — 이 플러그인을 만들고 유지보수하는 데 사용한 메타-하네스 (`.claude/` 하위)

Claude Code 개발자는 `.claude/skills/codex-harness-orchestrator`로 빌드를 자동화하고, Codex 사용자는 루트의 `skills/` · `agents/` · `mcp-team-server/`만 사용합니다. 두 흐름은 같은 저장소를 공유합니다.

## Codex 사용자용 빠른 설치

```bash
# 1) 저장소 클론
git clone https://github.com/<your-org>/codex_harness.git
cd codex_harness

# 2) MCP 팀 에뮬레이션 서버 빌드
cd mcp-team-server && npm install && npm run build && cd ..

# 3) Codex 마켓플레이스로 등록 (실측: 0.125.0)
codex plugin marketplace add "$(pwd)"
# → ~/.codex/config.toml에 [plugins."codex-harness@codex-harness-marketplace"] 추가
# 매니페스트는 .codex-plugin/plugin.json,
# 마켓플레이스는 .agents/plugins/marketplace.json,
# 팀 MCP 서버는 .mcp.json으로 자동 등록됩니다.

# (대안) 수동 MCP 등록만 필요한 경우
codex mcp add team --env TEAM_STORAGE_PATH=$HOME/.codex/teams.sqlite \
  -- node "$(pwd)/mcp-team-server/dist/index.js"
codex mcp list  # team 항목이 보여야 함
```

> 정확한 옵션은 `codex plugin marketplace --help`, `codex mcp add --help`로 실측 확인하세요. 본 저장소가 가정하는 schema는 `_workspace/01_codex_primitives.md`에 기록되어 있습니다.

설치 후:

```bash
codex
> /harness 도메인 분석 후 하네스 구성해줘
```

또는 비대화형:

```bash
codex exec --prompt-file skills/harness/SKILL.md "도메인 분석 후 하네스 구성해줘"
```

검증:

```bash
./tests/smoke.sh
```

## Claude Code 개발자용 빠른 진입

```bash
# Claude Code에서 이 디렉토리를 열고
cd codex_harness
claude
> /codex-harness-orchestrator codex 하네스 빌드해줘
```

오케스트레이터가 4단계 파이프라인을 실행합니다:
- **Phase A (Discovery)**: Codex CLI 분석 + revfactory 인벤토리
- **Phase B (Design)**: 매핑 테이블 설계 (에이전트 팀)
- **Phase C (Build)**: 루트의 `skills/`, `agents/`, `mcp-team-server/`, `AGENTS.md`, `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`, `.mcp.json`, `hooks/`, `tests/`를 채움
- **Phase D (Validate)**: smoke 테스트 + 경계면 검증

자세한 워크플로우: [`.claude/skills/codex-harness-orchestrator/SKILL.md`](.claude/skills/codex-harness-orchestrator/SKILL.md)

## 디렉토리 구조

```
codex_harness/
├── README.md                            # 이 파일
├── LICENSE                              # Apache-2.0 (원본과 동일)
├── .gitignore
├── CLAUDE.md                            # Claude Code 진입 지침
├── AGENTS.md                            # Codex 진입 지침 (도메인 트리거 + 라우팅 표 + MCP 도구 표)
├── LIMITATIONS.md                       # Claude→Codex 변환 손실 10항목
├── .codex-plugin/
│   └── plugin.json                      # Codex 플러그인 매니페스트 (실측 schema)
├── .agents/plugins/
│   └── marketplace.json                 # Codex 마켓플레이스 매니페스트
├── .mcp.json                            # 팀 MCP 서버 자동 등록 (stdio)
├── hooks/
│   ├── hooks.json                       # SessionStart / SessionEnd hook 등록
│   ├── session-start-priming.mjs
│   └── session-end-cleanup.mjs
├── skills/                              # Codex 자동 주입 디렉토리
│   └── harness/
│       ├── SKILL.md                     # 메인 스킬 (revfactory 1.2.0의 Codex 번역)
│       └── references/                  # agent-design-patterns / orchestrator-template / team-examples / skill-writing-guide / skill-testing-guide / qa-agent-guide
├── agents/                              # 메타-하네스 자체의 5개 페르소나
│   ├── codex-internals-analyst.md
│   ├── claude-harness-cartographer.md
│   ├── primitive-translator.md
│   ├── codex-plugin-builder.md
│   └── codex-harness-qa.md
├── mcp-team-server/                     # Agent Team 에뮬레이션 MCP 서버 (TypeScript)
│   ├── package.json
│   ├── tsconfig.json
│   └── src/{index,tools,storage,types}.ts
├── tests/
│   └── smoke.sh                         # 7-step 검증 시퀀스
├── .claude/                             # ── Claude Code 개발 하네스 (Codex 무시) ──
│   ├── agents/                          #    5개 에이전트 정의
│   └── skills/                          #    5개 스킬 (오케스트레이터 + 4 지식베이스)
└── _workspace/                          # 중간 산출물 (gitignored)
```

> 사용자가 자기 도메인용 새 에이전트를 만들 때는 본 플러그인의 `agents/`에 동봉된 5개 페르소나를 덮어쓰지 않고 자기 cwd의 `agents/` 또는 `~/.codex/agents/`에 새로 작성합니다. AGENTS.md의 라우팅 표에 새 항목을 추가하면 됩니다.

## 무엇을 옮겼고 무엇이 손실되는가

| Claude Code 원본 | Codex 포트 |
|---|---|
| Skill 자동 트리거 | `<skills_instructions>` 자동 주입 + 슬래시 트리거 + `codex exec --prompt-file` |
| `Agent` 도구 (`subagent_type=Explore/Plan/general-purpose`) | `codex exec --json --ephemeral -C <iso-dir> --prompt-file agents/<name>.md`. Explore는 `-s read-only`. |
| `TeamCreate` / `SendMessage` / `recv_messages` / `TaskCreate` 등 | MCP 팀 서버 (`mcp-team-server/`)의 8개 도구 |
| `CLAUDE.md` | `AGENTS.md` (cwd 1개만 자동 로드 — upward search 없음) |
| `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json` (JSON, schema는 `interface` 객체 등 차이) |
| `.claude-plugin/marketplace.json` | `.agents/plugins/marketplace.json` (`policy.installation`/`policy.authentication` 추가) |
| settings.json hooks (PreToolUse/PostToolUse 등) | `hooks/hooks.json` (SessionStart/SessionEnd만 실측 — 나머지 Unknown) |
| settings.json permissions | `--sandbox` 모드 + `~/.codex/rules/default.rules` |

Known limitations (메시지 전달이 폴링 기반, 자동 컨텍스트 압축 정책 차이, WebFetch/WebSearch는 별도 MCP 서버 필요, 일부 hook 이벤트 Unknown 등) 10개 항목은 [`LIMITATIONS.md`](LIMITATIONS.md)에 정리되어 있습니다. 변환 결정의 근거는 [`.claude/skills/claude-codex-translation/references/lossy-conversions.md`](.claude/skills/claude-codex-translation/references/lossy-conversions.md).

## 라이선스

Apache-2.0 — 원본 [`revfactory/harness`](https://github.com/revfactory/harness) 라이선스를 그대로 따릅니다.

## 기여

- 버그/한계 발견 시 이슈로 보고
- Codex 새 버전 출시 시 `_workspace/01_codex_primitives.md`를 갱신하고 매핑 테이블 회귀
- 회귀 절차: [`.claude/skills/codex-harness-orchestrator/references/regression-protocol.md`](.claude/skills/codex-harness-orchestrator/references/regression-protocol.md)
