# codex_harness

**Agent Team & Skill Architect — Codex CLI port of [revfactory/harness](https://github.com/revfactory/harness)**

이 저장소는 **두 가지 역할**을 동시에 수행합니다:

1. **Codex 플러그인** — `codex` CLI 사용자가 설치하면 동작하는 하네스 메타-스킬
2. **Claude Code 개발 하네스** — 이 플러그인을 만들고 유지보수하는 데 사용한 메타-하네스 (`.claude/` 하위)

Claude Code 개발자는 `.claude/skills/codex-harness-orchestrator`로 빌드를 자동화하고, Codex 사용자는 루트의 `prompts/` · `agents/` · `mcp-team-server/`만 사용합니다. 두 흐름은 같은 저장소를 공유합니다.

## Codex 사용자용 빠른 설치

```bash
# 1) 저장소 클론
git clone https://github.com/<your-org>/codex_harness.git
cd codex_harness

# 2) MCP 팀 에뮬레이션 서버 빌드
cd mcp-team-server && npm install && npm run build && cd ..

# 3) Codex에 등록
codex mcp add team --command node --args "$(pwd)/mcp-team-server/dist/index.js"
codex plugin install .
```

> 정확한 명령은 Codex 버전마다 다를 수 있습니다. `codex plugin --help`, `codex mcp add --help`로 실측 확인하세요. `codex-internals-analyst`가 `_workspace/01_codex_primitives.md`에 최신 사양을 기록합니다.

설치 후:

```bash
codex
> /harness 도메인 분석 후 하네스 구성해줘
```

또는 비대화형:

```bash
codex exec --prompt-file prompts/harness.md "도메인 분석 후 하네스 구성해줘"
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
- **Phase C (Build)**: 루트의 `prompts/`, `agents/`, `mcp-team-server/`, `AGENTS.md`, `plugin.toml`, `tests/`를 채움
- **Phase D (Validate)**: smoke 테스트 + 경계면 검증

자세한 워크플로우: [`.claude/skills/codex-harness-orchestrator/SKILL.md`](.claude/skills/codex-harness-orchestrator/SKILL.md)

## 디렉토리 구조

```
codex_harness/
├── README.md                            # 이 파일
├── LICENSE                              # Apache-2.0 (원본과 동일)
├── .gitignore
├── CLAUDE.md                            # Claude Code 진입 지침
├── AGENTS.md                            # Codex 진입 지침 (빌더가 채움)
├── plugin.toml                          # Codex 플러그인 매니페스트 (빌더가 채움)
├── prompts/                             # Codex 슬래시/명시 호출 프롬프트 (빌더가 채움)
├── agents/                              # Codex 에이전트 페르소나 (빌더가 채움)
├── mcp-team-server/                     # Agent Team 에뮬레이션 MCP 서버 (빌더가 채움)
├── tests/
│   └── smoke.sh                         # 빌드 검증 (빌더가 채움)
├── .claude/                             # ── Claude Code 개발 하네스 ──
│   ├── agents/                          #    5개 에이전트 정의
│   └── skills/                          #    5개 스킬 (오케스트레이터 + 4 지식베이스)
└── _workspace/                          # 중간 산출물 (gitignored)
```

## 무엇을 옮겼고 무엇이 손실되는가

| Claude Code 원본 | Codex 포트 |
|---|---|
| Skill 자동 트리거 | 슬래시 트리거 + `codex exec --prompt-file` |
| `Agent` 도구 | `codex exec` 서브프로세스 |
| `TeamCreate` / `SendMessage` / `TaskCreate` | MCP 팀 서버 (`mcp-team-server/`) |
| `CLAUDE.md` | `AGENTS.md` |

Known limitations (메시지 전달이 폴링 기반, 자동 컨텍스트 압축 없음, WebFetch/WebSearch는 별도 MCP 서버 필요 등)는 빌드 후 `LIMITATIONS.md`에 자동 정리됩니다. 자세히는 [`.claude/skills/claude-codex-translation/references/lossy-conversions.md`](.claude/skills/claude-codex-translation/references/lossy-conversions.md).

## 라이선스

Apache-2.0 — 원본 [`revfactory/harness`](https://github.com/revfactory/harness) 라이선스를 그대로 따릅니다.

## 기여

- 버그/한계 발견 시 이슈로 보고
- Codex 새 버전 출시 시 `_workspace/01_codex_primitives.md`를 갱신하고 매핑 테이블 회귀
- 회귀 절차: [`.claude/skills/codex-harness-orchestrator/references/regression-protocol.md`](.claude/skills/codex-harness-orchestrator/references/regression-protocol.md)
