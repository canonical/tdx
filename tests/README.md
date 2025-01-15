## Intel TDX Tests

This folder contains Intel TDX tests.

### Pre-requisites

- The tests must be executed on a host that has been set up properly for Intel TDX.

### Run tests

The script `tdtest` is the test runner, it is a wrapper around `pytest`.
Please run `tdtest -h` for more details about its usage.

The tests are organized in different categories and this organization is
reflected in the structure of the `tests`.

You can choose to run a category of tests by specifying the appropriate sudirectory under `tests`. For example, to run the boot tests:

```
$ sudo ./tdtest tests/boot
```

You can run all tests except the performance:

```
$ sudo ./tdtest -k 'not test_perf'
```

Since `tdtest` is a wrapper of pytest, it exposes all the features of `pytest`
that you can use to run, manage and inspect the tests.

### Run tests with checkbox:

Go to the `tests` folder.

```
$ snapcraft
$ sudo snap install ./checkbox-tdx_1.0.0_amd64.snap --dangerous --classic
```

- Run sanity tests to check the host setup:

```
$ checkbox-tdx.test-runner-automated-host
```

- Run guest tests:

```
$ checkbox-tdx.test-runner-automated-guest
```

- Run boot tests:

```
$ checkbox-tdx.test-runner-automated-boot
```

- Run perf tests:

```
$ checkbox-tdx.test-runner-automated-perf
```

- Run quote tests:

```
$ checkbox-tdx.test-runner-automated-quote
```

- Run stress tests:

```
$ checkbox-tdx.test-runner-automated-stress
```

- Run all tests:

Please note that the performance tests can take a long time to run.

```
$ checkbox-tdx.test-runner-automated
```


### Intel TDX Tests specification

For sanity and functionality test cases of Intel TDX, please see this [wiki](https://github.com/intel/tdx/wiki/Tests).
