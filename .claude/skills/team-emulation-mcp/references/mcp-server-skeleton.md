# MCP Team Server — Skeleton (Node.js / TypeScript)

최소 동작 가능한 골격 코드. 빌더 에이전트가 이 스켈레톤을 시작점으로 채운다.

```
mcp-team-server/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts         # MCP server entry
│   ├── tools.ts         # team_create, send_message, etc.
│   ├── storage.ts       # SQLite or JSONL backend
│   └── types.ts
└── dist/                # 빌드 산출물
```

## package.json (예시)

```json
{
  "name": "codex-harness-team-server",
  "version": "0.1.0",
  "type": "module",
  "bin": { "team-server": "dist/index.js" },
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^x.y.z",
    "better-sqlite3": "^x.y.z"
  },
  "devDependencies": { "typescript": "^5.x" }
}
```

> 정확한 SDK 버전은 빌드 시점에 npm view로 확인.

## src/index.ts (스켈레톤)

```ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerTeamTools } from "./tools.js";
import { openStorage } from "./storage.js";

async function main() {
  const storage = openStorage(process.env.TEAM_STORAGE_PATH ?? "~/.codex/teams.sqlite");
  const server = new Server(
    { name: "codex-harness-team", version: "0.1.0" },
    { capabilities: { tools: {} } }
  );
  registerTeamTools(server, storage);
  await server.connect(new StdioServerTransport());
}
main().catch((e) => { console.error(e); process.exit(1); });
```

## src/tools.ts (요지)

```ts
export function registerTeamTools(server, storage) {
  server.setRequestHandler("tools/list", async () => ({
    tools: [
      { name: "team_create", inputSchema: { /* ... */ } },
      { name: "send_message", inputSchema: { /* ... */ } },
      { name: "recv_messages", inputSchema: { /* ... */ } },
      { name: "task_create", inputSchema: { /* ... */ } },
      { name: "task_update", inputSchema: { /* ... */ } },
      { name: "task_list", inputSchema: { /* ... */ } },
      { name: "team_destroy", inputSchema: { /* ... */ } }
    ]
  }));

  server.setRequestHandler("tools/call", async (req) => {
    switch (req.params.name) {
      case "team_create": return storage.createTeam(req.params.arguments);
      case "send_message": return storage.sendMessage(req.params.arguments);
      case "recv_messages": return storage.recvMessages(req.params.arguments);
      // ...
    }
    throw new Error(`unknown tool: ${req.params.name}`);
  });
}
```

## src/storage.ts (SQLite 예시)

```sql
CREATE TABLE IF NOT EXISTS teams (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  members TEXT NOT NULL,   -- JSON array
  leader TEXT,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  team_id TEXT NOT NULL,
  from_member TEXT NOT NULL,
  to_member TEXT NOT NULL,
  content TEXT NOT NULL,
  tags TEXT,
  ts TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  team_id TEXT NOT NULL,
  subject TEXT, description TEXT, owner TEXT,
  status TEXT NOT NULL,
  blocked_by TEXT,         -- JSON array
  metadata TEXT,           -- JSON
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

## 첫 빌드 검증

```bash
npm install
npm run build
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | node dist/index.js
# → tools 목록이 JSON으로 응답되면 OK
```
