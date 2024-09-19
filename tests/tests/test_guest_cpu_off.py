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

def test_guest_cpu_off(qm, cpu_core):
    """
    tdx_VMP_cpu_onoff test case (See https://github.com/intel/tdx/wiki/Tests)
    """

    # Startup Qemu and connect via SSH
    qm.run()
    m = Qemu.QemuSSH(qm)

    cpu_core.set_state(0)
    
    # make sure the VM still does things
    m.check_exec('ls /tmp')

    qm.stop()

def test_guest_cpu_pinned_off():
    """
    tdx_cpuoff_pinedVMdown test case (See https://github.com/intel/tdx/wiki/Tests)
    """

    # do 20 iterations of starting up a VM, pinning the VM pid, turning off 
    # the pinned cpu and making sure host still works
    for i in range(1,20):
        print(f'Iteration: {i}')
        with Qemu.QemuMachine() as qm:
            qm.run_and_wait()

            cpu = util.cpu_select()

            with util.CpuOnOff(cpu) as cpu_manager:
                # bring the cpu online if necessary
                cpu_manager.set_state(1)
                util.pin_process_on_cpu(qm.pid, cpu)

                # bring the cpu core offline
                cpu_manager.set_state(0)
                m = Qemu.QemuSSH(qm)
                m.check_exec('sudo init 0 &')

            qm.stop()
