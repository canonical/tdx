#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

apt install --yes software-properties-common
add-apt-repository -y ppa:kobuk-team/tdx-release

apt update
apt install --yes libtdx-attest-dev trustauthority-cli

# compile tdx-attest source
apt install --yes build-essential
(cd /usr/share/doc/libtdx-attest-dev/examples/ && make)

# run : /usr/share/doc/libtdx-attest-dev/examples/test_tdx_attest
