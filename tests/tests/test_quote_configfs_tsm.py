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
from common import deploy_and_setup

script_path=os.path.dirname(os.path.realpath(__file__))

def test_quote_check_configfs_tsm(qm):
    """
    Check that the configfs tsm for quote generation is available
    """
    qm.run()

    m = Qemu.QemuSSH(qm)

    deploy_and_setup(m)

    m.check_exec('tdtsmcheck')

    qm.stop()

def test_qgs_socket(qm):
    """
    Test QGS socket (No Intel Case ID)
    """
    machine = qm.qcmd.plugins['machine']
    machine.enable_quote_socket()

    qm.run()

    # do basic tsm_config test on guest
    ssh = Qemu.QemuSSH(qm)
    deploy_and_setup(ssh)
    ssh.check_exec('tdtsmcheck')

    qm.stop()
