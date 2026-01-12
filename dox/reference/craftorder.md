# mulle-craft craftorder - Build Using Craftorder File

## Quick Start
Build multiple projects in the order specified by a craftorder file.

## All Available Options

### Basic Usage
```bash
mulle-craft craftorder [options] [-- [mulle-make options]]
```

**Arguments:** None

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed build information
- `--quiet`: Show minimal build information
- `--craftorder-file <file>`: Specify craftorder file path

### Hidden Options
- Various build-specific options passed to mulle-make
- Configuration options for multi-project builds

## Command Behavior

### Core Functionality
- **Craftorder Detection**: Automatically finds craftorder file in project
- **Dependency Ordering**: Builds projects in dependency order
- **Parallel Building**: Can build independent projects simultaneously
- **Error Handling**: Stops on first failure or continues based on configuration

### Conditional Behaviors

**Craftorder File:**
- Default: Looks for `craftorder` file in current directory
- Custom: Uses file specified by `--craftorder-file` option
- Missing: Fails with error message

**Build Strategy:**
- Sequential: Builds projects one after another
- Parallel: Builds independent projects concurrently
- Fail-fast: Stops on first build failure

## Practical Examples

### Basic Craftorder Building
```bash
# Build using default craftorder file
mulle-craft craftorder

# Build with custom craftorder file
mulle-craft craftorder --craftorder-file /path/to/craftorder

# Build with verbose output
mulle-craft craftorder --verbose
```

### Multi-Project Workflow
```bash
# Build all projects in craftorder
mulle-craft craftorder

# Check what will be built
mulle-craft list

# Clean all projects first
mulle-craft clean
mulle-craft craftorder
```

### Script Integration
```bash
# Use in CI/CD scripts
#!/bin/bash
set -e
mulle-craft craftorder --quiet
echo "All projects built successfully"
```

## Troubleshooting

### Missing Craftorder File
```bash
# No craftorder file found
mulle-craft craftorder
# Error: craftorder file not found

# Solution: Create craftorder file or specify path
echo "project1
project2" > craftorder
mulle-craft craftorder
```

### Build Failures
```bash
# Check which project failed
mulle-craft list

# View logs for failed project
mulle-craft log

# Clean and retry
mulle-craft clean
mulle-craft craftorder
```

### Dependency Issues
```bash
# Check project status
mulle-craft status

# Find missing dependencies
mulle-craft find <missing-item>

# Verify craftorder file
cat craftorder
```

## Integration with Other Commands

### Build Management
```bash
# Full multi-project cycle
mulle-craft clean
mulle-craft craftorder
mulle-craft status
```

### Monitoring and Debugging
```bash
# Monitor build progress
mulle-craft list

# View build logs
mulle-craft log

# Check final status
mulle-craft status
```

### Single Project Comparison
```bash
# Build single project
mulle-craft project

# Build all projects
mulle-craft craftorder
```

## Technical Details

### Craftorder File Format
```
# Comments start with #
project1
project2
# project3 (commented out)
```

### Build Process
1. **Parse Craftorder**: Read and validate craftorder file
2. **Dependency Analysis**: Determine build order and dependencies
3. **Build Execution**: Execute builds in correct order
4. **Status Tracking**: Monitor and report build progress
5. **Error Handling**: Handle failures and cleanup

### Build Directory Structure
```
kitchen/
├── craftorder/
│   ├── project1/
│   ├── project2/
│   └── logs/
└── dependency/
```

### Configuration Files
- `craftorder`: List of projects to build
- `craftinfo`: Per-project build configuration
- `CMakeLists.txt`: Build system configuration

## Related Commands

- **[`project`](project.md)** - Build single project
- **[`list`](list.md)** - List projects in craftorder
- **[`clean`](clean.md)** - Clean build artifacts
- **[`log`](log.md)** - View build logs
- **[`status`](status.md)** - Check build status