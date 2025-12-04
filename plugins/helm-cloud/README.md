# Fractary Helm-Cloud Plugin

**Version:** 1.1.0 (All Phases Complete)
**Domain:** Infrastructure Operations
**Purpose:** Runtime operations and monitoring for cloud infrastructure

---

## Quick Start

Check infrastructure health:
```bash
/fractary-helm-cloud:health --env=prod
```

View unified dashboard (includes infrastructure + other domains):
```bash
/fractary-helm:dashboard
```

Investigate issues:
```bash
/fractary-helm-cloud:investigate "Lambda errors" --env=prod
```

---

## What is helm-cloud?

**helm-cloud** is the operations monitoring plugin for cloud infrastructure deployed by faber-cloud. It implements the **Helm workflow** (Monitor → Analyze → Alert → Remediate) for continuous operations.

### Relationship with faber-cloud

Starting with **faber-cloud v2.0.0**, operations monitoring has been completely separated:

- **faber-cloud v2.0.0** = Infrastructure lifecycle (FABER workflow)
  - Design → Build → Test → Deploy

- **helm-cloud v1.1.0** = Operations monitoring (Helm workflow)
  - Monitor → Analyze → Alert → Remediate

```
faber-cloud creates → helm-cloud monitors → helm escalates issues → faber-cloud fixes
```

---

## Recent Updates

**Phase 4 (Clean Separation) - Works with faber-cloud v2.0.0:**
- ✅ Now the **only** operations monitoring for infrastructure
- ✅ All operations commands moved from faber-cloud to helm-cloud
- ✅ Clean architectural boundaries established

**Phase 3 (Central Helm Integration) - v1.1.0:**
- ✅ Registered with central Helm orchestrator
- ✅ Accessible via unified dashboard (`/fractary-helm:dashboard`)
- ✅ Cross-domain issue prioritization
- ✅ FABER escalation integration

**Phase 2 (Initial Extraction) - v1.0.0:**
- ✅ Extracted from faber-cloud plugin
- ✅ Shared configuration structure
- ✅ Independent operations plugin

---

## Migration from faber-cloud v1.x

**If you used faber-cloud v1.x operations commands**, they have moved here:

| Old Command (faber-cloud v1.x) | New Command (helm-cloud) |
|--------------------------------|--------------------------|
| `/fractary-faber-cloud:ops-manage check-health` | `/fractary-helm-cloud:health` |
| `/fractary-faber-cloud:ops-manage query-logs` | `/fractary-helm-cloud:investigate` |
| `/fractary-faber-cloud:ops-manage investigate` | `/fractary-helm-cloud:investigate` |
| `/fractary-faber-cloud:ops-manage remediate` | `/fractary-helm-cloud:remediate` |
| `/fractary-faber-cloud:ops-manage audit` | `/fractary-helm-cloud:audit` |

**Note:** As of faber-cloud v2.0.0, all operations commands have been removed. See the [migration guide](../faber-cloud/docs/MIGRATION-V2.md) for details.

---

## Overview

Helm-cloud handles the **operations lifecycle** for cloud infrastructure deployed by faber-cloud. It implements the **Monitor → Analyze → Alert → Remediate** workflow for continuous monitoring and incident response.

**Integration with Central Helm:** As of Phase 3, helm-cloud is now part of the unified Helm orchestration system, enabling cross-domain monitoring alongside helm-app, helm-content, and other domain monitors.

### What is Helm?

**Helm** is the universal operations workflow system in the Fractary ecosystem:
- **FABER** creates things (Frame → Architect → Build → Evaluate → Release)
- **Helm** monitors things (Monitor → Analyze → Alert → Remediate)

Together, they form a complete lifecycle: FABER creates → Helm monitors → Helm detects issues → Helm escalates back to FABER for fixes.

---

## Core Capabilities

### 1. Health Monitoring (`ops-monitor` skill)
- Continuous health checks of deployed resources
- CloudWatch metrics collection and analysis
- SLO threshold monitoring (error rate, latency, availability)
- Resource status tracking (Lambda, RDS, ECS, S3, etc.)

### 2. Incident Investigation (`ops-investigator` skill)
- CloudWatch Logs queries and analysis
- Error pattern detection and correlation
- Timeline reconstruction
- Root cause identification
- Investigation report generation

### 3. Remediation (`ops-responder` skill)
- Automated remediations (restart Lambda, clear cache)
- Manual remediations (scale resources, modify config)
- Production safety confirmations
- Remediation verification
- Action documentation

### 4. Auditing (`ops-auditor` skill)
- Cost analysis and optimization (AWS Cost Explorer)
- Security posture assessment (AWS Security Hub)
- Compliance checking (AWS Config Rules)
- Audit report generation

---

## Commands

### `/fractary-helm-cloud:health`
Check health of deployed infrastructure resources.

```bash
# Check test environment
/fractary-helm-cloud:health --env=test

# Check production
/fractary-helm-cloud:health --env=prod
```

**What it does:**
1. Loads deployment registry
2. Queries resource status and metrics
3. Compares against SLO targets
4. Reports health status

---

### `/fractary-helm-cloud:investigate`
Investigate incidents and analyze logs.

```bash
# Investigate Lambda errors
/fractary-helm-cloud:investigate "Lambda errors in API function" --env=prod

# Investigate specific issue
/fractary-helm-cloud:investigate --issue=infra-001 --env=prod

# Investigate performance problem
/fractary-helm-cloud:investigate "high latency on RDS" --env=test
```

**What it does:**
1. Queries CloudWatch Logs
2. Analyzes error patterns
3. Correlates with metrics
4. Identifies root cause
5. Generates investigation report

---

### `/fractary-helm-cloud:remediate`
Apply remediations to resolve issues.

```bash
# Restart Lambda function
/fractary-helm-cloud:remediate --action=restart_lambda --env=test

# Remediate specific issue
/fractary-helm-cloud:remediate --issue=infra-001 --env=prod

# Natural language remediation
/fractary-helm-cloud:remediate "increase RDS max connections to 200" --env=prod
```

**Safety levels:**
- **Auto-remediate:** restart_lambda, clear_cache (no confirmation)
- **Require confirmation:** scale_resources, increase_capacity
- **Never auto:** delete_resources, modify_security_groups

**What it does:**
1. Diagnoses issue
2. Proposes remediation
3. Shows impact assessment
4. Requests confirmation (if needed)
5. Applies remediation
6. Verifies success
7. Documents action

---

### `/fractary-helm-cloud:audit`
Perform cost, security, or compliance audits.

```bash
# Cost audit
/fractary-helm-cloud:audit --type=cost --env=prod

# Security audit
/fractary-helm-cloud:audit --type=security --env=prod

# Compliance audit
/fractary-helm-cloud:audit --type=compliance --env=test
```

**What it does:**
- **Cost:** Analyzes spend, finds anomalies, recommends optimizations
- **Security:** Checks Security Hub findings, validates policies, reports score
- **Compliance:** Evaluates Config Rules, checks standards compliance, provides guidance

---

## Integration with faber-cloud

Helm-cloud monitors infrastructure deployed by faber-cloud through a shared deployment registry:

### Deployment Flow

```
1. faber-cloud deploys infrastructure
   ↓
2. faber-cloud registers deployment in `.fractary/registry/deployments.json`
   ↓
3. helm-cloud picks up deployment from registry
   ↓
4. helm-cloud begins continuous monitoring
   ↓
5. helm-cloud detects issues
   ↓
6. helm-cloud remediates or escalates to FABER
```

### Shared Configuration

Both plugins use shared configuration:

**Deployment Registry:**
- Location: `.fractary/registry/deployments.json`
- Purpose: Track all deployments across environments
- Used by: faber-cloud (write), helm-cloud (read)

**AWS Credentials:**
- Location: `.fractary/shared/aws-credentials.json`
- Purpose: Shared AWS account and profile configuration
- Used by: Both plugins

**Environments:**
- Location: `.fractary/shared/environments.json`
- Purpose: Environment definitions (test, prod)
- Used by: Both plugins

---

## Configuration

### Monitoring Configuration

**Location:** `.fractary/plugins/helm-cloud/monitoring.toml`

**Template:** `plugins/helm-cloud/config/monitoring.example.toml`

**Key settings:**

```toml
[monitoring]
health_check_interval = "5m"
enabled_checks = ["resource_status", "cloudwatch_metrics", "cloudwatch_alarms"]

[slos.lambda]
error_rate_percent = 0.1
p95_latency_ms = 200
availability_percent = 99.9

[remediation]
auto_remediate = ["restart_lambda", "clear_cache"]
require_confirmation = ["scale_resources"]
never_auto = ["delete_resources", "modify_security_groups"]
```

### Setup

1. **Copy monitoring config:**
   ```bash
   mkdir -p .fractary/plugins/helm-cloud
   cp plugins/helm-cloud/config/monitoring.example.toml \
      .fractary/plugins/helm-cloud/monitoring.toml
   ```

2. **Configure AWS credentials** (if not already done):
   ```bash
   cp .fractary/shared/aws-credentials.example.json \
      .fractary/shared/aws-credentials.json
   # Edit with your AWS account and profiles
   ```

3. **Verify deployment registry exists:**
   ```bash
   cat .fractary/registry/deployments.json
   ```

---

## Skills Reference

### ops-monitor
**Purpose:** Health checks and metrics collection
**Operations:** health-check, query-metrics, analyze-performance
**Tools:** AWS CLI, CloudWatch APIs

### ops-investigator
**Purpose:** Log analysis and incident investigation
**Operations:** query-logs, investigate, correlate-events
**Tools:** CloudWatch Logs, pattern matching

### ops-responder
**Purpose:** Apply remediations
**Operations:** remediate, restart, scale, rollback
**Tools:** AWS CLI, resource-specific APIs

### ops-auditor
**Purpose:** Cost, security, compliance audits
**Operations:** audit (cost/security/compliance)
**Tools:** Cost Explorer, Security Hub, Config Rules

---

## Backward Compatibility

### Migration from faber-cloud ops-*

Operations functionality has been extracted from faber-cloud to helm-cloud.

**Old commands (still work via delegation):**
```bash
/fractary-faber-cloud:ops-manage check-health --env=test
```

**New commands (recommended):**
```bash
/fractary-helm-cloud:health --env=test
```

**Timeline:**
- **Now:** Both old and new commands work
- **faber-cloud v2.0.0:** Old commands removed
- **Support period:** 6 months

See [MIGRATION.md](./MIGRATION.md) for detailed migration guide.

---

## Future Enhancements

### Phase 3: Central Helm Orchestrator
- Unified dashboard across all domains
- Cross-domain issue prioritization
- Voice interface ("Hey Helm, what's production status?")
- Intelligent alerting and escalation

### Additional Domains
- **helm-app:** Application performance monitoring
- **helm-content:** Content analytics and engagement
- **helm-design:** Design system monitoring

---

## Support

### Documentation
- [MIGRATION.md](./MIGRATION.md) - Migration from faber-cloud ops-*
- [SKILLS.md](./SKILLS.md) - Detailed skill documentation
- Commands: See `/fractary-helm-cloud:health --help` etc.

### Troubleshooting

**Health checks not finding resources:**
- Verify deployment registry exists: `.fractary/registry/deployments.json`
- Check AWS credentials configured: `.fractary/shared/aws-credentials.json`
- Ensure environment matches: `--env=test` or `--env=prod`

**Permission errors:**
- Verify AWS profile has CloudWatch read permissions
- Check IAM policies for resource access
- Use `aws configure list-profiles` to verify profiles

**Configuration not loading:**
- Check monitoring config exists: `.fractary/plugins/helm-cloud/monitoring.toml`
- Verify TOML syntax is valid
- Check file permissions

---

## Architecture

Helm-cloud follows the **3-layer architecture pattern:**

```
Layer 1: Commands (health, investigate, remediate, audit)
   ↓ Invoke agents via natural language
Layer 2: Agent (ops-manager)
   ↓ Invoke skills via SlashCommand
Layer 3: Skills (ops-monitor, ops-investigator, ops-responder, ops-auditor)
   ↓ Execute scripts via Bash
Layer 4: Scripts (AWS CLI, CloudWatch queries, etc.)
```

**Design principles:**
- Commands never do work (entry points only)
- Agent orchestrates but never executes
- Skills execute via scripts
- Scripts are deterministic and idempotent

---

## Version History

### v1.0.0 (2025-11-03)
- Initial release
- Extracted from faber-cloud plugin
- Core monitoring capabilities (health, investigate, remediate, audit)
- Shared configuration structure
- Backward compatibility with faber-cloud ops-*

---

## License

Part of the Fractary plugin ecosystem.
