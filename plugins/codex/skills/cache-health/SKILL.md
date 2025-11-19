---
name: cache-health
description: Performs comprehensive diagnostics on the codex cache system, detects issues, and can fix them automatically with repair operations
---

# Cache Health Skill

<CONTEXT>
You are the Cache Health skill for the Codex plugin. Your responsibility is to perform comprehensive diagnostics on the cache system, detect issues, and optionally fix them automatically.
</CONTEXT>

<CRITICAL_RULES>
1. **READ-ONLY by default** - Only modify with --fix flag
2. **NEVER delete data** without explicit permission
3. **ALWAYS backup** before attempting repairs
4. **LOG all fixes** applied
5. **REPORT clearly** what was found and what was done
</CRITICAL_RULES>

<INPUTS>
Request format:
```json
{
  "operation": "health-check",
  "parameters": {
    "check_category": "all|cache|config|performance|storage|system",
    "verbose": false,
    "fix": false,
    "format": "text|json",
    "persist": false,
    "cache_path": "codex"
  }
}
```

**New Parameter**:
- `persist`: Boolean (default: false) - If true, generate persistent audit report via docs-manage-audit skill
</INPUTS>

<WORKFLOW>
1. **Cache Health Checks**
   - Directory exists and readable?
   - Index file exists and valid JSON?
   - All indexed files exist on disk?
   - All disk files are indexed?
   - File permissions correct?
   - No corrupted entries?

2. **Configuration Health Checks**
   - Config file exists?
   - Valid JSON format?
   - Required fields present (organization, codex_repo)?
   - Sources array present (v3.0)?
   - Source configurations valid?
   - TTL values reasonable (1-365 days)?
   - Handler references exist?

3. **Performance Health Checks**
   - Cache hit rate acceptable (> 70%)?
   - Average fetch time reasonable (< 3s)?
   - Failed fetch rate low (< 5%)?
   - Expired documents manageable (< 20%)?

4. **Storage Health Checks**
   - Disk space sufficient (> 1GB free)?
   - Cache size within configured limits?
   - Growth rate normal?
   - Compression working if enabled?

5. **System Health Checks**
   - Git installed and accessible?
   - jq installed and working?
   - Network connectivity available?
   - Write permissions on cache dir?

6. **Determine Overall Status**
   - Count: passed, warnings, errors
   - Overall: healthy | warning | error | critical
   - Exit code: 0 (ok) | 1 (warning) | 2 (error) | 3 (critical)

7. **Apply Fixes (if --fix)**
   - Remove orphaned files
   - Rebuild missing index entries
   - Fix file permissions
   - Clear expired documents
   - Repair corrupted entries
   - Log all changes made

8. **Generate Report**
   - Per-category results
   - Summary statistics
   - Recommendations
   - Fixes applied (if any)

9. **Persist Audit (if --persist)**
   - Invoke docs-manage-audit skill
   - Store audit report in logs/health/
   - Create dual-format report (README.md + audit.json)
   - Enable historical trend analysis
</WORKFLOW>

<COMPLETION_CRITERIA>
- All requested checks completed
- Issues detected and reported
- Fixes applied if requested
- Recommendations provided
- Overall status determined
</COMPLETION_CRITERIA>

<OUTPUTS>
## Text Format

```
🏥 Codex Health Check
═══════════════════════════════════════════════════════

[CACHE HEALTH section]
[CONFIG HEALTH section]
[PERFORMANCE HEALTH section]
[STORAGE HEALTH section]
[SYSTEM HEALTH section]

═══════════════════════════════════════════════════════

OVERALL STATUS: [✅ Healthy | ⚠️ Warning | ❌ Error]

Summary:
  Checks passed:  X/Y (Z%)
  Warnings:       N
  Errors:         M

[Recommendations if any]
[Fixes applied if --fix used]
```

## JSON Format

```json
{
  "cache": {
    "status": "pass|warning|error",
    "checks": [
      {"name": "directory_exists", "status": "pass"},
      {"name": "index_valid", "status": "pass"}
    ],
    "issues": []
  },
  "config": { ... },
  "performance": { ... },
  "storage": { ... },
  "system": { ... },
  "overall": {
    "status": "healthy|warning|error|critical",
    "checks_passed": 22,
    "checks_total": 24,
    "warnings": 2,
    "errors": 0,
    "exit_code": 1
  },
  "recommendations": [...],
  "fixes_applied": [...]
}
```
</OUTPUTS>

<DOCS_MANAGE_AUDIT_INTEGRATION>
## Step 9: Persist Audit Report (if --persist flag)

When the --persist flag is provided, invoke docs-manage-audit to create a persistent audit report:

```
Skill(skill="docs-manage-audit")
```

Then provide the health check data:

```
Use the docs-manage-audit skill to create system health audit report with the following parameters:
{
  "operation": "create",
  "audit_type": "system",
  "check_type": "cache-health",
  "audit_data": {
    "audit": {
      "type": "system",
      "check_type": "cache-health",
      "timestamp": "{ISO8601}",
      "duration_seconds": {duration},
      "auditor": {
        "plugin": "fractary-codex",
        "skill": "cache-health"
      },
      "audit_id": "{timestamp}-cache-health"
    },
    "summary": {
      "overall_status": "healthy|warning|error|critical",
      "status_counts": {
        "passing": {checks_passed},
        "warnings": {warnings},
        "failures": {errors}
      },
      "exit_code": {0|1|2|3}
    },
    "findings": {
      "categories": [
        {
          "name": "Cache",
          "status": "pass|warning|error",
          "checks_performed": {count},
          "passing": {count},
          "warnings": {count},
          "failures": {count}
        },
        {
          "name": "Configuration",
          "status": "pass|warning|error",
          "checks_performed": {count},
          "passing": {count},
          "warnings": {count},
          "failures": {count}
        },
        {
          "name": "Performance",
          "status": "pass|warning|error",
          "checks_performed": {count},
          "passing": {count},
          "warnings": {count},
          "failures": {count}
        },
        {
          "name": "Storage",
          "status": "pass|warning|error",
          "checks_performed": {count},
          "passing": {count},
          "warnings": {count},
          "failures": {count}
        },
        {
          "name": "System",
          "status": "pass|warning|error",
          "checks_performed": {count},
          "passing": {count},
          "warnings": {count},
          "failures": {count}
        }
      ],
      "by_severity": {
        "critical": [
          {
            "id": "cache-001",
            "severity": "critical",
            "category": "storage",
            "check": "disk_space",
            "message": "Disk space critically low",
            "details": "< 100MB available",
            "remediation": "Free up disk space or expand storage"
          }
        ],
        "high": [{finding}],
        "medium": [{finding}],
        "low": [{finding}]
      }
    },
    "metrics": {
      "cache_hit_rate": {percentage},
      "avg_fetch_time_ms": {time},
      "failed_fetch_rate": {percentage},
      "cache_size_mb": {size},
      "disk_free_mb": {free_space},
      "documents_total": {count},
      "documents_expired": {count}
    },
    "recommendations": [
      {
        "priority": "critical|high|medium|low",
        "category": "system",
        "recommendation": "{action}",
        "impact": "{description}"
      }
    ],
    "extensions": {
      "system": {
        "auto_fix_available": {boolean},
        "auto_fix_results": [{fix_applied}],
        "performance_metrics": {
          "cache_hit_rate": {percentage},
          "avg_fetch_time_ms": {time},
          "failed_fetch_rate": {percentage}
        },
        "dependency_status": {
          "git": "installed|missing",
          "jq": "installed|missing",
          "network": "available|unavailable"
        }
      }
    }
  },
  "output_path": "logs/health/",
  "project_root": "{project-root}"
}
```

This will generate:
- **README.md**: Human-readable health dashboard
- **audit.json**: Machine-readable health data

Both files in `logs/health/{timestamp}-cache-health.[md|json]`

**Benefits of Persistence**:
- Historical health trend analysis
- Compare health over time
- Track fixes applied
- Identify recurring issues
- Audit trail for debugging

**Default Behavior**: Without --persist, health checks remain real-time diagnostics (displayed but not saved).
</DOCS_MANAGE_AUDIT_INTEGRATION>

<SCRIPTS>
Use the following script for health checks:

```bash
./skills/cache-health/scripts/run-health-check.sh "$cache_path" "$check_category" "$verbose" "$fix" "$format"
```

The script returns health check results with pass/warning/error status.
</SCRIPTS>

<DOCUMENTATION>
After health check, provide guidance:

1. **If all checks pass**:
   - Confirm system is healthy
   - Mention any minor recommendations
   - Suggest periodic health checks

2. **If warnings present**:
   - Explain each warning
   - Provide resolution steps
   - Estimate impact if not resolved
   - Offer to fix automatically

3. **If errors detected**:
   - Detail each error
   - Provide step-by-step fix instructions
   - Suggest backup before manual fixes
   - Offer to attempt automatic repair

4. **If critical failure**:
   - Explain severity
   - Recommend immediate action
   - Provide rollback/recovery steps
   - May need to rebuild cache
</DOCUMENTATION>

<ERROR_HANDLING>
- **Cache not found**: Not an error, just not initialized yet
- **Permission denied**: Report as error, suggest chmod/chown
- **Disk full**: Critical error, suggest freeing space
- **Corrupted index**: Attempt repair with --fix, or rebuild
- **Missing dependencies**: Report which tools are missing
</ERROR_HANDLING>
