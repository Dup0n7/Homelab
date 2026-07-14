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
| Proxmox | TBD | Hypervisor host |
| automation01 | `192.168.1.20` | Docker host — n8n, Portainer, Uptime Kuma |
| truenas01 | `192.168.1.40` | TrueNAS SCALE (Community Edition) — ZFS storage |
| plex01 | `192.168.1.50` | Docker host — Plex, Portainer Agent |
| dc01 | Not yet built | Reserved: `192.168.1.30` (Windows Server / AD, per original plan) |

## Remote access

Not yet configured. Original plan calls for Tailscale rather than exposing any service directly to the internet.

## Notes

- All current VMs use static IPs assigned via Proxmox cloud-init (`ipconfig0`), not DHCP reservations on the router.
- SSH access to Linux VMs uses key-based auth only (ed25519 keypair generated on the Windows workstation); cloud-init images don't set a password, so password SSH login isn't available as a fallback.
