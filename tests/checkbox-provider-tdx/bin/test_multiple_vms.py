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
import unittest

from parameterized import parameterized

from Qemu import QemuEfiMachine, QemuEfiFlashSize, QemuMachineService
import Qemu

import util

class TdxMultipleVm(unittest.TestCase):
    """
    """
    def setUp(self):
        pass

    def tearDown(self):
        pass

    def test_multiple_vms(self):
        """
        Boot 10 TDs
        """
        self.qm = []
        for i in range(0,10):
            m = Qemu.QemuMachine('td',
                                 QemuEfiMachine.OVMF_Q35_TDX,
                                 service_blacklist = [QemuMachineService.QEMU_MACHINE_PORT_FWD])
            m.run()
            self.qm.append(m)
        for m in self.qm:
            m = Qemu.QemuMonitor(m)
            m.wait_for_state('running')

        for m in self.qm:
            m.stop()

if __name__ == '__main__':
    unittest.main(verbosity=2)
