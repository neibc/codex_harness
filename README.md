# codex_harness

> **Agent Team & Skill Architect for OpenAI Codex CLI** — port of [`revfactory/harness`](https://github.com/revfactory/harness).
>
> Codex CLI를 위한 에이전트 팀·스킬 아키텍트. revfactory의 Claude Code 플러그인을 Codex로 옮기면서, Codex에 없는 멀티-에이전트 1차 primitive를 작은 MCP 서버로 에뮬레이션합니다.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Codex CLI](https://img.shields.io/badge/Codex_CLI-0.125.0%2B-black)](https://github.com/openai/codex)
[![Status: beta](https://img.shields.io/badge/status-beta-orange)](#known-limitations--limitations)

---

## TL;DR

설치 후 `codex` 안에서 **자연어로 트리거**합니다. Codex 인터랙티브 모드에서 `/harness` 슬래시 자동완성이 안 보이는 경우가 자주 있는데 — **"하네스를 구성해줘"** 라고 그냥 말하면 플러그인이 활성화됩니다.

```
$ codex
> 하네스를 구성해줘
> /harness  (슬래시가 보이는 환경에서)
> build a harness for an e-commerce backend
```

세 발화 모두 같은 7-Phase 워크플로우(도메인 분석 → 팀 설계 → 에이전트/스킬 자동 생성 → 검증)로 진입합니다.

---

## ⚠️ Codex CLI 버전 호환성 / Codex CLI Version Compatibility

본 플러그인은 **Codex CLI `0.125.0` 기준**으로 설계·실측되었습니다. Codex의 플러그인 시스템·feature flag·MCP 등록 명령은 빠르게 변하고 있으므로, 다른 버전에서는 동작이 달라질 수 있습니다.

| Codex CLI 버전 | 상태 |
|---|---|
| `< 0.125.0` | **미지원**. 이 플러그인이 의존하는 stable feature(`plugins=true`, `multi_agent=true`, `skill_mcp_dependency_install=true`, `~/.codex/skills/` 자동 스캔)가 없거나 다를 수 있음 |
| `0.125.0` | **테스트 완료** — README의 모든 명령이 실측 검증됨 |
| `> 0.125.0` (미래) | 호환 가능성 높지만 미실측. 다음을 주의: |
| | - `codex plugin marketplace add` 의 동작 (자동 활성화 추가될 수 있음) |
| | - `.codex-plugin/plugin.json` 의 schema 변경 |
| | - `codex mcp add` 의 인자 형식 |
| | - `~/.codex/skills/` 자동 스캔 동작 |

**업그레이드 시 권장 절차**:

```bash
# 1) 현재 codex 버전 확인
codex --version

# 2) 업그레이드 후 재검증
./tests/smoke.sh                                                       # 매니페스트/구조 검증
codex mcp list                                                         # team 항목이 여전히 enabled 인가
codex debug prompt-input "x" 2>/dev/null | grep -o 'harness:[^"]*' | head -1
# → harness:harness ... 출력이 보이면 활성화 유지
```

문제가 발생하면 [issue tracker](https://github.com/neibc/codex_harness/issues)에 `codex --version` 결과와 함께 보고해 주세요. **Codex CLI 새 버전 회귀**는 [`CONTRIBUTING.md`](CONTRIBUTING.md)의 회귀 절차(Claude Code 측 `.claude/` 빌드 파이프라인 재실행)로 매핑 테이블을 자동 갱신할 수 있습니다.

> **EN**: This plugin was built and verified against **Codex CLI `0.125.0`**. Codex's plugin/feature/MCP surface is evolving — older versions are not supported, and future versions may shift schemas. After upgrading Codex, run `./tests/smoke.sh`, `codex mcp list`, and the `prompt-input` activation check; report regressions with your `codex --version`. The dev pipeline under `.claude/` can regenerate the mapping table when a new Codex version ships.

---

## 트리거 — 자연어가 1차 진입점

| 환경 | 작동하는 트리거 |
|---|---|
| Codex 인터랙티브 — 일반 | **"하네스를 구성해줘"**, "하네스 점검해줘", "harness build for ..." 등의 자연어 |
| Codex 인터랙티브 — 슬래시 자동완성이 보일 때 | `/harness` |
| 비대화형 / CI | `codex exec --prompt-file skills/harness/SKILL.md "<요청>"` |

> **왜 자연어를 권장하나**: Codex 0.125.0은 슬래시 자동완성이 항상 동작하지 않습니다. 그러나 SKILL.md의 description에 매칭되는 자연어가 들어오면 동일하게 활성화됩니다. **이 점이 revfactory 원본(Claude Code)과 가장 큰 차이**입니다.

추가 트리거 키워드: `하네스 구성/구축/설계/엔지니어링/점검/감사/현황`, `에이전트/스킬 동기화`, `agent team`, `skill architect`.

---

## 설치 (Codex 사용자)

### 사전 준비

```bash
codex --version       # 0.125.0+
node --version        # v18+
```

### 4단계 설치

```bash
# 1) 클론
git clone https://github.com/neibc/codex_harness.git
cd codex_harness

# 2) MCP 팀 서버 빌드 (Claude의 TeamCreate/SendMessage/TaskCreate 대체)
cd mcp-team-server && npm install && npm run build && cd ..

# 3) MCP 팀 서버를 Codex에 등록
codex mcp add team \
  --env TEAM_STORAGE_PATH=$HOME/.codex/teams.sqlite \
  -- node "$(pwd)/mcp-team-server/dist/index.js"

# 4) 스킬 활성화 — ~/.codex/skills/ 에 심볼릭 링크
mkdir -p ~/.codex/skills
ln -sfn "$(pwd)/skills/harness" ~/.codex/skills/harness
```

### 검증

```bash
./tests/smoke.sh                                                       # PASS=37 FAIL=0 OK
codex mcp list                                                         # team 항목이 enabled
codex debug prompt-input "x" 2>/dev/null | grep -o 'harness:[^"]*' | head -1
# → harness:harness: 하네스를 구성합니다... (출력되면 활성화 성공)
```

### 첫 사용

```bash
codex
> 하네스를 구성해줘
```

7-Phase 워크플로우가 시작되고 **종료 시 새 하네스를 어떤 발화로 트리거하는지 안내**가 출력됩니다.

> **선택 사항**: `codex plugin marketplace add "$(pwd)"` 로 마켓 메타데이터도 등록할 수 있습니다. 0.125.0에서는 활성화에 영향 없으나(아직 `codex plugin install` CLI가 없음) 향후 릴리스 호환을 위한 forward-compat schema입니다.

---

## 어떻게 작동하는가

### 1. 풀고 싶은 문제

revfactory의 `harness`는 Claude Code의 `Agent`/`TeamCreate`/`SendMessage`/`TaskCreate` 1차 primitive를 **총 85회** 호출합니다. Codex CLI 0.125.0은 같은 영역(에이전틱 코딩 CLI)이지만 이런 멀티-에이전트 primitive를 **사용자가 호출 가능한 표면으로 제공하지 않습니다**. 따라서 텍스트 번역만으로는 동작 불가.

### 2. 핵심 원리 — MCP 서버로 Agent Team 에뮬레이션

Codex의 MCP 클라이언트 지원을 활용해 **stdio MCP 서버**(`mcp-team-server/`)에서 8개 도구를 직접 구현합니다. SQLite(WAL)가 메시지·작업을 영속화.

```
[Codex 세션 1: 오케스트레이터]
[Codex 세션 2: 에이전트 A]    ─┐
[Codex 세션 3: 에이전트 B]    ─┼─→ stdio MCP 서버 → ~/.codex/teams.sqlite
[Codex 세션 4: 에이전트 C]    ─┘
```

도구: `team_create`, `send_message`, `recv_messages`, `task_create`, `task_update`, `task_list`, `task_get_output`, `team_destroy`.

원본과의 가장 큰 차이: 메시지 수신이 **push가 아닌 polling**. 대신 다중 머신 협업이 가능합니다.

### 3. 4개 계층

```
① skills/harness/        Codex가 ~/.codex/skills/<name>/ 를 자동 스캔하여 등록
② mcp-team-server/       8개 도구의 stdio MCP 서버 (TypeScript + SQLite)
③ AGENTS.md              cwd 자동 로드. 트리거 + MCP 도구 표 집약
④ .codex-plugin/, .agents/, .mcp.json
                         표준 플러그인 매니페스트 (forward-compat,
                         vercel/cloudflare와 동일 schema)
```

### 4. 데이터 흐름

```
사용자 자연어 ("하네스를 구성해줘")
   ↓
Codex가 description 매칭으로 harness 스킬을 컨텍스트에 주입
   ↓
SKILL.md의 7-Phase 워크플로우 진입
   ↓
필요 시 MCP team_create / send_message / task_* 호출 (외부 stdio MCP 서버)
   ↓
산출물: 사용자 프로젝트의 agents/, skills/, AGENTS.md 자동 생성/갱신
   ↓
종료 시 "이 하네스를 어떻게 다시 트리거하나요?" 안내 출력
```

### 5. 손실은 명시적이다

10개 손실 항목 → [`LIMITATIONS.md`](LIMITATIONS.md). 핵심:
- 동기 메시지 도착 통지 → polling
- `subagent_type=Explore/Plan` 카테고리 → `--sandbox read-only` + prompt 지시문
- `WebFetch`/`WebSearch` 빌트인 → 외부 MCP 서버 별도 등록
- `PreToolUse`/`PostToolUse` hook 이벤트 → 실측 미확인 (under development)

### 6. 듀얼 네이처

같은 저장소가 두 환경에서 동시 작동:
- **Codex 사용자**: `skills/`, `mcp-team-server/`, `AGENTS.md`, `.codex-plugin/` 만 사용
- **Claude Code 개발자**: `.claude/`의 4-phase 빌드 파이프라인이 위 Codex 측 파일들을 자동 갱신 — **자기 자신을 빌드하는 self-hosting 메타-하네스**

---

## How it works — English summary

`codex_harness` ports `revfactory/harness` (a Claude Code meta-skill that auto-designs agent teams + skills for any domain) to OpenAI Codex CLI. Codex lacks first-class multi-agent primitives, so the port emulates `TeamCreate` / `SendMessage` / `Task*` through a small stdio MCP server backed by SQLite (WAL).

After installation, **trigger with natural language** ("build a harness for ...") rather than relying on a slash command — Codex 0.125.0 does not always surface `/harness` in its slash autocomplete, but the skill's description matches the request and activates the same 7-Phase workflow regardless.

Lossy translations are documented in [`LIMITATIONS.md`](LIMITATIONS.md) (10 items: polling vs. push delivery, missing subagent categories, no built-in WebFetch/WebSearch, hook events still unverified in 0.125.0).

The repository is dual-runtime: it ships as a Codex plugin AND contains the Claude Code build pipeline (`.claude/`) that regenerates the Codex-side files when Codex CLI ships a new version.

---

## 디렉토리 / Directory

```
codex_harness/
├── README.md, LICENSE, AGENTS.md, CLAUDE.md
├── LIMITATIONS.md, CONTRIBUTING.md, SECURITY.md
├── .codex-plugin/plugin.json        ← 표준 plugin manifest (forward-compat)
├── .agents/plugins/marketplace.json ← 표준 marketplace manifest
├── .mcp.json                        ← stdio MCP 등록 (forward-compat)
├── skills/harness/                  ← Codex 자동 로드되는 메인 스킬
│   ├── SKILL.md
│   └── references/×6
├── mcp-team-server/                 ← 8 tools, TypeScript + SQLite
│   ├── package.json, tsconfig.json
│   └── src/{index,tools,storage,types}.ts
├── tests/smoke.sh                   ← 37 assertions
├── .claude/                         ← Claude Code 개발 하네스 (Codex 무시)
└── _workspace/                      ← gitignored 중간 산출물
```

> 이전 버전에 있던 루트 `agents/×5`와 `hooks/`는 **0.125.0에서 효과가 없어 제거**되었습니다 (`agents/`는 dev-time 페르소나, `hooks/`는 `plugin_hooks` under-development). `multi_agent_v2`/`enable_fanout`/`plugin_hooks`가 stable 전환되면 다시 도입 검토.

---

## 트러블슈팅

| 증상 | 원인 / 해결 |
|---|---|
| `/harness` 슬래시가 안 보임 | 정상 — Codex 0.125.0은 슬래시를 항상 표시하지 않음. **"하네스를 구성해줘"** 자연어로 트리거 |
| `codex mcp list`가 비어 있음 | Step 3 누락. `codex mcp add team ...` 실행 |
| 자연어로도 활성화 안 됨 | Step 4 누락. `~/.codex/skills/harness` 심링크 확인 |
| 활성화 검증 | `codex debug prompt-input "x" 2>/dev/null \| grep -o 'harness:[^"]*' \| head -1` |
| `mcp-team-server/dist/index.js` 없음 | Step 2 빌드 누락. `cd mcp-team-server && npm install && npm run build` |
| 비대화형으로 우회 | `codex exec --prompt-file skills/harness/SKILL.md "<요청>"` — 슬래시/스킬 활성화 무관하게 작동 |

---

## 업데이트 / Update

### 자동화 스크립트 — 1줄로 끝

```bash
cd /path/to/codex_harness
./bin/update.sh
```

스크립트가 다음을 자동 수행 (각 단계 진행 표시):

1. `git fetch` + 신규 커밋 요약 (없으면 즉시 종료)
2. fast-forward `git pull` (uncommitted 변경 있으면 안전하게 중단)
3. `mcp-team-server` 의존성/빌드 갱신 (변경 감지 시에만 `npm install`)
4. `codex mcp list` + `codex debug prompt-input`으로 활성화 검증
5. 마켓플레이스 등록되어 있다면 `codex plugin marketplace upgrade` 실행

옵션:
- `./bin/update.sh --check` — pull 안 하고 변경 사항만 미리 확인
- `./bin/update.sh --skip-build` — mcp-team-server 재빌드 생략 (스킬 텍스트만 바뀌었을 때)

### 자동 트리거 — cron / launchd

매일 한 번 또는 매 시간 자동 업데이트:

```bash
# crontab -e
0 9 * * * cd /path/to/codex_harness && ./bin/update.sh --no-color >> ~/.codex/codex_harness-update.log 2>&1
```

macOS launchd로 변환은 [`launchd.plist` 가이드](https://www.launchd.info/) 참조.

### 무엇이 자동 반영되는가

설치 시 `~/.codex/skills/harness`를 **심볼릭 링크**로 만들었기 때문에 다음은 `git pull`만으로 즉시 반영됩니다 — 별도 빌드 / 재시작 불필요:

| 변경 | 사용자 추가 작업 |
|---|---|
| `skills/harness/SKILL.md`, `references/*` | **없음** (다음 codex 세션에서 자동 반영) |
| `AGENTS.md`, `README.md`, `LIMITATIONS.md` | 없음 |
| `.codex-plugin/plugin.json`, `.mcp.json`, `.agents/...` | 없음 (0.125.0 forward-compat schema) |
| `mcp-team-server/src/*.ts` | **`bin/update.sh` 또는 `npm run build` 1회** |
| MCP 도구 인터페이스 추가/제거 | 위 + 진행 중인 codex 세션 재시작 |

### EN — Update

A single command keeps the install in sync:

```bash
cd /path/to/codex_harness && ./bin/update.sh
```

The script handles git fetch → fast-forward pull → conditional npm install → tsc build → activation verification → marketplace upgrade. Use `--check` for dry-run, `--skip-build` when only docs/skill text changed.

For unattended updates, add a cron entry: `0 9 * * * cd /path/to/codex_harness && ./bin/update.sh --no-color >> ~/.codex/codex_harness-update.log 2>&1`.

Because the skill is installed as a symlink to `~/.codex/skills/harness`, edits to `skills/harness/**` flow through immediately on the next codex session — no build, no re-register. Only `mcp-team-server/src/*.ts` changes require a rebuild, which the script does automatically.

---

## 제거 / Uninstall

```bash
codex mcp remove team
rm -f ~/.codex/skills/harness                                   # symlink (또는 -rf for copy)
codex plugin marketplace remove codex-harness-marketplace 2>/dev/null  # 마켓 등록한 경우
rm -f ~/.codex/teams.sqlite                                     # 영속 데이터
cd /path/to/codex_harness && rm -rf mcp-team-server/{node_modules,dist}  # 빌드 산출물
# 저장소도 지우려면: cd ~ && rm -rf /path/to/codex_harness
```

검증:
```bash
codex mcp list                                          # No MCP servers configured yet.
ls ~/.codex/skills/harness 2>&1                         # No such file or directory
```

---

## 기여 / Contributing · 라이선스 / License · 감사 / Acknowledgements

- 기여 가이드: [`CONTRIBUTING.md`](CONTRIBUTING.md), 보안 신고: [`SECURITY.md`](SECURITY.md), 변환 손실: [`LIMITATIONS.md`](LIMITATIONS.md)
- License: [Apache-2.0](LICENSE) (원본 [`revfactory/harness`](https://github.com/revfactory/harness)와 동일)
- Acknowledgements:
  - [`revfactory/harness`](https://github.com/revfactory/harness) — 원본 플러그인. 7-Phase 워크플로우와 SKILL.md+references 구조의 출처
  - **OpenAI Codex CLI** — 포팅 대상 런타임. 플러그인/MCP 아키텍처가 이 포팅을 가능하게 함
  - **Anthropic Claude Code** — 이 포트를 빌드한 개발 하네스 (`.claude/` 참조)
