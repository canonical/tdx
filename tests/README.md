## Intel TDX Tests

This folder contains Intel TDX tests.

### Pre-requisites

- The tests must be executed a host that has been setup properly for Intel TDX.

- Tox must be installed along with python3:
```
$ sudo apt install tox
$ sudo apt install python3
```

- You must specify a path to the guest image with `TDXTEST_GUEST_IMG` environment variable.
  This is for both pytest and checkbox tests.

- The guest image must enable ssh server with password-based authentication for `root` user.
  The root user password must be `123456`

### Run tests with pytest

Go to the `tests` folder.

- Run sanity tests to check the host setup:

```
$ sudo tox -e test_host
```

- Run guest tests:

```
$ sudo tox -e test_guest
```

- Run boot tests:

```
$ sudo tox -e test_boot
```

- Run perf tests:

```
$ sudo tox -e test_perf
```

- Run quote tests:

```
$ sudo tox -e test_quote
```

- Run stress tests:

```
$ sudo tox -e test_stress
```

- Run all tests:

Please note that the performance tests can take a long time (order of magnitude of a few hours per `pytest.test_perf_benchmark`) to run.

```
$ sudo tox -e test_all
```

### Run tests with checkbox:

Go to the `tests` folder.

```
$ snapcraft
$ sudo snap install ./checkbox-tdx-classic_2.0_amd64.snap --dangerous --classic
```

- Run sanity tests to check the host setup:

```
$ sudo -E checkbox-tdx-classic.test-runner-automated-host
```

- Run guest tests:

```
$ sudo -E checkbox-tdx-classic.test-runner-automated-guest
```

- Run boot tests:

```
$ sudo -E checkbox-tdx-classic.test-runner-automated-boot
```

- Run perf tests:

```
$ sudo -E checkbox-tdx-classic.test-runner-automated-perf
```

- Run quote tests:

```
$ sudo -E checkbox-tdx-classic.test-runner-automated-quote
```

- Run stress tests:

```
$ sudo -E checkbox-tdx-classic.test-runner-automated-stress
```

- Run all tests:

Please note that the performance tests can take a long time to run.

```
$ sudo -E checkbox-tdx-classic.test-runner-automated
```


### Intel TDX Tests specification

For sanity and functionality test cases of Intel TDX, please see this [wiki](https://github.com/intel/tdx/wiki/Tests).
