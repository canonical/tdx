#!/bin/bash

#
# Revert host to generic kernel and stock qemu
#

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR=$SCRIPT_DIR/../

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
KERNEL_TYPE=linux-image-generic

# cleanup
rm -f /etc/apt/preferences.d/kobuk-team-tdx-*

# stop at error
set -e

apt update
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
