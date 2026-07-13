#!/bin/bash

# Copyright (C) 2024 Canonical Ltd.
#
# This file is part of tdx repo. See LICENSE file for license information.

_on_error() {
  trap '' ERR
  line_path=$(caller)
  line=${line_path% *}
  path=${line_path#* }

  echo ""
  echo "ERR $path:$line $BASH_COMMAND exited with $1"
  exit 1
}
trap '_on_error $?' ERR

set -eE

apt update

# Utilities packages for automated testing
# linux-tools-common for perf, please make sure that linux-tools is also installed
apt install -y cpuid linux-tools-common msr-tools python3 python3-pip

# Enable TDX
/tmp/tdx/setup-tdx-guest.sh

# Install tools
cd /tmp/tdx/tdx-tools/
python3 -m pip install --break-system-packages ./

rm -rf /tmp/tdx || true
