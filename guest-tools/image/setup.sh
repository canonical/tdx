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
apt install -y cpuid linux-tools-common msr-tools

# setup ssh
# allow password auth + root login
sed -i 's|[#]*PasswordAuthentication .*|PasswordAuthentication yes|g' /etc/ssh/sshd_config
sed -i 's|[#]*PermitRootLogin .*|PermitRootLogin yes|g' /etc/ssh/sshd_config
sed -i 's|[#]*KbdInteractiveAuthentication .*|KbdInteractiveAuthentication yes|g' /etc/ssh/sshd_config

# Enable TDX
/tmp/tdx/setup-tdx-guest.sh

rm -rf /tmp/tdx || true
