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

CPU_MODEL=$(cat /proc/cpuinfo | awk 'match($0,/model.+: ([0-9]+)/,m){ print m[1]; exit}')

CPU_GEN="unknown generation"
# ref : https://github.com/qemu/qemu/blob/master/target/i386/cpu.c
if [ "$CPU_MODEL" = "143" ]; then
    CPU_GEN="4th Gen Intel® Xeon® Scalable Processors (codename: Sapphire Rapids)"
fi
if [ "$CPU_MODEL" = "173" ]; then
    CPU_GEN="Intel® Xeon® 6 with P-cores (codename: Granite Rapids)"
fi
if [ "$CPU_MODEL" = "175" ]; then
    CPU_GEN="Intel® Xeon® 6 with E-cores (codename: Sierra Forest)"
fi
if [ "$CPU_MODEL" = "207" ]; then
    CPU_GEN="5th Gen Intel® Xeon® Scalable Processors (codename: Emerald Rapids)"
fi

echo "CPU: ${CPU_GEN}"
if [ "${PROD}" = "0" ]; then
    echo "Production"
else
    echo "Pre-production"
fi
