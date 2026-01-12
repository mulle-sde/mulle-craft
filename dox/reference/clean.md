# mulle-craft clean - Clean Build Artifacts

## Quick Start
Remove build artifacts, cache files, and temporary build outputs from the project.

## All Available Options

### Basic Usage
```bash
mulle-craft clean [options] [name]*
```

**Arguments:**
- `name`: Optional project name(s) to clean (all, craftorder, dependency, project, or specific project names)

### Visible Options
- `--touch`: Touch craftorder files instead of cleaning (forces recompile)
- `--no-memo-makeflags`: Disable memoization of make flags

### Hidden Options
- Various internal cleaning options for different target types

## Command Behavior

### Core Functionality
- **Directory Removal**: Safely removes specified directories using `rmdir_safer`
- **Selective Cleaning**: Can target specific projects or clean entire categories
- **Dependency Management**: Updates craftorder files to reflect cleaning
- **Build State Reset**: Removes donefiles to force rebuilds

### Conditional Behaviors

**Clean Targets:**
- `all`: Removes the entire KITCHEN_DIR
- `craftorder`: Cleans CRAFTORDER_KITCHEN_DIR
- `dependency`: Cleans DEPENDENCY_DIR
- `project`: Cleans project subdirectories in KITCHEN_DIR
- `<project-name>`: Cleans specific project build directories

**Safety Features:**
- Uses `rmdir_safer` to prevent accidental deletion
- Checks for directory existence before removal
- Preserves important configuration files
- Updates tracking files appropriately

## Practical Examples

### Basic Cleaning
```bash
# Clean entire kitchen directory
mulle-craft clean all

# Clean craftorder build artifacts
mulle-craft clean craftorder

# Clean dependency directory
mulle-craft clean dependency

# Clean project subdirectories
mulle-craft clean project
```

### Selective Cleaning
```bash
# Clean specific project
mulle-craft clean myproject

# Touch craftorder files instead of cleaning
mulle-craft clean --touch craftorder

# Clean multiple targets
mulle-craft clean dependency project
```

### Script Integration
```bash
# Clean before build in scripts
#!/bin/bash
set -e
mulle-craft clean all
mulle-craft project
```

## Troubleshooting

### Permission Issues
```bash
# Cannot remove directories due to permissions
mulle-craft clean all
# Error: Permission denied

# Solution: Fix permissions first
chmod -R u+w kitchen/
mulle-craft clean all
```

### Directory Not Found
```bash
# Target directory doesn't exist
mulle-craft clean nonexistent
# Clean target "nonexistent" is not present

# Solution: Check available targets
mulle-craft clean --help
```

### Dependency Protection
```bash
# Cannot clean protected dependency
mulle-craft clean dependency
# Error: Dependency directory is protected

# Solution: The system handles protection automatically
# Wait for clean to complete or check status
```

## Integration with Other Commands

### Build Workflow
```bash
# Standard clean-build cycle
mulle-craft clean
mulle-craft project

# Clean before multi-project build
mulle-craft clean
mulle-craft craftorder
```

### Maintenance Tasks
```bash
# Deep clean for fresh start
mulle-craft clean --all

# Clean before testing
mulle-craft clean
mulle-craft project
mulle-craft test
```

### CI/CD Integration
```bash
# Clean workspace in CI
mulle-craft clean --quiet
mulle-craft craftorder --quiet
```

## Technical Details

### Cleaned Artifacts

**Target Categories:**
- `all`: Complete KITCHEN_DIR removal
- `craftorder`: CRAFTORDER_KITCHEN_DIR cleanup
- `dependency`: DEPENDENCY_DIR removal
- `project`: Project subdirectories in KITCHEN_DIR
- `<project-name>`: Specific project build directories

**Directory Structure:**
- `kitchen/` - Main build output directory
- `dependency/` - External dependency installations
- `craftorder/` - Multi-project build coordination files

**Tracking Files:**
- Craftorder donefiles (`.mulle-craft-built`)
- Build state tracking files
- Dependency protection files

### Clean Process
1. **Target Resolution**: Determine what to clean based on arguments
2. **Directory Validation**: Check if target directories exist
3. **Safe Removal**: Use `rmdir_safer` for directory removal
4. **State Updates**: Remove/update tracking files
5. **Dependency Protection**: Temporarily unprotect dependency directories

### Safety Mechanisms
- **Selective Targeting**: Clean only specified targets
- **Existence Checks**: Skip non-existent directories
- **Safe Directory Removal**: Use specialized removal functions
- **State Synchronization**: Update build tracking appropriately

## Related Commands

- **[`project`](project.md)** - Build project (often used after clean)
- **[`craftorder`](craftorder.md)** - Build multiple projects
- **[`status`](status.md)** - Check build status
- **[`log`](log.md)** - View build logs