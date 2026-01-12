# mulle-craft status - Check Build Status

## Quick Start
Display the current build status of projects in the craftorder.

## All Available Options

### Basic Usage
```bash
mulle-craft status [options]
```

**Arguments:** None

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed status information
- `--quiet`: Show minimal status information
- `--craftorder-file <file>`: Specify craftorder file path

### Hidden Options
- Various status-specific options for different output formats

## Command Behavior

### Core Functionality
- **Status Analysis**: Checks build status of all projects in craftorder
- **Dependency Tracking**: Shows which projects depend on others
- **Build State**: Indicates if projects are built, outdated, or failed
- **Progress Reporting**: Provides summary of overall build health

### Conditional Behaviors

**Status Sources:**
- Default: Checks status from craftorder file
- Custom: Uses file specified by `--craftorder-file` option
- Missing: Shows error or empty status

**Output Detail:**
- Normal: Summary status with key indicators
- Verbose: Detailed status for each project
- Quiet: Just overall status summary

## Practical Examples

### Basic Status Check
```bash
# Check status of all projects
mulle-craft status

# Check status with detailed information
mulle-craft status --verbose

# Check status from specific craftorder file
mulle-craft status --craftorder-file /path/to/craftorder
```

### Status Analysis
```bash
# Get quick overview
mulle-craft status --quiet

# Find projects that need building
mulle-craft status | grep "needs-build"

# Check specific project status
mulle-craft status --project myproject
```

### Script Integration
```bash
# Check if all projects are up-to-date
if mulle-craft status --quiet | grep -q "needs-build"; then
    echo "Some projects need building"
    mulle-craft craftorder
fi
```

## Troubleshooting

### No Status Information
```bash
# No craftorder file found
mulle-craft status
# Error: craftorder file not found

# Solution: Create craftorder file first
echo "project1
project2" > craftorder
```

### Inconsistent Status
```bash
# Status doesn't match actual build state
mulle-craft status
# Shows project as built but files are missing

# Solution: Clean and rebuild
mulle-craft clean
mulle-craft craftorder
```

### Permission Issues
```bash
# Cannot access build directories
mulle-craft status
# Error: Permission denied

# Solution: Fix permissions
chmod -R u+r kitchen/
```

## Integration with Other Commands

### Build Workflow
```bash
# Check status before building
mulle-craft status

# Build only needed projects
mulle-craft craftorder

# Verify build completion
mulle-craft status --verbose
```

### Maintenance Tasks
```bash
# Regular status monitoring
mulle-craft status --quiet

# Find failed projects
mulle-craft status | grep "failed"

# Clean outdated builds
mulle-craft status | grep "outdated" | xargs mulle-craft clean
```

### CI/CD Integration
```bash
# Status check in CI
mulle-craft status --quiet
if [ $? -ne 0 ]; then
    echo "Build status check failed"
    exit 1
fi
```

## Technical Details

### Status Indicators

**Project States:**
- **built**: Project is successfully built and up-to-date
- **needs-build**: Project source has changed, needs rebuilding
- **outdated**: Project dependencies have changed
- **failed**: Previous build attempt failed
- **missing**: Project directory or files not found

**Overall Status:**
- **all-built**: All projects are successfully built
- **some-needs-build**: Some projects need rebuilding
- **has-failures**: Some projects have build failures
- **incomplete**: Some projects are missing or incomplete

### Status Checking Process
1. **File Analysis**: Check timestamps of source files
2. **Dependency Verification**: Verify all dependencies are built
3. **Output Validation**: Check if build outputs exist
4. **State Determination**: Calculate overall project state
5. **Report Generation**: Format and display status information

### Status File Structure
```
kitchen/status/
├── project1.status
├── project2.status
└── overall.status
```

### Configuration Files
- `craftorder`: Defines which projects to check
- `craftinfo`: Per-project build configuration
- `kitchen/done/`: Build completion markers

## Related Commands

- **[`list`](list.md)** - List projects in craftorder
- **[`log`](log.md)** - View build logs
- **[`craftorder`](craftorder.md)** - Build projects in order
- **[`clean`](clean.md)** - Clean build artifacts