#!/usr/bin/env bash
# Cleanup test fixtures for nukedir test suite
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# Message functions
info() { echo "◉ $*"; }
success() { echo "✓ $*"; }
warn() { echo "▲ $*"; }
error() { >&2 echo "✗ $*"; }

# Find fixture directories
find_fixture_dirs() {
  # Look for fixture directories in common locations
  find /tmp -maxdepth 1 -type d -name "nukedir-fixtures-*" 2>/dev/null
}

# Cleanup a single fixture directory
cleanup_fixture() {
  local -- fixture_dir=$1

  if [[ ! -d "$fixture_dir" ]]; then
    warn "Fixture directory not found: $fixture_dir"
    return 1
  fi

  info "Cleaning up fixture: $fixture_dir"

  # Count files before deletion
  local -i file_count
  file_count=$(find "$fixture_dir" -type f 2>/dev/null | wc -l)

  # Remove the fixture directory
  rm -rf "$fixture_dir"

  if [[ -d "$fixture_dir" ]]; then
    error "Failed to remove fixture: $fixture_dir"
    return 1
  fi

  success "Removed fixture ($file_count files): $fixture_dir"
  return 0
}

# Main execution
main() {
  local -a fixture_dirs
  mapfile -t fixture_dirs < <(find_fixture_dirs)

  if ((${#fixture_dirs[@]} == 0)); then
    info "No fixture directories found"
    return 0
  fi

  info "Found ${#fixture_dirs[@]} fixture director$( ((${#fixture_dirs[@]} == 1)) && echo 'y' || echo 'ies')"

  local -i success_count=0
  local -i fail_count=0

  for fixture_dir in "${fixture_dirs[@]}"; do
    if cleanup_fixture "$fixture_dir"; then
      ((success_count++))
    else
      ((fail_count++))
    fi
  done

  echo
  if ((fail_count == 0)); then
    success "All fixtures cleaned up successfully ($success_count removed)"
  else
    warn "Cleanup completed with errors: $success_count removed, $fail_count failed"
  fi
}

main "$@"
