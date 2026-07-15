# Kyle's Homelab

## Overview

This repository documents my self-hosted infrastructure for building, testing, and learning enterprise infrastructure engineering, automation, identity management, observability, virtualization, and AI workloads.

The lab is designed to mirror production environments as closely as possible while remaining cost effective for home use.

See [Docs/Architecture.md](Docs/Architecture.md) for the current build, [Docs/Network.md](Docs/Network.md) and [Docs/Storage.md](Docs/Storage.md) for infrastructure detail, [Docs/AI.md](Docs/AI.md) for the AI/MCP/agents roadmap, and [Docs/LessonsLearned.md](Docs/LessonsLearned.md) for what's been learned along the way.

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
- [x] 2.5GbE switch — acquired, not yet installed/configured
- [ ] Install/configure the 2.5GbE switch and confirm NICs negotiate 2.5GbE on Proxmox/automation01/truenas01/plex01

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

## Planned

- Grafana
- Prometheus
- Loki
- Alloy
- PostgreSQL
- Redis
- Nextcloud
- Immich
- Vaultwarden
- Open WebUI
- Ollama

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

## In Progress

- [ ] Migrating existing media library onto TrueNAS
- [ ] Reconnecting/verifying the 2TB backup drive
- [ ] Installing/configuring the 2.5GbE switch
- [ ] Uptime Kuma → n8n → Discord outage alerting — design explored, not yet built (see LessonsLearned "Deferred")

## Planned

- [ ] Grafana / Prometheus / Loki monitoring stack
- [ ] Terraform
- [ ] Ansible
- [ ] Kubernetes
- [ ] Windows Server (dc01) / AD
- [ ] AI Stack (Ollama / Open WebUI via RTX 4000)
- [ ] n8n workflows calling AI (Claude / local LLMs)
- [ ] MCP fundamentals (run existing community MCP servers)
- [ ] Custom MCP server exposing homelab infrastructure (Proxmox/TrueNAS/Uptime Kuma status)
- [ ] Custom AI agents (e.g. via the Claude Agent SDK) operating against homelab services

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
