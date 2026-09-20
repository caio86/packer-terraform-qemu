packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1.1"
    }
  }
}

variable "ubuntu_image_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"
}

variable "ubuntu_image_checksum" {
  type    = string
  default = "file:https://cloud-images.ubuntu.com/resolute/current/SHA256SUMS"
}

source "qemu" "ubuntu" {
  iso_url      = var.ubuntu_image_url
  iso_checksum = var.ubuntu_image_checksum
  disk_size    = "20G"
  disk_image   = true

  vm_name = "ubuntu-resolute-base.qcow2"

  accelerator    = "kvm"
  cpus           = 2
  memory         = 2048
  format         = "qcow2"
  disk_interface = "virtio"
  net_device     = "virtio-net"
  headless       = true

  cd_files = ["cloud-init/user-data", "cloud-init/meta-data"]
  cd_label = "cidata"

  ssh_username              = "packer"
  ssh_password              = "packer"
  ssh_timeout               = "10m"
  ssh_clear_authorized_keys = true

  shutdown_command = "sudo shutdown -P now"
}

build {
  sources = [
    "source.qemu.ubuntu"
  ]

  provisioner "shell" {
    inline = [
      "sudo cloud-init status --wait",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade",
      "sudo apt-get install -y qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent",
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo cloud-init clean --logs --seed",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo apt-get clean"
    ]
  }
}

