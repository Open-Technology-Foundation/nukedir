#!/usr/bin/env bash
# Create test fixtures for nukedir test suite
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

declare -r FIXTURE_BASE="${BATS_TMPDIR:-/tmp}/nukedir-fixtures-$$"

# Message functions
info() { echo "◉ $*"; }
success() { echo "✓ $*"; }
error() { >&2 echo "✗ $*"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Create small test directory (100 files, 3 levels deep)
create_small_fixture() {
  local -- dir="$FIXTURE_BASE/small"
  info "Creating small fixture at $dir"

  mkdir -p "$dir"

  # Root level files
  for ((i=1; i<=100; i++)); do
    echo "Small fixture file $i" > "$dir/file_$i.txt"
  done

  # Create 3 levels of nested directories
  for ((level=1; level<=3; level++)); do
    local -- subdir="$dir/level_$level"
    mkdir -p "$subdir"
    for ((i=1; i<=50; i++)); do
      echo "Level $level file $i" > "$subdir/file_$i.txt"
    done
  done

  success "Small fixture created: $(find "$dir" -type f | wc -l) files"
}

# Create medium test directory (1000 files, 5 levels deep)
create_medium_fixture() {
  local -- dir="$FIXTURE_BASE/medium"
  info "Creating medium fixture at $dir"

  mkdir -p "$dir"

  # Root level files
  for ((i=1; i<=1000; i++)); do
    echo "Medium fixture file $i" > "$dir/file_$i.txt"
  done

  # Create 5 levels of nested directories
  for ((level=1; level<=5; level++)); do
    local -- subdir="$dir/level_$level"
    mkdir -p "$subdir"
    for ((i=1; i<=200; i++)); do
      echo "Level $level file $i" > "$subdir/file_$i.txt"
    done
  done

  success "Medium fixture created: $(find "$dir" -type f | wc -l) files"
}

# Create large test directory (10000 files, 3 levels deep)
create_large_fixture() {
  local -- dir="$FIXTURE_BASE/large"
  info "Creating large fixture at $dir"

  mkdir -p "$dir"

  # Root level files (batch creation for performance)
  for ((i=1; i<=10000; i++)); do
    touch "$dir/file_$i.txt"
  done

  # Create nested structure
  for ((level=1; level<=3; level++)); do
    local -- subdir="$dir/level_$level"
    mkdir -p "$subdir"
    for ((i=1; i<=1000; i++)); do
      touch "$subdir/file_$i.txt"
    done
  done

  success "Large fixture created: $(find "$dir" -type f | wc -l) files"
}

# Create empty directory fixture
create_empty_fixture() {
  local -- dir="$FIXTURE_BASE/empty"
  info "Creating empty fixture at $dir"

  mkdir -p "$dir"

  success "Empty fixture created"
}

# Create nested empty directories
create_nested_empty_fixture() {
  local -- dir="$FIXTURE_BASE/nested_empty"
  info "Creating nested empty directories at $dir"

  mkdir -p "$dir/level1/level2/level3/level4/level5"

  success "Nested empty fixture created"
}

# Create fixture with various file types
create_mixed_fixture() {
  local -- dir="$FIXTURE_BASE/mixed"
  info "Creating mixed file type fixture at $dir"

  mkdir -p "$dir"/{text,binary,symlinks,empty}

  # Text files
  for ((i=1; i<=50; i++)); do
    echo "Text content $i" > "$dir/text/file_$i.txt"
  done

  # Binary-like files (random data)
  for ((i=1; i<=10; i++)); do
    dd if=/dev/urandom of="$dir/binary/file_$i.bin" bs=1K count=10 2>/dev/null
  done

  # Symlinks
  for ((i=1; i<=10; i++)); do
    ln -s "../text/file_$i.txt" "$dir/symlinks/link_$i.txt"
  done

  # Empty files
  for ((i=1; i<=20; i++)); do
    touch "$dir/empty/file_$i.txt"
  done

  success "Mixed fixture created: $(find "$dir" -type f | wc -l) files"
}

# Create fixture with special characters in names
create_special_chars_fixture() {
  local -- dir="$FIXTURE_BASE/special_chars"
  info "Creating special characters fixture at $dir"

  mkdir -p "$dir"

  # Create files with spaces
  touch "$dir/file with spaces.txt"

  # Create files with special characters (safe ones)
  touch "$dir/file_with_dash-test.txt"
  touch "$dir/file_with_underscore_test.txt"
  touch "$dir/file.multiple.dots.txt"

  # Create directory with spaces
  mkdir -p "$dir/directory with spaces"
  touch "$dir/directory with spaces/nested file.txt"

  success "Special characters fixture created"
}

# Main execution
main() {
  info "Creating test fixtures in $FIXTURE_BASE"

  # Create base directory
  mkdir -p "$FIXTURE_BASE"

  # Create all fixtures
  create_small_fixture
  create_medium_fixture
  create_large_fixture
  create_empty_fixture
  create_nested_empty_fixture
  create_mixed_fixture
  create_special_chars_fixture

  echo
  success "All fixtures created successfully"
  info "Fixture location: $FIXTURE_BASE"
  info "Total files: $(find "$FIXTURE_BASE" -type f 2>/dev/null | wc -l)"
  info "Total directories: $(find "$FIXTURE_BASE" -type d 2>/dev/null | wc -l)"

  # Save fixture base path for tests
  echo "$FIXTURE_BASE" > "$FIXTURE_BASE/.fixture_path"
}

main "$@"
