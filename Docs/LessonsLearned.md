# Lessons Learned

## 2026-07-14

### Proxmox foundation
- Installed Proxmox VE 9.2.2 on the 512GB boot SSD, configured with a static IP on the home network.
- Home network facts: gateway `192.168.1.254`, subnet `255.255.255.0` (/24), router DHCP pool `192.168.1.64`-`192.168.1.253`. Static assignments should stay in `192.168.1.2`-`.63` or `.254`-`.255` to avoid DHCP collisions, and ideally get a DHCP reservation/exclusion on the router as well.

### automation01 (first VM)
- Built a reusable Ubuntu 24.04 cloud-init template (VMID `9000`) via `qm importdisk` from the official Ubuntu cloud image, instead of uploading/installing from an ISO. Cloned it to create `automation01` (VMID `101`) — this pattern is reused for every Linux VM since, and matches how Terraform will eventually provision VMs.
- `qm set --sshkeys` runs **on the Proxmox host** and needs a host-side file path — a Windows path like `C:\Users\...\id_ed25519.pub` doesn't exist from the host's perspective. Easiest fix: paste the public key directly into the VM's **Cloud-Init** tab in the Proxmox web UI rather than fighting file transfer.
- SSH key auth works with zero password prompts by design once the public key is injected via cloud-init — cloud-init images typically don't even set a password for the user, so this isn't a misconfiguration.
- n8n requires `N8N_SECURE_COOKIE=false` to allow login over plain HTTP; remove this once a reverse proxy with TLS is in front of it.
- Portainer's first-run admin setup uses a token/password printed to `docker logs portainer`, not a fixed default — and it expires (~5 minutes). If missed, `docker compose restart portainer` generates a fresh one.
- Uptime Kuma reported Portainer and Proxmox as "down" even though both were reachable — caused by their self-signed HTTPS certificates failing Uptime Kuma's default TLS validation. Fixed per-monitor via "Ignore TLS/SSL error for HTTPS websites."

### truenas01 (storage)
- TrueNAS SCALE has apparently rebranded the free tier as "TrueNAS Community Edition" (version `25.10.4` at time of install), replacing the old fish-codename releases (Angelfish/Bluefin/Cobia/etc.). Functionally still the same Linux/OpenZFS lineage previously called SCALE.
- After completing the installer and rebooting, the VM booted straight back into the installer instead of the installed OS — caused by the boot order still prioritizing the CD-ROM (`ide2`) device. Fixed by detaching the ISO (`qm set 200 --ide2 none,media=cdrom`) and setting `qm set 200 --boot order=scsi0`.
- ZFS pool creation failed with `Disks have duplicate serial numbers: None (sda, sdb)` — QEMU virtual SCSI disks don't get a serial number by default, so TrueNAS's safety check can't tell the boot disk and the passed-through 4TB drive apart. Fixed by adding an explicit `serial=` value to each disk in `qm set` (e.g. `qm set 200 --scsi1 /dev/disk/by-id/...,size=...,serial=truenas01data`).
- The 4TB drive (WD Red `WD40EFRX`, identified via `/dev/disk/by-id/ata-WDC_WD40EFRX-...`) was passed through directly to the VM rather than an entire controller, since the boot SSD shares the same controller. This is a common and accepted homelab approach, though it means TrueNAS only sees that one disk rather than owning the whole HBA.
- Only 2 physical disks are currently visible on the Proxmox host (the 512GB boot SSD and the 4TB WD Red) — **the 2TB backup drive from the original hardware plan is not currently connected/detected.** Needs follow-up.
- Built the `tank` pool as a **single-disk stripe** (no redundancy) on the 4TB drive, since there's no second matching drive yet. This is an accepted, deliberate risk for now — the drive fully protects against nothing until it's mirrored.
- SMB requires a separate "Samba Password" per user, distinct from the TrueNAS web UI login password — easy to miss when setting up a Windows-mapped drive for the first time.

### plex01 (media)
- Added as an unplanned addition to consolidate an existing separate Plex server onto the new lab, using the 4TB drive (via TrueNAS NFS export) as shared storage.
- Plex's browser-based "claim" flow returned `Not authorized — You do not have access to this server` on first attempt. The reliable fix for Docker/headless installs is the `PLEX_CLAIM` environment variable (one-time token from `plex.tv/claim`, expires in ~4 minutes) rather than relying on the web UI auto-detecting the unclaimed local server.
- Portainer only has visibility into the Docker daemon it's directly socket-mounted into (`automation01`). Seeing containers on another VM (`plex01`) requires deploying the **Portainer Agent** on that VM and registering it as a separate "environment" in Portainer — it does not automatically discover other Docker hosts on the network.
- Portainer Community Edition has no unified container view across environments — you have to actively switch the selected environment in the UI to see that host's containers. A real "all containers, all hosts" dashboard is deferred to the still-pending Grafana/Prometheus monitoring stack.
- Windows-to-SMB copy throughput capped around 113 MB/s, which is the expected practical ceiling for 1GbE (1000 Mbps ÷ 8 = 125 MB/s theoretical, ~110-118 MB/s realistic after overhead) — not a misconfiguration. Would need 2.5GbE/10GbE end-to-end to exceed it.

### General
- Added a repo-root `.gitignore` (`*.env`) early, before adding services with real credentials (Postgres, Redis, etc.), so secrets never get committed by accident.
