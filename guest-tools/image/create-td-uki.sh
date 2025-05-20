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

# This script will create a UKI (Unified Kernel Image) from the guest image

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

TMP_GUEST_IMG="${SCRIPT_DIR}/tdx-guest-tmp.qcow2"
TMP_GUEST_FOLDER="${SCRIPT_DIR}/tdx-guest-tmp/"

TD_GUEST_IMG=$1
if [[ -z "${TD_GUEST_IMG}" ]]; then
    echo "Usage : $0 <td_guest_qcow>"
    exit 1
fi

if [ "$EUID" -eq 0 ]
  then echo "Please do not run as root"
  exit
fi

cleanup() {
    echo "cleanup ..."
    umount ${TMP_GUEST_FOLDER} &> /dev/null
    rm -rf ${TMP_GUEST_FOLDER}
    rm -f ${TMP_GUEST_IMG}
}

trap "cleanup" EXIT

cleanup

set -e

# Ubuntu make the kernels (vmlinuz) readable ONLY for root user
# this makes libguestfs fails when it is run as normal user
# For more details, see the LP bug on that topic:
# https://bugs.launchpad.net/ubuntu/+source/linux/+bug/759725
# To work-around this issue, we allow normal users to read the kernel
# files
sudo chmod 0644 /boot/vmlinuz-*

# create an overlay image with guest image as a backing image
qemu-img create -f qcow2 -b ${TD_GUEST_IMG} -F qcow2 ${TMP_GUEST_IMG}

# virt-customize does in-place customization and use host kernel
# we have to give the create-uki script the guest image kernel 
virt-customize -a ${TMP_GUEST_IMG} \
    --mkdir /tmp/tdx/ \
    --copy-in ${SCRIPT_DIR}/create-uki.sh:/tmp/tdx/ \
    --run-command "/tmp/tdx/create-uki.sh"

# retrieve files
mkdir -p ${TMP_GUEST_FOLDER} && guestmount -a ${TMP_GUEST_IMG} -i --ro ${TMP_GUEST_FOLDER}

cp ${TMP_GUEST_FOLDER}/uki.efi* ./
cp ${TMP_GUEST_FOLDER}/vmlinuz* ./
cp ${TMP_GUEST_FOLDER}/initrd* ./
