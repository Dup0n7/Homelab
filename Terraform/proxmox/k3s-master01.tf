# First Kubernetes node in this lab - single-node K3s (control plane + worker
# in one), chosen specifically for its small RAM footprint (no separate etcd,
# ships as one binary) over a full kubeadm-style multi-node setup. See
# Docs/Kubernetes.md for why K3s and why single-node.
#
# Same clone-from-template pattern as the tf-test01 example (not an import -
# this VM doesn't exist yet): agent.enabled = false because the reusable
# template (VMID 9000) has no qemu-guest-agent installed, confirmed during
# the original tf-test01 exercise - relying on it would hang apply for its
# full 15m timeout. Static IP via cloud-init sidesteps needing the agent for
# IP discovery anyway.

resource "proxmox_virtual_environment_vm" "k3s_master01" {
  name      = "k3s-master01"
  node_name = var.proxmox_node_name
  tags      = ["terraform-managed", "k3s"]

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  agent {
    enabled = false
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 40
  }

  initialization {
    user_account {
      username = var.vm_user
      # Two keys: the Windows workstation's (matches every other VM, personal
      # SSH access) and automation01's dedicated Ansible key (matches
      # Docs/Ansible.md's cross-host pattern - baked in at creation instead
      # of appended to authorized_keys after the fact like plex01 needed).
      keys = [
        trimspace(file(var.ssh_public_key_path)),
        var.ansible_public_key,
      ]
    }

    ip_config {
      ipv4 {
        address = "192.168.1.60/24"
        gateway = var.vm_gateway
      }
    }
  }
}

output "k3s_master01_ipv4" {
  description = "Static IPv4 address assigned to k3s-master01 via cloud-init (not agent-reported - see agent block comment above)"
  value       = "192.168.1.60"
}
