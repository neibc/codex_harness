# Security Policy

## Reporting a vulnerability

If you discover a security issue in `codex_harness`, please **do not file a public issue**. Instead, contact the maintainer privately:

- Open a [GitHub Security Advisory](https://docs.github.com/en/code-security/security-advisories/repository-security-advisories) in this repository, or
- Email the maintainer (see repository profile / `git log`).

We will acknowledge receipt within a reasonable time and aim to publish a fix or mitigation in a subsequent release.

## Scope

In-scope concerns:

- Vulnerabilities in the **MCP team-emulation server** (`mcp-team-server/`) — e.g. unsafe SQL, path traversal in storage paths, untrusted-input handling in tool arguments.
- Hooks under `hooks/` — e.g. shell injection in `session-*.mjs`.
- Plugin manifests (`.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`, `.mcp.json`) that could cause Codex to execute unexpected commands when installed.
- Documentation that misleads users into running unsafe commands.

Out of scope:

- Issues in upstream OpenAI Codex CLI itself — please report to the [OpenAI Codex repository](https://github.com/openai/codex).
- Issues in `revfactory/harness` upstream — please report there.
- Configuration mistakes by individual users (e.g. weakening Codex's `--sandbox` policy).

## Hardening tips for users

- **Sandbox**: prefer `-s read-only` for analysis/exploration agents; reserve `workspace-write` for builders.
- **Storage path**: the team server defaults to `~/.codex/teams.sqlite`. Set `TEAM_STORAGE_PATH` to a per-project file if you don't want shared state.
- **Hooks**: review `hooks/session-*.mjs` before installing the plugin; they execute on every session start/end.
- **Manifest review**: before running `codex plugin marketplace add`, inspect `.codex-plugin/plugin.json` and `.mcp.json` to confirm what gets registered.
