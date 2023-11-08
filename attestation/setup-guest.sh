#!/bin/bash

apt install --yes software-properties-common
add-apt-repository -y ppa:kobuk-team/tdx

apt update
apt install --yes libtdx-attest-dev

# compile tdx-attest source
(cd /usr/share/doc/libtdx-attest-dev/examples/ && make)

# run : /usr/share/doc/libtdx-attest-dev/examples/test_tdx_attest
