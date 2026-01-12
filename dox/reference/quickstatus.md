# mulle-craft quickstatus - Quick Build Status Check

## Quick Start
Get a fast overview of the build status without detailed analysis.

## All Available Options

### Basic Usage
```bash
mulle-craft quickstatus [options]
```

**Arguments:** None

### Visible Options
- `--help`: Show usage information
- `--quiet`: Show minimal status information
- `--craftorder-file <file>`: Specify craftorder file path

### Hidden Options
- Various quick status-specific options

## Command Behavior

### Core Functionality
- **Fast Status Check**: Quickly determines overall build health
- **Minimal Analysis**: Skips detailed dependency checking
- **Summary Output**: Provides high-level status overview
- **Exit Codes**: Returns status codes for scripting

### Conditional Behaviors

**Status Sources:**
- Default: Uses craftorder file for project list
- Custom: Uses file specified by `--craftorder-file` option
- Missing: Shows error or empty status

**Output Detail:**
- Normal: Brief status summary
- Quiet: Only exit code, no output

## Practical Examples

### Basic Quick Status
```bash
# Quick status check
mulle-craft quickstatus

# Quiet status check for scripts
mulle-craft quickstatus --quiet
```

### Script Integration
```bash
# Check if build is needed
if mulle-craft quickstatus --quiet; then
    echo "All projects are up-to-date"
else
    echo "Some projects need attention"
    mulle-craft status  # Get detailed status
fi
```

### CI/CD Integration
```bash
# Fast CI status check
mulle-craft quickstatus --quiet
if [ $? -eq 0 ]; then
    echo "✅ Build status OK"
else
    echo "❌ Build issues detected"
    exit 1
fi
```

## Troubleshooting

### No Projects Found
```bash
# Empty craftorder file
mulle-craft quickstatus
# Shows "no projects found"

# Solution: Add projects to craftorder
echo "myproject" > craftorder
```

### Permission Issues
```bash
# Cannot access status files
mulle-craft quickstatus
# Error: Permission denied

# Solution: Fix permissions
chmod -R u+r kitchen/
```

## Integration with Other Commands

### Build Workflow
```bash
# Quick check before detailed status
mulle-craft quickstatus
if [ $? -ne 0 ]; then
    mulle-craft status --verbose
fi

# Fast CI pipeline
mulle-craft quickstatus --quiet || mulle-craft craftorder
```

### Monitoring Scripts
```bash
# Continuous monitoring
while true; do
    if ! mulle-craft quickstatus --quiet; then
        echo "Build status changed"
        mulle-craft status
    fi
    sleep 60
done
```

## Technical Details

### Quick Status Algorithm

**Fast Path:**
1. Check if craftorder file exists
2. Verify basic project directory structure
3. Check for presence of build outputs
4. Return summary status

**Performance Optimizations:**
- Skips detailed dependency analysis
- Uses cached status when available
- Minimal file system operations
- Fast exit on first failure found

### Status Codes

**Exit Codes:**
- `0`: All projects are successfully built
- `1`: Some projects need building
- `2`: Some projects have build failures
- `3`: Configuration or file access errors

### Quick vs Full Status

**Quick Status:**
- Fast execution (seconds)
- Basic health check
- Suitable for monitoring
- Minimal resource usage

**Full Status:**
- Detailed analysis (longer)
- Complete dependency checking
- Troubleshooting information
- Higher resource usage

## Related Commands

- **[`status`](status.md)** - Detailed build status check
- **[`list`](list.md)** - List projects in craftorder
- **[`craftorder`](craftorder.md)** - Build projects in order
- **[`log`](log.md)** - View build logs