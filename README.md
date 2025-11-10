# nukedir

Fast Delete Large Directory Trees - Version 3.1.0

A high-performance utility for rapidly deleting extremely large directory trees where standard `rm -rf` is too slow or inefficient. Uses `rsync --delete` from an empty temporary directory for optimal performance.

## Features

- **High-speed deletion** using rsync with empty source directory technique
- **Filesystem-specific optimizations** automatically detects and optimizes for XFS, Btrfs, ext4, and other filesystems
- **Safe by default** - dry-run mode enabled by default to preview operations
- **I/O priority control** with ionice/nice for system load management (levels 0-3)
- **Timeout capability** to prevent runaway processes (supports minutes/hours notation)
- **Mount point protection** prevents accidental deletion of mounted filesystems
- **Memory optimization** drops kernel caches before deletion (non-dry-run mode only)
- **Multiple directory support** delete multiple directories in a single command
- **Wait for rsync** option to queue deletions when other rsync processes are running
- **Verbose rsync output** optional detailed progress reporting
- **Standardized output icons** visual status indicators (◉ info, ▲ warning, ✓ success, ✗ error)

## Requirements

- **Root privileges** or non-interactive sudo access
- **rsync** command-line tool
- **bash** shell (version 4.0+)
- **ionice** and **nice** (optional, for I/O priority control)
- **timeout** command (optional, for time limits)

## Installation

### Quick Install (One-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/Open-Technology-Foundation/nukedir/main/install.sh | sudo bash
```

Or with wget:
```bash
wget -qO- https://raw.githubusercontent.com/Open-Technology-Foundation/nukedir/main/install.sh | sudo bash
```

### Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/Open-Technology-Foundation/nukedir.git
   cd nukedir
   ```

2. Run the installer:
   ```bash
   sudo ./install.sh
   ```

### What Gets Installed

- `nukedir` script → `/usr/local/bin/nukedir`
- Bash completion → `/etc/bash_completion.d/nukedir`

### Uninstall

```bash
sudo ./install.sh --uninstall
```

### Verify Installation

```bash
nukedir --version
```

## Usage

```bash
nukedir [OPTIONS] dirname [dirname ...]
```

### Basic Examples

```bash
# Dry run (default - shows what would be deleted without actually deleting)
nukedir /path/to/large/directory

# Actually delete the directory (requires explicit --notdryrun)
nukedir --notdryrun /path/to/large/directory

# Delete with quiet mode (minimal output)
nukedir -qN /path/to/directory
```

### Advanced Examples

```bash
# Set a 4-hour timeout for extremely large directories
nukedir -T 4h --notdryrun /path/to/huge/directory

# Use highest I/O priority (1) for faster deletion, verbose rsync output
nukedir -Nri 1 /path/to/large/directory

# Delete multiple directories with high priority, quiet mode
nukedir -wqN -i 1 /backups/old/set-{01..04}

# Wait for other rsync processes to finish before starting
nukedir --wait-for-rsync -N /path/to/directory

# Verbose rsync output to monitor progress
nukedir -rN /path/to/directory
```

### Command Line Options

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-n` | `--dryrun` | Dry run mode (no actual deletion) | **Enabled** |
| `-N` | `--notdryrun` | Execute actual deletion | Disabled |
| `-T` | `--timeout N` | Maximum runtime (e.g., 2m, 4h) | No timeout |
| `-i` | `--ionice 0-3` | I/O priority (0=none, 1=highest, 3=lowest) | 0 |
| `-w` | `--wait-for-rsync` | Wait for other rsync processes | Disabled |
| `-r` | `--rsync-verbose` | Extra verbose rsync output | Disabled |
| `-v` | `--verbose` | Verbose output | **Enabled** |
| `-q` | `--quiet` | Suppress output (recommended with -N) | Disabled |
| `-V` | `--version` | Display version and exit | - |
| `-h` | `--help` | Display help and exit | - |

### Safety Features

- **Default dry-run mode** - Must explicitly use `-N` or `--notdryrun` to delete
- **Root directory protection** - Cannot run from or target root directory (`/`)
- **Mount point protection** - Refuses to delete mount points
- **Directory validation** - Verifies targets exist and are directories
- **Process warnings** - Warns if other rsync processes are running

## How It Works

nukedir uses an efficient technique for deleting large directory trees:

1. **Creates an empty temporary directory** (BITBIN):
   - Preferably in `/run` (tmpfs) for best performance
   - Falls back to `/tmp` if `/run` is not available or not tmpfs

2. **Detects the filesystem type** using `df -PT` to optimize deletion strategy

3. **Applies filesystem-specific optimizations**:
   - **XFS**: Uses `--delete-during` for optimal performance with XFS's allocation groups
   - **Btrfs**: Uses `--delete-delay` with `--preallocate` for better B-tree handling
   - **Other filesystems** (ext4, etc.): Uses `--delete-before` with `--no-inc-recursive` and `--inplace`

4. **Memory optimization** (non-dry-run mode only):
   - Drops kernel caches before deletion using `sync && echo 3 > /proc/sys/vm/drop_caches`
   - This frees memory and improves deletion performance

5. **Uses rsync with --delete** to synchronize the target directory with the empty BITBIN directory, effectively deleting all contents

6. **Removes the empty target directory** with `rmdir` after successful deletion

This approach is significantly faster than `rm -rf` for directories containing millions of files, particularly on filesystems like XFS and ext4 where rsync's batched deletion is more efficient than recursive unlinking.

## Output Icons

nukedir uses standardized visual status indicators:

- **◉** Info - General information messages
- **▲** Warning - Important warnings that don't stop execution
- **✓** Success - Successful operation completion
- **✗** Error - Error messages

These icons are color-coded when running in a terminal (info=cyan, warning=yellow, success=green, error=red).

## Performance Tips

- **Use ionice level 1** (`-i 1`) for fastest deletion on dedicated systems
- **Use ionice level 3** (`-i 3`) to minimize impact on other processes
- **Set appropriate timeouts** (`-T`) for very large directories to prevent hanging
- **Use quiet mode** (`-q`) with `-N` to reduce output overhead
- **Consider filesystem type** - XFS and ext4 typically perform better than Btrfs for large deletions
- **Ensure sufficient RAM** - While the script clears kernel caches, rsync still needs memory to operate
- **Use /run for BITBIN** - The script automatically prefers tmpfs-backed /run for better performance

## Troubleshooting

### Common Issues

1. **"Requires root" error**: Run with `sudo` or as root user
2. **"Cannot execute from root directory"**: Change to a different directory before running
3. **"Cannot delete a mount point"**: Unmount the filesystem first or delete contents only
4. **Timeout errors**: Increase timeout value with `-T` option (e.g., `-T 8h`)
5. **Memory issues**: Script automatically drops caches in non-dry-run mode, but ensure sufficient RAM for rsync
6. **Other rsync processes running**: Use `-w` to wait for them to finish, or proceed with caution

### Testing

nukedir includes a comprehensive test suite using BATS (Bash Automated Testing System).

#### Test Suite Structure

```
tests/
├── unit/              # Function-level tests (basic, validation, filesystem)
├── integration/       # End-to-end deletion tests
├── safety/            # Security and protection mechanism tests
├── performance/       # Performance benchmarks (optional)
├── fixtures/          # Test data generators
├── helpers/           # Test utilities and helpers
└── run-all-tests.sh   # Main test runner
```

#### Running Tests

**Prerequisites:**
```bash
# Install BATS
sudo apt-get install bats  # Ubuntu/Debian
brew install bats-core     # macOS

# Install shellcheck (recommended)
sudo apt-get install shellcheck
```

**Run all tests:**
```bash
sudo ./tests/run-all-tests.sh
```

**Run specific test categories:**
```bash
sudo ./tests/run-all-tests.sh --unit         # Unit tests only
sudo ./tests/run-all-tests.sh --integration  # Integration tests only
sudo ./tests/run-all-tests.sh --safety       # Safety tests only
sudo ./tests/run-all-tests.sh --shellcheck   # Shellcheck only
```

**Run performance tests (skipped by default):**
```bash
PERF_TESTS=1 sudo ./tests/run-all-tests.sh --performance
```

**Run stress tests (manual only):**
```bash
STRESS_TESTS=1 sudo ./tests/run-all-tests.sh --performance
```

#### Test Categories

1. **Unit Tests** (tests/unit/)
   - Basic functionality (version, help, options)
   - Input validation (paths, arguments)
   - Filesystem detection and optimization

2. **Integration Tests** (tests/integration/)
   - Actual deletion operations (controlled environment)
   - Multiple directory handling
   - ionice/timeout integration
   - Dry-run vs. actual deletion

3. **Safety Tests** (tests/safety/)
   - Root directory protection
   - Mount point protection
   - Permission validation
   - Default dry-run enforcement

4. **Performance Tests** (tests/performance/)
   - Deletion speed benchmarks
   - Filesystem comparison
   - ionice level impact
   - Memory and CPU usage

#### Manual Testing

```bash
# Quick functionality test (safe)
./nukedir --dryrun /path/to/test/dir

# Lint check
shellcheck nukedir

# Performance test with timeout
./nukedir -T 4h --dryrun /path/to/large/dir
```

#### Continuous Integration

Tests run automatically on GitHub Actions for:
- Every push to main/develop branches
- All pull requests
- Multiple Ubuntu versions (20.04, 22.04, 24.04)

See `.github/workflows/test.yml` for CI configuration.

## I/O Priority Levels

The `-i` / `--ionice` option controls system resource usage:

- **0** (default): No I/O priority adjustment
- **1**: Highest priority (`nice -n -19` + `ionice -c1 -n0`) - fastest deletion, may impact other processes
- **2**: Medium priority
- **3**: Lowest priority - minimal impact on other processes, slower deletion

## Contributing

Contributions are welcome! Please:
1. **Run the test suite** before submitting PRs:
   ```bash
   sudo ./tests/run-all-tests.sh
   ```
2. **Run shellcheck** to ensure code quality:
   ```bash
   shellcheck nukedir
   ```
3. **Test changes in dry-run mode** first for safety
4. **Add tests** for new features or bug fixes
5. **Follow existing code style** (2-space indentation, BCS-compliant bash)
6. **Update version number** in script header for significant changes
7. **Update README** if adding new features or changing behavior

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Author

Part of the Open Technology Foundation toolkit.

## Warning

⚠️ **This tool is extremely powerful and can permanently delete large amounts of data very quickly. Always use dry-run mode first and double-check your target directories!**
