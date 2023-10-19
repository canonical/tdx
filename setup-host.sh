#!/bin/bash

apt update
apt install --yes software-properties-common &> /dev/null

add-apt-repository -y ppa:kobuk-team/tdx

# PPA pinning
rm -f /etc/apt/preferences.d/kobuk-tdx-pin-4000
cat <<EOF | tee /etc/apt/preferences.d/kobuk-tdx-pin-4000
Package: *
Pin: release o=LP-PPA-kobuk-team-tdx
Pin-Priority: 4000
EOF

apt update

apt install --yes kobuk-tdx-host

# update cmdline to add tdx=1 to kvm_intel
sed -i -E "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 kvm_intel.tdx=1\"/g" /etc/default/grub

