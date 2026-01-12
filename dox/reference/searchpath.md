# mulle-craft searchpath - Search Path Management

## Quick Start
Manage search paths for finding dependencies, libraries, and build resources.

## All Available Options

### Basic Usage
```bash
mulle-craft searchpath [command] [options]
```

**Arguments:** Command (show, add, remove, list, etc.)

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed search path information
- `--quiet`: Show minimal search path information
- `--type <type>`: Search path type (dependency, library, include, etc.)

### Hidden Options
- Various search path-specific options for different operations

## Command Behavior

### Core Functionality
- **Path Management**: Show, add, remove, and list search paths
- **Path Resolution**: Handle relative and absolute search paths
- **Path Validation**: Check if search paths exist and are accessible
- **Path Ordering**: Manage search path priority and precedence

### Conditional Behaviors

**Path Types:**
- Default: General search paths
- Dependency: Paths for finding dependencies
- Library: Paths for finding libraries
- Include: Paths for finding header files
- Binary: Paths for finding executables

**Path Operations:**
- Show: Display current search paths
- Add: Add new search path
- Remove: Remove existing search path
- List: List all configured search paths
- Validate: Check search path accessibility

## Practical Examples

### Basic Path Management
```bash
# Show current search paths
mulle-craft searchpath show

# Add new search path
mulle-craft searchpath add /opt/local/lib

# Remove search path
mulle-craft searchpath remove /usr/local/lib

# List all search paths
mulle-craft searchpath list
```

### Path Configuration
```bash
# Show detailed search path information
mulle-craft searchpath show --verbose

# Add multiple search paths
mulle-craft searchpath add /usr/local/lib
mulle-craft searchpath add /opt/homebrew/lib

# Add search path for specific type
mulle-craft searchpath add --type include /usr/local/include
```

### Script Integration
```bash
# Set up search paths before building
mulle-craft searchpath add /opt/local/lib
mulle-craft searchpath add /usr/local/lib
mulle-craft craftorder

# Clean up search paths
mulle-craft searchpath remove /tmp/build/lib
mulle-craft craftorder
```

## Troubleshooting

### Path Not Found
```bash
# Search path does not exist
mulle-craft searchpath add /nonexistent/path
# Error: Path does not exist

# Solution: Create path first or use existing path
mkdir -p /nonexistent/path
mulle-craft searchpath add /nonexistent/path
```

### Permission Issues
```bash
# Cannot access search path
mulle-craft searchpath add /restricted/path
# Error: Permission denied

# Solution: Change to accessible location
mulle-craft searchpath add ~/local/lib
```

### Path Resolution Issues
```bash
# Invalid path format
mulle-craft searchpath add "invalid path"
# Error: Invalid path format

# Solution: Use proper path format
mulle-craft searchpath add /valid/path
```

## Integration with Other Commands

### Build Workflow
```bash
# Configure search paths before building
mulle-craft searchpath add /opt/local/lib
mulle-craft searchpath add /usr/local/include
mulle-craft craftorder

# Use different search paths for different builds
mulle-craft searchpath add --type library /custom/libs
mulle-craft craftorder
```

### Multi-Project Builds
```bash
# Different search paths for different projects
cd project1
mulle-craft searchpath add /project1/libs
mulle-craft craftorder

cd ../project2
mulle-craft searchpath add /project2/libs
mulle-craft craftorder
```

### CI/CD Integration
```bash
# Set up search paths in CI environment
export CUSTOM_LIB_PATH=/ci/libs
mulle-craft searchpath add $CUSTOM_LIB_PATH
mulle-craft searchpath validate
mulle-craft craftorder
```

## Technical Details

### Search Path Types

**System Paths:**
- `/usr/lib`: Standard system libraries
- `/usr/local/lib`: Local system libraries
- `/opt/local/lib`: Optional software libraries

**Project Paths:**
- `./lib`: Project local libraries
- `../shared/lib`: Shared project libraries
- `/opt/project/lib`: Project-specific libraries

**Environment Paths:**
- `LD_LIBRARY_PATH`: Dynamic library search paths
- `LIBRARY_PATH`: Static library search paths
- `CPATH`: Header file search paths

### Path Resolution Algorithm

**Resolution Order:**
1. Explicit command-line paths
2. Environment variable paths
3. Project configuration paths
4. System default paths
5. Fallback search paths

**Path Validation:**
1. Check if path exists
2. Verify read permissions
3. Test path accessibility
4. Validate path format
5. Check for duplicates

### Configuration Files
- `searchpath/config.txt`: Main search path configuration
- `searchpath/types/*.txt`: Type-specific search paths
- `searchpath/cache.txt`: Cached search path information
- `searchpath/validation.log`: Path validation results

## Related Commands

- **[`find`](find.md)** - Find files and projects
- **[`dependency-dir`](dependency-dir.md)** - Manage dependency directory
- **[`libexec-dir`](libexec-dir.md)** - Manage libexec directory
- **[`craftorder`](craftorder.md)** - Build projects in order