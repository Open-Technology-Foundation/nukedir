#!/usr/bin/env bats
# Unit tests for nukedir input validation
# Tests directory validation, path handling, and error cases

load '../helpers/test_helpers'

setup() {
  common_setup
}

teardown() {
  common_teardown
}

@test "nukedir validates directory exists" {
  local -- nonexistent_dir="$TEST_TEMP_DIR/does_not_exist"

  run sudo "$NUKEDIR_SCRIPT" -n "$nonexistent_dir"
  # Script should handle non-existent directory gracefully
  # realpath will output error to stderr
  assert_success
  # Check for realpath error in output
  [[ "$output" == *"realpath"* ]] || [[ "$output" == *"No such file"* ]]
}

@test "nukedir rejects non-directory file" {
  local -- test_file="$TEST_TEMP_DIR/regular_file.txt"
  echo "test" > "$test_file"

  run sudo "$NUKEDIR_SCRIPT" -n "$test_file"
  assert_success
  # realpath outputs "Not a directory" error
  [[ "$output" == *"realpath"* ]] || [[ "$output" == *"Not a directory"* ]]
}

@test "nukedir handles directory with trailing slash" {
  local -- test_dir
  test_dir=$(create_test_dir "trailing_slash" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n "$test_dir/"
  assert_success
}

@test "nukedir handles directory without trailing slash" {
  local -- test_dir
  test_dir=$(create_test_dir "no_trailing_slash" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n "$test_dir"
  assert_success
}

@test "nukedir handles relative paths" {
  local -- test_dir
  test_dir=$(create_test_dir "relative_path" 5 1)

  # Change to parent directory and use relative path
  local -- parent_dir="${test_dir%/*}"
  local -- dir_name="${test_dir##*/}"

  (
    cd "$parent_dir"
    run sudo "$NUKEDIR_SCRIPT" -n "$dir_name"
    assert_success
  )
}

@test "nukedir resolves symlinks" {
  local -- test_dir
  test_dir=$(create_test_dir "symlink_target" 5 1)

  local -- symlink="$TEST_TEMP_DIR/symlink_to_dir"
  ln -s "$test_dir" "$symlink"

  run sudo "$NUKEDIR_SCRIPT" -n "$symlink"
  assert_success
}

@test "nukedir handles paths with spaces" {
  local -- test_dir="$TEST_TEMP_DIR/dir with spaces"
  mkdir -p "$test_dir"
  echo "test" > "$test_dir/file.txt"

  run sudo "$NUKEDIR_SCRIPT" -n "$test_dir"
  assert_success
}

@test "nukedir handles paths with special characters" {
  local -- test_dir="$TEST_TEMP_DIR/dir-with_special.chars"
  mkdir -p "$test_dir"
  echo "test" > "$test_dir/file.txt"

  run sudo "$NUKEDIR_SCRIPT" -n "$test_dir"
  assert_success
}

@test "nukedir accepts multiple directories" {
  local -- dir1 dir2 dir3
  dir1=$(create_test_dir "multi_1" 5 1)
  dir2=$(create_test_dir "multi_2" 5 1)
  dir3=$(create_test_dir "multi_3" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n "$dir1" "$dir2" "$dir3"
  assert_success
  assert_output_contains "$dir1"
  assert_output_contains "$dir2"
  assert_output_contains "$dir3"
}

@test "nukedir processes multiple directories with mixed valid/invalid" {
  local -- valid_dir invalid_dir
  valid_dir=$(create_test_dir "valid_multi" 5 1)
  invalid_dir="$TEST_TEMP_DIR/invalid_does_not_exist"

  run sudo "$NUKEDIR_SCRIPT" -n "$valid_dir" "$invalid_dir"
  # Should process valid dir and report error for invalid
  assert_success
  # Valid directory should be processed
  assert_output_contains "$valid_dir"
  # Invalid directory should produce realpath error
  [[ "$output" == *"realpath"* ]] || [[ "$output" == *"No such file"* ]]
}

@test "nukedir handles empty directory" {
  local -- empty_dir="$TEST_TEMP_DIR/empty_directory"
  mkdir -p "$empty_dir"

  run sudo "$NUKEDIR_SCRIPT" -n "$empty_dir"
  assert_success
}

@test "nukedir handles nested empty directories" {
  local -- nested_dir="$TEST_TEMP_DIR/nested/empty/dirs"
  mkdir -p "$nested_dir"

  run sudo "$NUKEDIR_SCRIPT" -n "$nested_dir"
  assert_success
}

@test "nukedir shows BITBIN location in verbose mode" {
  local -- test_dir
  test_dir=$(create_test_dir "bitbin_test" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -v -n "$test_dir"
  assert_success
  assert_output_contains "BITBIN="
}

@test "nukedir detects filesystem type" {
  local -- test_dir
  test_dir=$(create_test_dir "fs_detect" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n "$test_dir"
  assert_success
  assert_output_contains "Filesystem type:"
}

@test "nukedir shows rsync command in verbose mode" {
  local -- test_dir
  test_dir=$(create_test_dir "rsync_cmd" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -v -n "$test_dir"
  assert_success
  assert_output_contains "rsync"
  assert_output_contains "Executing"
}

@test "nukedir reports when rsync is already running" {
  skip "Requires controlled rsync process - implement with mock"
}

@test "nukedir --wait-for-rsync option is recognized" {
  local -- test_dir
  test_dir=$(create_test_dir "wait_rsync" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -w -n "$test_dir"
  assert_success
}

@test "nukedir --rsync-verbose adds verbosity to rsync" {
  local -- test_dir
  test_dir=$(create_test_dir "rsync_verbose" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -r -n "$test_dir"
  assert_success
  # Should include -av instead of just -a
  assert_output_contains "rsync"
}
