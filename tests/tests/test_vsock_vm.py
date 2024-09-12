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

import os
import subprocess
import threading
import time

import Qemu

# Global Variables
script_path=os.path.dirname(os.path.realpath(__file__))
guest_cid=25

# Helper Functions

def run_iperf_server_on_host():
    cmd = [f'{script_path}/../iperf/iperf-vsock-3.9', '--vsock', '-s', '-1']
    subprocess.run(cmd, stderr=subprocess.STDOUT, timeout=30)


def run_iperf_server_on_guest(ssh):
    cmd = '/tmp/iperf/iperf-vsock-3.9 --vsock -s -1'
    stdout, stderr = ssh.check_exec(cmd)


# Tests

def test_vsock_vm_client():
    """
    vsock vm guest client and host as server (Intel Case ID: 028)
    """
    qm = Qemu.QemuMachine()
    qm.qcmd.add_vsock(guest_cid)
    qm.run()

    ssh = Qemu.QemuSSH(qm)
    ssh.rsync_file(f'{script_path}/../iperf', '/tmp/')

    t = threading.Thread(target=run_iperf_server_on_host)
    t.start()

    cmd = '/tmp/iperf/iperf-vsock-3.9 --vsock -c 2'
    stdout, stderr = ssh.check_exec(cmd)
    assert 0 == stdout.channel.recv_exit_status(), 'Failed iperf server on client test'

    t.join(timeout=30.0)
    qm.stop()


def test_vsock_vm_server():
    """
    vsock vm guest server and host as client (Intel Case ID: 027)
    """
    qm = Qemu.QemuMachine()
    qm.qcmd.add_vsock(guest_cid)
    qm.run()

    ssh = Qemu.QemuSSH(qm)
    ssh.rsync_file(f'{script_path}/../iperf', '/tmp/')

    t = threading.Thread(target=run_iperf_server_on_guest, args=(ssh,))
    t.start()

    # Give time to iperf server to start
    time.sleep(1)

    cmd = [f'{script_path}/../iperf/iperf-vsock-3.9', '--vsock', '-c', '%d' % (guest_cid)]
    rc = subprocess.run(cmd, stderr=subprocess.STDOUT, timeout=30)
    assert 0 == rc.returncode, 'Failed iperf server on guest test'

    t.join(timeout=30.0)
    qm.stop()
