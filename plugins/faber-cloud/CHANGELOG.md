# Changelog

All notable changes to the faber-cloud plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **BREAKING**: Revised command names for clarity and Terraform alignment
  - `deploy-execute` → `deploy-apply` (matches `terraform apply` terminology)
  - `deploy-destroy` → `teardown` (clearer opposite of deploy, less contradictory)
  - These names better align with industry standards and improve intuitive understanding
  - Note: Previously renamed in opposite direction; this revision restores better naming

- **BREAKING**: Standardized command argument syntax to space-separated format
  - Changed from `--flag=value` to `--flag value` syntax
  - All 13 commands updated with new argument format
  - All 3 parsing scripts updated with validation and helpful error messages
  - All documentation and examples updated

- Improved architect command argument hint for clarity
  - Changed from `<description>` to `<description of infrastructure to build>`
  - Makes it clearer what kind of input is expected

- **BREAKING**: Standardized confirmation flag to `--auto-approve`
  - Changed from `--confirm` to `--auto-approve` in teardown command
  - Matches Terraform's own `--auto-approve` convention
  - More consistent with industry standard tooling

- Simplified debug command interface
  - Removed separate `--error` and `--operation` flags
  - Now accepts single natural language `<description of issue to debug>` argument
  - More intuitive: `/fractary-faber-cloud:debug "description of issue"`
  - Better aligns with conversational AI interaction model

### Migration Guide

**Old Syntax (no longer works):**
```bash
# Argument syntax
/fractary-faber-cloud:deploy-apply --env=test
/fractary-faber-cloud:init --provider=aws --iac=terraform
/fractary-faber-cloud:deploy-plan --env=prod

# Confirmation flag
/fractary-faber-cloud:deploy-destroy --env=test --confirm

# Debug command with flags
/fractary-faber-cloud:debug --error="AccessDenied" --operation=deploy
```

**New Syntax (required):**
```bash
# Argument syntax
/fractary-faber-cloud:deploy-apply --env test
/fractary-faber-cloud:init --provider aws --iac terraform
/fractary-faber-cloud:deploy-plan --env prod

# Confirmation flag
/fractary-faber-cloud:teardown --env test --auto-approve

# Debug command with description
/fractary-faber-cloud:debug "AccessDenied error during deployment"
```

**For multi-word values, use quotes:**
```bash
/fractary-faber-cloud:architect "S3 bucket with versioning"
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

All commands now use space-separated syntax:
- `/fractary-faber-cloud:deploy-apply`
- `/fractary-faber-cloud:deploy-plan`
- `/fractary-faber-cloud:init`
- `/fractary-faber-cloud:configure`
- `/fractary-faber-cloud:validate`
- `/fractary-faber-cloud:test`
- `/fractary-faber-cloud:debug`
- `/fractary-faber-cloud:architect`
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

See [SPEC-00014: CLI Argument Standards](../../specs/SPEC-00014-cli-argument-standards.md) for detailed analysis.
