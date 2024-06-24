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
