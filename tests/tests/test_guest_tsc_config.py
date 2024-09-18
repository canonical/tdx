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

def test_guest_tsc_config():
    """
    tdx_tsc_config test case (See https://github.com/intel/tdx/wiki/Tests)
    """

    # Get and parse cpuid value from host
    cs = subprocess.run(['cpuid', '-rl', '0x15', '-1'], check=True, capture_output=True)
    assert cs.returncode == 0, 'Failed getting cpuid'
    out_str = str(cs.stdout.strip())
    eax, ebx, ecx, edx = parse_cpuid_0x15_values(out_str)
    assert edx == 0, "CPUID values incorrect"

    # calculate tsc value
    tsc_host = ecx * ebx / eax

    with Qemu.QemuMachine() as qm:
        qm.run()

        # Get cpuid value from guest and parse it
        m = Qemu.QemuSSH(qm)
        out_str = ''
        [outlines, err] = m.check_exec('cpuid -rl 0x15 -1')
        for l in outlines.readlines():
            out_str += l
        eax, ebx, ecx, edx = parse_cpuid_0x15_values(out_str)

        # calculate tsc value on guest and make sure same as host
        tsc_guest = ecx * ebx / eax
        assert tsc_guest == tsc_host, "TSC host and guest don't match"

        # Verify tsc detected in guest dmesg logs
        stdout, _ = m.check_exec('dmesg')
        output = stdout.read().decode('utf-8')
        assert 'tsc: Detected' in output

        qm.stop()


def test_guest_set_tsc_frequency():
    """
    tdx_tsc_config test case (See https://github.com/intel/tdx/wiki/Tests)
    """

    # Set guest tsc frequency
    tsc_frequency = 3000000000
    with Qemu.QemuMachine() as qm:
        qm.qcmd.plugins['cpu'].cpu_flags += f',tsc-freq={tsc_frequency}'
        qm.run()

        # Get cpuid value from guest and parse it
        m = Qemu.QemuSSH(qm)
        out_str = ''
        [outlines, err] = m.check_exec('cpuid -rl 0x15 -1')
        for l in outlines.readlines():
            out_str += l
        eax, ebx, ecx, edx = parse_cpuid_0x15_values(out_str)

        # calculate tsc on guest and make sure its equal to value set
        tsc_guest = ecx * ebx / eax
        assert tsc_guest == tsc_frequency, "TSC frequency not set correctly"

def test_guest_tsc_deadline_enable():
    """
    tdx_tsc_deadline_enable test case (See https://github.com/intel/tdx/wiki/Tests)
    """
    qm = Qemu.QemuMachine()
    qm.run()

    m = Qemu.QemuSSH(qm)

    stdout, _ = m.check_exec('lscpu')
    output = stdout.read().decode('utf-8')
    assert 'Flags' in output
    assert 'tsc_deadline_timer' in output

    qm.stop()

def test_guest_tsc_deadline_disable():
    """
    tdx_tsc_deadline_disable test case (See https://github.com/intel/tdx/wiki/Tests)
    """
    with Qemu.QemuMachine() as qm:
        qm.qcmd.plugins['cpu'].cpu_flags += f',-tsc-deadline'
        qm.run()

        m = Qemu.QemuSSH(qm)

        stdout, _ = m.check_exec('lscpu')
        output = stdout.read().decode('utf-8')
        assert 'Flags' in output
        assert 'tsc_deadline_timer' not in output

        qm.stop()

# helper function for parsing cpuid value into registers
def parse_cpuid_0x15_values(val_str):
    # parse register values
    try:
        eax = int(re.findall(r'eax=0x([0-9a-f]+)', val_str)[0], 16)
        ebx = int(re.findall(r'ebx=0x([0-9a-f]+)', val_str)[0], 16)
        ecx = int(re.findall(r'ecx=0x([0-9a-f]+)', val_str)[0], 16)
        edx = int(re.findall(r'edx=0x([0-9a-f]+)', val_str)[0], 16)
    except Exception as e:
        assert False, print(f'Failed parsing cpuid registers {e}')
    return eax, ebx, ecx, edx
