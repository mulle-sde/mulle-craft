# mulle-craft tool-env - Tool Environment Management

## Quick Start
Manage environment variables and settings for build tools.

## All Available Options

### Basic Usage
```bash
mulle-craft tool-env [command] [options]
```

**Arguments:** Command (show, set, unset, list, etc.)

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed environment information
- `--quiet`: Show minimal environment information
- `--tool <name>`: Specify tool name

### Hidden Options
- Various environment-specific options for different operations

## Command Behavior

### Core Functionality
- **Environment Variables**: Show, set, and manage tool environment variables
- **Tool Configuration**: Configure settings for specific build tools
- **Path Management**: Handle tool executable paths and library paths
- **Configuration Persistence**: Save and restore tool configurations

### Conditional Behaviors

**Environment Sources:**
- Default: Uses system environment variables
- Tool-specific: Uses tool-specific environment settings
- Project: Uses project-specific environment configuration
- Global: Uses global mulle-craft environment settings

**Variable Operations:**
- Show: Display current environment variables
- Set: Set environment variable value
- Unset: Remove environment variable
- List: List all configured variables

## Practical Examples

### Basic Environment Management
```bash
# Show current environment
mulle-craft tool-env show

# Set environment variable
mulle-craft tool-env set CC=clang

# Unset environment variable
mulle-craft tool-env unset CC

# List all variables
mulle-craft tool-env list
```

### Tool-Specific Configuration
```bash
# Show tool-specific environment
mulle-craft tool-env show --tool clang

# Set compiler flags
mulle-craft tool-env set CFLAGS="-O2 -Wall"

# Configure linker
mulle-craft tool-env set LDFLAGS="-L/usr/local/lib"
```

### Script Integration
```bash
# Set up build environment
mulle-craft tool-env set CC=clang
mulle-craft tool-env set CXX=clang++
mulle-craft craftorder

# Clean environment
mulle-craft tool-env unset CC
mulle-craft tool-env unset CXX
```

## Troubleshooting

### Variable Not Set
```bash
# Environment variable not found
mulle-craft tool-env show CC
# Error: Variable CC not set

# Solution: Set it first
mulle-craft tool-env set CC=gcc
```

### Permission Issues
```bash
# Cannot modify environment
mulle-craft tool-env set PATH=/new/path
# Error: Permission denied

# Solution: Use user-writable location
mulle-craft tool-env set PATH=$HOME/bin:$PATH
```

### Invalid Variable Name
```bash
# Invalid environment variable name
mulle-craft tool-env set "invalid name"=value
# Error: Invalid variable name

# Solution: Use valid variable name
mulle-craft tool-env set MY_VAR=value
```

## Integration with Other Commands

### Build Workflow
```bash
# Configure build environment
mulle-craft tool-env set CMAKE_BUILD_TYPE=Release
mulle-craft tool-env set MAKEFLAGS="-j4"
mulle-craft craftorder

# Use different compilers
mulle-craft tool-env set CC=gcc
mulle-craft craftorder

mulle-craft tool-env set CC=clang
mulle-craft craftorder
```

### Cross-Compilation
```bash
# Set up cross-compilation environment
mulle-craft tool-env set CC=arm-linux-gcc
mulle-craft tool-env set CXX=arm-linux-g++
mulle-craft tool-env set AR=arm-linux-ar
mulle-craft craftorder
```

### CI/CD Integration
```bash
# Configure CI environment
export CI_BUILD=true
mulle-craft tool-env set CMAKE_BUILD_TYPE=Debug
mulle-craft tool-env set CTEST_OUTPUT_ON_FAILURE=1
mulle-craft craftorder
```

## Technical Details

### Environment Variable Types

**Build Variables:**
- `CC`: C compiler
- `CXX`: C++ compiler
- `CFLAGS`: C compiler flags
- `CXXFLAGS`: C++ compiler flags
- `LDFLAGS`: Linker flags

**Tool Variables:**
- `MAKE`: Make program
- `CMAKE`: CMake program
- `CTEST`: CTest program
- `NINJA`: Ninja build system

**Path Variables:**
- `PATH`: Executable search path
- `LD_LIBRARY_PATH`: Library search path
- `PKG_CONFIG_PATH`: pkg-config search path

### Variable Resolution

**Resolution Order:**
1. Command-line options
2. Tool-specific environment
3. Project configuration
4. System environment
5. Default values

**Variable Scoping:**
- Global: Available to all tools
- Tool-specific: Only for specific tool
- Project-specific: Only for current project
- Session-specific: Only for current session

### Configuration Files
- `tool-env/config.txt`: Main environment configuration
- `tool-env/tools/*.txt`: Tool-specific configurations
- `tool-env/variables/*.txt`: Variable definitions
- `tool-env/profiles/*.txt`: Environment profiles

## Related Commands

- **[`craftorder`](craftorder.md)** - Build projects in order
- **[`status`](status.md)** - Check build status
- **[`style`](style.md)** - Manage build styles
- **[`qualifier`](qualifier.md)** - Manage build qualifiers