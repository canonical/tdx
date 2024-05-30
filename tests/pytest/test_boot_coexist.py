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

from Qemu import QemuEfiMachine, QemuEfiFlashSize, QemuMachineService
import Qemu

import util

def test_coexist_boot():
    """
    Boot check
    """
    qm = Qemu.QemuMachine('td',
                               QemuEfiMachine.OVMF_Q35_TDX,
                               service_blacklist = [QemuMachineService.QEMU_MACHINE_PORT_FWD])
    qm.run()
    qm_normal = Qemu.QemuMachine('normal',
                                      QemuEfiMachine.OVMF_Q35,
                                      service_blacklist = [QemuMachineService.QEMU_MACHINE_PORT_FWD])
    qm_normal.run()

    m = Qemu.QemuMonitor(qm)
    m.wait_for_state('running')
    m_normal = Qemu.QemuMonitor(qm_normal)
    m_normal.wait_for_state('running')

    qm.stop()
    qm_normal.stop()
