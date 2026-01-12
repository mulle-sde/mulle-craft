# mulle-craft addiction-dir - Addiction Directory Management

## Quick Start
Manage the addiction directory where additional dependencies and extensions are stored.

## All Available Options

### Basic Usage
```bash
mulle-craft addiction-dir [command] [options]
```

**Arguments:** Command (show, set, clean, list, etc.)

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed addiction information
- `--quiet`: Show minimal addiction information
- `--addiction-dir <path>`: Specify addiction directory path

### Hidden Options
- Various addiction-specific options for different operations

## Command Behavior

### Core Functionality
- **Directory Management**: Show, set, and manage addiction directory location
- **Path Resolution**: Handle relative and absolute addiction directory paths
- **Directory Creation**: Automatically create addiction directory if needed
- **Cleanup Operations**: Remove unused addiction artifacts

### Conditional Behaviors

**Directory Sources:**
- Default: Uses standard addiction directory location
- Custom: Uses directory specified by `--addiction-dir` option
- Environment: Respects `MULLE_CRAFT_ADDICTION_DIR` environment variable

**Directory Operations:**
- Show: Display current addiction directory path
- Set: Change addiction directory location
- Clean: Remove unused addiction artifacts
- List: Show contents of addiction directory

## Practical Examples

### Basic Directory Management
```bash
# Show current addiction directory
mulle-craft addiction-dir show

# Set custom addiction directory
mulle-craft addiction-dir set /opt/addictions

# Clean addiction directory
mulle-craft addiction-dir clean

# List addiction contents
mulle-craft addiction-dir list
```

### Directory Configuration
```bash
# Show detailed addiction information
mulle-craft addiction-dir show --verbose

# Set addiction directory relative to project
mulle-craft addiction-dir set ./addictions

# Use environment variable
export MULLE_CRAFT_ADDICTION_DIR=/shared/addictions
mulle-craft addiction-dir show
```

### Script Integration
```bash
# Ensure addiction directory exists
mulle-craft addiction-dir create
mulle-craft craftorder

# Clean old addictions
mulle-craft addiction-dir clean
mulle-craft craftorder

# Use different addiction directories
mulle-craft addiction-dir set /tmp/addictions
mulle-craft craftorder
```

## Troubleshooting

### Directory Not Found
```bash
# Addiction directory missing
mulle-craft addiction-dir show
# Error: Addiction directory not found

# Solution: Create it first
mulle-craft addiction-dir create
```

### Permission Issues
```bash
# Cannot create addiction directory
mulle-craft addiction-dir create
# Error: Permission denied

# Solution: Change to writable location
mulle-craft addiction-dir set ~/craft-addictions
```

### Path Resolution Issues
```bash
# Invalid path specified
mulle-craft addiction-dir set invalid/path
# Error: Invalid addiction directory path

# Solution: Use absolute path or check permissions
mulle-craft addiction-dir set /tmp/valid-addictions
```

## Integration with Other Commands

### Build Workflow
```bash
# Set up addiction directory before building
mulle-craft addiction-dir create
mulle-craft craftorder

# Use clean addiction directory for fresh builds
mulle-craft addiction-dir clean
mulle-craft craftorder
```

### Multi-Project Builds
```bash
# Different addiction directories for different projects
cd project1
mulle-craft addiction-dir set /shared/addictions1
mulle-craft craftorder

cd ../project2
mulle-craft addiction-dir set /shared/addictions2
mulle-craft craftorder
```

### CI/CD Integration
```bash
# Use unique addiction directory per build
BUILD_ID=$(date +%s)
mulle-craft addiction-dir set "/tmp/addictions-${BUILD_ID}"
mulle-craft addiction-dir create
mulle-craft craftorder
```

## Technical Details

### Addiction Directory Structure

**Standard Layout:**
```
addiction/
├── plugins/              # Extension plugins
├── modules/              # Additional modules
├── tools/                # Extra tools
└── config/               # Configuration files
```

**Project-Specific Areas:**
- **plugins/**: Loadable plugins and extensions
- **modules/**: Additional build modules and components
- **tools/**: Supplementary build tools and utilities
- **config/**: Configuration files for addictions

### Directory Path Resolution

**Path Types:**
- **Relative**: Relative to project root (e.g., `./addiction`)
- **Absolute**: Full system path (e.g., `/usr/local/addiction`)
- **Environment**: From `MULLE_CRAFT_ADDICTION_DIR` variable
- **Default**: Standard location based on project structure

**Resolution Priority:**
1. Command-line `--addiction-dir` option
2. `MULLE_CRAFT_ADDICTION_DIR` environment variable
3. Project-specific configuration
4. Default location

### Directory Operations

**Creation Process:**
1. Resolve target directory path
2. Check if directory exists
3. Create directory with proper permissions
4. Initialize basic structure
5. Verify write access

**Cleanup Process:**
1. Identify unused addiction artifacts
2. Preserve active addictions
3. Remove obsolete files
4. Update addiction database
5. Report cleanup results

### Configuration Files
- `addiction/manifest.txt`: List of installed addictions
- `addiction/versions.txt`: Version information for addictions
- `addiction/dependencies.txt`: Addiction dependency information
- `addiction/config/*.cfg`: Configuration files

## Related Commands

- **[`dependency-dir`](dependency-dir.md)** - Manage dependency directory
- **[`kitchen-dir`](kitchen-dir.md)** - Manage kitchen directory
- **[`craftorder`](craftorder.md)** - Build projects in order
- **[`status`](status.md)** - Check build status