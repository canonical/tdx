#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# use can use -intel kernel by setting TDX_GUEST_SETUP_INTEL_KERNEL
if [ ! -z "${TDX_GUEST_SETUP_INTEL_KERNEL}" ]; then
   KERNEL_RELEASE=6.8.0-1001-intel
fi

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

apt update
apt install --yes software-properties-common &> /dev/null

# cleanup
rm -f /etc/apt/preferences.d/kobuk-team-tdx-*

add-apt-repository -y ppa:kobuk-team/tdx

# PPA pinning
cat <<EOF | tee /etc/apt/preferences.d/kobuk-team-tdx-pin-4000
Package: *
Pin: release o=LP-PPA-kobuk-team-tdx
Pin-Priority: 4000
EOF

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

# if a specific kernel has to be used
# TODO : install linux-modules-extra
if [ ! -z "${KERNEL_RELEASE}" ]; then
  apt install --yes --allow-downgrades \
    linux-image-unsigned-${KERNEL_RELEASE}
  grub_switch_kernel ${KERNEL_RELEASE}
fi

# setup attestation
${SCRIPT_DIR}/attestation/setup-guest.sh
