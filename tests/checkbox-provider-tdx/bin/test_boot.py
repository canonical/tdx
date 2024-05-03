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

from Qemu import QemuEfiMachine, QemuEfiFlashSize
import Qemu

import util

class TdxBoot(unittest.TestCase):
    """
    """
    def setUp(self):
        self.qm = Qemu.QemuMachine()
        #self.qm.qcmd.plugins['boot'].kernel='/boot/vmlinuz-6.8.0-31-generic'
        self.qm.run()

    def tearDown(self):
        self.qm.stop()

    def test_boot(self):
        """
        Boot check
        """
        m = Qemu.QemuSSH(self.qm)
        # tdx guest device driver
        m.check_exec('ls -la /dev/tdx_guest')
        # CCEL table (event log)
        m.check_exec('ls -la /sys/firmware/acpi/tables/CCEL')

if __name__ == '__main__':
    unittest.main(verbosity=2)
