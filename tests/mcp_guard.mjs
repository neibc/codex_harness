// mcp_guard.mjs — regression guard for mcp-team-server team/member validation (T19).
// Spawns the built stdio server and checks:
//   (a) a valid roundtrip (team_create → send → recv) still works,
//   (b) send_message to a nonexistent team_id is an isError,
//   (c) send_message with an unknown member is an isError.
// Exit 0 on all-pass, 1 otherwise. Uses an isolated temp DB (no user-env side effects).

import { spawn } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { dirname } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const SERVER = join(HERE, "..", "mcp-team-server", "dist", "index.js");
const tmp = mkdtempSync(join(tmpdir(), "codex-harness-guard-"));
const STORAGE = join(tmp, "guard.sqlite");

const child = spawn("node", [SERVER], {
  env: { ...process.env, TEAM_STORAGE_PATH: STORAGE },
  stdio: ["pipe", "pipe", "inherit"],
});

let buf = "";
const pending = new Map();
child.stdout.on("data", (d) => {
  buf += d.toString();
  let idx;
  while ((idx = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, idx).trim();
    buf = buf.slice(idx + 1);
    if (!line.startsWith("{")) continue;
    const msg = JSON.parse(line);
    if (msg.id !== undefined && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    }
  }
});

let nextId = 1;
const rpc = (method, params) => {
  const id = nextId++;
  const p = new Promise((resolve, reject) => {
    pending.set(id, resolve);
    setTimeout(() => reject(new Error(`timeout: ${method}`)), 10000);
  });
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  return p;
};
const notify = (method, params) =>
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method, params }) + "\n");

async function callRaw(name, args) {
  const res = await rpc("tools/call", { name, arguments: args });
  const text = res.result?.content?.[0]?.text ?? "";
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  return { isError: !!res.result?.isError || !!res.error, data };
}

const results = [];
const report = (step, ok, note) => {
  results.push(ok);
  console.log(`    ${ok ? "PASS" : "FAIL"} ${step} — ${note}`);
};

try {
  await rpc("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "mcp-guard", version: "0" },
  });
  notify("notifications/initialized", {});

  const t = (await callRaw("team_create", { team_name: "guard", members: ["alice", "bob"] })).data;
  const teamId = t.team_id ?? t.id;

  const sent = await callRaw("send_message", { team_id: teamId, from: "alice", to: "bob", content: "ping" });
  report("valid send_message", !sent.isError && (sent.data.message_id !== undefined), JSON.stringify(sent.data).slice(0, 60));

  const recv = await callRaw("recv_messages", { team_id: teamId, as: "bob" });
  const msgs = recv.messages ?? recv.data?.messages ?? recv.data;
  report("valid recv_messages", !recv.isError && Array.isArray(msgs) && msgs.some((m) => m.content === "ping"), `got ${Array.isArray(msgs) ? msgs.length : "?"}`);

  const badTeam = await callRaw("send_message", { team_id: "no-such-team", from: "x", to: "y", content: "z" });
  report("send to bad team_id is isError", badTeam.isError, JSON.stringify(badTeam.data).slice(0, 60));

  const badMember = await callRaw("send_message", { team_id: teamId, from: "ghost", to: "bob", content: "z" });
  report("send from unknown member is isError", badMember.isError, JSON.stringify(badMember.data).slice(0, 60));

  const bcast = await callRaw("send_message", { team_id: teamId, from: "alice", to: "*", content: "all" });
  report("broadcast to='*' allowed", !bcast.isError, JSON.stringify(bcast.data).slice(0, 60));
} catch (e) {
  report("(exception)", false, e.message);
} finally {
  child.kill();
  try { rmSync(tmp, { recursive: true, force: true }); } catch {}
}

console.log(`  guard: ${results.filter(Boolean).length}/${results.length} PASS`);
process.exit(results.every(Boolean) ? 0 : 1);
