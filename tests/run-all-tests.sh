#!/usr/bin/env bash
# Main test runner for nukedir test suite
# Executes all test categories and generates reports
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

declare -r SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
declare -r PROJECT_ROOT="${SCRIPT_DIR}/.."

# Message functions
info() { echo "◉ $*"; }
warn() { echo "▲ $*"; }
success() { echo "✓ $*"; }
error() { >&2 echo "✗ $*"; }
die() { (($# > 1)) && error "${@:2}"; exit "${1:-0}"; }

# Check for BATS installation
check_bats() {
  if ! command -v bats &>/dev/null; then
    error "BATS (Bash Automated Testing System) is not installed"
    info "Install with:"
    info "  Ubuntu/Debian: sudo apt-get install bats"
    info "  macOS: brew install bats-core"
    info "  npm: npm install -g bats"
    info "  Or visit: https://github.com/bats-core/bats-core"
    return 1
  fi
  return 0
}

# Check for required tools
check_dependencies() {
  local -a missing=()

  command -v bats &>/dev/null || missing+=("bats")
  command -v rsync &>/dev/null || missing+=("rsync")
  command -v shellcheck &>/dev/null || warn "shellcheck not found (optional but recommended)"

  if ((${#missing[@]} > 0)); then
    error "Missing required dependencies: ${missing[*]}"
    return 1
  fi

  return 0
}

# Run shellcheck on nukedir script
run_shellcheck() {
  if ! command -v shellcheck &>/dev/null; then
    warn "Skipping shellcheck (not installed)"
    return 0
  fi

  info "Running shellcheck on nukedir script..."
  if shellcheck "$PROJECT_ROOT/nukedir"; then
    success "shellcheck passed"
    return 0
  else
    error "shellcheck found issues"
    return 1
  fi
}

# Run tests in a category
run_test_category() {
  local -- category=$1
  local -- test_dir="$SCRIPT_DIR/$category"

  if [[ ! -d "$test_dir" ]]; then
    warn "Test category not found: $category"
    return 1
  fi

  local -a test_files=()
  mapfile -t test_files < <(find "$test_dir" -name "*.bats" -type f | sort)

  if ((${#test_files[@]} == 0)); then
    warn "No test files found in $category"
    return 0
  fi

  info "Running $category tests (${#test_files[@]} file(s))..."

  local -i failed=0
  for test_file in "${test_files[@]}"; do
    local -- test_name
    test_name=$(basename "$test_file")
    echo
    info "  → $test_name"

    if sudo bats "$test_file"; then
      success "  $test_name passed"
    else
      error "  $test_name failed"
      ((failed++))
    fi
  done

  if ((failed > 0)); then
    error "$category: $failed test file(s) failed"
    return 1
  else
    success "$category: All tests passed"
    return 0
  fi
}

# Main execution
main() {
  local -- run_mode="all"
  local -i shellcheck_only=0
  local -i skip_shellcheck=0

  # Parse arguments
  while (($#)); do
    case $1 in
      --unit|-u)
        run_mode="unit"
        ;;
      --integration|-i)
        run_mode="integration"
        ;;
      --safety|-s)
        run_mode="safety"
        ;;
      --performance|-p)
        run_mode="performance"
        ;;
      --shellcheck)
        shellcheck_only=1
        ;;
      --no-shellcheck)
        skip_shellcheck=1
        ;;
      --all|-a)
        run_mode="all"
        ;;
      --help|-h)
        cat <<EOF
nukedir Test Runner

Usage: $0 [OPTIONS]

Options:
  -u, --unit           Run unit tests only
  -i, --integration    Run integration tests only
  -s, --safety         Run safety tests only
  -p, --performance    Run performance tests only
  -a, --all            Run all tests (default)
  --shellcheck         Run shellcheck only
  --no-shellcheck      Skip shellcheck
  -h, --help           Show this help

Examples:
  $0                   # Run all tests
  $0 --unit            # Run only unit tests
  $0 --safety          # Run only safety tests
  $0 --shellcheck      # Run shellcheck only

Environment Variables:
  PERF_TESTS=1         Enable performance benchmarks (skipped by default)
  STRESS_TESTS=1       Enable stress tests (skipped by default)
  BATS_DEBUG=1         Enable debug output in tests

EOF
        exit 0
        ;;
      *)
        die 22 "Unknown option: $1"
        ;;
    esac
    shift
  done

  info "======================================"
  info "  nukedir Test Suite"
  info "======================================"
  echo

  # Check dependencies
  info "Checking dependencies..."
  check_dependencies || die 1 "Dependency check failed"
  success "All dependencies found"
  echo

  # Run shellcheck if requested
  if ((shellcheck_only)); then
    run_shellcheck
    exit $?
  fi

  # Run shellcheck unless skipped
  if ((! skip_shellcheck)); then
    run_shellcheck
    echo
  fi

  # Verify we're running as root or with sudo
  if ((EUID != 0)); then
    # Check if we can sudo
    if ! sudo -n true 2>/dev/null; then
      error "Tests require root privileges or passwordless sudo"
      die 1 "Please run as root or configure passwordless sudo"
    fi
  fi

  local -i total_failed=0

  # Run requested tests
  case "$run_mode" in
    unit)
      run_test_category "unit" || ((total_failed++))
      ;;

    integration)
      run_test_category "integration" || ((total_failed++))
      ;;

    safety)
      run_test_category "safety" || ((total_failed++))
      ;;

    performance)
      if [[ -z "${PERF_TESTS:-}" ]]; then
        warn "Performance tests skipped (set PERF_TESTS=1 to enable)"
      else
        run_test_category "performance" || ((total_failed++))
      fi
      ;;

    all)
      run_test_category "unit" || ((total_failed++))
      echo
      run_test_category "integration" || ((total_failed++))
      echo
      run_test_category "safety" || ((total_failed++))
      echo

      if [[ -n "${PERF_TESTS:-}" ]]; then
        run_test_category "performance" || ((total_failed++))
        echo
      else
        info "Performance tests skipped (set PERF_TESTS=1 to enable)"
        echo
      fi
      ;;
  esac

  # Summary
  echo
  info "======================================"
  if ((total_failed == 0)); then
    success "All test categories passed!"
    info "======================================"
    exit 0
  else
    error "$total_failed test categor$( ((total_failed == 1)) && echo 'y' || echo 'ies') failed"
    info "======================================"
    exit 1
  fi
}

main "$@"
