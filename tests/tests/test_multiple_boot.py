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
import Qemu

def test_4vcpus_1socket_10times():
    """
    Test 4vcpus 1socket 10 times (Intel Case ID 009)
    """

    qm = Qemu.QemuMachine()
    qm.qcmd.plugins['cpu'].nb_cores = 4

    Qemu.QemuMonitor.CONNECT_RETRIES = 10

    for i in range(0,10):
        qm.run()
        mon = Qemu.QemuMonitor(qm)
        mon.wait_for_state('running')
        qm.stop()


def test_4vcpus_2sockets_5times():
    """
    Test 4vcpus 2sockets 5 times (Intel Case ID 010)
    """

    qm = Qemu.QemuMachine()
    qm.qcmd.plugins['cpu'].nb_cores = 4
    qm.qcmd.plugins['cpu'].nb_sockets = 2

    Qemu.QemuMonitor.CONNECT_RETRIES = 10

    for i in range(0,5):
        qm.run()
        mon = Qemu.QemuMonitor(qm)
        mon.wait_for_state('running')
        qm.stop()
