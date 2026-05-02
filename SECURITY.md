# Security Policy

## Reporting a vulnerability

If you discover a security issue in `codex_harness`, please **do not file a public issue**. Instead, contact the maintainer privately:

- Open a [GitHub Security Advisory](https://docs.github.com/en/code-security/security-advisories/repository-security-advisories) in this repository, or
- Email the maintainer (see repository profile / `git log`).

We will acknowledge receipt within a reasonable time and aim to publish a fix or mitigation in a subsequent release.

## Scope

In-scope concerns:

- Vulnerabilities in the **MCP team-emulation server** (`mcp-team-server/`) — e.g. unsafe SQL, path traversal in storage paths, untrusted-input handling in tool arguments.
- Plugin manifests (`.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`, `.mcp.json`) that could cause Codex to execute unexpected commands when installed (forward-compat schema; not active in 0.125.x).
- Documentation that misleads users into running unsafe commands.

Out of scope:

- Issues in upstream OpenAI Codex CLI itself — please report to the [OpenAI Codex repository](https://github.com/openai/codex).
- Issues in `revfactory/harness` upstream — please report there.
- Configuration mistakes by individual users (e.g. weakening Codex's `--sandbox` policy).

## What is stored on disk / 디스크에 저장되는 데이터

본 플러그인의 MCP 팀 서버는 `~/.codex/teams.sqlite` (또는 `TEAM_STORAGE_PATH` 지정 경로)에 다음을 **평문으로 영속화**합니다:

| 테이블 | 저장 내용 | 민감도 |
|---|---|---|
| `teams` | 팀명, 멤버 이름 목록, 리더, 생성 시각 | 낮음 (메타데이터) |
| `messages` | from/to 멤버명, **메시지 본문** (`content`), 태그, 타임스탬프 | **중간~높음** — 에이전트 간 주고받은 코드 스니펫·프롬프트가 포함될 수 있음 |
| `tasks` | subject, description, owner, status, **metadata.output** | **중간~높음** — 작업 산출물 본문이 metadata에 들어감 |
| `task_history` | task 상태 전이 기록 | 낮음 |

**암호화 없음**, **자동 만료 없음**. `team_destroy`는 기본적으로 archive 처리(`status=archived`)만 하고 행은 삭제하지 않습니다.

### Hardening 권고

- **Sandbox**: prefer `-s read-only` for analysis/exploration agents; reserve `workspace-write` for builders.
- **Storage path**: per-project로 분리하려면 `TEAM_STORAGE_PATH`를 설정하세요. 예: `TEAM_STORAGE_PATH=./_workspace/teams.sqlite`.
- **민감 코드 처리**: 회사 내부 코드, 비밀키, PII가 메시지/작업 본문으로 흘러들어갈 가능성이 있다면 (a) per-project sqlite로 격리, (b) 작업 종료 후 `team_destroy({archive: false})`로 hard-delete, (c) 또는 sqlite 파일을 작업 후 직접 `rm` 하세요.
- **공유 머신 / 멀티유저**: 기본 `~/.codex/teams.sqlite`는 사용자 홈 디렉토리에 있어 같은 OS 사용자 간에는 격리되지만, root나 다른 사용자가 읽을 수 있는 환경이라면 perms를 확인하세요 (`chmod 600 ~/.codex/teams.sqlite`).
- **Manifest review**: before running `codex plugin marketplace add`, inspect `.codex-plugin/plugin.json` and `.mcp.json` to confirm what gets registered.
