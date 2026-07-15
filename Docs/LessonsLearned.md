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

## 2026-07-15

### Hardware: second SSD and second 4TB HDD
- A wiped/repurposed second 512GB SSD (identical model to the boot SSD) was built into a new `ssd2-thin` LVM-Thin pool on Proxmox for extra VM disk storage. Confirmed it's **M.2 SATA, not NVMe** — the giveaway is that it shows up as `/dev/sdX` with an `ata-` prefixed `by-id` path rather than `/dev/nvmeXn1`/`nvme-` prefix; "M.2" is only the connector shape, not the protocol. So this addition relieves I/O contention across VMs but isn't a raw speed upgrade, since it shares the same SATA ceiling (~550MB/s) as the existing boot SSD.
- A second 4TB HDD (HGST Ultrastar `HUS726040ALE610`) wasn't detected by Proxmox at all after installing it — no trace in `dmesg`, not even a failed link attempt. Root cause was physical: reseating the SATA data and power cables (and trying a different port) fixed it. This is the **second** drive in this lab to have a "not detected" scare (the original 2TB backup drive, still unresolved) — worth suspecting cabling/connector availability first on this hardware before assuming a software problem.
- **Proxmox `/dev/sdX` letters are not stable** — confirmed for a third time across sessions; they reassigned again the moment the new drive was added. Always re-run `ls -la /dev/disk/by-id/ | grep -v part` fresh and cross-check serial numbers immediately before any destructive or passthrough command — never trust a remembered letter mapping, even from earlier in the same session.
- Applying the earlier duplicate-serial lesson proactively (`serial=` set on the `qm set --scsiN` command from the start, instead of after hitting the error) avoided repeating that TrueNAS pool-creation failure this time.

### ZFS mirror
- Extended the previously-unmirrored `tank` pool into a proper mirror via TrueNAS's **Storage → (pool) → Extend** on the existing single-disk vdev, adding the new HGST drive. Resilvered cleanly in 11 seconds (only ~1.7GB of real data existed yet), 0 errors. Confirmed via `zpool status tank` — the two disks must appear nested under a shared `mirror-0` line; if they'd shown as separate top-level vdevs instead, that would have been an (undesired) stripe, not a mirror.
- ZFS mirrors don't require matching drives — pairing a WD Red with an HGST Ultrastar (different brand entirely) worked with no issue, only capacity needs to be adequate.

### Homepage dashboard
- Added [gethomepage.dev](https://gethomepage.dev) to `automation01` as a single-pane landing page linking every service, configured entirely via mounted YAML files (`settings.yaml`, `services.yaml`, `widgets.yaml`, `bookmarks.yaml`).
- Hit a `Host validation failed` error on first load — recent Homepage/Next.js versions validate the incoming `Host` header to prevent DNS-rebinding-style attacks, and reject requests from hosts not explicitly allowed. Fixed by setting `HOMEPAGE_ALLOWED_HOSTS=192.168.1.20:3000` in the container's environment.
- **Reinforced an important workflow gap**: editing files on the Windows dev machine only changes the local repo there. For a VM's `git pull` to see anything new, changes must be **committed locally *and* pushed to GitHub** first — `git pull` fetches from the remote, not from wherever the edits were actually made. This caused real confusion twice (Homepage not starting, then not picking up config changes) before the full edit → commit → push → pull → redeploy chain was made explicit.

### Uptime Kuma major version upgrade (1.23.17 → 2.4.0)
- The compose file pinned the image to `louislam/uptime-kuma:1` (floating within major version 1 only) — this is why `docker compose pull && up -d` silently did nothing when v2 came out. Floating tags only follow their pinned major version by design; this is a safety feature, not a bug.
- Bumping the tag straight to `:2` on the live production container caused a real (if brief) outage while it ran its internal database migration on first boot — normal behavior for a major version jump with a schema change, not a failure, but unsettling in the moment since the page was simply unreachable until the migration finished (~1 minute).
- **Lesson for future major-version upgrades**: don't test a migration against the live data volume first. Clone the named volume, run the new image against the clone in a disposable container on a throwaway port, confirm it starts and migrates cleanly, *then* redeploy production with confidence. The cutover still briefly migrates the live volume for real (the clone can go stale while testing), but the risk of an unknown/broken migration is eliminated before touching production.

### Deferred
- Explored two different architectures for Uptime Kuma → n8n → Discord outage alerting (webhook-push with time-window batching via workflow static data; then a poll-and-diff design against Uptime Kuma's Prometheus `/metrics` endpoint) before pivoting toward having n8n health-check services directly via HTTP rather than depending on Uptime Kuma's API shape at all. **Not yet implemented** — pinned for a later session. Whenever I pick this up next, I should start from the direct-HTTP-polling design (Schedule Trigger → per-service HTTP checks with `Ignore SSL Issues` + `On Error: Continue` → diff against last-known state via `$getWorkflowStaticData` → Discord only on change), not the earlier Uptime Kuma-dependent versions.
