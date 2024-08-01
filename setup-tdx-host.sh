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

# source config file
if [ -f ${SCRIPT_DIR}/setup-tdx-config ]; then
    source ${SCRIPT_DIR}/setup-tdx-config
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

source ${SCRIPT_DIR}/setup-tdx-common

# the kernel flavour/type we want to use
KERNEL_TYPE=linux-image-intel

# add the login user to kvm group
# the idea is that the login user will be the one who will run the guest (qemu)
# so skip adding root
add_user_to_kvm() {
    LOG_USER=$(logname)
    if [ -n "$LOG_USER" ] && [ "$LOG_USER" != "root" ]; then
        usermod -aG kvm $LOG_USER
    fi
}

grub_cmdline_kvm() {
  # update cmdline to add tdx=1 to kvm_intel
  if ! grep -q -E "GRUB_CMDLINE_LINUX.*=.*\".*kvm_intel.tdx( )*=1.*\"" /etc/default/grub; then
    sed -i -E "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 kvm_intel.tdx=1\"/g" /etc/default/grub
    update-grub
    grub-install
  fi
}

grub_cmdline_nohibernate() {
  # nohibernate
  # TDX cannot survive from S3 and deeper states.  The hardware resets and
  # disables TDX completely when platform goes to S3 and deeper.  Both TDX
  # guests and the TDX module get destroyed permanently.
  # The kernel uses S3 for suspend-to-ram, and use S4 and deeper states for
  # hibernation.  Currently, for simplicity, the kernel chooses to make TDX
  # mutually exclusive with S3 and hibernation.
  if ! grep -q -E "GRUB_CMDLINE_LINUX.*=.*\".*nohibernate.*\"" /etc/default/grub; then
    sed -i -E "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 nohibernate\"/g" /etc/default/grub
    update-grub
    grub-install
  fi
}

# preparation
apt update
apt install --yes software-properties-common gawk &> /dev/null

# cleanup
rm -f /etc/apt/preferences.d/kobuk-team-tdx-*
rm -f /etc/apt/apt.conf.d/99unattended-upgrades-kobuk

# stop at error
set -e

# We want wordsplitting if there is multiple entries
# shellcheck disable=SC2086
add_kobuk_ppas ${TDX_PPA:-tdx-release}

apt install --yes --allow-downgrades \
    ${KERNEL_TYPE} \
    qemu-system-x86 \
    libvirt-daemon-system \
    libvirt-clients \
    ovmf \
    tdx-tools-host

KERNEL_RELEASE=$(get_kernel_version "$KERNEL_TYPE")
# select the right kernel for next boot
grub_set_kernel

# some kernels (for example -intel) might not be installed with the modules-extra
# but we need it to support a wider range of hardware (network cards, ...)
# just force the installation of modules-extra to make sure we have it
apt install --yes --allow-downgrades linux-modules-extra-${KERNEL_RELEASE}

grub_cmdline_kvm || true
grub_cmdline_nohibernate || true
add_user_to_kvm || true

# setup attestation
if [[ "${TDX_SETUP_ATTESTATION}" == "1" ]]; then
  "${SCRIPT_DIR}"/attestation/setup-attestation-host.sh
else
  echo "Skip installing attestation components..."
fi

echo "========================================================================"
echo "The host OS setup has been done successfully. Now, please enable Intel TDX in the BIOS."
echo "========================================================================"
