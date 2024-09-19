import os
import pytest

import Qemu
import util

@pytest.fixture(autouse=True)
def run_before_and_after_tests(tmpdir):
    """
    Fixture to execute before and after a test is run
    Even in case of test failure
    """
    # Setup: fill with any logic you want
    # enable the debug flag if TDXTEST_DEBUG is set
    debug = os.environ.get('TDXTEST_DEBUG', False)
    if debug:
        Qemu.QemuMachine.set_debug(debug)

    yield # this is where the testing happens

    # Teardown : fill with any logic you want

def pytest_exception_interact(node, call, report):
    """
    Called at test failure
    """
    if report.failed:
        # enable debug flag to avoid cleanup to happen
        Qemu.QemuMachine.set_debug(True)

@pytest.fixture()
def release_kvm_use():
    """
    Clean all running instances of qemu to release the kvm_intel driver use
    """
    Qemu.QemuMachine.stop_all_running_qemus()

@pytest.fixture()
def qm():
    """
    Fixture to create a QEMU machine as context manager
    """
    with Qemu.QemuMachine() as qm:
        yield qm

@pytest.fixture()
def cpu_core():
    """
    Fixture to create CPU core manager
    """
    cpu = util.cpu_select()
    with util.CpuOnOff(cpu) as cpu:
        yield cpu
