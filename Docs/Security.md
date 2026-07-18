# Security & Credential Management

## Why this is in the plan

Real enterprise environments split credential management into two distinct layers:

1. **Machine/app secrets** (API tokens, SSH keys, service credentials used by automation and AI agents) — handled by a **secrets manager**.
2. **Human passwords** (admin logins to Proxmox, TrueNAS, Uptime Kuma, GitHub, etc.) — handled by a **password manager**.

This lab only builds layer 1 (Vault). Layer 2 stays on **Google Password Manager**, which the user already uses — a self-hosted password manager (Vaultwarden) was considered and explicitly declined: Vault's KV engine can technically hold arbitrary login passwords, but doing so buys no real learning (Vault isn't built for browser autofill/mobile access) and would blur a distinction real enterprises keep separate on purpose. Not worth standing up a second self-hosted service just to avoid one external tool that already works fine.

## Machine/app secrets — HashiCorp Vault

### Decision context
Evaluated for storing secrets used by n8n, MCP servers, and future AI agents:

| Option | Verdict |
|---|---|
| Hardcoded secrets | Avoid |
| Environment variables | Fine for dev, plaintext at rest — not production-grade |
| OS credential stores | Not centralized enough for multi-VM lab |
| AWS Secrets Manager / Google Secret Manager | Free tiers are limited, not permanently free |
| Infisical | Easier to learn |
| **HashiCorp Vault** | More complex, but the widely-used enterprise standard |

**Chosen: HashiCorp Vault**, specifically because the primary objective is gaining enterprise-relevant skills (see [[user-career-goals]]) — Vault experience is more directly hireable than Infisical experience.

**Docker secrets — considered, then explicitly rejected (2026-07-18).** Not really a competing option: Docker's native `secret create` feature requires Swarm mode, which this lab doesn't run (plain Compose). Standalone Compose's `secrets:` key is just a local file mount into the container — no centralized store, no policies/RBAC, no rotation, no dynamic credentials, no audit trail. It's a delivery mechanism, not a management plane, and offers little improvement over the current `.env`-file approach. Doesn't serve the long-term goal (agents pulling scoped, audited secrets from a centralized store) and isn't a resume-relevant skill the way Vault is. Vault remains the plan.

### Planned scope (initial)
Credential management only — no dynamic secrets, PKI, or database credential generation yet. Store:
- Proxmox API token
- Okta API token
- GitHub token
- OpenAI/Anthropic API keys
- SSH private keys
- Other infrastructure credentials

### Phased rollout
**Phase 1:**
- Deploy Vault in Docker on Proxmox (likely `automation01`, alongside the existing Docker Compose stack)
- Initialize and unseal Vault
- Configure the KV secrets engine
- Store and retrieve secrets manually
- Connect a Python (or Node, per the TypeScript-first convention from the MCP server work) application to Vault

**Phase 2:**
- Policies (least-privilege access per app/agent)
- AppRole authentication (so MCP servers/agents authenticate without a human in the loop)
- Secret rotation
- Dynamic credentials

### Long-term goal
Vault becomes the centralized credential source for AI agents and MCP servers, so automation tooling never embeds credentials directly. Future agents (Proxmox/TrueNAS MCP tools, custom Claude Agent SDK agents — see [AI.md](AI.md)) should pull secrets from Vault immediately before making an SSH or API call, rather than reading them from `.env` files or config.

## Human passwords — Google Password Manager (no self-hosted component)

Admin logins to homelab servers/services (Proxmox, TrueNAS, Uptime Kuma, GitHub, router, switch, etc.) stay in Google Password Manager. Decided against Vaultwarden or any self-hosted password manager — not enough marginal value to justify deploying and maintaining a second credential system alongside Vault.

## Open questions to resolve when this phase starts

- Where does Vault run — its own VM, or a container on `automation01` alongside n8n/Portainer/Uptime Kuma?
- Unseal-key handling: for a single-operator home lab, is Shamir's default 5-key/3-threshold split overkill, or worth doing anyway for the learning value?
