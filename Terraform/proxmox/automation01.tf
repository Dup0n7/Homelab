# Imported from the real, already-running automation01 VM (VMID 101) on
# 2026-07-22 via `terraform plan -generate-config-out` against live Proxmox
# state, then hand-cleaned (removed an invalid `cpu.units = 0` the schema
# rejects, and a deprecated `network_device.enabled` attribute). See
# Docs/Terraform.md for the full import exercise and what to watch for.
#
# The `import` block below is a one-time instruction — safe to leave in
# permanently (idempotent once state matches), but the goal from here is a
# `terraform plan` that shows zero changes, proving this resource block
# actually matches reality.

import {
  to = proxmox_virtual_environment_vm.automation01
  id = "pve/101"
}

resource "proxmox_virtual_environment_vm" "automation01" {
  acpi                                 = true
  bios                                 = "seabios"
  boot_order                           = ["scsi0"]
  delete_unreferenced_disks_on_destroy = true
  description                          = null
  hook_script_file_id                  = null
  keyboard_layout                      = "en-us"
  kvm_arguments                        = null
  mac_addresses                        = ["00:00:00:00:00:00", "BC:24:11:55:64:51", "FE:7F:D0:8D:F0:88", "AA:58:B2:B5:5A:B2", "AA:2D:EE:2A:BF:88", "3E:D6:E0:5E:F2:4E", "52:AE:AA:32:CF:51", "EE:E1:BB:2B:09:53", "AA:AF:E6:D4:1B:C0", "A6:F1:87:C7:CE:CD", "A6:AB:B6:DD:1D:B7"]
  machine                              = null
  migrate                              = false
  name                                 = "automation01"
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
  vm_id                                = 101

  network_device = [{
    bridge       = "vmbr0"
    disconnected = false
    enabled      = true
    firewall     = false
    mac_address  = "BC:24:11:55:64:51"
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
    cores        = 4
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
    path_in_datastore = "vm-101-disk-0"
    queues            = 0
    replicate         = true
    serial            = null
    size              = 80
    ssd               = false
  }

  initialization {
    datastore_id = "local-lvm"
    interface    = "ide2"
    upgrade      = true

    ip_config {
      ipv4 {
        address = "192.168.1.20/24"
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
    dedicated      = 8192
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
    order      = 2
    up_delay   = -1
  }

  vga {
    clipboard = null
    memory    = 16
    type      = "serial0"
  }
}
