#!/bin/bash

# This file is part of Canonical's TDX repository which includes tools
# to setup and configure a confidential computing environment
# based on Intel TDX technology.
# See the LICENSE file in the repository for the license text.

# Copyright 2024 Canonical Ltd.
# SPDX-License-Identifier: GPL-3.0-only

# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3,
# as published by the Free Software Foundation.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranties
# of MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

# This script will create a UKI (Unified Kernel Image) using
# systemd-ukify, update-initramfs

# if this script is executed with virt-customize, $(uname -r)
# will give the kernel version on host, so this information
# we have to look for it from /boot/
KERNEL_VER=$(find /boot/vmlinuz-*-generic 2>&1 | \
                 /usr/lib/grub/grub-sort-version -r 2>&1 | \
                 gawk 'match($0 , /^\/boot\/vmlinuz-(.*)/, a) {print a[1];exit}')

UBUNTU_VERSION=$(lsb_release -rs)

if [[ -z "${KERNEL_VER}" ]]; then
    echo "Cannot detect kernel version"
    exit 1
fi

echo "Creating the UKI with kernel ${KERNEL_VER}"

# the kernel commandline to put in the UKI
# the boot is specified using label, on Ubuntu cloud
# image, the rootfs partition is labelled as cloudimg-rootfs
# lrwxrwxrwx    1        11 UEFI -> ../../sda15
# lrwxrwxrwx    1        11 BOOT -> ../../sda13
# lrwxrwxrwx    1        10 cloudimg-rootfs -> ../../sda1
KERNEL_CMDLINE="console=tty1 console=ttyS0 root=LABEL=cloudimg-rootfs"

# use systemd-ukify to generate UKI
sudo apt install -y systemd-ukify systemd-boot-efi

# use update-initramfs
#  add kernel moules:
#    - tdx_guest
echo tdx_guest | sudo tee -a /etc/initramfs-tools/modules
sudo update-initramfs -c -k ${KERNEL_VER}

# copy the initrd
sudo cp /boot/initrd.img-${KERNEL_VER} initrd.img-${UBUNTU_VERSION}

# copy the kernel
sudo cp /boot/vmlinuz-${KERNEL_VER} ./vmlinuz-${UBUNTU_VERSION}
sudo chmod a+rw vmlinuz-${KERNEL_VER}

ukify build --linux=./vmlinuz-${UBUNTU_VERSION} \
      --cmdline "${KERNEL_CMDLINE}" \
      --initrd=initrd.img-${UBUNTU_VERSION} \
      --output uki.efi-${UBUNTU_VERSION} \
      --os-release '@/etc/os-release' \
      --uname ${KERNEL_VER}
