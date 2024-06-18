#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

SCRIPT_DIR=$SCRIPT_DIR/../

# source config file
if [ -f ${SCRIPT_DIR}/setup-tdx-config ]; then
    source ${SCRIPT_DIR}/setup-tdx-config
fi

on_exit() {
    rc=$?
    if [ ${rc} -ne 0 ]; then
        echo "====================================="
        echo "ERROR : The script failed..."
        echo "====================================="
    fi
    return ${rc}
}

_error() {
  echo "Error : $1"
  exit 1
}

trap "on_exit" EXIT

KERNEL_RELEASE=6.8.0-1006-intel

add_kobuk_ppa() {
  ppa_id=$1
  distro_id=LP-PPA-kobuk-team-${ppa_id}
  distro_codename=noble

  add-apt-repository -y ppa:kobuk-team/${ppa_id}

  cat <<EOF | tee /etc/apt/preferences.d/kobuk-team-${ppa_id}-pin-4000
Package: *
Pin: release o=${distro_id}
Pin-Priority: 5000
EOF
}
add_kobuk_ppa testing

apt install --yes --allow-downgrades \
    linux-image-unsigned-6.8.0-1006-intel \
    linux-modules-6.8.0-1006-intel \
    linux-modules-extra-6.8.0-1006-intel

source ${SCRIPT_DIR}/setup-tdx-common

grub_set_kernel

