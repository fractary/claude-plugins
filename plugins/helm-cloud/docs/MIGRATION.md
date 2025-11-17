# Migrating from faber-cloud ops-* to helm-cloud

**Version:** 1.0.0
**Date:** 2025-11-03

---

## Overview

Operations monitoring functionality has been extracted from `fractary-faber-cloud` into a separate `fractary-helm-cloud` plugin. This migration provides:

✅ Clear separation of concerns (creation vs. operations)
✅ Improved command structure (direct vs. nested)
✅ Foundation for centralized Helm dashboard
✅ Backward compatibility during transition

---

## Command Changes

### Health Checking

**Old:**
```bash
/fractary-faber-cloud:ops-manage check-health --env=test
```

**New:**
```bash
/fractary-helm-cloud:health --env=test
```

---

### Log Investigation

**Old:**
```bash
/fractary-faber-cloud:ops-manage query-logs --env=prod --service=api --filter=ERROR
/fractary-faber-cloud:ops-manage investigate --env=prod --service=api
```

**New:**
```bash
/fractary-helm-cloud:investigate "query error logs from API" --env=prod
/fractary-helm-cloud:investigate "API service errors" --env=prod
```

---

### Remediation

**Old:**
```bash
/fractary-faber-cloud:ops-manage remediate --env=prod --service=lambda --action=restart
```

**New:**
```bash
/fractary-helm-cloud:remediate --action=restart_lambda --env=prod
/fractary-helm-cloud:remediate "restart the API Lambda" --env=prod
```

---

### Auditing

**Old:**
```bash
/fractary-faber-cloud:ops-manage audit --env=test --focus=cost
```

**New:**
```bash
/fractary-helm-cloud:audit --type=cost --env=test
```

---

## Configuration Changes

### Monitoring Configuration

**Old location:**
- Part of `.fractary/plugins/faber-cloud/config/devops.json`

**New location:**
- Monitoring-specific: `.fractary/plugins/helm-cloud/config/monitoring.toml`
- Shared AWS config: `.fractary/shared/aws-credentials.json`
- Shared environments: `.fractary/shared/environments.json`

### Setup Steps

1. **Create monitoring configuration:**
   ```bash
   mkdir -p .fractary/plugins/helm-cloud/config
   cp plugins/helm-cloud/config/monitoring.example.toml \
      .fractary/plugins/helm-cloud/config/monitoring.toml
   ```

2. **Configure monitoring settings:**
   Edit `.fractary/plugins/helm-cloud/config/monitoring.toml`:
   ```toml
   [monitoring]
   health_check_interval = "5m"

   [slos.lambda]
   error_rate_percent = 0.1
   p95_latency_ms = 200

   [remediation]
   auto_remediate = ["restart_lambda", "clear_cache"]
   ```

3. **Verify shared AWS config** (created automatically if using faber-cloud):
   ```bash
   cat .fractary/shared/aws-credentials.json
   ```

---

## Deployment Registry

### Shared Registry Location

**Old:**
- `.fractary/plugins/faber-cloud/deployments/{env}/`

**New:**
- `.fractary/registry/deployments.json` (shared between plugins)

### Migration

**Automatic:** If you have existing faber-cloud deployments, they will be accessible to helm-cloud through the shared registry.

**Manual check:**
```bash
# Verify registry exists
cat .fractary/registry/deployments.json

# Should show deployments from faber-cloud
```

---

## Natural Language Interface

### devops-director Updates

The `devops-director` agent now routes operations requests to helm-cloud:

**Before:**
```
User: "check health of production"
→ Routes to: /fractary-faber-cloud:ops-manage check-health --env=prod
```

**After:**
```
User: "check health of production"
→ Routes to: /fractary-helm-cloud:health --env=prod
```

**Backward compatibility:** Director can still route to ops-manage for transition period.

---

## Backward Compatibility

### Delegation Layer

For backward compatibility, the old commands still work via delegation:

```
/fractary-faber-cloud:ops-manage check-health --env=test
  ↓ (shows deprecation warning)
  ↓ (delegates to)
/fractary-helm-cloud:health --env=test
```

### Timeline

| Phase | Status | Details |
|-------|--------|---------|
| **Now** | ✅ Both work | Old and new commands functional |
| **Transition** | ⚠️ Deprecated | Old commands show warnings |
| **faber-cloud v2.0.0** | ❌ Removed | Old commands no longer available |
| **Support period** | 📅 6 months | Time to complete migration |

---

## Migration Checklist

### For End Users

- [ ] Install helm-cloud plugin (if not automatic)
- [ ] Update scripts/workflows to use new commands
- [ ] Test health checks work: `/fractary-helm-cloud:health --env=test`
- [ ] Test investigations work: `/fractary-helm-cloud:investigate "test query" --env=test`
- [ ] Verify monitoring config exists: `.fractary/plugins/helm-cloud/config/monitoring.toml`
- [ ] Update documentation/runbooks with new commands

### For Plugin Developers

- [ ] helm-cloud plugin installed and registered
- [ ] Shared configuration structure created (`.fractary/registry/`, `.fractary/shared/`)
- [ ] ops-manager and ops-* skills copied to helm-cloud
- [ ] Internal references updated to `fractary-helm-cloud`
- [ ] Commands created (health, investigate, remediate, audit)
- [ ] Delegation layer in faber-cloud operational
- [ ] devops-director routes to helm-cloud
- [ ] Documentation updated
- [ ] Tests passing

---

## Testing Your Migration

### 1. Health Check

**Old command (should show deprecation warning):**
```bash
/fractary-faber-cloud:ops-manage check-health --env=test
```

**New command:**
```bash
/fractary-helm-cloud:health --env=test
```

**Expected:** Both work, new command doesn't show warning.

---

### 2. Investigation

**Test query:**
```bash
/fractary-helm-cloud:investigate "test investigation" --env=test
```

**Expected:** Can query CloudWatch Logs, analyze patterns.

---

### 3. Configuration

**Verify monitoring config:**
```bash
cat .fractary/plugins/helm-cloud/config/monitoring.toml
```

**Expected:** File exists with valid TOML.

**Verify AWS config:**
```bash
cat .fractary/shared/aws-credentials.json
```

**Expected:** File exists with AWS account and profiles.

---

### 4. Registry Access

**Check deployments:**
```bash
cat .fractary/registry/deployments.json
```

**Expected:** Shows deployments from faber-cloud (if any).

---

## Troubleshooting

### "helm-cloud plugin not found"

**Solution:**
1. Verify plugin installed: `ls plugins/helm-cloud`
2. Check plugin.json exists: `cat plugins/helm-cloud/.claude-plugin/plugin.json`
3. Restart Claude Code session

---

### "Configuration file not found"

**Solution:**
1. Copy example config:
   ```bash
   cp plugins/helm-cloud/config/monitoring.example.toml \
      .fractary/plugins/helm-cloud/config/monitoring.toml
   ```
2. Verify shared config:
   ```bash
   ls -la .fractary/shared/
   ```

---

### "Deployment registry empty"

**Solution:**
1. Deploy something with faber-cloud first:
   ```bash
   /fractary-faber-cloud:deploy --env=test
   ```
2. Registry will be populated automatically

---

### "AWS permission denied"

**Solution:**
1. Verify AWS profile in config:
   ```bash
   cat .fractary/shared/aws-credentials.json
   ```
2. Test AWS CLI access:
   ```bash
   aws cloudwatch describe-alarms --profile YOUR-PROFILE
   ```
3. Update IAM policies if needed (CloudWatch read permissions)

---

### "Delegation not working"

**Solution:**
1. Verify helm-cloud plugin is installed
2. Check ops-manage.md has delegation logic
3. Try new command directly: `/fractary-helm-cloud:health`

---

## Benefits of Migration

### For Users

✅ **Clearer commands** - Direct operation names (health, investigate)
✅ **Better organization** - Operations separate from infrastructure
✅ **Future-ready** - Prepares for centralized Helm dashboard
✅ **No disruption** - Backward compatibility maintained

### For Developers

✅ **Separation of concerns** - FABER creates, Helm monitors
✅ **Scalable architecture** - Pattern extends to multiple domains
✅ **Cleaner codebase** - Each plugin has focused responsibility
✅ **Easier testing** - Isolated operations functionality

---

## Next Steps After Migration

### Phase 3: Central Helm Dashboard

Once helm-cloud is stable, the next phase introduces:
- **helm/** central orchestrator plugin
- **Unified dashboard** across all domains (infrastructure, apps, content)
- **Cross-domain prioritization** of issues
- **Voice interface** support
- **Intelligent alerting** and escalation

### Additional Helm Domains

- **helm-app** - Application performance monitoring (APM, error tracking)
- **helm-content** - Content analytics and engagement
- **helm-design** - Design system monitoring

---

## Getting Help

### Documentation
- [README.md](./README.md) - Helm-cloud overview and commands
- [SKILLS.md](./SKILLS.md) - Detailed skill documentation
- Specifications: `specs/SPEC-00008-faber-helm-architecture.md`

### Support
- Check troubleshooting section above
- Review command documentation: `/fractary-helm-cloud:health --help`
- Verify configuration files exist and are valid

---

## Rollback Plan

If you encounter critical issues during migration:

### Disable Delegation
1. Comment out delegation logic in `faber-cloud/commands/ops-manage.md`
2. Restore direct invocation of faber-cloud ops-manager
3. Report issue for investigation

### Keep Using faber-cloud ops-*
- Old commands remain functional during transition period
- No forced upgrade until faber-cloud v2.0.0
- You have 6+ months to complete migration

---

## Summary

**What changed:**
- Operations moved from faber-cloud to helm-cloud plugin
- New command structure (health, investigate, remediate, audit)
- Shared configuration (.fractary/registry/, .fractary/shared/)

**What stayed the same:**
- Core functionality (monitoring, investigation, remediation, auditing)
- AWS integration and permissions model
- Production safety confirmations
- Skills and workflows

**Migration effort:**
- **Low** - Update commands in scripts/docs
- **Medium** - Copy monitoring config template
- **Time** - 30-60 minutes for most projects

---

**Questions or issues? Check the troubleshooting section or review the specifications.**
