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

PROCESS_NAME=td
TDVF_FIRMWARE=/usr/share/ovmf/OVMF.fd

KERNEL_FILE=$(realpath ${SCRIPT_DIR}/../image/vmlinuz-${UBUNTU_VERSION})
INITRD_FILE=$(realpath ${SCRIPT_DIR}/../image/initrd.img-${UBUNTU_VERSION})
TD_IMG=$(realpath ${SCRIPT_DIR}/../image/tdx-guest-ubuntu-${UBUNTU_VERSION}-generic.qcow2)

if [[ ! -f "${KERNEL_FILE}" ]]; then
    echo "Missing kernel file: ${KERNEL_FILE}
          You can use guest-tools/image/create-td-uki.sh to generate it"
    exit 1
fi

if [[ ! -f "${INITRD_FILE}" ]]; then
    echo "Missing initrd file: ${INITRD_FILE}
          You can use guest-tools/image/create-td-uki.sh to generate it"
    exit 1
fi

if [[ ! -f "${TD_IMG}" ]]; then
    echo "Missing guest image file: ${TD_IMG}
          You can use guest-tools/image/create-td-image.sh to generate it"
    exit 1
fi

set -e

qemu-system-x86_64 -accel kvm \
		   -m 2G -smp 16 \
		   -name ${PROCESS_NAME},process=${PROCESS_NAME},debug-threads=on \
		   -cpu host \
		   -object '{"qom-type":"tdx-guest","id":"tdx","quote-generation-socket":{"type": "vsock", "cid":"2","port":"4050"}}' \
		   -machine q35,kernel_irqchip=split,confidential-guest-support=tdx,hpet=off \
		   -bios ${TDVF_FIRMWARE} \
		   -nographic \
		   -nodefaults \
		   -kernel ${KERNEL_FILE} \
		   -initrd ${INITRD_FILE} \
		   -append "root=/dev/sda1 console=ttyS0" \
		   -hda ${TD_IMG} \
		   -serial stdio \
		   -pidfile /tmp/tdx-demo-td-pid.pid
