#!/bin/bash

# This source code is a modified copy of https://github.com/intel/tdx-tools.git
# See LICENSE.apache file for original license information.

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

# This script will create a TDX guest image (qcow2 format) from a cloud
# image that is released at : https://cloud-images.ubuntu.com
# The cloud image is released as qcow3/qcow2 image (with .img suffix)
# The image comes with only 2 partitions:
#   - rootfs (~2G -> /)
#   - BIOS Boot (4M)
#   - EFI partition (~100M -> /boot/efi/ partition)
#   - Ext boot (/boot/ partition)
#
# As first step, we will resize the rootfs partition to a bigger size
# As second step, we will boot up the image to run cloud-init (using virtinst)
# and finally, we use virt-customize to copy in and run TDX setup script
#
# TODO : ask cloud init to run the TDX setup script

# User can tune the current script by providing arguments to the script
# or setting following environment variables:

# UBUNTU_VERSION: the ubuntu version (24.04, 24.10, ...)
# GUEST_USER: the username in the image
# GUEST_SSH_KEY: the SSH key to put in $GUEST_USER/.ssh/authorized_keys
# GUEST_HOSTNAME: the guest hostname

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# source config file
if [ -f ${SCRIPT_DIR}/../../setup-tdx-config ]; then
    source ${SCRIPT_DIR}/../../setup-tdx-config
fi

LOGFILE=/tmp/tdx-guest-setup.txt
FORCE_RECREATE=false
TMP_GUEST_IMG_PATH="/tmp/tdx-guest-tmp.qcow2"
SIZE=100
GUEST_USER=${GUEST_USER:-"tdx"}
GUEST_HOSTNAME=${GUEST_HOSTNAME:-"tdx-guest"}

ok() {
    echo -e "\e[1;32mSUCCESS: $*\e[0;0m"
}

error() {
    echo -e "\e[1;31mERROR: $*\e[0;0m"
    cleanup
    exit 1
}

warn() {
    echo -e "\e[1;33mWARN: $*\e[0;0m"
}

info() {
    echo -e "\e[0;33mINFO: $*\e[0;0m"
}

check_tool() {
    [[ "$(command -v $1)" ]] || { error "$1 is not installed" 1>&2 ; }
}

# On Ubuntu noble 24.04
# if passt is install and virt-customize runs as root, virt-customize
# will fail, this is a work-around for this issue
# Furthermore, we see some instability to reach ubuntu archive when
# passt is used on 24.10, so for now, we decide to remove it
# for both 24.04 and 24.10
workaround_passt() {
    if command -v passt 2>&1 > /dev/null ; then
       echo "You have the package passt installed, this will prevent"
       echo "  the script to work properly. This package has to be removed:"
       apt autoremove passt
    fi
}

usage() {
    cat <<EOM
Usage: $(basename "$0") [OPTION]...
  -h                        Show this help
  -f                        Force to recreate the output image
  -n                        Guest host name, default is "tdx-guest"
  -u                        Guest user name, default is "tdx"
  -k                        Guest SSH authorized key entry (should be quoted)
  -s                        Specify the size of guest image
  -v                        Ubuntu version (24.04, 25.04)
  -o <output file>          Specify the output file, default is tdx-guest-ubuntu-<version>.qcow2.
                            Please make sure the suffix is qcow2. Due to permission consideration,
                            the output file will be put into /tmp/<output file>.
EOM
}

process_args() {
    while getopts "v:o:s:n:u:k:r:fch" option; do
        case "$option" in
        o) GUEST_IMG_PATH=$(realpath "$OPTARG") ;;
        s) SIZE=${OPTARG} ;;
        n) GUEST_HOSTNAME=${OPTARG} ;;
        u) GUEST_USER=${OPTARG} ;;
        k) GUEST_SSH_KEY=${OPTARG} ;;
        f) FORCE_RECREATE=true ;;
        v) UBUNTU_VERSION=${OPTARG} ;;
        h)
            usage
            exit 0
            ;;
        *)
            echo "Invalid option '-${OPTARG}'"
            usage
            exit 1
            ;;
        esac
    done

    if [[ -z "${UBUNTU_VERSION}" ]]; then
        error "Please specify the ubuntu release by setting UBUNTU_VERSION or passing it via -v"
    fi

    if [[ -z "${GUEST_SSH_KEY}" ]]; then
	error "Please specify the SSH authorized key to be configured for the user ${GUEST_USER}"
    fi

    # generate variables
    CLOUD_IMG="ubuntu-${UBUNTU_VERSION}-server-cloudimg-amd64.img"
    CLOUD_IMG_PATH=$(realpath "${SCRIPT_DIR}/${CLOUD_IMG}")

    # output guest image, set it if user does not specify it
    if [[ -z "${GUEST_IMG_PATH}" ]]; then
        if [[ "${TDX_SETUP_INTEL_KERNEL}" == "1" ]]; then
	    GUEST_IMG_PATH=$(realpath "tdx-guest-ubuntu-${UBUNTU_VERSION}-intel.qcow2")
        else
	    GUEST_IMG_PATH=$(realpath "tdx-guest-ubuntu-${UBUNTU_VERSION}-generic.qcow2")
        fi
    fi

    if [[ "${CLOUD_IMG_PATH}" == "${GUEST_IMG_PATH}" ]]; then
        error "Please specify a different name for guest image via -o"
    fi

    if [[ ${GUEST_IMG_PATH} != *.qcow2 ]]; then
        error "The output file should be qcow2 format with the suffix .qcow2."
    fi
}

download_image() {
    # Get the checksum file first
    if [[ -f ${SCRIPT_DIR}/"SHA256SUMS" ]]; then
        rm ${SCRIPT_DIR}/"SHA256SUMS"
    fi

    OFFICIAL_UBUNTU_IMAGE="https://cloud-images.ubuntu.com/releases/${UBUNTU_VERSION}/release/"
    wget "${OFFICIAL_UBUNTU_IMAGE}/SHA256SUMS" -O ${SCRIPT_DIR}/"SHA256SUMS"

    while :; do
        # Download the cloud image if not exists
        if [[ ! -f ${CLOUD_IMG_PATH} ]]; then
            wget -O ${CLOUD_IMG_PATH} ${OFFICIAL_UBUNTU_IMAGE}/${CLOUD_IMG}
        fi

        # calculate the checksum
        download_sum=$(sha256sum ${CLOUD_IMG_PATH} | awk '{print $1}')
        found=false
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == *"$CLOUD_IMG"* ]]; then
                if [[ "${line%% *}" != ${download_sum} ]]; then
                    echo "Invalid download file according to sha256sum, re-download"
                    rm ${CLOUD_IMG_PATH}
                else
                    ok "Verify the checksum for Ubuntu cloud image."
                    return
                fi
                found=true
            fi
        done < ${SCRIPT_DIR}/"SHA256SUMS"
        if [[ $found != "true" ]]; then
            echo "Invalid SHA256SUM file"
            exit 1
        fi
    done
}

create_guest_image() {
    if [ ${FORCE_RECREATE} = "true" ]; then
        rm -f ${CLOUD_IMG_PATH}
    fi

    download_image

    # this image will need to be customized both by virt-customize and virt-install
    # virt-install will interact with libvirtd and if the latter runs in normal user mode
    # we have to make sure that guest image is writable for normal user
    install -m 0777 ${CLOUD_IMG_PATH} ${TMP_GUEST_IMG_PATH}
    if [ $? -eq 0 ]; then
        ok "Copy the ${CLOUD_IMG} => ${TMP_GUEST_IMG_PATH}"
    else
        error "Failed to copy ${CLOUD_IMG} to /tmp"
    fi

    resize_guest_image
}

# To resize the guest image
# 1) we add additional space to the qcow image using qemu-img tool
# 2) we extend (using growpart) the partition sda1 to fill empty space until end of disk
#    since sda1 is the last partition, it will take all space we previously added
# 3) we resize the file system to cover all partition space
#
# NB: We should not use static name for the disk device (sda) because it can
# change on boot (e.g., the main disk might be named sdb). Using sda naming can cause failure
# of the resizeing operation from time to time.
# Instead, we access the disk by ID:
#
# /dev/disk/by-id:
# total 0
# lrwxrwxrwx 1 0 0  9 Sep  2 12:59 scsi-0QEMU_QEMU_HARDDISK_appliance -> ../../sdb
# lrwxrwxrwx 1 0 0  9 Sep  2 12:59 scsi-0QEMU_QEMU_HARDDISK_hd0 -> ../../sda
# lrwxrwxrwx 1 0 0 10 Sep  2 12:59 scsi-0QEMU_QEMU_HARDDISK_hd0-part1 -> ../../sda1
# lrwxrwxrwx 1 0 0 11 Sep  2 12:59 scsi-0QEMU_QEMU_HARDDISK_hd0-part14 -> ../../sda14
# lrwxrwxrwx 1 0 0 11 Sep  2 12:59 scsi-0QEMU_QEMU_HARDDISK_hd0-part15 -> ../../sda15
# lrwxrwxrwx 1 0 0 11 Sep  2 12:59 scsi-0QEMU_QEMU_HARDDISK_hd0-part16 -> ../../sda16
resize_guest_image() {
    qemu-img resize ${TMP_GUEST_IMG_PATH} +${SIZE}G
    virt-customize -a ${TMP_GUEST_IMG_PATH} \
        --no-network \
        --run-command 'growpart /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_hd0 1' \
        --run-command 'resize2fs /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_hd0-part1' \
        --run-command 'systemctl mask pollinate.service'
    if [ $? -eq 0 ]; then
        ok "Resize the guest image to ${SIZE}G"
    else
        error "Failed to resize guest image to ${SIZE}G"
    fi
}

config_cloud_init_cleanup() {
  virsh shutdown tdx-config-cloud-init &> /dev/null
  sleep 1
  virsh destroy tdx-config-cloud-init &> /dev/null
  virsh undefine tdx-config-cloud-init &> /dev/null
}

apply_cloud_init_conf() {
  virt_type=$1
  virt-install --debug --memory 4096 --vcpus 4 --name tdx-config-cloud-init \
     --disk ${TMP_GUEST_IMG_PATH} \
     --disk /tmp/ciiso.iso,device=cdrom \
     --os-variant ubuntu${UBUNTU_VERSION} \
     --virt-type ${virt_type} \
     --graphics none \
     --import \
     --wait=12 &>> ${LOGFILE}
}


config_cloud_init() {
    pushd ${SCRIPT_DIR}/cloud-init-data
    [ -e /tmp/ciiso.iso ] && rm /tmp/ciiso.iso
    cp user-data.template user-data
    cp meta-data.template meta-data

    # configure the user-data
    cat <<EOT >> user-data

users:
- name: $GUEST_USER
  gecos: TDX admin user
  sudo: ["ALL=(ALL) NOPASSWD:ALL"]
  groups: users, sudo, adm
  shell: /bin/bash
  lock_passwd: true
  ssh_authorized_keys:
    - $GUEST_SSH_KEY
EOT

    # configure the meta-dta
    cat <<EOT >> meta-data

local-hostname: $GUEST_HOSTNAME
EOT

    info "Generate configuration for cloud-init..."
    genisoimage -output /tmp/ciiso.iso -volid cidata -joliet -rock user-data meta-data
    info "Apply cloud-init configuration with virt-install..."
    info "(Check logfile for more details ${LOGFILE})"
    popd

    apply_cloud_init_conf kvm
    RET=$?
    if [ ${RET} -eq 0 ]; then
        ok "Apply cloud-init configuration with virt-install"
        sleep 1
    else
        # if the failure is caused by lack of KVM support
        # try qemu virt type
        if [ ! -f /dev/kvm ]; then
            apt install --yes qemu-system-x86
            apply_cloud_init_conf qemu
            RET=$?
        fi
    fi
    if [ ${RET} -ne 0 ]; then
        warn "Please increase wait time(--wait=12) above and try again..."
        error "Failed to configure cloud init. Please check logfile \"${LOGFILE}\" for more information."
    fi

    config_cloud_init_cleanup
}

setup_guest_image() {
    info "Run setup scripts inside the guest image. Please wait (can take > 10 minutes) ..."
    virt-customize -a ${TMP_GUEST_IMG_PATH} \
       --mkdir /tmp/tdx/ \
       --copy-in ${SCRIPT_DIR}/setup.sh:/tmp/tdx/ \
       --copy-in ${SCRIPT_DIR}/../../setup-tdx-guest.sh:/tmp/tdx/ \
       --copy-in ${SCRIPT_DIR}/../../setup-tdx-common:/tmp/tdx \
       --copy-in ${SCRIPT_DIR}/../../setup-tdx-config:/tmp/tdx \
       --copy-in ${SCRIPT_DIR}/../../attestation/:/tmp/tdx \
       --copy-in ${SCRIPT_DIR}/../../tests/lib/tdx-tools/:/tmp/tdx \
       --run-command "/tmp/tdx/setup.sh"
    if [ $? -eq 0 ]; then
        ok "Run setup scripts inside the guest image"
    else
        error "Failed to setup guest image"
    fi
}

cleanup() {
    if [[ -f ${SCRIPT_DIR}/"SHA256SUMS" ]]; then
        rm ${SCRIPT_DIR}/"SHA256SUMS"
    fi
    info "Cleanup!"
}

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# remove log file to avoid `permission denied` error if the file already exists and owned by a different user
# recently, on Ubuntu and Debian, the syctl variable fs.protected_regular is set to 2
# that will prevent root from writing to file owned by a different user
rm -f ${LOGFILE}
echo "=== tdx guest image generation === " > ${LOGFILE}

# sanity cleanup
config_cloud_init_cleanup

# install required tools
apt install --yes qemu-utils libguestfs-tools virtinst genisoimage libvirt-daemon-system &>> ${LOGFILE}

# to allow virt-customize to have name resolution, dhclient should be available
# on the host system. that is because virt-customize will create an appliance (with supermin)
# from the host system and will collect dhclient into the appliance
apt install --yes isc-dhcp-client &>> ${LOGFILE}

check_tool qemu-img
check_tool virt-customize
check_tool virt-install
check_tool genisoimage
workaround_passt

info "Installation of required tools"

process_args "$@"

create_guest_image

config_cloud_init

setup_guest_image

cleanup

mv ${TMP_GUEST_IMG_PATH} ${GUEST_IMG_PATH}
chmod a+rw ${GUEST_IMG_PATH}

ok "TDX guest image : ${GUEST_IMG_PATH}"
