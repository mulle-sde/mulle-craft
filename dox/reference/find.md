# mulle-craft find - File and Project Discovery

## Quick Start
Find files, projects, and dependencies within the build system.

## All Available Options

### Basic Usage
```bash
mulle-craft find [options] <pattern>
```

**Arguments:** Pattern to search for (file names, project names, etc.)

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed search results
- `--quiet`: Show minimal search results
- `--type <type>`: Search for specific types (project, file, dependency)
- `--path <path>`: Search within specific directory

### Hidden Options
- Various search-specific options for different search types

## Command Behavior

### Core Functionality
- **File Discovery**: Find files by name or pattern within project
- **Project Location**: Locate project directories and configurations
- **Dependency Search**: Find dependencies and their locations
- **Pattern Matching**: Support for wildcards and regular expressions

### Conditional Behaviors

**Search Types:**
- Default: Search for files and directories
- Project: Search for project configurations
- Dependency: Search for dependency locations
- Build: Search for build artifacts

**Search Scope:**
- Local: Search within current project
- Global: Search across all known projects
- Recursive: Search subdirectories
- Shallow: Search only top-level

## Practical Examples

### Basic File Search
```bash
# Find all CMakeLists.txt files
mulle-craft find CMakeLists.txt

# Find files with specific extension
mulle-craft find "*.c"

# Find files by pattern
mulle-craft find "test_*"
```

### Project Discovery
```bash
# Find project directories
mulle-craft find --type project

# Find specific project
mulle-craft find --type project myproject

# Find projects with dependencies
mulle-craft find --type project --with-dependencies
```

### Dependency Search
```bash
# Find all dependencies
mulle-craft find --type dependency

# Find specific dependency
mulle-craft find --type dependency zlib

# Find dependency locations
mulle-craft find --type dependency --locations
```

### Advanced Search
```bash
# Search in specific directory
mulle-craft find --path src "*.h"

# Search with verbose output
mulle-craft find --verbose "main.*"

# Search for build artifacts
mulle-craft find --type build "*.o"
```

## Troubleshooting

### No Results Found
```bash
# Search pattern not found
mulle-craft find nonexistent.txt
# No matches found

# Solution: Check pattern or search scope
mulle-craft find --verbose nonexistent.txt
```

### Permission Issues
```bash
# Cannot access directory
mulle-craft find --path /restricted "*.c"
# Permission denied

# Solution: Change to accessible location
mulle-craft find --path ./src "*.c"
```

### Pattern Errors
```bash
# Invalid pattern syntax
mulle-craft find "[invalid"
# Pattern syntax error

# Solution: Fix pattern or use simple wildcard
mulle-craft find "test_*.c"
```

## Integration with Other Commands

### Build Workflow
```bash
# Find source files before building
mulle-craft find "*.c" > sources.txt
mulle-craft craftorder

# Find missing dependencies
mulle-craft find --type dependency --missing
mulle-craft craftorder
```

### Project Management
```bash
# Find all projects in workspace
mulle-craft find --type project --all
mulle-craft craftorder

# Find projects needing updates
mulle-craft find --type project --outdated
mulle-craft craftorder
```

### CI/CD Integration
```bash
# Find test files for CI
mulle-craft find "test_*.c" > test_files.txt

# Find build artifacts for deployment
mulle-craft find --type build "*.so" > artifacts.txt
```

## Technical Details

### Search Algorithms

**File Search:**
1. Parse search pattern
2. Traverse directory tree
3. Match files against pattern
4. Filter by type and permissions
5. Return matching results

**Project Search:**
1. Scan for project markers (CMakeLists.txt, etc.)
2. Check project configuration files
3. Validate project structure
4. Return project information

**Dependency Search:**
1. Query dependency database
2. Check installation status
3. Verify version compatibility
4. Return dependency details

### Pattern Matching

**Supported Patterns:**
- Wildcards: `*` (any characters), `?` (single character)
- Character classes: `[abc]` (any of a, b, c)
- Negation: `[^abc]` (none of a, b, c)
- Ranges: `[a-z]` (any lowercase letter)

**Pattern Examples:**
- `*.c`: All C source files
- `test_*.h`: All test header files
- `src/**/*.c`: All C files in src and subdirectories
- `**/CMakeLists.txt`: All CMakeLists.txt files

### Search Optimization

**Performance Features:**
- Directory pruning for irrelevant paths
- Pattern pre-compilation
- Parallel search in large directories
- Caching of frequent searches

**Memory Management:**
- Streaming results for large searches
- Limited result set sizes
- Automatic cleanup of temporary files

### Configuration Files
- `find/cache.txt`: Cached search results
- `find/patterns.txt`: Saved search patterns
- `find/excludes.txt`: Excluded paths and files
- `find/config.txt`: Search configuration settings

## Related Commands

- **[`list`](list.md)** - List projects and dependencies
- **[`status`](status.md)** - Check build status
- **[`craftorder`](craftorder.md)** - Build projects in order
- **[`searchpath`](searchpath.md)** - Manage search paths