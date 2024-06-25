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

from parameterized import parameterized

from Qemu import QemuEfiMachine, QemuEfiFlashSize
import Qemu

import util

@parameterized.expand([
    ['normal', QemuEfiMachine.OVMF_Q35,'2G'],
    ['td', QemuEfiMachine.OVMF_Q35_TDX,'2G'],
    ['normal_16G', QemuEfiMachine.OVMF_Q35,'16G'],
    ['td_16G', QemuEfiMachine.OVMF_Q35_TDX,'16G'],
    ['normal_64G', QemuEfiMachine.OVMF_Q35,'64G'],
    ['td_64G', QemuEfiMachine.OVMF_Q35_TDX,'64G'],
])
def test_boot_time(name, machine, memory):
    """
    Boot time statistics for Normal VM and TD VM
    """
    qm = Qemu.QemuMachine(name,
                          machine,
                          memory=memory)
    def boot_vm_and_wait_ssh():
        qm.run()
        m = Qemu.QemuSSH(qm, timeout=200)

    util.timeit(boot_vm_and_wait_ssh)()

    qm.stop()
