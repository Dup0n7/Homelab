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

## 2026-07-17

### 2.5GbE switch install — "2.5GbE" doesn't mean every NIC does 2.5G
- Installed the switch and expected to just plug Proxmox into a 2.5G port and be done. Instead, `ethtool` revealed **none of Proxmox's onboard NICs support 2.5G at all**: `nic0`/`nic2` only go up to `1000baseT/Full`, and `nic3`/`nic4` (Intel `ixgbe` — the same NICs behind those repeating firmware warnings seen in `dmesg` back on 2026-07-15) jump straight from `1000baseT` to `10000baseT` with no 2.5G step in between. 1G/10G dual-speed enterprise NICs and 2.5G "multi-gig" consumer/prosumer NICs (Intel I225/I226, Realtek RTL8125) are different hardware families — a card supporting one doesn't imply it supports the other.
- `ethtool <iface>` reports **supported link modes from the hardware/PHY itself**, not from an active link — so every port could be checked (`ethtool nic0`, `nic2`, etc.) without touching a single cable, before deciding which one to actually move.
- **Resolution**: rather than buying a dedicated 2.5G PCIe card, moved Proxmox's existing 10G-capable NIC (`nic3`) to the switch's 10G port instead — confirmed via `ethtool nic3` negotiating a full `10000Mb/s`. This beats the original 2.5G goal outright. The Windows workstation went on one of the switch's 2.5G ports.
- **Important nuance**: since every VM's network traffic (TrueNAS, Plex, everything) shares this one physical host NIC through the `vmbr0` bridge, this single card's negotiated speed is the real ceiling for the whole lab's external throughput — VMs' virtual NICs don't have a meaningful "speed" of their own to configure.
- End-to-end throughput between the Windows PC and the lab is capped by the **slower** end of any given link, not the faster one — Proxmox's 10G doesn't help a transfer whose other end is only on 2.5G. Realistic ceiling is now ~280MB/s (2.5G) versus the old ~113MB/s (1GbE), a ~2.5x improvement, not a 10x one.

### Storage speed: NVMe evaluated and declined
- After the network stopped being the bottleneck, Windows-to-`tank` copy speed leveled off around ~150MB/s — this is the HDD mirror's own sequential write ceiling, not a new problem. Considered NVMe storage or a ZFS cache/log device (L2ARC/SLOG) and declined: L2ARC only accelerates random reads and SLOG only accelerates synchronous writes, neither of which describes a bulk async file copy, so neither would have actually fixed this. True 1GB/s+ throughput needs NVMe-class storage or many HDDs striped in parallel — either a real cost or a real pool restructuring, not a small tweak. Declined because the actual workload (Plex streaming) needs a small fraction of what the HDD mirror already provides; full reasoning in [Storage.md](Storage.md) "Decisions."

### Custom MCP server (`homelab-uptime-kuma`)
- **Docker Desktop vs. Docker Engine confusion, resolved**: "Docker Desktop won't run on headless Linux" is true but irrelevant — Docker Desktop is a separate Windows/Mac GUI product. Plain Docker Engine (`docker-ce`, no GUI) already runs everything in this lab on headless Ubuntu VMs; there was never an actual blocker to hosting anything in Docker on `automation01`.
- **The MCP TypeScript SDK is mid-transition between a stable v1 and an unreleased v2**, and this cost real time to untangle. The GitHub repo's `main` branch is a monorepo of `2.0.0-beta.4` packages (`@modelcontextprotocol/server`, `-legacy`, etc.) — building against these would have meant depending on unreleased beta code. The actual current **stable** package (what `npm install` gets by default) is `@modelcontextprotocol/sdk` v1.29.0, confirmed via the npm registry's `dist-tags` directly rather than trusting GitHub's default branch. **Lesson: for any actively-evolving SDK, check the npm registry's "latest" dist-tag before building against whatever the repo's default branch shows** — a default branch can easily be ahead of what's actually published/stable.
- Streamable HTTP (not stdio, not the older HTTP+SSE) is the current standard transport for remote MCP servers, confirmed against a real verified example (`src/examples/server/simpleStreamableHttp.ts`) pulled from the actual v1.29.0 tag. Session handling is manual: the server keeps an in-memory `Record<sessionId, transport>` map, keyed by the `Mcp-Session-Id` header Streamable HTTP clients send after the first `initialize` request.
- **The `claude` CLI wasn't reachable from any shell tried** — not from Claude Code's own Bash tool, not from PowerShell, not from the user's own terminal. Root cause not identified (environment/PATH-specific). Workaround: hand-write `.mcp.json` directly at the repo root in the exact format `claude mcp add --scope project` would have produced (`{"mcpServers": {"<name>": {"type": "http", "url": "..."}}}`) — this works identically without needing the CLI at all.
- **Project-scoped servers defined via `.mcp.json` require a one-time interactive approval** before Claude Code will actually use them — run `claude` interactively in the project and approve when prompted. This is a deliberate safety measure (a cloned repo can't silently smuggle in an MCP server), not a bug. MCP servers also only load at session start, so a brand-new Claude Code session is needed after either adding or approving one.
- Chose TypeScript/Node over Python for this and future MCP/agent work specifically because it better matches the target job market (IAM/platform engineering roles), not for a technical reason — worth remembering as the default language choice for the rest of the AI/MCP roadmap in [AI.md](AI.md).

## 2026-07-18

### n8n-mcp SSRF protection blocks a self-hosted n8n by default
- The `mcp-n8n` container's documentation/node-search tools worked fine, but every `n8n_*` management tool (create/update/list workflows) failed with `SSRF protection: Private IP addresses not allowed`. n8n-mcp's built-in SSRF guard treats any RFC1918 address as suspicious by default — which is exactly what a self-hosted n8n's `N8N_API_URL` always is (`http://192.168.1.20:5678`).
- Fix: `WEBHOOK_SECURITY_MODE=permissive` in `Docker/MCP/.env` (documented in `.env.example`). Safe here since n8n never leaves the LAN/Tailscale boundary; cloud metadata endpoints stay blocked in every mode regardless of this setting.

### Reddit's Developer Platform now requires pre-approval for new apps
- Attempted to create a Reddit "web app" (for a native Reddit node + OAuth2 credential, to pull posts from r/Claude, r/ClaudeAI, r/ClaudeCode, r/OpenAI, r/artificial for an n8n digest workflow) and hit Reddit's "Responsible Builder Policy" — new API access now requires an explicit approval request, not instant self-serve creation like it used to.
- Pivoted to Reddit's still-open, credential-free RSS endpoints instead (`reddit.com/r/{sub}/new/.rss`), which support the same multi-subreddit "+" combining syntax as the JSON API (e.g. `r/Claude+ClaudeAI+ClaudeCode+OpenAI+artificial`) — one RSS Feed Read node covers all 5 subreddits, no OAuth needed at all.

### JSearch (RapidAPI) `/search` endpoint is deprecated — use `/search-v2`
- The older `/search` endpoint returned jobs directly under `response.data` (an array). `/search-v2` nests them one level deeper: `response.data.jobs`. Code written for the old shape throws `(response.data || []).slice is not a function` at runtime, since `data` is now an object, not an array.
- **Lesson**: confirm the actual response shape from a real execution (`n8n_executions` in error mode surfaces the full upstream payload) rather than assuming docs/memory match whatever API version is currently live — RapidAPI listings especially can move to a `-v2` endpoint with a breaking shape change and leave the old one still technically reachable.

### n8n architecture gotcha: multiple wires into one input ≠ one execution
- Assumed that connecting several branches into the same input slot on a regular node (e.g. a Code node) would make n8n wait for all of them and run once with the combined data. This is wrong. Only a `Merge` node explicitly waits for multiple inputs before executing once — a regular node with several incoming wires on the same input slot runs once **per incoming branch** instead.
- Symptom: a single Discord webhook node fired multiple times per scheduled run, each with only a partial slice of the aggregated data, instead of sending one clean combined message.
- Fix: chain real `Merge` nodes (append mode) ahead of any node that must run exactly once per trigger. Since Merge only supports 2 inputs at a time (`numberOfInputs` defaults to 2 — see the n8n-node-configuration skill's Merge gotcha), converging N upstream branches into one downstream node always needs N-1 chained Merges.
- **General rule going forward**: any node meant to execute once per trigger, fed by more than one upstream branch, needs an explicit Merge chain — never rely on multiple direct connections into the same input to combine data.

### Discord message formatting
- `[text](url)` markdown-style masked links don't render in a plain Discord message's `content` field (Discord only supports that inside embeds) — switched to plain text followed by the raw URL wrapped in `<...>`, which keeps the link clickable while suppressing the automatic embed/preview. Paired with the message's `SUPPRESS_EMBEDS` flag for a second, more reliable layer of preview suppression.
- Any third-party text echoed into a Discord message (job titles, video titles, article headlines) can accidentally contain `@here`/`@everyone`-shaped substrings that Discord will parse as a real mention/ping. Defensive fix: insert a zero-width space after every `@` in untrusted text before building the message (`text.replace(/@/g, '@​')`).

### First real n8n workflow built via `n8n-mcp`: `Daily Job & Learning Digest`
- Built entirely through `n8n-mcp` tool calls (`search_nodes`, `get_node`, `n8n_create_workflow`, `n8n_update_partial_workflow`, `validate_workflow`, `n8n_executions`) rather than the n8n UI — the first time the workflow-management half of the toolchain was exercised end-to-end, not just docs/node lookups.
- n8n's public API cannot externally trigger a Schedule Trigger workflow — only webhook/form/chat triggers can be invoked via `n8n_test_workflow`. Testing a scheduled workflow requires clicking **Test workflow** in the n8n editor itself, then inspecting the resulting run via `n8n_executions` (list, then get by id with `mode: "error"` to see the exact failing node/payload).
- Full workflow detail in [AI.md](AI.md).

## 2026-07-21

### Several open items closed out
- **Media library migration to TrueNAS: complete.** All media files copied over to `tank/media` on `truenas01`.
- **`/uptime-status` slash command: confirmed working.** Was added 2026-07-18 but unverified since custom commands only load at session start; now confirmed end-to-end.
- **2TB backup drive: dropped from the plan, not just deferred.** It was never successfully detected/reconnected since first flagged 2026-07-14 (see that date's entry above), and it's no longer needed — removed from Storage.md/README rather than left as a perpetual "needs follow-up" item. Decision recorded in [Storage.md](Storage.md) "Decisions."

### `speedtest-cli` massively understates multi-gigabit link speed
- An internet speed test run from Proxmox over SSH (`speedtest-cli`, the Python tool) returned only 850 Mbps down / 274 Mbps up — alarming next to a PC on the same LAN's 2.5G switch port getting 2357/2337 Mbps, especially since Proxmox sits on the faster 10G switch port.
- Root cause was entirely tooling, not the network: `speedtest-cli` uses a single TCP connection, which is bandwidth-delay-product limited — throughput per stream drops sharply as latency rises, and it had picked a distant test server (~81ms RTT) on top of that. Neither issue is visible from the tool's output unless you notice the server it picked.
- A second gotcha compounded it: the official Ookla apt-repo install script (`packagecloud.io/.../script.deb.sh`) failed with a 404 because its OS detection doesn't yet recognize Proxmox's Debian 13 ("trixie") base — but the script's failure was easy to miss, and `speedtest` still ran afterward using the pre-existing Python `speedtest-cli`, silently masking that the "real" Ookla CLI was never actually installed.
- Fix: download the Ookla CLI's static binary directly from `install.speedtest.net` rather than relying on the repo script (`curl -LO https://install.speedtest.net/app/cli/ookla-speedtest-<version>-linux-x86_64.tgz`, extract, run). Re-running against a nearby server gave 4974 Mbps down / 5058 Mbps up, 0% loss — consistent with a ~5-Gig AT&T Fiber plan and confirming there was never a real network problem.
- **General lesson: for any link expected to exceed ~1 Gbps, use a multi-connection tool (the real Ookla CLI, `iperf3` with `-P`) — single-stream Python `speedtest-cli` will report numbers well below the true link capacity and can look like a false alarm.** Full detail in [Network.md](Network.md).
