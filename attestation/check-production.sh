# Copyright (C) 2024 Canonical Ltd.
#
# This file is part of tdx repo. See LICENSE file for license information.

#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

apt install -y msr-tools &> /dev/null

set -e

modprobe msr
PROD=$(rdmsr 0xce -f 27:27)

if [ "${PROD}" = "0" ]; then
    echo "Production"
else
    echo "Pre-production"
fi
