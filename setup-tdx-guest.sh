#!/bin/bash

# This file is part of Canonical's TDX repository which includes tools
# to setup and configure a confidential computing environment
# based on Intel TDX technology.
# See the LICENSE file in the repository for the license text.

# Copyright 2024 Canonical Ltd.
# SPDX-License-Identifier: GPL-3.0-only

# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3,
# as published by the Free Software Foundation.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranties
# of MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

_on_error() {
  trap '' ERR
  line_path=$(caller)
  line=${line_path% *}
  path=${line_path#* }

  echo ""
  echo "ERR $path:$line $BASH_COMMAND exited with $1"
  exit 1
}
trap '_on_error $?' ERR

parse_params() {
    while :; do
        case "${1-}" in
        -h | --help)
            usage
            exit 0
            ;;
        upgrade)
            install_kobuk
            exit 0
            ;;
        "")
	    break
        esac
        shift
    done
}

parse_params "$@"

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

set -eE

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# source config file
if [ -f ${SCRIPT_DIR}/setup-tdx-config ]; then
    source ${SCRIPT_DIR}/setup-tdx-config
fi

# the kernel flavour/type we want to use
KERNEL_TYPE=linux-image-generic

# use can use -intel kernel by setting TDX_SETUP_INTEL_KERNEL
if [[ "${TDX_SETUP_INTEL_KERNEL}" == "1" ]]; then
  KERNEL_TYPE=linux-image-intel
fi

source ${SCRIPT_DIR}/setup-tdx-common

install_kobuk() {
    # install TDX feature
    # install modules-extra to have tdx_guest module
    apt install --yes --allow-downgrades \
	${KERNEL_TYPE} \
	shim-signed \
	grub-efi-amd64-signed \
	grub-efi-amd64-bin

    # if a specific kernel has to be used instead of generic
    # TODO : install linux-modules-extra
    if [ -n "${KERNEL_RELEASE}" ]; then
	apt install --yes --allow-downgrades \
	    "linux-image-unsigned-${KERNEL_RELEASE}"
    fi

    KERNEL_RELEASE=$(get_kernel_version "$KERNEL_TYPE")
    # select the right kernel for next boot
    grub_set_kernel

    # some kernels (for example -intel) might not be installed with the modules-extra
    # but we need it to support a wider range of hardware (network cards, ...)
    # just force the installation of modules-extra to make sure we have it
    apt install --yes --allow-downgrades linux-modules-extra-${KERNEL_RELEASE}
}

apt update
apt install --yes software-properties-common gawk &> /dev/null

# cleanup
# NB: '*' before kobuk to keep backward compatiblity to make sure
# we clean up all conf files that have been deployed in the
# previous releases
rm -f /etc/apt/preferences.d/*kobuk*tdx-*
rm -f /etc/apt/apt.conf.d/99unattended-upgrades-kobuk

# We want wordsplitting if there is multiple entries
# shellcheck disable=SC2086
add_kobuk_ppas ${TDX_PPA:-tdx-release}

# upgrade the system to have the latest components (mostly generic kernel)
apt upgrade --yes

install_kobuk

# setup attestation
if [[ "${TDX_SETUP_ATTESTATION}" == "1" ]]; then
  "${SCRIPT_DIR}"/attestation/setup-attestation-guest.sh
else
  echo "Skip installing attestation components..."
fi

if [[ "${TDX_SETUP_NVIDIA_H100}" == "1" ]]; then
    echo "Setup components for NVIDIA H100..."
    echo "Setup components for NVIDIA H100... Enable LKCA"
    # Enable LKCA
    cat <<-EOF > /etc/modprobe.d/nvidia-lkca.conf
install nvidia /sbin/modprobe ecdsa_generic; /sbin/modprobe ecdh; /sbin/modprobe --ignore-install nvidia
EOF
    update-initramfs -u

    # https://documentation.ubuntu.com/server/how-to/graphics/install-nvidia-drivers/index.html
    # Cannot use ubuntu-drivers because we do not have GPUs passed-through in the guest image build
    # VM
    #apt install --yes ubuntu-drivers-common
    #ubuntu-drivers install --gpgpu nvidia:570-server
    #apt install --yes nvidia-utils-570-server

    echo "Setup components for NVIDIA H100... Install CUDA driver and toolkit"
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
    dpkg -i cuda-keyring_1.1-1_all.deb
    apt update
    apt install --yes cuda-toolkit-12-8
    wget https://us.download.nvidia.com/tesla/570.86.15/nvidia-driver-local-repo-ubuntu2404-570.86.15_1.0-1_amd64.deb
    dpkg -i ./nvidia-driver-local-repo-ubuntu2404-570.86.15_1.0-1_amd64.deb
    cp /var/nvidia-driver-local-repo-ubuntu2404-570.86.15/nvidia-driver-local-41F54E74-keyring.gpg /usr/share/keyrings/
    apt install --yes nvidia-driver-570-open

    # install nvtop
    echo "Setup components for NVIDIA H100... Install utilities"
    apt install --yes nvtop

    # enable and setup persistance mode
    echo "Setup components for NVIDIA H100... Enable persistence mode"
    systemctl enable nvidia-persistenced.service
    mkdir -p /etc/systemd/system/nvidia-persistenced.service.d/
    cat <<-EOF > /etc/systemd/system/nvidia-persistenced.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/nvidia-persistenced --uvm-persistence-mode --verbose
EOF

    # needs to put NVIDIA GPU to ready state before any USE
    # add init script to do it at VM boot
    echo "Setup components for NVIDIA H100... Add set ready script"
    cat <<-EOF > /lib/systemd/system/nvidia-tdx.service
[Unit]
Description=TDX H100 setup
After=nvidia-persistenced.service

[Service]
ExecStart=nvidia-smi conf-compute -srs 1                                                                        

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable nvidia-tdx
fi

# install ollama
if [[ "${TDX_SETUP_APPS_OLLAMA}" == "1" ]]; then
   echo "Install OLLAMA"
   curl \-fsSL https://ollama.com/install.sh | sh
   mkdir -p /etc/systemd/system/ollama.service.d/

   if [[ "${TDX_SETUP_NVIDIA_H100}" == "1" ]]; then
       cat <<-EOF > /etc/systemd/system/ollama.service.d/override.conf
[Unit]
After=nvidia-tdx.service
EOF
   fi

   systemctl enable ollama.service
   sync
fi
