# Changelog

All notable changes to the faber-cloud plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **BREAKING**: Standardized command argument syntax to space-separated format
  - Changed from `--flag=value` to `--flag value` syntax
  - All 13 commands updated with new argument format
  - All 3 parsing scripts updated with validation and helpful error messages
  - All documentation and examples updated

### Migration Guide

**Old Syntax (no longer works):**
```bash
/fractary-faber-cloud:deploy-apply --env=test
/fractary-faber-cloud:init --provider=aws --iac=terraform
/fractary-faber-cloud:deploy-plan --env=prod
```

**New Syntax (required):**
```bash
/fractary-faber-cloud:deploy-apply --env test
/fractary-faber-cloud:init --provider aws --iac terraform
/fractary-faber-cloud:deploy-plan --env prod
```

**For multi-word values, use quotes:**
```bash
/fractary-faber-cloud:design "S3 bucket with versioning"
```

**Helpful Error Messages:**
When using old syntax, you'll see:
```
Error: Use space-separated syntax, not equals syntax
Use: --env <value>
Not: --env=test

Examples:
  ✅ /command --env test
  ❌ /command --env=test
```

### Commands Affected

All 13 commands now use space-separated syntax:
- `/fractary-faber-cloud:deploy-apply`
- `/fractary-faber-cloud:deploy-plan`
- `/fractary-faber-cloud:init`
- `/fractary-faber-cloud:configure`
- `/fractary-faber-cloud:validate`
- `/fractary-faber-cloud:test`
- `/fractary-faber-cloud:debug`
- `/fractary-faber-cloud:design`
- `/fractary-faber-cloud:status`
- `/fractary-faber-cloud:resources`
- `/fractary-faber-cloud:teardown`
- `/fractary-faber-cloud:manage`
- `/fractary-faber-cloud:director`

### Why This Change?

- **Industry Standard**: Matches Git, npm, Docker, kubectl, AWS CLI (90%+ of major CLI tools)
- **POSIX Compliant**: Follows GNU coding standards
- **Better Parsing**: More reliable for Claude Code
- **Consistent**: All Fractary plugins now use the same syntax

See [RESEARCH-CLI-ARGUMENT-STANDARDS.md](../../RESEARCH-CLI-ARGUMENT-STANDARDS.md) for detailed analysis.
