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

import re
import subprocess
import tdxtools

def test_host_tdx_cpu():
    """
    Check that the CPU has TDX support enabled
    (the flag tdx_host_platform is present)
    """
    assert tdxtools.host.support_tdx()

def test_host_tdx_software():

    # when TDX is not properly loaded or initialized
    # this value should by 'N'
    # otherwise, the value 'Y' means tdx has been successfully initialized
    subprocess.check_call('grep Y /sys/module/kvm_intel/parameters/tdx', shell=True)

    subprocess.check_call('grep Y /sys/module/kvm_intel/parameters/sgx', shell=True)

def test_host_tdx_module_load():
    """
    Check the tdx module has been loaded successfuly on the host
    Check a log in dmesg with appropriate versioning information

    tdx_uefi test case (See https://github.com/intel/tdx/wiki/Tests)
    """

    # Get dmesg and make sure it has the tdx module load message
    cs = subprocess.run(['sudo', 'dmesg'], check=True, capture_output=True)
    assert cs.returncode == 0, 'Failed getting dmesg'
    dmesg_str = cs.stdout.decode('utf-8')

    items=re.findall(r'tdx: TDX module [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+, build number [0-9]+, build date [0-9]+', dmesg_str)
    assert len(items) > 0

if __name__ == '__main__':
    test_host_tdx_software()
