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

# check platform registration

set -e

REGISTRATION_SUCCESS=1

check_mpa_status() {
    # Use mpa_manage -get_registration_status to detect the status of registration
    # Do not use mpa_manage -get_last_registration_error_code because it outputs
    # code 0 even when the registration is in progress
    if mpa_manage -get_registration_status | grep "completed successfully" 2>&1 > /dev/null
    then
        REGISTRATION_SUCCESS=0
        echo "mpa_manage: registration status OK."
    else
        echo "mpa_manage: registration status NOK: platform not registered"
    fi
}

# check if MPA is used for platform registration
if systemctl is-enabled mpa_registration_tool.service  2>&1 > /dev/null
then
    if command -v mpa_manage 2>&1 > /dev/null
    then
        check_mpa_status
    else
        echo "mpa_manage is not available, assuming platform not registered."
    fi
fi

exit $REGISTRATION_SUCCESS