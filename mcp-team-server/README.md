# mcp-team-server (placeholder)

Agent Team 에뮬레이션을 담당할 MCP 서버. Phase C 빌더가 이 디렉토리를 다음 구조로 채웁니다:

```
mcp-team-server/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts        # MCP server entry (stdio)
│   ├── tools.ts        # team_create, send_message, recv_messages, task_*
│   ├── storage.ts      # SQLite 또는 JSONL backend
│   └── types.ts
└── dist/               # tsc 빌드 산출물 (gitignored)
```

설계 명세:
- 도구 시그니처: [`../.claude/skills/team-emulation-mcp/SKILL.md`](../.claude/skills/team-emulation-mcp/SKILL.md)
- 스토리지 schema: [`../.claude/skills/team-emulation-mcp/references/storage-schema.md`](../.claude/skills/team-emulation-mcp/references/storage-schema.md)
- 폴링 패턴: [`../.claude/skills/team-emulation-mcp/references/polling-patterns.md`](../.claude/skills/team-emulation-mcp/references/polling-patterns.md)

## 빌드 후 실행

```bash
npm install
npm run build
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | node dist/index.js
# → tools 목록이 JSON으로 응답되면 OK
```

## Codex 등록

```bash
codex mcp add team --command node --args "$(pwd)/dist/index.js"
codex mcp list   # team 항목이 보여야 함
```
