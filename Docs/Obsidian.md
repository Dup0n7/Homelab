# Obsidian ("Second Brain")

## Why this is in the plan

Testing [Obsidian](https://obsidian.md/) as a personal knowledge base for homelab documentation and notes, layered on top of (not replacing) this repo's own `Docs/*.md` files.

Status: **Testing started 2026-07-19.**

## Vault layout

Existing vault: `S:\Obsidian\Dupontke` (`S:` → `\\192.168.1.40\documents`, i.e. `truenas01`). This repo's content lives in a `Homelab` subfolder of that vault, split in two so automated mirroring never clobbers personal notes:

| Folder | Purpose | Touched by sync? |
|---|---|---|
| `Homelab/Repo-Docs/` | Mirror of this repo's `README.md` + `Docs/*.md` | Yes — treat as read-only, edits here get overwritten |
| `Homelab/Notes/` | Freeform personal notes, ideas, journaling | No — safe to edit directly |

## Sync mechanism — git post-commit hook

`README.md` and `Docs/*.md` are mirrored to `Homelab/Repo-Docs/` automatically after every commit via a tracked hook:

- Hook script: [`.githooks/post-commit`](../.githooks/post-commit) — copies `README.md` and `Docs/*.md` to the vault over the UNC path `\\192.168.1.40\documents\Obsidian\Dupontke\Homelab\Repo-Docs` (used instead of the `S:` drive letter so it doesn't depend on that mapping being active in the shell running the hook).
- Enabled via `git config core.hooksPath .githooks` — **one-time setup needed on any fresh clone** (this repo's `.git/hooks` isn't itself version-controlled, so the pointer has to be set locally); already configured on this machine as of 2026-07-19.
- Runs unconditionally on every commit (not just ones touching docs) — cost is negligible for a handful of small Markdown files, and it keeps the hook simple.
- If the vault isn't reachable (VPN down, `truenas01` offline, etc.) the hook logs a warning to stderr and exits 0 rather than failing the commit.

## Claude Desktop integration

Goal: Claude Desktop should be able to read/search the vault directly, not just Claude Code.

Chosen approach: **`mcp-obsidian`** (by MarkusPfundstein) talking to the **Local REST API** community plugin (by Adam Coddington, `obsidian-local-rest-api`) — richer than plain filesystem access (search, list, patch/append content by path) rather than raw file read/write.

**Status: configured but not yet working — deferred, pick back up later.**
- `uv`/`uvx` installed on this machine (`C:\Users\dupon\.local\bin`, added to the persistent user `PATH`).
- Local REST API plugin installed and enabled in Obsidian (v4.1.7 — above the v4.1.3 path-traversal patch, so no upgrade needed).
- `%APPDATA%\Claude\claude_desktop_config.json` created with an `obsidian` MCP server entry (`uvx mcp-obsidian`, `OBSIDIAN_API_KEY` set — **the key itself lives only in that local config file, never committed to this repo**, defaults to `127.0.0.1:27124` which matches the plugin's default).
- Verified independently of Claude Desktop: `uvx mcp-obsidian` resolves/installs correctly, and a direct HTTPS request to the plugin with the configured key returned `"authenticated": true`.
- **Known issue (2026-07-19): after restarting Claude Desktop, it still isn't seeing/using the vault files.** Config file and plugin both check out individually, so the break is somewhere in Claude Desktop actually loading/using the `obsidian` MCP server — not yet diagnosed (candidates: config not reloaded, `uvx` not resolving from the app's own launch environment/PATH, the MCP server process failing silently on startup, plugin's self-signed cert being rejected by the MCP client). Root cause not investigated yet — resume from here next session rather than re-doing the setup steps above.

## Open questions

- Whether to eventually restructure `Repo-Docs` into a different layout (e.g. PARA) — deferred; currently mirrors the repo's existing per-topic file structure 1:1 by design, see [[homelab-architecture-plan]].
- Whether `mcp-obsidian` should also be wired into Claude Code (project `.mcp.json`) once it's working in Desktop, so both surfaces share the same access pattern.
