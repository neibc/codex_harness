# Team Emulation Dependency — MCP 팀 서버 의존성

> **Status:** Active · **대상:** Codex CLI 0.136.0+ · **최종 갱신:** 2026-07-05

이 문서는 `codex_harness`가 왜 **MCP 팀 서버(`mcp-team-server/`)에 의존**하는지, codex의 멀티-에이전트 지원이 바뀔 때 이 저장소가 각 경우에 무엇을 할지를 설명한다. revfactory 원본의 [`experimental-dependency.md`](https://github.com/revfactory/harness)에 상응하는 Codex판이다 — 원본이 Claude Code의 Agent Teams **실험 플래그** 의존을 문서화했다면, 본 포트는 같은 효과를 **에뮬레이션**으로 얻으므로 그 에뮬레이션 계층의 의존성을 문서화한다.

> **EN summary:** revfactory/harness depends on Claude Code's experimental Agent Teams flag. This Codex port has no such flag — Codex 0.136 exposes no user-callable multi-agent primitive, so the port emulates `TeamCreate`/`SendMessage`/`Task*` through a small stdio MCP server (`mcp-team-server/`) backed by SQLite. This document explains that dependency and what happens when Codex ships (or breaks) a native surface.

---

## 현재 상태 / Current State

### 왜 에뮬레이션이 필요한가

revfactory `harness`는 `claude "build a harness for <domain>"` 실행 시 Claude Code의 1차 primitive를 내부에서 호출한다. Codex 0.136에는 이에 대응하는 **사용자 호출 가능 표면이 없다** — `codex debug prompt-input` 덤프에 spawn/subagent/sendmessage 도구가 0회, `multi_agent`는 stable이나 도구 표면 미노출, `multi_agent_v2`/`enable_fanout`은 under development(미출시). 따라서 텍스트 번역만으로는 동작하지 않고, MCP 팀 서버가 그 자리를 메운다.

| Claude Code primitive | 목적 | Codex 측 (에뮬레이션) |
|---|---|---|
| `TeamCreate` | 공유 컨텍스트를 가진 팀 인스턴스화 | MCP `team_create` |
| `SendMessage` | 팀원 간 메시지 라우팅(리더 ↔ 워커) | MCP `send_message` + `recv_messages`(폴링) |
| `TaskCreate`/`TaskUpdate`/`TaskList` | 팀 내 장기 작업 보드 | MCP `task_create`/`task_update`/`task_list`/`task_get_output` |
| (런타임 종료) | 팀 정리 | MCP `team_destroy` |
| `Agent` 도구(단일 디스패치) | 단일 에이전트 실행 | `codex exec --json --ephemeral - < agents/<name>.md` (에뮬레이션 불필요, 네이티브) |

### 등록 방식 (심링크 canonical)

MCP 팀 서버는 `codex mcp add`로 등록한다. `./install.sh`가 자동 수행하며, 수동으로는:

```bash
cd mcp-team-server && npm install && npm run build && cd ..
codex mcp add team --env TEAM_STORAGE_PATH=$HOME/.codex/teams.sqlite \
  -- node "$(pwd)/mcp-team-server/dist/index.js"
codex mcp list   # team 항목이 보여야 함
```

> 표준 마켓플레이스 install(`codex plugin add`)도 `.mcp.json`의 `mcpServers`를 자동 등록하지만, codex 0.136이 본 저장소의 루트 레이아웃을 해소하지 못해 실패한다([`../LIMITATIONS.md`](../LIMITATIONS.md) §15). 그래서 `codex mcp add`가 canonical 경로다.

### 저장소 / Storage

- `~/.codex/teams.sqlite` (WAL 모드). `TEAM_STORAGE_PATH`로 override.
- 여러 `codex exec` 서브프로세스가 같은 SQLite를 공유하므로 에이전트들이 실제로 메시지·작업 상태를 주고받는다.
- 메시지·작업 본문은 **평문 저장**된다 — 민감 데이터 처리 시 [`../SECURITY.md`](../SECURITY.md)의 hardening 권고 참조.

### 팀/멤버 존재 검증 (T19)

원본 `SendMessage`가 잘못된 수신자에 에러를 주는 동작을 에뮬레이션한다: `send_message`/`recv_messages`/`task_*`는 진입 시 팀 존재를 검증하고(없거나 archived면 `team not found or archived: <id>` isError), 멤버명(`from`/`to`/`as`/`owner`)이 팀 members에 없으면 `unknown member: <name>` isError를 반환한다(단 `to:"*"` 브로드캐스트 허용). 이 검증이 없으면 team_id 오타가 조용히 메시지를 블랙홀에 버려 수신 에이전트가 무한 대기한다. 상세: [`../LIMITATIONS.md`](../LIMITATIONS.md) §1.

---

## 의존성 그래프 / Dependency Graph

```
codex_harness (v0.3.0)
  └── mcp-team-server (stdio MCP, TypeScript + SQLite)
        ├── team_create / send_message / recv_messages   ← SendMessage/TeamCreate 에뮬레이션
        ├── task_create / task_update / task_list / task_get_output  ← Task* 에뮬레이션
        └── team_destroy
              └── Codex 로드맵 (관찰 대상)
                    ├── Scenario A: 네이티브 multi_agent 도구 표면 출시
                    ├── Scenario B: goals feature 표면 안정화
                    └── Scenario C: MCP/skill 스키마 파괴적 변경
```

**위→아래로 읽는다:** 하네스는 MCP 팀 서버에 의존하고, 그 서버의 존재 이유는 codex에 네이티브 멀티-에이전트 표면이 없다는 점이다. codex가 이 표면을 출시·변경하면 이 저장소가 아래 절차대로 적응한다.

---

## 3가지 시나리오 / Scenarios

각 시나리오는 **감지 트리거**와 이 저장소가 취할 **조치**를 기술한다. 조치는 실재하는 회귀 절차 — [`../CONTRIBUTING.md`](../CONTRIBUTING.md)의 회귀 워크플로우와 `.claude/` 빌드 파이프라인 재실행 — 을 따른다. (원본과 달리 별도 nightly CI/SLA 인프라는 본 저장소에 없다. 회귀는 codex 버전 갱신 시 수동/파이프라인 재빌드로 처리한다.)

### Scenario A — 네이티브 multi_agent 도구 표면 출시 (GA)

**감지:** `codex features list`에서 `multi_agent_v2`/`enable_fanout`이 stable&true로 전환되고, `codex exec`/MCP에 spawn·sendmessage에 상응하는 사용자 호출 가능 도구가 노출됨.

**개연성(주관):** 중간~높음. 두 플래그가 이미 under development로 존재.

**조치:** (1) Phase A 재조사(`.claude/` 내 `codex-internals-analyst`)로 새 표면의 도구명·스키마 실측. (2) 번역 테이블(`_workspace/03_*`) 갱신 — 해당 primitive를 MCP 우회에서 네이티브로 재매핑. (3) SKILL.md/references의 `send_message`/`recv_messages` 폴링 지시를 네이티브 도구 호출로 교체, 폴링 오버헤드 제거. (4) `mcp-team-server`는 하위호환 폴백으로 유지하거나 deprecate. → [`../LIMITATIONS.md`](../LIMITATIONS.md) §10에 기록된 재포팅 계획.

**사용자 영향:** 긍정적. 폴링 지연이 사라지고 실시간 조율이 개선된다. 생성된 `agents/`·`skills/` 파일은 순수 Markdown이라 그대로 유효하다.

### Scenario B — goals feature 표면 안정화

**감지:** codex `goals`(0.136에서 stable&true이나 표면 Unknown)의 도구명·스키마·팀 스코프가 문서화/실측됨.

**개연성(주관):** 중간. 개념이 하네스 Task*와 중첩 가능.

**조치:** (1) `goals`의 감사 추적(task_history 대응)·의존성(blocked_by 대응)·산출물 회수(task_get_output 대응) 지원 여부 실측. (2) 충분하면 `task_*` 백엔드를 `goals`로 교체 검토, 부족하면 관찰 유지. → [`../LIMITATIONS.md`](../LIMITATIONS.md) §14 거절 기록의 재검토 트리거.

**사용자 영향:** 중립. 채택 시 저장소 계층(sqlite)이 codex 관리 상태로 이동할 수 있으나 도구 호출 계약은 유지 목표.

### Scenario C — MCP / skill 스키마 파괴적 변경

**감지:** codex 새 버전이 `codex mcp add` 인자 형식, `.mcp.json` 스키마, `~/.codex/skills/` 자동 스캔, `${CODEX_PLUGIN_ROOT}` 치환 중 하나를 변경 → `tests/smoke.sh` 또는 실사용에서 회귀.

**개연성(주관):** 중간. 0.125→0.136 사이에도 profile v2·hook trust·default_permissions 등 표면 변화가 있었다.

**조치:** (1) `tests/smoke.sh` 재실행으로 영향 범위 격리. (2) `install.sh`/`.mcp.json`/`bin/update.sh`의 해당 호출부 패치. (3) [`../README.md`](../README.md) 버전 호환표에 영향받은 codex 버전 행 추가. (4) 비자명한 변경이면 [`../CONTRIBUTING.md`](../CONTRIBUTING.md) 회귀 절차로 매핑 테이블 재빌드.

**사용자 영향:** 이전 codex 버전 고정 사용자는 무영향. 최신 사용자는 같은 사이클 내 패치.

---

## 서버 미등록 시 열화 / Degradation without the server

MCP 팀 서버가 등록되지 않았거나(`codex mcp list`에 `team` 없음) 빌드되지 않았다면(`mcp-team-server/dist/index.js` 부재), 하네스는 **완전히 죽지 않고 열화**된다:

- **폴백:** 오케스트레이터가 팀 조율(메시지/작업 보드) 대신 **서브에이전트 `codex exec` fan-out**으로 전환한다 — 병렬 `codex exec --json --ephemeral - < agents/<name>.md` 호출 + JSONL 결과 수집(`references/orchestrator-template.md` 템플릿 B).
- **잃는 것:** 실시간 메시지 교환, 공유 작업 보드 기반 조율, 브로드캐스트 종료 신호. 팬아웃→팬인 1회성 작업은 여전히 동작하지만 상호작용적 협업은 약해진다.
- **복구:** `./install.sh` 재실행 또는 위 "등록 방식" 수동 명령.

---

## 엔터프라이즈 도입 FAQ

### Q1. 규제 산업이라 사용자 홈에 평문 sqlite를 두기 어렵다. 어떻게 도입하나?

**조치:** (a) `TEAM_STORAGE_PATH`를 프로젝트별 경로(예: `./_workspace/teams.sqlite`)로 격리, (b) 작업 종료 후 `team_destroy({archive:false})`로 hard-delete 또는 sqlite 파일 직접 `rm`, (c) `chmod 600`. 또는 **design-time only**로 사용 — 샌드박스에서 `agents/`·`skills/`를 생성해 커밋하면, 생성된 산출물은 순수 Markdown이라 팀 서버 없이도 라우팅에 쓰인다. 상세: [`../SECURITY.md`](../SECURITY.md).

### Q2. codex가 네이티브 멀티-에이전트를 출시하면 내 하네스가 깨지나?

**조치:** 사용자 조치 불필요. 생성된 `agents/*.md`·`skills/*`는 평문 Markdown이라 유효하게 남는다. 폴링 지시는 Scenario A에서 이 저장소가 갱신한다.

### Q3. 폴링 지연이 얼마나 되나?

**조치:** 수신자가 매 turn `recv_messages`를 호출하는 구조라, 지연은 폴링 인터벌(1s→2s→4s, max 30s 지수 증가)에 묶인다. 짧은 ping-pong 대화에서 가장 두드러지고, 오케스트레이터→워커 팬아웃에서는 무시할 만하다. 상세: [`../LIMITATIONS.md`](../LIMITATIONS.md) §1.

---

**관련 문서:**
- [`quickstart.md`](./quickstart.md) — 5분 설치 워크스루
- [`../LIMITATIONS.md`](../LIMITATIONS.md) — 변환 손실 15항목 (특히 §1 폴링, §10 재포팅 계획, §15 마켓 레이아웃)
- [`../README.md`](../README.md) — "Agent Team 에뮬레이션 — 무엇이 보존되고 무엇이 다른가" 섹션
- [`../SECURITY.md`](../SECURITY.md) — 디스크 저장 데이터 + hardening
