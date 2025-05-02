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

if [ ! -d "${SCRIPT_DIR}/nvtrust/" ]; then
  rm -rf nvtrust
  git clone -b 2025.4.11.001 --recursive https://github.com/NVIDIA/nvtrust.git
fi

# switch GPU to CC mode
NVIDIA_VENDOR_ID=10de

nvidia_h100_bdfs() {
    while read -r line
    do
	# extract BDF
	bdf=$(echo $line | cut -d " " -f1)
	echo $bdf
    done < <(lspci -nn | grep "${NVIDIA_VENDOR_ID}" | grep "H100")
}

enable_cc_mode() {
  for i in $(seq 0 $(($(lspci -nn | grep "$NVIDIA_VENDOR_ID" | grep -c "H100") - 1))); do
    ./nvtrust/host_tools/python/nvidia_gpu_tools.py --set-ppcie-mode=off --reset-after-ppcie-mode-switch --gpu=$i
  done
  for i in $(seq 0 $(($(lspci -nn | grep "$NVIDIA_VENDOR_ID" | grep -c "H100") - 1))); do
    ./nvtrust/host_tools/python/nvidia_gpu_tools.py --set-cc-mode=on --reset-after-cc-mode-switch --gpu=$i
  done
}

unbind_gpus() {
    
}


echo "================================"
echo "List of NVidia GPUs (PCI BDFs):"
lspci -nn | grep "${NVIDIA_VENDOR_ID}" | grep "H100"
echo "================================"

enable_cc_mode


