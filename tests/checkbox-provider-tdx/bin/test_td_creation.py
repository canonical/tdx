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

class TdxCreationFailure(unittest.TestCase):
    """
    """
    def setUp(self):
        pass

    def tearDown(self):
        pass

    def test_create_td_without_ovmf(self):
        """
        TD creation should be impossible without OVMF
        qemu-system-x86_64 should output the errors:
          Cannot find TDX_METADATA_OFFSET_GUID
          failed to parse TDVF for TDX VM
        """
        self.qm = Qemu.QemuMachine()
        # remove ovmf
        self.qm.qcmd.plugins.pop('ovmf')
        self.qm.run()

        # expect qemu quit immediately 
        _, err = self.qm.communicate()
        assert "failed to parse TDVF for TDX VM" in err.decode()

        self.qm.stop()

if __name__ == '__main__':
    unittest.main(verbosity=2)
