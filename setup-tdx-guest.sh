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

_on_error() {
  trap '' ERR
  line_path=$(caller)
  line=${line_path% *}
  path=${line_path#* }

  echo ""
  echo "ERR $path:$line $BASH_COMMAND exited with $1"
  exit 1
}
trap '_on_error $?' ERR

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

set -eE

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# source config file
if [ -f ${SCRIPT_DIR}/setup-tdx-config ]; then
    source ${SCRIPT_DIR}/setup-tdx-config
fi

# the kernel flavour/type we want to use
KERNEL_TYPE=linux-image-generic

# use can use -intel kernel by setting TDX_SETUP_INTEL_KERNEL
if [[ "${TDX_SETUP_INTEL_KERNEL}" == "1" ]]; then
  KERNEL_TYPE=linux-image-intel
fi

source ${SCRIPT_DIR}/setup-tdx-common

apt update
apt install --yes software-properties-common gawk &> /dev/null

# cleanup
# NB: '*' before kobuk to keep backward compatiblity to make sure
# we clean up all conf files that have been deployed in the
# previous releases
rm -f /etc/apt/preferences.d/*kobuk*tdx-*
rm -f /etc/apt/apt.conf.d/99unattended-upgrades-kobuk

# We want wordsplitting if there is multiple entries
# shellcheck disable=SC2086
add_kobuk_ppas ${TDX_PPA:-tdx-release}

# upgrade the system to have the latest components (mostly generic kernel)
apt upgrade --yes

# install TDX feature
# install modules-extra to have tdx_guest module
apt install --yes --allow-downgrades \
   ${KERNEL_TYPE} \
   shim-signed \
   grub-efi-amd64-signed \
   grub-efi-amd64-bin

# if a specific kernel has to be used instead of generic
# TODO : install linux-modules-extra
if [ -n "${KERNEL_RELEASE}" ]; then
  apt install --yes --allow-downgrades \
    "linux-image-unsigned-${KERNEL_RELEASE}"
fi

KERNEL_RELEASE=$(get_kernel_version "$KERNEL_TYPE")
# select the right kernel for next boot
grub_set_kernel

# some kernels (for example -intel) might not be installed with the modules-extra
# but we need it to support a wider range of hardware (network cards, ...)
# just force the installation of modules-extra to make sure we have it
apt install --yes --allow-downgrades linux-modules-extra-${KERNEL_RELEASE}

# setup attestation
if [[ "${TDX_SETUP_ATTESTATION}" == "1" ]]; then
  "${SCRIPT_DIR}"/attestation/setup-attestation-guest.sh
else
  echo "Skip installing attestation components..."
fi
