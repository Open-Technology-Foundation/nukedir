#!/usr/bin/env bats
# Regression test for sudo self-escalation
#
# Background: nukedir runs the equivalent of `exec sudo -n "$0" "$@"` when
# invoked as non-root. A prior bug (v3.1.1 WIP) moved this block INSIDE main()
# AFTER the argument-parsing while loop, which `shift`s away all of $@ — so the
# re-exec'd script saw zero arguments and always died with "No directory
# specified." This test verifies that a non-root user invoking nukedir with
# arguments successfully has those arguments delivered to the re-exec'd process.

load '../helpers/test_helpers'

setup() {
  common_setup
}

teardown() {
  common_teardown
}

# Pick a non-root user to run as. Prefer SUDO_USER (set when bats runs via
# sudo), then any existing uid=1000 user. Skip the test if we can't find one
# or if that user doesn't have passwordless sudo (required for self-escalation).
pick_non_root_user() {
  local -- candidate="${SUDO_USER:-}"
  if [[ -z $candidate ]]; then
    candidate=$(getent passwd 1000 2>/dev/null | cut -d: -f1)
  fi
  if [[ -z $candidate ]] || ! id -u "$candidate" &>/dev/null; then
    return 1
  fi
  # Verify passwordless sudo works for this user
  sudo -u "$candidate" sudo -n true 2>/dev/null || return 1
  echo "$candidate"
}

@test "self-escalation: args survive exec sudo re-exec (directory arg)" {
  local -- user
  user=$(pick_non_root_user) || skip "No non-root user with passwordless sudo available"

  local -- test_dir
  test_dir=$(create_test_dir "selfesc_dir" 3 1)
  # Make the test dir readable by the non-root user
  chmod -R a+rX "$TEST_TEMP_DIR"

  run sudo -u "$user" "$NUKEDIR_SCRIPT" --dryrun "$test_dir"
  assert_success
  # If args were lost to the self-escalation bug, output would be
  # "No directory specified." instead of processing the dir.
  assert_output_contains "$test_dir"
  assert_output_not_contains "No directory specified"
}

@test "self-escalation: flags survive exec sudo re-exec (--version)" {
  local -- user
  user=$(pick_non_root_user) || skip "No non-root user with passwordless sudo available"

  run sudo -u "$user" "$NUKEDIR_SCRIPT" --version
  assert_success
  assert_output_contains "nukedir"
}

@test "self-escalation: combined short options survive re-exec (-nv dir)" {
  local -- user
  user=$(pick_non_root_user) || skip "No non-root user with passwordless sudo available"

  local -- test_dir
  test_dir=$(create_test_dir "selfesc_combined" 3 1)
  chmod -R a+rX "$TEST_TEMP_DIR"

  run sudo -u "$user" "$NUKEDIR_SCRIPT" -nv "$test_dir"
  assert_success
  assert_output_contains "$test_dir"
  assert_output_contains "DRY_RUN"
}

@test "self-escalation: multiple directories survive re-exec" {
  local -- user
  user=$(pick_non_root_user) || skip "No non-root user with passwordless sudo available"

  local -- dir1 dir2
  dir1=$(create_test_dir "selfesc_multi_1" 3 1)
  dir2=$(create_test_dir "selfesc_multi_2" 3 1)
  chmod -R a+rX "$TEST_TEMP_DIR"

  run sudo -u "$user" "$NUKEDIR_SCRIPT" --dryrun "$dir1" "$dir2"
  assert_success
  assert_output_contains "$dir1"
  assert_output_contains "$dir2"
}
