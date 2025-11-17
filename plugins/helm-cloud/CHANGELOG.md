# Changelog

All notable changes to the helm-cloud plugin will be documented in this file.

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
/fractary-helm-cloud:health --env=prod
/fractary-helm-cloud:investigate "error message" --env=test
/fractary-helm-cloud:audit --type=security --env=prod
/fractary-helm-cloud:remediate "issue-123" --action=restart
```

**New Syntax (required):**
```bash
/fractary-helm-cloud:health --env prod
/fractary-helm-cloud:investigate "error message" --env test
/fractary-helm-cloud:audit --type security --env prod
/fractary-helm-cloud:remediate "issue-123" --action restart
```

**For multi-word values, use quotes:**
```bash
/fractary-helm-cloud:investigate "Connection timeout error" --env test
/fractary-helm-cloud:remediate "scale up instances" --env prod
```

### Commands Affected

All 4 commands now use space-separated syntax:
- `/fractary-helm-cloud:health`
- `/fractary-helm-cloud:investigate`
- `/fractary-helm-cloud:audit`
- `/fractary-helm-cloud:remediate`

### Why This Change?

- **Industry Standard**: Matches Git, npm, Docker, kubectl, AWS CLI
- **Consistency**: Aligns with all other Fractary plugins
- **Better UX**: More intuitive for developers familiar with standard CLI tools

See [SPEC-00014: CLI Argument Standards](../../specs/SPEC-00014-cli-argument-standards.md) for detailed analysis.
