import os
import pytest
import distro
import subprocess

import Qemu
import util

script_path=os.path.dirname(os.path.realpath(__file__))

# Is platform registered for quote generation
def is_platform_registered():
    try:
        subprocess.check_call([f'{script_path}/../../attestation/check-registration.sh'])
    except:
        return False
    return True

def pytest_runtest_setup(item):
    """
    Test setup function
    """
    # skip the test if needed
    for mark in item.iter_markers(name='quote_generation'):
        if not is_platform_registered():
            pytest.skip('Platform not registered, skip quote generation test')

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

@pytest.fixture()
def tdx_version():
    """
    This fixure gives the generation of TDX releases we deliver
    For now, we devide our releases into 2 major versions:
    - 1 (TDX1.0) : for releases with kernel < 6.14 and QEMU < 9.2.1
                   this version has been released Ubuntu 24.04 and 24.10
    - 2 (TDX2.0) : for kernel >= 6.14 and qemu >= 9.2.1
                   this version is released for Ubuntu 25.04
    Default version is TDX2.0 if the fixture cannot determine the version.
    """
    version=2
    # try to detect version 1
    lri = distro.lsb_release_info()
    if (lri.get('codename') == 'noble') or (lri.get('codename') == 'oracular'):
        version = 1
    yield version
