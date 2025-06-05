#!/bin/bash

# This file is part of Canonical's TDX repository which includes tools
# to setup and configure a confidential computing environment
# based on Intel TDX technology.
# See the LICENSE file in the repository for the license text.

# Copyright 2025 Canonical Ltd.
# SPDX-License-Identifier: GPL-3.0-only

# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3,
# as published by the Free Software Foundation.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranties
# of MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

PROJECT_DIR=$SCRIPT_DIR/../..

# source config file
if [ -f ${PROJECT_DIR}/setup-tdx-config ]; then
    source ${PROJECT_DIR}/setup-tdx-config
fi

on_exit() {
    rc=$?
    if [ ${rc} -ne 0 ]; then
        echo "====================================="
        echo "ERROR : The script failed..."
        echo "====================================="
    fi
    return ${rc}
}

_error() {
  echo "Error : $1"
  exit 1
}

trap "on_exit" EXIT

source ${PROJECT_DIR}/setup-tdx-common

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [ ! -d "nvtrust" ]; then
  rm -rf nvtrust
  git clone -b 2025.4.11.001 --recursive https://github.com/NVIDIA/nvtrust.git
fi

nvidia_h100_bdfs() {
    while read -r line
    do
	# extract BDF
	bdf=$(echo $line | cut -d " " -f1)
	echo ${bdf}
    done < <(lspci -nn | grep "${NVIDIA_VENDOR_ID}" | grep "H100")
}

enable_cc_mode() {
    GPU_BDF=$1
    ./nvtrust/host_tools/python/nvidia_gpu_tools.py --set-ppcie-mode=off --reset-after-ppcie-mode-switch --gpu-bdf=${GPU_BDF}
    ./nvtrust/host_tools/python/nvidia_gpu_tools.py --set-cc-mode=on --reset-after-cc-mode-switch --gpu-bdf=${GPU_BDF}
}

setup_udev() {
    cp ${SCRIPT_DIR}/vfio-passthrough.rules /etc/udev/rules.d/
    udevadm control --reload-rules
    udevadm trigger
}

gpus_bdfs() {
    GPUS_BDFS=$(./nvtrust/host_tools/python/nvidia_gpu_tools.py --query-cc-mode 2>&1 | gawk 'match($0, /[ ]+[0-9]+ GPU ([0-0]{4}:[a-z0-9]{2,4}:[a-z0-9]{2}.[0-9]+)/, a) {print a[1]}')
    echo ${GPUS_BDFS}
}

GPUS=$(gpus_bdfs)

if [ ! -z "$1" ]; then
    if [ "$1" != "*" ]; then
	GPUS=${1//,/ }
    fi

    for gpu_bdf in ${GPUS}
    do
	echo "======= Prepare ${gpu_bdf}"
	enable_cc_mode ${gpu_bdf}
	# virsh expect input format : pci_0000_b8_00_0
	virsh_gpu_bdf=$(echo "${gpu_bdf}" | tr :. _)
	# TMP: detach vfio first if already attached to vfio
	# this will avoid to have the error "Invalid argument" when
	# qemu tries to bind to the iommufd object just after the previous instance
	# has been stopped
	virsh nodedev-reattach pci_${virsh_gpu_bdf} || true
	virsh nodedev-detach pci_${virsh_gpu_bdf}
    done

    setup_udev
else
    echo "================================"
    echo "List of NVidia GPUs (PCI BDFs):"
    echo ${GPUS}
    echo "================================"
fi
