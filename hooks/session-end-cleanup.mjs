#!/usr/bin/env node
// SessionEnd hook for codex-harness.
//
// Currently a no-op. TODO: when team_destroy is invoked, archive sqlite
// rows older than the configured TTL (storage-schema.md §TTL/GC).

const payload = {
  hookSpecificOutput: {
    hookEventName: "SessionEnd"
  }
};

process.stdout.write(JSON.stringify(payload));
