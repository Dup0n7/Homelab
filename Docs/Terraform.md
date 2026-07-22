# Terraform

## Why this is in the plan

First step of the "Infrastructure as Code" phase from the original roadmap (Terraform provisions → Ansible configures → Kubernetes orchestrates, see [AI.md](AI.md)-style layering in the main learning-progress notes). Also directly job-market relevant — Terraform/HCL is a core platform-engineering skill, same reasoning as the earlier HashiCorp Vault decision (see [Security.md](Security.md)).

Status: **automation01 imported and under management 2026-07-22.** Full lifecycle now proven: created a disposable test VM from scratch (`tf-test01`, applied → SSH-verified → destroyed cleanly), then imported the real `automation01` VM into Terraform state with `terraform plan` showing only one benign cosmetic diff.

## Provider: `bpg/proxmox`

Chosen over the older `Telmate/proxmox` provider — more actively maintained, better cloud-init/clone support. Pinned to `~> 0.111` in [`Terraform/proxmox/provider.tf`](../Terraform/proxmox/provider.tf) (latest release as of 2026-07-21).

## What's built so far

`Terraform/proxmox/` — provider config, variables, and:

- **`automation01.tf`** — the real, actively-running `automation01` VM (VMID `101`: n8n, Portainer, Uptime Kuma), imported into Terraform state 2026-07-22. Built via `terraform plan -generate-config-out`, which reads the VM's actual live config from Proxmox and writes a matching resource block automatically — far less error-prone than hand-transcribing every attribute. `terraform plan` against it now shows only one cosmetic diff (`operating_system.type`, a Computed provider field — see "Gotchas hit"), no destructive changes. **automation01 is now Terraform-managed** — see "What changes when Terraform manages a running VM" below for what that means day to day.
- **`examples/tf-test01/`** (`main.tf` + `outputs.tf`, moved out of the active config 2026-07-22) — the disposable test VM used to learn the plan/apply/destroy cycle before touching anything real. Cloned from the Ubuntu 24.04 cloud-init template (VMID `9000`), static IP `192.168.1.21`, `kyle` cloud-init user — applied, SSH-verified, then destroyed cleanly. Kept as a reference pattern for provisioning a fresh VM from the template, but moved out of `Terraform/proxmox/`'s working directory so it doesn't get recreated on every `plan`/`apply` (Terraform only reads `.tf` files directly in the working directory, not subfolders).

**Why import automation01 instead of leaving it out of Terraform entirely:** this is what "codify existing infrastructure" actually means in practice — writing a resource block that matches a real, already-running VM and importing it into state, then iterating on `terraform plan` until it shows (near-)zero changes. It's a better exercise than `tf-test01` precisely because it's less forgiving: a resource block that doesn't match reality can make `apply` try to "fix" perceived drift by modifying or recreating a VM real services depend on — which is exactly why `tf-test01` came first, to learn the mechanics somewhere with zero stakes.

## What changes when Terraform manages a running VM

Once a VM is imported, Terraform believes it owns that resource's configuration — this cuts both ways:

- **Want to change automation01's config?** Edit `automation01.tf`, `terraform plan`, `terraform apply` — Terraform makes the real change on Proxmox.
- **Change it manually instead** (Proxmox UI, `qm set`, like before)? The next `terraform plan` shows that as **drift** — a diff between what's declared and what's real — and an unnoticed `apply` afterward would try to revert it back to whatever the `.tf` file says. From here, VM-level config changes to automation01 should go through Terraform, not ad hoc `qm` commands, or the two drift apart. (What runs *inside* the VM — Docker containers, n8n workflows — is untouched by any of this; that's Ansible's/Docker Compose's domain, not Terraform's.)
- **Does an `apply` bring the VM down?** Depends what's changing. CPU cores, memory, tags, description, and network device changes all apply live, no downtime. Changing `boot_order` or resizing a disk (since `disk` isn't in our `hotplug` list) requires a reboot — and since `reboot_after_update = true` (the provider's default, present in the imported config), Terraform performs that reboot **automatically** as part of `apply` rather than asking first. Worth being deliberate about timing specifically for disk-size/boot-order changes; everything else (including routine RAM/CPU bumps) is safe to apply anytime.

## One-time setup — Proxmox API token (manual, do this first)

Terraform authenticates to Proxmox via an API token, not the root password. Creating the user/token is done in the Proxmox web UI — not scriptable from outside it — but **the actual permission grants are much easier via the Proxmox node's built-in Shell (`pveum` CLI) than the Permissions page's GUI**, see "Gotchas hit" below for why.

1. **Datacenter → Permissions → Users → Add** — create a dedicated user, e.g. `terraform@pve` (realm: Proxmox VE authentication server). Using a dedicated user instead of `root@pam` is the least-privilege move — same principle behind everything else in [Security.md](Security.md).
2. **Datacenter → Permissions → API Tokens → Add** — User: `terraform@pve`, Token ID: `terraform`, leave **Privilege Separation** checked. **Copy the generated secret immediately — Proxmox only shows it once.**
3. Copy [`terraform.tfvars.example`](../Terraform/proxmox/terraform.tfvars.example) to `terraform.tfvars` in the same folder (already gitignored) and paste the full token (`terraform@pve!terraform=<uuid>`) into `proxmox_api_token`.
4. Grant the **token itself** (not just the user — see gotcha below) permissions across the three domains a VM clone touches, via node **pve → Shell** in the Proxmox web UI:
   ```bash
   pveum acl modify /                        --tokens 'terraform@pve!terraform' --roles PVEVMAdmin
   pveum acl modify /storage                 --tokens 'terraform@pve!terraform' --roles PVEDatastoreUser
   pveum acl modify /sdn/zones/localnetwork   --tokens 'terraform@pve!terraform' --roles PVESDNUser
   ```

## Gotchas hit getting the first apply through (2026-07-22)

### API tokens with Privilege Separation don't inherit the user's permissions
Granting `PVEVMAdmin` to the plain user `terraform@pve` did nothing for the token — with Privilege Separation enabled (the default, and the right choice for least-privilege), **the token is its own principal** (`terraform@pve!terraform`) and needs its own explicit ACL grants, conceptually the same as a scoped OAuth app registration being distinct from the user who owns it. The token also **didn't show up in the Permissions page's "Add: User Permission" dropdown** — a real Proxmox UI gap — so the reliable path is the `pveum acl modify` CLI via the node's built-in Shell (no SSH setup needed, it's a browser-based root shell right in the Proxmox web UI).

### Proxmox splits permissions by resource domain, not by "task"
Cloning a VM with a disk and a network device touches **three separate permission domains** — VM/compute (`VM.Clone`, path `/vms/<template-id>`), storage (`Datastore.AllocateSpace`, path `/storage/<datastore>`), and SDN/networking (`SDN.Use`, path `/sdn/zones/<zone>`) — and no single built-in role spans all three. Hit each one as a separate 403 in turn: `PVEVMAdmin` (compute) → `PVEDatastoreUser` (storage) → `PVESDNUser` (network, since Proxmox 9's SDN model wraps even plain Linux bridges like `vmbr0` in an implicit `localnetwork` zone for permission-checking purposes). All three are now granted at broad-enough paths (`/`, `/storage`, `/sdn/zones/localnetwork`) that future VMs/storage pools shouldn't repeat this.

### Template (VMID 9000) doesn't have `qemu-guest-agent`
`terraform apply` sat at "Creating..." for 5+ minutes with the VM already visible and booted in Proxmox — turned out to be `agent { enabled = true }` waiting (up to its 15-minute timeout) for a guest-agent response that was never going to come, confirmed via the VM's Summary tab showing "guest agent not running" despite a live login prompt on the console. Fix: set `agent.enabled = false` and switch from DHCP to a **static IP** (`192.168.1.21`, matching how every other host in this lab is already assigned per [Network.md](Network.md)) so IP discovery never depends on the agent at all. Confirmed the IP was actually free first via `Test-Connection`/ping before assigning it. Installing the agent in the template itself would be the more complete long-term fix (benefits every future clone) — not yet done, noted as an open item below.

### Importing an existing VM: Computed fields don't converge to zero-diff no matter what you write
Getting `automation01`'s `plan` down to zero changes wasn't fully achievable — `operating_system.type` kept showing as a diff (`+ type = "other"`) regardless of whether the config set it to `null`, `"other"`, or omitted the block entirely. Root cause: it's a Computed attribute the provider resolves to its own default at plan time rather than something reconciled against the config value — the "current state" from import genuinely has no cached value for it yet, since the import/refresh path doesn't populate every Computed field the way a full `Read` after `apply` does. **Lesson: for imports, a few single-attribute, non-destructive diffs on Computed fields are normal and not a sign the resource block is wrong** — the thing to actually scrutinize in the plan is whether anything shows as `-/+ create replacement` (destroy+recreate) or changes a hardware-affecting attribute unexpectedly; a lone `~ update in-place` on a cosmetic field like this is safe to just apply.

### A destroyed resource's `.tf` file doesn't stop wanting to exist
After `terraform destroy` on `tf-test01`, its resource block was still sitting in `main.tf` — so the very next `plan` showed "1 to add" for it again (destroy removes it from real infrastructure *and* state, but not from the declared config). Not a bug, just something to remember: once a resource's learning purpose is served, either remove it from the working directory's `.tf` files or move it somewhere Terraform won't auto-load it (moved to `examples/tf-test01/` here, since Terraform only reads `.tf` files directly in its working directory, not subfolders).

## Running it

**Careful: `Terraform/proxmox/` now manages the real `automation01` VM directly**, not just a disposable test resource. `terraform plan` before `apply`, always — and check the plan for anything unexpected before approving.

```bash
cd Terraform/proxmox
terraform init
terraform plan      # review before ever applying — especially now that automation01 is in scope
terraform apply
```

To experiment with provisioning a fresh VM again without touching automation01, copy `examples/tf-test01/*.tf` back into `Terraform/proxmox/` (or a separate working directory), `apply`, then `destroy` when done — same disposable pattern as before.

## Open questions / next steps

- [x] `terraform destroy` on `tf-test01` — confirmed clean 2026-07-22, full create/destroy lifecycle proven.
- [x] `terraform import` against `automation01` — complete 2026-07-22, see "Gotchas hit" below for the full trail.
- [ ] Install `qemu-guest-agent` in the template (VMID `9000`) so future clones can use DHCP + agent-based IP discovery if wanted — not required (static IP works fine without it) but the more complete fix.
- [ ] Remote state (currently local `terraform.tfstate`, gitignored) — fine solo, but worth learning a remote backend eventually since that's standard in team environments.
- [ ] Next phase: Ansible, starting with the prioritized PostgreSQL deployment (see README's Learning Progress).
