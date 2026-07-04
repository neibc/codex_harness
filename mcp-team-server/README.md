# codex-harness-team-server

Agent Team 에뮬레이션 MCP 서버. Claude Code의 1차 primitive(`TeamCreate`/`SendMessage`/`TaskCreate` 등)가 Codex CLI에 부재하므로, 외부 stdio MCP 서버로 동등 도구 8개를 제공한다.

## 구조

```
mcp-team-server/
├── package.json
├── tsconfig.json
├── README.md
└── src/
    ├── index.ts        # MCP server entry (stdio)
    ├── tools.ts        # 8개 도구 등록
    ├── storage.ts      # SQLite (better-sqlite3, WAL) 백엔드
    └── types.ts        # 도구 입출력 타입
```

빌드 산출물은 `dist/`에 떨어진다 (`.gitignore` 권장 — repo에는 소스만).

## 도구

| 도구 | 용도 |
|---|---|
| `team_create` | 팀 등록, `team_id` 반환 |
| `send_message` | 메시지 push (append-only). `to: "*"` 브로드캐스트 |
| `recv_messages` | 폴링 수신. `since`는 ISO ts 또는 message_id 정수 |
| `task_create` | 작업 등록 (status=`pending`) |
| `task_update` | status/owner/metadata 갱신. 모든 변경은 `task_history`에 기록 |
| `task_list` | 작업 목록 조회 (status/owner 필터) |
| `task_get_output` | 작업 산출물(`metadata.output`) 회수 |
| `team_destroy` | 팀 archive (default) 또는 hard delete |

상세 schema는 `src/tools.ts`와 [`../skills/harness/SKILL.md`](../skills/harness/SKILL.md) 참조.

## 빌드

```bash
cd mcp-team-server
npm install
npm run build
```

## 실행 (수동)

```bash
node dist/index.js
# 또는
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | node dist/index.js
# → 8개 도구가 JSON으로 응답되면 OK
```

## Codex 등록

**Codex 0.136에서는 `codex mcp add` 수동 등록이 canonical path입니다.** 다음 명령으로 등록:

```bash
codex mcp add team --env TEAM_STORAGE_PATH=$HOME/.codex/teams.sqlite \
  -- node "$(pwd)/dist/index.js"
codex mcp list   # team 항목이 보여야 함
```

> `.codex-plugin/plugin.json`의 `mcpServers` 키와 `./.mcp.json`은 표준 마켓플레이스 install이 **자동 등록하는 등록 소스**입니다 (실측 2026-07-04: 서브디렉토리 레이아웃 플러그인이면 `codex plugin add` 후 `codex mcp list`에 team이 자동 등장, `${CODEX_PLUGIN_ROOT}` 런타임 해소). 다만 codex 0.136 마켓 스캐너는 플러그인이 마켓 루트의 **서브디렉토리**에 있어야 해소하는데, 본 저장소는 루트==플러그인 레이아웃(`source.path:"./"`)이라 마켓 경로가 실패합니다 ([`../LIMITATIONS.md`](../LIMITATIONS.md) §15). 그래서 위 `codex mcp add`(심링크 canonical)가 실제 등록 경로이고, 마켓은 `--marketplace` 옵트인입니다.

## 저장소

- 기본 경로: `~/.codex/teams.sqlite` (단일 파일, WAL 모드)
- 환경변수 override: `TEAM_STORAGE_PATH`
- DDL은 `src/storage.ts`의 상수 `DDL` 참조

## 알려진 한계

- 동기 도착 통지 없음 — 수신자는 매 turn `recv_messages` 폴링 필요. 자세히는 [`../LIMITATIONS.md`](../LIMITATIONS.md) §1.
- 다중 머신 협업 시 sqlite 파일을 사용자가 공유 (NFS/Sync 등).
