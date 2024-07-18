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

def test_host_tdx_uefi():
    """
    tdx_uefi test case (See https://github.com/intel/tdx/wiki/Tests)
    """

    # Get dmesg and make sure it has the attributes line indicating uefi
    cs = subprocess.run(['sudo', 'dmesg'], check=True, capture_output=True)
    assert cs.returncode == 0, 'Failed getting dmesg'
    dmesg_str = str(cs.stdout)
    assert "tdx: TDX module: attributes" in dmesg_str, "Could not find tdx module init in dmesg"

    # Adding this for maybe doing more verification of the information here in the future
    # Parsing the line into pairs of "attributs,0x0", "vendor_id, 0x8086", ...
    i1 = dmesg_str.find('tdx: TDX module: attributes')
    i2 = dmesg_str[i1:].find('\\n')
    pairs = dmesg_str[i1+17:i1+i2].split(',')
    for p in pairs:
        print(p.strip().split(' '))


if __name__ == '__main__':
    test_host_tdx_software()
