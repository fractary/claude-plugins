# Logs Plugin v2.0 Migration Guide

## Overview

Logs plugin v2.0 introduces a **type-aware architecture** modeled after the docs plugin v2.0 refactoring. This guide helps you understand what changed and how to migrate.

## What's New in v2.0

### 1. Type Context System (8 Log Types)

Logs are now organized into **8 distinct types**, each with its own schema, template, standards, validation rules, and retention policy:

| Type | Retention (Local/Cloud) | Priority | Use Case |
|------|------------------------|----------|----------|
| **session** | 7d / forever | high | Claude Code conversations |
| **build** | 3d / 30d | medium | Build executions |
| **deployment** | 30d / forever | critical | Deployments (prod protected) |
| **debug** | 7d / 30d | medium | Error investigations |
| **test** | 3d / 7d | low | Test executions |
| **audit** | 90d / forever | critical | Security/compliance events |
| **operational** | 14d / 90d | medium | System maintenance |
| **_untyped** | 7d / 30d | low | Uncategorized logs |

**Type context files** (in `plugins/logs/types/{type}/`):
- `schema.json` - JSON Schema Draft 7 validation
- `template.md` - Mustache template structure
- `standards.md` - Logging conventions
- `validation-rules.md` - Type-specific checks
- `retention-config.json` - Retention policy

### 2. Operation-Specific Skills

New **universal operation skills** that work with ANY log type:

- **log-writer** - Create logs from templates (replaces type-specific creation logic)
- **log-classifier** - Detect log type from content (with confidence scoring)
- **log-validator** - Validate against schema + rules (type-aware)
- **log-lister** - List/filter logs by type (with retention status)

### 3. Coordination Skills

New **workflow orchestration** skills:

- **log-manager-skill** - Single-log workflows (classify → write → validate)
- **log-director-skill** - Multi-log batch operations (parallel archival, validation)

### 4. Streamlined Agent

`log-manager` agent reduced from ~500 lines to ~270 lines:
- Now a **pure routing wrapper**
- All logic moved to skills
- 60% context reduction
- Easier to extend with new operations

### 5. Per-Type Retention Policies

Retention is now **type-specific**:
- Audit logs: 90 days local (compliance)
- Test logs: 3 days local (low value, save space)
- Session logs: 7 days local, forever cloud (debugging)
- Production deployments: Never auto-delete (safety)

**Retention exceptions**:
- `never_delete_production` - Production deployments protected
- `keep_if_linked_to_open_issue` - Active work preserved
- `keep_recent_n` - Always keep N most recent
- `never_delete_security_incidents` - Security audits permanent

## Breaking Changes

### 1. Frontmatter Field Change

**v1.x**: Used `type:` field
```yaml
---
type: session
title: "My session"
---
```

**v2.0**: Uses `log_type:` field
```yaml
---
log_type: session
title: "My session"
---
```

**Migration**: Existing logs with `type:` will need reclassification. Use:
```bash
/fractary-logs:reclassify --all
```

### 2. Directory Structure

**v1.x**: Flat log storage
```
.fractary/logs/
  session-001.md
  build-001.md
```

**v2.0**: Type-specific directories
```
.fractary/logs/
  session/
    session-001.md
  build/
    build-001.md
  test/
    test-001.md
```

**Migration**: Logs will be moved to type directories on first `/fractary-logs:list` or classification.

### 3. Archive Index Format

**v1.x**: Simple array
```json
{
  "archives": [...]
}
```

**v2.0**: Type-aware with retention metadata
```json
{
  "version": "2.0",
  "type_aware": true,
  "archives": [...],
  "by_type": {
    "session": {"count": 12, "total_size_mb": 15.2}
  }
}
```

**Migration**: Index auto-upgrades on next archive operation.

## New Commands

v2.0 adds type-aware commands:

```bash
# Create typed log directly
/fractary-logs:write session '{"session_id": "...", "title": "..."}'

# Classify log content
/fractary-logs:classify "Test execution: 45 passed, 3 failed"
# → Returns: type=test, confidence=95%

# Validate log against schema
/fractary-logs:validate .fractary/logs/session/session-001.md

# List logs with type filter
/fractary-logs:list --type=test --status=failed

# Archive by type with retention check
/fractary-logs:archive --type=test --retention-expired

# Batch validate all logs
/fractary-logs:validate-all --type=session
```

## Backward Compatibility

**Existing commands still work**:
- `/fractary-logs:capture <issue>` - Still creates session logs
- `/fractary-logs:stop` - Still stops capture
- `/fractary-logs:archive <issue>` - Now type-aware
- `/fractary-logs:search "<query>"` - Now supports type filtering

**Skills refactored but compatible**:
- `log-capturer` - Now uses log-writer internally
- `log-archiver` - Now uses per-type retention
- `log-searcher` - Now supports type filtering
- `log-analyzer` - Now uses type-specific patterns

## Migration Steps

### Step 1: Update Plugin

```bash
cd ~/.claude-code/plugins
git pull  # or update however you manage plugins
```

### Step 2: Initialize Type Context

```bash
# Reinitialize to validate type context
/fractary-logs:init --validate-types
```

This checks all 8 type contexts are present.

### Step 3: Reclassify Existing Logs (Optional)

```bash
# Classify all existing logs
/fractary-logs:classify-all --auto-apply

# Or manually review:
/fractary-logs:classify-all --preview
```

This:
- Scans all logs without `log_type` field
- Classifies using log-classifier
- Moves to type-specific directories
- Updates frontmatter

### Step 4: Validate Logs

```bash
# Validate all logs against new schemas
/fractary-logs:validate-all --fix-auto

# Review validation errors
/fractary-logs:validate-all --report
```

### Step 5: Update Archive Index

```bash
# Rebuild index with type awareness
/fractary-logs:rebuild-index --type-aware
```

## What You Get

**Benefits of v2.0**:

✅ **Type-specific retention** - Test logs cleaned in 3 days, audit logs kept 90 days
✅ **Automatic validation** - Schema validation on all log creation
✅ **Better classification** - AI-powered type detection with confidence scoring
✅ **Faster operations** - 60% context reduction in agent = faster processing
✅ **Production safety** - Production deployments never auto-deleted
✅ **Compliance-ready** - Audit logs with 90-day retention + immutability
✅ **Consistent structure** - Mustache templates ensure uniform logs
✅ **Easier debugging** - Session logs kept forever in cloud
✅ **Space savings** - Short-lived logs (test, build) cleaned quickly

## Troubleshooting

### Issue: Logs not being classified

**Cause**: Missing `log_type` field in frontmatter

**Solution**:
```bash
/fractary-logs:classify <log_path> --auto-apply
```

### Issue: Validation failing after upgrade

**Cause**: Old logs missing required fields from new schemas

**Solution**:
```bash
# Auto-fix missing optional fields
/fractary-logs:validate <log_path> --fix-auto

# Or manually review and fix
/fractary-logs:validate <log_path> --report
```

### Issue: Archive operations failing

**Cause**: Archive index not upgraded to v2.0 format

**Solution**:
```bash
/fractary-logs:rebuild-index --force
```

### Issue: Retention not working as expected

**Cause**: Using old single retention policy vs new per-type

**Solution**: Check type's retention-config.json:
```bash
cat plugins/logs/types/session/retention-config.json
```

Retention policies now per-type, not global.

## Rollback

If you need to rollback to v1.x:

```bash
cd ~/.claude-code/plugins/fractary-logs
git checkout v1.x  # or your previous version tag
/fractary-logs:init --force
```

**Note**: Type-aware features will be lost, but existing logs will still work (with `type:` field).

## Support

Questions? Check:
- Plugin README: `plugins/logs/README.md`
- Type context: `plugins/logs/types/{type}/`
- Skill docs: `plugins/logs/skills/{skill}/SKILL.md`
- GitHub issues: [Report bugs](https://github.com/fractary/claude-plugins/issues)

## Summary

v2.0 = **Type-aware architecture** for smarter retention, better validation, and clearer organization. The migration is mostly automatic, with validation and classification tools to help transition existing logs.

Enjoy per-type retention policies that match log value! 🎯
