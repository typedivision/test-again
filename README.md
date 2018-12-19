![test-again](test-again.png)

runs shell script functions as tests
====================================

**test-again** comes as a shell script to run functions of script files as tests
for any kind of programs.

The test script files can be run individually or in a batch format using
**test-again** as command.

**test-again** generates [TAP](http://testanything.org/) compliant output.

## test script files

The `test-again` command runs script files defining the test cases.
Test scripts have the form of this `test_script` file:
```
#!/usr/bin/env sh          # bash, dash or busybox ash

STORE=/tmp/results         # define variables like in any other shell script

t_setup () {               # optional setup, 't_' is for test-again functions
  mkdir $STORE             # if setup fails, the test will fail immediately
}

t_teardown () {            # optional teardown step, is always executed
  LOG=$STORE/$t_TEST_NAME  # given test properties also have the prefix 't_'
  cd $t_TEST_TMP           # properties are available within function bodies
  tar -cf $LOG.tar .
}

test_true () {             # the test functions follow the pattern 'test_*'
  return                   # return 0 to pass, otherwise the test fails
}

test_status_of_prog () {   # for all tests t_setup and t_teardown is called
  t_expect_status prog 0   # use t_expect_* for reasonable output on failures
  prog >"$t_TEST_TMP"/out  # temporary dir t_TEST_TMP created for each test
}

. test-again               # source test-again to run the tests
```

To run the tests, use any of
```
test-again test_script ... # run the test_script (and optionally more files)
./test_script              # run the test_script file as a single test
./test_script test_true    # run a single test function from test_script
```

The output of the `test_script` is
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
usage: test-again [-h|-l|-dkv] [-t <tmp-dir>] [<script>...]

options:

  -d  debug output (print shell traces)
  -h  print this help
  -k  keep (do not delete) the test dirs
  -l  list tests (don't run, just print)
  -t  set the tmp dir path (default ./tmp)
  -v  verbose output (print stdout)
```

## test-again functions and properties

```
t_setup                   # test setup step
t_teardown                # test teardown step

t_skip [<reason>]         # skip the test with optional reason
t_bailout [<reason>]      # abort the test execution
t_subtest <file>          # run script file as subtest

t_call [--errout] <cmd>   # run <command> and save result in
                          # t_STATUS and t_OUTPUT
                          # --errout includes stderr

t_expect_status <cmd> <status>   # compare <command> exit code with <status>
t_expect_output <cmd> <output>   # compare <command> stdout with <output>
t_expect_value '<exp>' <value>   # compare <expression> result and <value>

t_TEST_FILE               # the file name of the currently running test script
t_TEST_NAME               # the actual test name (= test function name)
t_TEST_NUM                # the actual test number
t_BASE_DIR                # the shell working dir when calling the test script
t_BASE_TMP                # a temparary test base dir under <tmp-dir>
t_TEST_TMP                # a temparary test dir under t_BASE_DIR
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

# or run a single os/shell combination
test/distributions debian /bin/dash
```

## authors

the `test-again` script is initially based on the `ts` command
by Simon Chiang http://github.com/thinkerbot/ts
