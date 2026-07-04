# codex_harness

> **Codex CLI에 '내 프로젝트 전담 AI 에이전트 팀'을 붙여주는 메타-스킬** ([revfactory/harness](https://github.com/revfactory/harness)의 Codex 포트).
>
> A meta-skill that gives the OpenAI Codex CLI a project-specific AI agent team — port of `revfactory/harness` from Claude Code.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Codex CLI](https://img.shields.io/badge/Codex_CLI-0.136.0%2B-black)](https://github.com/openai/codex)
[![Status: beta](https://img.shields.io/badge/status-beta-orange)](#-한계--limitations-요약)

---

## 🤔 What is this?

`codex` 안에서 **"하네스를 구성해줘"** 라고 한 번 말하면, 본 플러그인이 프로젝트 도메인을 분석해 **전문 에이전트와 스킬을 자동 생성**해 cwd의 `agents/`, `skills/`, `AGENTS.md`에 영속화합니다. 그 다음부터 "API 변경해줘", "테스트 자동화" 같은 후속 요청은 적절한 에이전트/스킬로 라우팅됩니다.

> Inside `codex`, say "build a harness" once. The plugin analyzes your project's domain, generates specialist agents and skills, and persists them under `agents/`, `skills/`, and `AGENTS.md` in your cwd. Subsequent requests like "add an API endpoint" or "automate tests" are routed to the right agent and skill automatically.

핵심 차별점:
- 일회성 응답이 아닌 **프로젝트 영속 에이전트 팀** 구성
- 복수 에이전트가 협업하도록 **MCP 팀 서버**로 메시지·작업 큐 제공 (Codex에 없는 `TeamCreate`/`SendMessage`/`Task*` 에뮬레이션)
- revfactory `harness`의 **7-Phase 워크플로우** 그대로 계승 (도메인 분석 → 팀 아키텍처 → 에이전트/스킬 생성 → 검증 → 진화)

---

## 🎬 30초 예시 / 30-second example

빈 작업 디렉토리에서 시작 → `codex` 진입 → "**AI 빅테크 3사의 올해 신제품/신상품 로드맵 보고서를 작성하는 하네스를 구성해줘**" → 본 플러그인이 자동 생성:

```
ai-roadmap-research/
├── agents/
│   ├── market-researcher.md            ← 공식 발표·블로그·뉴스 자료 수집
│   ├── product-cataloger.md            ← 신제품/업데이트 카탈로그 분류
│   ├── roadmap-analyst.md              ← 3사 비교 분석 (시기·카테고리)
│   └── report-writer.md                ← 종합 보고서 작성
├── skills/
│   ├── tech-source-discovery/SKILL.md  ← 신뢰 가능한 출처 탐색 워크플로우
│   └── comparative-roadmap/SKILL.md    ← 3사 비교 분석 패턴
└── AGENTS.md                           ← 도메인 트리거 + 라우팅 표
```

이후 같은 cwd에서:

```
> OpenAI 11월 발표를 추가해서 다시 작성해줘
```

→ AGENTS.md 라우팅 → `market-researcher` (신규 자료 수집) → `product-cataloger` (카탈로그 갱신) → `roadmap-analyst` (비교 재분석) → `report-writer` (보고서 재작성) 순서로 자동 실행.

> **외부 자료가 중심인 도메인**: Codex에는 `WebFetch`/`WebSearch` 빌트인이 없습니다. 하네스 구성 전 외부 MCP 서버를 등록하세요 — 예: `codex mcp add fetch -- npx -y @modelcontextprotocol/server-fetch`.

코드 도메인 (Express 백엔드) 예시는 [`examples/node-cli/`](examples/node-cli/) 참조.

---

## 🚀 설치 / Install

### 한 줄 설치 (권장 / recommended)

```bash
git clone https://github.com/neibc/codex_harness.git
cd codex_harness
./install.sh
```

`install.sh`가 처리하는 것 (기본 = 심링크 canonical):
1. node 18+ / codex 0.136.0+ 사전 검사
2. `mcp-team-server` 빌드 (`npm install` + `tsc`)
3. `codex mcp add team` — MCP 팀 서버 등록
4. `~/.codex/skills/harness` 심링크 (저장소 변경 즉시 반영)
5. 활성화 검증 (`codex mcp list` + `codex debug prompt-input`)
6. 다음 액션 안내 출력

이미 부분 설치되어 있으면 해당 단계만 skip / 충돌 시 안전 중단. 옵션: `--marketplace` (옵트인 마켓 모드, 아래 박스 참조), `--skip-build`, `--copy` (심링크 대신 복사), `--no-color`. (`--dev`는 기본 모드의 별칭으로 계속 허용됩니다.)

> 본 플러그인은 hook을 동봉하지 않으므로 Codex 0.136의 hook trust 프롬프트가 발생하지 않습니다. (직접 hook을 추가할 경우에만 사전 trust 또는 `--dangerously-bypass-hook-trust`가 필요합니다.)

### 수동 설치 — 심링크 canonical / Manual install (canonical)

(자동화가 막힐 때만 사용)

```bash
git clone https://github.com/neibc/codex_harness.git && cd codex_harness
cd mcp-team-server && npm install && npm run build && cd ..
codex mcp add team --env TEAM_STORAGE_PATH=$HOME/.codex/teams.sqlite \
  -- node "$(pwd)/mcp-team-server/dist/index.js"
mkdir -p ~/.codex/skills && ln -sfn "$(pwd)/skills/harness" ~/.codex/skills/harness
codex debug prompt-input "x" 2>/dev/null | grep -o 'harness:[^"]*' | head -1   # 활성화 확인
```

### ⚠️ 마켓플레이스 2단계 설치 — 현재 미지원 (opt-in / known limitation)

**KR**: `codex plugin marketplace add` → `codex plugin add`의 표준 마켓 경로는 **codex 0.136에서 본 저장소에 대해 동작하지 않습니다.** codex 0.136의 마켓 스캐너는 플러그인이 마켓 루트의 **서브디렉토리**(예: `./plugins/<name>/`)에 있어야 해소하는데, 본 저장소는 "루트 == 플러그인 == 마켓"의 듀얼-네이처 레이아웃(`marketplace.json`의 `source.path: "./"`)이라 `codex plugin add`가 `plugin ... was not found`로 실패합니다 (실측: 2026-07-04, codex 0.136.0 — 서브디렉토리 레이아웃에서는 성공, 루트 레이아웃에서는 실패). 자세한 근거와 완화책은 [LIMITATIONS.md #15](LIMITATIONS.md).

`./install.sh --marketplace`로 시도할 수 있으나, **실패 시 자동으로 심링크(canonical) 모드로 폴백**합니다. 듀얼-네이처 설계를 보존하기 위해 서브디렉토리 재배치는 채택하지 않았습니다.

```bash
./install.sh --marketplace     # 실패 시 심링크 모드로 자동 폴백
```

**EN**: The standard marketplace path (`codex plugin marketplace add` → `codex plugin add`) **does not work for this repository on codex 0.136.** The 0.136 marketplace scanner only resolves plugins that live in a **subdirectory** of the marketplace root (e.g. `./plugins/<name>/`); this repo's dual-nature "root == plugin == marketplace" layout (`source.path: "./"` in `marketplace.json`) makes `codex plugin add` fail with `plugin ... was not found` (verified 2026-07-04 on codex 0.136.0: succeeds with a subdirectory layout, fails with the root layout). `./install.sh --marketplace` attempts it but **auto-falls back to symlink (canonical) mode on failure.** We keep the dual-nature layout rather than relocating into a subdirectory — see [LIMITATIONS.md #15](LIMITATIONS.md).

---

## 🎯 첫 사용 / First use

```bash
codex
> ANSI SQL을 지원하는 python DB서버와 클라이언트를 개발하는 하네스를 구성해줘
```

도메인을 함께 적어주면 7-Phase 워크플로우(도메인 분석 → 팀 아키텍처 → 에이전트/스킬 생성 → 통합·오케스트레이션 → 검증 → 진화)가 그 도메인에 맞춰 시작됩니다. **슬래시 명령(`/harness`)은 본 플러그인이 `commands/`를 동봉하지 않아 마켓/심링크 어느 경로에서도 노출되지 않으므로 자연어 발화로만 활성화**됩니다.

비대화형 / CI:

```bash
codex exec "ANSI SQL을 지원하는 python DB서버와 클라이언트를 개발하는 하네스를 구성해줘"
# SKILL.md 본문 stdin 주입:
codex exec - "ANSI SQL을 지원하는 python DB서버와 클라이언트를 개발하는 하네스를 구성해줘" < skills/harness/SKILL.md
```

---

## 🎚️ When to use / When NOT to use

**잘 맞는 경우:**
- Codex CLI를 매일 쓰는 개발자
- 같은 프로젝트에서 반복 작업이 5개 이상이고, 매번 컨텍스트를 다시 주는 게 번거로운 상황
- 멀티-에이전트 협업 워크플로우를 실험하려는 사람
- `revfactory/harness`를 Claude Code에서 잘 쓰던 사용자가 Codex에서도 같은 UX를 원할 때

**부적합:**
- Codex CLI를 안 씀 (IDE 통합 또는 Cursor/Copilot 사용 중)
- 1회성 코드 생성이 주 사용 패턴
- 설치 자동화 1줄도 부담스러운 환경

작은 도메인(1~2단계 작업)에서는 **하네스 구성보다 단일 스킬이 효과적**입니다. Codex 환경에서 팀 MCP polling 오버헤드가 작업 가치를 넘을 수 있으므로, 하네스 구성을 요청할 때 "**단일 스킬로 만들어줘**" 또는 "**작업 복잡도에 맞춰 최소한으로**"를 명시하세요. (자세한 가이드: [LIMITATIONS.md #11](LIMITATIONS.md))

---

## ⚠️ 한계 / Limitations 요약

| 한계 | 영향 |
|---|---|
| 산출물 깊이 | Claude 대비 짧고 단순 — 아래 "솔직한 안내" 참조 |
| MCP 메시지 전달 | polling 기반 (Claude의 push 대비 응답 지연 가능) |
| 데이터 저장 | `~/.codex/teams.sqlite`에 메시지·작업 본문 평문 저장 — [SECURITY.md](SECURITY.md) |
| 마켓플레이스 설치 | codex 0.136 루트-레이아웃 미지원 — 심링크가 canonical, 마켓은 `--marketplace` 옵트인 ([#15](LIMITATIONS.md)) |
| Codex 버전 의존 | 0.136.0 검증(0.125.0 최초 검증). 미래 버전 회귀 가능 |
| Hook trust (0.136) | hook 미동봉이라 현재 무영향 — 직접 추가 시 사전 trust 필요 ([#4](LIMITATIONS.md)) |
| Profile v2 (0.136) | in-file `[profiles.*]` 진부화 가능 — 호출 시점 `-m <model>` 우선 ([#12](LIMITATIONS.md)) |

15개 손실 항목 전체: [LIMITATIONS.md](LIMITATIONS.md).

### 솔직한 안내 — Codex의 작업 분화/깊이 격차 / Honest note on output depth

**KR**: Codex(GPT-5.x)는 Claude(Opus) 대비 작업을 더 단순화하는 경향이 있으나, 빠른 속도와 짧은 결과물, 적은 토큰 소모가 장점으로 다가올 때도 있습니다. 같은 메타-스킬·프롬프트로 실측한 결과 보고서 단어 수 14.9×, 중간 산출물 29×, 변증법/대안 검토 키워드 ∞ 격차가 났습니다 (`~/codexwork/leehongjang` vs `~/claudework/saju`, [LIMITATIONS.md #11](LIMITATIONS.md)).

본 플러그인은 SKILL.md에 3개의 "Codex 환경 안내" 박스(Phase 2/3/6)를 부착해 격차를 좁혔지만, 모델 보수성과 `WebFetch`/`WebSearch` 부재 같은 환경 한계는 SKILL.md만으로 해결되지 않습니다. 깊이가 필요한 도메인이면 다음 발화 중 도메인에 맞는 것을 함께 보내세요:

- "**변증법 phase 추가**" / "**양측 입장 steelman 분석**"
- "**산출물 sub-item을 도메인 맞게 구체 분해**"
- "**작업 원칙에 'Why' + 안 했을 때 문제 함께**"
- "**최종 보고서 ≥N 섹션, ≥N 인용**" (Goodhart 부풀림 가능성 인지)

**EN**: Codex (GPT-5.x) tends to simplify work more than Claude (Opus), but the trade-off — faster runs, shorter outputs, lower token cost — is sometimes the point. With the same meta-skill and prompt, we measured a 14.9× word-count gap, 29× workspace gap, and ∞ on dialectic keywords (`~/codexwork/leehongjang` vs `~/claudework/saju`, [LIMITATIONS.md #11](LIMITATIONS.md)). Three callout boxes in SKILL.md (Phases 2/3/6) narrow but don't close it — model conservatism and the lack of built-in `WebFetch`/`WebSearch` are environment limits. When depth matters, append one of: "add a dialectic phase / steelman both sides", "decompose each artifact into concrete sub-items", "each principle: why + consequence of skipping", or "final report ≥N sections, ≥N citations" (Goodhart caveat applies).

---


## 트러블슈팅

| 증상 | 원인 / 해결 |
|---|---|
| 자연어 발화에 스킬이 응답 안 함 | `~/.codex/skills/harness` 심링크 확인 + `codex debug prompt-input "x" \| grep harness:harness` |
| `codex mcp list`가 비어 있음 | `codex mcp add team ...` 미실행 (수동 설치 step 3) |
| `mcp-team-server/dist/index.js` 없음 | `cd mcp-team-server && npm install && npm run build` |
| 비대화형으로 우회 | `codex exec "<요청>"` 또는 `codex exec - "<요청>" < skills/harness/SKILL.md` |

---

## 업데이트 / Update

> 이 섹션과 [제거](#-제거--uninstall) 섹션의 `/path/to/codex_harness`는 **본 저장소를 `git clone`한 경로**를 의미합니다 (예: `/work/dev/codex_harness`). 본인 환경의 실제 경로로 바꿔서 실행하세요.

```bash
cd /path/to/codex_harness && ./bin/update.sh
```

`git fetch` → fast-forward `git pull` → 조건부 `npm install` + `tsc` → 활성화 검증 → (있으면) marketplace upgrade. 옵션: `--check`(dry-run), `--skip-build`(스킬 텍스트만 바뀌었을 때).

심링크 설치 덕분에 `skills/harness/**`, `AGENTS.md`, README/LIMITATIONS 변경은 **다음 codex 세션에서 자동 반영**됩니다. 재빌드가 필요한 유일한 경우는 `mcp-team-server/src/*.ts` 수정이며, 위 스크립트가 자동 처리합니다.

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

---

# 🛠️ For maintainers

여기서부터는 플러그인 자체를 유지보수하거나 회귀 검증을 하는 사람을 위한 섹션입니다. 일반 사용자는 위 섹션까지만 보면 됩니다.

## 어떻게 작동하는가 (개요)

### 1. 풀고 싶은 문제

revfactory의 `harness`는 Claude Code의 `Agent`/`TeamCreate`/`SendMessage`/`TaskCreate` 1차 primitive를 **총 85회** 호출합니다. Codex CLI 0.136.0은 같은 영역(에이전틱 코딩 CLI)이지만 이런 멀티-에이전트 primitive를 **사용자가 호출 가능한 표면으로 제공하지 않습니다** (`multi_agent`는 stable이나 도구 표면 미노출, `multi_agent_v2`/`enable_fanout`은 under development). 따라서 텍스트 번역만으로는 동작 불가.

### 2. 핵심 원리 — MCP 서버로 Agent Team 에뮬레이션

Codex의 MCP 클라이언트 지원을 활용해 **stdio MCP 서버**(`mcp-team-server/`)에서 8개 도구를 직접 구현합니다. SQLite(WAL)가 메시지·작업을 영속화.

```
[Codex 세션 1: 오케스트레이터]
[Codex 세션 2: 에이전트 A]    ─┐
[Codex 세션 3: 에이전트 B]    ─┼─→ stdio MCP 서버 → ~/.codex/teams.sqlite
[Codex 세션 4: 에이전트 C]    ─┘
```

도구: `team_create`, `send_message`, `recv_messages`, `task_create`, `task_update`, `task_list`, `task_get_output`, `team_destroy`. 원본과의 가장 큰 차이: 메시지 수신이 **push가 아닌 polling**.

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
사용자 자연어 → Codex description 매칭 → SKILL.md 7-Phase 진입 → MCP 도구 호출
   → 사용자 프로젝트의 agents/, skills/, AGENTS.md 생성 → 트리거 안내 출력
```

### 5. 듀얼 네이처

같은 저장소가 두 환경에서 동시 작동:
- **Codex 사용자**: `skills/`, `mcp-team-server/`, `AGENTS.md`, `.codex-plugin/` 만 사용
- **Claude Code 개발자**: `.claude/`의 4-phase 빌드 파이프라인이 위 Codex 측 파일들을 자동 갱신 — **자기 자신을 빌드하는 self-hosting 메타-하네스**

canonical 설치 경로는 **`codex mcp add` + `~/.codex/skills/<name>/` 심링크**입니다. `.codex-plugin/`, `.agents/plugins/marketplace.json`, `.mcp.json`은 표준 마켓플레이스 install(`codex plugin marketplace add` → `codex plugin add`)의 등록 소스로, 레이아웃만 맞으면 `skills`·`mcpServers`(→`.mcp.json`, `${CODEX_PLUGIN_ROOT}` 자동 해소)를 자동 등록합니다. 다만 **codex 0.136 마켓 스캐너는 플러그인이 마켓 루트의 서브디렉토리에 있어야 해소**하는데 본 저장소는 루트==플러그인 레이아웃(`source.path:"./"`)이라 마켓 경로가 실패합니다([LIMITATIONS #15](LIMITATIONS.md)). 그래서 마켓은 `--marketplace` 옵트인(실패 시 심링크 자동 폴백)으로만 제공합니다.

## How it works — English summary

`codex_harness` ports `revfactory/harness` (a Claude Code meta-skill that auto-designs agent teams + skills for any domain) to OpenAI Codex CLI. Codex lacks first-class multi-agent primitives, so the port emulates `TeamCreate` / `SendMessage` / `Task*` through a small stdio MCP server backed by SQLite (WAL).

After installation, **trigger with natural language** ("build a harness for ..."). The slash command surface (`/<name>`) is not exposed because this plugin ships no `commands/` directory — neither the marketplace nor the symlink path registers slash commands. Skills are activated through description matching instead.

The canonical install path is **`codex mcp add` + a symlink at `~/.codex/skills/<name>/`**. The `.codex-plugin/`, `.agents/plugins/marketplace.json`, and `.mcp.json` files match the schema used by official OpenAI plugins (vercel, cloudflare) and drive the standard marketplace install (`codex plugin marketplace add` → `codex plugin add`), which auto-registers `skills` and `mcpServers`→`.mcp.json` (with `${CODEX_PLUGIN_ROOT}` resolved) **when the layout matches**. However, the codex 0.136 marketplace scanner only resolves plugins in a **subdirectory** of the marketplace root, whereas this repo uses a root==plugin layout (`source.path:"./"`), so the marketplace path fails ([LIMITATIONS #15](LIMITATIONS.md)). The marketplace is therefore offered only as an `--marketplace` opt-in that auto-falls back to the symlink path. Lossy translations are documented in [`LIMITATIONS.md`](LIMITATIONS.md) (15 items).

The repository is dual-runtime: it ships as a Codex plugin AND contains the Claude Code build pipeline (`.claude/`) that regenerates the Codex-side files when Codex CLI ships a new version.

## Agent Team 에뮬레이션 — 무엇이 보존되고 무엇이 다른가 / Equivalence with Claude Code's Agent Team

Claude Code의 (실험적) Agent Team primitive를 본 포트가 어디까지 재현하는지의 정확한 경계.

### Primitive 매핑

| Claude Code | Codex 측 (MCP) | 구현 위치 |
|---|---|---|
| `TeamCreate` | `team_create` | `mcp-team-server/src/tools.ts` |
| `SendMessage` (1:1, `to:"*"` 브로드캐스트) | `send_message` | 동상 |
| (런타임이 자동 전달) | `recv_messages` (폴링) | 동상 |
| `TaskCreate` / `TaskUpdate` / `TaskList` | `task_create` / `task_update` / `task_list` / `task_get_output` | 동상 |
| (런타임 종료) | `team_destroy` | 동상 |

저장소: `~/.codex/teams.sqlite` (WAL 모드, append-only `messages` + 작업 보드 `tasks`). **여러 `codex exec` 서브프로세스가 같은 SQLite를 공유하므로 에이전트들끼리 실제로 메시지·작업 상태를 주고받는다.**

### 핵심 격차 — push vs poll

Claude Code는 `SendMessage` 도착 즉시 수신자가 깨어난다(runtime scheduler). Codex 측에는 그 스케줄러가 없으므로, **수신자가 매 턴 `recv_messages({since: <cursor>})`를 직접 호출해야 발견**된다 ([LIMITATIONS.md #1](LIMITATIONS.md)).

이 차이를 보완하는 두 장치:
- `skills/harness/references/orchestrator-template.md`이 모든 팀원 prompt에 *"매 turn 시작 시 `recv_messages` 호출"*을 강제 주입
- 폴링 간격 지수 증가 (1s → 2s → 4s … max 30s) — 부하 제어

### 실효성

- **잘 됨**: orchestrator → worker 분배 + 결과 회수, 브로드캐스트 종료 신호(`<TEAM_DONE>`), 공유 task 보드 기반 조율
- **약함**: 짧은 ping-pong 대화 — 폴링 간격만큼 지연
- **미해결**: Codex `multi_agent` feature flag가 `stable`이지만 1차 Task 도구 표면이 아직 없어 MCP 우회 ([LIMITATIONS.md #10](LIMITATIONS.md)). 향후 Codex가 노출하면 폴링 오버헤드 제거 가능

요약하면, Claude Code의 Agent Team이 제공하던 "여러 에이전트가 한 팀에서 메시지+태스크를 공유"라는 효과는 **재현된다**. 다만 "즉시 깨어남" 같은 런타임 시맨틱은 폴링으로 변환된 것이라, 동등(equivalent)이 아니라 동형(isomorphic via polling).

**EN summary**: All Claude-Code Agent-Team primitives map to MCP tools in `mcp-team-server` (`team_create`, `send_message`, `recv_messages`, `task_*`, `team_destroy`) over a shared SQLite log at `~/.codex/teams.sqlite`. Multiple `codex exec` subprocesses really do exchange messages and task state through it. The one structural gap is that Claude's `SendMessage` wakes the recipient instantly via the runtime scheduler, while the Codex port requires recipients to poll `recv_messages` each turn (mitigated by mandated polling in `skills/harness/references/orchestrator-template.md` and 1s→30s exponential backoff). Works well for orchestrator/worker fan-out and broadcast termination; weaker for tight ping-pong dialogue. Not equivalent — *isomorphic via polling*.

## 디렉토리 / Directory

```
codex_harness/
├── README.md, LICENSE, AGENTS.md, CLAUDE.md
├── LIMITATIONS.md, CONTRIBUTING.md, SECURITY.md
├── install.sh                       ← 한 줄 설치
├── bin/update.sh                    ← 자동 업데이트
├── .codex-plugin/plugin.json        ← 표준 plugin manifest (forward-compat)
├── .agents/plugins/marketplace.json ← 표준 marketplace manifest (forward-compat)
├── .mcp.json                        ← stdio MCP 등록 (forward-compat)
├── skills/harness/                  ← Codex 자동 로드되는 메인 스킬
│   ├── SKILL.md
│   └── references/×6
├── mcp-team-server/                 ← 8 tools, TypeScript + SQLite
│   ├── package.json, tsconfig.json
│   └── src/{index,tools,storage,types}.ts
├── examples/                        ← before/after 사례
├── tests/smoke.sh                   ← 매니페스트 + MCP 등록 + 활성화 검증
├── .claude/                         ← Claude Code 개발 하네스 (Codex 무시)
└── _workspace/                      ← gitignored 중간 산출물
```

> 이전 버전에 있던 루트 `agents/×5`와 `hooks/`는 **효과가 없어 제거**되었습니다 (`agents/`는 dev-time 페르소나). Codex 0.136에서 `codex_hooks`/`plugin_hooks` 플래그는 단일 `hooks`로 통합되고 `plugin_hooks`는 removed, hook은 trust-gated(`--dangerously-bypass-hook-trust`)가 되었습니다 — **본 플러그인은 hook을 미동봉**하므로 trust 마찰이 없습니다. `multi_agent_v2`/`enable_fanout`가 stable 전환되면 네이티브 fan-out 재도입 검토.

## Codex CLI 버전 호환성 / Version Compatibility

| Codex CLI 버전 | 상태 |
|---|---|
| `< 0.125.0` | **미지원**. stable feature(`plugins=true`, `multi_agent=true`, `skill_mcp_dependency_install=true`, `~/.codex/skills/` 자동 스캔)가 없거나 다를 수 있음 |
| `0.125.0` | **최초 검증** — README의 모든 명령이 이 버전에서 실측 검증됨 (심링크 경로 기준) |
| `0.128.0` | **smoke test 통과** (외부 검증). 활성화·MCP 등록·스킬 매칭 모두 동작 |
| `0.136.0` | **테스트 완료 기준선** — 심링크 canonical 설치 + 0.125→0.136 delta 반영 (마켓플레이스 2단계는 opt-in, LIMITATIONS #15). 주의 영역: hook trust 모델, profile v2(별도 파일 오버레이), `default_permissions` 권한 계층 |
| `> 0.136.0` (미래) | 호환 가능성 높지만 미실측. 주의 영역: `codex plugin marketplace add`/`plugin add` 동작, plugin.json schema, hook trust, profile v2, `~/.codex/skills/` 자동 스캔 |

**업그레이드 시 권장 절차:**

```bash
codex --version
./bin/update.sh                   # 또는 ./tests/smoke.sh + codex mcp list
codex debug prompt-input "x" 2>/dev/null | grep -o 'harness:[^"]*' | head -1
```

Codex 새 버전 회귀는 [`CONTRIBUTING.md`](CONTRIBUTING.md)의 회귀 절차(Claude Code 측 `.claude/` 빌드 파이프라인 재실행)로 매핑 테이블을 자동 갱신합니다. 문제 보고 시 `codex --version` 함께 [issue tracker](https://github.com/neibc/codex_harness/issues)로.

---

## 기여 / Contributing · 라이선스 / License · 감사 / Acknowledgements

- 기여 가이드: [`CONTRIBUTING.md`](CONTRIBUTING.md), 보안 신고: [`SECURITY.md`](SECURITY.md), 변환 손실: [`LIMITATIONS.md`](LIMITATIONS.md)
- License: [Apache-2.0](LICENSE) (원본 [`revfactory/harness`](https://github.com/revfactory/harness)와 동일)
- Acknowledgements:
  - [`revfactory/harness`](https://github.com/revfactory/harness) — 원본 플러그인. 7-Phase 워크플로우와 SKILL.md+references 구조의 출처
  - **OpenAI Codex CLI** — 포팅 대상 런타임. 플러그인/MCP 아키텍처가 이 포팅을 가능하게 함
  - **Anthropic Claude Code** — 이 포트를 빌드한 개발 하네스 (`.claude/` 참조)
