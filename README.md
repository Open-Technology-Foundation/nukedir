# nukedir

Fast Delete Large Directory Trees - Version 3.0.0

A high-performance utility for rapidly deleting extremely large directory trees where standard `rm -rf` is too slow or inefficient. Uses `rsync --delete` from an empty temporary directory for optimal performance.

## Features

- **High-speed deletion** using rsync with empty source directory technique
- **Filesystem-specific optimizations** automatically detects and optimizes for XFS, Btrfs, ext4, and other filesystems
- **Safe by default** - dry-run mode enabled by default to preview operations
- **I/O priority control** with ionice/nice for system load management (levels 0-3)
- **Timeout capability** to prevent runaway processes (supports minutes/hours notation)
- **Mount point protection** prevents accidental deletion of mounted filesystems
- **Memory optimization** automatically drops kernel caches during deletion
- **Multiple directory support** delete multiple directories in a single command
- **Wait for rsync** option to queue deletions when other rsync processes are running
- **Verbose rsync output** optional detailed progress reporting

## Requirements

- **Root privileges** or non-interactive sudo access
- **rsync** command-line tool
- **bash** shell (version 4.0+)
- **ionice** and **nice** (optional, for I/O priority control)
- **timeout** command (optional, for time limits)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/Open-Technology-Foundation/nukedir.git
   cd nukedir
   ```

2. Make the script executable:
   ```bash
   chmod +x nukedir
   ```

3. Optionally, install to system PATH:
   ```bash
   sudo cp nukedir /usr/local/bin/
   ```

4. Verify installation:
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
nukedir -wqN -i 1 /path/to/backups/2025-06-{01..04}

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

1. **Creates an empty temporary directory** in `/run` (tmpfs) or `/tmp`
2. **Uses rsync with --delete** to synchronize the target directory with the empty directory
3. **Optimizes deletion strategy** based on detected filesystem type:
   - XFS: Uses `--delete-during` for better performance
   - Btrfs: Uses `--delete-delay` with `--preallocate`
   - Others: Uses `--delete-before` with `--no-inc-recursive`
4. **Clears kernel caches** before and after deletion to free memory
5. **Removes the empty target directory** after successful deletion

This approach is significantly faster than `rm -rf` for directories containing millions of files.

## Performance Tips

- **Use ionice level 1** (`-i 1`) for fastest deletion on dedicated systems
- **Use ionice level 3** (`-i 3`) to minimize impact on other processes
- **Set appropriate timeouts** (`-T`) for very large directories to prevent hanging
- **Use quiet mode** (`-q`) with `-N` to reduce output overhead
- **Consider filesystem type** - XFS and ext4 typically perform better than Btrfs for large deletions

## Troubleshooting

### Common Issues

1. **"Requires root" error**: Run with `sudo` or as root user
2. **"Cannot execute from root directory"**: Change to a different directory before running
3. **"Cannot delete a mount point"**: Unmount the filesystem first or delete contents only
4. **Timeout errors**: Increase timeout value with `-T` option (e.g., `-T 8h`)
5. **Memory issues**: Script automatically drops caches, but ensure sufficient RAM for rsync

### Testing

```bash
# Test with dry run (safe)
./nukedir --dryrun /path/to/test/dir

# Lint check
shellcheck nukedir

# Performance test with timeout
./nukedir -T 4h --dryrun /path/to/large/dir
```

## Contributing

Contributions are welcome! Please:
1. Run `shellcheck` before submitting PRs
2. Test changes in dry-run mode first
3. Follow existing code style (2-space indentation, function naming conventions)
4. Update version number in script header for significant changes

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Author

Part of the Open Technology Foundation toolkit.

## Warning

⚠️ **This tool is extremely powerful and can permanently delete large amounts of data very quickly. Always use dry-run mode first and double-check your target directories!**

