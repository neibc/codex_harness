// SQLite-backed storage for codex-harness MCP team server.
// Schema matches _workspace/03_translation_table.md §2.3.
// All writes go through prepared statements; messages are append-only.

import Database from "better-sqlite3";
import { randomUUID } from "node:crypto";
import { existsSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import type {
  MessageRow,
  RecvMessagesInput,
  SendMessageInput,
  SendMessageOutput,
  TaskCreateInput,
  TaskCreateOutput,
  TaskGetOutputInput,
  TaskGetOutputResult,
  TaskListInput,
  TaskListOutput,
  TaskRow,
  TaskStatus,
  TaskUpdateInput,
  TaskUpdateOutput,
  TeamCreateInput,
  TeamCreateOutput,
  TeamDestroyInput,
  TeamDestroyOutput,
  TeamRow,
} from "./types.js";

const DDL = `
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS teams (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  members     TEXT NOT NULL,
  leader      TEXT,
  status      TEXT NOT NULL DEFAULT 'active',
  created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS messages (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  team_id      TEXT NOT NULL,
  from_member  TEXT NOT NULL,
  to_member    TEXT NOT NULL,
  content      TEXT NOT NULL,
  tags         TEXT,
  ts           TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_messages_team_to_id ON messages(team_id, to_member, id);

CREATE TABLE IF NOT EXISTS tasks (
  id           TEXT PRIMARY KEY,
  team_id      TEXT NOT NULL,
  subject      TEXT NOT NULL,
  description  TEXT,
  owner        TEXT,
  status       TEXT NOT NULL,
  blocked_by   TEXT,
  metadata     TEXT,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tasks_team_status ON tasks(team_id, status);

CREATE TABLE IF NOT EXISTS task_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id     TEXT NOT NULL,
  status      TEXT NOT NULL,
  owner       TEXT,
  metadata    TEXT,
  ts          TEXT NOT NULL
);
`;

function nowIso(): string {
  return new Date().toISOString();
}

function expandHome(path: string): string {
  if (path.startsWith("~/")) {
    const home = process.env.HOME ?? process.env.USERPROFILE ?? "";
    return home + path.slice(1);
  }
  return path;
}

function parseJsonArray(raw: string | null | undefined): string[] {
  if (!raw) return [];
  try {
    const v = JSON.parse(raw);
    return Array.isArray(v) ? (v as string[]) : [];
  } catch {
    return [];
  }
}

function parseJsonObject(raw: string | null | undefined): Record<string, unknown> {
  if (!raw) return {};
  try {
    const v = JSON.parse(raw);
    return v && typeof v === "object" ? (v as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

export class Storage {
  private db: Database.Database;

  constructor(dbPath: string) {
    const resolved = expandHome(dbPath);
    const dir = dirname(resolved);
    if (dir && !existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
    this.db = new Database(resolved);
    this.db.exec(DDL);
  }

  close(): void {
    this.db.close();
  }

  // --- Teams ---

  createTeam(input: TeamCreateInput): TeamCreateOutput {
    const team_id = randomUUID();
    const leader = input.leader ?? input.members[0] ?? null;
    const stmt = this.db.prepare(
      `INSERT INTO teams (id, name, members, leader, status, created_at)
       VALUES (?, ?, ?, ?, 'active', ?)`,
    );
    stmt.run(
      team_id,
      input.team_name,
      JSON.stringify(input.members),
      leader,
      nowIso(),
    );
    return { team_id };
  }

  destroyTeam(input: TeamDestroyInput): TeamDestroyOutput {
    const archive = input.archive ?? true;
    if (archive) {
      this.db
        .prepare(`UPDATE teams SET status = 'archived' WHERE id = ?`)
        .run(input.team_id);
      return { ok: true, archived: true };
    }
    // hard delete (cascade by hand — no FKs)
    const tx = this.db.transaction((id: string) => {
      this.db.prepare(`DELETE FROM messages WHERE team_id = ?`).run(id);
      this.db.prepare(`DELETE FROM task_history WHERE task_id IN (SELECT id FROM tasks WHERE team_id = ?)`).run(id);
      this.db.prepare(`DELETE FROM tasks WHERE team_id = ?`).run(id);
      this.db.prepare(`DELETE FROM teams WHERE id = ?`).run(id);
    });
    tx(input.team_id);
    return { ok: true, archived: false };
  }

  getTeam(team_id: string): TeamRow | null {
    const row = this.db
      .prepare(
        `SELECT id, name, members, leader, status, created_at FROM teams WHERE id = ?`,
      )
      .get(team_id) as
      | { id: string; name: string; members: string; leader: string | null; status: string; created_at: string }
      | undefined;
    if (!row) return null;
    return {
      id: row.id,
      name: row.name,
      members: parseJsonArray(row.members),
      leader: row.leader,
      status: row.status as TeamRow["status"],
      created_at: row.created_at,
    };
  }

  // --- Messages ---

  sendMessage(input: SendMessageInput): SendMessageOutput {
    const ts = nowIso();
    const stmt = this.db.prepare(
      `INSERT INTO messages (team_id, from_member, to_member, content, tags, ts)
       VALUES (?, ?, ?, ?, ?, ?)`,
    );
    const result = stmt.run(
      input.team_id,
      input.from,
      input.to,
      input.content,
      JSON.stringify(input.tags ?? []),
      ts,
    );
    return { message_id: Number(result.lastInsertRowid), ts };
  }

  recvMessages(input: RecvMessagesInput): MessageRow[] {
    const limit = input.limit ?? 50;
    let cursorClause = "";
    const params: Array<string | number> = [input.team_id, input.as];
    if (typeof input.since === "number") {
      cursorClause = "AND id > ?";
      params.push(input.since);
    } else if (typeof input.since === "string" && input.since.length > 0) {
      cursorClause = "AND ts > ?";
      params.push(input.since);
    }
    const sql = `
      SELECT id, team_id, from_member, to_member, content, tags, ts
      FROM messages
      WHERE team_id = ?
        AND (to_member = ? OR to_member = '*')
        ${cursorClause}
      ORDER BY id ASC
      LIMIT ?
    `;
    params.push(limit);
    const rows = this.db.prepare(sql).all(...params) as Array<{
      id: number;
      team_id: string;
      from_member: string;
      to_member: string;
      content: string;
      tags: string | null;
      ts: string;
    }>;
    return rows.map((r) => ({
      id: r.id,
      team_id: r.team_id,
      from: r.from_member,
      to: r.to_member,
      content: r.content,
      tags: parseJsonArray(r.tags),
      ts: r.ts,
    }));
  }

  // --- Tasks ---

  createTask(input: TaskCreateInput): TaskCreateOutput {
    const task_id = randomUUID();
    const ts = nowIso();
    const stmt = this.db.prepare(
      `INSERT INTO tasks (id, team_id, subject, description, owner, status, blocked_by, metadata, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?)`,
    );
    stmt.run(
      task_id,
      input.team_id,
      input.subject,
      input.description ?? null,
      input.owner ?? null,
      JSON.stringify(input.blocked_by ?? []),
      JSON.stringify({}),
      ts,
      ts,
    );
    this.db
      .prepare(
        `INSERT INTO task_history (task_id, status, owner, metadata, ts)
         VALUES (?, 'pending', ?, ?, ?)`,
      )
      .run(task_id, input.owner ?? null, JSON.stringify({}), ts);
    return { task_id };
  }

  updateTask(input: TaskUpdateInput): TaskUpdateOutput {
    const existing = this.db
      .prepare(`SELECT status, owner, metadata FROM tasks WHERE id = ? AND team_id = ?`)
      .get(input.task_id, input.team_id) as
      | { status: string; owner: string | null; metadata: string | null }
      | undefined;
    if (!existing) {
      throw new Error(`task not found: ${input.task_id}`);
    }
    const ts = nowIso();
    const newStatus = (input.status ?? existing.status) as TaskStatus;
    const newOwner = input.owner ?? existing.owner;
    const mergedMetadata: Record<string, unknown> = {
      ...parseJsonObject(existing.metadata),
      ...(input.metadata ?? {}),
    };
    this.db
      .prepare(
        `UPDATE tasks SET status = ?, owner = ?, metadata = ?, updated_at = ?
         WHERE id = ? AND team_id = ?`,
      )
      .run(
        newStatus,
        newOwner,
        JSON.stringify(mergedMetadata),
        ts,
        input.task_id,
        input.team_id,
      );
    this.db
      .prepare(
        `INSERT INTO task_history (task_id, status, owner, metadata, ts)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .run(input.task_id, newStatus, newOwner, JSON.stringify(mergedMetadata), ts);
    return { ok: true };
  }

  listTasks(input: TaskListInput): TaskListOutput {
    const params: Array<string> = [input.team_id];
    let statusClause = "";
    if (Array.isArray(input.status) && input.status.length > 0) {
      const placeholders = input.status.map(() => "?").join(",");
      statusClause = `AND status IN (${placeholders})`;
      params.push(...input.status);
    } else if (typeof input.status === "string" && input.status.length > 0) {
      statusClause = "AND status = ?";
      params.push(input.status);
    }
    let ownerClause = "";
    if (typeof input.owner === "string" && input.owner.length > 0) {
      ownerClause = "AND owner = ?";
      params.push(input.owner);
    }
    const rows = this.db
      .prepare(
        `SELECT id, team_id, subject, description, owner, status, blocked_by, metadata, created_at, updated_at
         FROM tasks
         WHERE team_id = ?
           ${statusClause}
           ${ownerClause}
         ORDER BY created_at ASC`,
      )
      .all(...params) as Array<{
      id: string;
      team_id: string;
      subject: string;
      description: string | null;
      owner: string | null;
      status: string;
      blocked_by: string | null;
      metadata: string | null;
      created_at: string;
      updated_at: string;
    }>;
    const tasks: TaskRow[] = rows.map((r) => ({
      id: r.id,
      team_id: r.team_id,
      subject: r.subject,
      description: r.description,
      owner: r.owner,
      status: r.status as TaskStatus,
      blocked_by: parseJsonArray(r.blocked_by),
      metadata: parseJsonObject(r.metadata),
      created_at: r.created_at,
      updated_at: r.updated_at,
    }));
    return { tasks };
  }

  getTaskOutput(input: TaskGetOutputInput): TaskGetOutputResult | null {
    const row = this.db
      .prepare(
        `SELECT status, metadata, updated_at FROM tasks WHERE id = ? AND team_id = ?`,
      )
      .get(input.task_id, input.team_id) as
      | { status: string; metadata: string | null; updated_at: string }
      | undefined;
    if (!row) return null;
    const md = parseJsonObject(row.metadata);
    return {
      output: md.output ?? null,
      status: row.status as TaskStatus,
      updated_at: row.updated_at,
    };
  }
}

export function openStorage(dbPath?: string): Storage {
  const path = dbPath ?? process.env.TEAM_STORAGE_PATH ?? "~/.codex/teams.sqlite";
  return new Storage(path);
}
