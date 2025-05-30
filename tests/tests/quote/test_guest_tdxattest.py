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
import pytest
import subprocess
import Qemu

# This file contains tests for the tdxattest lib in the guest
# The tdxattest library allows application to request a quote from the
# host system
# This request can be done through 2 channels:
# - vsock : the application connects directly to the QGSD service in the host
# - configfs tsm : the application use configsf tsm to ask the guest kernel
#                  to contact the QGSD service for the quote generation
def change_qgsd_state(state):
    cmd = ['systemctl', state, 'qgsd']
    rc = subprocess.run(cmd, stderr=subprocess.STDOUT, timeout=30)
    assert 0 == rc.returncode, 'Failed change state of qgsd'

@pytest.mark.quote_generation
@pytest.mark.xfail(reason="https://jira.devtools.intel.com/browse/SICT0-580")
def test_guest_tdxattest_tsm():
    """
    TDX attest library
    Success when only TSM is available
    vsock support is disabled by removing the configuration file and not enabling
    the vsock support in QEMU command line
    """
    with Qemu.QemuMachine() as qm:
        machine = qm.qcmd.plugins['machine']
        machine.enable_qgs_addr()

        qm.run()
        ssh = Qemu.QemuSSH(qm)

        change_qgsd_state('start')
        # ssh.check_exec('rm -f /etc/tdx-attest.conf')
        ssh.check_exec('cd /opt/intel/tdx-quote-generation-sample/ && make clean && make')
        stdout, _ = ssh.check_exec('cd /opt/intel/tdx-quote-generation-sample/ && ./test_tdx_attest')

        assert 'Successfully get the TD Quote' in stdout.read().decode()

@pytest.mark.quote_generation
@pytest.mark.xfail(reason="https://jira.devtools.intel.com/browse/SICT0-580")
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
        ssh.check_exec('cd /opt/intel/tdx-quote-generation-sample/ && make clean && make')
        ret, stdout, stderr = ssh.exec_command('cd /opt/intel/tdx-quote-generation-sample/ && ./test_tdx_attest')

        assert (ret != 0) and ('Failed to get the quote' in stderr.read().decode())

@pytest.mark.quote_generation
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

        ssh.check_exec('cd /opt/intel/tdx-quote-generation-sample/ && make clean && make')
        ret, stdout, stderr = ssh.exec_command('cd /opt/intel/tdx-quote-generation-sample/ && ./test_tdx_attest')

        assert 'Successfully get the TD Quote' in stdout.read().decode()

@pytest.mark.quote_generation
@pytest.mark.xfail(reason="https://jira.devtools.intel.com/browse/SICT0-580")
def test_guest_tdxattest_vsock_wrong_qgs_addr(qm):
    """
    Success even when QGS address is not properly configured
    Test setup:
    - the qgs addr is not properly configured by using CID=3 instead of 2
      (the configfs tsm method should fail however)
    - vsock is enabled for the guest
    Expected behavior:
    The quote generation request should succeed because
    vsock is enabled and tdxattest should fallback to use vsock
    """
    qm.qcmd.add_vsock(10)

    machine = qm.qcmd.plugins['machine']
    machine.enable_qgs_addr(addr = {'type': 'vsock', 'cid':'3','port':'4050'})

    qm.run()
    ssh = Qemu.QemuSSH(qm)

    ssh.check_exec('cd /opt/intel/tdx-quote-generation-sample/ && make clean && make')
    ret, stdout, stderr = ssh.exec_command('cd /opt/intel/tdx-quote-generation-sample/ && ./test_tdx_attest')

    assert 'Successfully get the TD Quote' in stdout.read().decode()

@pytest.mark.quote_generation
@pytest.mark.xfail(reason="https://jira.devtools.intel.com/browse/SICT0-580")
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

        ssh.check_exec('cd /opt/intel/tdx-quote-generation-sample/ && make clean && make')
        ret, stdout, stderr = ssh.exec_command('cd /opt/intel/tdx-quote-generation-sample/ && ./test_tdx_attest')

        assert (ret != 0) and ('Failed to get the quote' in stderr.read().decode())

@pytest.mark.quote_generation
@pytest.mark.xfail(reason="https://jira.devtools.intel.com/browse/SICT0-580")
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

        ssh.check_exec('cd /opt/intel/tdx-quote-generation-sample/ && make clean && make')
        ret, stdout, stderr = ssh.exec_command('cd /opt/intel/tdx-quote-generation-sample/ && ./test_tdx_attest')

        assert (ret != 0) and ('Failed to get the quote' in stderr.read().decode())

@pytest.mark.quote_generation
@pytest.mark.xfail(reason="https://jira.devtools.intel.com/browse/SICT0-580")
def test_guest_tdxattest_failure_1(qm):
    """
    Failure when vsock disabled and QGS addr is not properly configured
    Test setup:
    - the qgs addr is not properly configured by using CID=3 instead of 2
      (the configfs tsm method should fail however)
    - vsock is not enabled for the guest
    Expected behavior:
    The quote generation request should fail
    """
    machine = qm.qcmd.plugins['machine']
    machine.enable_qgs_addr(addr = {'type': 'vsock', 'cid':'3','port':'4050'})

    qm.run()
    ssh = Qemu.QemuSSH(qm)

    ssh.check_exec('cd /opt/intel/tdx-quote-generation-sample/ && make clean && make')
    ret, stdout, stderr = ssh.exec_command('cd /opt/intel/tdx-quote-generation-sample/ && ./test_tdx_attest')

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
