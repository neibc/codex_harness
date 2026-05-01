// Tool registration for codex-harness MCP team server.
// Registers 8 tools per _workspace/03_translation_table.md §2.2.

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type Tool,
} from "@modelcontextprotocol/sdk/types.js";
import type { Storage } from "./storage.js";
import type {
  RecvMessagesInput,
  SendMessageInput,
  TaskCreateInput,
  TaskGetOutputInput,
  TaskListInput,
  TaskUpdateInput,
  TeamCreateInput,
  TeamDestroyInput,
} from "./types.js";

const TOOLS: Tool[] = [
  {
    name: "team_create",
    description: "Create a team and return its id.",
    inputSchema: {
      type: "object",
      required: ["team_name", "members"],
      properties: {
        team_name: { type: "string" },
        members: {
          type: "array",
          items: { type: "string" },
          minItems: 1,
        },
        leader: {
          type: "string",
          description: "default: members[0]",
        },
      },
    },
  },
  {
    name: "send_message",
    description:
      "Push a message into a team's append-only message log. Use to='*' for broadcast.",
    inputSchema: {
      type: "object",
      required: ["team_id", "from", "to", "content"],
      properties: {
        team_id: { type: "string" },
        from: { type: "string" },
        to: {
          type: "string",
          description: "member name or '*' for broadcast",
        },
        content: { type: "string" },
        tags: { type: "array", items: { type: "string" } },
      },
    },
  },
  {
    name: "recv_messages",
    description:
      "Poll messages addressed to `as` (or broadcast) since a cursor. Cursor may be ISO ts or message_id integer.",
    inputSchema: {
      type: "object",
      required: ["team_id", "as"],
      properties: {
        team_id: { type: "string" },
        as: { type: "string" },
        since: {
          oneOf: [{ type: "string" }, { type: "integer" }],
          description: "ISO8601 ts or message_id cursor",
        },
        limit: { type: "integer", default: 50 },
      },
    },
  },
  {
    name: "task_create",
    description: "Create a task in pending state.",
    inputSchema: {
      type: "object",
      required: ["team_id", "subject"],
      properties: {
        team_id: { type: "string" },
        subject: { type: "string" },
        description: { type: "string" },
        owner: { type: "string" },
        blocked_by: { type: "array", items: { type: "string" } },
      },
    },
  },
  {
    name: "task_update",
    description:
      "Update a task's status / owner / metadata. Each update is recorded in task_history.",
    inputSchema: {
      type: "object",
      required: ["team_id", "task_id"],
      properties: {
        team_id: { type: "string" },
        task_id: { type: "string" },
        status: {
          type: "string",
          enum: [
            "pending",
            "in_progress",
            "completed",
            "blocked",
            "timed_out",
            "deleted",
          ],
        },
        owner: { type: "string" },
        metadata: { type: "object" },
      },
    },
  },
  {
    name: "task_list",
    description: "List tasks, optionally filtered by status / owner.",
    inputSchema: {
      type: "object",
      required: ["team_id"],
      properties: {
        team_id: { type: "string" },
        status: {
          oneOf: [
            { type: "string" },
            { type: "array", items: { type: "string" } },
          ],
        },
        owner: { type: "string" },
      },
    },
  },
  {
    name: "task_get_output",
    description:
      "Return the latest metadata.output value for a task, plus its status and updated_at.",
    inputSchema: {
      type: "object",
      required: ["team_id", "task_id"],
      properties: {
        team_id: { type: "string" },
        task_id: { type: "string" },
      },
    },
  },
  {
    name: "team_destroy",
    description:
      "Archive (default) or hard-delete a team and its messages/tasks/history.",
    inputSchema: {
      type: "object",
      required: ["team_id"],
      properties: {
        team_id: { type: "string" },
        archive: { type: "boolean", default: true },
      },
    },
  },
];

function asJsonResult(payload: unknown): {
  content: Array<{ type: "text"; text: string }>;
  isError?: boolean;
} {
  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(payload),
      },
    ],
  };
}

function asError(message: string): {
  content: Array<{ type: "text"; text: string }>;
  isError: true;
} {
  return {
    content: [{ type: "text", text: JSON.stringify({ error: message }) }],
    isError: true,
  };
}

export function registerTeamTools(server: Server, storage: Storage): void {
  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: TOOLS,
  }));

  server.setRequestHandler(CallToolRequestSchema, async (req) => {
    const name = req.params.name;
    const args = (req.params.arguments ?? {}) as Record<string, unknown>;
    try {
      switch (name) {
        case "team_create": {
          const input = args as unknown as TeamCreateInput;
          if (!input.team_name || !Array.isArray(input.members)) {
            return asError("team_create requires team_name and members[]");
          }
          return asJsonResult(storage.createTeam(input));
        }
        case "send_message": {
          const input = args as unknown as SendMessageInput;
          if (!input.team_id || !input.from || !input.to || !input.content) {
            return asError(
              "send_message requires team_id, from, to, content",
            );
          }
          return asJsonResult(storage.sendMessage(input));
        }
        case "recv_messages": {
          const input = args as unknown as RecvMessagesInput;
          if (!input.team_id || !input.as) {
            return asError("recv_messages requires team_id and as");
          }
          const messages = storage.recvMessages(input);
          return asJsonResult({ messages });
        }
        case "task_create": {
          const input = args as unknown as TaskCreateInput;
          if (!input.team_id || !input.subject) {
            return asError("task_create requires team_id and subject");
          }
          return asJsonResult(storage.createTask(input));
        }
        case "task_update": {
          const input = args as unknown as TaskUpdateInput;
          if (!input.team_id || !input.task_id) {
            return asError("task_update requires team_id and task_id");
          }
          return asJsonResult(storage.updateTask(input));
        }
        case "task_list": {
          const input = args as unknown as TaskListInput;
          if (!input.team_id) {
            return asError("task_list requires team_id");
          }
          return asJsonResult(storage.listTasks(input));
        }
        case "task_get_output": {
          const input = args as unknown as TaskGetOutputInput;
          if (!input.team_id || !input.task_id) {
            return asError("task_get_output requires team_id and task_id");
          }
          const result = storage.getTaskOutput(input);
          if (!result) return asError(`task not found: ${input.task_id}`);
          return asJsonResult(result);
        }
        case "team_destroy": {
          const input = args as unknown as TeamDestroyInput;
          if (!input.team_id) {
            return asError("team_destroy requires team_id");
          }
          return asJsonResult(storage.destroyTeam(input));
        }
        default:
          return asError(`unknown tool: ${name}`);
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return asError(message);
    }
  });
}

export { TOOLS as TEAM_TOOLS };
