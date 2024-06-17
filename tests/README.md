## Intel TDX Tests

This folder contains Intel TDX tests.

### Pre-requisites

- The tests must be executed a host that has been setup properly for Intel TDX.

- The guest image must be available at the project folder with the name `tdx-guest.qcow2`
  You can follow the instructions in the project README to create one guest image.
  You can specify a path to the guest image with `TDXTEST_IMAGE_FILE` environment variable.

- The guest image must enable ssh server with password-based authentication for `root` user.
  The root user password must be `123456`

### Run tests with pytest

Go to the `tests` folder.

- Run sanity tests to check the host setup:

```
$ sudo ./run.sh pytest pytest/test_host_*.py
```

- Run sanity tests to check the guest boot:

```
$ sudo ./run.sh pytest pytest/test_guest_*.py bin/test_boot_*.py
```

- Run all tests except the performance and stress ones:

```
$ sudo ./run.sh pytest --ignore-glob="pytest/guest/" --ignore-glob="*test_perf*" --ignore-glob="*test_stress*" pytest/
```

- Run all tests:

Please note that the performance tests can take a long time (order of magnitude of a few hours per `pytest.test_perf_benchmark`) to run.

```
$ sudo ./run.sh pytest pytest/test_*.py
```

#### Example test `report.xml` ####

For INTEL(R) XEON(R) PLATINUM 8570, with 224 CPUs, running in Intel's SDP:

```xml
<?xml version="1.0" encoding="utf-8"?>
<testsuites>
    <testsuite name="pytest" errors="0" failures="0" skipped="0" tests="23" time="30914.770" timestamp="2024-06-12T04:35:25.801200" hostname="sdp">
        <testcase classname="pytest.test_host_tdx_hardware" name="test_host_tdx_hardware_enabled" time="0.001" />
        <testcase classname="pytest.test_host_tdx_software" name="test_host_tdx_software" time="0.011" />
        <testcase classname="pytest.test_boot_basic" name="test_guest_boot" time="102.168" />
        <testcase classname="pytest.test_boot_coexist" name="test_coexist_boot" time="5.650" />
        <testcase classname="pytest.test_boot_multiple_vms" name="test_multiple_vms" time="25.068" />
        <testcase classname="pytest.test_boot_td_creation" name="test_create_td_without_ovmf" time="0.432" />
        <testcase classname="pytest.test_guest_eventlog" name="test_guest_eventlog" time="106.441" />
        <testcase classname="pytest.test_guest_eventlog" name="test_guest_eventlog_initrd" time="101.572" />
        <testcase classname="pytest.test_guest_measurement" name="test_guest_measurement_check_rtmr" time="102.928" />
        <testcase classname="pytest.test_guest_reboot" name="test_guest_reboot" time="207.524" />
        <testcase classname="pytest.test_guest_report" name="test_guest_report" time="107.273" />
        <testcase classname="pytest.test_host_tdx_hardware" name="test_host_tdx_hardware_enabled" time="0.001" />
        <testcase classname="pytest.test_host_tdx_software" name="test_host_tdx_software" time="0.012" />
        <testcase classname="pytest.test_perf_benchmark" name="test_run_perf_0_normal" time="11124.133" />
        <testcase classname="pytest.test_perf_benchmark" name="test_run_perf_1_td" time="14106.958" />
        <testcase classname="pytest.test_perf_boot_time" name="test_boot_time_0_normal" time="18.120" />
        <testcase classname="pytest.test_perf_boot_time" name="test_boot_time_1_td" time="40.882" />
        <testcase classname="pytest.test_perf_boot_time" name="test_boot_time_2_normal_16G" time="17.444" />
        <testcase classname="pytest.test_perf_boot_time" name="test_boot_time_3_td_16G" time="56.652" />
        <testcase classname="pytest.test_perf_boot_time" name="test_boot_time_4_normal_64G" time="17.471" />
        <testcase classname="pytest.test_perf_boot_time" name="test_boot_time_5_td_64G" time="57.457" />
        <testcase classname="pytest.test_quote_configfs_tsm" name="test_quote_check_configfs_tsm" time="92.785" />
        <testcase classname="pytest.test_stress_boot" name="test_boot" time="4623.619" />
    </testsuite>
</testsuites>
```

### Run tests with checkbox:

TODO

### Intel TDX Tests specification

For sanity and functionality test cases of Intel TDX, please see this [wiki](https://github.com/intel/tdx/wiki/Tests).
