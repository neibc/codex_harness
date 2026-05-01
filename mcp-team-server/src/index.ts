#!/usr/bin/env node
// codex-harness team server — stdio MCP entry point.
// Exposes 8 tools (team_create / send_message / recv_messages /
// task_create / task_update / task_list / task_get_output / team_destroy)
// backed by SQLite at ~/.codex/teams.sqlite (override via TEAM_STORAGE_PATH).

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { openStorage } from "./storage.js";
import { registerTeamTools } from "./tools.js";

async function main(): Promise<void> {
  const storage = openStorage();
  const server = new Server(
    {
      name: "codex-harness-team",
      version: "0.1.0",
    },
    {
      capabilities: {
        tools: {},
      },
    },
  );

  registerTeamTools(server, storage);

  const transport = new StdioServerTransport();
  await server.connect(transport);

  const shutdown = (): void => {
    try {
      storage.close();
    } catch {
      // ignore close errors at shutdown
    }
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main().catch((err: unknown) => {
  const message = err instanceof Error ? err.stack ?? err.message : String(err);
  process.stderr.write(`team-server fatal: ${message}\n`);
  process.exit(1);
});
