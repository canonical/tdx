#!/bin/bash

# caller can set a list of environment variables by putting them into the file /tmp/tdx-guest-setup-env
if [ -f /tmp/tdx-guest-setup-env ]; then
  source /tmp/tdx-guest-setup-env
fi

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
/tmp/setup-tdx-guest.sh
