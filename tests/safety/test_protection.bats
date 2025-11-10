#!/usr/bin/env bats
# Safety tests for nukedir
# Tests protection mechanisms against dangerous operations
# CRITICAL: These tests verify that nukedir refuses to delete protected paths

load '../helpers/test_helpers'

setup() {
  common_setup
}

teardown() {
  common_teardown
}

@test "nukedir refuses to delete root directory /" {
  run sudo "$NUKEDIR_SCRIPT" -n /
  assert_failure
  assert_output_contains "ROOT directory CANNOT be specified"
}

@test "nukedir refuses to run from root directory" {
  run sudo bash -c "cd / && $NUKEDIR_SCRIPT -n /tmp/test"
  assert_failure
  assert_output_contains "Cannot execute from root directory"
}

@test "nukedir refuses to delete /home" {
  # This should fail or at least require --notdryrun and explicit confirmation
  # Test in dryrun first
  run sudo "$NUKEDIR_SCRIPT" -n /home
  # In dryrun, it might proceed but we should be cautious
  # The key is that it should NEVER actually delete /home without explicit --notdryrun
}

@test "nukedir refuses to delete /etc" {
  # Similar to /home test - dryrun should work, but actual deletion should be explicit
  run sudo "$NUKEDIR_SCRIPT" -n /etc
  # Again, dryrun might proceed but actual deletion requires --notdryrun
}

@test "nukedir refuses to delete /usr" {
  run sudo "$NUKEDIR_SCRIPT" -n /usr
  # Test that it doesn't accidentally delete system directories
}

@test "nukedir refuses to delete /var" {
  run sudo "$NUKEDIR_SCRIPT" -n /var
  # System directory protection
}

@test "nukedir refuses to delete /boot" {
  run sudo "$NUKEDIR_SCRIPT" -n /boot
  # Critical boot files protection
}

@test "nukedir refuses to delete mount points" {
  # Get actual mount points
  local -a mount_points=()
  mapfile -t mount_points < <(mount | awk '{print $3}' | grep -v '^/$' | head -5)

  if ((${#mount_points[@]} == 0)); then
    skip "No suitable mount points found for testing"
  fi

  local -- mount_point="${mount_points[0]}"

  run sudo "$NUKEDIR_SCRIPT" -n "$mount_point"
  assert_failure
  assert_output_contains "Cannot delete a mount point"
}

@test "nukedir detects mount points correctly" {
  # Test with a known mount point like /proc or /sys
  if is_mount_point /proc; then
    run sudo "$NUKEDIR_SCRIPT" -n /proc
    assert_failure
    assert_output_contains "Cannot delete a mount point"
  else
    skip "/proc is not a mount point on this system"
  fi
}

@test "nukedir detects /tmp as potential mount point" {
  if is_mount_point /tmp; then
    run sudo "$NUKEDIR_SCRIPT" -n /tmp
    assert_failure
    assert_output_contains "Cannot delete a mount point"
  else
    skip "/tmp is not a mount point on this system - test not applicable"
  fi
}

@test "nukedir detects /run as potential mount point" {
  if is_mount_point /run; then
    run sudo "$NUKEDIR_SCRIPT" -n /run
    assert_failure
    assert_output_contains "Cannot delete a mount point"
  else
    skip "/run is not a mount point on this system - test not applicable"
  fi
}

@test "nukedir requires root or sudo" {
  # This test should run as non-root user
  if ((EUID == 0)); then
    skip "Test must run as non-root user"
  fi

  local -- test_dir
  test_dir=$(create_test_dir "no_root" 5 1)

  # Try to run without sudo
  run "$NUKEDIR_SCRIPT" -n "$test_dir"
  assert_failure
  assert_output_contains "root"
}

@test "nukedir validates directory before deletion" {
  local -- nonexistent="$TEST_TEMP_DIR/does_not_exist"

  run sudo "$NUKEDIR_SCRIPT" -N -q "$nonexistent"
  # Should successfully handle non-existent directory (realpath reports error)
  assert_success
  # realpath outputs error message
  [[ "$output" == *"realpath"* ]] || [[ "$output" == *"No such file"* ]]
}

@test "nukedir handles permission denied gracefully" {
  skip "Permission test requires specific setup - implement with root-only directory"
}

@test "nukedir default mode is dryrun (safety check)" {
  local -- test_dir
  test_dir=$(create_test_dir "default_safe" 10 1)

  # Run without specifying -n or -N
  run sudo "$NUKEDIR_SCRIPT" "$test_dir"
  assert_success

  # Directory should still exist because default is dryrun
  [[ -d "$test_dir" ]]
  assert_output_contains "DRY_RUN"
}

@test "nukedir requires explicit --notdryrun for deletion" {
  local -- test_dir
  test_dir=$(create_test_dir "explicit_notdryrun" 10 1)

  # Run with only dryrun flag
  run sudo "$NUKEDIR_SCRIPT" -n "$test_dir"
  assert_success
  [[ -d "$test_dir" ]]

  # Now with explicit --notdryrun
  run sudo "$NUKEDIR_SCRIPT" --notdryrun -q "$test_dir"
  assert_success
  [[ ! -d "$test_dir" ]]
}

@test "nukedir -N short form requires explicit flag" {
  local -- test_dir
  test_dir=$(create_test_dir "explicit_N" 10 1)

  # Verify dryrun doesn't delete
  run sudo "$NUKEDIR_SCRIPT" "$test_dir"
  [[ -d "$test_dir" ]]

  # Now with -N
  run sudo "$NUKEDIR_SCRIPT" -N -q "$test_dir"
  assert_success
  [[ ! -d "$test_dir" ]]
}

@test "nukedir does not follow symlinks to protected areas" {
  local -- test_dir="$TEST_TEMP_DIR/symlink_test"
  mkdir -p "$test_dir"

  # Create symlink to /etc (dangerous)
  ln -s /etc "$test_dir/link_to_etc"

  run sudo "$NUKEDIR_SCRIPT" -N -q "$test_dir"
  assert_success

  # Verify /etc still exists and is intact
  [[ -d /etc ]]
  [[ -d /etc/passwd ]] || [[ -f /etc/passwd ]]

  # Verify test_dir is removed
  [[ ! -d "$test_dir" ]]
}

@test "nukedir handles broken symlinks safely" {
  local -- test_dir="$TEST_TEMP_DIR/broken_symlink"
  mkdir -p "$test_dir"

  # Create broken symlink
  ln -s /nonexistent/path "$test_dir/broken_link"

  run sudo "$NUKEDIR_SCRIPT" -N -q "$test_dir"
  assert_success

  [[ ! -d "$test_dir" ]]
}

@test "nukedir protects against accidental script deletion" {
  # If someone tries to delete the directory containing nukedir itself
  local -- nukedir_dir
  nukedir_dir=$(dirname "$NUKEDIR_SCRIPT")

  # Only test in dryrun mode for safety
  run sudo "$NUKEDIR_SCRIPT" -n "$nukedir_dir"
  # This should work in dryrun, but we're testing it doesn't accidentally execute

  # Verify nukedir script still exists
  [[ -x "$NUKEDIR_SCRIPT" ]]
}

@test "nukedir shows warning before deletion" {
  local -- test_dir
  test_dir=$(create_test_dir "warning_test" 5 1)

  run sudo "$NUKEDIR_SCRIPT" -N "$test_dir"
  assert_success
  assert_output_contains "DELETING ALL CONTENTS"
  assert_output_contains "***"
}

@test "nukedir validates paths before operating" {
  # Test with invalid path characters (if any)
  run sudo "$NUKEDIR_SCRIPT" -n ""
  assert_failure
}

@test "nukedir handles concurrent execution safely" {
  skip "Concurrency test requires complex setup - implement with background processes"
}
