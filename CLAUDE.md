# codex_harness — 프로젝트 지침 (Claude Code)

이 저장소는 **두 환경이 공유하는 듀얼-네이처 프로젝트**다:

1. **Codex 플러그인** — 저장소 루트가 곧 Codex CLI 플러그인. 설치는 `install.sh`(심링크 + `codex mcp add`)가 canonical. marketplace 2단계(`codex plugin marketplace add` → `codex plugin add codex-harness@codex-harness-marketplace`)는 codex 0.136이 루트-레이아웃 마켓 소스를 해소하지 못해 옵트인/known limitation (LIMITATIONS #15).
   - 사용자 진입: `skills/`, `mcp-team-server/`, `AGENTS.md`, `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`
2. **Claude Code 개발 하네스** — 위 플러그인을 빌드/유지보수하는 메타-하네스가 `.claude/` 아래에 있다.
   - 진입점: `.claude/skills/codex-harness-orchestrator/SKILL.md`

Claude Code에서는 `.claude/`만 활성화되고, Codex에서는 루트의 plugin 트리만 활성화된다. 양쪽 모두 같은 git 저장소에 커밋된다.

## 하네스: codex-harness

**목표:** revfactory의 Claude Code `harness` 플러그인을 OpenAI Codex CLI 호환 플러그인으로 포팅한다. Codex가 1차 primitive로 제공하지 않는 Agent Team(`TeamCreate`/`SendMessage`/`TaskCreate`)을 MCP 서버(`mcp-team-server/`)로 에뮬레이션하여, Claude Code 사용자와 Codex 사용자가 같은 하네스 효과를 얻게 한다.

**트리거:** 다음 요청에 `codex-harness-orchestrator` 스킬을 사용하라.
- "codex 하네스 빌드/포팅", "harness를 codex로 변환", "codex용 plugin 만들기"
- "MCP 팀 서버 작성", "Agent Team 에뮬레이션 설계"
- 기존 빌드 결과물(`skills/`, `mcp-team-server/`, `AGENTS.md`, `.codex-plugin/`, `tests/`) 재실행/수정/보완/업데이트/재빌드/부분 재실행
- `_workspace/` 또는 루트 Codex 플러그인 트리 변경 요청

단순 질문(예: "codex CLI가 무엇인가요?")은 직접 응답 가능. 하네스 호출이 필요한지 판단 기준: **분석/설계/빌드/검증 중 2개 이상의 단계가 필요한가?** 그렇다면 오케스트레이터.

## 하네스: codex-quality (품질 격차 정비)

**목표:** Codex 산출물이 Claude 대비 분량·구조·깊이가 부족할 때, 동일 task를 양 환경에서 실측 비교하고 Codex 특성 기인을 진단해 SKILL.md/agents 프롬프트를 비침습적으로 정비한 뒤 재측정으로 검증한다. **revfactory 원본 추상화 보존 원칙**(LIMITATIONS.md #11) 안에서만 정비.

**트리거:** 다음 요청에 `codex-quality-orchestrator` 스킬을 사용하라.
- "Codex 품질 정비", "claude 대비 codex 격차 측정", "비교 실험 돌려줘"
- "프롬프트 튜닝/정비/다시 검증", "회귀 측정해줘"
- "프롬프트 패턴 카탈로그 갱신"

**작업 디렉토리:** 사이클 산출물은 `_workspace/quality/<ts>/` 아래 영속화. 다음 사이클은 이전 baseline을 비교 기준으로.

**팀:** 5명 — quality-evaluator(오케) / dual-environment-runner(양 환경 실행) / output-comparator(8축 비교) / prompt-engineer(가설+정비) / regression-tester(재측정).

## 작업 디렉토리 규칙

- 중간 산출물: `_workspace/<NN>_<artifact>.md` (gitignored, 사후 감사용)
- **최종 산출물: 프로젝트 루트의 Codex 플러그인 파일들** (`skills/`, `mcp-team-server/`, `tests/`, `AGENTS.md`, `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`, `LIMITATIONS.md`) — git 커밋 대상
- 이전 버전 보관: `_workspace/_archive/` (gitignored)
- `dist/` 서브디렉토리에 빌드 출력하지 **않는다** — 저장소 루트가 곧 설치 가능한 Codex 플러그인이다.
- 디렉토리 규약 상세: `.claude/skills/codex-harness-orchestrator/references/workspace-conventions.md`

## 빌더의 영역 / 보호 파일

빌더(`codex-plugin-builder`)가 갱신/생성하는 파일:
- `skills/**/*.md`, `mcp-team-server/{src,dist,package.json,tsconfig.json}`, `tests/smoke.sh`, `install.sh`, `bin/update.sh`
- `AGENTS.md`, `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`, `LIMITATIONS.md`
- 루트 `README.md`의 "Codex 사용자용 빠른 설치", "Known limitations" 섹션만 갱신

빌더가 함부로 손대지 않는 파일:
- `CLAUDE.md` (이 파일), `LICENSE`, `.gitignore`, `.claude/` 전체
- 사용자 수동 수정 흔적이 있는 파일 — 사용자 확인 후 진행

## 변경 이력

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-05-02 | 초기 하네스 구성 (5 에이전트 + 5 스킬 + 오케스트레이터) | 전체 | - |
| 2026-05-02 | 빌드 출력 경로를 `dist/codex-harness/` → 프로젝트 루트로 재배선 | 오케스트레이터, 패키징 스킬, 빌더 에이전트, workspace 규약, CLAUDE.md | 저장소 자체가 git에 push되어 codex plugin install . 으로 직접 설치되는 듀얼-네이처 구조로 통합 |
| 2026-05-02 | 루트 Codex 플러그인 스캐폴딩 (README, LICENSE, .gitignore, AGENTS.md/plugin.toml placeholder, prompts/agents/mcp-team-server/tests 빈 트리) | 루트 | 빌드 전에도 git 저장소가 일관된 Codex 플러그인 형상을 유지하도록 |
| 2026-05-02 | 신규 하네스 `codex-quality` 추가 (5 에이전트 + 4 스킬) | `.claude/agents/{quality-evaluator,dual-environment-runner,output-comparator,prompt-engineer,regression-tester}.md`, `.claude/skills/{codex-quality-orchestrator,dual-runtime-comparison,output-quality-metrics,codex-prompt-patterns}/SKILL.md` + references/×3 | Codex 산출물이 Claude 대비 5~8× 짧은 격차를 측정·진단·정비하는 사이클 자동화. revfactory 원본 추상화는 보존하면서 4가지 비침습 표면(frontmatter, 환경 박스, 호출 wrapper, AGENTS.md)에만 정비 적용 |
| 2026-05-02 | `codex-quality` Cycle 1 — 3개 환경 박스 추가 (+13줄) | `skills/harness/SKILL.md` Phase 2/3/6 끝 | 실측 격차(분량 8~29×, 변증법 ∞)에 대해 (a) 산출물 sub-item 분해, (b) 변증법 도메인 가이드, (c) 에이전트 정의 단서(Why+안 했을 때 문제) — 분량 강제는 Goodhart 함정으로 거부, 단서/구체성 풍부화로 재설계 |
| 2026-07-04 | Codex 0.136.0 + 원본 1.2.1+Unreleased 기준 전면 재빌드 (T1~T13) | plugin.json(0.3.0, factory 재포지셔닝), marketplace.json, install.sh/update.sh, SKILL.md(Phase 3-0/4-0 재사용 검토 이식), agent-design-patterns/skill-writing-guide(재사용 설계 섹션), LIMITATIONS(#4 hook trust 개정, #12~#14 신설), smoke.sh, README/AGENTS.md, CLAUDE.md 구조 서술 정정 | codex 0.125→0.136 델타(plugin install 명령 부재, hook trust 모델, JSONL 로그 누출)와 원본 upstream 델타(재사용 검토 체계, team-architecture factory 포지셔닝) catch-up |
| 2026-07-04 | Phase D 블로킹 회귀 (T14~T18) — 심링크 설치 canonical 환원, marketplace는 옵트인 강등 | install.sh/update.sh, README/AGENTS.md, LIMITATIONS #15 신설, mcp-team-server/README·SECURITY.md 스테일 정정, smoke.sh | QA end-to-end 실측: codex 0.136 marketplace 스캐너가 서브디렉토리 플러그인만 해소 — 루트==플러그인 듀얼-네이처 레이아웃과 비호환 (`path:"./"` add 실패). 듀얼-네이처 설계 보존 우선 |
