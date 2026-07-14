# AI & Agents

## Why this is in the plan

MCP (Model Context Protocol) and AI agent tooling are becoming standard ways to connect AI systems to infrastructure and tools — conceptually similar to how OAuth/SCIM standardized identity integrations. Given the career direction behind this lab (IAM/platform engineering), building real MCP servers and agents against this homelab's own infrastructure is a natural, differentiated portfolio project rather than a detour.

Status: **planned, not yet started.** Logged here ahead of time per the original "document the plan before building it" habit from the repo's early setup.

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

### 5. Custom AI agents
- Build agents (e.g. via the Claude Agent SDK) that operate against homelab services — not just answering questions, but taking action (restarting a container, creating a VM, responding to an alert)
- This is the furthest-out item and depends on the MCP server work above existing first, since agents need tools to call

## Open questions to resolve when this phase starts

- Where does this run — a new dedicated VM, or added to `automation01`?
- How much of this is safe to let an agent *act* on autonomously vs. requiring approval (this matters a lot once agents can restart services or touch TrueNAS)
