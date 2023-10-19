#!/bin/bash

apt update
apt install --yes software-properties-common &> /dev/null

# setup TDX guest
add-apt-repository -y ppa:kobuk-team/tdx

# PPA pinning
cat <<EOF | tee /etc/apt/preferences.d/kobuk-team-tdx-pin-4000
Package: *
Pin: release o=LP-PPA-kobuk-team-tdx
Pin-Priority: 4000
EOF

apt update

# install TDX feature
apt install -y kobuk-tdx-guest
