#!/usr/bin/env python3
#
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

import random
import string

import Qemu

# This file contains tests for the tdxattest lib in the guest
# The tdxattest library allows application to request a quote from the
# host system
# This request can be done through 2 channels:
# - vsock : the application connects directly to the QGSD service in the host
# - configfs tsm : the application use configsf tsm to ask the guest kernel
#                  to contact the QGSD service for the quote generation

def test_guest_tdxattest_tsm():
    """
    TDX attest library
    Success when only TSM is available
    vsock support is disabled by removing the configuration file and not enabling
    the vsock support in QEMU command line
    """
    with Qemu.QemuMachine() as qm:
        machine = qm.qcmd.plugins['machine']
        machine.enable_quote_socket()

        qm.run()
        ssh = Qemu.QemuSSH(qm)

        ssh.check_exec('rm -f /etc/tdx-attest.conf')
        stdout, _ = ssh.check_exec('/usr/share/doc/libtdx-attest-dev/examples/test_tdx_attest')

        assert 'Successfully get the TD Quote' in stdout.read().decode()

def test_guest_tdxattest_tsm_failure():
    """
    TDX attest library
    Failure if we force the lib to use TSM but QEMU does not have the
    quote generation socket specified.
    """
    with Qemu.QemuMachine() as qm:
        qm.run()
        ssh = Qemu.QemuSSH(qm)

        ssh.check_exec('rm -f /etc/tdx-attest.conf')

        ret, stdout, stderr = ssh.exec_command('/usr/share/doc/libtdx-attest-dev/examples/test_tdx_attest')
        assert (ret != 0) and ('Failed to get the quote' in stderr.read().decode())

def test_guest_tdxattest_vsock():
    """
    TDX attest library
    Success when only vsock is available
    ConfigFs TSM is disabled
    """
    with Qemu.QemuMachine() as qm:
        qm.qcmd.add_vsock(10)

        qm.run()
        ssh = Qemu.QemuSSH(qm)

        disable_tsm(ssh)

        stdout, _ = ssh.check_exec('/usr/share/doc/libtdx-attest-dev/examples/test_tdx_attest')

        assert 'Successfully get the TD Quote' in stdout.read().decode()

def test_guest_tdxattest_vsock_failure():
    """
    TDX attest library
    Failure if we force the lib to use vsock and QEMU does not have the
    vsock arguments specified
    """
    with Qemu.QemuMachine() as qm:
        qm.run()
        ssh = Qemu.QemuSSH(qm)

        disable_tsm(ssh)

        ret, stdout, stderr = ssh.exec_command('/usr/share/doc/libtdx-attest-dev/examples/test_tdx_attest')
        assert (ret != 0) and ('Failed to get the quote' in stderr.read().decode())

def test_guest_tdxattest_failure():
    """
    TDX attest library
    Fail when vsock and TSM are both disabled
    """
    with Qemu.QemuMachine() as qm:
        qm.run()
        ssh = Qemu.QemuSSH(qm)

        disable_tsm(ssh)
        ssh.check_exec('rm -f /etc/tdx-attest.conf')

        ret, stdout, stderr = ssh.exec_command('/usr/share/doc/libtdx-attest-dev/examples/test_tdx_attest')

        assert (ret != 0) and ('Failed to get the quote' in stderr.read().decode())

def disable_tsm(ssh):
    """
    Disable the configfs tsm
    There is no official way to disable the configfs tsm functionality
    but we can simulate configfs tsm errors by bind mounting an empty folder
    on top of the tsm folder.
    """
    tmp_folder_name=''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(4))
    ssh.check_exec(f'mkdir -p /tmp/{tmp_folder_name}')
    ssh.check_exec(f'mount --bind /tmp/{tmp_folder_name} /sys/kernel/config/tsm/report/')
