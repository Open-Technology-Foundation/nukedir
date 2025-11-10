# nukedir Test Suite - Comprehensive Test Plan

## Overview

This document describes the comprehensive test suite for nukedir, a high-performance directory deletion utility. The test suite uses BATS (Bash Automated Testing System) and includes unit tests, integration tests, safety tests, and performance benchmarks.

## Test Framework

- **Primary Framework**: BATS (Bash Automated Testing System)
- **Linting**: ShellCheck for static analysis
- **CI/CD**: GitHub Actions
- **Test Runner**: Custom bash script (`tests/run-all-tests.sh`)

## Test Suite Structure

```
tests/
├── unit/                         # Unit tests (40+ tests)
│   ├── test_basic.bats          # Basic functionality (version, help, options)
│   ├── test_validation.bats     # Input validation and path handling
│   └── test_filesystem.bats     # Filesystem detection and optimization
│
├── integration/                  # Integration tests (20+ tests)
│   └── test_deletion.bats       # End-to-end deletion operations
│
├── safety/                       # Safety tests (30+ tests)
│   └── test_protection.bats     # Security and protection mechanisms
│
├── performance/                  # Performance tests (15+ tests)
│   └── test_benchmarks.bats     # Benchmarks and stress tests
│
├── fixtures/                     # Test data generators
│   ├── create-fixtures.sh       # Generate test directories
│   └── cleanup-fixtures.sh      # Clean up test fixtures
│
├── helpers/                      # Test utilities
│   └── test_helpers.bash        # Common test functions and assertions
│
└── run-all-tests.sh             # Main test runner script
```

## Test Categories

### 1. Unit Tests (tests/unit/)

Tests individual functions and components in isolation.

#### test_basic.bats (30+ tests)
- Script existence and executability
- Version output (--version, -V)
- Help output (--help, -h)
- No arguments error handling
- Invalid option detection
- Option parsing (dry-run, verbose, quiet)
- ionice level validation (0-3)
- Timeout format validation (minutes, hours)
- Aggregated short options (-nv, -qn)
- Output icon validation (◉ ▲ ✓ ✗)

#### test_validation.bats (25+ tests)
- Directory existence validation
- Non-directory file rejection
- Path handling (trailing slashes, relative paths)
- Symlink resolution
- Paths with spaces and special characters
- Multiple directory support
- Empty directory handling
- Nested empty directories
- BITBIN location reporting
- Filesystem type detection
- Rsync command visibility
- --wait-for-rsync functionality
- --rsync-verbose option

#### test_filesystem.bats (15+ tests)
- Filesystem type detection
- Filesystem-specific optimization messages
- Correct rsync options per filesystem:
  - XFS: --delete-during
  - Btrfs: --delete-delay, --preallocate
  - ext4/others: --delete-before, --no-inc-recursive, --inplace
- BITBIN location preference (/run tmpfs vs /tmp)
- tmpfs filesystem handling

### 2. Integration Tests (tests/integration/)

Tests complete workflows and actual deletion operations in controlled environments.

#### test_deletion.bats (20+ tests)
- Dry-run non-deletion verification
- Small directory deletion (10 files)
- Medium directory deletion (100 files)
- Large directory deletion (1000+ files)
- Empty directory deletion
- Nested empty directories
- Directory with symlinks
- Special character filenames
- Multiple directory sequential deletion
- ionice level integration (1, 3)
- Timeout functionality
- Rsync verbose mode
- Completion status reporting
- Dry-run vs. notdryrun comparison
- BITBIN lifecycle management

### 3. Safety Tests (tests/safety/)

Critical tests ensuring nukedir doesn't cause catastrophic system damage.

#### test_protection.bats (30+ tests)
- Root directory (/) protection
- Cannot run from root directory
- System directory protection (/home, /etc, /usr, /var, /boot)
- Mount point detection and refusal
- Mount point tests (/proc, /sys, /tmp, /run)
- Root/sudo requirement enforcement
- Non-existent directory handling
- Permission denied graceful handling
- Default dry-run mode enforcement
- Explicit --notdryrun requirement
- Symlink safety (no following to protected areas)
- Broken symlink handling
- Deletion warning display
- Path validation
- Concurrent execution safety

### 4. Performance Tests (tests/performance/)

Benchmarks and stress tests (skipped by default, enabled with PERF_TESTS=1).

#### test_benchmarks.bats (15+ tests)
- Delete 1000 files benchmark
- Delete 10000 files benchmark
- nukedir vs. rm -rf comparison
- ionice level 1 performance
- ionice level 3 performance
- Deep directory structure (10 levels)
- Wide directory structure (100 subdirs)
- Mixed file sizes
- BITBIN location performance (tmpfs vs. regular)
- Filesystem type performance comparison
- Timeout overhead measurement
- Stress test: 50000 files
- Stress test: 50 levels deep
- Memory usage monitoring
- CPU usage monitoring

## Test Helpers and Utilities

### test_helpers.bash

Provides common functions for all tests:

**Setup/Teardown:**
- `common_setup()` - Initialize test environment
- `common_teardown()` - Clean up test environment
- `test_setup()` - Create isolated test directory
- `test_teardown()` - Remove test directory

**Test Data Creation:**
- `create_test_dir()` - Create directory with files
- `create_large_test_dir()` - Create directory with many files
- `count_files()` - Count files recursively
- `count_dirs()` - Count directories recursively

**Assertions:**
- `assert_success()` - Assert exit code 0
- `assert_failure()` - Assert non-zero exit code
- `assert_exit_code()` - Assert specific exit code
- `assert_output_contains()` - Assert output contains string
- `assert_output_not_contains()` - Assert output doesn't contain string

**Execution Helpers:**
- `run_nukedir_sudo()` - Run with sudo
- `run_nukedir_dryrun()` - Run in dry-run mode
- `run_nukedir_delete()` - Run with actual deletion

**Skip Conditions:**
- `skip_if_not_root()` - Skip if not running as root
- `skip_if_no_rsync()` - Skip if rsync not installed
- `skip_if_no_ionice()` - Skip if ionice not available

**Filesystem Utilities:**
- `get_filesystem_type()` - Get filesystem type for path
- `is_filesystem()` - Check if specific filesystem
- `is_mount_point()` - Check if path is mount point

## Test Fixtures

### create-fixtures.sh

Generates test data directories:
- **small**: 100 files, 3 levels deep
- **medium**: 1000 files, 5 levels deep
- **large**: 10000 files, 3 levels deep
- **empty**: Empty directory
- **nested_empty**: Nested empty directories
- **mixed**: Various file types (text, binary, symlinks)
- **special_chars**: Files with special characters in names

### cleanup-fixtures.sh

Automatically finds and removes all test fixtures in /tmp.

## Test Runner (run-all-tests.sh)

Main test execution script with options:

```bash
./tests/run-all-tests.sh [OPTIONS]

Options:
  -u, --unit           Run unit tests only
  -i, --integration    Run integration tests only
  -s, --safety         Run safety tests only
  -p, --performance    Run performance tests only
  -a, --all            Run all tests (default)
  --shellcheck         Run shellcheck only
  --no-shellcheck      Skip shellcheck
  -h, --help           Show help
```

**Environment Variables:**
- `PERF_TESTS=1` - Enable performance benchmarks
- `STRESS_TESTS=1` - Enable stress tests
- `BATS_DEBUG=1` - Enable debug output

## Continuous Integration (GitHub Actions)

Automated testing via `.github/workflows/test.yml`:

### Jobs

1. **shellcheck** - Lint all bash scripts
2. **unit-tests** - Run unit tests
3. **integration-tests** - Run integration tests
4. **safety-tests** - Run safety tests
5. **all-tests** - Run complete test suite on Ubuntu 20.04, 22.04, 24.04
6. **performance-tests** - Optional, manual trigger only
7. **stress-tests** - Optional, manual trigger only
8. **test-summary** - Aggregate results

### Triggers

- Push to main/develop branches
- Pull requests
- Manual workflow dispatch

## Running the Test Suite

### Prerequisites

```bash
# Install BATS
sudo apt-get install bats      # Ubuntu/Debian
brew install bats-core         # macOS

# Install dependencies
sudo apt-get install rsync shellcheck
```

### Quick Start

```bash
# Run all tests
sudo ./tests/run-all-tests.sh

# Run specific category
sudo ./tests/run-all-tests.sh --unit
sudo ./tests/run-all-tests.sh --safety

# Run with performance tests
PERF_TESTS=1 sudo ./tests/run-all-tests.sh

# Run individual test file
sudo bats tests/unit/test_basic.bats
```

### Expected Results

- **Unit tests**: ~70 tests, all should pass
- **Integration tests**: ~20 tests, all should pass
- **Safety tests**: ~30 tests, all should pass
- **Performance tests**: ~15 tests (skipped by default)

**Total**: ~120+ automated tests

## Test Coverage

### Functionality Coverage

- ✓ Command-line option parsing
- ✓ Input validation
- ✓ Filesystem detection
- ✓ Filesystem-specific optimizations
- ✓ Dry-run mode
- ✓ Actual deletion
- ✓ Multiple directory handling
- ✓ ionice/nice integration
- ✓ Timeout functionality
- ✓ BITBIN management
- ✓ Cache clearing
- ✓ Error handling
- ✓ Safety mechanisms

### Safety Coverage

- ✓ Root directory protection
- ✓ Mount point protection
- ✓ System directory protection
- ✓ Symlink safety
- ✓ Permission validation
- ✓ Default dry-run enforcement

### Edge Cases

- ✓ Empty directories
- ✓ Deeply nested structures
- ✓ Special characters in filenames
- ✓ Broken symlinks
- ✓ Non-existent paths
- ✓ Paths with spaces
- ✓ Large file counts

## Maintenance

### Adding New Tests

1. Choose appropriate category (unit/integration/safety/performance)
2. Create or update .bats file
3. Use test_helpers.bash functions
4. Follow naming convention: `@test "description"`
5. Include setup/teardown if needed
6. Add skip conditions for optional features

### Test Naming Conventions

- Use descriptive test names
- Format: `@test "nukedir [action] [expected result]"`
- Examples:
  - `@test "nukedir --version displays version number"`
  - `@test "nukedir refuses to delete root directory"`
  - `@test "nukedir detects filesystem type"`

### Best Practices

1. Always use `common_setup()` and `common_teardown()`
2. Clean up test data in teardown
3. Use assertions from test_helpers.bash
4. Add skip conditions for optional dependencies
5. Test both success and failure cases
6. Use descriptive variable names
7. Keep tests independent and isolated

## Known Limitations

- Some tests require root/sudo privileges
- Mount point tests depend on system configuration
- Filesystem-specific tests require specific filesystems
- Performance tests are resource-intensive
- Stress tests can take significant time

## Future Enhancements

- [ ] Add code coverage reporting
- [ ] Add performance regression detection
- [ ] Add memory leak detection
- [ ] Add concurrent execution tests
- [ ] Add network filesystem tests
- [ ] Add container-based testing
- [ ] Add mutation testing

## Resources

- [BATS Documentation](https://github.com/bats-core/bats-core)
- [ShellCheck](https://www.shellcheck.net/)
- [GitHub Actions](https://docs.github.com/en/actions)

## Support

For issues with the test suite:
1. Check test output for specific failures
2. Run individual test files for detailed diagnostics
3. Enable BATS_DEBUG=1 for verbose output
4. Review test_helpers.bash for utility functions
5. Check GitHub Actions logs for CI failures

---

**Test Suite Version**: 1.0.0
**Last Updated**: 2025-11-10
**Maintainer**: Open Technology Foundation
