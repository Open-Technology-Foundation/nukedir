#!/usr/bin/env bash
# Test helper functions for nukedir test suite
# Provides common utilities, setup/teardown, and assertion helpers

# Test directories
export TEST_ROOT="${BATS_TEST_DIRNAME}/.."
export NUKEDIR_SCRIPT="${TEST_ROOT}/../nukedir"
export TEST_TEMP_DIR="${BATS_TMPDIR}/nukedir-test-$$"
export FIXTURE_DIR="${TEST_ROOT}/fixtures"

# Ensure nukedir script exists and is executable
assert_nukedir_exists() {
  [[ -x "$NUKEDIR_SCRIPT" ]] || {
    echo "FATAL: nukedir script not found or not executable at $NUKEDIR_SCRIPT"
    return 1
  }
}

# Setup function - creates isolated test environment
test_setup() {
  mkdir -p "$TEST_TEMP_DIR"
  export TEST_DIR="$TEST_TEMP_DIR"
}

# Teardown function - cleans up test environment
test_teardown() {
  if [[ -d "$TEST_TEMP_DIR" ]]; then
    # Use rm directly for cleanup since we're in test mode
    rm -rf "$TEST_TEMP_DIR"
  fi
}

# Create a test directory with files
# Usage: create_test_dir <name> <num_files> <depth>
create_test_dir() {
  local -- name=$1
  local -i num_files=${2:-10}
  local -i depth=${3:-2}
  local -- dir="$TEST_TEMP_DIR/$name"

  mkdir -p "$dir"

  # Create files at root level
  for ((i=1; i<=num_files; i++)); do
    echo "test file $i" > "$dir/file_$i.txt"
  done

  # Create nested directories
  if ((depth > 0)); then
    for ((d=1; d<=depth; d++)); do
      local -- subdir="$dir/level_$d"
      mkdir -p "$subdir"
      for ((i=1; i<=num_files; i++)); do
        echo "test file $i at depth $d" > "$subdir/file_$i.txt"
      done
    done
  fi

  echo "$dir"
}

# Create a large test directory (many files)
# Usage: create_large_test_dir <name> <num_files>
create_large_test_dir() {
  local -- name=$1
  local -i num_files=${2:-1000}
  local -- dir="$TEST_TEMP_DIR/$name"

  mkdir -p "$dir"

  # Create files in batches for performance
  for ((i=1; i<=num_files; i++)); do
    touch "$dir/file_$i.txt"
  done

  echo "$dir"
}

# Count files in directory recursively
count_files() {
  local -- dir=$1
  find "$dir" -type f 2>/dev/null | wc -l
}

# Count directories recursively
count_dirs() {
  local -- dir=$1
  find "$dir" -type d 2>/dev/null | wc -l
}

# Check if directory is empty
is_dir_empty() {
  local -- dir=$1
  [[ -d "$dir" ]] || return 1
  local -i count
  count=$(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
  ((count == 0))
}

# Check if directory exists
dir_exists() {
  [[ -d "$1" ]]
}

# Check if directory does not exist
dir_not_exists() {
  [[ ! -d "$1" ]]
}

# Run nukedir with sudo (required for root operations)
run_nukedir_sudo() {
  run sudo "$NUKEDIR_SCRIPT" "$@"
}

# Run nukedir in dry-run mode (safe default)
run_nukedir_dryrun() {
  run sudo "$NUKEDIR_SCRIPT" --dryrun "$@"
}

# Run nukedir with actual deletion (USE CAREFULLY)
run_nukedir_delete() {
  run sudo "$NUKEDIR_SCRIPT" --notdryrun "$@"
}

# Assert output contains string
assert_output_contains() {
  local -- expected=$1
  [[ "$output" == *"$expected"* ]] || {
    echo "Expected output to contain: $expected"
    echo "Actual output: $output"
    return 1
  }
}

# Assert output does not contain string
assert_output_not_contains() {
  local -- unexpected=$1
  [[ "$output" != *"$unexpected"* ]] || {
    echo "Expected output NOT to contain: $unexpected"
    echo "Actual output: $output"
    return 1
  }
}

# Assert exit code equals
assert_exit_code() {
  local -i expected=$1
  ((status == expected)) || {
    echo "Expected exit code: $expected"
    echo "Actual exit code: $status"
    return 1
  }
}

# Assert exit code is success (0)
assert_success() {
  assert_exit_code 0
}

# Assert exit code is failure (non-zero)
assert_failure() {
  ((status != 0)) || {
    echo "Expected failure but got success (exit 0)"
    return 1
  }
}

# Skip test if not running as root
skip_if_not_root() {
  if ((EUID != 0)); then
    skip "This test requires root privileges"
  fi
}

# Skip test if rsync not installed
skip_if_no_rsync() {
  if ! command -v rsync &>/dev/null; then
    skip "rsync is not installed"
  fi
}

# Skip test if ionice not available
skip_if_no_ionice() {
  if ! command -v ionice &>/dev/null; then
    skip "ionice is not available"
  fi
}

# Get filesystem type for a path
get_filesystem_type() {
  local -- path=$1
  df -PT "$path" 2>/dev/null | awk 'NR==2 {print $2}'
}

# Check if running on specific filesystem
is_filesystem() {
  local -- path=$1
  local -- expected_fs=$2
  local -- actual_fs
  actual_fs=$(get_filesystem_type "$path")
  [[ "$actual_fs" == "$expected_fs" ]]
}

# Create a mock mount point (for testing mount point protection)
create_mock_mount() {
  local -- mount_dir=$1
  mkdir -p "$mount_dir"
  # Note: Cannot actually mount without root in test environment
  # Tests should use real mount points or skip
}

# Check if path is a mount point
is_mount_point() {
  mountpoint -q "$1" 2>/dev/null
}

# Get nukedir version
get_nukedir_version() {
  "$NUKEDIR_SCRIPT" --version 2>/dev/null | awk '{print $NF}'
}

# Print debug info (only if BATS_DEBUG is set)
debug() {
  if [[ -n "${BATS_DEBUG:-}" ]]; then
    echo "DEBUG: $*" >&3
  fi
}

# Setup function to be called in setup()
common_setup() {
  assert_nukedir_exists
  test_setup
}

# Teardown function to be called in teardown()
common_teardown() {
  test_teardown
}

# Export functions so they're available in tests
export -f assert_nukedir_exists
export -f test_setup test_teardown
export -f create_test_dir create_large_test_dir
export -f count_files count_dirs
export -f is_dir_empty dir_exists dir_not_exists
export -f run_nukedir_sudo run_nukedir_dryrun run_nukedir_delete
export -f assert_output_contains assert_output_not_contains
export -f assert_exit_code assert_success assert_failure
export -f skip_if_not_root skip_if_no_rsync skip_if_no_ionice
export -f get_filesystem_type is_filesystem
export -f create_mock_mount is_mount_point
export -f get_nukedir_version
export -f debug
export -f common_setup common_teardown
