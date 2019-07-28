![test-again](test-again.png)

runs shell script functions as tests
====================================

**test-again** comes as a shell script to run functions of script files as tests
for any kind of programs. The test script files can be run individually or in a
batch format using **test-again** as command.

**test-again** generates [TAP](http://testanything.org/) compliant output.

## test script files

The `test-again` command runs script files defining the test cases.
Test scripts have the form of this `test_script` file:
```
#!/usr/bin/env sh          # works with bash, dash or busybox ash

LOG=/path/to/logdir        # define variables like in any other shell script

t_setup () {               # optional setup, 't_' is for test-again functions
  mkdir -p $LOG            # if setup fails, the test will fail immediately
}

t_teardown () {            # the optional teardown step is always executed
  log=$LOG/$t_TEST_NAME    # given test properties also have the prefix 't_'
  out=$t_TEST_TMP/out      # properties are available within function bodies
  if [ -e $out ]; then
    cp $out $log
  fi
}                          # for all tests, t_setup and t_teardown is called

test_pass () {             # the test functions follow the pattern 'test_*'
  return                   # return 0 to pass, otherwise the test fails
}

test_return_of_prog () {
  t_expect_ret prog 0      # use t_expect_* for reasonable output on failures
  prog >$t_TEST_TMP/out    # temporary dir t_TEST_TMP is created for each test
}

. test-again               # source test-again to run the tests
```

To run the tests, use any of
```
test-again test_script ... # run the test_script (and optionally more files)
./test_script              # run the test_script file as a single test
./test_script test_pass    # run a single test function from test_script
```

The output of the `test_script` is
```
1..2
ok 1 test_pass
ok 2 test_return_of_prog
```

And in case of `prog` fails
```
1..2
ok 1 test_pass
# expect_ret failed
#   prog
#  actual   1
#  expected 0
not ok 2 test_return_of_prog
```

## options

```
usage: test-again [-h|-l|-kvd] [-t <tmp-dir>] [<script> ...]

options:

  -h  print this help
  -l  list tests (don't run, just print)
  -k  keep (do not delete) the test dirs
  -v  verbose output (print stdout)
  -d  debug output (print shell traces)
  -t  set the tmp dir path (default ./tmp)
```

## test-again functions and properties

```
t_setup                      # test setup step called before each test
t_teardown                   # test teardown step called after each test

t_setup_once                 # setup step called once before all tests
t_teardown_once              # teardown step called once after all tests

t_skip [<reason>]            # skip the test with optional reason
t_bailout [<reason>]         # abort test execution with optional reason
t_subtest <file>             # run script file as subtest

t_call [-perr] <cmd>         # run <command> and save result in
                             # t_CALL_RET and t_CALL_OUT
                             # -perr includes stderr in t_CALL_OUT

t_expect_ret <cmd> <return>  # compare command exit code with <return>
t_expect_out <cmd> <output>  # compare command stdout with <output>
t_expect_eq '<exp>' <value>  # compare expression result and <value>

t_TEST_FILE                  # the file name of the currently running script
t_TEST_NAME                  # the actual test name (= test function name)
t_TEST_NUM                   # the actual test number
t_BASE_DIR                   # the shell working dir when calling the script
t_BASE_TMP                   # a temparary test base dir under <tmp-dir>
t_TEST_TMP                   # a temparary test dir under t_BASE_DIR
```

## development

Clone the repo and run the tests
```
test/suite
```

To run the tests for different distributions (alpine, debian) and specific shells
(bash, dash, busybox ash), start the [docker](https://www.docker.com/) test script
```
test/docker/run-suite

# or run a single os/shell combination
test/docker/run-suite debian /bin/dash
```

## authors

The `test-again` script is initially based on the `ts` command
by Simon Chiang http://github.com/thinkerbot/ts
