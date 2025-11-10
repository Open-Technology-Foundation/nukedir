#!/usr/bin/env bats
# Unit tests for filesystem detection and optimization
# Tests filesystem-specific rsync options

load '../helpers/test_helpers'

setup() {
  common_setup
}

teardown() {
  common_teardown
}

@test "nukedir detects current filesystem type" {
  local -- test_dir
  test_dir=$(create_test_dir "fs_type" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -n "$test_dir"
  assert_success
  assert_output_contains "Filesystem type:"

  # Should show one of the common filesystem types
  [[ "$output" =~ ext4|xfs|btrfs|tmpfs|zfs ]] || {
    # Or any other valid filesystem
    [[ "$output" =~ "Filesystem type:" ]]
  }
}

@test "nukedir shows filesystem-specific optimization message" {
  local -- test_dir
  test_dir=$(create_test_dir "fs_optimization" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -v -n "$test_dir"
  assert_success

  # Check for rsync delete options in output
  [[ "$output" =~ --delete-before|--delete-during|--delete-delay ]]
}

@test "nukedir uses correct rsync options for filesystem" {
  local -- test_dir
  test_dir=$(create_test_dir "rsync_opts" 5 1)

  local -- fs_type
  fs_type=$(get_filesystem_type "$test_dir")

  run sudo "$NUKEDIR_SCRIPT" -v -n "$test_dir"
  assert_success

  case "$fs_type" in
    xfs)
      assert_output_contains "--delete-during"
      ;;
    btrfs)
      assert_output_contains "--delete-delay"
      assert_output_contains "--preallocate"
      ;;
    *)
      # For ext4 and others, should use --delete-before
      assert_output_contains "--delete-before"
      assert_output_contains "--no-inc-recursive"
      assert_output_contains "--inplace"
      ;;
  esac
}

@test "nukedir handles ext4 filesystem" {
  skip "Filesystem-specific test - requires ext4 filesystem"

  # This test would need to be run on ext4 specifically
  # or with a controlled test environment
}

@test "nukedir handles xfs filesystem" {
  skip "Filesystem-specific test - requires XFS filesystem"
}

@test "nukedir handles btrfs filesystem" {
  skip "Filesystem-specific test - requires Btrfs filesystem"
}

@test "nukedir handles tmpfs filesystem" {
  # /tmp is often tmpfs or /run is tmpfs
  local -- tmpfs_path=""

  # Check if /run is tmpfs
  if df -t tmpfs 2>/dev/null | grep -q '\s/run$'; then
    tmpfs_path="/run"
  elif df -t tmpfs 2>/dev/null | grep -q '\s/tmp$'; then
    tmpfs_path="/tmp"
  else
    skip "No tmpfs filesystem found"
  fi

  local -- test_dir="$tmpfs_path/nukedir-test-$$"
  mkdir -p "$test_dir"
  echo "test" > "$test_dir/file.txt"

  run sudo "$NUKEDIR_SCRIPT" -n "$test_dir"
  assert_success
  assert_output_contains "Filesystem type:"

  # Cleanup
  rm -rf "$test_dir"
}

@test "nukedir prefers /run for BITBIN when it's tmpfs" {
  # Check if /run is tmpfs
  if ! df -t tmpfs 2>/dev/null | grep -q '\s/run$'; then
    skip "/run is not tmpfs on this system"
  fi

  local -- test_dir
  test_dir=$(create_test_dir "bitbin_run" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -v -n "$test_dir"
  assert_success

  # Should show BITBIN in /run
  assert_output_contains "BITBIN=/run/"
}

@test "nukedir falls back to /tmp for BITBIN when /run is not tmpfs" {
  skip "Environment-specific test - depends on system configuration"
}

@test "nukedir includes --no-inc-recursive for non-XFS/Btrfs" {
  local -- test_dir
  test_dir=$(create_test_dir "no_inc_recursive" 5 1)

  local -- fs_type
  fs_type=$(get_filesystem_type "$test_dir")

  # Skip if on XFS or Btrfs
  if [[ "$fs_type" == "xfs" || "$fs_type" == "btrfs" ]]; then
    skip "Test requires non-XFS/Btrfs filesystem (current: $fs_type)"
  fi

  run sudo "$NUKEDIR_SCRIPT" -v -n "$test_dir"
  assert_success
  assert_output_contains "--no-inc-recursive"
}

@test "nukedir includes --inplace for standard filesystems" {
  local -- test_dir
  test_dir=$(create_test_dir "inplace_test" 5 1)

  local -- fs_type
  fs_type=$(get_filesystem_type "$test_dir")

  # Skip if on XFS or Btrfs (they use different options)
  if [[ "$fs_type" == "xfs" || "$fs_type" == "btrfs" ]]; then
    skip "Test requires non-XFS/Btrfs filesystem (current: $fs_type)"
  fi

  run sudo "$NUKEDIR_SCRIPT" -v -n "$test_dir"
  assert_success
  assert_output_contains "--inplace"
}
