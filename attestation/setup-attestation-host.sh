#!/bin/bash
#
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

apt install --yes --allow-downgrades sgx-dcap-pccs tdx-qgs

# using RA registration (direct registration method)
apt install --yes --allow-downgrades sgx-ra-service

# using indirect registration method
apt install --yes --allow-downgrades sgx-pck-id-retrieval-tool

