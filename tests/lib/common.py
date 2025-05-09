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

script_path=os.path.dirname(os.path.realpath(__file__)) + '/'
# put in /var/tmp instead of /tmp to be persistent across reboots 
guest_workdir='/var/tmp'

def deploy_and_setup(m : Qemu.QemuSSH):
    m.rsync_file(f'{script_path}/../', f'{guest_workdir}')
    m.check_exec(f'cd {guest_workdir} && ./lib/setup_guest.sh')
