# mulle-craft Command Reference

## Overview

This document provides a comprehensive reference for all mulle-craft commands. mulle-craft is a build tool that manages the compilation and linking of projects within the mulle-sde ecosystem.

## Command Categories

### Core Build Commands

| Command | Description | Documentation |
|---------|-------------|---------------|
| [`craftorder`](craftorder.md) | Build projects in dependency order | [craftorder](craftorder.md) |
| [`project`](project.md) | Manage project configuration | [project](project.md) |
| [`clean`](clean.md) | Clean build artifacts | [clean](clean.md) |
| [`list`](list.md) | List available projects and configurations | [list](list.md) |

### Status and Monitoring

| Command | Description | Documentation |
|---------|-------------|---------------|
| [`status`](status.md) | Show build status | [status](status.md) |
| [`quickstatus`](quickstatus.md) | Show quick build status | [quickstatus](quickstatus.md) |
| [`log`](log.md) | View build logs | [log](log.md) |
| [`donefile`](donefile.md) | Manage build completion tracking | [donefile](donefile.md) |

### Configuration and Environment

| Command | Description | Documentation |
|---------|-------------|---------------|
| [`style`](style.md) | Manage build styles | [style](style.md) |
| [`qualifier`](qualifier.md) | Manage build qualifiers | [qualifier](qualifier.md) |
| [`tool-env`](tool-env.md) | Manage tool environment variables | [tool-env](tool-env.md) |
| [`uname`](uname.md) | Show system information | [uname](uname.md) |
| [`version`](version.md) | Show version information | [version](version.md) |

### Directory and Path Management

| Command | Description | Documentation |
|---------|-------------|---------------|
| [`kitchen-dir`](kitchen-dir.md) | Manage kitchen directory | [kitchen-dir](kitchen-dir.md) |
| [`dependency-dir`](dependency-dir.md) | Manage dependency directory | [dependency-dir](dependency-dir.md) |
| [`addiction-dir`](addiction-dir.md) | Manage addiction directory | [addiction-dir](addiction-dir.md) |
| [`craftorder-kitchen-dir`](craftorder-kitchen-dir.md) | Manage craftorder kitchen directory | [craftorder-kitchen-dir](craftorder-kitchen-dir.md) |
| [`libexec-dir`](libexec-dir.md) | Manage libexec directory | [libexec-dir](libexec-dir.md) |
| [`find`](find.md) | Find files and directories | [find](find.md) |
| [`searchpath`](searchpath.md) | Manage search paths | [searchpath](searchpath.md) |

## Command Usage Patterns

### Basic Build Workflow
```bash
# Standard build process
mulle-craft craftorder
mulle-craft status

# Clean and rebuild
mulle-craft clean
mulle-craft craftorder

# Check build completion
mulle-craft donefile show
```

### Configuration Management
```bash
# Set up build environment
mulle-craft style set release
mulle-craft qualifier add x86_64
mulle-craft tool-env set CC=clang

# Check system compatibility
mulle-craft uname --verbose
mulle-craft version --all
```

### Project Management
```bash
# List available projects
mulle-craft list

# Manage project configuration
mulle-craft project show
mulle-craft project set name=myproject

# Find project files
mulle-craft find src/
mulle-craft searchpath show
```

### Monitoring and Debugging
```bash
# Monitor build progress
mulle-craft status --verbose
mulle-craft log show

# Check build completion
mulle-craft donefile show
mulle-craft quickstatus
```

## Command Reference Table

| Command | Category | Purpose |
|---------|----------|---------|
| `craftorder` | Build | Execute builds in dependency order |
| `project` | Configuration | Manage project settings |
| `clean` | Maintenance | Remove build artifacts |
| `list` | Information | Display available items |
| `status` | Monitoring | Show current build status |
| `quickstatus` | Monitoring | Show brief build status |
| `log` | Monitoring | Display build logs |
| `donefile` | Tracking | Manage build completion files |
| `style` | Configuration | Manage build styles |
| `qualifier` | Configuration | Manage build qualifiers |
| `tool-env` | Environment | Manage tool environment |
| `uname` | System | Show system information |
| `version` | Information | Show version information |
| `kitchen-dir` | Directory | Manage kitchen directory |
| `dependency-dir` | Directory | Manage dependency directory |
| `addiction-dir` | Directory | Manage addiction directory |
| `craftorder-kitchen-dir` | Directory | Manage craftorder kitchen |
| `libexec-dir` | Directory | Manage libexec directory |
| `find` | Search | Find files and directories |
| `searchpath` | Search | Manage search paths |

## Getting Help

### Command-Specific Help
```bash
# Get help for any command
mulle-craft <command> --help

# Example
mulle-craft craftorder --help
mulle-craft status --help
```

### Documentation Navigation
- Each command links to its detailed documentation
- Examples are provided for common use cases
- Troubleshooting sections address frequent issues
- Integration examples show how commands work together

## Quick Start Examples

### New Project Setup
```bash
# Initialize project
mulle-craft project init

# Configure build
mulle-craft style set debug
mulle-craft qualifier add native

# First build
mulle-craft craftorder
```

### Development Workflow
```bash
# Daily development cycle
mulle-craft status          # Check current state
mulle-craft craftorder      # Build changes
mulle-craft log show        # Review build output
mulle-craft donefile create # Mark as complete
```

### CI/CD Integration
```bash
# Automated build script
mulle-craft clean
mulle-craft craftorder
mulle-craft status --strict
mulle-craft version --quiet > version.txt
```

## Advanced Usage

### Custom Build Configurations
```bash
# Cross-compilation setup
mulle-craft tool-env set CC=arm-linux-gcc
mulle-craft tool-env set AR=arm-linux-ar
mulle-craft qualifier add armhf
mulle-craft craftorder
```

### Multi-Project Builds
```bash
# Build multiple projects
mulle-craft list --projects
mulle-craft craftorder --all-projects
mulle-craft status --all
```

### Performance Optimization
```bash
# Parallel builds
mulle-craft tool-env set MAKEFLAGS="-j8"
mulle-craft craftorder

# Incremental builds
mulle-craft donefile show
mulle-craft craftorder --incremental
```

## Troubleshooting

### Common Issues
- **Build failures**: Check `mulle-craft log show`
- **Missing dependencies**: Use `mulle-craft list --dependencies`
- **Configuration errors**: Run `mulle-craft status --verbose`
- **Path issues**: Check `mulle-craft searchpath show`

### Diagnostic Commands
```bash
# Comprehensive diagnostics
mulle-craft status --verbose
mulle-craft uname --all
mulle-craft version --all
mulle-craft tool-env show
```

## Related Documentation

- [TODO](TODO.md) - Documentation process guide
- [mulle-sde Documentation](../../mulle-sde/dox/reference/) - Main mulle-sde reference
- [mulle-env Documentation](../../mulle-env/dox/reference/) - Environment management
- [Build System Guidelines](../../rules/mulle-sde.md) - Build system rules

## Contributing

When adding new commands:
1. Create command documentation following the established pattern
2. Add entry to this index with appropriate categorization
3. Include practical examples and troubleshooting
4. Update cross-references between related commands

## Version Information

This documentation covers mulle-craft commands. For the latest information, run:
```bash
mulle-craft version --verbose