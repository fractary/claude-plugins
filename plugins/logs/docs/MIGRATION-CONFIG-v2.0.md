# Migration Guide: Logs Config v1.x → v2.0

## Overview

Version 2.0 introduces **centralized, path-based retention configuration** in `config.json`. This replaces the old plugin-level retention configs in `plugins/logs/types/{type}/retention-config.json`.

**Key changes:**
- ✅ All retention settings in **one file**: `.fractary/plugins/logs/config.json`
- ✅ **Path-based matching**: Use glob patterns to match logs to retention policies
- ✅ **User-customizable**: Configure retention per project, not globally
- ✅ **Sensible defaults**: Init generates comprehensive config with 9 log types
- ❌ **Deprecated**: `plugins/logs/types/{type}/retention-config.json` files no longer used

## Breaking Changes

### Configuration Structure

**v1.x (OLD)**:
```json
{
  "schema_version": "1.1",
  "retention": {
    "strategy": "hybrid",
    "local_days": 30,
    "cloud_days": "forever",
    "auto_archive_on_age": true,
    "auto_archive_threshold_days": 7
  }
}
```

Plugin source had separate files:
- `plugins/logs/types/session/retention-config.json`
- `plugins/logs/types/build/retention-config.json`
- `plugins/logs/types/deployment/retention-config.json`

**v2.0 (NEW)**:
```json
{
  "schema_version": "2.0",
  "retention": {
    "default": {
      "local_days": 30,
      "cloud_days": "forever",
      "priority": "medium",
      "auto_archive": true,
      "cleanup_after_archive": true
    },
    "paths": [
      {
        "pattern": "sessions/*",
        "log_type": "session",
        "local_days": 7,
        "cloud_days": "forever",
        "priority": "high",
        "auto_archive": true,
        "cleanup_after_archive": false,
        "retention_exceptions": {
          "keep_if_linked_to_open_issue": true,
          "keep_recent_n": 10
        },
        "archive_triggers": {
          "age_days": 7,
          "size_mb": null,
          "status": ["stopped", "error"]
        },
        "compression": {
          "enabled": true,
          "format": "gzip",
          "threshold_mb": 1
        },
        "validation": {
          "require_summary": true,
          "require_redaction_check": true,
          "warn_if_no_decisions": true
        }
      }
    ]
  }
}
```

All retention settings now in user's config file, not plugin source.

## Migration Steps

### Automatic Migration (Recommended)

The easiest way to migrate is to re-initialize:

```bash
# Backup your current config (optional)
cp .fractary/plugins/logs/config.json .fractary/plugins/logs/config.json.v1.backup

# Re-initialize with v2.0 config
/fractary-logs:init --force

# Review and customize the new config
vim .fractary/plugins/logs/config.json
```

This generates a comprehensive v2.0 config with sensible defaults for all log types.

### Manual Migration

If you have custom retention settings in v1.x, map them to the new structure:

#### Step 1: Update Schema Version

```json
{
  "schema_version": "2.0"  // Change from "1.1" to "2.0"
}
```

#### Step 2: Convert Global Retention to Default

**Old (v1.x)**:
```json
{
  "retention": {
    "strategy": "hybrid",
    "local_days": 30,
    "cloud_days": "forever"
  }
}
```

**New (v2.0)**:
```json
{
  "retention": {
    "default": {
      "local_days": 30,
      "cloud_days": "forever",
      "priority": "medium",
      "auto_archive": true,
      "cleanup_after_archive": true
    }
  }
}
```

#### Step 3: Add Path-Specific Policies

Copy retention policies from plugin source (`plugins/logs/types/{type}/retention-config.json`) into your config as path rules:

```json
{
  "retention": {
    "default": { /* ... */ },
    "paths": [
      {
        "pattern": "sessions/*",
        "log_type": "session",
        "local_days": 7,
        "cloud_days": "forever",
        "priority": "high",
        "auto_archive": true,
        "cleanup_after_archive": false,
        "retention_exceptions": {
          "keep_if_linked_to_open_issue": true,
          "keep_recent_n": 10
        },
        "archive_triggers": {
          "age_days": 7,
          "size_mb": null,
          "status": ["stopped", "error"]
        },
        "compression": {
          "enabled": true,
          "format": "gzip",
          "threshold_mb": 1
        }
      },
      // Add more path policies as needed
    ]
  }
}
```

#### Step 4: Validate Config

```bash
# Install ajv-cli if not already installed
npm install -g ajv-cli

# Validate against schema
ajv validate \
  -s plugins/logs/config/config.schema.json \
  -d .fractary/plugins/logs/config.json
```

## Configuration Reference

### Path-Based Retention Structure

Each entry in `retention.paths` array supports:

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `pattern` | string | Glob pattern (e.g., `sessions/*`) | ✅ Yes |
| `log_type` | string | Logical type (session, build, etc.) | No |
| `local_days` | number | Days to keep locally (1-365) | No |
| `cloud_days` | string\|number | Days in cloud or "forever" | No |
| `priority` | string | critical\|high\|medium\|low | No |
| `auto_archive` | boolean | Enable automatic archival | No |
| `cleanup_after_archive` | boolean | Remove local after archive | No |
| `retention_exceptions` | object | Special rules (see below) | No |
| `archive_triggers` | object | When to archive (see below) | No |
| `compression` | object | Compression settings (see below) | No |
| `validation` | object | Validation rules (see below) | No |
| `metadata` | object | Documentation (see below) | No |

### Retention Exceptions

```json
{
  "retention_exceptions": {
    "keep_if_linked_to_open_issue": true,
    "keep_if_referenced_in_docs": true,
    "keep_recent_n": 10,
    "never_delete_production": true,
    "never_delete_security_incidents": true,
    "never_delete_compliance_audits": true
  }
}
```

### Archive Triggers

```json
{
  "archive_triggers": {
    "age_days": 7,
    "size_mb": null,
    "status": ["stopped", "error", "success", "failure"]
  }
}
```

### Compression Settings

```json
{
  "compression": {
    "enabled": true,
    "format": "gzip",  // or "bzip2", "xz"
    "threshold_mb": 1
  }
}
```

### Validation Rules

```json
{
  "validation": {
    "require_summary": true,
    "require_redaction_check": true,
    "warn_if_no_decisions": true,
    "warn_if_no_errors_on_failure": true,
    "require_health_checks_for_production": true,
    "require_rollback_plan_for_production": true
  }
}
```

## Default Policies

When you run `/fractary-logs:init`, these policies are created:

| Log Type | Pattern | Local Days | Cloud Days | Priority | Notes |
|----------|---------|------------|------------|----------|-------|
| Session | `sessions/*` | 7 | forever | high | Keep decisions forever |
| Build | `builds/*` | 3 | 30 | medium | Short-term relevance |
| Deployment | `deployments/*` | 30 | forever | critical | Audit trail, never delete production |
| Test | `test/*` | 3 | 7 | low | Temporary debugging |
| Debug | `debug/*` | 7 | 30 | medium | Issue tracking |
| Audit | `audit/*` | 90 | forever | critical | Compliance, never delete security/compliance |
| Operational | `operational/*` | 14 | 90 | medium | Metrics, monitoring |
| Workflow | `workflow/*` | 7 | forever | high | FABER workflow logs |
| Changelog | `changelog/*` | 7 | forever | high | Release history |

## Path Matching Algorithm

Logs are matched against patterns in order:

1. Extract relative path from `/logs/` directory
   - Example: `/logs/sessions/session-123.md` → `sessions/session-123.md`

2. Test against each pattern in `retention.paths` array (in order)
   - Uses bash glob matching (`sessions/*` matches `sessions/session-123.md`)

3. First match wins
   - If pattern matches, use that path's retention policy

4. Fallback to default
   - If no pattern matches, use `retention.default` policy

**Example**:
```json
{
  "retention": {
    "paths": [
      {"pattern": "sessions/prod-*", "local_days": 30},  // Checked first
      {"pattern": "sessions/*", "local_days": 7},        // Checked second
      {"pattern": "*/critical-*", "local_days": 90}      // Checked third
    ]
  }
}
```

- `/logs/sessions/prod-123.md` → matches `sessions/prod-*` (30 days)
- `/logs/sessions/dev-123.md` → matches `sessions/*` (7 days)
- `/logs/builds/critical-build.log` → matches `*/critical-*` (90 days)
- `/logs/test/test-1.log` → no match, uses default policy

## Customization Examples

### Separate Production from Dev Deployments

```json
{
  "paths": [
    {
      "pattern": "deployments/prod-*",
      "local_days": 90,
      "cloud_days": "forever",
      "priority": "critical",
      "retention_exceptions": {
        "never_delete_production": true
      }
    },
    {
      "pattern": "deployments/dev-*",
      "local_days": 7,
      "cloud_days": 30,
      "priority": "medium"
    },
    {
      "pattern": "deployments/*",
      "local_days": 14,
      "cloud_days": 90,
      "priority": "high"
    }
  ]
}
```

### High-Value Debug Sessions

```json
{
  "paths": [
    {
      "pattern": "debug/production-incident-*",
      "local_days": 180,
      "cloud_days": "forever",
      "priority": "critical",
      "retention_exceptions": {
        "never_delete_security_incidents": true
      }
    },
    {
      "pattern": "debug/*",
      "local_days": 7,
      "cloud_days": 30,
      "priority": "medium"
    }
  ]
}
```

### Compliance Logs

```json
{
  "paths": [
    {
      "pattern": "audit/compliance-*",
      "local_days": 365,
      "cloud_days": "forever",
      "priority": "critical",
      "retention_exceptions": {
        "never_delete_compliance_audits": true
      },
      "validation": {
        "require_summary": true,
        "require_redaction_check": false
      }
    },
    {
      "pattern": "audit/security-*",
      "local_days": 365,
      "cloud_days": "forever",
      "priority": "critical",
      "retention_exceptions": {
        "never_delete_security_incidents": true
      }
    }
  ]
}
```

## Troubleshooting

### Config Validation Fails

```bash
# Check JSON syntax
jq . .fractary/plugins/logs/config.json

# Validate against schema
ajv validate \
  -s plugins/logs/config/config.schema.json \
  -d .fractary/plugins/logs/config.json
```

### Logs Not Matching Expected Policy

Test path matching:
```bash
# Test a specific log path
/home/user/claude-plugins/plugins/logs/skills/log-archiver/scripts/load-retention-policy.sh \
  "/logs/sessions/session-123.md" \
  ".fractary/plugins/logs/config.json"
```

This shows which policy matched (or if it fell back to default).

### Old Config Still Being Used

Make sure you've updated `schema_version` to `"2.0"`. The plugin checks this field to determine which config structure to use.

## Rollback

If you need to rollback to v1.x:

```bash
# Restore backup
cp .fractary/plugins/logs/config.json.v1.backup .fractary/plugins/logs/config.json

# Or regenerate v1.x config
# (requires v1.x plugin version)
```

## Benefits of v2.0

✅ **Single source of truth** - all retention settings in one config file
✅ **Project-specific** - customize per project, commit to version control
✅ **Flexible matching** - glob patterns support complex path hierarchies
✅ **Gradual migration** - old v1.x configs still work (deprecated)
✅ **Better defaults** - init creates comprehensive config for all log types
✅ **More control** - per-path compression, validation, exceptions
✅ **Self-documenting** - metadata field explains each log type

## Getting Help

- **Schema reference**: `plugins/logs/config/config.schema.json`
- **Example config**: `plugins/logs/config/config.example.json`
- **Plugin docs**: `plugins/logs/README.md`
- **Skill docs**: `plugins/logs/skills/log-archiver/SKILL.md`
