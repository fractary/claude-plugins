# Changelog

All notable changes to the helm plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **BREAKING**: Standardized command argument syntax to space-separated format
  - Changed from `--flag=value` to `--flag value` syntax
  - All 4 commands updated with new argument format
  - All documentation and examples updated

### Migration Guide

**Old Syntax (no longer works):**
```bash
/fractary-helm:status --domain=infrastructure --env=prod
/fractary-helm:issues --critical --domain=application
/fractary-helm:dashboard --format=text --env=prod
```

**New Syntax (required):**
```bash
/fractary-helm:status --domain infrastructure --env prod
/fractary-helm:issues --critical --domain application
/fractary-helm:dashboard --format text --env prod
```

**For multi-word values, use quotes:**
```bash
/fractary-helm:escalate "issue-123" --priority "high priority"
```

### Commands Affected

All 4 commands now use space-separated syntax:
- `/fractary-helm:status`
- `/fractary-helm:issues`
- `/fractary-helm:dashboard`
- `/fractary-helm:escalate`

### Why This Change?

- **Industry Standard**: Matches Git, npm, Docker, kubectl, AWS CLI
- **Consistency**: Aligns with all other Fractary plugins
- **Better UX**: More intuitive for developers familiar with standard CLI tools

See [RESEARCH-CLI-ARGUMENT-STANDARDS.md](../../RESEARCH-CLI-ARGUMENT-STANDARDS.md) for detailed analysis.
