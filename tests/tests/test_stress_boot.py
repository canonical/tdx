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

from Qemu import QemuEfiMachine, QemuEfiFlashSize
import Qemu

import util

def test_boot():
    """
    Boot in loop
    """
    for i in range(0,100):
        print(f'\nBooting TD nb={i}')
        qm = Qemu.QemuMachine()
        qm.run()
        m = Qemu.QemuSSH(qm)
        qm.stop()
