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
