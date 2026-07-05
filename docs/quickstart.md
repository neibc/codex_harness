# Quickstart — 5분 만에 첫 하네스 / 5 Minutes to Your First Harness

> **KR**: 이 문서는 최단 경로 요약입니다. 설치 옵션·트러블슈팅의 정본은 [`../README.md`](../README.md)이며, 여기서는 그 핵심만 5단계로 추립니다.
> **EN**: This is the shortest path. The canonical reference for install options and troubleshooting is [`../README.md`](../README.md); this doc distills its essentials into five steps.

**끝나면 갖게 되는 것 / What you'll have at the end:** 작업 디렉토리(cwd)에 도메인 특화 에이전트 2~5개(`agents/`), 이들이 쓰는 스킬(`skills/`), 그리고 트리거·라우팅을 담은 `AGENTS.md` — 한 문장 요청에서 생성됨.

**사전 요구 / Prerequisites:**
- **Codex CLI 0.136.0+** (`codex --version`), **node 18+** (`node --version`)
- `export`가 명령 사이에 유지되는 셸 (bash, zsh, fish)
- `github.com` 네트워크 접근

> Claude Code 원본과 달리 **실험 플래그(`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`)가 필요 없습니다.** 멀티-에이전트 조율은 본 저장소의 MCP 팀 서버가 담당하며 별도 ENV 게이트가 없습니다. 왜 그 서버가 필요한지는 [`team-emulation-dependency.md`](./team-emulation-dependency.md) 참조.

---

## Step 1 — 저장소 클론 (30초)

```bash
git clone https://github.com/neibc/codex_harness.git
cd codex_harness
```

**하는 일:** 본 플러그인(스킬 + MCP 팀 서버 + 매니페스트)을 로컬에 받습니다.

---

## Step 2 — 설치 (60초) — 심링크가 canonical

```bash
./install.sh
```

**하는 일:** node/codex 사전 검사 → `mcp-team-server` 빌드(`npm install` + `tsc`) → `codex mcp add team` 등록 → `~/.codex/skills/harness` 심링크 → 활성화 검증.

**기대 출력:** 마지막에 `✓ codex_harness 설치 완료`와 자연어 트리거 안내.

**실패 FAQ #1 — `harness 스킬이 prompt-input에 안 보임`**
**원인:** codex 세션 캐시가 아직 새 스킬을 못 읽음.
**해결:** `codex`를 재시작한 뒤 `codex debug prompt-input "x" 2>/dev/null | grep harness:harness` 로 확인. 그래도 없으면 `./install.sh` 재실행.

> ⚠️ `codex plugin marketplace add`/`codex plugin add`(2단계 마켓 경로)는 codex 0.136이 본 저장소의 루트==플러그인 레이아웃을 해소하지 못해 **실패**합니다. `./install.sh --marketplace`로 시도할 수 있으나 실패 시 심링크로 자동 폴백합니다. 근거: [`../LIMITATIONS.md`](../LIMITATIONS.md) §15.

---

## Step 3 — 한 문장으로 하네스 생성 (2분)

빈 작업 디렉토리로 이동한 뒤 `codex` 안에서 자연어로 요청합니다:

```bash
mkdir -p ~/work/fintech-risk && cd ~/work/fintech-risk
codex
> 핀테크 리스크 평가 팀을 위한 하네스를 구성해줘
```

**하는 일:** `harness` 메타-스킬이 도메인 문장을 분석해 전문 에이전트 + 스킬을 **현재 cwd**의 `agents/`·`skills/`·`AGENTS.md`에 생성합니다.

**대체 발화 (아무거나 동작):**
- `build a harness for a fintech risk-assessment team` (영어도 동작)
- `전자상거래 이상거래 탐지 워크플로우 하네스를 구성해줘`
- `design an agent team for technical due diligence on open-source repos`

**비대화형 / CI:**
```bash
codex exec "핀테크 리스크 평가 팀을 위한 하네스를 구성해줘"
```

**실패 FAQ #2 — 한국어 발화는 무응답, 영어는 성공**
**원인:** description 자연어 매칭 강도는 모델별로 다를 수 있음([`../LIMITATIONS.md`](../LIMITATIONS.md) §9).
**해결:** 영어 발화로 재시도하세요 — 내부 스킬은 동일합니다. 둘 다 실패하면 실패 FAQ #3으로.

---

## Step 4 — 생성 파일 확인 (30초)

```bash
ls -la agents/ skills/ AGENTS.md
```

**하는 일:** 메타-스킬이 파일을 기대 위치(`.claude/`가 아니라 **cwd**)에 썼는지 확인합니다.

**기대 출력:** `agents/`에 2~5개, `skills/`에 1~2개, 그리고 도메인 트리거를 담은 `AGENTS.md`. 예(핀테크): `agents/risk-analyst.md`, `agents/compliance-reviewer.md`, `skills/risk-memo/SKILL.md`.

**실패 FAQ #3 — "아무것도 생성 안 됨" / 디렉토리 비어 있음**
**원인:** 스킬이 활성화되지 않았거나 트리거 매칭 실패.
**해결:** `codex debug prompt-input "x" 2>/dev/null | grep harness:harness` 로 활성화 확인 → 없으면 Step 2 재실행. 있으면 Step 3을 영어 발화로 재시도.

---

## Step 5 — 새 팀에 샘플 작업 실행 (90초)

현실적인 티켓형 프롬프트를 방금 만든 팀에 넘깁니다:

```bash
codex "티켓 FIN-427: 중견 제조사(연매출 800억, 한국)가 50억 운전자본 한도를 신청했다. (1) 신용 이력 위험신호, (2) 기존 포트폴리오 대비 섹터 집중도, (3) 규제 노출(KFTC/FSC)을 다루는 리스크 평가를 작성하고, go/no-go 권고가 담긴 1페이지 메모로 출력해."
```

**하는 일:** `AGENTS.md` 라우팅이 요청을 방금 생성한 팀 패턴(리스크 작업은 보통 생성-검증 또는 전문가 풀)으로 흘려보내 구조화된 메모를 반환합니다.

**실패 FAQ #4 — "팀이 실행 안 됨 / 한 에이전트만 응답"**
**원인:** MCP 팀 서버가 등록 안 됨 → 오케스트레이터가 팀 조율 대신 단일 에이전트로 열화.
**해결:** `codex mcp list`에 `team`이 있는지 확인. 없으면 `./install.sh` 재실행(또는 [`team-emulation-dependency.md`](./team-emulation-dependency.md)의 수동 등록). 그래도 안 되면 서브에이전트 `codex exec` fan-out 폴백으로 동작하되 실시간 조율은 약해집니다.

**실패 FAQ #5 — "API 호출이 너무 많음 / 비용 우려"**
**원인:** 멀티-에이전트 팀은 작업당 여러 병렬 `codex exec` 호출로 팬아웃될 수 있음.
**해결:** 하네스 구성 요청 시 "**작업 복잡도에 맞춰 최소한으로**" 또는 "**단일 스킬로 만들어줘**"를 명시([`../README.md`](../README.md)의 "When to use / When NOT to use"). 소규모 도메인은 팀 오버헤드가 이득을 넘습니다.

---

## 완료 / You're done

이 시점에서 다음을 갖추게 됩니다:

- [x] 도메인 특화 에이전트가 담긴 `agents/` 디렉토리
- [x] 이들이 쓰는 스킬이 담긴 `skills/` 디렉토리
- [x] 트리거 + 라우팅 표가 담긴 `AGENTS.md`
- [x] 샘플 작업 1회 성공 실행

**다음에 읽을 것 / Next reads:**
- [`team-emulation-dependency.md`](./team-emulation-dependency.md) — MCP 팀 서버가 왜 필요한지, codex가 네이티브 멀티-에이전트를 출시하면 어떻게 할지
- [`../LIMITATIONS.md`](../LIMITATIONS.md) — Claude Code → Codex 변환 손실 15항목
- [`../README.md`](../README.md) — 설치 옵션·트러블슈팅·유지보수 정본

**이 가이드가 못 다룬 문제를 만났다면:** `codex --version`, 실패한 Step, 정확한 에러 메시지를 담아 [issue tracker](https://github.com/neibc/codex_harness/issues)에 `quickstart-gap` 라벨로 올려주세요.
