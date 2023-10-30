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

# install TDX feature
apt install -y kobuk-tdx-guest

# modprobe the tdx_guest
modprobe tdx-guest
echo tdx-guest > /etc/modprobe.d/tdx-guest.conf
