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

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

source ${SCRIPT_DIR}/../setup-tdx-config
source ${SCRIPT_DIR}/../setup-tdx-common

apt install --yes software-properties-common
add_kobuk_ppa ${TDX_PPA_ATTESTATION:-tdx-attestation-release}

apt update

set -e

apt install --yes --allow-downgrades sgx-dcap-pccs tdx-qgs

# install the Intel Quote Provider library implementation
# this package can be skipped if user can provider its own
# provider
apt install --yes --allow-downgrades libsgx-dcap-default-qpl

# using RA registration (direct registration method)
apt install --yes --allow-downgrades sgx-ra-service

# using indirect registration method
apt install --yes --allow-downgrades sgx-pck-id-retrieval-tool

