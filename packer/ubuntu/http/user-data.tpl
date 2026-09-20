#cloud-config

autoinstall:
  version: 1

  locale: pt_BR.UTF-8

  keyboard:
    layout: br

  timezone: America/Sao_Paulo

  refresh-installer:
    update: false

  identity:
    hostname: ubuntu-template
    username: packer
    password: "${password_hash}"

  ssh:
    install-server: true
    authorized-keys:
      - ${ssh_public_key}
    allow-pw: false

  storage:
    layout:
      name: lvm

  packages:
    - qemu-guest-agent
    - sudo

  user-data:
    disable_root: true
    package_upgrade: false
    users:
      - name: packer
        groups: [sudo]
        lock-passwd: false
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash

