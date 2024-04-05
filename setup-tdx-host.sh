#!/bin/bash

_error() {
  echo "Error : $1"
  exit 1
}

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

add-apt-repository -y ppa:kobuk-team/tdx-release

# PPA pinning
cat <<EOF | tee /etc/apt/preferences.d/kobuk-team-tdx-release-pin-4000
Package: *
Pin: release o=LP-PPA-kobuk-team-tdx-release
Pin-Priority: 4000
EOF

apt update

# modules-extra is needed (igc for example)
apt install --yes --allow-downgrades \
    linux-intel-opt \
    linux-modules-extra-intel-opt \
    qemu-system-x86 \
    libvirt-daemon-system \
    libvirt-clients \
    ovmf \
    tdx-tools-host

# detect the intel-opt current release (example : 6.5.0-1003-intel-opt)
KERNEL_RELEASE=$(apt show linux-image-intel-opt 2>&1 | gawk 'match($0, /Depends: linux-image-(.+)/, a) {print a[1]}')
if [ -z $KERNEL_RELEASE ]; then
  echo "ERROR: cannot determine the intel-opt release"
  exit 1
fi
echo "Request kernel ${KERNEL_RELEASE} for next boot ..."
grub_switch_kernel ${KERNEL_RELEASE}

# update cmdline to add tdx=1 to kvm_intel
grep -E "GRUB_CMDLINE_LINUX.*=.*\".*kvm_intel.tdx( )*=1.*\"" /etc/default/grub &> /dev/null
if [ $? -ne 0 ]; then
  sed -i -E "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 kvm_intel.tdx=1\"/g" /etc/default/grub
  update-grub
  grub-install
fi

# FIXME : with the current kernel, we do not have login prompt with getty
# as a work around, use nomodeset to tell kernel to use BIOS mode
grep -E "GRUB_CMDLINE_LINUX.*=.*\".*nomodeset.*\"" /etc/default/grub &> /dev/null
if [ $? -ne 0 ]; then
  sed -i -E "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 nomodeset\"/g" /etc/default/grub
  update-grub
  grub-install
fi

echo "========================================================================"
echo "The setup has been done successfully. Please enable now TDX in the BIOS."
echo "========================================================================"
