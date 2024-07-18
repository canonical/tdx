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

import os
import subprocess
import time
import re

import Qemu
import util

script_path=os.path.dirname(os.path.realpath(__file__))

def test_guest_noept_fail():
    """
    tdx_NOEPT test case (See https://github.com/intel/tdx/wiki/Tests)
    """

    # Get initial dmesg contents for comparison later
    cs = subprocess.run(['sudo', 'dmesg'], check=True, capture_output=True)
    assert cs.returncode == 0, 'Failed getting dmesg'
    dmesg_start = str(cs.stdout)

    # Setup ept=0 in driver
    cs = subprocess.run(['sudo', 'rmmod', 'kvm_intel'], check=True)
    assert cs.returncode == 0, 'Failed rmmod'
    cs = subprocess.run(['sudo', 'modprobe', 'kvm_intel', 'tdx=1', 'pt_mode=1', 'ept=0'], check=True)
    assert cs.returncode == 0, 'Failed modprobe'

    # Get after modprobe dmesg contents
    cs = subprocess.run(['sudo', 'dmesg'], check=True, capture_output=True)
    assert cs.returncode == 0, 'Failed getting dmesg'
    dmesg_end = str(cs.stdout)

    # Verify "TDX requires mmio caching" in dmesg (but only one more time)
    dmesg_start_count = dmesg_start.count("TDX requires TDP MMU.  Please enable TDP MMU for TDX")
    dmesg_end_count = dmesg_end.count("TDX requires TDP MMU.  Please enable TDP MMU for TDX")
    assert dmesg_end_count == dmesg_start_count+1, "dmesg missing proper message"

    # Run Qemu and verify failure
    qm = Qemu.QemuMachine()
    qm.run()

    # Qemu should fail (capture error string)
    err = ""
    try:
        [tmpout, tmperr] = qm.communicate()
        err += str(tmperr)
    except Exception as e:
        assert False, print(f'Failed communicating with QEMU with Exception {e}')

    # Qemu should fail w/ "-accel kvm: vm-type tdx not supported by KVM"
    assert qm.proc.returncode != 0, "Qemu didn't fail properly"
    assert "-accel kvm: vm-type tdx not supported by KVM" in err, \
            "Qemu didn't fail with proper error"

    # Reinstall kvm_intel "normally"
    cs = subprocess.run(['sudo', 'rmmod', 'kvm_intel'], check=True)
    assert cs.returncode == 0, 'Failed rmmod'
    cs = subprocess.run(['sudo', 'modprobe', 'kvm_intel'], check=True)
    assert cs.returncode == 0, 'Failed modprobe'


def test_guest_disable_tdx_fail():
    """
    tdx_disabled test case (See https://github.com/intel/tdx/wiki/Tests)
    """

    # Setup tdx=0 in driver
    cs = subprocess.run(['sudo', 'rmmod', 'kvm_intel'], check=True)
    assert cs.returncode == 0, 'Failed rmmod'
    cs = subprocess.run(['sudo', 'modprobe', 'kvm_intel', 'tdx=0'], check=True)
    assert cs.returncode == 0, 'Failed modprobe'

    # Run Qemu and verify failure
    qm = Qemu.QemuMachine()
    qm.run()

    # Qemu should fail
    err = ""
    try:
        [tmpout, tmperr] = qm.communicate()
        err += str(tmperr)
    except Exception as e:
        assert False, print(f'Failed communicating with QEMU with Exception {e}')

    # Qemu should fail w/ "-accel kvm: vm-type tdx not supported by KVM"
    assert qm.proc.returncode != 0, "Qemu didn't fail properly"
    assert "-accel kvm: vm-type tdx not supported by KVM" in err, \
            "Qemu didn't fail with proper error"

    # Reinstall kvm_intel "normally"
    cs = subprocess.run(['sudo', 'rmmod', 'kvm_intel'], check=True)
    assert cs.returncode == 0, 'Failed rmmod'
    cs = subprocess.run(['sudo', 'modprobe', 'kvm_intel'], check=True)
    assert cs.returncode == 0, 'Failed modprobe'
