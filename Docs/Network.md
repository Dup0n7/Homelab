# Network

## Home network

| Property | Value |
|---|---|
| Gateway | `192.168.1.254` |
| Subnet | `255.255.255.0` (/24) |
| Router DHCP range | `192.168.1.64` - `192.168.1.253` |
| Static IP range in use | `192.168.1.2` - `.63` (outside the DHCP pool) |

Static IPs should also get a DHCP reservation/exclusion set on the router to prevent future collisions.

## Static IP assignments

| Host | IP | Role |
|---|---|---|
| Proxmox | `192.168.1.209` | Hypervisor host |
| automation01 | `192.168.1.20` | Docker host — n8n, Portainer, Uptime Kuma |
| truenas01 | `192.168.1.40` | TrueNAS SCALE (Community Edition) — ZFS storage |
| plex01 | `192.168.1.50` | Docker host — Plex, Portainer Agent |
| dc01 | Not yet built | Reserved: `192.168.1.30` (Windows Server / AD, per original plan) |

## Remote access

Not yet configured. Original plan calls for Tailscale rather than exposing any service directly to the internet.

## Notes

- All current VMs use static IPs assigned via Proxmox cloud-init (`ipconfig0`), not DHCP reservations on the router.
- SSH access to Linux VMs uses key-based auth only (ed25519 keypair generated on the Windows workstation); cloud-init images don't set a password, so password SSH login isn't available as a fallback.

## Open items

- **Proxmox's IP (`192.168.1.209`) falls inside the router's DHCP range (`.64`-`.253`)**, unlike every other static host in this lab (all assigned in the `.2`-`.63` range specifically to avoid this). The router could theoretically hand `.209` to another device via DHCP, conflicting with Proxmox. Fix by either adding a DHCP reservation/exclusion for `.209` on the router, or re-IPing Proxmox into the safe static range — reservation is less disruptive.
- **Resolved 2026-07-17: switch installed, Proxmox upgraded past 1GbE.** Proxmox's onboard NICs (`nic0`/`nic2`) turned out to only support up to `1000baseT` — no 2.5G mode at all. The other onboard NIC pair (`nic3`/`nic4`, Intel `ixgbe`) supports `1000baseT`/`10000baseT` with nothing in between either, so rather than buying a dedicated 2.5G card, `nic3` was moved to the switch's 10G port instead — confirmed via `ethtool nic3` negotiating a full `10000Mb/s`. The Windows workstation is on one of the switch's 2.5G ports. End-to-end throughput between them is capped by the slower side (2.5G, ~280MB/s realistic ceiling) rather than Proxmox's own 10G link, but that's still roughly 2.5x the old 1GbE ceiling of ~113MB/s.
