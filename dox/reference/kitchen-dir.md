# mulle-craft kitchen-dir - Kitchen Directory Management

## Quick Start
Manage the kitchen directory where build artifacts and temporary files are stored.

## All Available Options

### Basic Usage
```bash
mulle-craft kitchen-dir [command] [options]
```

**Arguments:** Command (show, set, clean, etc.)

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed directory information
- `--quiet`: Show minimal directory information
- `--kitchen-dir <path>`: Specify kitchen directory path

### Hidden Options
- Various directory-specific options for different operations

## Command Behavior

### Core Functionality
- **Directory Management**: Show, set, and manage kitchen directory location
- **Path Resolution**: Handle relative and absolute kitchen directory paths
- **Directory Creation**: Automatically create kitchen directory if needed
- **Cleanup Operations**: Remove temporary files and build artifacts

### Conditional Behaviors

**Directory Sources:**
- Default: Uses standard kitchen directory location
- Custom: Uses directory specified by `--kitchen-dir` option
- Environment: Respects `MULLE_CRAFT_KITCHEN_DIR` environment variable

**Directory Operations:**
- Show: Display current kitchen directory path
- Set: Change kitchen directory location
- Clean: Remove build artifacts from kitchen
- Create: Ensure kitchen directory exists

## Practical Examples

### Basic Directory Management
```bash
# Show current kitchen directory
mulle-craft kitchen-dir show

# Set custom kitchen directory
mulle-craft kitchen-dir set /tmp/my-kitchen

# Clean kitchen directory
mulle-craft kitchen-dir clean

# Create kitchen directory if missing
mulle-craft kitchen-dir create
```

### Directory Configuration
```bash
# Show detailed kitchen information
mulle-craft kitchen-dir show --verbose

# Set kitchen relative to project
mulle-craft kitchen-dir set ./build/kitchen

# Use environment variable
export MULLE_CRAFT_KITCHEN_DIR=/tmp/craft
mulle-craft kitchen-dir show
```

### Script Integration
```bash
# Ensure kitchen exists before building
mulle-craft kitchen-dir create
mulle-craft craftorder

# Clean old builds
mulle-craft kitchen-dir clean
mulle-craft craftorder

# Use different kitchens for different builds
mulle-craft kitchen-dir set /tmp/debug-kitchen
mulle-craft qualifier set debug
mulle-craft craftorder
```

## Troubleshooting

### Directory Not Found
```bash
# Kitchen directory missing
mulle-craft kitchen-dir show
# Error: Kitchen directory not found

# Solution: Create it first
mulle-craft kitchen-dir create
```

### Permission Issues
```bash
# Cannot create kitchen directory
mulle-craft kitchen-dir create
# Error: Permission denied

# Solution: Change to writable location
mulle-craft kitchen-dir set ~/craft-kitchen
```

### Path Resolution Issues
```bash
# Invalid path specified
mulle-craft kitchen-dir set invalid/path
# Error: Invalid kitchen directory path

# Solution: Use absolute path or check permissions
mulle-craft kitchen-dir set /tmp/valid-kitchen
```

## Integration with Other Commands

### Build Workflow
```bash
# Set up kitchen before building
mulle-craft kitchen-dir create
mulle-craft craftorder

# Use clean kitchen for fresh builds
mulle-craft kitchen-dir clean
mulle-craft craftorder
```

### Multi-Project Builds
```bash
# Different kitchens for different projects
cd project1
mulle-craft kitchen-dir set /tmp/kitchen1
mulle-craft craftorder

cd ../project2
mulle-craft kitchen-dir set /tmp/kitchen2
mulle-craft craftorder
```

### CI/CD Integration
```bash
# Use unique kitchen per build
BUILD_ID=$(date +%s)
mulle-craft kitchen-dir set "/tmp/kitchen-${BUILD_ID}"
mulle-craft kitchen-dir create
mulle-craft craftorder
```

## Technical Details

### Kitchen Directory Structure

**Standard Layout:**
```
kitchen/
├── build-cc33/          # CMake build directory
├── craftinfo/           # Project build information
├── dependency/          # Dependency artifacts
├── done/               # Build completion markers
├── log/                # Build logs
└── status/             # Build status files
```

**Project-Specific Areas:**
- **build-cc33/**: CMake build files and artifacts
- **craftinfo/**: Per-project build configuration
- **dependency/**: External library build outputs
- **done/**: Completion markers for built projects
- **log/**: Build logs and error messages
- **status/**: Current build status information

### Directory Path Resolution

**Path Types:**
- **Relative**: Relative to project root (e.g., `./kitchen`)
- **Absolute**: Full system path (e.g., `/tmp/kitchen`)
- **Environment**: From `MULLE_CRAFT_KITCHEN_DIR` variable
- **Default**: Standard location based on project structure

**Resolution Priority:**
1. Command-line `--kitchen-dir` option
2. `MULLE_CRAFT_KITCHEN_DIR` environment variable
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
1. Identify files to remove
2. Preserve important artifacts
3. Remove temporary files
4. Update status information
5. Report cleanup results

### Configuration Files
- `craftorder`: Defines build order and projects
- `craftinfo/*.craftinfo`: Per-project build settings
- `kitchen/done/*.done`: Build completion markers
- `kitchen/status/*.status`: Current build status

## Related Commands

- **[`clean`](clean.md)** - Clean build artifacts
- **[`status`](status.md)** - Check build status
- **[`log`](log.md)** - View build logs
- **[`craftorder`](craftorder.md)** - Build projects in order