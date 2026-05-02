# codex_harness

**Agent Team & Skill Architect — Codex CLI port of [revfactory/harness](https://github.com/revfactory/harness)**

이 저장소는 **두 가지 역할**을 동시에 수행합니다:

1. **Codex 플러그인** — `codex` CLI 사용자가 설치하면 동작하는 하네스 메타-스킬
2. **Claude Code 개발 하네스** — 이 플러그인을 만들고 유지보수하는 데 사용한 메타-하네스 (`.claude/` 하위)

Claude Code 개발자는 `.claude/skills/codex-harness-orchestrator`로 빌드를 자동화하고, Codex 사용자는 루트의 `skills/` · `agents/` · `mcp-team-server/`만 사용합니다. 두 흐름은 같은 저장소를 공유합니다.

---

## 개요 — 이 플러그인이 어떻게 작동하는가

### 1. 풀고 싶은 문제

[`revfactory/harness`](https://github.com/revfactory/harness)는 Claude Code에서 **도메인을 입력하면 그 도메인에 맞는 전문 에이전트 팀과 스킬을 자동으로 설계·생성하는 메타-스킬**입니다. 하지만 이 플러그인은 Claude Code의 1차 primitive에 강하게 의존합니다 — 특히 `Agent` 도구로 서브 에이전트를 띄우고, `TeamCreate`/`SendMessage`/`TaskCreate`로 에이전트들이 서로 메시지·작업 큐를 공유하면서 협업하는 구조입니다.

OpenAI Codex CLI는 같은 영역(에이전틱 코딩 CLI)에 있지만 **명시적으로 Agent Team을 선언하는 1차 primitive가 없습니다**. Codex 0.125.0 실측 결과:

- `feature.multi_agent=stable&true` 플래그는 존재하나 사용자가 호출 가능한 표면이 미발견
- `Agent` 도구 등가물은 **`codex exec --json --ephemeral -C <iso-dir>` 서브프로세스**가 가장 가까움
- `TeamCreate`/`SendMessage` 등에 1:1 대응하는 도구 없음

revfactory 원본 SKILL.md와 references 본문은 이 1차 primitive를 **총 85회** 호출합니다 (`SendMessage` 35회, `Agent` 28회, `TeamCreate` 19회, `TaskCreate` 16회). 단순 텍스트 번역만으로는 동작하지 않습니다.

### 2. 핵심 원리 — "MCP 팀 서버로 Agent Team을 에뮬레이션"

본 플러그인은 Codex의 **MCP(Model Context Protocol) 클라이언트 지원**을 활용해, 외부 stdio MCP 서버를 하나 띄워서 Agent Team의 8가지 도구를 직접 구현합니다. Codex는 이 도구들을 일반 도구처럼 호출하고, 뒤에서 SQLite(WAL 모드)가 메시지·작업 상태를 영속화합니다.

```
[Codex 세션 1: 오케스트레이터]
[Codex 세션 2: 에이전트 A]      ─┐
[Codex 세션 3: 에이전트 B]      ─┼─→ 같은 stdio MCP 서버 (mcp-team-server)
[Codex 세션 4: 에이전트 C]      ─┘        ↓
                                    ~/.codex/teams.sqlite
                                    (messages/tasks/teams 테이블, WAL)
```

세션 간 통신은 다음 방식으로 일어납니다:

- **송신**: 에이전트가 `send_message({to: "agent-B", content: "..."})` 도구를 호출 → MCP 서버가 sqlite에 append
- **수신**: 수신자는 매 turn `recv_messages({as: "agent-B", since: <last_seen>})`를 폴링
- **작업 큐**: `task_create`/`task_update`/`task_list`가 같은 sqlite 테이블에서 동기화

이 패턴이 Claude Code의 in-process Agent Team과 다른 점은 **수신이 push가 아닌 polling**이라는 것입니다. 그 대가로 다중 머신/다중 세션 협업이 가능하고, 같은 MCP 서버를 Claude Code도 등록해서 **Claude ↔ Codex 혼합 팀**도 이론상 가능합니다.

### 3. 5개 계층

```
┌─────────────────────────────────────────────────────────────┐
│ ① Manifests   .codex-plugin/plugin.json                     │
│               .agents/plugins/marketplace.json              │
│               .mcp.json                                     │
│  → Codex가 부팅 시 이 파일들을 읽고 플러그인을 자동 등록    │
├─────────────────────────────────────────────────────────────┤
│ ② Skills      skills/harness/SKILL.md (메인)                │
│               skills/harness/references/×6                  │
│  → Codex가 매 세션 시작 시 SKILL.md를 자동 주입             │
│  → 7-Phase 워크플로우(도메인 분석→팀 설계→스킬 생성→검증)   │
├─────────────────────────────────────────────────────────────┤
│ ③ Agents      agents/×5 페르소나                            │
│  → SKILL.md가 codex exec --prompt-file agents/X.md 로 호출  │
│  → 각 에이전트는 독립 컨텍스트(서브프로세스)로 격리         │
├─────────────────────────────────────────────────────────────┤
│ ④ MCP Team    mcp-team-server/ (TypeScript + SQLite)        │
│   Server      8개 도구: team_create, send_message,          │
│               recv_messages, task_create, task_update,      │
│               task_list, task_get_output, team_destroy      │
│  → Agent Team의 1차 primitive를 외부 도구로 에뮬레이션      │
├─────────────────────────────────────────────────────────────┤
│ ⑤ Hooks       hooks/hooks.json (SessionStart/SessionEnd)    │
│               hooks/session-start-priming.mjs               │
│               hooks/session-end-cleanup.mjs                 │
│  → 세션 부팅 시 컨텍스트 프라이밍, 종료 시 sqlite 정리      │
└─────────────────────────────────────────────────────────────┘
```

### 4. 사용자 발화부터 산출까지의 데이터 흐름

```
사용자: "전자상거래 도메인용 하네스 구성해줘"
   ↓
Codex 세션 시작 → AGENTS.md 자동 로드 → SKILL.md 자동 주입 (skills_instructions)
   ↓
SKILL.md의 7-Phase 워크플로우 진입
   ↓
Phase 0: 컨텍스트 확인 (기존 산출물? 부분 재실행?)
   ↓
Phase 1: 도메인 분석 (사용자와 대화 + 코드베이스 탐색)
   ↓
Phase 2: 팀 아키텍처 설계
   ↓
Phase 3-4: 에이전트 팀 + 스킬 생성  ──┐
                                       ├─→ MCP team_create / send_message / task_*
   ↓                                   │   (협업이 필요한 단계에서 외부 도구 호출)
Phase 5: 오케스트레이터 통합          ──┘
   ↓
Phase 6: 검증 (smoke.sh 등)
   ↓
Phase 7: 진화 (피드백 루프, CLAUDE.md/AGENTS.md 변경 이력 갱신)
   ↓
산출물: 사용자 프로젝트의 .codex/ 또는 ~/.codex/ 에 새 에이전트/스킬 작성
```

### 5. 손실은 명시적이다 — `LIMITATIONS.md`

Codex의 1차 primitive 부재로 인해 **완전 무손실 포팅은 불가능**합니다. 본 플러그인은 손실을 숨기지 않고 [`LIMITATIONS.md`](LIMITATIONS.md)에 10개 항목을 명시합니다 — 예: 동기 메시지 도착 통지 손실(폴링 우회), `subagent_type=Explore/Plan` 카테고리 부재(`-s read-only` + 프롬프트 지시문 우회), `WebFetch`/`WebSearch` 빌트인 부재(외부 MCP 서버 권장), `PreToolUse`/`PostToolUse` 등 hook 이벤트는 실측 미확인.

### 6. 듀얼 네이처 — 한 저장소가 두 환경에 동시에 동작

같은 저장소가 두 가지로 동시에 작동합니다:

- **Codex 환경**: 루트의 `skills/`, `agents/`, `mcp-team-server/`, `AGENTS.md`, `.codex-plugin/`, `.agents/`, `.mcp.json`, `hooks/`만 사용. `.claude/` 디렉토리는 무시됨(Codex가 모르는 경로).
- **Claude Code 환경**: `.claude/skills/codex-harness-orchestrator`가 4-Phase 빌드 파이프라인을 실행해 위 Codex 측 파일들을 자동 생성·갱신. 즉 **이 저장소 자체가 자기 자신을 빌드하는 self-hosting 메타-하네스**.

이로써 Codex CLI가 새 버전을 내면 Claude Code 측에서 오케스트레이터를 다시 돌려 매핑 테이블(`_workspace/03_translation_table.md`)을 회귀 검증하고, 변경분만 Codex 측 파일에 반영할 수 있습니다.

---

## Overview — How this plugin works

### 1. The problem

[`revfactory/harness`](https://github.com/revfactory/harness) is a Claude Code meta-skill: **give it a domain and it auto-designs and generates a specialist agent team and the skills they need**. But it leans heavily on Claude Code's first-class primitives — `Agent` to spawn sub-agents, and `TeamCreate` / `SendMessage` / `TaskCreate` so that those agents share a message bus and a task queue while collaborating.

OpenAI Codex CLI is in the same space (agentic coding CLI) but **has no first-class primitive for declaring an explicit Agent Team**. From Codex 0.125.0 inspection:

- The `feature.multi_agent=stable&true` flag exists, but no user-callable surface was discovered.
- The closest equivalent of the `Agent` tool is the **`codex exec --json --ephemeral -C <iso-dir>` subprocess**.
- There is no 1:1 counterpart to `TeamCreate` / `SendMessage` and friends.

The original SKILL.md and references in revfactory's plugin invoke these primitives **85 times in total** (`SendMessage` ×35, `Agent` ×28, `TeamCreate` ×19, `TaskCreate` ×16). A textual translation alone won't run.

### 2. Core idea — emulate Agent Team via an MCP server

This plugin leans on Codex's **MCP (Model Context Protocol) client support**: it ships a single external stdio MCP server that implements eight Agent-Team-equivalent tools directly. Codex calls them like ordinary tools, and behind the scenes a SQLite database (WAL mode) persists the messages and task state.

```
[Codex session 1: orchestrator]
[Codex session 2: agent A]    ─┐
[Codex session 3: agent B]    ─┼─→ same stdio MCP server (mcp-team-server)
[Codex session 4: agent C]    ─┘             ↓
                                       ~/.codex/teams.sqlite
                                       (messages / tasks / teams tables, WAL)
```

Inter-session communication works like this:

- **Send**: an agent calls `send_message({to: "agent-B", content: "..."})` and the MCP server appends a row in SQLite.
- **Receive**: the receiver polls `recv_messages({as: "agent-B", since: <last_seen>})` every turn.
- **Task queue**: `task_create` / `task_update` / `task_list` synchronize on the same SQLite tables.

The trade-off versus Claude Code's in-process Agent Team is that **delivery is polling rather than push** — but you gain multi-machine / multi-session collaboration, and in principle Claude Code can register the same MCP server, enabling **mixed Claude ↔ Codex teams**.

### 3. Five layers

```
┌─────────────────────────────────────────────────────────────┐
│ ① Manifests   .codex-plugin/plugin.json                     │
│               .agents/plugins/marketplace.json              │
│               .mcp.json                                     │
│  → Codex reads these at boot to auto-register the plugin.   │
├─────────────────────────────────────────────────────────────┤
│ ② Skills      skills/harness/SKILL.md (main)                │
│               skills/harness/references/×6                  │
│  → Codex auto-injects SKILL.md every session.               │
│  → 7-Phase workflow (analyze → design → build → validate).  │
├─────────────────────────────────────────────────────────────┤
│ ③ Agents      agents/×5 personas                            │
│  → SKILL.md invokes them via                                │
│    `codex exec --prompt-file agents/X.md`.                  │
│  → Each agent runs in its own isolated subprocess context.  │
├─────────────────────────────────────────────────────────────┤
│ ④ MCP Team    mcp-team-server/ (TypeScript + SQLite)        │
│   Server      8 tools: team_create, send_message,           │
│               recv_messages, task_create, task_update,      │
│               task_list, task_get_output, team_destroy.     │
│  → Emulates the Agent Team primitives as external tools.    │
├─────────────────────────────────────────────────────────────┤
│ ⑤ Hooks       hooks/hooks.json (SessionStart/SessionEnd)    │
│               hooks/session-start-priming.mjs               │
│               hooks/session-end-cleanup.mjs                 │
│  → Prime context on boot, clean up SQLite on exit.          │
└─────────────────────────────────────────────────────────────┘
```

### 4. Data flow — from user prompt to artifact

```
User: "Build a harness for an e-commerce domain"
   ↓
Codex session starts → AGENTS.md auto-loaded → SKILL.md auto-injected
   ↓
Enter 7-Phase workflow defined in SKILL.md
   ↓
Phase 0: Context check (existing artifacts? partial re-run?)
   ↓
Phase 1: Domain analysis (dialogue + codebase exploration)
   ↓
Phase 2: Team architecture design
   ↓
Phase 3-4: Generate agents and skills  ──┐
                                          ├─→ MCP team_create / send_message / task_*
   ↓                                      │   (called whenever collaboration is needed)
Phase 5: Orchestrator wiring             ──┘
   ↓
Phase 6: Validation (smoke.sh and friends)
   ↓
Phase 7: Evolution (feedback loop, CLAUDE.md/AGENTS.md changelog updates)
   ↓
Output: new agent/skill files written under the user's project
        .codex/ directory or ~/.codex/.
```

### 5. Losses are explicit — see `LIMITATIONS.md`

Because of the missing first-class primitives in Codex, **a fully lossless port is impossible**. This plugin does not hide the loss — it documents ten items in [`LIMITATIONS.md`](LIMITATIONS.md). Examples: synchronous arrival notification is lost (replaced by polling); `subagent_type=Explore/Plan` categories are absent (replaced with `-s read-only` plus prompt directives); `WebFetch` and `WebSearch` are not built-in (use external MCP servers); `PreToolUse` / `PostToolUse` hook events are not yet empirically confirmed in 0.125.0.

### 6. Dual nature — one repository, two runtimes

The same repository operates simultaneously in two environments:

- **In Codex**: only the root-level `skills/`, `agents/`, `mcp-team-server/`, `AGENTS.md`, `.codex-plugin/`, `.agents/`, `.mcp.json`, and `hooks/` are used. The `.claude/` directory is invisible to Codex.
- **In Claude Code**: `.claude/skills/codex-harness-orchestrator` runs a 4-phase build pipeline that auto-generates and refreshes the Codex-side files above. In other words, **this repository is a self-hosting meta-harness that builds itself**.

This makes regression cheap: when a new Codex CLI version ships, run the orchestrator in Claude Code, regenerate the mapping table at `_workspace/03_translation_table.md`, and patch only the diffs into the Codex-side files.

---

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
