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

def test_guest_noept_fail(qm, release_kvm_use):
    """
    tdx_NOEPT test case (See https://github.com/intel/tdx/wiki/Tests)
    """

    # Get initial dmesg contents for comparison later
    cs = subprocess.run(['sudo', 'dmesg'], check=True, capture_output=True)
    assert cs.returncode == 0, 'Failed getting dmesg'
    dmesg_start = str(cs.stdout)

    with KvmIntelModuleReloader('pt_mode=1 ept=0') as module:
        # Get after modprobe dmesg contents
        cs = subprocess.run(['sudo', 'dmesg'], check=True, capture_output=True)
        assert cs.returncode == 0, 'Failed getting dmesg'
        dmesg_end = str(cs.stdout)

        # Verify "TDX requires mmio caching" in dmesg (but only one more time)
        dmesg_start_count = dmesg_start.count("TDX requires TDP MMU.  Please enable TDP MMU for TDX")
        dmesg_end_count = dmesg_end.count("TDX requires TDP MMU.  Please enable TDP MMU for TDX")
        assert dmesg_end_count == dmesg_start_count+1, "dmesg missing proper message"

        # Run Qemu and verify failure
        qm.run()

        # expect qemu quit immediately with specific error message
        _, err = qm.communicate()
        assert "-accel kvm: vm-type tdx not supported by KVM" in err.decode()

def test_guest_disable_tdx_fail(qm, release_kvm_use):
    """
    tdx_disabled test case (See https://github.com/intel/tdx/wiki/Tests)
    """

    with KvmIntelModuleReloader('tdx=0') as module:
        # Run Qemu and verify failure
        qm.run()

        # expect qemu quit immediately with specific error message
        _, err = qm.communicate()
        assert "-accel kvm: vm-type tdx not supported by KVM" in err.decode()

class KvmIntelModuleReloader:
    """
    kvm_intel module reloader (context manager)
    Allow to reload kvm_intel module with custom arguments
    """
    def __init__(self, module_args=''):
        self.args = module_args
    def __enter__(self):
        subprocess.check_call('sudo rmmod kvm_intel', shell=True)
        subprocess.check_call(f'sudo modprobe kvm_intel {self.args}', shell=True)
        return self
    def __exit__(self, exc_type, exc_value, exc_tb):
        # reload the kvm_intel
        subprocess.check_call('sudo rmmod kvm_intel', shell=True)
        subprocess.check_call('sudo modprobe kvm_intel', shell=True)
