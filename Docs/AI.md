# AI & Agents

## Why this is in the plan

MCP (Model Context Protocol) and AI agent tooling are becoming standard ways to connect AI systems to infrastructure and tools — conceptually similar to how OAuth/SCIM standardized identity integrations. Given the career direction behind this lab (IAM/platform engineering), building real MCP servers and agents against this homelab's own infrastructure is a natural, differentiated portfolio project rather than a detour.

Status: **Phase 4 underway** — first custom MCP server built and deployed 2026-07-17, and a second (adopted, community) MCP server (`n8n-mcp`) deployed 2026-07-18 — both confirmed connected via `/mcp` (2 servers connected). Phases 1-3 (Ollama/Open WebUI, n8n+AI) are still not started; Phase 3 (MCP fundamentals via community servers) is effectively satisfied by adopting `n8n-mcp` rather than a separate learning exercise. `n8n-mcp`'s workflow-management tools (not just node/docs search) were confirmed working end-to-end the same day by building a real production workflow — see below.

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

**First real workflow built via `n8n-mcp` (2026-07-18): `Daily Job & Learning Digest`** — the first time the toolchain's workflow-management tools (create/update/validate/test, not just node/docs search) were exercised end-to-end against a production workflow. Runs daily at 7am and sends one combined Discord message with three sections, numbered 1-5 each:

| Section | Source(s) |
|---|---|
| Job postings (Solutions Engineer / Automation Engineer) | JSearch API via RapidAPI (`/search-v2`) |
| Learning videos | YouTube Data API v3 search, topic rotates daily through 7 homelab/IAM-learning subjects keyed off day-of-week |
| News (top 5 combined, most recent first) | Hacker News (Algolia API), Bleeping Computer + Wired (native RSS), an unofficial TLDR RSS mirror, Reddit r/Claude+ClaudeAI+ClaudeCode+OpenAI+artificial (RSS, not the API — see below) |

Architecture: a Schedule Trigger fans out to all source branches in parallel; each has its own HTTP Request/RSS/formatter Code node; all 6 streams (jobs+videos already combined, plus the 5 news sources) converge through 5 chained `Merge` nodes before a single Code node builds the final message and a Discord node (webhook auth) sends it once.

Real gotchas hit and resolved (full detail in [LessonsLearned.md](LessonsLearned.md) 2026-07-18):
- n8n-mcp's SSRF protection blocks any private-IP `N8N_API_URL` by default — fixed with `WEBHOOK_SECURITY_MODE=permissive` in `Docker/MCP/.env`.
- Reddit's Developer Platform now gates new app creation behind an approval process ("Responsible Builder Policy") — dropped the Reddit node/OAuth2 entirely in favor of Reddit's still-open, credential-free RSS endpoints.
- JSearch's `/search` endpoint is deprecated in favor of `/search-v2`, which nests results one level deeper (`data.jobs`, not `data`) — caused a runtime `TypeError` caught via `n8n_executions` error inspection.
- Wiring multiple branches into the same input on a regular node does **not** combine them into one execution in n8n — it runs that node once per incoming branch. This caused a "duplicate Discord post" bug, fixed by inserting chained `Merge` nodes for real fan-in.
- Discord's plain message `content` doesn't render `[text](url)` masked links (embeds only) — switched to plain text + `<url>` (suppresses the link preview) plus the message's `SUPPRESS_EMBEDS` flag, and escaped literal `@`-mentions in third-party titles to prevent accidental pings.

Credentials: RapidAPI (Header Auth) and the YouTube/Discord credentials all live in n8n's own encrypted credential store, not the workflow JSON — the RapidAPI one was created directly via `n8n_manage_credentials` (the user shared the key mid-conversation, so it went straight into n8n rather than being retyped into the UI).

Status: built, iterated through several real bugs, and functional — job search, YouTube, and news branches all confirmed returning real data via test executions.

### 5. Custom AI agents
- Build agents (e.g. via the Claude Agent SDK) that operate against homelab services — not just answering questions, but taking action (restarting a container, creating a VM, responding to an alert)
- This is the furthest-out item and depends on the MCP server work above existing first, since agents need tools to call

**Added to roadmap (2026-07-19): Hermes Agent as a Discord IT-admin bot.** [Hermes Agent](https://hermes-agent.nousresearch.com/) (Nous Research) — a self-improving, self-hosted agent (cross-session memory, self-authored skills, cron tasks, messaging-platform gateway) that runs entirely on local hardware via Ollama, no API keys/cloud dependency. Goal: run it against this homelab's own MCP tools (Uptime Kuma today, Proxmox/TrueNAS later) as a Discord-facing "IT admin" — chat with it to check homelab health, troubleshoot issues, and get explanations that build toward [[user-career-goals]]. Depends on the Local AI foundation (Ollama + RTX 4000, item 1 above) being built first, since Hermes needs a local model to run against. Not yet started.

## Open questions to resolve when this phase starts

- Where does this run — a new dedicated VM, or added to `automation01`?
- How much of this is safe to let an agent *act* on autonomously vs. requiring approval (this matters a lot once agents can restart services or touch TrueNAS)

### 6. Public-facing custom MCP server (internet-exposed)

**Idea captured 2026-07-23.** All MCP servers built so far (`homelab-uptime-kuma`, `n8n-mcp`) are LAN-only — reachable at `192.168.1.20`, never exposed past the router. This is a different, harder tier: a self-hosted MCP server reachable from the public internet, for external users/devices to call, not just Claude sessions on this LAN.

Candidate ideas:
- A **Zendesk ticketing MCP** — plays directly to the user's existing day-job Zendesk admin experience (see [[user-career-goals]]), and no well-known public Zendesk MCP server exists yet as of this writing.
- Something else genuinely missing from the current MCP ecosystem — not yet chosen; worth a quick survey of existing public/community MCP servers before committing so this doesn't duplicate something that already exists well.

This depends on infrastructure this lab hasn't built yet — internet exposure isn't safe without it:
- **Reverse proxy + real TLS certs** (README "Future Projects" — not started)
- **Auth on the server itself** — a bearer token like `n8n-mcp` uses today is fine LAN-only, but an internet-facing tool-calling server needs something stronger (OAuth2/API-key-per-consumer at minimum) given MCP tools can take real actions (e.g. creating/updating Zendesk tickets)
- Some thought on rate limiting / abuse prevention, since this is no longer just "me talking to my own infra"

**Open questions specific to this idea:**
- Which idea to build (Zendesk vs. something else) — survey existing public MCP servers first
- Reverse proxy choice (Traefik vs. Caddy — Caddy already named as a target skill in [[user-career-goals]])
- Where credentials for the exposed service live — likely the first real consumer of Vault ([Docs/Security.md](Docs/Security.md)) rather than a `.env` file, given the stakes of exposing a credentialed tool-calling server to the internet

## Future consideration: Docker MCP Gateway

Evaluated 2026-07-18. Docker MCP Gateway (`docker mcp gateway run`, part of Docker's MCP Toolkit) fronts multiple MCP servers behind one proxy endpoint — curated/signed community catalog, centralized secrets via Docker's vault instead of env files, per-client tool enable/disable, request interceptors for auth/logging.

Decision: not adopting yet. At 2 servers (`homelab-uptime-kuma`, `n8n-mcp`), the current pattern — one container per server in `Docker/MCP/docker-compose.yml`, each its own port, each listed individually in `.mcp.json` — already gives hands-on practice with per-server auth (bearer tokens, env-based secrets), which is the actual point of this phase for IAM/platform engineering skill-building. The gateway would abstract that away.

Revisit once the server count grows past ~5 (Proxmox/TrueNAS additions plus whatever comes after) or managing individual `.mcp.json` entries/auth becomes real toil — worth standing up and testing then, both to see if it simplifies management and as its own portfolio-relevant piece (aggregation/gateway patterns are common in IAM/platform tooling).

**2026-07-23: formally added to the tracked roadmap** (README "Docker Services > Planned" and "Learning Progress > Planned") per user request — the "not adopting yet" timing decision above still stands, but it's now a real checklist item rather than a paragraph that could get lost.
