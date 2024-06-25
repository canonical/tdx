#!/usr/bin/env python3
#
# Copyright 2024 Canonical Ltd.
# Authors:
# - Hector Cao <hector.cao@canonical.com>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranties of MERCHANTABILITY,
# SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#

import subprocess

def test_host_tdx_software():

    # when TDX is not properly loaded or initialized
    # this value should by 'N'
    # otherwise, the value 'Y' means tdx has been successfully initialized
    subprocess.check_call('grep Y /sys/module/kvm_intel/parameters/tdx', shell=True)

    subprocess.check_call('grep Y /sys/module/kvm_intel/parameters/sgx', shell=True)

if __name__ == '__main__':
    test_host_tdx_software()
