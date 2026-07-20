# Kyle's Homelab

## Overview

This repository documents my self-hosted infrastructure for building, testing, and learning enterprise infrastructure engineering, automation, identity management, observability, virtualization, and AI workloads.

The lab is designed to mirror production environments as closely as possible while remaining cost effective for home use.

See [Docs/Architecture.md](Docs/Architecture.md) for the current build, [Docs/Network.md](Docs/Network.md) and [Docs/Storage.md](Docs/Storage.md) for infrastructure detail, [Docs/AI.md](Docs/AI.md) for the AI/MCP/agents roadmap, [Docs/Security.md](Docs/Security.md) for the credential/secrets management plan, [Docs/LessonsLearned.md](Docs/LessonsLearned.md) for what's been learned along the way, and [Docs/Commands.md](Docs/Commands.md) for a running cheat sheet of commonly used commands.

---

# Goals

- Learn Infrastructure as Code (Terraform)
- Learn Configuration Management (Ansible)
- Learn Docker & Docker Compose
- Learn Kubernetes (K3s)
- Build enterprise monitoring with Grafana
- Host a TrueNAS storage server
- Practice Windows Server & Active Directory
- Learn GitHub Actions CI/CD
- Experiment with local AI using an RTX 4000 GPU
- Learn the Model Context Protocol (MCP) and build a custom MCP server exposing this homelab's infrastructure to AI agents
- Build custom AI agents (e.g. via the Claude Agent SDK) that can operate against homelab services
- Integrate AI (Claude, local LLMs via Ollama) into n8n automation workflows
- Build an enterprise-style secrets management environment with HashiCorp Vault for machine/app secrets (see [Docs/Security.md](Docs/Security.md)) — human/admin logins stay in Google Password Manager, not self-hosted
- Document all infrastructure as code

---

# Hardware

## Server

| Component | Details |
|-----------|---------|
| Host | BOXX Workstation |
| CPU | TBD |
| RAM | 32 GB DDR4 |
| GPU | NVIDIA RTX 4000 |
| Boot Drive | 512 GB SSD |
| Second SSD | 512 GB SSD (M.2 SATA) — `ssd2-thin` LVM-Thin pool |
| Storage | 2x 4 TB NAS HDD (WD Red + HGST Ultrastar) — mirrored ZFS pool on truenas01 |
| Backup | 2 TB NAS HDD |

---

# Hardware Wishlist

- [x] Second 4TB+ NAS HDD — `tank` ZFS pool on truenas01 is now a mirror (resilvered 2026-07-15, 0 errors)
- [x] 2.5GbE switch — installed 2026-07-17; Proxmox actually ended up on the switch's 10G port (its 2.5G-tier NICs turned out to be 1G-only), Windows workstation on a 2.5G port. See [Docs/Network.md](Docs/Network.md).

---

# Hypervisor

- Proxmox VE 9.x
- Static IP
- Local SSD VM Storage

---

# Virtual Machines

| VM | Purpose | Status |
|----|----------|--------|
| automation01 | Docker — n8n, Portainer, Uptime Kuma | ✅ Running |
| truenas01 | TrueNAS SCALE — ZFS storage (NFS/SMB) | ✅ Running |
| plex01 | Docker — Plex, Portainer Agent | ✅ Running |
| dc01 | Windows Server (AD/DNS/GPO) | Planned |
| win11-test01 | Test workstation | Planned |
| k3s-master01 | Kubernetes | Planned |
| k3s-worker01 | Kubernetes | Planned |

---

# Docker Services

## Running

- n8n (automation01)
- Portainer + Agent (automation01, plex01)
- Uptime Kuma (automation01) — v2.4.0
- Homepage dashboard (automation01)
- Plex (plex01)
- mcp-n8n (automation01) — community MCP server giving Claude Code n8n node/workflow knowledge, see [Docs/AI.md](Docs/AI.md)
- Obsidian (testing) — vault at `S:\Obsidian\Dupontke`, `Homelab/Repo-Docs` auto-mirrored from this repo via git post-commit hook, see [Docs/Obsidian.md](Docs/Obsidian.md)

## Planned

- Grafana
- Prometheus
- Loki
- Alloy
- PostgreSQL
- Redis
- Nextcloud
- Immich
- HashiCorp Vault (machine/app secrets — see [Docs/Security.md](Docs/Security.md))
- Open WebUI
- Ollama
- Homelable (network visual mapping — [github.com/Pouzor/homelable](https://github.com/Pouzor/homelable))
- Hermes Agent (self-hosted Discord IT-admin agent, via Ollama — see [Docs/AI.md](Docs/AI.md))

---

# Storage

## Current

- `tank` pool (truenas01) — **mirrored** (WD Red 4TB + HGST Ultrastar 4TB), resilvered cleanly 2026-07-15
- `ssd2-thin` pool (Proxmox, second SSD) — extra VM disk storage / room for more VMs
- `tank/media` dataset — exported via NFS (plex01) and SMB (Windows access)
- 2 TB backup drive — not currently detected/connected, needs follow-up

## Future

- Snapshots
- Automated Backups
- Lock down NFS export to plex01's IP specifically

---

# Monitoring

Planned

- Grafana
- Prometheus
- Loki
- Node Exporter
- Windows Exporter

---

# Automation

Planned

- Terraform
- Ansible
- GitHub Actions
- Docker Compose

---

# Networking

Static IPs (see [Docs/Network.md](Docs/Network.md) for full detail)

| Device | Address |
|---------|---------|
| Proxmox | 192.168.1.209 |
| automation01 | 192.168.1.20 |
| truenas01 | 192.168.1.40 |
| plex01 | 192.168.1.50 |
| dc01 | Reserved: 192.168.1.30 |

---

# Learning Progress

## Completed

- [x] Install Proxmox
- [x] Configure Static IP
- [x] Ubuntu cloud-init template + automation01 VM
- [x] Docker / Docker Compose
- [x] n8n
- [x] Portainer (+ multi-host via Agent)
- [x] Uptime Kuma
- [x] TrueNAS SCALE (NFS + SMB shares)
- [x] Plex (plex01, NFS-backed media)
- [x] ZFS mirror for tank pool
- [x] Second SSD wiped and built into an `ssd2-thin` LVM-Thin pool
- [x] Reboot resilience (VM autostart/order, NFS mount options)
- [x] Homepage dashboard (single landing page for all services)
- [x] Uptime Kuma upgraded 1.23.17 → 2.4.0
- [x] 2.5GbE switch installed — Proxmox on a 10G port, Windows workstation on 2.5G

## In Progress

- [ ] Migrating existing media library onto TrueNAS
- [ ] Reconnecting/verifying the 2TB backup drive
- [ ] Uptime Kuma → n8n → Discord outage alerting — design explored, not yet built (see LessonsLearned "Deferred")
- [x] First custom MCP server (`homelab-uptime-kuma`) — built, deployed, running on automation01, and confirmed connected via `/mcp` (see [Docs/AI.md](Docs/AI.md))
- [x] n8n-mcp community MCP server (`mcp-n8n`) — deployed to automation01 and confirmed connected via `/mcp` (see [Docs/AI.md](Docs/AI.md))
- [x] n8n-skills (14 skills + router skill) installed to `~/.claude/skills/`
- [ ] `/uptime-status` slash command (`.claude/commands/uptime-status.md`) — lists every Uptime Kuma-monitored service and its status via the `homelab-uptime-kuma` MCP tool; added but not yet verified working (custom commands load at session start, same as MCP servers)
- [x] First real n8n workflow built via `n8n-mcp`: `Daily Job & Learning Digest` (2026-07-18) — daily Discord message combining job postings (JSearch/RapidAPI), YouTube learning picks, and top-5 news across Hacker News/Bleeping Computer/Wired/TLDR/Reddit. See [Docs/AI.md](Docs/AI.md).
- [x] Obsidian vault publishing started (2026-07-19) — `Homelab/Repo-Docs` mirrored from this repo's `README.md`/`Docs/*.md` via a tracked git post-commit hook (`.githooks/post-commit`); see [Docs/Obsidian.md](Docs/Obsidian.md)
- [ ] Claude Desktop MCP access to the Obsidian vault (`mcp-obsidian` + Local REST API plugin) — config + plugin verified independently 2026-07-19, but Claude Desktop still isn't seeing the vault after a restart; root cause not yet diagnosed, deferred to next session — see [Docs/Obsidian.md](Docs/Obsidian.md)

## Planned

- [ ] Grafana / Prometheus / Loki monitoring stack
- [ ] Terraform
- [ ] Ansible
- [ ] Kubernetes
- [ ] Windows Server (dc01) / AD
- [ ] AI Stack (Ollama / Open WebUI via RTX 4000)
- [ ] n8n workflows calling AI (Claude / local LLMs)
- [x] MCP fundamentals (run existing community MCP servers) — n8n-mcp adopted 2026-07-18
- [ ] Proxmox + TrueNAS MCP tools (Uptime Kuma tool already built)
- [ ] Custom AI agents (e.g. via the Claude Agent SDK) operating against homelab services
- [ ] Hermes Agent (self-hosted Discord IT-admin agent via Ollama, homelab troubleshooting + career-goal learning) — see [Docs/AI.md](Docs/AI.md)
- [ ] HashiCorp Vault (machine/app secrets — Docker deploy, KV engine, policies, AppRole) — see [Docs/Security.md](Docs/Security.md)
- [ ] Homelable (network visual mapping/monitoring, nmap discovery + live health status — [github.com/Pouzor/homelable](https://github.com/Pouzor/homelable))

---

# Future Projects

- GitHub Runner
- Reverse Proxy
- SSL Certificates
- Internal DNS
- Active Directory
- SSO Integration
- AI Automation
- Backup Automation

---

# Repository Structure

```
homelab/
│
├── ansible/
├── docker/
├── docs/
├── kubernetes/
├── terraform/
├── scripts/
├── diagrams/
└── README.md
```

---

# Technologies

- Proxmox
- Ubuntu Server
- Docker
- Docker Compose
- Kubernetes
- Terraform
- Ansible
- Grafana
- Prometheus
- Loki
- TrueNAS
- Windows Server
- PowerShell
- GitHub Actions
- Python
- Bash
- Claude / Claude Agent SDK
- Model Context Protocol (MCP)
- Ollama
- Open WebUI

---

# License

Personal learning project.
