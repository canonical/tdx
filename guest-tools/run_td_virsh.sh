#!/bin/bash

TD_VM="td_guest"

if [ ! -f "${TD_IMG}" ]; then
  echo "Please provide image path by setting TD_IMG variable"
  exit 1
fi

virsh shutdown ${TD_VM} &> /dev/null
virsh shutdown --domain ${TD_VM} &> /dev/null

virsh destroy ${TD_VM} &> /dev/null
virsh destroy --domain ${TD_VM} &> /dev/null

virsh undefine ${TD_VM} &> /dev/null

# Generate td_guest.xml with the right image path provided by the user
TD_IMG_PATH=$(realpath ${TD_IMG})
awk -v img_path=${TD_IMG_PATH} '{gsub("TD_IMG_PATH", img_path, $0); print}' td_guest.xml.template > td_guest.xml

virsh define ${TD_VM}.xml
virsh start ${TD_VM}
