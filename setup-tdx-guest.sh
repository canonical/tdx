#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# use can use -intel kernel by setting TDX_GUEST_SETUP_INTEL_KERNEL
if [ -n "${TDX_GUEST_SETUP_INTEL_KERNEL}" ]; then
   KERNEL_RELEASE=6.8.0-1001-intel
fi

source ${SCRIPT_DIR}/setup-tdx-common

# grub: switch to kernel version
grub_switch_kernel() {
    KERNELVER=$1
    MID=$(awk '/Advanced options for Ubuntu/{print $(NF-1)}' /boot/grub/grub.cfg | cut -d\' -f2)
    KID=$(awk "/with Linux $KERNELVER/"'{print $(NF-1)}' /boot/grub/grub.cfg | cut -d\' -f2 | head -n1)
    cat > /etc/default/grub.d/99-tdx-kernel.cfg <<EOF
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true
EOF
    grub-editenv /boot/grub/grubenv set saved_entry="${MID}>${KID}"
    update-grub
}

# select the kernel release for next boot
# if KERNEL_RELEASE is specified, we use it
# if not, select the latest generic kernel available on the system
grub_set_kernel() {
    if [ -z "${KERNEL_RELEASE}" ]; then
      KERNEL_RELEASE=$(find /boot/vmlinuz-*-generic 2>&1 | \
                      /usr/lib/grub/grub-sort-version -r 2>&1 | \
                      gawk 'match($0 , /^\/boot\/vmlinuz-(.*)/, a) {print a[1];exit}')
    fi
    if [ -z "${KERNEL_RELEASE}" ]; then
      echo "ERROR : unable to determine kernel release"
      exit 1
    fi
    grub_switch_kernel "${KERNEL_RELEASE}"
}

apt update
apt install --yes software-properties-common &> /dev/null

# cleanup
rm -f /etc/apt/preferences.d/kobuk-team-tdx-*
rm -f /etc/apt/apt.conf.d/99unattended-upgrades-kobuk

add_kobuk_ppa

# upgrade the system to have the latest components (mostly generic kernel)
apt upgrade --yes

# install TDX feature
# install modules-extra to have tdx_guest module
apt install --yes --allow-downgrades \
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

# select the right kernel for next boot
grub_set_kernel

# install modules-extra for generic kernel because the tdx-guest module
# is still in modules-extra only
# NB: grub_set_kernel updates kernel release that will be used, just check if it is generic
if [[ "$KERNEL_RELEASE" == *-generic ]]; then
  apt install --yes "linux-modules-extra-${KERNEL_RELEASE}"
fi

# setup attestation
"${SCRIPT_DIR}"/attestation/setup-guest.sh
