#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
LOCAL_IMG="${SCRIPT_DIR}/../tdx-guest.qcow2"

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

if [ -z "${TDXTEST_GUEST_IMG}" ]; then
  if ! test -f $LOCAL_IMG; then
    echo "TDXTEST_GUEST_IMG must be specified!"
    echo "e.g. export TDXTEST_GUEST_IMG=/tmp/tmp.qcow2"
    echo "(Use sudo -E to pass environment to sudo)"
    exit 1
  fi
else
  if ! test -f $TDXTEST_GUEST_IMG; then
    echo "\$TDXTEST_GUEST_IMG specified, but does not exist!"
    echo "  Can't find $TDXTEST_GUEST_IMG"
    exit 1
  fi
fi


cleanup

install_deps &> /dev/null
