# mulle-craft log - View Build Logs

## Quick Start
Display build logs and output from previous build operations.

## All Available Options

### Basic Usage
```bash
mulle-craft log [options]
```

**Arguments:** None

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed log information
- `--quiet`: Show minimal log information
- `--tail`: Show only the last N lines of logs

### Hidden Options
- Various log-specific options for filtering and formatting

## Command Behavior

### Core Functionality
- **Log Discovery**: Automatically finds build log files
- **Log Display**: Shows contents of build logs with formatting
- **Log Filtering**: Can filter logs by project, time, or content
- **Log Analysis**: Provides summary and error highlighting

### Conditional Behaviors

**Log Location:**
- Default: Looks in kitchen/logs/ directory
- Custom: Can specify alternative log directories
- Missing: Shows appropriate error message

**Output Format:**
- Normal: Formatted log output with timestamps
- Verbose: Includes additional debug information
- Quiet: Shows only errors and warnings

## Practical Examples

### Basic Log Viewing
```bash
# View recent build logs
mulle-craft log

# View logs with detailed information
mulle-craft log --verbose

# View only the last 50 lines
mulle-craft log --tail 50
```

### Log Analysis
```bash
# Search for errors in logs
mulle-craft log | grep -i error

# View logs for specific project
mulle-craft log --project myproject

# View logs from last build
mulle-craft log --latest
```

### Script Integration
```bash
# Check for build errors in script
if mulle-craft log --quiet | grep -q "error"; then
    echo "Build had errors"
    mulle-craft log --tail 20
    exit 1
fi
```

## Troubleshooting

### No Logs Found
```bash
# No build logs available
mulle-craft log
# Error: No log files found

# Solution: Run a build first
mulle-craft project
mulle-craft log
```

### Log File Issues
```bash
# Log files corrupted or inaccessible
mulle-craft log
# Error: Cannot read log file

# Solution: Check permissions and rebuild
ls -la kitchen/logs/
mulle-craft clean
mulle-craft project
```

### Large Log Files
```bash
# Very large log files
mulle-craft log
# Takes too long to display

# Solution: Use tail or grep
mulle-craft log --tail 100
mulle-craft log | grep -A5 -B5 "error"
```

## Integration with Other Commands

### Build Workflow
```bash
# Build and check logs
mulle-craft project
mulle-craft log

# Clean build with log verification
mulle-craft clean
mulle-craft craftorder
mulle-craft log --verbose
```

### Error Investigation
```bash
# Find build failures
mulle-craft status
mulle-craft log | grep -i "failed\|error"

# Debug specific project
mulle-craft log --project failing-project
```

### Continuous Integration
```bash
# CI log collection
mulle-craft log --all > build.log
cat build.log | grep -c "warning"
cat build.log | grep -c "error"
```

## Technical Details

### Log File Structure

**Standard Log Location:**
```
kitchen/logs/
├── craftorder.log
├── project1.log
├── project2.log
└── build.log
```

**Log File Format:**
```
[2023-09-03 10:15:30] INFO: Starting build for project1
[2023-09-03 10:15:31] DEBUG: Configuring CMake...
[2023-09-03 10:15:35] INFO: Build successful
[2023-09-03 10:15:35] ERROR: Failed to link library
```

### Log Levels
- **DEBUG**: Detailed internal information
- **INFO**: General progress information
- **WARNING**: Potential issues that don't stop the build
- **ERROR**: Build-stopping errors
- **FATAL**: Critical errors requiring immediate attention

### Log Rotation
- Automatic log rotation based on size
- Timestamped log files for historical reference
- Compression of old log files
- Configurable retention policies

## Related Commands

- **[`project`](project.md)** - Build project (generates logs)
- **[`craftorder`](craftorder.md)** - Build multiple projects
- **[`status`](status.md)** - Check build status
- **[`clean`](clean.md)** - Clean build artifacts (including logs)