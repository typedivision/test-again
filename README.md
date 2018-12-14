![test-again](test-again.png)

tea.sh (test again) runs shell script functions as tests
========================================================

**tea.sh** comes as a shell script to run functions of script files as tests
for any programs. The test script files can be run individually or in a batch
format using `tea.sh` as command.

**tea.sh** generates [TAP](http://testanything.org/) compliant output.

## test script files

The `tea.sh` command runs script files defining the test cases.
Test scripts have the form of this `example_test` file:
```
#!/usr/bin/env sh          # bash, dash or busybox ash

STORE=/tmp/results         # define variables like in any other shell script

t_setup () {               # optional setup, the 't_' is for tea.sh functions
  mkdir -p $STORE          # if setup fails, the test will fail immediately
}

t_teardown () {            # optional teardown step, is always executed
  LOG=$STORE/$t_TEST_NAME  # given test properties also have the prefix '$t_'
  cd $t_TEST_TMP           # properties are available within function bodies
  tar -cf $LOG.tar .
}

test_true () {             # the test functions follow the pattern 'test_*'
  return                   # return 0 to pass, otherwise the test fails
}

test_status_of_prog () {   # every test runs as t_setup, test_*, t_teardown
  t_expect_status prog 0   # use t_expect_* for reasonable output on failures
  prog >"$t_TEST_TMP"/out  # temporary dir t_TEST_TMP created for each test
}

. tea.sh                   # source tea.sh to run the tests
```

To run the tests, use any of
```
tea.sh example_test [...]  # run the example_test (and optionally more files)
./example_test             # run the example_test file as a single test
./example_test test_true   # run a single test function from example_test
```

The output of the `example_test` is
```
1..2
ok 1 test_true
ok 2 test_status_of_prog
```

And in case of prog fails
```
1..2
ok 1 test_true
# expect_status failed
#   prog
#  actual   1
#  expected 0
not ok 2 test_status_of_prog
```

## options

```
usage: tea.sh [-h|-l|-dikv] [-t <tmp-dir>] [<test-file>...]

options:

  -d  debug output (print shell traces)
  -h  print this help
  -i  interactive stops after tests
  -k  keep (do not delete) the test dirs
  -l  list tests (don't run, just print)
  -t  set the tmp dir path (default ./tmp)
  -v  verbose output (print stdout)
```

## tea.sh functions and properties

```
t_setup                # test setup step
t_teardown             # test teardown step

t_skip [<reason>]      # skip the test with optional reason
t_bailout [<reason>]   # abort the test execution
t_subtest <file>       # run script file as subtest

t_call <cmd>           # run <command> and save result in
                       # t_STATUS and t_OUTPUT

t_expect_status <cmd> <status>   # compare <command> exit code with <status>
t_expect_output <cmd> <output>   # compare <command> stdout with <output>
t_expect_value '<exp>' <value>   # compare <expression> and <value>

t_TEST_FILE            # the file name of the currently running test
t_TEST_NAME            # the actual test name (= test function name)
t_BASE_DIR             # the shell working dir when calling the test script
t_BASE_TMP             # a temparary test base dir under <tmp-dir>
t_TEST_TMP             # a temparary test dir under t_BASE_DIR
```

## development

Clone the repo and run the tests
```
test/suite
```

To run the tests for different distributions (alpine, debian) and specific shells
(bash, dash, busybox as), start the [docker](https://www.docker.com/) test
```
test/distributions
```

## authors

the `tea.sh` script is based on the `ts` command
by Simon Chiang http://github.com/thinkerbot/ts
