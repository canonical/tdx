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

#!/bin/bash
#

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

CURR_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# source config file
if [ -f ${CURR_DIR}/../../setup-tdx-config ]; then
    source ${CURR_DIR}/../../setup-tdx-config
fi

LOGFILE=/tmp/tdx-guest-setup.txt
WORK_DIR=${PWD}
FORCE_RECREATE=false
OFFICIAL_UBUNTU_IMAGE=${OFFICIAL_UBUNTU_IMAGE:-"https://cloud-images.ubuntu.com/releases/noble/release/"}
CLOUD_IMG=${CLOUD_IMG:-"ubuntu-24.04-server-cloudimg-amd64.img"}
if [[ "${TDX_SETUP_INTEL_KERNEL}" == "1" ]]; then
    GUEST_IMG="tdx-guest-ubuntu-24.04-intel.qcow2"
else
    GUEST_IMG="tdx-guest-ubuntu-24.04-generic.qcow2"
fi
SIZE=50
GUEST_USER=${GUEST_USER:-"tdx"}
GUEST_PASSWORD=${GUEST_PASSWORD:-"123456"}
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

check_tool() {
    [[ "$(command -v $1)" ]] || { error "$1 is not installed" 1>&2 ; }
}

usage() {
    cat <<EOM
Usage: $(basename "$0") [OPTION]...
  -h                        Show this help
  -f                        Force to recreate the output image
  -n                        Guest host name, default is "tdx-guest"
  -u                        Guest user name, default is "tdx"
  -p                        Guest password, default is "123456"
  -s                        Specify the size of guest image
  -o <output file>          Specify the output file, default is tdx-guest-ubuntu-24.04.qcow2.
                            Please make sure the suffix is qcow2. Due to permission consideration,
                            the output file will be put into /tmp/<output file>.
EOM
}

process_args() {
    while getopts "o:s:n:u:p:r:fch" option; do
        case "$option" in
        o) GUEST_IMG=$OPTARG ;;
        s) SIZE=$OPTARG ;;
        n) GUEST_HOSTNAME=$OPTARG ;;
        u) GUEST_USER=$OPTARG ;;
        p) GUEST_PASSWORD=$OPTARG ;;
        f) FORCE_RECREATE=true ;;
        h)
            usage
            exit 0
            ;;
        *)
            echo "Invalid option '-$OPTARG'"
            usage
            exit 1
            ;;
        esac
    done

    if [[ "${CLOUD_IMG}" == "${GUEST_IMG}" ]]; then
        error "Please specify a different name for guest image via -o"
    fi

    if [[ ${GUEST_IMG} != *.qcow2 ]]; then
        error "The output file should be qcow2 format with the suffix .qcow2."
    fi
}

download_image() {
    # Get the checksum file first
    if [[ -f ${CURR_DIR}/"SHA256SUMS" ]]; then
        rm ${CURR_DIR}/"SHA256SUMS"
    fi

    wget "${OFFICIAL_UBUNTU_IMAGE}/SHA256SUMS"

    while :; do
        # Download the cloud image if not exists
        if [[ ! -f ${CLOUD_IMG} ]]; then
            wget -O ${CURR_DIR}/${CLOUD_IMG} ${OFFICIAL_UBUNTU_IMAGE}/${CLOUD_IMG}
        fi

        # calculate the checksum
        download_sum=$(sha256sum ${CURR_DIR}/${CLOUD_IMG} | awk '{print $1}')
        found=false
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == *"$CLOUD_IMG"* ]]; then
                if [[ "${line%% *}" != ${download_sum} ]]; then
                    echo "Invalid download file according to sha256sum, re-download"
                    rm ${CURR_DIR}/${CLOUD_IMG}
                else
                    ok "Verify the checksum for Ubuntu cloud image."
                    return
                fi
                found=true
            fi
        done <"SHA256SUMS"
        if [[ $found != "true" ]]; then
            echo "Invalid SHA256SUM file"
            exit 1
        fi
    done
}

create_guest_image() {
    if [ ${FORCE_RECREATE} = "true" ]; then
        rm -f ${CURR_DIR}/${CLOUD_IMG}
    fi

    download_image

    # this image will need to be customized both by virt-customize and virt-install
    # virt-install will interact with libvirtd and if the latter runs in normal user mode
    # we have to make sure that guest image is writable for normal user
    install -m 0777 ${CURR_DIR}/${CLOUD_IMG} /tmp/${GUEST_IMG}
    if [ $? -eq 0 ]; then
        ok "Copy the ${CLOUD_IMG} => /tmp/${GUEST_IMG}"
    else
        error "Failed to copy ${CLOUD_IMG} to /tmp"
    fi

    resize_guest_image
}

resize_guest_image() {
    qemu-img resize /tmp/${GUEST_IMG} +${SIZE}G
    virt-customize -a /tmp/${GUEST_IMG} \
        --run-command 'growpart /dev/sda 1' \
        --run-command 'resize2fs /dev/sda1' \
        --run-command 'systemctl mask pollinate.service'
    if [ $? -eq 0 ]; then
        ok "Resize the guest image to ${SIZE}G"
    else
        warn "Failed to resize guest image to ${SIZE}G"
    fi
}

config_cloud_init_cleanup() {
  virsh shutdown tdx-config-cloud-init &> /dev/null
  sleep 1
  virsh destroy tdx-config-cloud-init &> /dev/null
  virsh undefine tdx-config-cloud-init &> /dev/null
}

config_cloud_init() {
    pushd ${CURR_DIR}/cloud-init-data
    [ -e /tmp/ciiso.iso ] && rm /tmp/ciiso.iso
    cp user-data.template user-data
    cp meta-data.template meta-data

    # configure the user-data
    cat <<EOT >> user-data

user: $GUEST_USER
password: $GUEST_PASSWORD
chpasswd: { expire: False }
EOT

    # configure the meta-dta
    cat <<EOT >> meta-data

local-hostname: $GUEST_HOSTNAME
EOT

    ok "Generate configuration for cloud-init..."
    genisoimage -output /tmp/ciiso.iso -volid cidata -joliet -rock user-data meta-data
    ok "Generate the cloud-init ISO image..."
    popd

    virt-install --debug --memory 4096 --vcpus 4 --name tdx-config-cloud-init \
        --disk /tmp/${GUEST_IMG} \
        --disk /tmp/ciiso.iso,device=cdrom \
        --os-variant ubuntu24.04 \
        --virt-type kvm \
        --graphics none \
        --import \
        --wait=12 &>> $LOGFILE
    if [ $? -eq 0 ]; then
        ok "Complete cloud-init..."
        sleep 1
    else
        warn "Please increase wait time(--wait=12) above and try again..."
        error "Failed to configure cloud init"
    fi

    config_cloud_init_cleanup
}

setup_guest_image() {
    virt-customize -a /tmp/${GUEST_IMG} \
       --mkdir /tmp/tdx/ \
       --copy-in ${CURR_DIR}/setup.sh:/tmp/tdx/ \
       --copy-in ${CURR_DIR}/../../setup-tdx-guest.sh:/tmp/tdx/ \
       --copy-in ${CURR_DIR}/../../setup-tdx-common:/tmp/tdx \
       --copy-in ${CURR_DIR}/../../setup-tdx-config:/tmp/tdx \
       --copy-in ${CURR_DIR}/../../attestation/:/tmp/tdx \
       --run-command "/tmp/tdx/setup.sh"
    if [ $? -eq 0 ]; then
        ok "Setup guest image..."
    else
        error "Failed to setup guest image"
    fi
}

cleanup() {
    if [[ -f ${CURR_DIR}/"SHA256SUMS" ]]; then
        rm ${CURR_DIR}/"SHA256SUMS"
    fi
    ok "Cleanup!"
}

echo "=== tdx guest image generation === " > $LOGFILE

# sanity cleanup
config_cloud_init_cleanup

# install required tools
apt install --yes qemu-utils libguestfs-tools virtinst genisoimage libvirt-daemon-system &>> $LOGFILE

# to allow virt-customize to have name resolution, dhclient should be available
# on the host system. that is because virt-customize will create an appliance (with supermin)
# from the host system and will collect dhclient into the appliance
apt install --yes isc-dhcp-client &>> $LOGFILE

check_tool qemu-img
check_tool virt-customize
check_tool virt-install
check_tool genisoimage

ok "Installation of required tools"

process_args "$@"

#
# Check user permission
#
if (( $EUID != 0 )); then
    warn "Current user is not root, please use root permission via \"sudo\" or make sure current user has correct "\
         "permission by configuring /etc/libvirt/qemu.conf"
    warn "Please refer https://libvirt.org/drvqemu.html#posix-users-groups"
    sleep 5
fi

create_guest_image

config_cloud_init

setup_guest_image

cleanup

mv /tmp/${GUEST_IMG} ${WORK_DIR}/
chmod a+rw ${WORK_DIR}/${GUEST_IMG}

ok "TDX guest image : ${WORK_DIR}/${GUEST_IMG}"
