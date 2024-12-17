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
import subprocess
import tdxtools

def test_host_tdx_hardware_enabled():
    """
    Check if host is TDX capabled
    """
    
    #
    # Check the bit 1 of MSR 0x982. 1 means MK-TME is enabled in BIOS.
    # SDM:
    #   Vol. 4 Model Specific Registers (MSRs)
    #     Table 2-2. IA-32 Architectural MSRs (Contd.)
    #       Register Address: 982H
    #       Architectural MSR Name: IA32_TME_ACTIVATE
    #       Bit Fields: 1
    #       Bit Description: Hardware Encryption Enable. This bit also enables TME-MK.
    #
    assert tdxtools.host.readmsr(0x982, 1, 1) == 1

    # Intel® Trust Domain CPU Architectural Extensions
    # IA32_SEAMRR_PHYS_BASE MSR
    # 11:11 : Enable bit for SEAMRR (SEAM Range Registers)
    assert tdxtools.host.readmsr(0x1401, 11, 11) == 1

    # Intel® Trust Domain CPU Architectural Extensions
    # IA32_TME_CAPABILITY MSR
    # 63:32 : NUM_TDX_PRIV_KEYS
    assert tdxtools.host.readmsr(0x87, 63, 32) > 16

if __name__ == '__main__':
    test_host_tdx_hardware_enabled()
