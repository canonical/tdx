## TDX Tests

This folder contains TDX tests.

### Pre-requisites

- The tests must be executed a TDX host that has been setup properly.

- The guest image must be available at the project folder with the name `tdx-guest.qcow2`
  You can follow the instructions in the project README to create one guest image.
  You can specify a path to the guest image with `TDXTEST_IMAGE_FILE` environment variable.

- The guest image must enable ssh server with password-based authentication for `root` user.
  The root user password must be `123456`

### Run tests with pytest

- Run sanity tests to check the TDX host setup:

```
$ cd tests
$ sudo ./run.sh pytest bin/test_host_*.py
```

- Run sanity tests to check the TDX guest boot:

```
$ cd tests
$ sudo ./run.sh pytest bin/test_guest_*.py bin/test_boot_*.py
```

- Run all tests except the performance ones:

```
$ cd tests
$ sudo ./run.sh pytest --ignore-glob *perf* bin/test_*.py
```

- Run all tests:

```
$ cd tests
$ sudo ./run.sh pytest bin/test_*.py
```

### Run tests with checkbox:

TODO

### TDX Tests specification

For sanity and functionality test cases of TDX, please see this [wiki](https://github.com/intel/tdx/wiki/Tests).  
