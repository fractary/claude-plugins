# Build Log Standards

## Purpose

Build logs capture complete build process execution for:
- Debugging build failures
- Performance analysis and optimization
- Dependency tracking
- Artifact management
- Historical build analysis

## Required Sections

1. **Build Metadata** - Build ID, repository, branch, commit, tool
2. **Build Output** - stdout and stderr from build process
3. **Errors** - Compilation/build errors with file/line numbers
4. **Warnings** - Build warnings
5. **Artifacts** - Generated build artifacts with sizes
6. **Build Summary** - High-level outcome summary

## Capture Rules

### What to Capture

**ALWAYS capture**:
- Complete stdout and stderr from build process
- Exit code (0 = success, non-zero = failure)
- All error messages with file/line context
- All warning messages
- Build tool and version
- Dependency versions
- Artifact paths and sizes
- Build duration and performance metrics

**MAY capture**:
- Intermediate build steps
- Dependency resolution logs
- Test execution results (if included in build)

### What to Redact

**ALWAYS redact**:
- Build secrets (API keys used during build)
- Internal paths that reveal infrastructure
- Private repository URLs
- Credentials in dependency URLs

## Naming Conventions

Pattern: `build-{build_id}-{commit_short}-{branch}.md`

Examples:
- `build-20250116-143052-abc1234-main.md`
- `build-20250116-145030-def5678-feature-125.md`

## Content Guidelines

### Build Output

- **Format**: Preserve as code blocks with language hint
- **Length**: Capture full output (may be large)
- **Errors**: Extract and highlight separately

### Error Format

```
- **src/main.ts:45**: Expected ';' after statement
- **src/api.ts:102**: Cannot find module 'express'
```

### Performance Metrics

- Compile time, link time, total time
- Peak memory usage
- CPU utilization (if available)
- Cache hit rate (if applicable)

## Status Values

- **pending**: Build queued but not started
- **running**: Build in progress
- **success**: Build completed successfully (exit code 0)
- **failure**: Build failed (non-zero exit code)
- **cancelled**: Build cancelled by user
- **archived**: Build log archived

## Retention

- Local: 3 days
- Cloud: 30 days
- Priority: Medium
- Auto-archive: Yes
