// Shared types for codex-harness MCP team server.
// Mirrors the JSON Schemas in skills/harness/SKILL.md and
// _workspace/03_translation_table.md §2.2.

export type TaskStatus =
  | "pending"
  | "in_progress"
  | "completed"
  | "blocked"
  | "timed_out"
  | "deleted";

export type TeamStatus = "active" | "archived";

export interface TeamRow {
  id: string;
  name: string;
  members: string[];
  leader: string | null;
  status: TeamStatus;
  created_at: string;
}

export interface MessageRow {
  id: number;
  team_id: string;
  from: string;
  to: string;
  content: string;
  tags: string[];
  ts: string;
}

export interface TaskRow {
  id: string;
  team_id: string;
  subject: string;
  description: string | null;
  owner: string | null;
  status: TaskStatus;
  blocked_by: string[];
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

// --- Tool input/output shapes ---

export interface TeamCreateInput {
  team_name: string;
  members: string[];
  leader?: string;
}
export interface TeamCreateOutput {
  team_id: string;
}

export interface SendMessageInput {
  team_id: string;
  from: string;
  to: string; // member name or "*"
  content: string;
  tags?: string[];
}
export interface SendMessageOutput {
  message_id: number;
  ts: string;
}

export interface RecvMessagesInput {
  team_id: string;
  as: string;
  since?: string | number; // ISO ts or message_id cursor
  limit?: number;
}
export interface RecvMessagesOutput {
  messages: MessageRow[];
}

export interface TaskCreateInput {
  team_id: string;
  subject: string;
  description?: string;
  owner?: string;
  blocked_by?: string[];
}
export interface TaskCreateOutput {
  task_id: string;
}

export interface TaskUpdateInput {
  team_id: string;
  task_id: string;
  status?: TaskStatus;
  owner?: string;
  metadata?: Record<string, unknown>;
}
export interface TaskUpdateOutput {
  ok: true;
}

export interface TaskListInput {
  team_id: string;
  status?: TaskStatus | TaskStatus[];
  owner?: string;
}
export interface TaskListOutput {
  tasks: TaskRow[];
}

export interface TaskGetOutputInput {
  team_id: string;
  task_id: string;
}
export interface TaskGetOutputResult {
  output: unknown;
  status: TaskStatus;
  updated_at: string;
}

export interface TeamDestroyInput {
  team_id: string;
  archive?: boolean;
}
export interface TeamDestroyOutput {
  ok: true;
  archived: boolean;
}
