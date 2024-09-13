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
import Qemu
from common import *

def test_guest_boot():
    """
    Boot TD
    """
    qm = Qemu.QemuMachine()
    qm.run()

    m = Qemu.QemuSSH(qm)

    deploy_and_setup(m)

    # tdx guest device driver
    m.check_exec('ls -la /dev/tdx_guest')
    # CCEL table (event log)
    m.check_exec('ls -la /sys/firmware/acpi/tables/CCEL')

    qm.stop()

def test_early_printk():
    """
    Test Early Printk with Debug Off (Intel Case ID 018)
    """

    qm = Qemu.QemuMachine()
    qm.qcmd.plugins['boot'].kernel = "/boot/vmlinuz"
    qm.qcmd.plugins['boot'].append = "earlyprintk=ttyS0,115200"
    qm.run()

    mon = Qemu.QemuMonitor(qm)
    mon.wait_for_state('running')

    qm.stop()
