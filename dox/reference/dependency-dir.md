# mulle-craft dependency-dir - Dependency Directory Management

## Quick Start
Manage the dependency directory where external libraries and build artifacts are stored.

## All Available Options

### Basic Usage
```bash
mulle-craft dependency-dir [command] [options]
```

**Arguments:** Command (show, set, clean, list, etc.)

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed dependency information
- `--quiet`: Show minimal dependency information
- `--dependency-dir <path>`: Specify dependency directory path

### Hidden Options
- Various dependency-specific options for different operations

## Command Behavior

### Core Functionality
- **Directory Management**: Show, set, and manage dependency directory location
- **Path Resolution**: Handle relative and absolute dependency directory paths
- **Directory Creation**: Automatically create dependency directory if needed
- **Cleanup Operations**: Remove unused dependency artifacts

### Conditional Behaviors

**Directory Sources:**
- Default: Uses standard dependency directory location
- Custom: Uses directory specified by `--dependency-dir` option
- Environment: Respects `MULLE_CRAFT_DEPENDENCY_DIR` environment variable

**Directory Operations:**
- Show: Display current dependency directory path
- Set: Change dependency directory location
- Clean: Remove unused dependency artifacts
- List: Show contents of dependency directory

## Practical Examples

### Basic Directory Management
```bash
# Show current dependency directory
mulle-craft dependency-dir show

# Set custom dependency directory
mulle-craft dependency-dir set /opt/dependencies

# Clean dependency directory
mulle-craft dependency-dir clean

# List dependency contents
mulle-craft dependency-dir list
```

### Directory Configuration
```bash
# Show detailed dependency information
mulle-craft dependency-dir show --verbose

# Set dependency directory relative to project
mulle-craft dependency-dir set ./dependencies

# Use environment variable
export MULLE_CRAFT_DEPENDENCY_DIR=/shared/deps
mulle-craft dependency-dir show
```

### Script Integration
```bash
# Ensure dependency directory exists
mulle-craft dependency-dir create
mulle-craft craftorder

# Clean old dependencies
mulle-craft dependency-dir clean
mulle-craft craftorder

# Use different dependency directories
mulle-craft dependency-dir set /tmp/deps
mulle-craft craftorder
```

## Troubleshooting

### Directory Not Found
```bash
# Dependency directory missing
mulle-craft dependency-dir show
# Error: Dependency directory not found

# Solution: Create it first
mulle-craft dependency-dir create
```

### Permission Issues
```bash
# Cannot create dependency directory
mulle-craft dependency-dir create
# Error: Permission denied

# Solution: Change to writable location
mulle-craft dependency-dir set ~/craft-deps
```

### Path Resolution Issues
```bash
# Invalid path specified
mulle-craft dependency-dir set invalid/path
# Error: Invalid dependency directory path

# Solution: Use absolute path or check permissions
mulle-craft dependency-dir set /tmp/valid-deps
```

## Integration with Other Commands

### Build Workflow
```bash
# Set up dependency directory before building
mulle-craft dependency-dir create
mulle-craft craftorder

# Use clean dependency directory for fresh builds
mulle-craft dependency-dir clean
mulle-craft craftorder
```

### Multi-Project Builds
```bash
# Different dependency directories for different projects
cd project1
mulle-craft dependency-dir set /shared/deps1
mulle-craft craftorder

cd ../project2
mulle-craft dependency-dir set /shared/deps2
mulle-craft craftorder
```

### CI/CD Integration
```bash
# Use unique dependency directory per build
BUILD_ID=$(date +%s)
mulle-craft dependency-dir set "/tmp/deps-${BUILD_ID}"
mulle-craft dependency-dir create
mulle-craft craftorder
```

## Technical Details

### Dependency Directory Structure

**Standard Layout:**
```
dependency/
├── lib/              # Built libraries
├── include/          # Header files
├── share/            # Shared resources
├── bin/              # Executables
└── pkgconfig/        # Package configuration files
```

**Project-Specific Areas:**
- **lib/**: Static and dynamic libraries (.a, .so, .dylib)
- **include/**: Public header files for dependencies
- **share/**: Documentation, examples, and other resources
- **bin/**: Executable tools from dependencies
- **pkgconfig/**: Library configuration files

### Directory Path Resolution

**Path Types:**
- **Relative**: Relative to project root (e.g., `./dependency`)
- **Absolute**: Full system path (e.g., `/usr/local/dependency`)
- **Environment**: From `MULLE_CRAFT_DEPENDENCY_DIR` variable
- **Default**: Standard location based on project structure

**Resolution Priority:**
1. Command-line `--dependency-dir` option
2. `MULLE_CRAFT_DEPENDENCY_DIR` environment variable
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
1. Identify unused dependency artifacts
2. Preserve active dependencies
3. Remove obsolete files
4. Update dependency database
5. Report cleanup results

### Configuration Files
- `craftinfo/*.craftinfo`: Dependency build information
- `dependency/.mulle-craft-cache`: Cached dependency metadata
- `dependency/installed.txt`: List of installed dependencies
- `dependency/versions.txt`: Version information for dependencies

## Related Commands

- **[`kitchen-dir`](kitchen-dir.md)** - Manage kitchen directory
- **[`craftorder`](craftorder.md)** - Build projects in order
- **[`status`](status.md)** - Check build status
- **[`clean`](clean.md)** - Clean build artifacts