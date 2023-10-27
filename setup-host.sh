#!/bin/bash

apt update
apt install --yes software-properties-common &> /dev/null

# cleanup
rm -f /etc/apt/preferences.d/kobuk-team-tdx-*
add-apt-repository -yr ppa:kobuk-team/tdx
apt autoremove

add-apt-repository -y ppa:kobuk-team/tdx-release

# PPA pinning
cat <<EOF | tee /etc/apt/preferences.d/kobuk-team-tdx-release-pin-4000
Package: *
Pin: release o=LP-PPA-kobuk-team-tdx-release
Pin-Priority: 4000
EOF

apt update

# --allow-downgrades : if kobuk-tdx-host is already installed
apt install --yes --allow-downgrades kobuk-tdx-host
apt upgrade --yes kobuk-tdx-host

# update cmdline to add tdx=1 to kvm_intel
grep -E "GRUB_CMDLINE_LINUX.*=.*\".*kvm_intel.tdx( )*=1.*\"" /etc/default/grub &> /dev/null
if [ $? -ne 0 ]; then
  sed -i -E "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 kvm_intel.tdx=1\"/g" /etc/default/grub
  update-grub
  grub-install
fi

