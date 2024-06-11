#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

source ${SCRIPT_DIR}/../setup-tdx-config
source ${SCRIPT_DIR}/../setup-tdx-common

apt install --yes software-properties-common
add_kobuk_ppa ${TDX_PPA:-tdx-release}

apt update
apt install --yes --allow-downgrades libtdx-attest-dev trustauthority-cli

# compile tdx-attest source
apt install --yes build-essential
(cd /usr/share/doc/libtdx-attest-dev/examples/ && make)

# run : /usr/share/doc/libtdx-attest-dev/examples/test_tdx_attest
