# codex_harness

> **Codex CLI에 '내 프로젝트 전담 AI 에이전트 팀'을 붙여주는 메타-스킬** ([revfactory/harness](https://github.com/revfactory/harness)의 Codex 포트).
>
> A meta-skill that gives the OpenAI Codex CLI a project-specific AI agent team — port of `revfactory/harness` from Claude Code.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Codex CLI](https://img.shields.io/badge/Codex_CLI-0.125.0%2B-black)](https://github.com/openai/codex)
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

> **외부 자료 수집이 핵심인 도메인 주의**: Codex CLI에는 `WebFetch`/`WebSearch` 빌트인이 없습니다. 위 예시처럼 외부 자료가 중심이라면 하네스 구성 전에 외부 MCP 서버를 미리 등록하세요 — 예: `codex mcp add fetch -- npx -y @modelcontextprotocol/server-fetch`. 등록하지 않으면 자료 수집 phase가 표면적으로 끝나 보고서 깊이가 떨어집니다 (자세히는 [LIMITATIONS.md #3, #11](LIMITATIONS.md), 본 README 하단 "솔직한 안내" 섹션).

코드 도메인 (Express 백엔드) 예시는 [`examples/node-cli/`](examples/node-cli/) 참조.

---

## 🚀 설치 / Install

### 한 줄 설치 (권장 / recommended)

```bash
git clone https://github.com/neibc/codex_harness.git
cd codex_harness
./install.sh
```

`install.sh`가 처리하는 것:
1. node 18+ / codex 0.125.0+ 사전 검사
2. `mcp-team-server` 빌드 (`npm install` + `tsc`)
3. `codex mcp add team` MCP 서버 등록
4. `~/.codex/skills/harness` 심링크 (저장소 변경 즉시 반영)
5. 활성화 검증 (`codex debug prompt-input`)
6. 다음 액션 안내 출력

이미 부분 설치되어 있으면 해당 단계만 skip / 충돌 시 안전 중단. 옵션: `--skip-build`, `--copy` (심링크 대신 복사), `--no-color`.

### 수동 설치 / Manual install

(자동화가 막힐 때만 사용)

```bash
git clone https://github.com/neibc/codex_harness.git && cd codex_harness
cd mcp-team-server && npm install && npm run build && cd ..
codex mcp add team --env TEAM_STORAGE_PATH=$HOME/.codex/teams.sqlite \
  -- node "$(pwd)/mcp-team-server/dist/index.js"
mkdir -p ~/.codex/skills && ln -sfn "$(pwd)/skills/harness" ~/.codex/skills/harness
codex debug prompt-input "x" 2>/dev/null | grep -o 'harness:[^"]*' | head -1   # 활성화 확인
```

> **`codex mcp list`만 실행하면 비어 보입니다.** Codex 0.125.x에서는 `codex mcp add` 후 등록되며, 플러그인 자체의 자동 활성화 CLI는 아직 없습니다 — 자세한 이유는 [Maintainers / 호환성 메모](#%EF%B8%8F-maintainers--codex-cli-version-compatibility) 참조.

---

## 🎯 첫 사용 / First use

```bash
codex
> 하네스를 구성해줘
```

7-Phase 워크플로우(도메인 분석 → 팀 아키텍처 → 에이전트/스킬 생성 → 통합·오케스트레이션 → 검증 → 진화)가 시작되고, **종료 시 어떤 자연어로 후속 트리거하는지 안내**가 출력됩니다.

비대화형 / CI:

```bash
codex exec "전자상거래 백엔드용 하네스를 구성해줘"
# 또는 SKILL.md 본문을 stdin으로 명시 주입:
#   codex exec - "전자상거래 백엔드용 하네스를 구성해줘" < skills/harness/SKILL.md
```

> Codex 0.125.x의 심링크 install 경로에서는 `/<name>` 슬래시 명령은 노출되지 않습니다 (별도 메커니즘). 자연어 발화로만 활성화됩니다.

활성화에 매칭되는 키워드: `하네스 구성/구축/설계/엔지니어링/점검/감사/현황`, `에이전트/스킬 동기화`, `harness`, `agent team`, `skill architect`.

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
| 슬래시 명령 미노출 | "하네스를 구성해줘" 자연어로만 트리거 |
| Codex 산출물 분량 | Claude Code 대비 5~8배 짧을 수 있음 (모델 보수성 + WebSearch/WebFetch 부재) — 명시적 깊이 요구로 보완 |
| MCP 메시지 전달 | polling 기반 (Claude의 push 대비 응답 지연 가능) |
| 데이터 저장 | `~/.codex/teams.sqlite`에 메시지·작업 본문 평문 저장 — [SECURITY.md](SECURITY.md) 참조 |
| Codex 버전 의존 | 0.125.0 검증, 0.128.0 smoke 통과. 미래 버전 회귀 가능 |

10개 손실 항목 전체: [LIMITATIONS.md](LIMITATIONS.md).

### 솔직한 안내 — Codex의 작업 분화/깊이 격차 / Honest note on output depth

**KR**: 같은 메타-스킬(SKILL.md)과 같은 프롬프트를 받아도 **Codex(GPT-5.x)는 Claude(Opus)보다 작업을 단순하게 처리하는 경향**이 있습니다. 실측에서 동일한 7-Phase 워크플로우를 받았을 때 Codex는 phase를 더 적게 펼치고, 각 phase의 본문을 짧게 끝냈습니다 (보고서 단어 수 14.9×, 중간 산출물 분량 29×, 변증법/대안 검토 키워드 ∞ 격차 — `~/codexwork/leehongjang` vs `~/claudework/saju` 비교, 자세히는 [LIMITATIONS.md #11](LIMITATIONS.md)).

본 플러그인은 이 격차를 좁히기 위해 SKILL.md 본문 옆에 **3개의 "Codex 환경 안내" 박스**를 부착했습니다 (Phase 2/3/6) — 작업 분화/단서/도메인별 검토 가이드. 그러나 **이 정비로 격차가 완전히 메워지지는 않습니다** — 모델 자체의 보수성, `WebFetch`/`WebSearch` 빌트인 부재, multi-agent 1차 primitive 부재 같은 환경 한계는 SKILL.md 변경으로 해결 불가입니다. revfactory 원본의 추상화를 보존하기로 한 결정 때문에, 분량/구조 강제(Goodhart 함정)도 의도적으로 거부했습니다.

가장 효과적인 보완은 **사용자의 명시 발화**입니다:
- "**변증법 phase 추가**" / "**양측 입장 steelman 분석**" — 비판적 검토 도메인
- "**산출물 sub-item을 도메인 맞게 구체 분해**" — phase 본문이 짧을 때
- "**작업 원칙에 'Why' + 안 했을 때 문제 함께**" — 에이전트 정의가 빈약할 때
- "**최종 보고서 ≥N 섹션, ≥N 인용**" — 분량/근거 요구 시 (단, 모델 부풀림 가능성 인지)

위 4가지 발화 중 도메인에 맞는 것을 하네스 구성 요청과 함께 보내면 격차가 부분적으로 좁혀집니다. **Claude 수준의 자율적 깊이는 현 환경에서 도달하기 어렵다**는 점이 본 포팅의 정직한 한계입니다.

---

**EN**: Given the **same** meta-skill (SKILL.md) and prompt, **Codex (GPT-5.x) tends to handle the task more simply than Claude (Opus)** — it splits the work into fewer phases and writes shorter bodies under each phase. In a real comparison (`~/codexwork/leehongjang` on Codex vs `~/claudework/saju` on Claude with the same upstream meta-skill), Codex produced a final report **14.9× shorter** (in words) and **29× less** intermediate workspace content; dialectic / counter-argument keywords appeared 7 times in saju but **0 times** in leehongjang ([LIMITATIONS.md #11](LIMITATIONS.md)).

To narrow this gap, the plugin attaches **three "Codex 환경 안내" callout boxes** to SKILL.md (Phases 2 / 3 / 6) — guidance on work decomposition, agent-definition cues, and domain-specific review. **These callouts do not fully close the gap.** The remaining causes (model conservatism, no built-in `WebFetch`/`WebSearch`, no first-class multi-agent primitive) are environment limits that no amount of SKILL.md editing can fix. We also intentionally rejected length/structure quotas (Goodhart's-Law trap), and we preserve revfactory's original abstractions, so the patches are deliberately conservative.

The most effective complement is **explicit user phrasing** at request time:
- "**Add a dialectic phase**" / "**steelman both sides**" — for domains where critical review matters
- "**Decompose each artifact into concrete sub-items for this domain**" — when phase bodies look thin
- "**Each work principle: include the why + the consequence of skipping**" — when agent definitions look thin
- "**Final report should have ≥N sections and ≥N citations**" — when length/grounding matters (with Goodhart caveat)

Combine the relevant phrasing above with your harness request, and the gap narrows. **Reaching Claude's level of autonomous depth is currently out of reach** — that's the honest limit of this port.

---


## 트러블슈팅

| 증상 | 원인 / 해결 |
|---|---|
| 자연어 발화에 스킬이 응답 안 함 | 활성화 누락. `~/.codex/skills/harness` 심링크 존재 확인 + `codex debug prompt-input "x" \| grep harness:harness` 로 검증 |
| `codex mcp list`가 비어 있음 | Step 3 누락. `codex mcp add team ...` 실행 |
| 자연어로도 활성화 안 됨 | Step 4 누락. `~/.codex/skills/harness` 심링크 확인 |
| 활성화 검증 | `codex debug prompt-input "x" 2>/dev/null \| grep -o 'harness:[^"]*' \| head -1` |
| `mcp-team-server/dist/index.js` 없음 | Step 2 빌드 누락. `cd mcp-team-server && npm install && npm run build` |
| 비대화형으로 우회 | `codex exec "<요청>"` — skill 활성화돼 있으면 자연어 매칭. 또는 `codex exec - "<요청>" < skills/harness/SKILL.md`로 본문을 stdin 주입 |
| 산출물 분량이 Claude Code 대비 짧음 | Codex(GPT-5.4)는 같은 가이드를 받아도 Claude(Opus)보다 보수적으로 phase를 줄이는 경향 + `WebSearch`/`WebFetch` 빌트인 부재로 외부 자료 수집이 약함. **하네스 구성 시 명시적으로 깊이 요구**: "변증법적 검토 phase 추가해줘", "방법론 비평 phase 포함해줘", "Phase별 정량 완료 조건(예: 카탈로그 ≥10개) 명시해줘", "최종 보고서 ≥10 섹션·≥400줄로", 또는 "자료 수집 에이전트의 `tools:` frontmatter에 외부 MCP(web search/fetch) 명시" |

> **외부 자료 수집이 핵심인 도메인에서**: Codex에는 `WebSearch`/`WebFetch` 빌트인이 없으므로, 하네스 구성 전에 외부 MCP 서버를 먼저 등록하라 — 예: `codex mcp add fetch -- npx -y @modelcontextprotocol/server-fetch`. 그렇지 않으면 외부 자료 수집 phase가 표면적으로 끝나고 산출물 깊이가 Claude Code 원본 대비 5~8배 짧아질 수 있습니다 (`~/codexwork/leehongjang` 사례 — 동일 메타-스킬·동일 자료를 받았으나 사주 사례(`~/claudework/saju`) 대비 보고서 8배 짧음). 이 격차의 정확한 원인은 [`LIMITATIONS.md`](LIMITATIONS.md)의 "Output depth on Codex" 항목 참조.

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

---

# 🛠️ For maintainers

여기서부터는 플러그인 자체를 유지보수하거나 회귀 검증을 하는 사람을 위한 섹션입니다. 일반 사용자는 위 섹션까지만 보면 됩니다.

## 어떻게 작동하는가 (개요)

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

`.codex-plugin/`, `.agents/plugins/marketplace.json`, `.mcp.json`은 **현재 0.125.x에서 활성화 동작 없음 — forward-compat schema만**. canonical 활성화 경로는 `codex mcp add` + `~/.codex/skills/<name>/` 심링크입니다.

## How it works — English summary

`codex_harness` ports `revfactory/harness` (a Claude Code meta-skill that auto-designs agent teams + skills for any domain) to OpenAI Codex CLI. Codex lacks first-class multi-agent primitives, so the port emulates `TeamCreate` / `SendMessage` / `Task*` through a small stdio MCP server backed by SQLite (WAL).

After installation, **trigger with natural language** ("build a harness for ..."). Codex 0.125.x's slash command surface (`/<name>`) is gated behind plugin marketplace install via the TUI, which the symlink-based install path used here does not exercise. Skills are activated through description matching instead.

The `.codex-plugin/`, `.agents/plugins/marketplace.json`, and `.mcp.json` files match the schema used by official OpenAI plugins (vercel, cloudflare) and are kept as **forward-compat only** — the canonical activation path on 0.125.x is `codex mcp add` + a symlink at `~/.codex/skills/<name>/`. Lossy translations are documented in [`LIMITATIONS.md`](LIMITATIONS.md) (11 items).

The repository is dual-runtime: it ships as a Codex plugin AND contains the Claude Code build pipeline (`.claude/`) that regenerates the Codex-side files when Codex CLI ships a new version.

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

> 이전 버전에 있던 루트 `agents/×5`와 `hooks/`는 **0.125.x에서 효과가 없어 제거**되었습니다 (`agents/`는 dev-time 페르소나, `hooks/`는 `plugin_hooks` under-development). `multi_agent_v2`/`enable_fanout`/`plugin_hooks`가 stable 전환되면 다시 도입 검토.

## Codex CLI 버전 호환성 / Version Compatibility

| Codex CLI 버전 | 상태 |
|---|---|
| `< 0.125.0` | **미지원**. stable feature(`plugins=true`, `multi_agent=true`, `skill_mcp_dependency_install=true`, `~/.codex/skills/` 자동 스캔)가 없거나 다를 수 있음 |
| `0.125.0` | **테스트 완료** — README의 모든 명령이 실측 검증됨 |
| `0.128.0` | **smoke test 통과** (외부 검증). 활성화·MCP 등록·스킬 매칭 모두 동작. 새 schema/feature 변동은 미실측 |
| `> 0.128.0` (미래) | 호환 가능성 높지만 미실측. 주의 영역: `codex plugin marketplace add` 동작, plugin.json schema, `codex mcp add` 인자 형식, `~/.codex/skills/` 자동 스캔 |

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
