# mulle-craft project - Craft Main Project

## Quick Start
Build the main project in the current directory using mulle-make.

## All Available Options

### Basic Usage
```bash
mulle-craft project [options] [-- [mulle-make options]]
```

**Arguments:** None

### Visible Options
- Options are passed through to mulle-make
- No command-specific options (uses mulle-make options)

### Hidden Options
- Various build-specific options passed to mulle-make
- Configuration options for build process

## Command Behavior

### Core Functionality
- **Project Detection**: Automatically detects project in current directory
- **Dependency Building**: Builds all required dependencies first
- **Main Build**: Executes mulle-make on the main project
- **Output Management**: Manages build artifacts and logs

### Conditional Behaviors

**Build Context:**
- With craftorder: Builds only the main project
- Without craftorder: Builds project and its dependencies
- Environment detection: Adapts to mulle-sde environment

**Output Control:**
- Normal mode: Standard build output
- Verbose mode: Detailed build information
- Quiet mode: Minimal output for scripting

## Practical Examples

### Basic Project Building
```bash
# Build the current project
mulle-craft project

# Build with verbose output
mulle-craft project --verbose

# Build with custom mulle-make options
mulle-craft project -- --clean-first
```

### Environment Integration
```bash
# Build in mulle-sde environment
cd /path/to/project
mulle-craft project

# Build with specific configuration
mulle-craft project -- --configuration Release
```

### Script Integration
```bash
# Use in build scripts
#!/bin/bash
set -e
mulle-craft project --quiet
echo "Build completed successfully"
```

## Troubleshooting

### Build Failures
```bash
# Check for missing dependencies
mulle-craft project --verbose

# Clean and retry
mulle-craft clean
mulle-craft project
```

### Configuration Issues
```bash
# Check project configuration
ls -la
cat craftinfo 2>/dev/null || echo "No craftinfo found"

# Verify mulle-make availability
which mulle-make
```

### Permission Issues
```bash
# Fix build directory permissions
chmod -R u+w kitchen/
mulle-craft project
```

## Integration with Other Commands

### Build Workflow
```bash
# Full build cycle
mulle-craft clean
mulle-craft project
mulle-craft status
```

### Dependency Management
```bash
# Check dependencies before building
mulle-craft status
mulle-craft project
```

### Multi-Project Building
```bash
# Build single project
mulle-craft project

# Compare with craftorder approach
mulle-craft craftorder
```

## Technical Details

### Build Process
1. **Environment Setup**: Initialize build environment
2. **Dependency Check**: Verify all dependencies are available
3. **Build Execution**: Run mulle-make with appropriate options
4. **Artifact Management**: Handle build outputs and logs
5. **Status Reporting**: Report build success/failure

### Build Directory Structure
```
kitchen/
├── build/
│   └── [project-name]/
├── dependency/
└── logs/
```

### Configuration Files
- `craftinfo`: Project build configuration
- `CMakeLists.txt`: CMake build configuration
- `Makefile`: Make build configuration

## Related Commands

- **[`craftorder`](craftorder.md)** - Build using craftorder file
- **[`clean`](clean.md)** - Clean build artifacts
- **[`status`](status.md)** - Check build status
- **[`log`](log.md)** - View build logs