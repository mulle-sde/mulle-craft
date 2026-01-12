# mulle-craft version - Version Information

## Quick Start
Display version information for mulle-craft and related components.

## All Available Options

### Basic Usage
```bash
mulle-craft version [options]
```

**Arguments:** None required

### Visible Options
- `--help`: Show usage information
- `--verbose`: Show detailed version information
- `--quiet`: Show minimal version information
- `--all`: Show all version information

### Hidden Options
- Various version-specific display options

## Command Behavior

### Core Functionality
- **Version Display**: Show mulle-craft version information
- **Component Versions**: Display versions of related tools and libraries
- **Build Information**: Show build details and metadata
- **Compatibility Info**: Display version compatibility information

### Conditional Behaviors

**Information Sources:**
- Default: Uses built-in version information
- Verbose: Includes build details and dependencies
- All: Shows comprehensive version information
- Quiet: Shows only essential version numbers

**Output Formats:**
- Standard: Human-readable version format
- JSON: Structured version information
- Build: Version information for build scripts
- Debug: Detailed internal version data

## Practical Examples

### Basic Version Information
```bash
# Show current version
mulle-craft version

# Show detailed version information
mulle-craft version --verbose

# Show all version information
mulle-craft version --all
```

### Version Checking
```bash
# Check if version meets requirements
mulle-craft version --quiet | grep -q "1.2.3"

# Get version for build scripts
VERSION=$(mulle-craft version --quiet)
echo "Building with mulle-craft $VERSION"
```

### Script Integration
```bash
# Version validation in scripts
REQUIRED_VERSION="1.2.0"
CURRENT_VERSION=$(mulle-craft version --quiet)

if [ "$CURRENT_VERSION" \< "$REQUIRED_VERSION" ]; then
    echo "mulle-craft version $REQUIRED_VERSION or higher required"
    exit 1
fi

# Log version information
mulle-craft version --all >> build_log.txt
```

## Troubleshooting

### Version Not Available
```bash
# Version information not found
mulle-craft version
# Error: Version information not available

# Solution: Check installation or rebuild
mulle-sde craft
```

### Inconsistent Version Output
```bash
# Different version formats
mulle-craft version --verbose
# Output varies by build

# Solution: Use consistent options
mulle-craft version --format=text
```

### Permission Issues
```bash
# Cannot access version information
mulle-craft version --verbose
# Error: Permission denied

# Solution: Check file permissions or run as appropriate user
```

## Integration with Other Commands

### Build Workflow
```bash
# Version-aware building
VERSION=$(mulle-craft version --quiet)
mulle-craft craftorder --version="$VERSION"

# Version logging
mulle-craft version --all > version_info.txt
mulle-craft craftorder >> build_log.txt
```

### CI/CD Integration
```bash
# Version validation in CI
mulle-craft version --quiet
if [ $? -ne 0 ]; then
    echo "Version check failed"
    exit 1
fi

# Version tagging
VERSION=$(mulle-craft version --quiet)
git tag "v$VERSION"
```

### Multi-Version Support
```bash
# Check compatibility across versions
mulle-craft version --all | grep -E "(mulle-sde|cmake)"

# Version-specific configurations
case $(mulle-craft version --quiet) in
    1.*)
        mulle-craft style legacy
        ;;
    2.*)
        mulle-craft style modern
        ;;
esac
```

## Technical Details

### Version Information Types

**Core Version Information:**
- mulle-craft version number
- Build date and time
- Git commit hash
- Build platform information

**Component Versions:**
- mulle-sde version
- CMake version
- Compiler versions
- Library versions

**Build Metadata:**
- Build configuration
- Compiler flags
- Linker information
- System information

### Version Format

**Standard Format:**
```
mulle-craft 1.2.3 (2025-09-03)
```

**Detailed Format:**
```json
{
  "version": "1.2.3",
  "build_date": "2025-09-03T00:07:18Z",
  "git_commit": "abc123def456",
  "platform": "linux-x86_64",
  "compiler": "gcc-9.3.0"
}
```

**Build Format:**
```
VERSION=1.2.3
BUILD_DATE=2025-09-03
GIT_COMMIT=abc123def456
PLATFORM=linux-x86_64
```

### Version Management

**Version Sources:**
1. Version header files
2. Git tags and commits
3. Build system metadata
4. Package manager information

**Version Validation:**
- Check version format compliance
- Validate version compatibility
- Verify build integrity
- Confirm dependency versions

### Configuration Files
- `version.txt`: Main version information file
- `version/build.txt`: Build-specific version data
- `version/components.txt`: Component version information
- `version/compatibility.txt`: Version compatibility matrix

## Related Commands

- **[`status`](status.md)** - Check build status
- **[`uname`](uname.md)** - Show system information
- **[`tool-env`](tool-env.md)** - Manage tool environment
- **[`craftorder`](craftorder.md)** - Build projects in order