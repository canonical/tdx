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
import pytest
import Qemu
import util
from common import *

@pytest.mark.xfail(reason="https://jira.devtools.intel.com/browse/SICT0-579")
def test_guest_eventlog(qm):
    """
    Dump event log
    """
    qm.run()

    m = Qemu.QemuSSH(qm)

    deploy_and_setup(m)

    stdout, stderr = m.check_exec('tdeventlog')
    for l in stderr.readlines():
        print(l.rstrip())

    qm.stop()

@pytest.mark.xfail(reason="https://jira.devtools.intel.com/browse/SICT0-579")
def test_guest_eventlog_initrd(qm):
    """
    Check presence of event log for initrd measurement
    """
    qm.run()

    m = Qemu.QemuSSH(qm)

    deploy_and_setup(m)

    stdout, stderr = m.check_exec('tdeventlog_check_initrd')
    for l in stderr.readlines():
        print(l.rstrip())

    qm.stop()
