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
import time
import multiprocessing
import pytest

import Qemu
import util

def vm_teardown(max_td_vms, qm):
    try:
        # stop all machines
        for i in range(max_td_vms):
            print("Stopping machine %d" % (i))
            qm[i].shutdown()

        # wait for all machines to exit
        for i in range(max_td_vms):
            print("Waiting for machine to exit %d" % (i))
            try:
                qm[i].communicate()
            except:
                pass
    except Exception as e:
        print("Exception occured during vm cleanup: %s" % (e))

def test_stress_huge_resource_vm(qm):
    """
    Test huge resources  (Intel Case ID 007)
    """

    # choose half available memory per Intel case spec
    huge_mem_gb = int(util.get_memory_free_gb() / 2)
    num_cpus = int(multiprocessing.cpu_count() / 2)

    qm.qcmd.plugins['cpu'].nb_cores = num_cpus
    qm.qcmd.plugins['memory'].memory = '%dG' % (huge_mem_gb)
    qm.run()

    # huge guest memory -> increase the timeout to give more time to guest to boot
    ssh = Qemu.QemuSSH(qm, timeout=100)

    qm.stop()

def test_stress_memory_limit_resource_vm(qm):
    """
    Test memory limit resource  (No Intel Case)
    """

    # choose half available memory per Intel case spec
    huge_mem_gb = int(util.get_memory_available_gb())

    qm.qcmd.plugins['memory'].memory = '%dG' % (huge_mem_gb)
    qm.run()

    ssh = Qemu.QemuSSH(qm)

    qm.stop()

@pytest.xfail(reason="https://jira.devtools.intel.com/browse/SICT0-587")
def test_stress_max_vcpus(qm):
    """
    Test max vcpus (No Intel Case ID)
    """
    num_cpus = multiprocessing.cpu_count()
    if num_cpus > 255:
        num_cpus = 255 # max possible right now

    qm.qcmd.plugins['cpu'].nb_cores = num_cpus
    qm.run()

    ssh = Qemu.QemuSSH(qm, timeout=100)

    qm.stop()

def check_qemu_fail_to_start(qm, error_msg=None):
    try:
        _, err = qm.communicate(timeout=5)
    except:
        # if timeout, that means the QEMU is running fine
        # try to connect with ssh to make sure the TD is running fine
        try:
            ssh = Qemu.QemuSSH(qm)
        except:
            # the qemu is running but we cannot connect to SSH
            # we consider that the check is OK
            qm.stop()
            return
        pytest.fail('The TD is running !')
    if error_msg:
        assert error_msg in err.decode()

def test_stress_max_guests():
    """
    Test max guests (No Intel Case ID)

    There is a limit on the number of TDs that can be run in parralel.
    This limit can be due to several factors, but the most prevalent factor
    is the number of keys the CPU can allocate to TDs.
    In fact, TDX takes advantage of an existing CPU feature called MK-TME
    (Multi-key Total Memory Encryption) to encrypt the VM memory. It enables
    the CPU to encrypt each TD’s memory with a unique Advanced Encryption Standard (AES) key.
    MK-TME offers a number of keys and this key space is partionned into 2 sets:
    Shared (VMM) and Private (TDX). The number of key in the Private space defines the
    maximum number of TDs we can run in parralel.

    This test verifies that we can run TDs up to this limit and any new TD creation
    is refused by qemu in a nice way.
    """

    # get max number of TD VMs we can create (max - current)
    max_td_vms = util.get_max_td_vms() - util.get_current_td_vms()
    assert max_td_vms > 0, "No available space for TD VMs"

    print(f'The limit number of TDs is : {max_td_vms}')

    qm = [None] * max_td_vms

    try:
        # initialize machines
        for i in range(max_td_vms):
            qm[i] = Qemu.QemuMachine()

        # start machines
        for i in range(max_td_vms):
            print("Starting machine %d" % (i))
            qm[i].run()

        # wait for all machines running
        for i in range(max_td_vms):
            print("Waiting for machine %d" % (i))
            ssh = Qemu.QemuSSH(qm[i])

        # try to run a new TD
        # expect qemu quit immediately with a specific error message
        with Qemu.QemuMachine() as one_more:
            one_more.run()
            check_qemu_fail_to_start(one_more, error_msg="KVM_TDX_INIT_VM failed: No space left on device")
    except Exception as e:
        vm_teardown(max_td_vms, qm)
        pytest.fail(f"Test failed due to exception: {e}")
    finally:
        vm_teardown(max_td_vms, qm)
