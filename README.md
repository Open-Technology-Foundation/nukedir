# nukedir

A utility for rapidly deleting extremely large directory trees where standard `rm -rf` is too slow or inefficient.

## Features

- **High-speed deletion** of large directory trees using rsync with empty directories
- **Filesystem-specific optimizations** for XFS, Btrfs, and other filesystems
- **Dry-run mode** enabled by default for safety
- **Priority control** with ionice/nice for performance tuning
- **Timeout capability** to prevent runaway processes
- **Mount point protection** to prevent accidental deletion of mounted filesystems

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/Open-Technology-Foundation/nukedir.git
   ```

2. Make the script executable:
   ```bash
   chmod +x nukedir
   ```

3. Optionally, move to a directory in your PATH:
   ```bash
   sudo cp nukedir /usr/local/bin/
   ```

## Usage

### Basic Usage

```bash
# Dry run (will not delete anything - default mode)
nukedir --dryrun /path/to/large/directory

# Actually delete the directory contents
nukedir --notdryrun /path/to/large/directory
```

### Advanced Options

```bash
# Set a 4-hour timeout for very large directories
nukedir -T 4h /path/to/huge/directory

# Use highest I/O priority (1) for faster deletion
nukedir -Nri 1 /path/to/large/directory

# Delete multiple directories with highest priority
nukedir -wqN -i 1 "/path/to/backups/2025-06-{01..04}"

# Wait for other rsync processes to finish before starting
nukedir --wait-for-rsync -N /path/to/directory
```

### Safety Notes

- **Always run in dry-run mode first** to see what will be deleted
- **Requires root privileges** or non-interactive sudo
- **Never run from within the root directory** (`/`)
- **Cannot delete mount points** - script has safeguards to prevent this

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Authors

Gary Dean with Claude Code 0.2.29