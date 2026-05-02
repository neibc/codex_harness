---
name: harness
description: "하네스를 구성합니다. 전문 에이전트를 정의하며, 해당 에이전트가 사용할 스킬을 생성하는 메타 스킬. (1) '하네스 구성해줘', '하네스 구축해줘' 요청 시, (2) '하네스 설계', '하네스 엔지니어링' 요청 시, (3) 새로운 도메인/프로젝트에 대한 하네스 기반 자동화 체계를 구축할 때, (4) 하네스 구성을 재구성하거나 확장할 때, (5) '하네스 점검', '하네스 감사', '하네스 현황', '에이전트/스킬 동기화' 등 기존 하네스 운영/유지보수 요청 시 사용."
metadata:
  short-description: "Agent Team & Skill Architect — Codex port of revfactory/harness."
---

# Harness — Agent Team & Skill Architect (Codex port)

도메인/프로젝트에 맞는 하네스를 구성하고, 각 에이전트의 역할을 정의하며, 에이전트가 사용할 스킬을 생성하는 메타 스킬.

> **Codex 환경 안내**: 본 스킬은 revfactory의 Claude Code `harness` 1.2.0을 Codex CLI로 포팅한 것이다. Claude의 1차 primitive(`Agent`/`TeamCreate`/`SendMessage`/`TaskCreate`)는 Codex에 없다. 각각 다음으로 대체된다:
> - `Agent(...)` → `codex exec --json --ephemeral -C <iso-dir> --prompt-file agents/<name>.md "<task>"` 서브프로세스
> - `TeamCreate/SendMessage/TaskCreate/...` → MCP team server (`mcp-team-server/`)의 도구 호출
> - `subagent_type=Explore` → `--sandbox read-only` 플래그
>
> 손실 항목 전체는 [`LIMITATIONS.md`](../../LIMITATIONS.md) 참조.

**핵심 원칙:**
1. 에이전트 정의(`프로젝트/agents/`)와 스킬(`프로젝트/skills/`)을 생성한다.
2. **에이전트 팀을 기본 실행 모드로 사용한다.** 팀 통신은 MCP team server의 도구 호출로 수행한다.
3. **AGENTS.md에 하네스 포인터를 등록한다.** — Codex는 cwd의 단일 AGENTS.md만 자동 로드(upward search 없음)하므로 모든 도메인 트리거를 한 파일에 집약한다.
4. **하네스는 고정물이 아니라 진화하는 시스템이다.** — 매 실행 후 피드백을 반영하고, 에이전트·스킬·AGENTS.md를 지속 갱신한다.

## 워크플로우

### Phase 0: 현황 감사

하네스 스킬이 트리거되면 가장 먼저 기존 하네스 현황을 확인한다.

1. `프로젝트/agents/`, `프로젝트/skills/`, `프로젝트/AGENTS.md`를 읽는다 (Read 도구).
2. 현황에 따라 실행 모드를 분기한다:
   - **신규 구축**: 에이전트/스킬 디렉토리가 없거나 비어있음 → Phase 1부터 전체 실행
   - **기존 확장**: 기존 하네스가 있고 새 에이전트/스킬 추가 요청 → Phase 선택 매트릭스에 따라 필요한 Phase만 실행
   - **운영/유지보수**: 기존 하네스의 감사·수정·동기화 요청 → Phase 7-5 운영/유지보수 워크플로우로 이동

   **기존 확장 시 Phase 선택 매트릭스:**
   | 변경 유형 | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 | Phase 6 |
   |----------|---------|---------|---------|---------|---------|---------|
   | 에이전트 추가 | 건너뜀 (Phase 0 결과 활용) | 배치 결정만 | 필수 | 전용 스킬 필요 시 | 오케스트레이터 수정 | 필수 |
   | 스킬 추가/수정 | 건너뜀 | 건너뜀 | 건너뜀 | 필수 | 연결 변경 시 | 필수 |
   | 아키텍처 변경 | 건너뜀 | 필수 | 영향받는 에이전트만 | 영향받는 스킬만 | 필수 | 필수 |
3. 기존 에이전트/스킬 목록과 AGENTS.md 라우팅 표를 대조하여 불일치(drift)를 감지한다.
4. 감사 결과를 사용자에게 요약 보고하고, 실행 계획을 확인받는다.

### Phase 1: 도메인 분석
1. 사용자 요청에서 도메인/프로젝트 파악
2. 핵심 작업 유형 식별 (생성, 검증, 편집, 분석 등)
3. Phase 0 감사 결과를 기반으로 기존 에이전트/스킬과의 충돌/중복 분석
4. 프로젝트 코드베이스 탐색 — 기술 스택, 데이터 모델, 주요 모듈 파악
5. **사용자 숙련도 감지** — 대화의 맥락 단서(사용 용어, 질문 수준)로 기술 수준을 파악하고, 이후 커뮤니케이션 톤을 조절한다.

### Phase 2: 팀 아키텍처 설계

#### 2-1. 실행 모드 선택

**에이전트 팀이 최우선 기본값이다.** 2개 이상의 에이전트가 협업할 때는 반드시 에이전트 팀을 먼저 검토한다.

| 모드 | 언제 사용 | Codex 구현 |
|------|----------|----------|
| **에이전트 팀** (기본) | 2명 이상 협업, 실시간 조율·피드백 교환 | MCP team server: `team_create` + `send_message` + `task_create` 호출 |
| **서브 에이전트** (대안) | 단일 에이전트 작업, 결과만 반환하면 충분 | `codex exec --json --ephemeral -C <iso-dir> --prompt-file agents/<name>.md` 서브프로세스. 병렬은 shell `&` + `wait` |
| **하이브리드** | Phase마다 특성이 다를 때 | Phase 단위로 팀/서브를 섞어 구성 |

**의사결정 순서:**
1. 먼저 에이전트 팀으로 설계 가능한지 검토한다 — 2명 이상이면 기본값
2. 팀 통신이 구조적으로 불필요하고(결과 전달만), 팀 오버헤드가 이득보다 클 때만 서브 에이전트 선택
3. Phase별 특성이 확연히 다르면 하이브리드 고려

> 상세 비교표와 패턴별 의사결정 트리는 `references/agent-design-patterns.md`의 "실행 모드" 참조.

#### 2-2. 아키텍처 패턴 선택

작업을 전문 영역으로 분해 후 다음 중 선택 (`references/agent-design-patterns.md` 참조):
- **파이프라인**, **팬아웃/팬인**, **전문가 풀**, **생성-검증**, **감독자**, **계층적 위임**

#### 2-3. 에이전트 분리 기준

전문성·병렬성·컨텍스트·재사용성 4축으로 판단한다. 상세 기준표는 `references/agent-design-patterns.md`의 "에이전트 분리 기준" 참조.

### Phase 3: 에이전트 정의 생성

**모든 에이전트는 반드시 `프로젝트/agents/{name}.md` 파일로 정의한다.** Codex `codex exec` 호출 시 prompt에 역할을 직접 넣는 것은 금지한다.

**모델 설정:** `codex exec -m <model>` 또는 `--profile <p>`로 명시. 본 하네스의 권장 등급은 "최고 추론 등급"(Codex의 `gpt-5.4` 등). 에이전트 정의 frontmatter의 `model:` 필드는 사람용 안내(Codex가 자동 인식하지는 않음).

**팀 재구성:** 에이전트 팀은 같은 sqlite 저장소를 공유하므로, Phase 간에 `team_destroy` 후 새 `team_create`로 팀을 교체할 수 있다. 이전 팀의 산출물은 파일(`_workspace/`)로 보존한다.

각 에이전트를 `프로젝트/agents/{name}.md`에 정의한다. 필수 섹션: 핵심 역할, 작업 원칙, 입력/출력 프로토콜, 에러 핸들링, 협업. 에이전트 팀 모드에서는 `## 팀 통신 프로토콜` 섹션을 추가하여 메시지 수신/발신 대상과 작업 요청 범위를 명시한다.

> 정의 템플릿과 실제 파일 전문은 `references/agent-design-patterns.md`의 "에이전트 정의 구조" + `references/team-examples.md` 참조.

**QA 에이전트 포함 시 필수 사항:**
- QA 에이전트는 일반 (sandbox 미적용) 모드를 사용하라. `--sandbox read-only`로는 검증 스크립트 실행 불가.
- QA의 핵심은 "존재 확인"이 아니라 **"경계면 교차 비교"**.
- QA는 전체 완성 후 1회가 아니라, **각 모듈 완성 직후 점진적으로 실행** (incremental QA).
- 상세 가이드: `references/qa-agent-guide.md` 참조.

**자체 페르소나 5개**: 본 플러그인의 `agents/` 디렉토리에는 메타-하네스를 빌드한 페르소나 5종(claude-harness-cartographer, codex-internals-analyst, codex-plugin-builder, codex-harness-qa, primitive-translator)이 동봉된다. 사용자가 자기 도메인용 새 에이전트를 만들 때는 이 5개를 덮어쓰지 말고 자신의 cwd에 새로 작성한다.

**외부 자료 수집(웹 검색/페치) 도구 — Codex 환경 한계:**
revfactory 원본 환경(Claude Code)에는 `WebSearch`/`WebFetch` 빌트인이 있지만, **Codex CLI에는 없다**. 도메인이 외부 자료 수집을 요구하면(예: 학술 문헌 조사, 사이트 탐색, 사실 검증):

1. **에이전트 정의의 `tools:` frontmatter에 사용 도구를 명시한다** (사람용 안내 + 호출 시점 점검표):
   ```yaml
   ---
   name: literature-researcher
   description: ...
   tools: web_search, web_fetch, Read, Write
   ---
   ```
2. **외부 MCP 서버 등록을 사용자에게 안내한다** — 트리거링 안내 섹션에 예: `codex mcp add web-search -- npx -y @modelcontextprotocol/server-fetch`. 사용자가 별도 설치하지 않으면 해당 에이전트의 외부 자료 깊이가 제한된다.
3. **자료 수집 결과 깊이 기준을 SKILL.md 본문에 명시한다** — "수집 항목 N개 이상", "각 항목에 출처 메타데이터 포함" 등. 외부 도구가 약하면 산출물이 짧아지므로 도메인이 깊이를 요구할 때 사용자가 명시적 정량 기준을 요구하면 보완된다.

이 한계를 무시하면 외부 자료 수집 도메인의 산출물이 Claude Code 원본 대비 약 5~8배 짧아지는 패턴이 관측되었다(`leehongjang` 사례 참조).

### Phase 4: 스킬 생성

각 에이전트가 사용할 스킬을 `프로젝트/skills/{name}/SKILL.md`에 생성한다. Codex는 plugin manifest의 `"skills": "./skills/"` 디렉토리를 자동 주입하며, 별도 invocation 도구 없이 모델이 SKILL.md를 직접 read 한다(progressive disclosure). 상세 작성 가이드는 `references/skill-writing-guide.md` 참조.

#### 4-1. 스킬 구조

```
skill-name/
├── SKILL.md (필수)
│   ├── YAML frontmatter (name, description 필수)
│   └── Markdown 본문
└── Bundled Resources (선택)
    ├── scripts/    - 반복/결정적 작업용 실행 코드
    ├── references/ - 조건부 로딩하는 참조 문서
    └── assets/     - 출력에 사용되는 파일
```

#### 4-2. Description 작성 — 적극적 트리거 유도

Codex 0.125.0의 심링크 install 경로(`~/.codex/skills/<name>/`)에서는 **슬래시 명령이 노출되지 않는다** — 슬래시는 플러그인 정식 install(TUI 경유 `commands/<name>.md` 등록) 경로에서만 작동. 따라서 Codex 사용자에게는 **자연어 트리거 발화와 비대화형 호출(`codex exec --prompt-file`)을 명시**하라. description은 자연어 매칭이 잘 일어나도록 적극적("pushy")으로 작성한다.

**나쁜 예:** `"PDF 문서를 처리하는 스킬"`
**좋은 예:** `"PDF 파일 읽기, 텍스트/테이블 추출, 병합, 분할, 회전, 워터마크, 암호화, OCR 등 모든 PDF 작업을 수행. .pdf 파일을 언급하거나 PDF 산출물을 요청하면 반드시 이 스킬을 사용할 것."`

#### 4-3. 본문 작성 원칙

| 원칙 | 설명 |
|------|------|
| **Why를 설명하라** | "ALWAYS/NEVER" 같은 강압적 지시 대신, 왜 그렇게 해야 하는지 이유를 전달한다. |
| **Lean하게 유지** | SKILL.md 본문은 500줄 이내를 목표로, 무게를 벌지 않는 내용은 references/로 이동한다. |
| **일반화하라** | 원리를 설명하여 다양한 입력에 대응할 수 있게 한다. 오버피팅 금지. |
| **반복 코드는 번들링** | 공통 스크립트는 `scripts/`에 미리 번들링한다. |
| **명령형으로 작성** | "~한다", "~하라" 형태의 어조를 사용한다. |

#### 4-4. Progressive Disclosure

| 단계 | 로딩 시점 | 크기 목표 |
|------|----------|----------|
| **Metadata** (name + description) | 항상 컨텍스트에 존재 (Codex `<skills_instructions>` 자동 주입) | ~100단어 |
| **SKILL.md 본문** | 모델이 read | <500줄 |
| **references/** | 필요할 때만 | 무제한 |

#### 4-5. 스킬-에이전트 연결 원칙

- 에이전트 1개 ↔ 스킬 1~N개 (1:1 또는 1:다)
- 여러 에이전트가 공유하는 스킬도 가능
- 스킬은 "어떻게 하는가"를 담고, 에이전트는 "누가 하는가"를 담는다

> 상세 작성 패턴, 예시, 데이터 스키마 표준은 `references/skill-writing-guide.md` 참조.

### Phase 5: 통합 및 오케스트레이션

오케스트레이터는 스킬의 특수한 형태로, 개별 에이전트와 스킬을 하나의 워크플로우로 엮어 팀 전체를 조율한다. 구체적 템플릿은 `references/orchestrator-template.md` 참조.

**기존 확장 시 오케스트레이터 수정:** 신규 구축이 아닌 기존 확장일 때는 오케스트레이터를 새로 생성하지 않고 기존 오케스트레이터를 수정한다.

#### 5-0. 오케스트레이터 패턴 (모드별)

**에이전트 팀 패턴 (기본):**
오케스트레이터(리더)가 MCP team server를 호출하여 팀을 구성하고, 작업을 등록한다.

```
[오케스트레이터/리더]
    ├── team_create({team_name, members})
    ├── task_create({...}) × N (의존성 포함)
    ├── 팀원 prompt 호출 (codex exec --prompt-file agents/<name>.md)
    │     팀원은 매 turn 시작 시 recv_messages 폴링, 끝에 send_message 호출
    ├── task_list({status: ["pending","in_progress"]}) 폴링
    ├── 결과 수집 (task_get_output)
    └── team_destroy({archive: true})
```

**서브 에이전트 패턴 (대안):**
오케스트레이터가 `codex exec` 서브프로세스를 직접 호출한다. 병렬 실행은 shell `&` + `wait`.

```
[오케스트레이터]
    ├── codex exec --json --ephemeral -C _workspace/a/ --prompt-file agents/agent-1.md "..." > a.jsonl &
    ├── codex exec --json --ephemeral -C _workspace/b/ --prompt-file agents/agent-2.md "..." > b.jsonl &
    ├── wait
    ├── 각 events.jsonl 에서 마지막 agent_message 회수
    └── 통합 산출물 생성
```

**하이브리드 패턴:**
Phase마다 다른 모드를 섞어 구성한다. 자주 쓰이는 조합:
- **병렬 수집(서브) → 합의 통합(팀)**
- **팀 생성(팀) → 검증(서브)**
- **Phase 간 팀 재구성**: 각 Phase마다 `team_destroy` 후 새 `team_create`, 사이에 `codex exec` 서브 호출 삽입

하이브리드 선택 시 오케스트레이터의 각 Phase 섹션 상단에 해당 Phase의 실행 모드를 명시한다.

#### 5-1. 데이터 전달 프로토콜

| 전략 | 방식 | 적용 모드 | 적합한 경우 |
|------|------|----------|-----------|
| **메시지 기반** | MCP `send_message`/`recv_messages` (push + polling) | 팀 | 실시간 조율, 피드백 교환 |
| **태스크 기반** | MCP `task_create`/`task_update`/`task_get_output` | 팀 | 진행상황 추적, 의존 관계 관리 |
| **파일 기반** | 약속된 경로에 파일을 쓰고 읽음 | 팀 + 서브 | 대용량 데이터, 구조화된 산출물, 감사 추적 |
| **JSONL 이벤트** | `codex exec --json` stdout 파싱 | 서브 | 서브프로세스 결과 회수 |

**권장 조합 (팀 모드):** 태스크 기반(조율) + 파일 기반(산출물) + 메시지 기반(실시간 소통)
**권장 조합 (서브 모드):** JSONL 이벤트(결과 수집) + 파일 기반(대용량 산출물)

파일 기반 전달 시 규칙:
- 작업 디렉토리 하위에 `_workspace/` 폴더를 만들어 중간 산출물 저장
- 파일명 컨벤션: `{phase}_{agent}_{artifact}.{ext}` (예: `01_analyst_requirements.md`)
- 최종 산출물만 사용자 지정 경로에 출력, 중간 파일은 보존 (사후 검증·감사 추적용)

#### 5-2. 에러 핸들링

오케스트레이터 내에 에러 처리 방침을 포함한다. 핵심 원칙: 1회 재시도 후 재실패 시 해당 결과 없이 진행(보고서에 누락 명시), 상충 데이터는 삭제하지 않고 출처 병기.

> 에러 유형별 전략표와 구현 상세는 `references/orchestrator-template.md`의 "에러 핸들링" 참조.

#### 5-3. 팀 크기 가이드라인

| 작업 규모 | 권장 팀원 수 | 팀원당 작업 수 |
|----------|------------|--------------|
| 소규모 (5~10개 작업) | 2~3명 | 3~5개 |
| 중규모 (10~20개 작업) | 3~5명 | 4~6개 |
| 대규모 (20개+ 작업) | 5~7명 | 4~5개 |

> 팀원이 많을수록 조율 오버헤드(폴링, 메시지 누적)가 커진다. 3명의 집중된 팀원이 5명의 산만한 팀원보다 낫다.

#### 5-4. AGENTS.md 하네스 포인터 등록

하네스 구성 완료 후, 프로젝트의 `AGENTS.md`(cwd 자동 로드)에 최소한의 포인터를 등록한다. Codex는 upward search를 하지 않으므로 **루트 cwd에 모든 도메인 트리거 + 라우팅 표를 집약**해야 한다.

**AGENTS.md 템플릿:**

````markdown
## 하네스: {도메인명}

**목표:** {하네스의 핵심 목표 한 줄}

**트리거:** {도메인} 관련 작업 요청 시:
- 인터랙티브: `codex` 진입 후 `/{orchestrator-skill-name}`
- 비대화형: `codex exec --prompt-file skills/{orchestrator-skill-name}/SKILL.md "<요청>"`

**변경 이력:**
| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| {YYYY-MM-DD} | 초기 구성 | 전체 | - |
````

**AGENTS.md에 넣지 않는 것:** 에이전트 목록, 스킬 목록, 디렉토리 구조 상세, 실행 규칙 상세. 단 **에이전트 호출 라우팅 표와 MCP 도구 호출 표는 cwd-only 로딩 제약상 AGENTS.md에 명시**해야 한다.

#### 5-5. 후속 작업 지원

오케스트레이터는 초기 실행뿐 아니라 후속 작업도 처리해야 한다.

**1. 오케스트레이터 description에 후속 키워드 포함:**
- "다시 실행", "재실행", "업데이트", "수정", "보완"
- "{도메인}의 {부분작업}만 다시"

**2. 오케스트레이터 Phase 1에 컨텍스트 확인 단계 추가:**
- `_workspace/` 존재 + 사용자가 부분 수정 요청 → **부분 재실행** (해당 에이전트만 재호출)
- `_workspace/` 존재 + 사용자가 새 입력 제공 → **새 실행** (기존 _workspace를 `_workspace_prev/`로 이동)
- `_workspace/` 미존재 → **초기 실행**

**3. 에이전트 정의에 재호출 지침 포함**

> 오케스트레이터 템플릿의 "Phase 0: 컨텍스트 확인" 섹션 참조: `references/orchestrator-template.md`

### Phase 6: 검증 및 테스트

상세 테스트 방법론은 `references/skill-testing-guide.md` 참조.

#### 6-1. 구조 검증
- 모든 에이전트 파일이 `프로젝트/agents/`에 있는지 확인
- 스킬의 frontmatter(name, description) 검증
- 에이전트 간 참조 일관성 확인
- AGENTS.md 라우팅 표가 실제 파일과 일치하는지 확인

#### 6-2. 실행 모드별 검증
- **에이전트 팀**: MCP 도구 호출 경로(`team_create`/`send_message` 등), 작업 의존성, 팀 크기 적정성 확인
- **서브 에이전트**: 각 에이전트의 입출력 연결, `codex exec` JSONL 이벤트 파싱, 마지막 메시지 회수 로직 확인
- **하이브리드**: 각 Phase의 실행 모드가 오케스트레이터에 명시되었는지, Phase 경계에서 데이터 전달이 끊기지 않는지 확인

#### 6-3. 스킬 실행 테스트

생성된 각 스킬에 대해 실제 실행 테스트를 수행한다:

1. **테스트 프롬프트 작성** — 각 스킬에 대해 2~3개의 현실적인 테스트 프롬프트를 작성한다.
2. **With-skill vs Without-skill 비교 실행** — `codex exec --prompt-file <skill>` vs `codex exec` 두 호출을 병렬로 수행하여 부가가치 확인.
3. **결과 평가** — 정성적(사용자 리뷰) + 정량적(assertion) 평가.
4. **반복 개선 루프** — 피드백을 일반화하여 스킬 수정 후 재테스트.
5. **반복 패턴 번들링** — 공통 코드는 `scripts/`에 번들링.

#### 6-4. 트리거 검증

각 스킬의 description이 올바르게 트리거되는지 검증한다:

1. **Should-trigger 쿼리** (8~10개) — 스킬을 트리거해야 하는 다양한 표현
2. **Should-NOT-trigger 쿼리** (8~10개) — near-miss 쿼리

> Codex 0.125.0 심링크 install 경로에서는 슬래시 명령이 노출되지 않는다. 자연어 매칭 + `codex exec --prompt-file` 양쪽이 모두 동작하는지 확인한다. 활성화 검증: `codex debug prompt-input "x" 2>/dev/null | grep -o '<skill-name>:[^"]*' | head -1`.

#### 6-5. 드라이런 테스트

- 오케스트레이터 스킬의 Phase 순서가 논리적인지 검토
- 데이터 전달 경로에 빈 구간(dead link)이 없는지 확인
- 모든 에이전트의 입력이 이전 Phase의 출력과 매칭되는지 확인

#### 6-6. 테스트 시나리오 작성

- 오케스트레이터 스킬에 `## 테스트 시나리오` 섹션 추가
- 정상 흐름 1개 + 에러 흐름 1개 이상 기술

### Phase 7: 하네스 진화

하네스는 한 번 만들고 끝나는 정적 산출물이 아니다.

#### 7-1. 실행 후 피드백 수집
매 하네스 실행 완료 후, 사용자에게 피드백을 요청한다.

#### 7-2. 피드백 반영 경로

| 피드백 유형 | 수정 대상 | 예시 |
|-----------|----------|------|
| 결과물 품질 | 해당 에이전트의 스킬 | "분석이 너무 피상적" → 스킬에 깊이 기준 추가 |
| 에이전트 역할 | 에이전트 정의 `.md` | "보안 검토도 필요" → 새 에이전트 추가 |
| 워크플로우 순서 | 오케스트레이터 스킬 | "검증을 먼저 해야" → Phase 순서 변경 |
| 팀 구성 | 오케스트레이터 + 에이전트 | "이 둘은 합쳐도 될 듯" → 에이전트 병합 |
| 트리거 누락 | 스킬 description | description 확장 |

#### 7-3. 변경 이력

모든 변경은 AGENTS.md의 **변경 이력** 테이블에 기록한다.

#### 7-4. 진화 트리거

사용자가 명시적으로 "하네스 수정해줘"라고 할 때만이 아니라, 다음 상황에서도 진화를 제안한다:
- 같은 유형의 피드백이 2회 이상 반복될 때
- 에이전트가 반복적으로 실패하는 패턴이 발견될 때
- 사용자가 오케스트레이터를 우회하여 수동으로 작업하는 것이 관찰될 때

#### 7-5. 운영/유지보수 워크플로우

기존 하네스의 점검·수정·동기화를 체계적으로 수행한다.

**Step 1: 현황 감사** — `agents/` 와 `skills/` 디렉토리 목록을 AGENTS.md 라우팅 표와 대조하여 불일치 목록 생성. 사용자에게 보고.

**Step 2: 점진적 추가/수정** — 변경은 한 번에 하나씩.

**Step 3: AGENTS.md 변경 이력 갱신** — 날짜, 변경 내용, 대상, 사유 기록.

**Step 4: 변경 검증** — Phase 6-1 구조 검증 → 트리거 영향 시 6-4 검증 → 대규모 변경 시 6-3, 6-5까지 수행.

## Codex MCP 팀 서버 도구 — 빠른 참조

본 플러그인은 `mcp-team-server/`를 통해 8개 도구를 자동 등록한다(`.mcp.json`). prompt 본문에서 직접 호출:

| 도구 | 용도 | 예시 |
|---|---|---|
| `team_create({team_name, members, leader?})` | 팀 생성 | `team_create({team_name:"design", members:["a","b"]})` → `{team_id}` |
| `send_message({team_id, from, to, content, tags?})` | 메시지 송신 (push) | 수신자 명시 또는 `to:"*"` 브로드캐스트 |
| `recv_messages({team_id, as, since?, limit?})` | 메시지 수신 (polling) | 매 turn 시작 시 호출 — 폴링 인터벌 1~10s |
| `task_create({team_id, subject, description?, owner?, blocked_by?})` | 작업 생성 | status는 자동으로 `pending` |
| `task_update({team_id, task_id, status?, owner?, metadata?})` | 작업 갱신 | status 전이는 history 에 자동 기록 |
| `task_list({team_id, status?, owner?})` | 작업 목록 조회 | 종료 폴링용 |
| `task_get_output({team_id, task_id})` | 작업 산출물 회수 | metadata.output 반환 |
| `team_destroy({team_id, archive?})` | 팀 정리 | `archive:true`(기본)는 sqlite에 status=archived |

> 폴링 패턴 상세는 `references/orchestrator-template.md` 본문 참조.

## 사용자에게 트리거링 안내 — 필수

**하네스 구성을 종료하기 직전에 반드시 사용자에게 다음을 출력하라.** Codex 0.125.0의 심링크 install 경로에서는 슬래시 명령(`/<name>`)이 노출되지 않으므로 **유일한 진입점은 자연어 트리거 발화 + 비대화형 `codex exec`**다. 사용자가 새로 만든 하네스를 어떻게 다시 실행하는지 모른 채 끝나면 안 된다.

출력 템플릿 (한국어와 영어 둘 다):

```markdown
## ✅ 하네스 구성 완료 — 이제 어떻게 트리거하나요?

생성된 하네스: `<orchestrator-skill-name>` (위치: `skills/<orchestrator-skill-name>/SKILL.md` 또는 `~/.codex/skills/<orchestrator-skill-name>/`)

### 자연어 트리거 (인터랙티브 — 1차 진입)
Codex 인터랙티브에서 다음 발화 중 하나를 입력하세요:
- "**<도메인명>의 <대표 작업>을 해줘**" — 예: "전자상거래 백엔드 리뷰해줘"
- "**<오케스트레이터의 핵심 동사구>**" — 예: "결제 모듈 보안 감사 돌려줘"
- "**<직접 스킬 이름 호명>**" — 예: "<orchestrator-skill-name> 실행해줘"

> Codex 0.125.0 심링크 install 경로에서는 `/<orchestrator-skill-name>` 같은 슬래시 명령이 노출되지 않습니다. 위 자연어 발화로만 트리거됩니다.

### 비대화형 (스크립트/CI)
\`\`\`bash
codex exec --prompt-file skills/<orchestrator-skill-name>/SKILL.md "<요청>"
\`\`\`

### 활성화 확인
\`\`\`bash
codex debug prompt-input "x" 2>/dev/null | grep -o '<orchestrator-skill-name>:[^"]*' | head -1
# 출력이 보이면 활성화 완료
\`\`\`

### MCP 팀 서버
이 하네스는 다중 에이전트 협업을 위해 codex-harness의 MCP 팀 서버를 사용합니다. 등록되어 있지 않다면:
\`\`\`bash
codex mcp add team --env TEAM_STORAGE_PATH=$HOME/.codex/teams.sqlite \\
  -- node "/path/to/codex_harness/mcp-team-server/dist/index.js"
\`\`\`
```

**원칙:**
- `<orchestrator-skill-name>`, `<도메인명>`, `<대표 작업>`은 실제 이 세션에서 생성한 값으로 치환한다.
- 트리거 발화는 사용자가 그대로 복사해 붙여 즉시 작동해야 한다 — 추상적 표현 금지.
- AGENTS.md의 description과 일치하는 키워드를 자연어 트리거에 포함하라(트리거 매칭률 ↑).
- 영어로도 동일 안내를 짧게 추가하면 다국어 사용자에게 도움이 된다 (선택).

> 이 단계를 건너뛰면 사용자가 구성된 하네스를 영원히 못 찾을 수 있다. revfactory 원본 플러그인의 종료 안내를 Codex 환경에 맞춰 자연어 트리거 우선으로 변형한 결과다.

## 산출물 체크리스트

생성 완료 후 확인:

- [ ] `프로젝트/agents/` — **에이전트 정의 파일 필수 생성**
- [ ] `프로젝트/skills/` — 스킬 파일들 (SKILL.md + references/)
- [ ] 오케스트레이터 스킬 1개 (데이터 흐름 + 에러 핸들링 + 테스트 시나리오 포함)
- [ ] 실행 모드 명시 (에이전트 팀 / 서브 에이전트 / 하이브리드)
- [ ] 모든 `codex exec` 호출에 권장 모델/sandbox 명시
- [ ] 기존 에이전트/스킬과 충돌 없음
- [ ] 스킬 description이 적극적("pushy")으로 작성됨 — **후속 작업 키워드 포함**
- [ ] SKILL.md 본문이 500줄 이내, 초과 시 references/ 분리
- [ ] 테스트 프롬프트 2~3개로 실행 검증 완료
- [ ] 트리거 검증 (should-trigger + should-NOT-trigger) 완료
- [ ] **AGENTS.md에 하네스 포인터 + 라우팅 표 + MCP 도구 표 등록**
- [ ] **AGENTS.md 변경 이력에 에이전트/스킬 추가/삭제/수정 기록**
- [ ] **오케스트레이터 Phase 1에 컨텍스트 확인 단계** (초기/후속/부분 재실행 판별)
- [ ] **종료 직전 사용자에게 자연어 트리거 + 슬래시 + 비대화형 명령 + 활성화 확인 명령을 출력했음** (위 "사용자에게 트리거링 안내" 섹션의 템플릿 사용)

## 참고

- 하네스 패턴: `references/agent-design-patterns.md`
- 기존 하네스 예시: `references/team-examples.md`
- 오케스트레이터 템플릿: `references/orchestrator-template.md`
- **스킬 작성 가이드**: `references/skill-writing-guide.md`
- **스킬 테스트 가이드**: `references/skill-testing-guide.md`
- **QA 에이전트 가이드**: `references/qa-agent-guide.md`
- **Codex 변환 한계**: [`../../LIMITATIONS.md`](../../LIMITATIONS.md)
