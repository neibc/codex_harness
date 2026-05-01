---
name: codex-internals-map
description: OpenAI Codex CLI의 1차 primitive와 확장점을 빠르게 조회하는 지식베이스. 서브커맨드, 플러그인 시스템, MCP 클라이언트/서버, 프롬프트 파일, AGENTS.md, hooks, config.toml, sandbox, exec 모드 등을 다룬다. Codex 동작 원리, "codex가 X를 지원하는가", "codex의 Y는 Claude Code의 Z에 해당하는가" 같은 질문이 나오면 반드시 이 스킬을 참조하라. Codex 하네스 포팅, MCP 서버 작성, 프롬프트 변환 작업 시에도 사용.
---

# Codex Internals Map

OpenAI Codex CLI(`@openai/codex`)의 확장점을 한 페이지에 모은 빠른 참조. 정확한 최신 사양은 `references/codex-cli-spec.md`에 보관하고, SKILL.md는 의사결정용 요약만 담는다.

## 1. Codex CLI 한눈에

| 항목 | 값 |
|------|----|
| 패키지 | `@openai/codex` (npm 글로벌, 내부는 Rust 바이너리) |
| 실행 | `codex` (interactive), `codex exec` (non-interactive), `codex review`, `codex sandbox`, `codex mcp-server` |
| 설정 | `~/.codex/config.toml` |
| 프로젝트 지침 | `AGENTS.md` (Claude Code의 `CLAUDE.md`에 대응) |
| 플러그인 | `codex plugin marketplace` 서브커맨드 (마켓 형식 + 매니페스트) |
| MCP 클라이언트 | `codex mcp add/remove/list/get` |
| MCP 서버로 노출 | `codex mcp-server` (stdio) |

> 위 표의 **현재 시점 정확한 형식**은 `codex-internals-analyst` 에이전트가 실측하여 `_workspace/01_codex_primitives.md`에 기록한다. 이 SKILL.md는 의사결정 지도이지 사양서가 아니다.

## 2. 확장점 의사결정 — Claude 자산을 어디에 매핑할까

| Claude Code 자산 | Codex 1순위 매핑 | 2순위 / 폴백 |
|------------------|------------------|---------------|
| `.claude/skills/<name>/SKILL.md` (slash trigger) | `prompts/<name>.md` (Codex prompt 파일) | AGENTS.md 섹션 |
| `.claude/skills/.../references/*.md` | 같은 위치에 그대로 (Codex가 prompt에서 상대경로 참조) | 단일 파일에 인라인 |
| `.claude/agents/<name>.md` | `agents/<name>.md` + AGENTS.md에 페르소나 등록 | MCP 도구로 래핑 |
| `Agent` 도구 (subagent_type) | `codex exec` 서브프로세스 + 작업 디렉토리 격리 | MCP 도구가 내부적으로 `codex exec` 호출 |
| `TeamCreate` / `SendMessage` / `TaskCreate` | **MCP 팀 서버** (자체 구현) | 파일 IPC, 단일 컨텍스트 직렬 시뮬레이션 |
| Hooks (settings.json) | Codex hooks (있다면 그대로) | shell wrapper로 codex 호출 전후 처리 |
| `CLAUDE.md` | `AGENTS.md` | — |

자세한 매핑 근거와 예시는 `references/mapping-rationale.md` 참조.

## 3. 비대응 항목

Codex는 다음을 1차 primitive로 제공하지 **않는다**(현재 분석 시점 기준 — 항상 `01_codex_primitives.md` 최신본으로 재확인):

- **명시적 Agent Team 선언** — 팀 생성/팀원 간 직접 메시지 전송이 빌트인으로 없음
- **TaskCreate 류의 공유 작업 큐** — 컨텍스트 내 메모리에는 있으나 다른 프로세스와 공유되는 표준 형식 없음
- **빌트인 subagent_type 카테고리** — Claude Code의 `Explore`, `Plan` 같은 분류 없음

→ 이 결손은 **`team-emulation-mcp` 스킬의 MCP 팀 서버 패턴**으로 메운다.

## 4. 실측 절차 (분석 에이전트용)

`codex-internals-analyst` 에이전트는 다음 순서를 따른다:

1. `codex --version` — 버전 고정
2. `codex --help`, 모든 서브커맨드 `--help` — 표면 카탈로그
3. `~/.codex/` 트리 inspect — 설정/프롬프트/세션 저장 위치 확인
4. `codex mcp list`, `codex plugin marketplace --help` — 확장점 형식
5. GitHub `openai/codex` 저장소(가능 시) — 소스에서 매니페스트 schema 확인
6. 결과를 `_workspace/01_codex_primitives.md`로 정리

상세 체크리스트는 `references/analyst-checklist.md`.

## 5. 자주 막히는 함정

- **Codex는 Rust 바이너리이므로 npm 패키지 내부에 JS 소스가 없다** — 동작 검증은 GitHub 저장소나 `--help` 출력에 의존.
- **Codex의 `mcp-server` ≠ MCP 서버 빌딩 키트** — Codex 자신을 MCP 서버로 노출하는 모드. 우리가 만들 팀 서버와 다른 개념. 헷갈리면 `references/mcp-direction-glossary.md` 참조.
- **`codex exec`의 입출력 형식**(JSON/streaming)은 버전마다 변경된 이력이 있다 — 빌더는 버전을 README에 고정하라.

## 참조

- `references/codex-cli-spec.md` — 서브커맨드별 정확한 인자/출력 사양 (실측치 누적)
- `references/mapping-rationale.md` — 매핑 결정 근거와 거절된 대안
- `references/analyst-checklist.md` — Codex 분석 시 빠뜨리지 말 항목
- `references/mcp-direction-glossary.md` — Codex가 MCP 클라이언트일 때 vs 서버일 때 vs 우리가 만든 팀 서버의 구분
