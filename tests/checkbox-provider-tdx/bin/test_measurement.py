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
import time

from Qemu import QemuEfiMachine, QemuEfiFlashSize
import Qemu

import util

script_path=os.path.dirname(os.path.realpath(__file__))

class TdxMeasurement(unittest.TestCase):
    """
    """
    def setUp(self):
        self.qm = Qemu.QemuMachine()
        self.qm.run()

    def tearDown(self):
        self.qm.stop()

    def test_guest_report(self):
        """
        Boot measurements check
        """
        m = Qemu.QemuSSH(self.qm)
        
        self.qm.rsync_file(f'{script_path}/guest', '/tmp/')
        m.check_exec('/tmp/guest/test_tdreport.py')

    def test_guest_eventlog(self):
        """
        Boot measurements check
        """
        m = Qemu.QemuSSH(self.qm)
        
        self.qm.rsync_file(f'{script_path}/guest', '/tmp/')
        m.check_exec('/tmp/guest/test_eventlog.py')

if __name__ == '__main__':
    unittest.main(verbosity=2)
