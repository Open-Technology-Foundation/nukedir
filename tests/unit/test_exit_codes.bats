#!/usr/bin/env bats
# Unit tests for canonical BCS0602 exit codes
# Guards against regression of exit-code semantics:
#   5  = ERR_IO         (I/O failure, e.g. cannot create tempdir)
#   8  = ERR_REQUIRED   (required arg/dir missing)
#   9  = ERR_RANGE      (value out of range, e.g. ionice 0-3)
#   13 = ERR_ACCESS     (permission denied)
#   18 = ERR_NODEP      (missing dependency)
#   21 = ERR_STATE      (invalid precondition, e.g. cwd is /, target is mount)
#   22 = ERR_INVAL      (invalid argument, e.g. nuke_dir is /)

load '../helpers/test_helpers'

setup() {
  common_setup
}

teardown() {
  common_teardown
}

@test "exit 8 when no directory is specified" {
  run sudo "$NUKEDIR_SCRIPT" --dryrun
  assert_exit_code 8
  assert_output_contains "No directory specified"
}

@test "exit 8 when -i option is missing its argument" {
  run sudo "$NUKEDIR_SCRIPT" -i
  assert_exit_code 8
  assert_output_contains "requires an argument"
}

@test "exit 8 when -T option is missing its argument" {
  run sudo "$NUKEDIR_SCRIPT" -T
  assert_exit_code 8
  assert_output_contains "requires an argument"
}

@test "exit 8 when --ionice is missing its argument" {
  run sudo "$NUKEDIR_SCRIPT" --ionice
  assert_exit_code 8
}

@test "exit 8 when --timeout is missing its argument" {
  run sudo "$NUKEDIR_SCRIPT" --timeout
  assert_exit_code 8
}

@test "exit 9 when ionice value exceeds valid range (4)" {
  local -- test_dir
  test_dir=$(create_test_dir "ionice_range_high" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n -i 4 "$test_dir"
  assert_exit_code 9
  assert_output_contains "Invalid ionice priority"
}

@test "negative ionice value fails early (noarg intercepts)" {
  local -- test_dir
  test_dir=$(create_test_dir "ionice_negative" 5 1)

  # `-i -1`: the `-1` argument begins with `-`, so noarg() treats the option
  # as missing its argument (exit 8). Negative values cannot reach the range
  # check on the current CLI — by design, since option arguments cannot start
  # with `-`.
  run sudo "$NUKEDIR_SCRIPT" -n -i -1 "$test_dir"
  assert_exit_code 8
  assert_output_contains "requires an argument"
}

@test "exit 21 when executing from root directory" {
  run sudo bash -c "cd / && '$NUKEDIR_SCRIPT' -n /tmp/some-test-dir"
  assert_exit_code 21
  assert_output_contains "Cannot execute from root directory"
}

@test "exit 22 when target directory is /" {
  run sudo "$NUKEDIR_SCRIPT" -n /
  assert_exit_code 22
  assert_output_contains "ROOT directory CANNOT be specified"
}

@test "exit 22 on unrecognized long option" {
  run sudo "$NUKEDIR_SCRIPT" --bogus-flag-never-exists
  assert_exit_code 22
  assert_output_contains "Invalid option"
}

@test "exit 22 on unrecognized short option" {
  run sudo "$NUKEDIR_SCRIPT" -Z
  assert_exit_code 22
  assert_output_contains "Invalid option"
}

@test "exit 21 when target is a mount point" {
  # Require a known mount point for this test
  if ! is_mount_point /proc; then
    skip "/proc is not a mount point on this system"
  fi

  run sudo "$NUKEDIR_SCRIPT" -n /proc
  assert_exit_code 21
  assert_output_contains "Cannot delete a mount point"
}

@test "exit 0 on --version" {
  run sudo "$NUKEDIR_SCRIPT" --version
  assert_exit_code 0
}

@test "exit 0 on --help" {
  run sudo "$NUKEDIR_SCRIPT" --help
  assert_exit_code 0
}

@test "exit 0 on valid dryrun" {
  local -- test_dir
  test_dir=$(create_test_dir "valid_dryrun_exit" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n "$test_dir"
  assert_exit_code 0
}
