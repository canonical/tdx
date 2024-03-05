#!/bin/bash

_error() {
  echo "Error : $1"
  exit 1
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

# --allow-downgrades : if kobuk-tdx-host is already installed
apt install --yes --allow-downgrades kobuk-tdx-host || _error "Cannot install TDX components !"
apt upgrade --yes --allow-downgrades kobuk-tdx-host || _error "Cannot upgrade TDX components !"

# for now, use the preview kernel in the PPA
#apt install --yes linux-image-unsigned-6.7.0-7-generic
apt install --yes linux-image-unsigned-6.7.0-1001-intel

# update cmdline to add tdx=1 to kvm_intel
grep -E "GRUB_CMDLINE_LINUX.*=.*\".*kvm_intel.tdx( )*=1.*\"" /etc/default/grub &> /dev/null
if [ $? -ne 0 ]; then
  sed -i -E "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 kvm_intel.tdx=1\"/g" /etc/default/grub
  update-grub
  grub-install
fi

# nohibernate
# TDX cannot survive from S3 and deeper states.  The hardware resets and
# disables TDX completely when platform goes to S3 and deeper.  Both TDX
# guests and the TDX module get destroyed permanently.
# The kernel uses S3 for suspend-to-ram, and use S4 and deeper states for
# hibernation.  Currently, for simplicity, the kernel chooses to make TDX
# mutually exclusive with S3 and hibernation.
grep -E "GRUB_CMDLINE_LINUX.*=.*\".*nohibernate.*\"" /etc/default/grub &> /dev/null
if [ $? -ne 0 ]; then
  sed -i -E "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 nohibernate\"/g" /etc/default/grub
  update-grub
  grub-install
fi

echo "========================================================================"
echo "The setup has been done successfully. Please enable now TDX in the BIOS."
echo "========================================================================"
