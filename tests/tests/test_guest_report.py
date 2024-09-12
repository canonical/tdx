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
import time

import Qemu
import util
from common import *

def test_guest_report():
    """
    Boot measurements check
    """
    qm = Qemu.QemuMachine()
    qm.run()

    m = Qemu.QemuSSH(qm)

    deploy_and_setup(m)

    m.check_exec(f'python3 {guest_workdir}/tests/guest/test_tdreport.py')

    qm.stop()
