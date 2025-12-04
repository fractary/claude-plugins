# Migrating to faber-cloud v2.0.0

**Date:** 2025-11-03
**Breaking Changes:** Yes
**Migration Required:** For operations monitoring users

---

## Overview

Version 2.0.0 of faber-cloud represents a **clean architectural separation** where:
- **faber-cloud** = Infrastructure lifecycle (architect → build → test → deploy)
- **helm-cloud** = Operations monitoring (monitor → investigate → remediate → audit)

This separation creates cleaner boundaries, better maintainability, and prepares for unified cross-domain monitoring via the central `helm` plugin.

---

## Breaking Changes

### 1. Operations Monitoring Removed

**Removed from faber-cloud:**
- `ops-manager` agent
- `ops-monitor` skill
- `ops-investigator` skill
- `ops-responder` skill
- `ops-auditor` skill
- `/fractary-faber-cloud:ops-manage` command

**Moved to helm-cloud:**
All operations monitoring functionality is now in the `fractary-helm-cloud` plugin.

### 2. Command Changes

| Old Command (v1.x) | Status | New Command (v2.0.0) |
|--------------------|---------|----------------------|
| `/fractary-faber-cloud:ops-manage check-health` | ❌ **REMOVED** | `/fractary-helm-cloud:health` |
| `/fractary-faber-cloud:ops-manage query-logs` | ❌ **REMOVED** | `/fractary-helm-cloud:investigate` |
| `/fractary-faber-cloud:ops-manage investigate` | ❌ **REMOVED** | `/fractary-helm-cloud:investigate` |
| `/fractary-faber-cloud:ops-manage remediate` | ❌ **REMOVED** | `/fractary-helm-cloud:remediate` |
| `/fractary-faber-cloud:ops-manage audit` | ❌ **REMOVED** | `/fractary-helm-cloud:audit` |
| `/fractary-faber-cloud:architect` | ✅ **WORKS** | No change |
| `/fractary-faber-cloud:deploy` | ✅ **WORKS** | No change |
| `/fractary-faber-cloud:infra-manage ...` | ⚠️ **DEPRECATED** | Use simplified commands |

### 3. Configuration Changes

**faber-cloud configuration:**
- Location: `.fractary/plugins/faber-cloud/config.json`
- **No changes required** for infrastructure operations (migrates from devops.json automatically)

**helm-cloud configuration:**
- New location: `.fractary/plugins/helm-cloud/` (optional)
- Shares deployment registry: `.fractary/registry/deployments.json`
- Shares AWS credentials: `.fractary/shared/aws-credentials.json`

---

## Migration Steps

### Step 1: Install helm-cloud Plugin

```bash
# Helm-cloud should already be installed if you had faber-cloud v1.2.0
# If not, install it:
cd ~/.claude-code/plugins/
git clone https://github.com/fractary/claude-plugins.git
# Or ensure plugins/helm-cloud/ exists in your workspace
```

### Step 2: Update Commands in Scripts/Workflows

If you have scripts or workflows using faber-cloud operations commands:

**Before (v1.x):**
```bash
#!/bin/bash
/fractary-faber-cloud:ops-manage check-health --env=prod
/fractary-faber-cloud:ops-manage investigate --service=api-lambda
```

**After (v2.0.0):**
```bash
#!/bin/bash
/fractary-helm-cloud:health --env=prod
/fractary-helm-cloud:investigate --env=prod --service=api-lambda
```

### Step 3: Update Natural Language Commands

If using the director with natural language:

**Before (v1.x):**
```bash
/fractary-faber-cloud:director "check health of production"
# Routed to ops-manager
```

**After (v2.0.0):**
```bash
# Director will inform you to use helm-cloud:
/fractary-faber-cloud:director "check health of production"
# Response: "Operations monitoring has moved to helm-cloud. Please use:"
#           "/fractary-helm-cloud:health --env=prod"

# Use helm-cloud directly:
/fractary-helm-cloud:health --env=prod

# Or use unified dashboard:
/fractary-helm:dashboard
```

### Step 4: Verify Configuration (Optional)

Check that deployment registry is accessible:

```bash
ls .fractary/registry/deployments.json
```

If it doesn't exist, it will be created on first deployment.

### Step 5: Test Infrastructure Operations

Verify infrastructure commands still work:

```bash
# These should work unchanged:
/fractary-faber-cloud:architect "S3 bucket for uploads"
/fractary-faber-cloud:validate --env=test
/fractary-faber-cloud:deploy --env=test
/fractary-faber-cloud:list --env=test
```

### Step 6: Test Operations Monitoring

Verify operations commands work with helm-cloud:

```bash
# New commands:
/fractary-helm-cloud:health --env=test
/fractary-helm-cloud:investigate --env=test
/fractary-helm:dashboard
```

### Step 7: Upgrade to v2.0.0

Once you've verified everything works:

```bash
# Update faber-cloud to v2.0.0
# (This will remove ops-* components)

# Verify version:
cat plugins/faber-cloud/.claude-plugin/plugin.json
# Should show "version": "2.0.0"
```

---

## Command Migration Reference

### Health Monitoring

**Old:**
```bash
/fractary-faber-cloud:ops-manage check-health --env=prod
/fractary-faber-cloud:ops-manage check-health --env=prod --service=api-lambda
```

**New:**
```bash
/fractary-helm-cloud:health --env=prod
/fractary-helm-cloud:health --env=prod --service=api-lambda
```

### Log Investigation

**Old:**
```bash
/fractary-faber-cloud:ops-manage query-logs --env=prod --filter=ERROR
/fractary-faber-cloud:ops-manage investigate --env=prod --service=api-lambda
```

**New:**
```bash
/fractary-helm-cloud:investigate --env=prod --filter=ERROR
/fractary-helm-cloud:investigate --env=prod --service=api-lambda
```

### Remediation

**Old:**
```bash
/fractary-faber-cloud:ops-manage remediate --env=prod --service=api-lambda --action=restart
```

**New:**
```bash
/fractary-helm-cloud:remediate --env=prod --service=api-lambda --action=restart
```

### Auditing

**Old:**
```bash
/fractary-faber-cloud:ops-manage audit --env=test --focus=cost
/fractary-faber-cloud:ops-manage audit --env=prod --focus=security
```

**New:**
```bash
/fractary-helm-cloud:audit --type=cost --env=test
/fractary-helm-cloud:audit --type=security --env=prod
```

### Unified Dashboard (NEW in Helm)

**No equivalent in v1.x:**
```bash
/fractary-helm:dashboard
/fractary-helm:dashboard --env=prod
/fractary-helm:issues --critical
/fractary-helm:status
```

---

## What Stays the Same

### Infrastructure Commands (No Changes)

All infrastructure lifecycle commands remain unchanged:

```bash
# Design
/fractary-faber-cloud:architect "API service"

# Build
/fractary-faber-cloud:engineer api-service

# Validate
/fractary-faber-cloud:validate --env=test

# Test
/fractary-faber-cloud:test --env=test --phase=pre-deployment

# Preview
/fractary-faber-cloud:deploy-plan --env=test

# Deploy
/fractary-faber-cloud:deploy --env=test

# Status
/fractary-faber-cloud:status --env=test

# Resources
/fractary-faber-cloud:list --env=test

# Debug
/fractary-faber-cloud:debug --error="AccessDenied"
```

### Configuration Files

Infrastructure configuration remains the same:
- `.fractary/plugins/faber-cloud/devops.json`
- AWS profiles
- Terraform settings
- Resource naming patterns

---

## Benefits of Migration

### 1. Clean Separation
- **faber-cloud:** Pure infrastructure lifecycle (FABER workflow)
- **helm-cloud:** Pure operations monitoring (Helm workflow)
- Clear boundaries, easier to maintain

### 2. Unified Monitoring
- **helm plugin:** Central dashboard across all domains
- Cross-domain issue prioritization
- FABER escalation integration

### 3. Better Extensibility
- Add new domains easily (helm-app, helm-content, etc.)
- No coupling between creation and monitoring
- Registry-based domain discovery

### 4. Focused Responsibility
- faber-cloud focuses on "making things"
- helm-cloud focuses on "monitoring things"
- Each plugin does one thing well

---

## Troubleshooting

### Error: "Command not found: ops-manage"

**Problem:** Trying to use removed operations command

**Solution:**
```bash
# Instead of:
/fractary-faber-cloud:ops-manage check-health --env=prod

# Use:
/fractary-helm-cloud:health --env=prod
```

### Error: "Agent not found: ops-manager"

**Problem:** faber-cloud v2.0.0 removed ops-manager

**Solution:** Install and use helm-cloud:
```bash
# Ensure helm-cloud is installed
ls plugins/helm-cloud/

# Use helm-cloud commands
/fractary-helm-cloud:health --env=prod
```

### Operations commands don't work

**Problem:** Upgraded to v2.0.0 but still using old commands

**Solution:** Update all operations commands to use helm-cloud:
- Find: `/fractary-faber-cloud:ops-manage`
- Replace with: `/fractary-helm-cloud:` (with appropriate new command)

### Infrastructure commands still work fine

**Expected behavior:** Infrastructure commands are unchanged in v2.0.0. Only operations monitoring was removed.

---

## Rollback (If Needed)

If you need to rollback to v1.x:

```bash
# Restore v1.2.0 (last version before breaking changes)
git checkout v1.2.0 plugins/faber-cloud/

# Or use v1.2.0 from releases
```

**Note:** We recommend migrating to v2.0.0 for clean architecture and access to new Helm features.

---

## Support

### Migration Issues

If you encounter issues during migration:
1. Check this guide for common problems
2. Verify helm-cloud is installed
3. Test commands individually
4. Report issues: https://github.com/fractary/claude-plugins/issues

### Questions

- **Infrastructure questions:** Use faber-cloud documentation
- **Operations questions:** Use helm-cloud documentation
- **General questions:** See CLAUDE.md or open an issue

---

## Summary

**Migration Checklist:**
- [ ] Install helm-cloud plugin
- [ ] Update scripts/workflows (ops-manage → helm-cloud commands)
- [ ] Update natural language commands
- [ ] Test infrastructure operations (should work unchanged)
- [ ] Test operations monitoring (with helm-cloud)
- [ ] Upgrade to faber-cloud v2.0.0
- [ ] Remove v1.x references

**Key Takeaway:**
- **Infrastructure** = faber-cloud (unchanged)
- **Operations** = helm-cloud (new location)

**Timeline:**
- v1.2.0: Both work (transition period)
- v2.0.0: Operations removed from faber-cloud

**Resources:**
- [helm-cloud Documentation](../../helm-cloud/docs/README.md)
- [helm Plugin Documentation](../../helm/README.md)
- [Phase 4 Summary](../../../PHASE-4-IMPLEMENTATION-SUMMARY.md)

---

**End of Migration Guide**
