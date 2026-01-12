# mulle-craft style - Manage Build Styles

## Quick Start
Manage build styles and configurations for different build environments.

## All Available Options

### Basic Usage
```bash
mulle-craft style [command] [options]
```

**Arguments:** Command (list, set, get, etc.)

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed style information
- `--quiet`: Show minimal style information
- `--style-name <name>`: Specify style name

### Hidden Options
- Various style-specific options for different operations

## Command Behavior

### Core Functionality
- **Style Management**: Create, modify, and switch between build styles
- **Configuration Storage**: Store build settings per style
- **Environment Setup**: Apply style-specific environment variables
- **Style Inheritance**: Support style inheritance and overrides

### Conditional Behaviors

**Style Sources:**
- Default: Uses built-in styles
- Custom: Uses user-defined styles from configuration files
- Missing: Falls back to default style

**Style Operations:**
- List: Shows available styles
- Set: Changes current style
- Get: Shows current style settings
- Create: Creates new custom style

## Practical Examples

### Basic Style Management
```bash
# List available styles
mulle-craft style list

# Show current style
mulle-craft style get

# Set a specific style
mulle-craft style set debug

# Create a new style
mulle-craft style create my-style
```

### Style Configuration
```bash
# Show style details
mulle-craft style get --verbose

# Edit style settings
mulle-craft style edit my-style

# Copy an existing style
mulle-craft style copy debug my-debug
```

### Script Integration
```bash
# Set style for build
mulle-craft style set release
mulle-craft craftorder

# Use different styles for different builds
mulle-craft style set debug
mulle-craft project
mulle-craft style set release
mulle-craft project
```

## Troubleshooting

### Style Not Found
```bash
# Style doesn't exist
mulle-craft style set nonexistent
# Error: Style 'nonexistent' not found

# Solution: List available styles first
mulle-craft style list
```

### Permission Issues
```bash
# Cannot modify style files
mulle-craft style create my-style
# Error: Permission denied

# Solution: Check permissions on style directory
ls -la ~/.mulle-craft/styles/
```

### Invalid Style Configuration
```bash
# Malformed style file
mulle-craft style set broken-style
# Error: Invalid style configuration

# Solution: Validate style file syntax
mulle-craft style validate broken-style
```

## Integration with Other Commands

### Build Workflow
```bash
# Use style-specific builds
mulle-craft style set debug
mulle-craft craftorder

# Style affects build configuration
mulle-craft style set release
mulle-craft craftorder
```

### Configuration Management
```bash
# Style affects environment
mulle-craft style set cross-compile
export CC=arm-linux-gcc
mulle-craft project

# Style affects build options
mulle-craft style set minimal
mulle-craft craftorder
```

### Development Workflow
```bash
# Development style
mulle-craft style set development
mulle-craft craftorder

# CI style
mulle-craft style set ci
mulle-craft craftorder
```

## Technical Details

### Style File Structure

**Style Directory:**
```
~/.mulle-craft/styles/
├── debug.style
├── release.style
├── development.style
└── ci.style
```

**Style File Format:**
```json
{
  "name": "debug",
  "description": "Debug build configuration",
  "variables": {
    "CFLAGS": "-g -O0",
    "CXXFLAGS": "-g -O0"
  },
  "options": {
    "verbose": true,
    "parallel": false
  }
}
```

### Style Types

**Built-in Styles:**
- **debug**: Development with debug symbols
- **release**: Optimized production build
- **minimal**: Minimal dependencies build

**Custom Styles:**
- User-defined configurations
- Project-specific settings
- Environment-specific builds

### Style Inheritance

**Base Styles:**
- Styles can inherit from other styles
- Override specific settings
- Combine multiple style aspects

**Inheritance Example:**
```json
{
  "name": "my-debug",
  "inherits": "debug",
  "variables": {
    "CFLAGS": "-g -O0 -fsanitize=address"
  }
}
```

## Related Commands

- **[`project`](project.md)** - Build project (uses current style)
- **[`craftorder`](craftorder.md)** - Build multiple projects
- **[`status`](status.md)** - Check build status
- **[`clean`](clean.md)** - Clean build artifacts