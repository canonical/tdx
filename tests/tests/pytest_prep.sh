#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

IMAGE_FILE=/var/tmp/tdxtest/tdx-guest.qcow2

_error() {
  echo "Error : $1"
  exit 1
}

cleanup() {
  for f in /tmp/tdxtest-*-*; do
    if [ -f "$f/qemu.pid" ]; then
      pkill -TERM -F "$f/qemu.pid"
    fi
    rm -rf $f
  done
  rm -rf /tmp/tdxtest-*
  rm -rf /run/user/$UID/tdxtest-*
}

install_deps() {
  sudo apt install -y python3-parameterized \
         sshpass \
         python3-cpuinfo  &> /dev/null
}

rm -rf /var/tmp/tdxtest
mkdir -p /var/tmp/tdxtest

cleanup

install_deps &> /dev/null
