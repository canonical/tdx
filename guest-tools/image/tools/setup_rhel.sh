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

# setup ssh
# allow password auth + root login
sed -i 's|[#]*PasswordAuthentication .*|PasswordAuthentication yes|g' /etc/ssh/sshd_config
sed -i 's|[#]*PermitRootLogin .*|PermitRootLogin yes|g' /etc/ssh/sshd_config
sed -i 's|[#]*KbdInteractiveAuthentication .*|KbdInteractiveAuthentication yes|g' /etc/ssh/sshd_config
# livecd-rootfs adds 60-cloudimg-settings.conf file to set PasswordAuthentication to no
# if the file exists, remove it
rm -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf || true

rm -rf /tmp/tdx || true