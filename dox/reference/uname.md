# mulle-craft uname - System Information

## Quick Start
Display system information and uname details for build configuration.

## All Available Options

### Basic Usage
```bash
mulle-craft uname [options]
```

**Arguments:** None required

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed system information
- `--quiet`: Show minimal system information
- `--all`: Show all available system information

### Hidden Options
- Various system information display options

## Command Behavior

### Core Functionality
- **System Information**: Display uname and system details
- **Build Context**: Show information relevant to build configuration
- **Platform Detection**: Identify system type and capabilities
- **Environment Details**: Display system environment information

### Conditional Behaviors

**Information Sources:**
- Default: Uses standard uname command output
- Extended: Includes additional system information
- Build-specific: Shows build-relevant system details
- Environment: Includes environment variable information

**Output Formats:**
- Standard: Traditional uname output format
- Detailed: Extended system information
- Build: Information formatted for build scripts
- JSON: Structured output for automation

## Practical Examples

### Basic System Information
```bash
# Show basic system information
mulle-craft uname

# Show detailed system information
mulle-craft uname --verbose

# Show all available information
mulle-craft uname --all
```

### Build Configuration
```bash
# Get system info for build scripts
mulle-craft uname --quiet

# Check system compatibility
mulle-craft uname --verbose | grep -i linux

# Get system details for CI
mulle-craft uname --all > system_info.txt
```

### Script Integration
```bash
# Use in build scripts
SYSTEM_INFO=$(mulle-craft uname --quiet)
echo "Building on: $SYSTEM_INFO"

# Conditional compilation based on system
if mulle-craft uname | grep -q "Darwin"; then
    echo "macOS build"
elif mulle-craft uname | grep -q "Linux"; then
    echo "Linux build"
fi
```

## Troubleshooting

### Command Not Found
```bash
# uname command not available
mulle-craft uname
# Error: uname command not found

# Solution: Install uname or use alternative
# On some systems, try: mulle-craft uname --fallback
```

### Permission Issues
```bash
# Cannot access system information
mulle-craft uname --verbose
# Error: Permission denied

# Solution: Run with appropriate permissions
sudo mulle-craft uname --verbose
```

### Inconsistent Output
```bash
# Different output formats
mulle-craft uname --verbose
# Output varies by system

# Solution: Use consistent options
mulle-craft uname --all --format=text
```

## Integration with Other Commands

### Build Workflow
```bash
# System-aware building
SYSTEM=$(mulle-craft uname --quiet)
mulle-craft craftorder --system="$SYSTEM"

# Platform-specific configuration
if mulle-craft uname | grep -q "x86_64"; then
    mulle-craft qualifier add x86_64
fi

# Cross-platform builds
TARGET_SYSTEM=$(mulle-craft uname --quiet)
mulle-craft tool-env set TARGET_SYSTEM="$TARGET_SYSTEM"
```

### CI/CD Integration
```bash
# System information for CI logs
mulle-craft uname --all >> ci_build.log

# Conditional deployment
if mulle-craft uname | grep -q "production"; then
    mulle-craft craftorder --production
fi
```

### Multi-Platform Development
```bash
# Detect and configure for different systems
case $(mulle-craft uname --quiet) in
    *Linux*)
        mulle-craft style linux
        ;;
    *Darwin*)
        mulle-craft style macos
        ;;
    *Windows*)
        mulle-craft style windows
        ;;
esac
```

## Technical Details

### System Information Types

**Basic uname Information:**
- Kernel name (`uname -s`)
- Network name (`uname -n`)
- Kernel release (`uname -r`)
- Kernel version (`uname -v`)
- Machine hardware (`uname -m`)
- Processor type (`uname -p`)
- Operating system (`uname -o`)

**Extended Information:**
- System architecture details
- Available memory and CPU information
- Disk space and filesystem details
- Network configuration
- Environment variables
- Build tool versions

### Output Formats

**Standard Format:**
```
Linux hostname 5.4.0-42-generic #46-Ubuntu SMP Fri Jul 10 00:24:02 UTC 2020 x86_64 x86_64 x86_64 GNU/Linux
```

**Detailed Format:**
```json
{
  "system": "Linux",
  "hostname": "hostname",
  "kernel": "5.4.0-42-generic",
  "architecture": "x86_64",
  "distribution": "Ubuntu",
  "version": "20.04"
}
```

**Build Format:**
```
SYSTEM=Linux
ARCH=x86_64
DISTRO=Ubuntu
VERSION=20.04
```

### System Detection

**Platform Identification:**
1. Parse uname output
2. Check for distribution-specific files
3. Query system package managers
4. Validate system capabilities
5. Determine build compatibility

**Compatibility Checking:**
- Check for required system features
- Verify tool availability
- Test system resource availability
- Validate build environment

### Configuration Files
- `uname/cache.txt`: Cached system information
- `uname/detection/*.sh`: System detection scripts
- `uname/compatibility/*.txt`: Compatibility matrices
- `uname/config.txt`: uname command configuration

## Related Commands

- **[`style`](style.md)** - Manage build styles
- **[`qualifier`](qualifier.md)** - Manage build qualifiers
- **[`tool-env`](tool-env.md)** - Manage tool environment
- **[`status`](status.md)** - Check build status