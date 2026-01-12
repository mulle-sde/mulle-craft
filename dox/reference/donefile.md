# mulle-craft donefile - Build Completion Tracking

## Quick Start
Track and manage build completion status using done files.

## All Available Options

### Basic Usage
```bash
mulle-craft donefile [command] [options]
```

**Arguments:** Command (show, create, remove, clean, etc.)

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed donefile information
- `--quiet`: Show minimal donefile information
- `--donefile <path>`: Specify donefile path

### Hidden Options
- Various donefile-specific options for different operations

## Command Behavior

### Core Functionality
- **Completion Tracking**: Mark build tasks as completed
- **Status Checking**: Verify if builds are up-to-date
- **File Management**: Create, remove, and clean done files
- **Dependency Validation**: Check if dependencies have been rebuilt

### Conditional Behaviors

**File Sources:**
- Default: Uses standard donefile location
- Custom: Uses file specified by `--donefile` option
- Project: Uses project's default donefile configuration

**File Operations:**
- Show: Display current donefile status
- Create: Mark build as completed
- Remove: Clear completion status
- Clean: Remove obsolete donefiles

## Practical Examples

### Basic Completion Tracking
```bash
# Show current build status
mulle-craft donefile show

# Mark build as completed
mulle-craft donefile create

# Remove completion status
mulle-craft donefile remove

# Clean obsolete donefiles
mulle-craft donefile clean
```

### Status Checking
```bash
# Check if build is up-to-date
mulle-craft donefile show --verbose

# Check specific target completion
mulle-craft donefile show --target main

# Check dependency status
mulle-craft donefile show --dependencies
```

### Script Integration
```bash
# Build only if not up-to-date
if ! mulle-craft donefile show --quiet; then
    mulle-craft craftorder
    mulle-craft donefile create
fi

# Clean build with status reset
mulle-craft donefile remove
mulle-craft craftorder
mulle-craft donefile create
```

## Troubleshooting

### Donefile Not Found
```bash
# Donefile missing
mulle-craft donefile show
# Error: Donefile not found

# Solution: Create it first
mulle-craft donefile create
```

### Outdated Status
```bash
# Build completed but sources changed
mulle-craft donefile show
# Shows: Build completed, but sources modified

# Solution: Rebuild and update status
mulle-craft donefile remove
mulle-craft craftorder
mulle-craft donefile create
```

### Permission Issues
```bash
# Cannot create donefile
mulle-craft donefile create
# Error: Permission denied

# Solution: Change to writable location
mulle-craft donefile create --donefile /tmp/donefile
```

## Integration with Other Commands

### Build Workflow
```bash
# Incremental build with status tracking
mulle-craft donefile show
if [ $? -ne 0 ]; then
    mulle-craft craftorder
    mulle-craft donefile create
fi

# Clean rebuild
mulle-craft donefile remove
mulle-craft craftorder
mulle-craft donefile create
```

### CI/CD Integration
```bash
# Check build status in CI
mulle-craft donefile show --strict
if [ $? -ne 0 ]; then
    echo "Build required"
    mulle-craft craftorder
    mulle-craft donefile create
fi
```

### Multi-Project Builds
```bash
# Track completion across projects
cd project1
mulle-craft donefile create --project project1

cd ../project2
mulle-craft donefile create --project project2

# Check all project status
mulle-craft donefile show --all-projects
```

## Technical Details

### Donefile Structure

**Standard Format:**
```json
{
  "version": "1.0",
  "timestamp": "2025-09-03T00:05:50Z",
  "project": "myproject",
  "target": "all",
  "sources": [
    "src/main.c",
    "src/utils.c"
  ],
  "dependencies": [
    "zlib",
    "openssl"
  ],
  "build_hash": "abc123def456",
  "status": "completed"
}
```

**File Location:**
```
project/
├── .mulle/
│   └── donefile.json          # Main donefile
├── kitchen/
│   ├── donefile/             # Per-target donefiles
│   │   ├── main.done         # Main target completion
│   │   ├── test.done         # Test target completion
│   │   └── lib.done          # Library target completion
│   └── status/               # Build status files
```

### Completion Tracking

**Status Types:**
- **completed**: Build finished successfully
- **failed**: Build failed
- **outdated**: Sources changed since build
- **partial**: Some targets completed
- **unknown**: Status cannot be determined

**Validation Process:**
1. Check file timestamps
2. Compare source file hashes
3. Verify dependency versions
4. Validate build artifacts
5. Update completion status

### Configuration Files
- `donefile.json`: Main completion tracking file
- `donefile/*.done`: Per-target completion files
- `kitchen/status/*.status`: Build status information
- `kitchen/log/*.log`: Build logs with timestamps

## Related Commands

- **[`status`](status.md)** - Check build status
- **[`craftorder`](craftorder.md)** - Build projects in order
- **[`log`](log.md)** - View build logs
- **[`clean`](clean.md)** - Clean build artifacts