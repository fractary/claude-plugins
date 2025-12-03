---
name: check-consistency
description: Check if high-level project documentation is consistent with recent code changes
model: claude-haiku-4-5
argument-hint: "[--fix] [--targets <files>] [--base <ref>]"
---

# /docs:check-consistency

Check if high-level project documentation (CLAUDE.md, README.md, etc.) is consistent with recent code changes.

## Usage

```bash
# Check all default targets
/docs:check-consistency

# Check specific targets
/docs:check-consistency --targets "CLAUDE.md,README.md"

# Check and auto-fix (with confirmation)
/docs:check-consistency --fix

# Check against specific base branch
/docs:check-consistency --base develop
```

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `--fix` | Generate and apply update suggestions | false |
| `--targets` | Comma-separated list of target docs | CLAUDE.md,README.md,docs/README.md,CONTRIBUTING.md |
| `--base` | Base git reference for comparison | main |
| `--head` | Head git reference for comparison | HEAD |
| `--mode` | Operation mode: confirm, auto, dry-run | confirm |

## Default Targets

The following documents are checked by default:
- `CLAUDE.md` - Project instructions for Claude Code
- `README.md` - Main project readme
- `docs/README.md` - Documentation index
- `CONTRIBUTING.md` - Contribution guidelines

## What It Checks

The command analyzes the git diff between base and head refs and identifies:

1. **API Changes** - New endpoints, modified schemas, authentication changes
2. **Feature Changes** - New commands, skills, modified functionality
3. **Architecture Changes** - New components, modified dependencies
4. **Configuration Changes** - Environment variables, config formats

It then determines which documentation sections may need updates based on the type of changes detected.

## Example Output

```
🎯 STARTING: Documentation Consistency Check
Targets: CLAUDE.md, README.md, docs/README.md, CONTRIBUTING.md
Base: main → Head: HEAD
───────────────────────────────────────

📊 Changes Detected:
  Features: 2 new skills added
  Architecture: 1 config file modified
  Configuration: 0

📄 Document Status:
  ⚠️  CLAUDE.md - STALE
      Sections affected: Directory Structure, Common Development Tasks
  ✅ README.md - Current
  ✅ docs/README.md - Current
  ⏭️  CONTRIBUTING.md - Not found

───────────────────────────────────────
✅ COMPLETED: Documentation Consistency Check
Status: stale
Documents needing updates: 1
───────────────────────────────────────
Next: Run with --fix to generate update suggestions
```

## Integration with FABER

This command is automatically invoked during the FABER Release phase to ensure documentation is updated before PR creation.

## Invoke Skill

Use the @skill-fractary-docs:doc-consistency-checker skill with the following request:

```json
{
  "operation": "check",
  "parameters": {
    "targets": ["CLAUDE.md", "README.md", "docs/README.md", "CONTRIBUTING.md"],
    "base_ref": "main",
    "head_ref": "HEAD",
    "mode": "confirm"
  }
}
```
