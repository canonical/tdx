#!/bin/bash

_error() {
		echo "Error : $1"
		exit 1
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

# --allow-downgrades : if kobuk-tdx-host is already installed
apt install --yes --allow-downgrades kobuk-tdx-host || _error "Cannot install TDX components !"
apt upgrade --yes --allow-downgrades kobuk-tdx-host || _error "Cannot upgrade TDX components !"

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
