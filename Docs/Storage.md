# Storage

## Physical disks

| Disk | Size | Model | Host role |
|---|---|---|---|
| Boot SSD | 512GB | SanDisk SD7SN6S512G | Proxmox OS, local-lvm (VM disks) |
| Second SSD | 512GB | SanDisk SD7SN6S512G (M.2 SATA, same model as boot) | `ssd2-thin` LVM-Thin pool — extra VM disk storage |
| Data HDD 1 | 4TB | WD Red WD40EFRX (CMR, NAS-rated) | `tank` mirror member, passed through to `truenas01` |
| Data HDD 2 | 4TB | HGST Ultrastar HUS726040ALE610 (enterprise-class, CMR) | `tank` mirror member, passed through to `truenas01` |
| Backup HDD | 2TB | NAS-rated (model TBD) | **Not currently detected/connected** — see Lessons Learned |

Both 4TB drives are passed through to the `truenas01` VM as individual disks (`/dev/disk/by-id/...`), not a whole controller — the boot SSD shares the same SATA controller, so full controller passthrough wasn't an option on this hardware. The two drives are different models/brands (WD Red + HGST Ultrastar) — ZFS mirrors don't require matching drives, only adequate capacity, so this is a fine pairing.

## TrueNAS (truenas01)

| Property | Value |
|---|---|
| Pool | `tank` |
| Layout | **Mirror (2-wide)** — WD Red 4TB + HGST Ultrastar 4TB, extended from the original single-disk stripe on 2026-07-15, resilvered cleanly with 0 errors |
| Dataset | `tank/media` (record size `1M`, tuned for large sequential media files) |
| NFS share | `/mnt/tank/media`, currently allowed from `192.168.1.0/24` (should be narrowed to `192.168.1.50` now that `plex01` has a fixed IP) |
| SMB share | `/mnt/tank/media`, named `media` — used for bulk file copies from Windows (separate Samba password required per user) |

## VM disk layout

| VM | Boot disk | Data disk |
|---|---|---|
| automation01 | 80GB (local-lvm, SSD) | — |
| truenas01 | 32GB (local-lvm, SSD) — TrueNAS OS only | 2x 4TB passthrough, mirrored (`tank` pool) |
| plex01 | 40GB (local-lvm, SSD) | NFS mount from `truenas01:/mnt/tank/media` at `/mnt/media` |

## Backups

Not yet implemented. Per the original plan: Proxmox's native snapshots/backups first, Proxmox Backup Server deferred until the lab is large enough to benefit from deduplication (10+ VMs).

## Open items

- 2TB backup drive needs to be physically reconnected/verified before it can serve as a backup target.
- Lock down the NFS export to `plex01`'s IP specifically (still allowing the whole `/24` today).
