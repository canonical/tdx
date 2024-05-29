#!/bin/bash

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
rm -f /etc/apt/preferences.d/kobuk-team-tdx-*
rm -f /etc/apt/apt.conf.d/99unattended-upgrades-kobuk

add_kobuk_ppa ${TDX_PPA:-tdx-release}

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
