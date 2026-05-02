# codex_harness

> **Agent Team & Skill Architect for OpenAI Codex CLI** — a port of [`revfactory/harness`](https://github.com/revfactory/harness) (Claude Code) to Codex, with the missing multi-agent primitives emulated through a small MCP server.
>
> **OpenAI Codex CLI를 위한 에이전트 팀 & 스킬 아키텍트** — [`revfactory/harness`](https://github.com/revfactory/harness) (Claude Code 플러그인)를 Codex로 포팅하면서, Codex에 없는 멀티-에이전트 1차 primitive를 작은 MCP 서버로 에뮬레이션한 결과물.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Codex CLI](https://img.shields.io/badge/Codex_CLI-0.125.0%2B-black)](https://github.com/openai/codex)
[![Status: beta](https://img.shields.io/badge/status-beta-orange)](#known-limitations--limitations)

---

## 한 줄 요약 / TL;DR

**KR**: `codex` 한 줄로 "이 프로젝트의 도메인에 맞는 에이전트 팀과 스킬 자동으로 만들어줘" 가능. Claude Code 사용자가 익숙한 `harness` 메타-스킬을, Codex CLI에서도 동일한 사용 경험으로 제공합니다.

**EN**: One `codex` invocation can ask "design and generate the right agent team and skills for this project's domain" — bringing the `harness` meta-skill that Claude Code users know to OpenAI Codex CLI with the same UX.

```bash
$ codex
> /harness 전자상거래 백엔드용 하네스 구성해줘
# → 도메인 분석 → 팀 설계 → 에이전트/스킬 자동 생성 → 검증
```

---

## 누구를 위한 프로젝트인가 / Who is this for

**KR**

| 당신은… | 이 프로젝트가 주는 것 |
|---|---|
| Codex CLI를 쓰는 개발자 | `/harness` 슬래시 커맨드로 도메인 특화 에이전트 팀·스킬을 자동 생성 |
| `revfactory/harness`를 Claude Code에서 잘 쓰던 사람 | 같은 사용 경험을 Codex로 그대로 |
| 멀티-에이전트 협업을 Codex에서 시도하려던 사람 | MCP 기반 팀 통신 인프라(8개 도구) 즉시 사용 가능 |
| Codex CLI 플러그인 개발자 | 매니페스트 schema, hooks, MCP 등록 패턴의 실측 레퍼런스 |

**EN**

| If you are… | What this project gives you |
|---|---|
| A Codex CLI user | A `/harness` slash command that auto-designs domain-specific agent teams & skills |
| A `revfactory/harness` user moving to Codex | The same UX, on the new runtime |
| Anyone wanting multi-agent collaboration in Codex | A ready-to-register MCP team server with 8 tools |
| A Codex CLI plugin author | A working reference for manifest schema, hooks, and MCP registration |

---

## 설치 (Codex 사용자) / Install for Codex users

### 사전 준비 / Prerequisites

```bash
codex --version       # 0.125.0 이상이면 OK
node --version        # v18 이상 권장
```

### 단계별 설치 / Step-by-step

> **중요 / Important**: Codex 0.125.0의 실측 결과는 다음과 같습니다.
> - `codex plugin marketplace add`는 마켓 메타데이터만 등록할 뿐 스킬을 활성화하지 않습니다 (CLI에 `codex plugin install` 명령 없음, 플러그인-스코프 MCP는 `codex mcp list`에 보이지 않음).
> - **스킬은 `~/.codex/skills/<name>/SKILL.md`에 파일이 있어야 활성화**됩니다 (이 위치를 Codex가 자동 스캔하여 `<skills>` 블록에 등록).
> - **MCP 서버는 `codex mcp add`로 등록**해야 모든 세션에서 사용 가능합니다.
>
> 따라서 안정적인 설치는 (a) MCP 서버 등록 + (b) 스킬을 `~/.codex/skills/`에 심볼릭 링크하는 두 단계입니다. 본 머신에서 검증 완료.
>
> Empirical findings on Codex 0.125.0:
> - `codex plugin marketplace add` only registers marketplace metadata; it does not activate skills (there is no `codex plugin install` CLI, and plugin-scoped MCP servers do not appear in `codex mcp list`).
> - **A skill is activated when its `SKILL.md` lives at `~/.codex/skills/<name>/SKILL.md`** — Codex auto-scans this directory and registers the skill in its `<skills>` block.
> - **MCP servers must be registered with `codex mcp add`** to be available in every session.
>
> So the reliable install is two steps: (a) register the MCP server, and (b) symlink the skill into `~/.codex/skills/`. Verified live on the dev machine.

**KR**

```bash
# 1) 저장소 클론
git clone https://github.com/neibc/codex_harness.git
cd codex_harness

# 2) MCP 팀 에뮬레이션 서버 빌드
#    (Claude Code의 TeamCreate/SendMessage/TaskCreate 대체)
cd mcp-team-server
npm install
npm run build
cd ..

# 3) [필수] MCP 팀 서버를 Codex에 직접 등록
#    (codex mcp list에 즉시 보이고, 모든 codex 세션에서 사용 가능)
codex mcp add team \
  --env TEAM_STORAGE_PATH=$HOME/.codex/teams.sqlite \
  -- node "$(pwd)/mcp-team-server/dist/index.js"
codex mcp list        # Status: enabled 으로 team 표시되어야 함

# 4) [필수] harness 스킬을 ~/.codex/skills/ 에 활성화 (심볼릭 링크 권장)
#    심링크는 이 저장소의 스킬 변경이 즉시 반영되어 개발/사용에 모두 편함.
mkdir -p ~/.codex/skills
ln -sfn "$(pwd)/skills/harness" ~/.codex/skills/harness
ls ~/.codex/skills/    # harness 항목이 표시되어야 함

# 5) [옵션] 마켓플레이스 메타데이터 등록 (현재 0.125.0에서는 비활성)
#    향후 codex plugin install CLI가 추가되면 활용 가능. 현 단계에서는
#    스킬 활성화에는 영향 없음.
codex plugin marketplace add "$(pwd)"

# 6) 설치 검증
./tests/smoke.sh                                    # PASS=37 FAIL=0 OK
codex debug prompt-input "test" 2>/dev/null \
  | grep -o 'harness:[^"]*' | head -1               # harness:harness ... 출력되면 활성화 성공
```

**EN**

```bash
# 1) Clone
git clone https://github.com/neibc/codex_harness.git
cd codex_harness

# 2) Build the MCP team-emulation server
#    (replaces Claude Code's TeamCreate/SendMessage/TaskCreate primitives)
cd mcp-team-server
npm install
npm run build
cd ..

# 3) [Required] Register the MCP team server with Codex directly
#    (Visible in `codex mcp list` immediately and usable from every session.)
codex mcp add team \
  --env TEAM_STORAGE_PATH=$HOME/.codex/teams.sqlite \
  -- node "$(pwd)/mcp-team-server/dist/index.js"
codex mcp list        # the "team" entry should show Status: enabled

# 4) [Required] Activate the harness skill into ~/.codex/skills/ (symlink recommended)
#    A symlink lets edits to the repo flow through immediately, which is handy
#    for both running and developing the harness.
mkdir -p ~/.codex/skills
ln -sfn "$(pwd)/skills/harness" ~/.codex/skills/harness
ls ~/.codex/skills/    # the "harness" entry should appear

# 5) [Optional] Register the marketplace metadata (currently inactive in 0.125.0)
#    Useful once a `codex plugin install` CLI exists. Has no effect on
#    skill activation today.
codex plugin marketplace add "$(pwd)"

# 6) Verify
./tests/smoke.sh                                    # PASS=37 FAIL=0 OK
codex debug prompt-input "test" 2>/dev/null \
  | grep -o 'harness:[^"]*' | head -1               # prints harness:harness ... when active
```

### 트러블슈팅 / Troubleshooting

**KR**

- **`codex` 진입 후 `/harness`(또는 `harness:harness`)가 안 보임**
  - 가장 흔한 원인: `~/.codex/skills/harness` 심링크 누락 (위 단계 4). Codex는 이 디렉토리를 스캔해서만 스킬을 등록합니다.
  - 해결: `mkdir -p ~/.codex/skills && ln -sfn "$(pwd)/skills/harness" ~/.codex/skills/harness`
  - 검증: `codex debug prompt-input "x" 2>/dev/null | grep -o 'harness:[^"]*' | head -1` — `harness:harness` 가 출력되면 활성화됨.
  - 비대화형으로도 사용 가능 (스킬 활성화 없이): `codex exec --prompt-file skills/harness/SKILL.md "<요청>"`.

- **`codex mcp list`가 비어 있음** (`No MCP servers configured yet.`)
  - 위 단계 3의 `codex mcp add team ...` 누락. 등록 후 즉시 `Status: enabled`로 표시됩니다.
  - 플러그인 시스템(`codex plugin marketplace add`)으로 등록한 MCP 서버는 `codex mcp list`에 보이지 않습니다 — 0.125.0의 알려진 동작.

- **`mcp-team-server/dist/index.js` 없음** (smoke의 [5]에서 WARN)
  - 빌드 단계 누락. `cd mcp-team-server && npm install && npm run build` 재실행.

- **`codex plugin marketplace add` 실패**
  - 경로에 공백이 있거나 `marketplace.json` 파싱 에러. `jq < .agents/plugins/marketplace.json` 으로 유효성 확인.

- **심링크 대신 복사를 쓰고 싶다**
  - `cp -R "$(pwd)/skills/harness" ~/.codex/skills/harness` — 다만 저장소 변경이 자동 반영되지 않으니 git pull 후 재복사 필요.

**EN**

- **`/harness` (or `harness:harness`) does not appear in `codex`**
  - Most common cause: missing `~/.codex/skills/harness` symlink (step 4 above). Codex scans only this directory to register skills.
  - Fix: `mkdir -p ~/.codex/skills && ln -sfn "$(pwd)/skills/harness" ~/.codex/skills/harness`
  - Verify: `codex debug prompt-input "x" 2>/dev/null | grep -o 'harness:[^"]*' | head -1` — when active, this prints `harness:harness` ...
  - Non-interactive use does not require activation: `codex exec --prompt-file skills/harness/SKILL.md "<request>"`.

- **`codex mcp list` is empty** (`No MCP servers configured yet.`)
  - You skipped step 3 (`codex mcp add team ...`). Once you run it, the team server shows up as `Status: enabled` immediately.
  - MCP servers registered via the plugin system (`codex plugin marketplace add`) do not appear in `codex mcp list` in 0.125.0 — known behavior.

- **`mcp-team-server/dist/index.js` missing** (smoke step [5] warns)
  - You skipped the build step. Run `cd mcp-team-server && npm install && npm run build`.

- **`codex plugin marketplace add` fails**
  - The path contains spaces, or `marketplace.json` failed to parse. Validate with `jq < .agents/plugins/marketplace.json`.

- **You prefer copying the skill instead of symlinking**
  - `cp -R "$(pwd)/skills/harness" ~/.codex/skills/harness` — but you will need to re-copy after each `git pull`.

---

## 첫 사용 / First run

### 인터랙티브 / Interactive

```bash
$ codex
> /harness 전자상거래 백엔드용 하네스 구성해줘
```

또는 영어로:

```bash
$ codex
> /harness build a harness for an e-commerce backend domain
```

`harness` 스킬이 자동으로 활성화되어 7-Phase 워크플로우를 시작합니다 (도메인 분석 → 팀 아키텍처 설계 → 에이전트 정의 생성 → 스킬 생성 → 통합/오케스트레이션 → 검증/테스트 → 진화). 산출물은 사용자가 작업 중인 프로젝트의 `agents/`, `skills/` 디렉토리에 자동 작성됩니다.

### 비대화형 / Non-interactive

```bash
codex exec --prompt-file skills/harness/SKILL.md "도메인: ML 데이터 파이프라인. 팀 구성해줘"
```

### 빠른 검증 / Sanity check

```bash
./tests/smoke.sh
```

총 7단계, 37개 어설션을 검사합니다 (매니페스트 파싱, 디렉토리 구조, MCP 도구 등록 확인 등).

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
Phase 7: 진화 (피드백 루프, AGENTS.md 변경 이력 갱신)
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
Phase 7: Evolution (feedback loop, AGENTS.md changelog updates)
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

## 디렉토리 구조 / Directory layout

```
codex_harness/
├── README.md                            # 이 파일 / this file
├── LICENSE                              # Apache-2.0 (원본과 동일 / same as upstream)
├── CONTRIBUTING.md                      # 기여 가이드 / contribution guide
├── SECURITY.md                          # 취약점 신고 정책 / security policy
├── CLAUDE.md                            # Claude Code 진입 지침 (Codex 무시)
├── AGENTS.md                            # Codex 진입 지침 (트리거+라우팅+MCP 도구표)
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
├── skills/                              # Codex가 자동 로드하는 스킬 트리
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
│   └── smoke.sh                         # 7-step 검증 시퀀스 (37 assertions)
├── .claude/                             # ── Claude Code 개발 하네스 (Codex 무시) ──
│   ├── agents/                          #    5개 에이전트 정의
│   └── skills/                          #    5개 스킬 (오케스트레이터 + 4 지식베이스)
└── _workspace/                          # 중간 산출물 (gitignored)
```

> **KR**: 사용자가 자기 도메인용 새 에이전트를 만들 때는 본 플러그인의 `agents/`에 동봉된 5개 페르소나를 덮어쓰지 않고 자기 cwd의 `agents/` 또는 `~/.codex/agents/`에 새로 작성합니다. AGENTS.md의 라우팅 표에 새 항목을 추가하면 됩니다.
>
> **EN**: When you author your own domain-specific agents, do not overwrite the bundled five personas in `agents/`. Add new files in your project's `agents/` (or `~/.codex/agents/`) and append a row to the routing table in your `AGENTS.md`.

---

## 무엇을 옮겼고 무엇이 손실되는가 / What's mapped and what's lost

| Claude Code 원본 / source | Codex 포트 / port |
|---|---|
| Skill 자동 트리거 / Skill auto-trigger | `<skills_instructions>` 자동 주입 + `/<name>` 슬래시 + `codex exec --prompt-file` |
| `Agent` (`subagent_type=Explore/Plan/general-purpose`) | `codex exec --json --ephemeral -C <iso-dir> --prompt-file agents/<name>.md` (Explore = `-s read-only`) |
| `TeamCreate` / `SendMessage` / `recv_messages` / `TaskCreate` etc. | MCP 팀 서버 8개 도구 / 8 tools in `mcp-team-server/` |
| `CLAUDE.md` | `AGENTS.md` (cwd 1개만 자동 로드 / cwd-only auto-load — no upward search) |
| `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json` (다른 schema, `interface` 객체 등 / different schema) |
| `.claude-plugin/marketplace.json` | `.agents/plugins/marketplace.json` (`policy.installation`/`policy.authentication` 추가) |
| settings.json hooks | `hooks/hooks.json` (SessionStart/SessionEnd만 실측 / only these confirmed empirically) |
| settings.json permissions | `--sandbox` 모드 + `~/.codex/rules/default.rules` |

세부 손실 10항목 / Full 10-item lossy table → [`LIMITATIONS.md`](LIMITATIONS.md)

---

## Claude Code 개발자용 / For Claude Code developers

이 저장소는 **자기 자신을 빌드하는 self-hosting 메타-하네스**입니다. Codex CLI에 새 버전이 나왔거나 매핑 테이블에 회귀가 필요할 때 Claude Code에서 다음을 실행:

```bash
cd codex_harness
claude
> /codex-harness-orchestrator codex 하네스 빌드해줘
```

오케스트레이터가 4단계 파이프라인을 실행:

- **Phase A (Discovery)**: Codex CLI 분석 + revfactory 인벤토리 — 병렬 서브 에이전트
- **Phase B (Design)**: 매핑 테이블 설계 — 에이전트 팀
- **Phase C (Build)**: 루트의 `skills/`, `agents/`, `mcp-team-server/`, `AGENTS.md`, `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`, `.mcp.json`, `hooks/`, `tests/` 자동 생성·갱신
- **Phase D (Validate)**: smoke 테스트 + 경계면 검증

상세: [`.claude/skills/codex-harness-orchestrator/SKILL.md`](.claude/skills/codex-harness-orchestrator/SKILL.md), 회귀 절차: [`.claude/skills/codex-harness-orchestrator/references/regression-protocol.md`](.claude/skills/codex-harness-orchestrator/references/regression-protocol.md).

---

## 기여 / Contributing

Issues, PRs, 매핑 갭 보고를 환영합니다. 시작 전 [`CONTRIBUTING.md`](CONTRIBUTING.md)를 한 번 읽어 주세요. 보안 이슈는 [`SECURITY.md`](SECURITY.md) 절차를 따릅니다.

Issues, PRs, and reports of mapping gaps are welcome. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) first. Follow [`SECURITY.md`](SECURITY.md) for vulnerability reports.

---

## 제거 / Uninstall

**KR**

설치는 (a) MCP 등록, (b) 스킬 심링크, (c) 옵션 마켓 등록의 세 곳을 건드렸으니, 제거도 같은 세 곳을 정리합니다. 본 머신에서 실측 확인된 절차:

```bash
# 1) MCP 팀 서버 등록 해제
codex mcp remove team
codex mcp list                # team이 사라졌는지 확인

# 2) 스킬 활성화 해제 (심링크 또는 복사본 제거)
rm -f ~/.codex/skills/harness                # 심링크라면
# rm -rf ~/.codex/skills/harness             # 복사본이라면 (-rf)

# 3) [옵션] 마켓플레이스 등록 해제 (마켓을 등록했다면)
codex plugin marketplace remove codex-harness-marketplace

# 4) [옵션] 마켓 add 단계에서 codex 인터랙티브 메뉴로 플러그인을 활성화했다면,
#    config.toml에 남은 plugin 엔트리도 제거. 자동으로 같이 지워지지 않을 수 있습니다.
#    아래 한 줄을 ~/.codex/config.toml에서 직접 삭제하세요:
#    [plugins."codex-harness@codex-harness-marketplace"]
#    enabled = true

# 5) 영속 데이터 정리 (팀 협업 sqlite — 다른 프로젝트와 공유 안 했다면 삭제 안전)
rm -f ~/.codex/teams.sqlite

# 6) 빌드 산출물 정리 (저장소 자체를 보존하면서 fresh 상태로 되돌리려면)
cd /path/to/codex_harness
rm -rf mcp-team-server/node_modules mcp-team-server/dist

# 7) 저장소 자체를 지우려면
cd ~ && rm -rf /path/to/codex_harness
```

검증:

```bash
codex mcp list                                                          # No MCP servers configured yet.
ls ~/.codex/skills/harness 2>&1                                         # No such file or directory
grep -E 'codex-harness|teams\.sqlite' ~/.codex/config.toml              # 출력 없으면 정리 완료
ls ~/.codex/teams.sqlite                                                 # No such file
```

> 다른 Codex 플러그인(`github@openai-curated`, `vercel-plugin@plugins-cli` 등)과 그들의 설정은 **건드리지 않습니다** — 위 명령은 codex-harness 관련 항목만 정리합니다.

**EN**

Install touched three places (MCP, skill symlink, optional marketplace), so uninstall cleans the same three. Sequence verified on this machine:

```bash
# 1) Unregister the MCP team server
codex mcp remove team
codex mcp list                # confirm "team" is gone

# 2) Deactivate the skill (remove the symlink or the copy)
rm -f ~/.codex/skills/harness                 # if symlinked
# rm -rf ~/.codex/skills/harness              # if copied (-rf)

# 3) [Optional] Unregister the marketplace (if you added it)
codex plugin marketplace remove codex-harness-marketplace

# 4) [Optional] If you enabled the plugin from the codex interactive
#    menu after `marketplace add`, also remove the lingering plugin
#    entry from ~/.codex/config.toml — it may not be cleaned up
#    automatically. Delete this block by hand:
#    [plugins."codex-harness@codex-harness-marketplace"]
#    enabled = true

# 5) Delete persistent data (the team-collaboration sqlite — safe to drop
#    if you did not share it across other projects)
rm -f ~/.codex/teams.sqlite

# 6) Reset build artifacts while keeping the repo (for a fresh re-install test)
cd /path/to/codex_harness
rm -rf mcp-team-server/node_modules mcp-team-server/dist

# 7) Or delete the repo entirely
cd ~ && rm -rf /path/to/codex_harness
```

Verification:

```bash
codex mcp list                                                          # → "No MCP servers configured yet."
ls ~/.codex/skills/harness 2>&1                                         # → No such file or directory
grep -E 'codex-harness|teams\.sqlite' ~/.codex/config.toml              # → no output means clean
ls ~/.codex/teams.sqlite                                                 # → No such file
```

> Other Codex plugins (e.g. `github@openai-curated`, `vercel-plugin@plugins-cli`) and their settings are **not touched** — the commands above only clean codex-harness-related entries.

---

## 라이선스 / License

[Apache License 2.0](LICENSE) — same as upstream [`revfactory/harness`](https://github.com/revfactory/harness).

## 감사 / Acknowledgements

- **[revfactory/harness](https://github.com/revfactory/harness)** — the upstream Claude Code plugin that this project ports. The 7-Phase workflow, the agent team philosophy, and the SKILL.md+references structure are all from there.
- **OpenAI Codex CLI** — the runtime this port targets, and the project whose plugin/MCP architecture made this port feasible.
- **Anthropic Claude Code** — the development harness used to build this port (see `.claude/`).
