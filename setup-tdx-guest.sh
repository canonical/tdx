#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# for now, use the generic kernel
KERNEL_RELEASE=6.8.0-22-generic

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

apt update

# install TDX feature
# install modules-extra to have tdx_guest module
apt install --yes --allow-downgrades \
   linux-image-unsigned-${KERNEL_RELEASE} \
   linux-modules-extra-${KERNEL_RELEASE} \
   shim-signed \
   grub-efi-amd64-signed \
   grub-efi-amd64-bin \
   tdx-tools-guest \
   python3-pytdxmeasure

grub_switch_kernel ${KERNEL_RELEASE}

# setup attestation
${SCRIPT_DIR}/attestation/setup-guest.sh
