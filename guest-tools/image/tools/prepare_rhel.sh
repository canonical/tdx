#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

RHEL_QCOW=$1

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

virt-customize -a ${RHEL_QCOW} \
       --root-password password:123456 \
       --no-network \
       --mkdir /tmp/tdx/ \
       --copy-in ${SCRIPT_DIR}/setup_rhel.sh:/tmp/tdx/ \
       --run-command "/tmp/tdx/setup_rhel.sh"


