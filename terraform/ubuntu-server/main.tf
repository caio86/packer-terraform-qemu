terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.9"
    }
  }
}

provider "libvirt" {}

variable "base_image" {
  type    = string
  default = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

resource "libvirt_volume" "base" {
  name = "ubuntu-resolute-base.qcow2"
  pool = "default"
  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = var.base_image
    }
  }
}

resource "libvirt_volume" "disk" {
  name          = "vm-teste.qcow2"
  pool          = "default"
  capacity      = 20
  capacity_unit = "G"
  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = libvirt_volume.base.path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_cloudinit_disk" "seed" {
  name = "vm-test-cloudinit"

  user_data = <<-EOF
    #cloud-config
    hostname: vm-teste
    users:
      - name: admin
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
          - ${trimspace(file(pathexpand(var.ssh_public_key_path)))}
    ssh_pwauth: false
  EOF

  meta_data = <<-EOF
    instance-id: vm-teste-001
    local-hostname: vm-teste
  EOF
}

resource "libvirt_volume" "seed" {
  name = "vm-teste-cloudinit.iso"
  pool = "default"

  create = {
    content = {
      url = libvirt_cloudinit_disk.seed.path
    }
  }
}


resource "libvirt_domain" "vm" {
  name        = "vm-teste"
  type        = "kvm"
  memory      = 2
  memory_unit = "G"
  vcpu        = 2

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }

  features = {
    acpi = true
  }

  devices = {
    disks = [
      {
        driver = {
          name = "qemu"
          type = "qcow2"
        }
        source = {
          file = {
            file = libvirt_volume.disk.path
          }
        }
        target = { dev = "vda", bus = "virtio" }
      },
      {
        device = "cdrom"
        source = {
          file = {
            file = libvirt_volume.seed.path
          }
        }
        target = { dev = "sdb", bus = "sata" }
      }
    ]

    interfaces = [
      {
        type = "network"
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
        wait_for_ip = {
          timeout = 300
          source  = "lease"
        }
      }
    ]

    graphics = [
      {
        spice = {
          auto_port = true
          listen    = "127.0.0.1"
        }
      }
    ]

    videos = [
      {
        driver = {
          name = "virtio"
        }
      }
    ]
  }

  running = true
}

data "libvirt_domain_interface_addresses" "vm" {
  domain = libvirt_domain.vm.name
  source = "lease"
}

output "vm_ip" {
  value = try(data.libvirt_domain_interface_addresses.vm.interfaces[0].addrs[0].addr, "Sem ip Ainda")
}

