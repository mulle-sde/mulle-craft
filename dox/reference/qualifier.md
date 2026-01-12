# mulle-craft qualifier - Manage Build Qualifiers

## Quick Start
Manage build qualifiers and conditional compilation settings.

## All Available Options

### Basic Usage
```bash
mulle-craft qualifier [command] [options]
```

**Arguments:** Command (list, set, get, add, remove, etc.)

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed qualifier information
- `--quiet`: Show minimal qualifier information
- `--qualifier-name <name>`: Specify qualifier name

### Hidden Options
- Various qualifier-specific options for different operations

## Command Behavior

### Core Functionality
- **Qualifier Management**: Create, modify, and apply build qualifiers
- **Conditional Compilation**: Control which code gets compiled based on qualifiers
- **Platform Targeting**: Specify platform-specific build conditions
- **Feature Selection**: Enable/disable optional features

### Conditional Behaviors

**Qualifier Sources:**
- Default: Uses built-in qualifiers
- Custom: Uses user-defined qualifiers from configuration files
- Missing: Falls back to default qualifier

**Qualifier Operations:**
- List: Shows available qualifiers
- Set: Changes current qualifier
- Get: Shows current qualifier settings
- Add/Remove: Modifies qualifier conditions

## Practical Examples

### Basic Qualifier Management
```bash
# List available qualifiers
mulle-craft qualifier list

# Show current qualifier
mulle-craft qualifier get

# Set a specific qualifier
mulle-craft qualifier set debug

# Add a custom qualifier
mulle-craft qualifier add my-feature
```

### Qualifier Configuration
```bash
# Show qualifier details
mulle-craft qualifier get --verbose

# Edit qualifier settings
mulle-craft qualifier edit my-qualifier

# Remove a qualifier
mulle-craft qualifier remove old-qualifier
```

### Script Integration
```bash
# Set qualifier for conditional build
mulle-craft qualifier set production
mulle-craft craftorder

# Use different qualifiers for different builds
mulle-craft qualifier set experimental
mulle-craft project
mulle-craft qualifier set stable
mulle-craft project
```

## Troubleshooting

### Qualifier Not Found
```bash
# Qualifier doesn't exist
mulle-craft qualifier set nonexistent
# Error: Qualifier 'nonexistent' not found

# Solution: List available qualifiers first
mulle-craft qualifier list
```

### Invalid Qualifier Configuration
```bash
# Malformed qualifier file
mulle-craft qualifier set broken-qualifier
# Error: Invalid qualifier configuration

# Solution: Validate qualifier file syntax
mulle-craft qualifier validate broken-qualifier
```

### Permission Issues
```bash
# Cannot modify qualifier files
mulle-craft qualifier add my-qualifier
# Error: Permission denied

# Solution: Check permissions on qualifier directory
ls -la ~/.mulle-craft/qualifiers/
```

## Integration with Other Commands

### Build Workflow
```bash
# Use qualifier-specific builds
mulle-craft qualifier set ios
mulle-craft craftorder

# Qualifier affects build configuration
mulle-craft qualifier set android
mulle-craft craftorder
```

### Configuration Management
```bash
# Qualifier affects compilation flags
mulle-craft qualifier set optimized
export CFLAGS="-O3"
mulle-craft project

# Qualifier affects feature selection
mulle-craft qualifier set minimal
mulle-craft craftorder
```

### Development Workflow
```bash
# Development qualifier
mulle-craft qualifier set development
mulle-craft craftorder

# Release qualifier
mulle-craft qualifier set release
mulle-craft craftorder
```

## Technical Details

### Qualifier File Structure

**Qualifier Directory:**
```
~/.mulle-craft/qualifiers/
├── debug.qualifier
├── release.qualifier
├── ios.qualifier
└── android.qualifier
```

**Qualifier File Format:**
```json
{
  "name": "debug",
  "description": "Debug build qualifier",
  "conditions": {
    "platform": "any",
    "architecture": "any"
  },
  "defines": [
    "DEBUG=1",
    "ENABLE_LOGGING=1"
  ],
  "flags": {
    "c": "-g -O0",
    "cxx": "-g -O0"
  }
}
```

### Qualifier Types

**Platform Qualifiers:**
- **ios**: iOS-specific build settings
- **android**: Android-specific build settings
- **linux**: Linux-specific build settings
- **macos**: macOS-specific build settings

**Build Type Qualifiers:**
- **debug**: Development with debug symbols
- **release**: Optimized production build
- **profile**: Profiling-enabled build

### Qualifier Composition

**Multiple Conditions:**
- Qualifiers can combine multiple conditions
- Platform + architecture + build type
- Feature flags and compilation options

**Qualifier Example:**
```json
{
  "name": "ios-arm64-release",
  "conditions": {
    "platform": "ios",
    "architecture": "arm64",
    "build_type": "release"
  },
  "defines": [
    "NDEBUG=1",
    "TARGET_OS_IPHONE=1"
  ]
}
```

## Related Commands

- **[`style`](style.md)** - Manage build styles
- **[`project`](project.md)** - Build project (uses current qualifier)
- **[`craftorder`](craftorder.md)** - Build multiple projects
- **[`status`](status.md)** - Check build status