# Kyle's Homelab

## Overview

This repository documents my self-hosted infrastructure for building, testing, and learning enterprise infrastructure engineering, automation, identity management, observability, virtualization, and AI workloads.

The lab is designed to mirror production environments as closely as possible while remaining cost effective for home use.

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
| Storage | 4 TB NAS HDD |
| Backup | 2 TB NAS HDD |

---

# Hypervisor

- Proxmox VE 9.x
- Static IP
- Local SSD VM Storage

---

# Virtual Machines

| VM | Purpose | Status |
|----|----------|--------|
| automation01 | Docker / Terraform / Ansible | 🚧 |
| dc01 | Windows Server | Planned |
| win11-test01 | Test workstation | Planned |
| truenas01 | NAS | Planned |
| k3s-master01 | Kubernetes | Planned |
| k3s-worker01 | Kubernetes | Planned |

---

# Docker Services

Planned

- Portainer
- Grafana
- Prometheus
- Loki
- Alloy
- Uptime Kuma
- n8n
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

- 4 TB Primary Storage
- 2 TB Backup Storage

## Future

- ZFS Mirror
- Snapshots
- Automated Backups

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

Static IPs

| Device | Address |
|---------|---------|
| Proxmox | TBD |
| automation01 | TBD |
| dc01 | TBD |
| TrueNAS | TBD |

---

# Learning Progress

## Completed

- [x] Install Proxmox
- [x] Configure Static IP

## In Progress

- [ ] Ubuntu Automation VM
- [ ] Docker
- [ ] Docker Compose

## Planned

- [ ] Grafana
- [ ] Terraform
- [ ] Ansible
- [ ] Kubernetes
- [ ] TrueNAS
- [ ] AI Stack

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

---

# License

Personal learning project.
