#!/usr/bin/env bats
# Integration tests for nukedir deletion functionality
# Tests actual deletion operations in controlled environments
# WARNING: These tests perform actual deletions - use with caution

load '../helpers/test_helpers'

setup() {
  common_setup
}

teardown() {
  common_teardown
}

@test "nukedir dryrun does not delete files" {
  local -- test_dir
  test_dir=$(create_test_dir "dryrun_no_delete" 10 2)

  local -i file_count_before
  file_count_before=$(count_files "$test_dir")

  run sudo "$NUKEDIR_SCRIPT" --dryrun "$test_dir"
  assert_success

  # Directory should still exist with all files
  [[ -d "$test_dir" ]]
  local -i file_count_after
  file_count_after=$(count_files "$test_dir")
  ((file_count_before == file_count_after))
}

@test "nukedir --notdryrun deletes small directory" {
  local -- test_dir
  test_dir=$(create_test_dir "small_delete" 10 2)

  # Verify directory exists and has files
  [[ -d "$test_dir" ]]
  local -i file_count
  file_count=$(count_files "$test_dir")
  ((file_count > 0))

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir"
  assert_success

  # Directory should be completely removed
  [[ ! -d "$test_dir" ]]
}

@test "nukedir --notdryrun deletes medium directory" {
  local -- test_dir
  test_dir=$(create_test_dir "medium_delete" 100 3)

  # Verify directory exists
  [[ -d "$test_dir" ]]

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir"
  assert_success

  # Directory should be completely removed
  [[ ! -d "$test_dir" ]]
}

@test "nukedir --notdryrun deletes large directory" {
  local -- test_dir
  test_dir=$(create_large_test_dir "large_delete" 1000)

  # Verify directory exists
  [[ -d "$test_dir" ]]
  local -i file_count
  file_count=$(count_files "$test_dir")
  ((file_count >= 1000))

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir"
  assert_success

  # Directory should be completely removed
  [[ ! -d "$test_dir" ]]
}

@test "nukedir deletes empty directory" {
  local -- test_dir="$TEST_TEMP_DIR/empty_delete"
  mkdir -p "$test_dir"

  [[ -d "$test_dir" ]]

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir"
  assert_success

  [[ ! -d "$test_dir" ]]
}

@test "nukedir deletes nested empty directories" {
  local -- test_dir="$TEST_TEMP_DIR/nested/empty/structure"
  mkdir -p "$test_dir"

  [[ -d "$test_dir" ]]

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir"
  assert_success

  [[ ! -d "$test_dir" ]]
}

@test "nukedir deletes directory with symlinks" {
  local -- test_dir="$TEST_TEMP_DIR/with_symlinks"
  mkdir -p "$test_dir"/{real,links}

  echo "real file" > "$test_dir/real/file.txt"
  ln -s "../real/file.txt" "$test_dir/links/symlink.txt"

  [[ -d "$test_dir" ]]

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir"
  assert_success

  [[ ! -d "$test_dir" ]]
}

@test "nukedir deletes directory with special character filenames" {
  local -- test_dir="$TEST_TEMP_DIR/special_chars_delete"
  mkdir -p "$test_dir"

  touch "$test_dir/file with spaces.txt"
  touch "$test_dir/file-with-dashes.txt"
  touch "$test_dir/file_with_underscores.txt"
  touch "$test_dir/file.multiple.dots.txt"

  [[ -d "$test_dir" ]]

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir"
  assert_success

  [[ ! -d "$test_dir" ]]
}

@test "nukedir deletes multiple directories in sequence" {
  local -- dir1 dir2 dir3
  dir1=$(create_test_dir "multi_del_1" 10 1)
  dir2=$(create_test_dir "multi_del_2" 10 1)
  dir3=$(create_test_dir "multi_del_3" 10 1)

  [[ -d "$dir1" ]]
  [[ -d "$dir2" ]]
  [[ -d "$dir3" ]]

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$dir1" "$dir2" "$dir3"
  assert_success

  [[ ! -d "$dir1" ]]
  [[ ! -d "$dir2" ]]
  [[ ! -d "$dir3" ]]
}

@test "nukedir with ionice level 1 performs deletion" {
  skip_if_no_ionice

  local -- test_dir
  test_dir=$(create_test_dir "ionice_delete" 50 2)

  [[ -d "$test_dir" ]]

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet -i 1 "$test_dir"
  assert_success

  [[ ! -d "$test_dir" ]]
}

@test "nukedir with ionice level 3 performs deletion" {
  skip_if_no_ionice

  local -- test_dir
  test_dir=$(create_test_dir "ionice3_delete" 50 2)

  [[ -d "$test_dir" ]]

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet -i 3 "$test_dir"
  assert_success

  [[ ! -d "$test_dir" ]]
}

@test "nukedir with timeout completes within time limit" {
  local -- test_dir
  test_dir=$(create_test_dir "timeout_delete" 20 2)

  [[ -d "$test_dir" ]]

  # Use a generous timeout for small directory
  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet -T 1m "$test_dir"
  assert_success

  [[ ! -d "$test_dir" ]]
}

@test "nukedir with rsync verbose mode shows progress" {
  local -- test_dir
  test_dir=$(create_test_dir "rsync_verbose_delete" 10 1)

  [[ -d "$test_dir" ]]

  run sudo "$NUKEDIR_SCRIPT" --notdryrun -r "$test_dir"
  assert_success

  [[ ! -d "$test_dir" ]]

  # Should have some verbose output from rsync
  [[ -n "$output" ]]
}

@test "nukedir reports completion status" {
  local -- test_dir
  test_dir=$(create_test_dir "completion_status" 10 1)

  [[ -d "$test_dir" ]]

  run sudo "$NUKEDIR_SCRIPT" --notdryrun "$test_dir"
  assert_success

  assert_output_contains "nuked"
  [[ ! -d "$test_dir" ]]
}

@test "nukedir in dryrun reports NOT nuked" {
  local -- test_dir
  test_dir=$(create_test_dir "dryrun_report" 10 1)

  run sudo "$NUKEDIR_SCRIPT" --dryrun "$test_dir"
  assert_success

  assert_output_contains "NOT"
  assert_output_contains "been nuked"
  [[ -d "$test_dir" ]]
}

@test "nukedir creates and removes BITBIN successfully" {
  local -- test_dir
  test_dir=$(create_test_dir "bitbin_lifecycle" 10 1)

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --verbose "$test_dir"
  assert_success

  # BITBIN should be mentioned in output
  assert_output_contains "BITBIN="
  [[ ! -d "$test_dir" ]]

  # BITBIN itself should be cleaned up (can't easily verify as it's temporary)
}
