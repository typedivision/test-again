#!/usr/bin/env sh

_t_SCRIPT="${0##*/}"

# Prints usage message.
_t_usage () {
  if [ "$_t_SCRIPT" = tea.sh ]; then
    local args="[<test-file>...]"
    local examples="\
  tea.sh test_*   # run test functions of multiple test files
  test_1          # run test functions of a single test file
  test_1 fn_a     # run selected test function of the test file
"
  else
    local args="[<test-function>...]"
    local examples="\
  $_t_SCRIPT                 # run all test functions
  $_t_SCRIPT <fn_a>          # run a single test function
  $_t_SCRIPT <fn_a> <fn_b>   # run selected test functions
"
  fi
  echo "\
Run shell functions as tests.
usage: $_t_SCRIPT [-h|-l|-dikqv] [-t <tmp-dir>] $args

$examples
options:

  -d  debug output (print shell traces)
  -h  print this help
  -i  interactive stops after tests
  -k  keep (do not delete) the test dirs
  -l  list tests (don't run, just print)
  -q  quiet output (hide stderr)
  -t  set the tmp dir path (default ./tmp)
  -v  verbose output (print stdout)
"
}

while getopts "dhiklqt:v" option; do
  case "$option" in
    d) _t_OPT_DEBUG=1; _t_OPT_VERB=1 ;;
    h) _t_usage
       exit 0 ;;
    i) _t_OPT_INTERACT=1 ;;
    k) _t_OPT_KEEP_TMP=1 ;;
    l) _t_OPT_LIST=1 ;;
    q) _t_OPT_QUIET=1 ;;
    t) _t_OPT_TMP_DIR=$OPTARG ;;
    v) _t_OPT_VERB=1 ;;
    *) _t_usage | head -n 1
       exit 2 ;;
  esac
done
shift $((OPTIND - 1))

_t_TOP_DIR="$PWD"

# export command options to test file and subtest runs
export _t_TMP_DIR="${_t_OPT_TMP_DIR:-$_t_TOP_DIR/tmp}"
export _t_OPT_DEBUG="${_t_OPT_DEBUG:-}"
export _t_OPT_INTERACT="${_t_OPT_INTERACT:-}"
export _t_OPT_KEEP_TMP="${_t_OPT_KEEP_TMP:-}"
export _t_OPT_LIST="${_t_OPT_LIST:-}"
export _t_OPT_QUIET="${_t_OPT_QUIET:-}"
export _t_OPT_VERB="${_t_OPT_VERB:-}"
export _t_SUB_INDENT="${_t_SUB_INDENT:-}"

#
# private functions
#

# Prints all functions in a file starting with 'test_' or $test_pattern.
_t_list () {
  local file="$1"
  shift
  local test_pattern=$(printf "$*" | tr " " "|")
  grep -onE "^[[:space:]]*(${test_pattern:-test_\w+})[[:space:]]*\(\)" /dev/null "$file" |
  sed -e 's/^\([^:]*\):\([0-9]\{1,\}\):[[:space:]]*\([^ (]\{1,\}\).*/\3 \1:\2/'
}

# Runs a specific test.
_t_run_test () {
  if [ "$_t_OPT_VERB" ]; then
    exec 1>&2
  elif [ "$_t_OPT_QUIET" ]; then
    exec 1>/dev/null 2>/dev/null
  else
    exec 1>/dev/null
  fi
  # input /dev/null so that tests which read from stdin will not hang
  exec </dev/null

  trap 't_teardown; exit 1' EXIT
  if [ "$_t_OPT_DEBUG" ]; then
    set -eux
  else
    set -eu
  fi

  t_setup
  local exit_status=$?

  if [ $exit_status -eq 0 ]; then
    "$t_TEST_NAME"
    exit_status=$?
  fi
  trap - EXIT

  t_teardown
  return $exit_status
}

# Runs a test file or selected tests from it, when given as option.
_t_run_test_functions () {
  local test_file="$0"
  local test_case="${test_file##*/}"
  test_case="${test_case%\.*}"

  local case_dir="$_t_TMP_DIR/$test_case"
  if ! [ "$_t_OPT_LIST" ] && ! rm -rf "$case_dir"; then
    echo "error: could not clean existing test dir: $case_dir"
    exit 1
  fi

  # use fd 3>1 for tap output
  # fd 2 is stderr and stdout
  exec 3>&1

  local test_cnt=1
  local test_plan=$(_t_list "$test_file" "$@" | wc -l | xargs)
  if ! [ "$_t_OPT_LIST" ]; then
    >&3 echo "$_t_SUB_INDENT$test_cnt..$test_plan"
  fi
  _t_list "$test_file" "$@" |
  while read test_name test_desc; do
    if [ "$_t_OPT_LIST" ]; then
      >&3 echo "[$test_desc] $test_name"
      continue
    fi

    export t_TEST_NAME=$test_name
    export t_BASE_DIR="$_t_TOP_DIR"
    export t_TEST_DIR="$case_dir/$test_name"

    mkdir -p "$t_TEST_DIR"
    {
      if [ "$_t_OPT_VERB" ]; then
        echo "$test_name [$test_desc]"
      fi
      # run the test by calling back into the test file
      # use a subprocess to prevent leakage (eg set -x)
      # a zero exit status is considered a pass, otherwise fail
      (_t_run_test)
      [ $? -eq 0 ] || touch "$t_TEST_DIR"/fail

    } 2>&1 | sed "/^ *#/! s/^/$_t_SUB_INDENT# /" >&2

    if [ -e "$t_TEST_DIR"/skip ]; then
      local reason="$(cat "$t_TEST_DIR"/skip)"
      if [ "$reason" ]; then
        status="ok $test_cnt $test_name # skip $reason"
      else
        status="ok $test_cnt $test_name # skip"
      fi
    elif [ -e "$t_TEST_DIR"/fail ]; then
      status="not ok $test_cnt $test_name"
      touch "$case_dir"/fail
    else
      status="ok $test_cnt $test_name"
    fi

    >&3 echo "$_t_SUB_INDENT$status"
    test_cnt=$((test_cnt + 1))

    if [ "$_t_OPT_INTERACT" ]; then
      read x < /dev/tty
    fi
  done

  local result=0
  if [ -e "$case_dir"/fail ]; then
    result=1
  fi
  if ! [ "$_t_OPT_LIST" ] && ! [ "$_t_OPT_KEEP_TMP" ]; then
    rm -rf "$case_dir"
  fi
  return $result
}

# Runs multipe test files given as 'tea.sh' arguments.
_t_run_test_files () {
  local error
  for test_file in "$@"; do
    if [ -f "$test_file" ]; then
      if [ -x "$test_file" ]; then
        if [ "${test_file}" = "${test_file#*/}" ]; then
          ./"$test_file"
        else
          "$test_file"
        fi
      else
        echo "error: $test_file not executable"
        error=1
        continue
      fi
    else
      echo "error: $test_file not a file"
      error=1
      continue
    fi
  done
  if [ "$error" ]; then
    exit 1
  fi
}

#
# public functions
#

# Optional test setup step.
if ! type "t_setup" >/dev/null 2>&1; then
t_setup () { return; }
fi

# Optional test teardown step.
if ! type "t_teardown" >/dev/null 2>&1; then
t_teardown () { return; }
fi

# Skip this test with optional reason.
t_skip () {
  local reason="${1:-}"
  printf "$reason\n" > "$t_TEST_DIR"/skip
  exit 0
}

# Run a test file as subtest.
t_subtest () {
  _t_SUB_INDENT="    $_t_SUB_INDENT"
  1>&3 $@
}

# Helper function for expect message indention for all lines.
_inl () {
  echo "$1" | sed "s/^/  /"
}

# Assert, if status (exit code) of command is not equal to the expected output.
t_expect_status () {
  set +e
  eval "$1"
  local actual=$?
  local expect="${2:-0}"
  set -e
  if [ $actual = $expect ]; then
    return
  fi
  >&2 echo "expect_status failed"
  >&2 _inl "$1"
  >&2 echo " actual   $actual"
  >&2 echo " expected $expect"
  exit 1
}

# Assert, if std output of command is not equal to the expected output.
t_expect_output () {
  local actual="$(eval "$1")"
  local expect="$2"
  if [ "$actual" = "$expect" ]; then
    return
  fi
  >&2 echo "expect_output failed"
  >&2 _inl "$1"
  >&2 echo " actual"
  >&2 _inl "$actual"
  >&2 echo " expected"
  >&2 _inl "$expect"
  exit 1
}

# Assert, if value of expression is not equal to the expected value.
t_expect_value () {
  eval local actual="$1"
  local expect="$2"
  if [ "$actual" = "$expect" ]; then
    return
  fi
  >&2 echo "expect_value failed"
  >&2 _inl "$1"
  >&2 echo " actual"
  >&2 _inl "$actual"
  >&2 echo " expected"
  >&2 _inl "$expect"
  exit 1
}

#
# Run the given test files or this script as single suite.
#

if [ "$_t_SCRIPT" = tea.sh ]; then
  _t_run_test_files "$@"
else
  _t_run_test_functions "$@"
fi
