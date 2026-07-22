# First Terraform-managed VM in this lab. Deliberately a disposable test VM
# (not one of the existing hand-built hosts) so `terraform apply`/`destroy`
# carry zero risk to automation01/truenas01/plex01 while learning the workflow.
# See Docs/Terraform.md for context and next steps (e.g. importing an existing VM).

resource "proxmox_virtual_environment_vm" "tf_test01" {
  name      = "tf-test01"
  node_name = var.proxmox_node_name

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  agent {
    # Confirmed 2026-07-22: the template (VMID 9000) does NOT have
    # qemu-guest-agent installed, so `enabled = true` here would make
    # `apply` hang until its 15m timeout waiting for a response that never
    # comes. Static IP below sidesteps needing the agent for IP discovery
    # anyway. Revisit if the template ever gets the agent added.
    enabled = false
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  initialization {
    user_account {
      username = var.vm_user
      keys     = [trimspace(file(var.ssh_public_key_path))]
    }

    ip_config {
      ipv4 {
        address = "${var.vm_ip}/24"
        gateway = var.vm_gateway
      }
    }
  }
}
