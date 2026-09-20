packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1.1"
    }
  }
}

variable "ssh_public_key_path" {
  type = string
}

variable "ssh_private_key_path" {
  type = string
}

variable "password_hash" {
  type      = string
  sensitive = true
}

variable "ubuntu_image_url" {
  type    = string
  default = "https://releases.ubuntu.com/24.04.5/ubuntu-24.04.5-live-server-amd64.iso"
}

variable "ubuntu_image_checksum" {
  type    = string
  default = "file:https://releases.ubuntu.com/24.04.5/SHA256SUMS"
}

source "qemu" "ubuntu" {
  iso_url      = var.ubuntu_image_url
  iso_checksum = var.ubuntu_image_checksum

  vm_name          = "ubuntu-24.04-base.qcow2"

  accelerator = "kvm"
  headless    = true

  disk_size      = "20G"
  disk_interface = "virtio"
  disk_image     = false

  format = "qcow2"

  cpus   = 2
  memory = 2048

  net_device = "virtio-net"

  ssh_username         = "packer"
  ssh_private_key_file = var.ssh_private_key_path
  ssh_timeout          = "10m"

  ssh_clear_authorized_keys = true

  http_content = {
    "/meta-data" = <<-EOF
      instance-id: packer-ubuntu-2404
      local-hostname: ubuntu-template
    EOF

    "/user-data" = templatefile(
      "${path.root}/http/user-data.tpl",
      {
        ssh_public_key = trimspace(
          file(var.ssh_public_key_path)
        )

        password_hash = var.password_hash
      }
    )
  }

  boot_wait = "5s"

  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]


  shutdown_command = "sudo shutdown -P now"
}

build {
  sources = [
    "source.qemu.ubuntu"
  ]

  provisioner "shell" {
    inline = [
      "sudo cloud-init status --wait || true",

      "sudo apt update",

      "sudo DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y",

      "sudo systemctl enable qemu-guest-agent",

      "sudo cloud-init clean --logs --seed",

      "sudo truncate -s 0 /etc/machine-id",

      "sudo rm -f /var/lib/dbus/machine-id",

      "sudo rm -f /home/packer/.ssh/authorized_keys",

      "sudo rm -f /etc/sudoers.d/90-packer",

      "sudo userdel -r packer || true"
    ]
  }
}
