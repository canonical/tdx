#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TEST_DIR=checkbox-provider-tdx/
IMAGE_FILE=$SCRIPT_DIR/$TEST_DIR/data/tdx-guest.qcow2

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
}

install_deps() {
		sudo apt install -y python3-parameterized sshpass
}

FRONTEND=$1

if [ -z "$FRONTEND" ]; then
  _error "Usage: ./run.sh <pytest|checkbox>"
fi
	 
if [ ! -f $IMAGE_FILE ]; then
  _error "Missing image file : $IMAGE_FILE"
fi

cleanup

install_deps &> /dev/null

$SCRIPT_DIR/run_$FRONTEND
