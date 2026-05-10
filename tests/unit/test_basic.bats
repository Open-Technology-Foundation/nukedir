#!/usr/bin/env bats
# Unit tests for basic nukedir functionality
# Tests version, help, and basic option parsing

load '../helpers/test_helpers'

setup() {
  common_setup
}

teardown() {
  common_teardown
}

@test "nukedir script exists and is executable" {
  [[ -x "$NUKEDIR_SCRIPT" ]]
}

@test "nukedir --version displays version number" {
  run sudo "$NUKEDIR_SCRIPT" --version
  assert_success
  assert_output_contains "nukedir"
  # Match any semver — avoids drift when VERSION is bumped
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "nukedir -V displays version number (short form)" {
  run sudo "$NUKEDIR_SCRIPT" -V
  assert_success
  assert_output_contains "nukedir"
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "nukedir --help displays usage information" {
  run sudo "$NUKEDIR_SCRIPT" --help
  assert_success
  assert_output_contains "Usage:"
  assert_output_contains "Options:"
  assert_output_contains "Examples:"
}

@test "nukedir -h displays help (short form)" {
  run sudo "$NUKEDIR_SCRIPT" -h
  assert_success
  assert_output_contains "Usage:"
}

@test "nukedir with no arguments shows error" {
  run sudo "$NUKEDIR_SCRIPT"
  assert_failure
  assert_output_contains "No directory specified"
}

@test "nukedir with invalid option shows error" {
  run sudo "$NUKEDIR_SCRIPT" --invalid-option
  assert_failure
  assert_output_contains "Invalid option"
}

@test "nukedir -n (dryrun short form) is recognized" {
  local -- test_dir
  test_dir=$(create_test_dir "dryrun_test" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n "$test_dir"
  assert_success
  assert_output_contains "DRY_RUN"
}

@test "nukedir --dryrun is default mode" {
  local -- test_dir
  test_dir=$(create_test_dir "default_dryrun" 5 1)

  run sudo "$NUKEDIR_SCRIPT" "$test_dir"
  assert_success
  assert_output_contains "DRY_RUN"

  # Verify directory still exists
  [[ -d "$test_dir" ]]
}

@test "nukedir -v enables verbose mode" {
  local -- test_dir
  test_dir=$(create_test_dir "verbose_test" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -v -n "$test_dir"
  assert_success
  # Verbose is default, so this should work
  assert_output_contains "◉"
}

@test "nukedir -q enables quiet mode" {
  local -- test_dir
  test_dir=$(create_test_dir "quiet_test" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -q -n "$test_dir"
  assert_success
  # In quiet mode, should have minimal output
}

@test "nukedir detects missing argument for -i option" {
  run sudo "$NUKEDIR_SCRIPT" -i
  assert_failure
  assert_output_contains "requires an argument"
}

@test "nukedir detects missing argument for -T option" {
  run sudo "$NUKEDIR_SCRIPT" -T
  assert_failure
  assert_output_contains "requires an argument"
}

@test "nukedir accepts valid ionice level 0" {
  local -- test_dir
  test_dir=$(create_test_dir "ionice_0" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n -i 0 "$test_dir"
  assert_success
}

@test "nukedir accepts valid ionice level 1" {
  skip_if_no_ionice

  local -- test_dir
  test_dir=$(create_test_dir "ionice_1" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n -i 1 "$test_dir"
  assert_success
}

@test "nukedir accepts valid ionice level 3" {
  skip_if_no_ionice

  local -- test_dir
  test_dir=$(create_test_dir "ionice_3" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n -i 3 "$test_dir"
  assert_success
}

@test "nukedir rejects invalid ionice level 4" {
  local -- test_dir
  test_dir=$(create_test_dir "ionice_invalid" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n -i 4 "$test_dir"
  assert_failure
  assert_output_contains "Invalid ionice priority"
}

@test "nukedir rejects invalid ionice level -1" {
  local -- test_dir
  test_dir=$(create_test_dir "ionice_negative" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n -i -1 "$test_dir"
  assert_failure
}

@test "nukedir accepts timeout format with minutes" {
  local -- test_dir
  test_dir=$(create_test_dir "timeout_m" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n -T 2m "$test_dir"
  assert_success
}

@test "nukedir accepts timeout format with hours" {
  local -- test_dir
  test_dir=$(create_test_dir "timeout_h" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n -T 4h "$test_dir"
  assert_success
}

@test "nukedir output contains standard icons" {
  local -- test_dir
  test_dir=$(create_test_dir "icons_test" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n "$test_dir"
  assert_success

  # Check for at least one standard icon
  [[ "$output" =~ ◉|▲|✓|✗ ]]
}

@test "nukedir aggregated short options work (-nv)" {
  local -- test_dir
  test_dir=$(create_test_dir "aggregated_options" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -nv "$test_dir"
  assert_success
}

@test "nukedir aggregated short options work (-qn)" {
  local -- test_dir
  test_dir=$(create_test_dir "aggregated_quiet" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -qn "$test_dir"
  assert_success
}

@test "nukedir combined short options with trailing arg-taking option (-nri 1)" {
  # The combined-flag splitter on line 149 must correctly split -nri 1 into
  # -n -r -i 1. This covers the arg-taking option (-i) at the end of the group.
  skip_if_no_ionice

  local -- test_dir
  test_dir=$(create_test_dir "combined_with_arg" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -nri 1 "$test_dir"
  assert_success
  assert_output_contains "DRY_RUN"
  # Verify both ionice AND rsync verbose took effect
  assert_output_contains "-avn"
  assert_output_contains "ionice"
}

@test "nukedir -- marks end of options" {
  local -- test_dir
  test_dir=$(create_test_dir "end_of_options" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n -- "$test_dir"
  assert_success
  assert_output_contains "$test_dir"
  assert_output_contains "DRY_RUN"
}

@test "nukedir -- allows dash-prefixed directory names" {
  local -- test_dir="$TEST_TEMP_DIR/-weird-prefix"
  mkdir -p "$test_dir"
  echo "content" > "$test_dir/file.txt"

  run sudo "$NUKEDIR_SCRIPT" -n -- "$test_dir"
  assert_success
  assert_output_contains "$test_dir"
}

@test "nukedir RSYNC_WAIT_SECONDS env var is consumed" {
  # The default is 60s, but we just need to verify the var is readable.
  # The value is only used inside the --wait-for-rsync loop, which we cannot
  # easily trigger without a live rsync. But we can confirm the script starts
  # cleanly with a custom value set.
  local -- test_dir
  test_dir=$(create_test_dir "rsync_wait_env" 3 1)

  run sudo RSYNC_WAIT_SECONDS=5 "$NUKEDIR_SCRIPT" -n "$test_dir"
  assert_success
}
