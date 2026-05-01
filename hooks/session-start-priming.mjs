#!/usr/bin/env node
// SessionStart hook for codex-harness.
//
// Output schema follows Anthropic SyncHookJSONOutput:
//   { "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": "..." } }
//
// Currently emits a minimal context primer pointing the user at AGENTS.md
// and the harness skill. Extend as needed (e.g., load _workspace state,
// pull pending team messages, etc.).

const additionalContext = [
  "codex-harness loaded.",
  "- Routing & MCP tool table: ./AGENTS.md",
  "- Main skill: ./skills/harness/SKILL.md",
  "- Personas: ./agents/<name>.md",
  "- Known limitations: ./LIMITATIONS.md"
].join("\n");

const payload = {
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext
  }
};

process.stdout.write(JSON.stringify(payload));
