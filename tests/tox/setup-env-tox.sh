#!/bin/bash

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
  sudo apt install -y sshpass cpuid
  sudo apt remove iperf3 -y
  sudo add-apt-repository ppa:kobuk-team/testing -y
  sudo apt update || true
  sudo apt install iperf-vsock -y
}

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

set -e

install_deps
