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

def test_guest_boot(qm):
    """
    Boot TD
    """
    qm.run()

    m = Qemu.QemuSSH(qm)

    #deploy_and_setup(m)

    # tdx guest device driver
    m.check_exec('ls -la /dev/tdx_guest')
    # CCEL table (event log)
    m.check_exec('ls -la /sys/firmware/acpi/tables/CCEL')

    qm.stop()

def test_guest_early_printk(qm):
    """
    Test Early Printk with Debug Off (Intel Case ID 018)
    """

    qm.run()

    m = Qemu.QemuSSH(qm)
    # add_earlyprintk_cmd = r'''
    #   sed -i -E "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 earlyprintk=ttyS0,115200\"/g" /etc/default/grub
    #   update-grub
    #   grub-install --no-nvram
    # '''
    add_earlyprintk_cmd = r'''
      sed -i -E "s/GRUB_CMDLINE_LINUX=\"(.*)\"/GRUB_CMDLINE_LINUX=\"\1 earlyprintk=ttyS0,115200\"/g" /etc/default/grub
      grub2-mkconfig -o /boot/grub2/grub.cfg
    '''
    m.check_exec(add_earlyprintk_cmd)

    qm.reboot()

    m = Qemu.QemuSSH(qm)
    m.check_exec('grep earlyprintk=ttyS0,115200 /proc/cmdline')

    qm.stop()
