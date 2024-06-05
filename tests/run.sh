#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

IMAGE_FILE=/var/tmp/tdxtest/tdx-guest.qcow2

_error() {
  echo "Error : $1"
  exit 1
}

# usage : run.sh <pytest|checkbox>
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

FRONTEND=$1

if [ -z "$FRONTEND" ]; then
  _error "Usage: ./run.sh <pytest|checkbox>"
fi

# copy guest image
if [ -z "${TDXTEST_IMAGE_FILE}" ]; then
    if [ -f "${SCRIPT_DIR}/tdx-guest.qcow2" ]; then
	TDXTEST_IMAGE_FILE="${SCRIPT_DIR}/tdx-guest.qcow2"
    else
	_error "Should specify a guest image by setting TDXTEST_IMAGE_FILE"
    fi
fi

rm -rf /var/tmp/tdxtest
mkdir -p /var/tmp/tdxtest
cp ${TDXTEST_IMAGE_FILE} $IMAGE_FILE &> /dev/null

if [ ! -f $IMAGE_FILE ]; then
  _error "Missing image file : $IMAGE_FILE"
fi

cleanup

install_deps &> /dev/null

export TDXTEST_DEBUG=1

$SCRIPT_DIR/run_$FRONTEND "${@:2}"
