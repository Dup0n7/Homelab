# AI & Agents

## Why this is in the plan

MCP (Model Context Protocol) and AI agent tooling are becoming standard ways to connect AI systems to infrastructure and tools — conceptually similar to how OAuth/SCIM standardized identity integrations. Given the career direction behind this lab (IAM/platform engineering), building real MCP servers and agents against this homelab's own infrastructure is a natural, differentiated portfolio project rather than a detour.

Status: **Phase 4 underway** — first custom MCP server built and deployed 2026-07-17, and a second (adopted, community) MCP server (`n8n-mcp`) deployed 2026-07-18 — both confirmed connected via `/mcp` (2 servers connected). Phases 1-3 (Ollama/Open WebUI, n8n+AI) are still not started; Phase 3 (MCP fundamentals via community servers) is effectively satisfied by adopting `n8n-mcp` rather than a separate learning exercise.

## Planned track

These build on each other roughly in order, though not strictly gated — some (like n8n + AI) could start before others finish.

### 1. Local AI foundation
- Ollama running on a VM with the RTX 4000 passed through
- Open WebUI as a chat front-end against local models

### 2. n8n calling AI
- Wire n8n workflows to call Claude (or a local Ollama model) for tasks like summarizing Uptime Kuma alerts, classifying incoming data, or generating reports
- Natural extension of the automation work already running on `automation01`

### 3. MCP fundamentals
- Learn the protocol itself (tools, resources, prompts)
- Run a few existing community MCP servers (filesystem, GitHub, etc.) against Claude Desktop or Claude Code to understand the request/response model before building one

### 4. Custom MCP server for this homelab
- Build an MCP server that exposes real infrastructure as callable tools — e.g. Proxmox VM status, TrueNAS pool/dataset health, Uptime Kuma alert state
- Goal: be able to ask an AI agent "what's the health of my homelab" and get a real answer sourced from live systems, not a guess

**Built (2026-07-17): `homelab-uptime-kuma` MCP server** — first tool live: `get_service_status`, wrapping the same Uptime Kuma `/metrics` endpoint used in the earlier n8n alerting design. Details:

| Property | Value |
|---|---|
| Language | TypeScript/Node — chosen explicitly over Python for alignment with the target job market (IAM/platform engineering roles), not a technical necessity |
| SDK | `@modelcontextprotocol/sdk` v1.29.0 (the current **stable** package — see Lessons Learned for why this matters) |
| Transport | Streamable HTTP (the current standard for remote MCP servers, not stdio) |
| Hosting | `Docker/MCP/docker-compose.yml` on `automation01`, port `3100` — chosen over running on the PC so it's always available and reusable later by n8n or other agents, not just interactive Claude sessions |
| Source | `mcp-servers/uptime-kuma/` — a new top-level folder for custom MCP server source code, since these are real applications with their own `package.json`/`Dockerfile`, distinct from the `Docker/*` folders which mostly just wrap published images |
| Client config | `.mcp.json` at repo root (project-scoped, committed to git — safe since it holds only a plain LAN URL, no secrets) |

**Status: confirmed connected** via `/mcp` (2026-07-18).

**`/uptime-status` slash command added (2026-07-18):** `.claude/commands/uptime-status.md` — calls `get_service_status` and lays out every monitored service with its current status, sorting anything not "up" to the top. Distinct from a skill (auto-triggers on relevant conversation content) — this is an explicit `/`-invoked command. Custom commands load at session start like MCP servers, so it wasn't visible until a fresh session — not yet confirmed working end-to-end.

Proxmox and TrueNAS tools are the natural next additions — each needs its own API token set up first (Proxmox: Datacenter → API Tokens; TrueNAS: its own API key), unlike Uptime Kuma which reused an already-working integration.

**Added (2026-07-18): `n8n-mcp`** (community server, [czlonkowski/n8n-mcp](https://github.com/czlonkowski/n8n-mcp)) — not custom-built like the Uptime Kuma tool, but the first *adopted* MCP server, giving Claude Code direct knowledge of all n8n nodes/docs/templates plus (with an n8n API key configured) the ability to create/update/validate/deploy workflows directly against the `automation01` n8n instance.

| Property | Value |
|---|---|
| Image | `ghcr.io/czlonkowski/n8n-mcp:latest` (published image, not custom-built — unlike `mcp-servers/uptime-kuma/`) |
| Transport | Streamable HTTP, same pattern as the Uptime Kuma MCP server |
| Hosting | Same `Docker/MCP/docker-compose.yml` on `automation01`, its **own container** (`mcp-n8n`), port `3101` |
| Auth | Requires a bearer `AUTH_TOKEN` (HTTP mode is unauthenticated-by-default otherwise) — set in `Docker/MCP/.env` on the VM, and mirrored into the local `N8N_MCP_AUTH_TOKEN` shell env var so root `.mcp.json`'s `${N8N_MCP_AUTH_TOKEN}` substitution resolves it. Keeps the actual token out of git even though `.mcp.json` itself stays committed. |
| n8n API access | Optional `N8N_API_URL`/`N8N_API_KEY` (n8n → Settings → n8n API → API Keys) — without it, only read-only tools (node search, docs, templates) work; with it, workflow create/update/deploy tools activate too. |

**Status: deployed and confirmed connected** via `/mcp` (2026-07-18) — `AUTH_TOKEN` and `N8N_API_KEY` both configured, so workflow create/update/deploy tools should be active, not just read-only ones.

**Same container vs. separate — resolved:** one Docker container per MCP server, all sharing one `docker-compose.yml` per functional host (`automation01`). Reasoning: each server is a different image/runtime/release cadence (custom TypeScript app vs. published npm-based image), so Compose's normal multi-service model fits better than merging them into one container — and it keeps the pattern trivially repeatable for the still-planned Proxmox/TrueNAS MCP tools.

**Skills added (2026-07-18):** [czlonkowski/n8n-skills](https://github.com/czlonkowski/n8n-skills) — 14 skills plus a router skill (`using-n8n-mcp-skills`), installed via the documented manual method (`skills/*` copied into `~/.claude/skills/`) rather than the plugin/marketplace method, since the `claude` CLI still isn't reachable from any shell here (same blocker noted 2026-07-17). This means the repo's optional hooks layer (`hooks/hooks.json` — pre/post-tool-use scripts that intercept `n8n_create_workflow`, `validate_workflow`, etc.) was **not** installed; only the plugin/marketplace method wires those up. Skills activate automatically by content-matching, so this isn't a blocker — revisit installing the hooks only if the `claude` CLI reachability issue gets resolved and the enforcement layer seems worth the added complexity.

### 5. Custom AI agents
- Build agents (e.g. via the Claude Agent SDK) that operate against homelab services — not just answering questions, but taking action (restarting a container, creating a VM, responding to an alert)
- This is the furthest-out item and depends on the MCP server work above existing first, since agents need tools to call

## Open questions to resolve when this phase starts

- Where does this run — a new dedicated VM, or added to `automation01`?
- How much of this is safe to let an agent *act* on autonomously vs. requiring approval (this matters a lot once agents can restart services or touch TrueNAS)
