#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

apt install --yes software-properties-common
add-apt-repository -y ppa:kobuk-team/tdx

apt update
apt install --yes libsgx-ae-id-enclave \
    libsgx-ae-qve \
    libsgx-ae-tdqe \
    libsgx-dcap-default-qpl \
    libsgx-dcap-quote-verify \
    libsgx-pce-logic \
    libsgx-psw-common \
    libsgx-ra-uefi \
    libsgx-tdx-logic \
    sgx-dcap-pccs \
    sgx-pck-id-retrieval-tool  \
    tdx-qgs

# add qgsd user to group  sgx_prv to allow to use /dev sgx
#ubuntu@sysid-739457:~/tdx$ ls -la /dev/sgx_*
#crw-rw---- 1 root sgx  10, 125 Nov  8 17:44 /dev/sgx_enclave
#crw------- 1 root root 10, 126 Nov  8 17:44 /dev/sgx_provision
#crw-rw---- 1 root sgx  10, 124 Nov  8 17:44 /dev/sgx_vepc

# libsgx-enclave-common/etc/udev/rules.d/94-sgx-enclave.rules

chown root:sgx /dev/sgx_provision
chmod g+rw /dev/sgx_provision

usermod -aG sgx_prv qgsd

