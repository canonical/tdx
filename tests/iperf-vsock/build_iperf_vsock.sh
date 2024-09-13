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

if [ ! -f "${SCRIPT_DIR}/../iperf/bin/iperf3" ]; then
    echo "Cloning and building iperf-vsock"
    rm -rf ${SCRIPT_DIR}/../iperf
    TMP_DIR=$(mktemp -d)
    pushd ${TMP_DIR}
    git clone https://github.com/stefano-garzarella/iperf-vsock.git --branch iperf-vsock-3.9
    rc=$?
    if [ $rc -eq 0 ]; then
        cd iperf-vsock
        mkdir build
        cd build
        ../configure --prefix=${SCRIPT_DIR}/../iperf
        make install
        rc=$?
        cp ${TMP_DIR}/iperf-vsock/LICENSE ${SCRIPT_DIR}/../iperf
        cp ${SCRIPT_DIR}/iperf-vsock-3.9 ${SCRIPT_DIR}/../iperf
    fi
    rm -rf ${TMP_DIR}
    popd
    if [ $rc -eq 0 ]; then
        echo "Successfull installed iperf"
        exit 0
    else
        echo "Failed to install iperf"
        exit -1
    fi
fi
echo "Already installed iperf"
exit 0
