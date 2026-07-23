# Imported from the real, already-running plex01 VM (VMID 102) on 2026-07-23
# via `terraform plan -generate-config-out` against live Proxmox state, then
# hand-cleaned the same way as automation01.tf: removed invalid
# `cpu.units = 0`, removed `mac_addresses` (Computed, live-agent-reported —
# see automation01.tf's history for why that's unsafe to pin), and resolved
# `operating_system.type` (Computed field, always shows a diff otherwise).

import {
  to = proxmox_virtual_environment_vm.plex01
  id = "pve/102"
}

resource "proxmox_virtual_environment_vm" "plex01" {
  acpi                                 = true
  bios                                 = "seabios"
  boot_order                           = ["scsi0"]
  delete_unreferenced_disks_on_destroy = true
  description                          = null
  hook_script_file_id                  = null
  keyboard_layout                      = "en-us"
  kvm_arguments                        = null
  machine                              = null
  migrate                              = false
  name                                 = "plex01"
  node_name                            = "pve"
  on_boot                              = true
  pool_id                              = null
  protection                           = false
  purge_on_destroy                     = true
  reboot                               = false
  reboot_after_update                  = true
  scsi_hardware                        = "virtio-scsi-pci"
  started                              = true
  stop_on_destroy                      = false
  tablet_device                        = true
  tags                                 = []
  template                             = false
  timeout_clone                        = 1800
  timeout_create                       = 1800
  timeout_migrate                      = 1800
  timeout_reboot                       = 1800
  timeout_shutdown_vm                  = 1800
  timeout_start_vm                     = 1800
  timeout_stop_vm                      = 300
  vm_id                                = 102

  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "BC:24:11:B1:47:48"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = ""
    vlan_id      = 0
  }]

  agent {
    enabled = true
    timeout = "15m"
    trim    = false
    type    = "virtio"
  }

  cpu {
    affinity     = null
    architecture = null
    cores        = 2
    flags        = []
    hotplugged   = 0
    limit        = 0
    numa         = false
    sockets      = 1
    type         = "qemu64"
  }

  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "local-lvm"
    discard           = "ignore"
    file_format       = "raw"
    file_id           = null
    import_from       = null
    interface         = "scsi0"
    iothread          = false
    path_in_datastore = "vm-102-disk-0"
    queues            = 0
    replicate         = true
    serial            = null
    size              = 40
    ssd               = false
  }

  initialization {
    datastore_id = "local-lvm"
    interface    = "ide2"
    upgrade      = true

    ip_config {
      ipv4 {
        address = "192.168.1.50/24"
        gateway = "192.168.1.254"
      }
    }

    user_account {
      keys     = [trimspace(file(var.ssh_public_key_path))]
      password = null # sensitive
      username = var.vm_user
    }
  }

  memory {
    dedicated      = 4096
    floating       = 0
    hugepages      = null
    keep_hugepages = false
    shared         = 0
  }

  operating_system {
    type = "other"
  }

  serial_device {
    device = "socket"
  }

  startup {
    down_delay = -1
    order      = 3
    up_delay   = -1
  }

  vga {
    clipboard = null
    memory    = 16
    type      = "serial0"
  }
}
