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

import pytest

import Qemu

@pytest.mark.quote_generation
def test_stress_tdxattest_tsm():
    """
    Stress test on quote generation
    Have a loop to generate 200 quotes
    """
    with Qemu.QemuMachine() as qm:
        machine = qm.qcmd.plugins['machine']
        machine.enable_qgs_addr()
        qm.qcmd.add_vsock(10)

        qm.run()
        ssh = Qemu.QemuSSH(qm)

        ssh.check_exec('rm -f /etc/tdx-attest.conf')
        nb_iterations = 200
        stdout, _ = ssh.check_exec(f'''
            count={nb_iterations}
            for i in $(seq $count); do
              cd /opt/intel/tdx-quote-generation-sample/ && make clean && make && ./test_tdx_attest | grep "Successfully get the TD Quote"
            done
            ''')
        assert stdout.read().decode().count('Successfully get the TD Quote') == nb_iterations
