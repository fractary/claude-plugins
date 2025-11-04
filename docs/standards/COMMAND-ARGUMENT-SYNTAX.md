# Command Argument Syntax Standard

**Version:** 1.0
**Status:** Proposed
**Last Updated:** 2025-11-04

## Purpose

This document defines the standard syntax for command arguments across all Fractary plugins to ensure consistency, clarity, and ease of use.

## Standard Syntax

All Fractary plugin commands MUST use **space-separated syntax** for flags and arguments.

### Flags with Values

**Format:** `--flag value`

```bash
# Correct ✅
--env test
--type feature
--description "multi word value"

# Incorrect ❌
--env=test
--type=feature
--description=multi word value
```

### Boolean Flags

**Format:** `--flag` (no value)

```bash
# Correct ✅
--dry-run
--auto-merge
--force

# Incorrect ❌
--dry-run=true
--auto-merge true
--force=yes
```

### Positional Arguments

**Format:** Unquoted for single words, quoted for multiple words

```bash
# Correct ✅
/command argument1 "argument 2 with spaces"
/command 123 --flag value

# Incorrect ❌
/command argument1 argument 2 with spaces
```

## Quote Rules

### MUST Use Quotes

**Multi-word values:**
```bash
✅ --body "This is a multi-word description"
✅ --title "Feature: Add CSV export"
✅ --message "Fix: Resolve authentication bug"

❌ --body This is a multi-word description
❌ --title Feature: Add CSV export
```

**Values with special characters:**
```bash
✅ --url "https://example.com/path?param=value"
✅ --description "Value with = or : or other chars"
✅ --query "status:open label:bug"

❌ --url https://example.com/path?param=value
```

### MAY Omit Quotes

**Single-word values:**
```bash
✅ --type feature
✅ --env test
✅ --scope auth

Also acceptable:
✅ --type "feature"
✅ --env "test"
✅ --scope "auth"
```

### NEVER Use Quotes

**Boolean flags:**
```bash
✅ --dry-run
✅ --auto-merge
✅ --force

❌ --dry-run "true"
❌ --auto-merge "yes"
```

## Common Gotchas

### 1. Forgetting Quotes for Multi-Word Values

**Problem:**
```bash
❌ /command --description This is a description
```

**What happens:** Only "This" is parsed as the value, "is a description" becomes unexpected arguments.

**Solution:**
```bash
✅ /command --description "This is a description"
```

### 2. Using Equals Syntax

**Problem:**
```bash
❌ /command --env=test
❌ /command --type=feature
```

**What happens:** You'll see an error:
```
Error: Use space-separated syntax, not equals syntax
Use: --env <value>
Not: --env=test
```

**Solution:**
```bash
✅ /command --env test
✅ /command --type feature
```

### 3. Adding Values to Boolean Flags

**Problem:**
```bash
❌ /command --auto-merge true
❌ /command --dry-run=true
```

**What happens:** "true" is parsed as an unexpected argument, or equals syntax error.

**Solution:**
```bash
✅ /command --auto-merge
✅ /command --dry-run
```

### 4. Missing Quotes for Values with Special Characters

**Problem:**
```bash
❌ /command --url https://example.com/path?param=value
❌ /command --query status:open label:bug
```

**What happens:** Shell interprets special characters (`?`, `:`, etc.) causing unexpected behavior.

**Solution:**
```bash
✅ /command --url "https://example.com/path?param=value"
✅ /command --query "status:open label:bug"
```

### 5. Mixing Positional Args Without Quotes

**Problem:**
```bash
❌ /command Multi word title --type feature
```

**What happens:** "Multi" is positional arg, "word title" becomes unexpected arguments.

**Solution:**
```bash
✅ /command "Multi word title" --type feature
```

### 6. Using Single Quotes Instead of Double Quotes

**Problem:**
```bash
⚠️ /command --description 'This is a description'
```

**What might happen:** Single quotes work in most cases, but double quotes are the standard and handle variable expansion consistently.

**Best practice:**
```bash
✅ /command --description "This is a description"
```

### Quick Reference Card

```bash
# ✅ CORRECT USAGE
/command "positional arg" --flag value --boolean-flag
/command "multi word" --flag "multi word value"
/command arg --url "https://example.com/path?x=y"

# ❌ COMMON MISTAKES
/command multi word arg              # Missing quotes on multi-word
/command --flag=value                # Using equals syntax
/command --boolean-flag true         # Value on boolean flag
/command --url https://example.com   # Missing quotes on URL
```

## Complete Examples

### Work Plugin
```bash
# Create issue
/work:issue-create "Add CSV export" --type feature --body "Users need to export data"

# Add label
/work:label-add 123 urgent

# Create with multiple options
/work:issue-create "Fix login bug" --type bug --body "Error on timeout" --assignee @me
```

### Repo Plugin
```bash
# Create commit
/repo:commit "Add CSV export" --type feat --work-id 123

# With description
/repo:commit "Improve performance" --type perf --description "Optimized database queries"

# With scope
/repo:commit "Update API" --type refactor --scope api
```

### FABER Plugin
```bash
# Run workflow
/faber:run 123 --domain engineering --autonomy guarded

# With auto-merge
/faber:run 456 --autonomy autonomous --auto-merge
```

### Faber-Cloud Plugin
```bash
# Deploy
/fractary-faber-cloud:deploy-apply --env test

# With description
/fractary-faber-cloud:design "S3 bucket for user uploads with versioning"

# Multiple flags
/fractary-faber-cloud:init --provider aws --iac terraform
```

### Codex Plugin
```bash
# Sync project
/fractary-codex:sync-project my-project --to-codex --dry-run

# Bidirectional
/fractary-codex:sync-project --bidirectional
```

## Command Documentation Template

All command files MUST include an `<ARGUMENT_SYNTAX>` section:

```markdown
<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Example**: `--description "Multi word value"` ✅
- **Wrong**: `--description Multi word value` ❌

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /plugin:command "Title" --body "Description with spaces"
✅ /plugin:command "Title" --flag value --flag2 "value with spaces"

❌ /plugin:command Title --body Description with spaces
```

**Single-word values don't require quotes:**
```bash
✅ /plugin:command "Title" --type feature
✅ /plugin:command "Title" --env test
```

**Boolean flags have no value:**
```bash
✅ /plugin:command "Title" --flag
✅ /plugin:command "Title" --flag --flag2

❌ /plugin:command "Title" --flag=true
❌ /plugin:command "Title" --flag true
```

**Specific type/enum values** (if applicable):
```bash
# Valid values: value1, value2, value3
✅ /plugin:command --type value1
❌ /plugin:command --type invalid
```
</ARGUMENT_SYNTAX>
```

## Argument Hint Format

The `argument-hint` in command frontmatter should use this format:

### Pattern

```markdown
argument-hint: [positional] [--flag <value>] [--flag2 <value>] [--boolean-flag]
```

### Examples

```markdown
# Command with required positional and optional flags
argument-hint: <work_id> [--domain <domain>] [--autonomy <level>] [--auto-merge]

# Command with optional positional and flags
argument-hint: [project-name] [--to-codex|--from-codex|--bidirectional] [--dry-run]

# Command with only flags
argument-hint: --env <environment> [--auto-approve]

# Command with required string and multiple optional
argument-hint: <title> [--type <type>] [--body <text>] [--label <label>]
```

### Conventions

- `<required>` - Required positional argument
- `[optional]` - Optional positional argument
- `[--flag <value>]` - Optional flag with value
- `[--flag1|--flag2]` - Mutually exclusive flags
- `[--boolean-flag]` - Boolean flag (no value)

## Standard Parsing Pattern

### Bash Implementation

```bash
#!/bin/bash

# Initialize variables
POSITIONAL_ARG=""
FLAG_VALUE=""
BOOLEAN_FLAG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --flag)
            # Flag with value - expect next arg is the value
            if [[ $# -lt 2 || "$2" =~ ^-- ]]; then
                echo "Error: --flag requires a value" >&2
                exit 2
            fi
            FLAG_VALUE="$2"
            shift 2
            ;;
        --boolean-flag)
            # Boolean flag - no value expected
            BOOLEAN_FLAG="true"
            shift
            ;;
        --*=*)
            # Detect and reject equals syntax
            echo "Error: Use space-separated syntax, not equals syntax" >&2
            echo "Use: ${1%%=*} <value>" >&2
            echo "Not: $1" >&2
            exit 2
            ;;
        --*)
            # Unknown flag
            echo "Error: Unknown flag: $1" >&2
            exit 2
            ;;
        *)
            # Positional argument
            if [[ -z "$POSITIONAL_ARG" ]]; then
                POSITIONAL_ARG="$1"
            else
                echo "Error: Unexpected argument: $1" >&2
                exit 2
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$POSITIONAL_ARG" ]]; then
    echo "Error: Missing required argument" >&2
    exit 2
fi
```

## Error Messages

### Missing Value

```
Error: --flag requires a value
Usage: /command [args] --flag <value>
```

### Equals Syntax Detected

```
Error: Use space-separated syntax, not equals syntax
Use: --env <value>
Not: --env=value

Example:
  ✅ /command --env test
  ❌ /command --env=test
```

### Invalid Flag

```
Error: Unknown flag: --invalid
Valid flags: --flag1, --flag2, --boolean-flag
```

### Missing Quotes

```
Error: Multi-word values must be quoted
Use: --description "Multi word value"
Not: --description Multi word value
```

## Agent and Skill Documentation

When agents and skills document command examples, they MUST follow this standard:

### In Agent Prompts

```markdown
<EXAMPLES>
## Command Examples

Invoke this agent using commands like:

```bash
/plugin:command "Argument" --flag value
/plugin:command "Argument" --flag "multi word value" --boolean-flag
```
</EXAMPLES>
```

### In Skill Workflows

```markdown
## Parameters Received

The skill receives parameters in this format:
- `flag`: Single or multi-word string value
- `boolean_flag`: Boolean (true/false)
- `positional_arg`: Required string value

When invoked via command:
```bash
/plugin:command "positional" --flag value --boolean-flag
```
```

## Testing Requirements

All commands MUST be tested with:

1. **Single-word values** - Without quotes
2. **Multi-word values** - With quotes
3. **Boolean flags** - Without values
4. **Multiple flags** - In various orders
5. **Special characters** - URLs, paths, punctuation
6. **Equals syntax** - Should reject with helpful error

## Migration from Equals Syntax

If migrating from equals syntax (`--flag=value`):

1. Update `argument-hint` in frontmatter
2. Add `<ARGUMENT_SYNTAX>` section
3. Update all examples
4. Update parsing logic:
   - Change `--flag=*)` to `--flag)`
   - Change `${1#*=}` to `$2`
   - Change `shift` to `shift 2`
5. Add equals syntax rejection case
6. Test all edge cases

## Rationale

**Why space-separated syntax?**

1. **Consistency** - Matches common CLI tools (git, npm, docker)
2. **Clarity** - Visual separation between flag and value
3. **Simplicity** - Easier to parse and understand
4. **Flexibility** - Better for optional flags and positional args
5. **Documentation** - Easier to document and explain
6. **Error handling** - Clearer error messages

**Why not equals syntax?**

1. Less intuitive for users
2. More complex parsing
3. Unclear quote handling
4. Harder to mix with positional args
5. Not better than space-separated for any use case

## References

- Git CLI: Uses space-separated (`git commit -m "message"`)
- npm CLI: Uses space-separated (`npm install --save package`)
- Docker CLI: Uses space-separated (`docker run --name container image`)
- GNU Standards: Recommends space-separated for long options

## Compliance

All new commands MUST follow this standard.

All existing commands SHOULD be migrated to this standard.

Deviations require explicit justification and documentation.

## See Also

- [Fractary Plugin Standards](./FRACTARY-PLUGIN-STANDARDS.md)
- [Command Development Guide](../guides/command-development.md)
- [Argument Parsing Library](./scripts/parse-arguments.sh) (to be created)
