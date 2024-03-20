#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

apt install --yes software-properties-common
add-apt-repository -y ppa:kobuk-team/tdx

apt update

apt install --yes sgx-dcap-pccs tdx-qgs

# using RA registration (direct registration method)
apt install --yes sgx-ra-service

# using indirect registration method
apt install --yes sgx-pck-id-retrieval-tool

# add qgsd user to group  sgx_prv to allow to use /dev sgx
#ubuntu@sysid-739457:~/tdx$ ls -la /dev/sgx_*
#crw-rw---- 1 root sgx  10, 125 Nov  8 17:44 /dev/sgx_enclave
#crw------- 1 root root 10, 126 Nov  8 17:44 /dev/sgx_provision
#crw-rw---- 1 root sgx  10, 124 Nov  8 17:44 /dev/sgx_vepc

# /dev/sgx_provision must have sgx_prv as group

usermod -aG sgx_prv qgsd

