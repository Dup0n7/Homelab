# Ansible

## Why this is in the plan

Second step of the "Infrastructure as Code" phase (Terraform provisions → **Ansible configures** → Kubernetes orchestrates — see [Terraform.md](Terraform.md)). Also directly job-market relevant, same reasoning as Terraform/Vault: Ansible is a core platform/IAM-engineering skill, and it's specifically strong in exactly the kind of on-prem/config-management work this lab targets.

Status: **First playbook applied and verified 2026-07-23** — PostgreSQL deployed on `automation01`, storing its data on `truenas01` (NFS) rather than local disk, connected to and queried for real (`PostgreSQL 17.10`).

## Where Ansible runs: automation01, not the Windows workstation

Unlike Terraform (a self-contained Go binary with a native Windows build), **Ansible's control node has to be Linux, macOS, or WSL — it does not run natively on Windows.** Two options were weighed:
- Set up WSL2 on the Windows workstation and run Ansible from there.
- Install Ansible on `automation01` (already a Linux Docker host with SSH reachability) and run playbooks from there after a `git pull`.

**Chosen: automation01.** Fits the existing edit → commit → push → pull → deploy workflow ([Commands.md](Commands.md)) exactly as-is, no new environment to learn on the Windows side, and mirrors how Ansible is actually run in most real environments — a dedicated control/bastion host, not individual engineers' laptops.

Installed via `sudo apt-get install -y ansible` → `ansible [core 2.16.3]` (Ubuntu 24.04's package).

## Inventory: automation01 only, for now

[`Ansible/inventory.ini`](../Ansible/inventory.ini) has a single host, `automation01`, using `ansible_connection=local` — Ansible manages the very host it's running on directly, no SSH involved. This isn't a limitation of the exercise, it's a real gap: **`automation01` has no SSH keypair of its own** (checked directly — only an `authorized_keys` file for accepting incoming connections from the Windows workstation). Managing `plex01` or `truenas01` from here would need a keypair generated on `automation01` and added to those hosts' `authorized_keys` first. Not yet done — see "Open questions."

## Secrets: Ansible Vault, not a plaintext `.env`

The Postgres password is generated randomly (`openssl rand -base64 24`), then encrypted with `ansible-vault encrypt_string` before ever touching a file that gets committed:

- [`Ansible/host_vars/automation01/vault.yml`](../Ansible/host_vars/automation01/vault.yml) — the encrypted password (`vault_postgres_password`), **safe to commit** — that's the entire point of Ansible Vault, the ciphertext is meaningless without the vault password.
- The vault password itself lives at `Ansible/.vault_pass` **on automation01 only**, generated directly there via `openssl rand -base64 32`, gitignored (`**/.vault_pass`), never synced through git. Same handling pattern as Terraform's `terraform.tfvars` — the encrypted/templated config is version-controlled, the actual key that unlocks it isn't.
- The playbook renders `Ansible/templates/postgres.env.j2` into `Docker/Postgres/.env` at runtime, substituting the decrypted password — the plaintext password only ever exists on disk inside that gitignored `.env` file (same as every other service's secrets in this repo), never in git history.

## Gotcha hit: `group_vars` vs `host_vars`

First playbook run failed with `'postgres_compose_dir' is undefined` — the non-secret vars (`Ansible/host_vars/automation01/vars.yml` today) were originally placed under `group_vars/automation01/`. **`group_vars/<name>/` only applies to a *group* named `<name>`** — `automation01` is a host in the `docker_hosts` group, not a group itself, so those variable files were silently never loaded. Fix: moved both the vars and vault files to `Ansible/host_vars/automation01/`, which is the correct convention for host-specific variables. Easy mistake since the file structure looks nearly identical either way and Ansible doesn't error on an unused `group_vars` directory — it just silently doesn't apply.

## Storage: NFS-backed on truenas01, not a local Docker volume

Postgres's data directory lives on `tank/postgres` (a new dataset on `truenas01`), NFS-mounted at `/mnt/postgres` on automation01 — same pattern as `plex01`'s media mount, chosen over a local named Docker volume once it came up that local storage isn't durable and has no backups. `docker-compose.yml` bind-mounts `/mnt/postgres:/var/lib/postgresql/data` directly rather than using a named volume.

**Two real gotchas hit getting this working:**

- **NFS export network typo silently blocked the mount.** The TrueNAS NFS share was created restricted to `196.168.1.20/32` (a typo — should've been `192`.168.1.20). `showmount -e` still listed the export fine (export visibility isn't access-controlled), but actually mounting failed with `access denied by server`. Diagnosed by explicitly test-mounting from automation01 rather than trusting the share existed correctly just because it appeared in TrueNAS's UI.
- **NFS root-squash broke Postgres's own startup script.** The official `postgres` image's entrypoint runs as root specifically to `chown`/`chmod` its data directory to the `postgres` user before dropping privileges — but NFS servers by default map an incoming client's root to an unprivileged "nobody" (root squash), so that chown was silently rejected (`Operation not permitted`), and the container crash-looped forever on the same two failing commands. **Fix: set "Maproot User: root" / "Maproot Group: root"** on the TrueNAS NFS share (Sharing → NFS → Advanced Options) — scoped to just that one export, already network-restricted to automation01's IP alone, so the blast radius of granting root-equivalent NFS access is small. This is a known, common gotcha for **any** containerized app that needs to manage ownership on its own NFS-mounted data directory, not specific to Postgres.

The playbook itself handles the NFS side declaratively before ever starting the container: installs `nfs-common`, ensures the mount point exists, mounts `tank/postgres` persistently (`ansible.posix.mount`, `_netdev,nofail` — same options as `plex01`'s fstab entry), and explicitly verifies the mount is actually active via `mountpoint -q` before proceeding — otherwise Docker would silently create the bind-mount path as an empty local directory if the NFS mount wasn't there yet, masking the intended NFS storage entirely without any error.

## What the first playbook does

[`Ansible/playbooks/deploy_postgres.yml`](../Ansible/playbooks/deploy_postgres.yml):
1. Confirms Docker is present (does **not** install it — that's a bigger, separate concern; this playbook assumes Docker already exists, which it does on every host in this lab).
2. Ensures `nfs-common` is installed, the mount point exists, `tank/postgres` is mounted from `truenas01`, and confirms the mount is actually active.
3. Renders the `.env` file from the vault-encrypted password via the Jinja2 template.
4. Runs `docker compose up -d` against [`Docker/Postgres/docker-compose.yml`](../Docker/Postgres/docker-compose.yml) (`postgres:17`, matching the same one-folder-per-service convention as `Docker/Automation/` and `Docker/MCP/`).
5. Waits for `pg_isready`, retrying — Postgres takes longer to accept connections on first-time NFS-backed initialization than on local disk (many small files, NFS metadata overhead), so a single immediate check would be flaky.

Verified end-to-end, not just "container exists": connected via `docker exec postgres psql` and ran real queries (`\l`, `SELECT version()`) — confirmed `PostgreSQL 17.10` running and queryable, with its actual data files (`~7.5MB`) confirmed present on the NFS mount, not local disk.

**One-time migration note**: since Postgres had already been deployed once with a local named volume before this storage move, switching required a one-time `docker compose down -v` to discard the old local volume (safe — nothing but default/empty test databases were ever in it) before re-running the playbook against the new NFS-backed config. This teardown step was **not** added to the playbook itself — baking in "delete the old volume" as a normal, repeatable task would be dangerous once real data exists.

## Running it

From `automation01` (SSH in, or however you're driving it):
```bash
cd ~/homelab/Ansible
ansible-playbook playbooks/deploy_postgres.yml --vault-password-file .vault_pass
```

## Open questions / next steps

- [ ] Give `automation01` its own SSH keypair and authorize it on `plex01`/`truenas01` so the inventory can grow beyond a single local host.
- [ ] Decide whether `truenas01` should ever be Ansible-managed at all — it's usually driven through its own UI/API by design, unlike the general-purpose Docker hosts.
- [ ] Next phase per the original order: Kubernetes (K3s), once Terraform + Ansible both feel solid.
