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

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

UBUNTU_VERSION=$1

if [[ -z "${UBUNTU_VERSION}" ]]; then
    echo "Usage: $0 <24.04|24.10>"
    exit 1
fi

UKI_FILE=$(realpath ${SCRIPT_DIR}/../image/uki.efi-${UBUNTU_VERSION})
TD_IMG=$(realpath ${SCRIPT_DIR}/../image/tdx-guest-ubuntu-${UBUNTU_VERSION}-generic.qcow2)

usage() {
    cat <<EOM
Run TD with UKI (Unified Kernel Image)

This script requires 2 files to be available:

- ${UKI_FILE}
  UKI file (Unified Kernel Image)
  You can use guest-tools/image/create-td-uki.sh to generate it

- ${TD_IMG}
  TD guest image (qcow2)
  You can use guest-tools/image/create-td-image.sh to generate it
EOM
}

cleanup() {
    echo "cleanup ..."
    rm -rf ${ROOTFS_DIR}
}

trap "cleanup" EXIT
cleanup &> /dev/null

PROCESS_NAME=td
TDVF_FIRMWARE=/usr/share/ovmf/OVMF.fd
ROOTFS_DIR=${SCRIPT_DIR}/uki_rootfs

# sanity check
if [[ ! -f "${UKI_FILE}" ]] || [[ ! -f "${TD_IMG}" ]]; then
    usage
    exit 1
fi

set -e

# Since the uki kernel is designed to be started by UEFI directly,
# it has to reside in the EFI partition, because without additional
# drivers UEFI can only read VFAT.
mkdir -p ${ROOTFS_DIR}/efi/boot
cp -f ${UKI_FILE} ${ROOTFS_DIR}/efi/boot/bootx64.efi

qemu-system-x86_64 -accel kvm \
		   -m 2G -smp 16 \
		   -name ${PROCESS_NAME},process=${PROCESS_NAME},debug-threads=on \
		   -cpu host \
		   -object '{"qom-type":"tdx-guest","id":"tdx","quote-generation-socket":{"type": "vsock", "cid":"2","port":"4050"}}' \
		   -machine q35,kernel_irqchip=split,confidential-guest-support=tdx,hpet=off \
		   -bios ${TDVF_FIRMWARE} \
		   -nographic \
		   -nodefaults \
		   -hda fat:rw:${ROOTFS_DIR} \
		   -hdb ${TD_IMG} \
		   -serial stdio \
		   -pidfile /tmp/tdx-demo-td-pid.pid
