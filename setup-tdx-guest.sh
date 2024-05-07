#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# the kernel flavour/type we want to use
KERNEL_TYPE=linux-image-generic

# use can use -intel kernel by setting TDX_SETUP_INTEL_KERNEL
if [ -n "${TDX_SETUP_INTEL_KERNEL}" ]; then
  KERNEL_TYPE=linux-image-intel
fi

source ${SCRIPT_DIR}/setup-tdx-common

apt update
apt install --yes software-properties-common gawk &> /dev/null

# cleanup
rm -f /etc/apt/preferences.d/kobuk-team-tdx-*
rm -f /etc/apt/apt.conf.d/99unattended-upgrades-kobuk

add_kobuk_ppa

# upgrade the system to have the latest components (mostly generic kernel)
apt upgrade --yes

# install TDX feature
# install modules-extra to have tdx_guest module
apt install --yes --allow-downgrades \
   ${KERNEL_TYPE} \
   shim-signed \
   grub-efi-amd64-signed \
   grub-efi-amd64-bin \
   tdx-tools-guest \
   python3-pytdxmeasure

# if a specific kernel has to be used instead of generic
# TODO : install linux-modules-extra
if [ -n "${KERNEL_RELEASE}" ]; then
  apt install --yes --allow-downgrades \
    "linux-image-unsigned-${KERNEL_RELEASE}"
fi

KERNEL_RELEASE=$(get_kernel_version "$KERNEL_TYPE")
# select the right kernel for next boot
grub_set_kernel

# install modules-extra for generic kernel because the tdx-guest module
# is still in modules-extra only
# NB: grub_set_kernel updates kernel release that will be used, just check if it is generic
if [[ "$KERNEL_RELEASE" == *-generic ]]; then
  apt install --yes "linux-modules-extra-${KERNEL_RELEASE}"
fi

# setup attestation
if [[ "${TDX_SETUP_ATTESTATION}" == "1" ]]; then
  "${SCRIPT_DIR}"/attestation/setup-attestation-guest.sh
else
  echo "Skip installing attestation components..."
fi
