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

from parameterized import parameterized

from Qemu import QemuEfiMachine, QemuEfiFlashSize
import Qemu

import util

@parameterized.expand([
    ['normal', QemuEfiMachine.OVMF_Q35],
    ['td', QemuEfiMachine.OVMF_Q35_TDX]
])
def test_run_perf(name, machine):
    """
    Run benchmark.sh script on TD VM and VM
    """
    qm = Qemu.QemuMachine(name,
                               machine,
                               memory='32G')
    qm.run()

    test_profile='tdx_memory'
    m1 = Qemu.QemuSSH(qm)
    script_path=os.path.dirname(os.path.realpath(__file__))
    qm.rsync_file(f'{script_path}/../lib/pts', '/')
    m.ssh_conn.exec_command('chmod a+x /pts/benchmark.sh')
    _, stdout, _ = m.ssh_conn.exec_command(f'/pts/benchmark.sh {test_profile} &> /pts/benchmark-{name}.txt')
    assert (0 == stdout.channel.recv_exit_status()), 'benchmark run failed !'
    m.get(f'/pts/benchmark-{name}.txt', f'{script_path}/benchmark-{name}.txt')
    m.get(f'/pts/benchmark.csv', f'{script_path}/benchmark-{name}.csv')
    m.poweroff()
