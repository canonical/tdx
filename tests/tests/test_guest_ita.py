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
import util

def test_guest_measurement_trust_authority_success():
    """
    Trust Authority CLI quote generation success
    """
    change_qgsd_state('start')
    quote_str = run_trust_authority()
    quote = json.loads(quote_str.replace(' ', ','))
    assert len(quote) > 0, "Quote not valid: %s" % (quote_str)


def test_guest_measurement_trust_authority_failure():
    """
    Trust Authority CLI quote generation failure
    """
    change_qgsd_state('stop')
    quote_str = run_trust_authority()
    change_qgsd_state('start')
    quote = json.loads(quote_str.replace(' ', ','))
    assert len(quote) == 0, "Quote not valid: %s" % (quote_str)


def change_qgsd_state(state):
    cmd = ['systemctl', state, 'qgsd']
    subprocess.run(cmd)
    rc = subprocess.run(cmd, stderr=subprocess.STDOUT, timeout=30)
    assert 0 == rc.returncode, 'Failed change state of qgsd'


def run_trust_authority():
    object = '{"qom-type":"tdx-guest","id":"tdx","quote-generation-socket":{"type": "vsock", "cid":"2","port":"4050"}}'
    Qemu.QemuMachineType.Qemu_Machine_Params[Qemu.QemuEfiMachine.OVMF_Q35_TDX][1] = object

    quote_str = ""
    with Qemu.QemuMachine() as qm:
        qm.qcmd.add_vsock(3)
        qm.run()

        ssh = Qemu.QemuSSH(qm)

        stdout, stderr = ssh.check_exec('trustauthority-cli quote')
        quote_str = stdout.read().decode()
    return quote_str
