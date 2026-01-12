# mulle-craft craftorder-kitchen-dir - Craftorder Kitchen Directory Management

## Quick Start
Manage the craftorder file and build configuration in the kitchen directory.

## All Available Options

### Basic Usage
```bash
mulle-craft craftorder-kitchen-dir [command] [options]
```

**Arguments:** Command (show, edit, validate, etc.)

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed craftorder information
- `--quiet`: Show minimal craftorder information
- `--craftorder-file <path>`: Specify craftorder file path

### Hidden Options
- Various craftorder-specific options for different operations

## Command Behavior

### Core Functionality
- **Craftorder Management**: Show, edit, and validate craftorder files
- **Build Configuration**: Manage build order and project dependencies
- **File Resolution**: Handle craftorder file paths and locations
- **Validation Operations**: Check craftorder file syntax and consistency

### Conditional Behaviors

**File Sources:**
- Default: Uses craftorder file in kitchen directory
- Custom: Uses file specified by `--craftorder-file` option
- Project: Uses project's default craftorder configuration

**File Operations:**
- Show: Display current craftorder contents
- Edit: Modify craftorder file
- Validate: Check craftorder syntax and dependencies
- Generate: Create new craftorder from project structure

## Practical Examples

### Basic Craftorder Management
```bash
# Show current craftorder
mulle-craft craftorder-kitchen-dir show

# Edit craftorder file
mulle-craft craftorder-kitchen-dir edit

# Validate craftorder syntax
mulle-craft craftorder-kitchen-dir validate

# Generate new craftorder
mulle-craft craftorder-kitchen-dir generate
```

### Craftorder Configuration
```bash
# Show detailed craftorder information
mulle-craft craftorder-kitchen-dir show --verbose

# Edit with specific editor
EDITOR=vim mulle-craft craftorder-kitchen-dir edit

# Validate with dependency checking
mulle-craft craftorder-kitchen-dir validate --check-dependencies
```

### Script Integration
```bash
# Validate before building
mulle-craft craftorder-kitchen-dir validate
if [ $? -eq 0 ]; then
    mulle-craft craftorder
fi

# Generate craftorder for new project
mulle-craft craftorder-kitchen-dir generate
mulle-craft craftorder-kitchen-dir edit
mulle-craft craftorder
```

## Troubleshooting

### Craftorder File Not Found
```bash
# Craftorder file missing
mulle-craft craftorder-kitchen-dir show
# Error: Craftorder file not found

# Solution: Generate it first
mulle-craft craftorder-kitchen-dir generate
```

### Invalid Craftorder Syntax
```bash
# Malformed craftorder file
mulle-craft craftorder-kitchen-dir validate
# Error: Invalid craftorder syntax

# Solution: Edit and fix syntax
mulle-craft craftorder-kitchen-dir edit
```

### Dependency Issues
```bash
# Missing project dependencies
mulle-craft craftorder-kitchen-dir validate --check-dependencies
# Error: Missing dependency 'project-x'

# Solution: Add missing dependency to craftorder
mulle-craft craftorder-kitchen-dir edit
```

## Integration with Other Commands

### Build Workflow
```bash
# Validate craftorder before building
mulle-craft craftorder-kitchen-dir validate
mulle-craft craftorder

# Edit craftorder for custom build order
mulle-craft craftorder-kitchen-dir edit
mulle-craft craftorder
```

### Project Management
```bash
# Generate craftorder for new projects
mulle-craft craftorder-kitchen-dir generate
mulle-craft craftorder-kitchen-dir validate
mulle-craft craftorder
```

### CI/CD Integration
```bash
# Validate craftorder in CI pipeline
mulle-craft craftorder-kitchen-dir validate --strict
if [ $? -ne 0 ]; then
    echo "Craftorder validation failed"
    exit 1
fi
mulle-craft craftorder
```

## Technical Details

### Craftorder File Structure

**Standard Format:**
```json
{
  "version": "1.0",
  "projects": [
    {
      "name": "project-a",
      "url": "https://github.com/user/project-a.git",
      "branch": "main",
      "dependencies": []
    },
    {
      "name": "project-b",
      "url": "https://github.com/user/project-b.git",
      "branch": "main",
      "dependencies": ["project-a"]
    }
  ],
  "build_order": [
    "project-a",
    "project-b"
  ]
}
```

**Kitchen Location:**
```
kitchen/
├── craftorder.json          # Main craftorder file
├── craftorder/             # Craftorder working directory
│   ├── project-a.craftinfo # Project-specific info
│   ├── project-b.craftinfo # Project-specific info
│   └── build.log           # Build log
```

### File Path Resolution

**Path Types:**
- **Kitchen**: `kitchen/craftorder.json` (default)
- **Custom**: User-specified path via `--craftorder-file`
- **Project**: Project root craftorder file

**Resolution Priority:**
1. Command-line `--craftorder-file` option
2. Kitchen directory craftorder.json
3. Project root craftorder file
4. Auto-generated from project structure

### Validation Process

**Syntax Validation:**
1. Parse JSON structure
2. Check required fields
3. Validate project references
4. Verify dependency relationships

**Dependency Validation:**
1. Check project existence
2. Validate dependency chains
3. Ensure no circular dependencies
4. Verify build order consistency

### Configuration Files
- `craftorder.json`: Main build configuration
- `craftorder/*.craftinfo`: Per-project build settings
- `kitchen/status/*.status`: Build status information
- `kitchen/log/*.log`: Build logs

## Related Commands

- **[`craftorder`](craftorder.md)** - Execute build order
- **[`kitchen-dir`](kitchen-dir.md)** - Manage kitchen directory
- **[`status`](status.md)** - Check build status
- **[`log`](log.md)** - View build logs