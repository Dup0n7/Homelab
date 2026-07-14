# Storage

## Physical disks

| Disk | Size | Model | Host role |
|---|---|---|---|
| Boot SSD | 512GB | SanDisk SD7SN6S512G | Proxmox OS, local-lvm (VM disks) |
| Data HDD | 4TB | WD Red WD40EFRX (CMR, NAS-rated) | Passed through to `truenas01` |
| Backup HDD | 2TB | NAS-rated (model TBD) | **Not currently detected/connected** — see Lessons Learned |

The 4TB drive is passed through to the `truenas01` VM as an individual disk (`/dev/disk/by-id/ata-WDC_WD40EFRX-...`), not a whole controller — the boot SSD shares the same SATA controller, so full controller passthrough wasn't an option on this hardware.

## TrueNAS (truenas01)

| Property | Value |
|---|---|
| Pool | `tank` |
| Layout | Single-disk stripe (**no redundancy** — accepted risk until a second matching drive is added) |
| Dataset | `tank/media` (record size `1M`, tuned for large sequential media files) |
| NFS share | `/mnt/tank/media`, currently allowed from `192.168.1.0/24` (should be narrowed to `192.168.1.50` now that `plex01` has a fixed IP) |
| SMB share | `/mnt/tank/media`, named `media` — used for bulk file copies from Windows (separate Samba password required per user) |

## VM disk layout

| VM | Boot disk | Data disk |
|---|---|---|
| automation01 | 80GB (local-lvm, SSD) | — |
| truenas01 | 32GB (local-lvm, SSD) — TrueNAS OS only | 4TB passthrough (`tank` pool) |
| plex01 | 40GB (local-lvm, SSD) | NFS mount from `truenas01:/mnt/tank/media` at `/mnt/media` |

## Backups

Not yet implemented. Per the original plan: Proxmox's native snapshots/backups first, Proxmox Backup Server deferred until the lab is large enough to benefit from deduplication (10+ VMs).

## Open items

- 2TB backup drive needs to be physically reconnected/verified before it can serve as a backup target.
- Mirror the `tank` pool once a second matching (or larger) drive is available.
