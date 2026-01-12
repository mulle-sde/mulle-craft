# mulle-craft libexec-dir - Libexec Directory Management

## Quick Start
Manage the libexec directory where executable tools and build scripts are stored.

## All Available Options

### Basic Usage
```bash
mulle-craft libexec-dir [command] [options]
```

**Arguments:** Command (show, set, clean, list, etc.)

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed libexec information
- `--quiet`: Show minimal libexec information
- `--libexec-dir <path>`: Specify libexec directory path

### Hidden Options
- Various libexec-specific options for different operations

## Command Behavior

### Core Functionality
- **Directory Management**: Show, set, and manage libexec directory location
- **Path Resolution**: Handle relative and absolute libexec directory paths
- **Directory Creation**: Automatically create libexec directory if needed
- **Cleanup Operations**: Remove unused libexec artifacts

### Conditional Behaviors

**Directory Sources:**
- Default: Uses standard libexec directory location
- Custom: Uses directory specified by `--libexec-dir` option
- Environment: Respects `MULLE_CRAFT_LIBEXEC_DIR` environment variable

**Directory Operations:**
- Show: Display current libexec directory path
- Set: Change libexec directory location
- Clean: Remove unused libexec artifacts
- List: Show contents of libexec directory

## Practical Examples

### Basic Directory Management
```bash
# Show current libexec directory
mulle-craft libexec-dir show

# Set custom libexec directory
mulle-craft libexec-dir set /usr/local/libexec/mulle-craft

# Clean libexec directory
mulle-craft libexec-dir clean

# List libexec contents
mulle-craft libexec-dir list
```

### Directory Configuration
```bash
# Show detailed libexec information
mulle-craft libexec-dir show --verbose

# Set libexec directory relative to project
mulle-craft libexec-dir set ./libexec

# Use environment variable
export MULLE_CRAFT_LIBEXEC_DIR=/opt/mulle/libexec
mulle-craft libexec-dir show
```

### Script Integration
```bash
# Ensure libexec directory exists
mulle-craft libexec-dir create
mulle-craft craftorder

# Clean old libexec files
mulle-craft libexec-dir clean
mulle-craft craftorder

# Use different libexec directories
mulle-craft libexec-dir set /tmp/libexec
mulle-craft craftorder
```

## Troubleshooting

### Directory Not Found
```bash
# Libexec directory missing
mulle-craft libexec-dir show
# Error: Libexec directory not found

# Solution: Create it first
mulle-craft libexec-dir create
```

### Permission Issues
```bash
# Cannot create libexec directory
mulle-craft libexec-dir create
# Error: Permission denied

# Solution: Change to writable location
mulle-craft libexec-dir set ~/mulle-libexec
```

### Path Resolution Issues
```bash
# Invalid path specified
mulle-craft libexec-dir set invalid/path
# Error: Invalid libexec directory path

# Solution: Use absolute path or check permissions
mulle-craft libexec-dir set /tmp/valid-libexec
```

## Integration with Other Commands

### Build Workflow
```bash
# Set up libexec directory before building
mulle-craft libexec-dir create
mulle-craft craftorder

# Use clean libexec directory for fresh builds
mulle-craft libexec-dir clean
mulle-craft craftorder
```

### Multi-Project Builds
```bash
# Different libexec directories for different projects
cd project1
mulle-craft libexec-dir set /shared/libexec1
mulle-craft craftorder

cd ../project2
mulle-craft libexec-dir set /shared/libexec2
mulle-craft craftorder
```

### CI/CD Integration
```bash
# Use unique libexec directory per build
BUILD_ID=$(date +%s)
mulle-craft libexec-dir set "/tmp/libexec-${BUILD_ID}"
mulle-craft libexec-dir create
mulle-craft craftorder
```

## Technical Details

### Libexec Directory Structure

**Standard Layout:**
```
libexec/
├── mulle-craft/          # Main mulle-craft executables
├── plugins/              # Plugin executables
├── tools/                # Build tools and utilities
└── scripts/              # Build scripts and helpers
```

**Project-Specific Areas:**
- **mulle-craft/**: Core mulle-craft executable and libraries
- **plugins/**: Loadable plugin executables
- **tools/**: Supplementary build tools (compilers, linkers, etc.)
- **scripts/**: Shell scripts and build automation tools

### Directory Path Resolution

**Path Types:**
- **Relative**: Relative to project root (e.g., `./libexec`)
- **Absolute**: Full system path (e.g., `/usr/local/libexec`)
- **Environment**: From `MULLE_CRAFT_LIBEXEC_DIR` variable
- **Default**: Standard location based on installation

**Resolution Priority:**
1. Command-line `--libexec-dir` option
2. `MULLE_CRAFT_LIBEXEC_DIR` environment variable
3. Project-specific configuration
4. Default installation location

### Directory Operations

**Creation Process:**
1. Resolve target directory path
2. Check if directory exists
3. Create directory with proper permissions
4. Initialize basic structure
5. Verify write access

**Cleanup Process:**
1. Identify unused libexec artifacts
2. Preserve active executables
3. Remove obsolete files
4. Update executable database
5. Report cleanup results

### Configuration Files
- `libexec/manifest.txt`: List of installed executables
- `libexec/versions.txt`: Version information for tools
- `libexec/paths.txt`: Path configuration for executables
- `libexec/config/*.cfg`: Tool-specific configuration

## Related Commands

- **[`kitchen-dir`](kitchen-dir.md)** - Manage kitchen directory
- **[`dependency-dir`](dependency-dir.md)** - Manage dependency directory
- **[`craftorder`](craftorder.md)** - Build projects in order
- **[`status`](status.md)** - Check build status