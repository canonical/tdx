#!/bin/bash

TD_VM="td_guest"

if [ -z "${TD_IMG}" ]; then
  echo "Please provide image path by setting TD_IMG variable"
  exit 1
fi

virsh shutdown ${TD_VM} &> /dev/null
virsh shutdown --domain ${TD_VM} &> /dev/null

virsh destroy ${TD_VM} &> /dev/null
virsh destroy --domain ${TD_VM} &> /dev/null

virsh undefine ${TD_VM} &> /dev/null

# copy the image
cp ${TD_IMG} /tmp/tdx-guest-ubuntu-23.10.qcow2

virsh define ${TD_VM}.xml
virsh start ${TD_VM}
