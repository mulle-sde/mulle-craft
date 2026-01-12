# mulle-craft list - List Projects in Craftorder

## Quick Start
Display the list of projects that will be built according to the craftorder file.

## All Available Options

### Basic Usage
```bash
mulle-craft list [options]
```

**Arguments:** None

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed project information
- `--quiet`: Show minimal project information
- `--craftorder-file <file>`: Specify craftorder file path

### Hidden Options
- Various listing-specific options for different output formats

## Command Behavior

### Core Functionality
- **Craftorder Reading**: Parses the craftorder file to extract project list
- **Project Validation**: Verifies that listed projects exist and are accessible
- **Dependency Analysis**: Shows project relationships and build order
- **Status Display**: Indicates which projects are ready for building

### Conditional Behaviors

**Craftorder File:**
- Default: Uses `craftorder` file in current directory
- Custom: Uses file specified by `--craftorder-file` option
- Missing: Shows error or empty list

**Output Detail:**
- Normal: Project names with basic status
- Verbose: Detailed information about each project
- Quiet: Just project names, one per line

## Practical Examples

### Basic Project Listing
```bash
# List projects in default craftorder
mulle-craft list

# List projects with detailed information
mulle-craft list --verbose

# List projects from specific craftorder file
mulle-craft list --craftorder-file /path/to/craftorder
```

### Script Integration
```bash
# Get project count
PROJECT_COUNT=$(mulle-craft list --quiet | wc -l)
echo "Found $PROJECT_COUNT projects"

# Check if specific project is in craftorder
if mulle-craft list --quiet | grep -q "myproject"; then
    echo "myproject is in craftorder"
fi
```

### Build Planning
```bash
# Review projects before building
mulle-craft list --verbose

# Check project status
mulle-craft status
mulle-craft list
```

## Troubleshooting

### Missing Craftorder File
```bash
# No craftorder file found
mulle-craft list
# Error: craftorder file not found

# Solution: Create craftorder file first
echo "project1
project2" > craftorder
```

### Invalid Projects
```bash
# Project not found
mulle-craft list
# Warning: project 'missing-project' not found

# Solution: Fix craftorder file
editor craftorder
```

### Permission Issues
```bash
# Cannot read craftorder file
mulle-craft list
# Error: Permission denied

# Solution: Fix permissions
chmod 644 craftorder
```

## Integration with Other Commands

### Build Workflow
```bash
# Check what will be built
mulle-craft list

# Build all listed projects
mulle-craft craftorder

# Verify build completion
mulle-craft list --verbose
```

### Project Management
```bash
# Add project to craftorder
echo "newproject" >> craftorder
mulle-craft list

# Remove project from craftorder
sed -i '/oldproject/d' craftorder
mulle-craft list
```

### Status Monitoring
```bash
# Monitor build progress
mulle-craft list
mulle-craft craftorder &
watch mulle-craft list
```

## Technical Details

### Craftorder File Format
```
# Comments start with #
project1
project2
# project3 (commented out)
```

### Project Information Displayed

**Basic Mode:**
```
project1
project2
project3
```

**Verbose Mode:**
```
project1:
  Path: /path/to/project1
  Status: ready
  Dependencies: lib1, lib2

project2:
  Path: /path/to/project2
  Status: needs-build
  Dependencies: project1
```

### Project Status Indicators
- **ready**: Project is built and up-to-date
- **needs-build**: Project needs to be built
- **missing**: Project directory not found
- **invalid**: Project configuration is invalid

### Listing Process
1. **File Reading**: Read and parse craftorder file
2. **Project Discovery**: Locate each project directory
3. **Status Checking**: Verify project build status
4. **Dependency Analysis**: Determine build relationships
5. **Output Formatting**: Format and display results

## Related Commands

- **[`craftorder`](craftorder.md)** - Build projects in listed order
- **[`status`](status.md)** - Check detailed project status
- **[`log`](log.md)** - View build logs for listed projects
- **[`find`](find.md)** - Find projects in craftorder