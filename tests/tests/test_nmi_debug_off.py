# Copyright 2024 Canonical Ltd.
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

# Global Variables
script_path=os.path.dirname(os.path.realpath(__file__))


# Tests

def test_nmi_debug_off():
    """
    Boot TDX VM and make sure nmi runs without issue in monitor
    """
    qm = Qemu.QemuMachine()
    #Qemu.QemuMachineType.Qemu_Machine_Params[Qemu.QemuEfiMachine.OVMF_Q35_TDX][1] += ",debug=off"
    qm.run()

    m = Qemu.QemuMonitor(qm)

    # tdx guest run nmi
    msgs = m.send_command('nmi')
    assert len(msgs) > 0, "Invalid response from nmi command"
    for msg in msgs:
        assert "unknown" not in msg

    # make sure system is still running
    running = False
    msgs = m.send_command('info status')
    for msg in msgs:
        running |= "running" in msg
    assert running, "Invalid state after running nmi command"
    m.send_command('quit')

    qm.stop()
