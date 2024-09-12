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
import multiprocessing
import random

import Qemu
import util

script_path=os.path.dirname(os.path.realpath(__file__))

def test_guest_cpu_off():
    """
    tdx_VMP_cpu_onoff test case (See https://github.com/intel/tdx/wiki/Tests)
    """

    # Startup Qemu and connect via SSH
    qm = Qemu.QemuMachine()
    qm.run()
    m = Qemu.QemuSSH(qm)

    # turn off arbitrary cpus
    cpu = cpu_off_random()
    
    # make sure the VM still does things
    still_working = True
    try:
        m.check_exec('ls /tmp')
    except Exception as e:
        still_working = False

    qm.stop()

    # turn back on cpus
    cpu_on_off(f'/sys/devices/system/cpu/cpu{cpu}/online', 1)

    assert still_working, 'VM dysfunction when a cpu is brought offline'

def test_guest_cpu_pinned_off():
    """
    tdx_cpuoff_pinedVMdown test case (See https://github.com/intel/tdx/wiki/Tests)
    """

    # do 20 iterations of starting up a VM, pinning the VM pid, turning off 
    # the pinned cpu and making sure host still works
    for i in range(1,20):
        print(f'Iteration: {i}')
        qm = Qemu.QemuMachine()
        qm.run()

        # get pid of Qemu machine (not written immediately sometimes)
        tries = 0
        cs = subprocess.run(['cat', f'{qm.workdir.name}/qemu.pid'], capture_output=True)
        while cs.returncode != 0 and tries < 10:
            cs = subprocess.run(['cat', f'{qm.workdir.name}/qemu.pid'], capture_output=True)
            tries += 1
        assert cs.returncode == 0, 'Failed getting qemu pid'
        pid = int(cs.stdout.strip())

        m = Qemu.QemuSSH(qm)

        # pin pid to a particular cpu
        cs = subprocess.run(['sudo', 'taskset', '-pc', '18', f'{pid}'], capture_output=True)
        assert cs.returncode == 0, 'Failed pinning qemu pid to cpu 18'

        cpu_on_off('/sys/devices/system/cpu/cpu18/online', 0)

        m.check_exec('sudo init 0 &')

        qm.stop()

        cpu_on_off('/sys/devices/system/cpu/cpu18/online', 1)

def cpu_off_random():
    cpu = cpu_select()
    cpu_on_off(f'/sys/devices/system/cpu/cpu{cpu}/online', 1)
    cpu_on_off(f'/sys/devices/system/cpu/cpu{cpu}/online', 0)
    return cpu

def cpu_select():
    cpu_count = multiprocessing.cpu_count()
    cpu = random.randint(0, cpu_count-1)
    return cpu

# Helper function for turning cpu on/off
def cpu_on_off(file_str, val):
    dev_f = open(file_str, 'w')
    cs = subprocess.run(['echo', f'{val}'], check=True, stdout=dev_f)
    assert cs.returncode == 0, 'Failed turning cpu off'
    dev_f.close()

