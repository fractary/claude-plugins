---
org: fractary
system: claude-code
title: FABER-Cloud Command Reorganization and Audit Integration
description: Reorganization of faber-cloud commands for clarity, consistency with FABER phases, and integration of audit-first observability patterns from corthos
tags: [faber-cloud, commands, reorganization, audit, observability, corthos-patterns]
created: 2025-11-04
updated: 2025-11-04
codex_sync_include: []
codex_sync_exclude: []
visibility: internal
---

# FABER-Cloud Command Reorganization and Audit Integration

**Status**: Approved for Implementation
**Date**: 2025-11-04
**Author**: Architecture Discussion
**Related**: [faber-cloud-v2.1-phase1-commands.md](./faber-cloud-v2.1-phase1-commands.md), [corthos infrastructure patterns](../../corthos/core.corthuxa.ai/)

## Executive Summary

This specification defines a comprehensive reorganization of the `fractary-faber-cloud` plugin commands to improve naming clarity, align with FABER phase terminology, and integrate audit-first observability patterns learned from the corthos infrastructure implementation.

## Background

### Current State Issues

1. **Inconsistent Naming**: Commands don't align with FABER phase terminology
   - `design` should be `architect` (matches FABER Architect phase)
   - `configure` should be `engineer` (better describes IaC generation)

2. **Deploy Command Ambiguity**: `deploy-apply` doesn't convey the seriousness of execution
   - "apply" is Terraform jargon, not user-facing clarity
   - Should be `deploy-execute` (or `deploy-launch`/`deploy-release`)

3. **Teardown Naming Inconsistency**: `teardown` doesn't match deploy-* pattern
   - Should be `deploy-destroy` for parallel naming

4. **Generic Command Names**: `resources` too vague
   - Should be `list` (simpler, clearer)

5. **Slash Prefix in Front Matter**: All command `name` fields include `/` prefix
   - This is incorrect; the slash is added by the command system
   - Example: `name: /fractary-faber-cloud:design` should be `name: fractary-faber-cloud:design`

6. **Missing Observability**: No audit command for non-destructive infrastructure inspection
   - Cannot check drift, costs, security posture without making changes
   - Critical for production environments

### Lessons from Corthos

The corthos infrastructure implementation (`core.corthuxa.ai`) uses a **7-phase workflow** with audit-first approach:

```
1. INSPECT  → auditor checks current state
2. ANALYZE  → architect or debugger based on audit
3. PRESENT  → show plan to user
4. APPROVE  → user confirms
5. EXECUTE  → deployer implements
6. VERIFY   → auditor confirms success
7. REPORT   → final status
```

**Key Pattern**: Auditor skill provides **observability without modification**:
- Fast targeted checks (config-valid, iam-health, drift)
- Comprehensive full audits
- Pre-deployment readiness verification
- Post-deployment health confirmation
- Troubleshooting preparation

This pattern should be integrated into faber-cloud.

## Requirements

### 1. Command Renames

| Current | New | Rationale |
|---------|-----|-----------|
| `design` | `architect` | Aligns with FABER Architect phase, consistent terminology |
| `configure` | `engineer` | Better describes IaC code generation activity |
| `deploy-apply` | `deploy-execute` | More serious, clearer intent, matches EXECUTE phase |
| `teardown` | `deploy-destroy` | Parallel naming with deploy-execute, clearer destructive action |
| `resources` | `list` | Simpler, more intuitive |

### 2. Front Matter Corrections

Remove `/` prefix from all command `name` fields:

**Before**:
```yaml
name: /fractary-faber-cloud:design
```

**After**:
```yaml
name: fractary-faber-cloud:architect
```

### 3. Test vs Validate Evaluation

**Decision**: Keep `test` and `validate` as separate commands

**Rationale**:
- **validate**: Fast syntax checking (2-5 seconds)
  - Runs `terraform validate`
  - Checks syntax, references, provider config
  - Pre-coding phase verification

- **test**: Comprehensive analysis (30-60 seconds)
  - Security scans (Checkov, tfsec)
  - Cost estimation
  - Compliance checks
  - Best practices validation
  - Pre/post deployment testing

- **Different purposes**: Validation is about correctness, testing is about safety/cost/compliance
- **Terraform plan is NOT testing**: Plan shows what will change, not security/cost analysis

**Recommendation**: Keep both, clarify their distinct purposes in documentation

### 4. New Audit Command

Add `audit` command based on corthos auditor pattern.

#### Command Specification

```yaml
---
name: fractary-faber-cloud:audit
description: Audit infrastructure status, health, and compliance without changes
examples:
  - /fractary-faber-cloud:audit --env=test
  - /fractary-faber-cloud:audit --env=prod --check=drift
  - /fractary-faber-cloud:audit --env=prod --check=full
argument-hint: "--env=<environment> [--check=<type>]"
---
```

#### Audit Check Types

| Check Type | Duration | Purpose |
|------------|----------|---------|
| `config-valid` | ~2-3s | Terraform configuration syntax and structure |
| `iam-health` | ~3-5s | IAM users, roles, permissions current |
| `drift` | ~5-10s | Detect configuration drift (Terraform vs AWS) |
| `cost` | ~3-5s | Cost analysis, anomalies, projections |
| `security` | ~5-7s | Security posture, compliance checks |
| `full` | ~20-30s | Comprehensive audit (all checks) |

#### Default Behavior

```bash
# Default: config-valid check on test environment
/fractary-faber-cloud:audit

# Specific check
/fractary-faber-cloud:audit --env=prod --check=drift

# Full comprehensive audit
/fractary-faber-cloud:audit --env=prod --check=full
```

#### Output Format

```markdown
## Audit Report: infrastructure/{env}

**Check Type**: {check_type}
**Timestamp**: {ISO8601}
**Duration**: {seconds}s

### Status Summary
✅ {passing} passing
⚠️  {warnings} warnings
❌ {failures} failures

### Checks Performed

#### ✅ Terraform Configuration Valid
- Syntax: Valid
- Variables: All defined
- Backend: Configured

#### ⚠️ Configuration Drift Detected
- S3 bucket tags modified manually
- Lambda timeout increased outside Terraform
- Recommendation: Import changes or re-apply

#### ✅ IAM Health
- Deploy users: Healthy
- Service roles: All present
- Unused resources: None

### Metrics
- Total resources: 42
- Drift items: 2
- Estimated monthly cost: $15.23
- Last deployment: 2 days ago

### Recommendations
1. Address configuration drift
2. Review S3 bucket tags
3. Update Lambda timeout in Terraform
```

#### Integration Points

**Pre-deployment audit**:
```bash
/fractary-faber-cloud:audit --env=test --check=full
# Review output
/fractary-faber-cloud:deploy-execute --env=test
```

**Post-deployment verification**:
```bash
/fractary-faber-cloud:deploy-execute --env=test
# Automatic audit runs as final step
# Or manual:
/fractary-faber-cloud:audit --env=test --check=full
```

**Troubleshooting preparation**:
```bash
/fractary-faber-cloud:audit --env=prod --check=drift
# If drift detected:
/fractary-faber-cloud:debug
```

## Implementation Plan

### Phase 1: File Renames and Front Matter Fixes

**Commands to rename**:
1. `commands/design.md` → `commands/architect.md`
2. `commands/configure.md` → `commands/engineer.md`
3. `commands/deploy-apply.md` → `commands/deploy-execute.md`
4. `commands/teardown.md` → `commands/deploy-destroy.md`
5. `commands/resources.md` → `commands/list.md`

**Front matter updates** (all commands):
- Remove `/` prefix from `name` field
- Update `examples` to use new command names
- Update `description` to match new semantics

**Files to update**:
```
plugins/faber-cloud/commands/
├── architect.md (was design.md)
├── engineer.md (was configure.md)
├── deploy-execute.md (was deploy-apply.md)
├── deploy-destroy.md (was teardown.md)
├── list.md (was resources.md)
├── deploy-plan.md (update references)
├── validate.md (update references)
├── test.md (update references)
├── status.md (update references)
├── debug.md (update references)
├── manage.md (update references)
├── init.md (update references)
└── director.md (update references)
```

### Phase 2: Agent Updates

**Files to update**:
```
plugins/faber-cloud/agents/
├── cloud-director.md
│   └── Update operation routing for new command names
└── infra-manager.md
    └── Update operation handlers for new command names
```

**Operation name mappings**:
| Old Operation | New Operation |
|--------------|---------------|
| `design` | `architect` |
| `configure` | `engineer` |
| `deploy-apply` | `deploy-execute` |
| `teardown` | `deploy-destroy` |
| `show-resources` | `list-resources` |

### Phase 3: Skill Updates

**Files to update**:
```
plugins/faber-cloud/skills/
├── infra-designer/SKILL.md → infra-architect/SKILL.md
├── infra-configurator/SKILL.md → infra-engineer/SKILL.md
├── infra-deployer/SKILL.md (update references to deploy-execute)
└── infra-teardown/SKILL.md (update references to deploy-destroy)
```

**Note**: Skill renames should match operation renames for consistency

### Phase 4: New Audit Command and Skill

**New files to create**:

1. **Command**: `plugins/faber-cloud/commands/audit.md`
   - Front matter with examples
   - Usage documentation
   - Check type descriptions
   - Output format examples
   - Integration examples

2. **Skill**: `plugins/faber-cloud/skills/infra-auditor/SKILL.md`
   - Based on corthos `corthuxa-infra-auditor` pattern
   - Implement all 6 check types
   - Structured output generation
   - No modifications to infrastructure
   - Fast execution (most checks <10s)

3. **Workflow files**: `plugins/faber-cloud/skills/infra-auditor/workflow/`
   - `config-valid.md` - Terraform validation workflow
   - `iam-health.md` - IAM health check workflow
   - `drift.md` - Drift detection workflow
   - `cost.md` - Cost analysis workflow
   - `security.md` - Security posture workflow
   - `full.md` - Comprehensive audit workflow

4. **Scripts**: `plugins/faber-cloud/skills/infra-auditor/scripts/`
   - `audit-config.sh` - Terraform config validation
   - `audit-iam.sh` - IAM health checks
   - `audit-drift.sh` - Drift detection
   - `audit-cost.sh` - Cost analysis
   - `audit-security.sh` - Security checks
   - `audit-full.sh` - Orchestrate all checks

### Phase 5: Documentation Updates

**Files to update**:

1. **Plugin README**: `plugins/faber-cloud/README.md`
   - Update command list
   - Update examples
   - Add audit command documentation
   - Update workflow diagrams

2. **Plugin specification**: `plugins/faber-cloud/docs/specs/faber-cloud-plugin-spec.md`
   - Update command reference
   - Add audit integration
   - Update workflow descriptions

3. **User guides**: `plugins/faber-cloud/docs/*.md`
   - Update all command references
   - Add audit workflow examples
   - Update troubleshooting guides

4. **Configuration examples**: `plugins/faber-cloud/config/*.example.json`
   - Update operation names
   - Add audit configuration options

### Phase 6: Integration Updates

**Infra-manager agent workflow integration**:

Add audit checkpoints to deployment workflow:

```markdown
## Enhanced Deployment Workflow

1. **Pre-deployment Audit** (NEW)
   - Run `infra-auditor --check=config-valid`
   - Run `infra-auditor --check=security`
   - Block if critical issues found

2. **Design/Architect**
   - Existing `infra-architect` skill

3. **Engineer**
   - Existing `infra-engineer` skill
   - Automatic `terraform validate` after generation

4. **Validate**
   - Existing `infra-validator` skill

5. **Test**
   - Existing `infra-tester` skill (security scans, cost estimates)

6. **Plan**
   - Existing `infra-planner` skill (terraform plan)

7. **Execute**
   - Existing `infra-deployer` skill

8. **Post-deployment Audit** (NEW)
   - Run `infra-auditor --check=full`
   - Verify deployment health
   - Document final state
```

## Migration Strategy

### Backward Compatibility

**Breaking Changes**: Yes, command names are changing

**Migration Period**: Recommend 1-2 weeks with deprecation warnings

**Approach**:
1. Keep old command files with deprecation warnings
2. Forward to new commands
3. Log warnings when old commands used
4. Remove after migration period

**Example deprecation wrapper**:

```markdown
---
name: fractary-faber-cloud:design
description: "[DEPRECATED] Use /fractary-faber-cloud:architect instead"
deprecated: true
redirect: fractary-faber-cloud:architect
---

# [DEPRECATED] Design Command

⚠️ **This command has been renamed to `/fractary-faber-cloud:architect`**

Please update your workflows to use the new command name.

This command will be removed in version 3.0.

---

Forwarding to /fractary-faber-cloud:architect...
```

### User Communication

**Announcement template**:

```markdown
## FABER-Cloud v2.2: Command Reorganization

We've reorganized faber-cloud commands for clarity and consistency:

**Renamed Commands**:
- `/fractary-faber-cloud:design` → `/fractary-faber-cloud:architect`
- `/fractary-faber-cloud:configure` → `/fractary-faber-cloud:engineer`
- `/fractary-faber-cloud:deploy-apply` → `/fractary-faber-cloud:deploy-execute`
- `/fractary-faber-cloud:teardown` → `/fractary-faber-cloud:deploy-destroy`
- `/fractary-faber-cloud:resources` → `/fractary-faber-cloud:list`

**New Command**:
- `/fractary-faber-cloud:audit` - Infrastructure observability without changes

**Migration**: Old command names will work with deprecation warnings until v3.0
```

## Success Criteria

### Functional Requirements

- ✅ All renamed commands function identically to originals
- ✅ All front matter slash prefixes removed
- ✅ All agent operations updated to new names
- ✅ All skill references updated
- ✅ Audit command implements all 6 check types
- ✅ Audit command completes checks in specified time ranges
- ✅ Audit command produces structured output
- ✅ Audit command integrates with deployment workflow

### Non-Functional Requirements

- ✅ No regression in existing functionality
- ✅ Documentation fully updated
- ✅ Examples all tested and working
- ✅ Migration path clearly documented
- ✅ Performance maintained or improved

### Testing Requirements

1. **Command invocation tests**:
   - All new command names resolve correctly
   - All parameters parsed correctly
   - Help text displays correctly

2. **Agent routing tests**:
   - Operations route to correct skills
   - Parameters passed correctly
   - Error handling works

3. **Audit functionality tests**:
   - Each check type executes successfully
   - Output format matches specification
   - Execution time within bounds
   - No infrastructure modifications

4. **Integration tests**:
   - Pre-deployment audit blocks on critical issues
   - Post-deployment audit runs automatically
   - Audit integrates with debug workflow

## Reference Implementation

### Corthos Patterns

The corthos implementation provides reference patterns for:

1. **Auditor skill structure**: `core.corthuxa.ai/.claude/skills/corthuxa-infra-auditor/SKILL.md`
2. **Audit command**: `core.corthuxa.ai/.claude/commands/corthuxa-infra-manage.md`
3. **7-phase workflow**: INSPECT → ANALYZE → PRESENT → APPROVE → EXECUTE → VERIFY → REPORT
4. **Audit check types**: config-valid, iam-health, drift, cost, security, full
5. **Output formatting**: Structured reports with recommendations

### Adaptations for FABER-Cloud

**Differences from corthos**:
1. FABER-Cloud uses Terraform (corthos uses Terraform)
2. FABER-Cloud targets AWS (corthos targets AWS)
3. FABER-Cloud uses handler pattern (corthos is AWS-specific)

**Similarities**:
1. Audit-first approach for observability
2. Fast targeted checks vs comprehensive full audit
3. Pre/post deployment verification
4. Drift detection and remediation
5. IAM and security posture checks

## Risks and Mitigations

### Risk: User Confusion During Migration

**Mitigation**:
- Deprecation warnings on old commands
- Clear migration documentation
- Examples updated everywhere
- Announcement in release notes

### Risk: Broken Workflows

**Mitigation**:
- Old command names still work (with warnings)
- Migration period before removal
- Automated tests for all commands

### Risk: Audit Command Performance

**Mitigation**:
- Time limits specified for each check type
- Caching where appropriate
- Parallel execution of independent checks
- Option to run targeted checks vs full audit

### Risk: Incomplete Agent/Skill Updates

**Mitigation**:
- Comprehensive grep for old operation names
- Automated testing of all operations
- Review of all cross-references
- Documentation review checklist

## Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: File renames and front matter | 1 hour | None |
| Phase 2: Agent updates | 1 hour | Phase 1 |
| Phase 3: Skill updates | 2 hours | Phase 2 |
| Phase 4: Audit command/skill | 4 hours | Phase 3 |
| Phase 5: Documentation | 2 hours | Phase 4 |
| Phase 6: Integration | 2 hours | Phase 4 |
| Testing | 2 hours | All phases |
| **Total** | **14 hours** | |

## Future Enhancements

### Enhanced Audit Capabilities

1. **Continuous Auditing**: Background audit runner
2. **Audit History**: Track drift over time
3. **Compliance Frameworks**: CIS, PCI-DSS, HIPAA checks
4. **Custom Audit Rules**: User-defined checks
5. **Audit Alerts**: Notify on critical findings

### Workflow Orchestration

1. **Auto-remediation**: Fix drift automatically (with approval)
2. **Scheduled Audits**: Daily/weekly audit runs
3. **Audit-driven Deployment**: Block deployment on audit failures
4. **Audit Reports**: Generate compliance reports

### Multi-Cloud Support

1. **Azure Auditor**: Extend pattern to Azure
2. **GCP Auditor**: Extend pattern to GCP
3. **Cross-cloud Auditor**: Compare resources across providers

## Appendix A: Command Reference

### Final Command List

```bash
# Lifecycle Commands
/fractary-faber-cloud:init              # Initialize plugin configuration
/fractary-faber-cloud:architect         # Design infrastructure (was: design)
/fractary-faber-cloud:engineer          # Generate IaC code (was: configure)
/fractary-faber-cloud:validate          # Validate Terraform syntax
/fractary-faber-cloud:test              # Security scans and cost estimates
/fractary-faber-cloud:deploy-plan       # Preview deployment changes
/fractary-faber-cloud:deploy-execute    # Deploy infrastructure (was: deploy-apply)
/fractary-faber-cloud:deploy-destroy    # Destroy infrastructure (was: teardown)

# Observability Commands
/fractary-faber-cloud:audit             # Audit infrastructure [NEW]
/fractary-faber-cloud:list              # List deployed resources (was: resources)
/fractary-faber-cloud:status            # Show deployment status
/fractary-faber-cloud:debug             # Troubleshoot issues

# Management Commands
/fractary-faber-cloud:manage            # Manage infrastructure resources
/fractary-faber-cloud:director          # Workflow orchestration
```

## Appendix B: Operation Mappings

### Agent Operation Names

| Command | Agent Operation | Skill |
|---------|----------------|-------|
| `architect` | `architect` | `infra-architect` |
| `engineer` | `engineer` | `infra-engineer` |
| `validate` | `validate-config` | `infra-validator` |
| `test` | `test-changes` | `infra-tester` |
| `deploy-plan` | `deploy-plan` | `infra-planner` |
| `deploy-execute` | `deploy-execute` | `infra-deployer` |
| `deploy-destroy` | `deploy-destroy` | `infra-teardown` |
| `audit` | `audit` | `infra-auditor` |
| `list` | `list-resources` | `infra-lister` |
| `status` | `show-status` | `infra-status` |
| `debug` | `debug` | `infra-debugger` |

## Appendix C: Files Affected

### Commands (13 files)

```
plugins/faber-cloud/commands/
├── architect.md         # RENAME from design.md
├── engineer.md          # RENAME from configure.md
├── deploy-execute.md    # RENAME from deploy-apply.md
├── deploy-destroy.md    # RENAME from teardown.md
├── list.md              # RENAME from resources.md
├── audit.md             # NEW
├── deploy-plan.md       # UPDATE references
├── validate.md          # UPDATE references
├── test.md              # UPDATE references
├── status.md            # UPDATE references
├── debug.md             # UPDATE references
├── manage.md            # UPDATE references
├── init.md              # UPDATE references
└── director.md          # UPDATE references
```

### Agents (2 files)

```
plugins/faber-cloud/agents/
├── cloud-director.md    # UPDATE operation routing
└── infra-manager.md     # UPDATE operation handlers
```

### Skills (6 files + 1 new)

```
plugins/faber-cloud/skills/
├── infra-architect/     # RENAME from infra-designer/
├── infra-engineer/      # RENAME from infra-configurator/
├── infra-deployer/      # UPDATE references
├── infra-teardown/      # UPDATE references
├── infra-validator/     # UPDATE references
├── infra-tester/        # UPDATE references
└── infra-auditor/       # NEW
    ├── SKILL.md
    ├── workflow/
    │   ├── config-valid.md
    │   ├── iam-health.md
    │   ├── drift.md
    │   ├── cost.md
    │   ├── security.md
    │   └── full.md
    └── scripts/
        ├── audit-config.sh
        ├── audit-iam.sh
        ├── audit-drift.sh
        ├── audit-cost.sh
        ├── audit-security.sh
        └── audit-full.sh
```

### Documentation (5+ files)

```
plugins/faber-cloud/
├── README.md                                    # UPDATE
├── docs/
│   ├── specs/
│   │   └── faber-cloud-plugin-spec.md          # UPDATE
│   ├── guides/
│   │   ├── getting-started.md                  # UPDATE
│   │   ├── deployment-workflow.md              # UPDATE
│   │   └── troubleshooting.md                  # UPDATE
│   └── examples/
│       └── *.md                                 # UPDATE all examples
└── config/
    └── *.example.json                           # UPDATE
```

---

**End of Specification**
