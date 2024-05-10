#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

apt install --yes software-properties-common
add-apt-repository -y ppa:kobuk-team/tdx-release

apt update

apt install --yes sgx-dcap-pccs tdx-qgs

# using RA registration (direct registration method)
apt install --yes sgx-ra-service

# using indirect registration method
apt install --yes sgx-pck-id-retrieval-tool

