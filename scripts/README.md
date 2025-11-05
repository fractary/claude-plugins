# Development Scripts

This directory contains development and maintenance scripts for the claude-plugins repository.

## lint-command-frontmatter.sh

Validates frontmatter in plugin command files (`plugins/*/commands/*.md`) to catch common errors before they cause issues.

### What It Checks

**Errors (must fix):**
- Missing frontmatter structure (must start with `---`)
- Missing required `name` field
- Leading slashes in `name` field (e.g., `/fractary-faber:run` → should be `fractary-faber:run`)

**Warnings (recommended to fix):**
- `name` field doesn't follow `plugin-name:command-name` pattern
- Missing recommended `description` field

### Usage

```bash
# Check all command files in all plugins
./scripts/lint-command-frontmatter.sh plugins/

# Check a specific plugin
./scripts/lint-command-frontmatter.sh plugins/faber-cloud/

# Check a single file
./scripts/lint-command-frontmatter.sh plugins/faber-cloud/commands/init.md
```

### Exit Codes

- `0`: All checks passed
- `1`: Found one or more errors

### Example Output

```
=== Frontmatter Linter ===

File: plugins/faber-cloud/commands/debug.md
  ✗ ERROR: Name field has leading slash: '/fractary-faber-cloud:debug' (should be 'fractary-faber-cloud:debug')

File: plugins/repo/commands/init-permissions.md
  ✗ ERROR: Missing required field: name

=== Summary ===
Files checked: 88
Files with issues: 2
Total errors: 2

✗ Found 2 error(s) that must be fixed
```

### Integration with CI/CD

You can add this to your CI/CD pipeline to automatically catch frontmatter issues:

**.github/workflows/lint.yml**:
```yaml
name: Lint

on: [push, pull_request]

jobs:
  frontmatter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Lint command frontmatter
        run: ./scripts/lint-command-frontmatter.sh plugins/
```

### Common Issues

**Leading slashes in name field:**

This was a common issue that was fixed in commit `b7f661e`. The linter prevents this from happening again.

❌ Incorrect:
```yaml
---
name: /fractary-faber-cloud:init
---
```

✅ Correct:
```yaml
---
name: fractary-faber-cloud:init
---
```

**Missing name field:**

All command files must have a `name` field in their frontmatter.

```yaml
---
name: fractary-faber-cloud:init
description: Initialize faber-cloud plugin configuration
---
```

### Development

To modify the linter:

1. Edit `scripts/lint-command-frontmatter.sh`
2. Test your changes on a sample file: `./scripts/lint-command-frontmatter.sh plugins/faber-cloud/commands/init.md`
3. Run on all files: `./scripts/lint-command-frontmatter.sh plugins/`

### See Also

- [Plugin Development Standards](../docs/standards/FRACTARY-PLUGIN-STANDARDS.md)
- [Commit b7f661e](https://github.com/fractary/claude-plugins/commit/b7f661e) - Fix that removed leading slashes
