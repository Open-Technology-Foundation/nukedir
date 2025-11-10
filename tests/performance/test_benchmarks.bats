#!/usr/bin/env bats
# Performance tests for nukedir
# Benchmarks deletion speed and resource usage
# These tests measure performance characteristics

load '../helpers/test_helpers'

setup() {
  common_setup
}

teardown() {
  common_teardown
}

# Helper function to time command execution
time_command() {
  local -- start_time end_time elapsed
  start_time=$(date +%s.%N)
  "$@"
  end_time=$(date +%s.%N)
  elapsed=$(echo "$end_time - $start_time" | bc)
  echo "$elapsed"
}

@test "benchmark: delete 1000 files" {
  skip "Performance test - enable with PERF_TESTS=1"

  local -- test_dir
  test_dir=$(create_large_test_dir "perf_1k" 1000)

  local -- elapsed
  elapsed=$(time_command sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir")

  echo "Time to delete 1000 files: ${elapsed}s" >&3
  [[ ! -d "$test_dir" ]]
}

@test "benchmark: delete 10000 files" {
  skip "Performance test - enable with PERF_TESTS=1"

  local -- test_dir
  test_dir=$(create_large_test_dir "perf_10k" 10000)

  local -- elapsed
  elapsed=$(time_command sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir")

  echo "Time to delete 10000 files: ${elapsed}s" >&3
  [[ ! -d "$test_dir" ]]
}

@test "benchmark: compare nukedir vs rm -rf for 1000 files" {
  skip "Performance comparison - enable with PERF_TESTS=1"

  # Test nukedir
  local -- test_dir1
  test_dir1=$(create_large_test_dir "nukedir_comp" 1000)
  local -- nukedir_time
  nukedir_time=$(time_command sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir1")

  # Test rm -rf
  local -- test_dir2
  test_dir2=$(create_large_test_dir "rm_comp" 1000)
  local -- rm_time
  rm_time=$(time_command sudo rm -rf "$test_dir2")

  echo "nukedir: ${nukedir_time}s" >&3
  echo "rm -rf: ${rm_time}s" >&3

  # Both should complete successfully
  [[ ! -d "$test_dir1" ]]
  [[ ! -d "$test_dir2" ]]
}

@test "benchmark: ionice level 1 (highest priority)" {
  skip "Performance test - enable with PERF_TESTS=1"

  skip_if_no_ionice

  local -- test_dir
  test_dir=$(create_large_test_dir "ionice1_perf" 1000)

  local -- elapsed
  elapsed=$(time_command sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet -i 1 "$test_dir")

  echo "Time with ionice level 1: ${elapsed}s" >&3
  [[ ! -d "$test_dir" ]]
}

@test "benchmark: ionice level 3 (lowest priority)" {
  skip "Performance test - enable with PERF_TESTS=1"

  skip_if_no_ionice

  local -- test_dir
  test_dir=$(create_large_test_dir "ionice3_perf" 1000)

  local -- elapsed
  elapsed=$(time_command sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet -i 3 "$test_dir")

  echo "Time with ionice level 3: ${elapsed}s" >&3
  [[ ! -d "$test_dir" ]]
}

@test "benchmark: deep directory structure (10 levels)" {
  skip "Performance test - enable with PERF_TESTS=1"

  local -- test_dir="$TEST_TEMP_DIR/deep_structure"
  mkdir -p "$test_dir"

  # Create deep nested structure
  local -- current="$test_dir"
  for ((i=1; i<=10; i++)); do
    current="$current/level_$i"
    mkdir -p "$current"
    touch "$current/file.txt"
  done

  local -- elapsed
  elapsed=$(time_command sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir")

  echo "Time for 10-level deep structure: ${elapsed}s" >&3
  [[ ! -d "$test_dir" ]]
}

@test "benchmark: wide directory structure (100 subdirs)" {
  skip "Performance test - enable with PERF_TESTS=1"

  local -- test_dir="$TEST_TEMP_DIR/wide_structure"
  mkdir -p "$test_dir"

  # Create wide structure
  for ((i=1; i<=100; i++)); do
    mkdir -p "$test_dir/subdir_$i"
    touch "$test_dir/subdir_$i/file.txt"
  done

  local -- elapsed
  elapsed=$(time_command sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir")

  echo "Time for 100-subdir wide structure: ${elapsed}s" >&3
  [[ ! -d "$test_dir" ]]
}

@test "benchmark: mixed file sizes" {
  skip "Performance test - enable with PERF_TESTS=1"

  local -- test_dir="$TEST_TEMP_DIR/mixed_sizes"
  mkdir -p "$test_dir"

  # Create files of various sizes
  for ((i=1; i<=100; i++)); do
    dd if=/dev/zero of="$test_dir/small_$i" bs=1K count=1 2>/dev/null
  done

  for ((i=1; i<=10; i++)); do
    dd if=/dev/zero of="$test_dir/medium_$i" bs=1M count=1 2>/dev/null
  done

  for ((i=1; i<=2; i++)); do
    dd if=/dev/zero of="$test_dir/large_$i" bs=10M count=1 2>/dev/null
  done

  local -- elapsed
  elapsed=$(time_command sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir")

  echo "Time for mixed file sizes: ${elapsed}s" >&3
  [[ ! -d "$test_dir" ]]
}

@test "benchmark: BITBIN in tmpfs (/run) vs regular (/tmp)" {
  skip "Performance comparison - enable with PERF_TESTS=1"

  # This test would need to control BITBIN location
  # and compare performance differences
}

@test "benchmark: filesystem type performance" {
  skip "Performance test - enable with PERF_TESTS=1"

  local -- test_dir
  test_dir=$(create_large_test_dir "fs_perf" 1000)

  local -- fs_type
  fs_type=$(get_filesystem_type "$test_dir")

  local -- elapsed
  elapsed=$(time_command sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir")

  echo "Filesystem: $fs_type" >&3
  echo "Time: ${elapsed}s" >&3
  [[ ! -d "$test_dir" ]]
}

@test "benchmark: timeout overhead" {
  skip "Performance test - enable with PERF_TESTS=1"

  local -- test_dir
  test_dir=$(create_test_dir "timeout_overhead" 100 2)

  # With timeout
  local -- with_timeout
  with_timeout=$(time_command sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet -T 5m "$test_dir")

  echo "Time with timeout: ${with_timeout}s" >&3
  [[ ! -d "$test_dir" ]]
}

@test "stress test: very large directory (50000 files)" {
  skip "Stress test - enable with STRESS_TESTS=1"

  local -- test_dir
  test_dir=$(create_large_test_dir "stress_50k" 50000)

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet -T 30m "$test_dir"
  assert_success
  [[ ! -d "$test_dir" ]]
}

@test "stress test: extremely deep nesting (50 levels)" {
  skip "Stress test - enable with STRESS_TESTS=1"

  local -- test_dir="$TEST_TEMP_DIR/extremely_deep"
  mkdir -p "$test_dir"

  local -- current="$test_dir"
  for ((i=1; i<=50; i++)); do
    current="$current/level_$i"
    mkdir -p "$current"
    touch "$current/file.txt"
  done

  run sudo "$NUKEDIR_SCRIPT" --notdryrun --quiet "$test_dir"
  assert_success
  [[ ! -d "$test_dir" ]]
}

@test "memory usage: monitor memory during deletion" {
  skip "Memory profiling test - requires additional tooling"

  # Would use /proc/$$/status or similar to monitor memory
}

@test "CPU usage: monitor CPU during deletion" {
  skip "CPU profiling test - requires additional tooling"

  # Would use time -v or similar to get CPU stats
}
