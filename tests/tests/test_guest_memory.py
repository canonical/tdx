#!/usr/bin/env python3
#
# Copyright 2024 Canonical Ltd.
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
import time
import json
import subprocess

import Qemu
from common import *

MEMORY_FILE='memory.bin'
CHECK_EXEC='export INCLEAR=6150079244'

def check_for_string(filename, needle):
    cs = subprocess.run(['sudo', 'grep', needle, filename], check=True, capture_output=True)
    return cs.returncode

def remove_file(filename):
    cs = subprocess.run(['sudo', 'rm', '-f', filename], check=True, capture_output=True)
    return cs.returncode

def test_guest_memory_confidentiality_no_tdx(qm):
    """
    Test guest memory confidentiality without TDX
    """
    with Qemu.QemuMachine(memory='1G', machine=Qemu.QemuEfiMachine.OVMF_Q35) as qm:
        qm.run()

        qmon = Qemu.QemuMonitor(qm)
        qmon.wait_for_state('running')

        qssh = Qemu.QemuSSH(qm)

        qssh.check_exec(CHECK_EXEC)

        qmon.send_command('dump-guest-memory %s' % (MEMORY_FILE))

        rc = check_for_string(MEMORY_FILE, CHECK_EXEC)
        assert rc == 0, 'Failed finding %s in %s' % (CHECK_EXEC, MEMORY_FILE)

        remove_file(MEMORY_FILE)

        qm.stop()

def test_guest_memory_confidentiality_tdx(qm):
    """
    Test guest memory confidentiality with TDX
    """
    with Qemu.QemuMachine(memory='1G') as qm:
        qm.run()

        qmon = Qemu.QemuMonitor(qm)
        qmon.wait_for_state('running')

        qssh = Qemu.QemuSSH(qm)

        qssh.check_exec(CHECK_EXEC)

        qmon.send_command('dump-guest-memory %s' % (MEMORY_FILE))

        rc = check_for_string(MEMORY_FILE, CHECK_EXEC)
        assert rc == 1, 'Failed by finding %s in %s' % (CHECK_EXEC, MEMORY_FILE)

        remove_file(MEMORY_FILE)

        qm.stop()
