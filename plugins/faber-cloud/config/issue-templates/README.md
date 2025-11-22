# Infrastructure Issue Templates

This directory contains GitHub issue templates for the faber-cloud plugin workflows.

## Templates

### infrastructure-audit.yml
Maps to the `infrastructure-audit` workflow for non-destructive infrastructure audits.

**Labels**: `type:audit`, `workflow:infrastructure-audit`, `infrastructure`

**Workflow**: Frame → Evaluate (audits) → Release (report)

**Autonomy**: Autonomous (safe, read-only operations)

**Fields**:
- **Target Environment**: Which environment to audit (dev/staging/prod/all)
- **Audit Types**: Multi-select for specific audit types to run
  - Configuration validity (syntax, references)
  - Drift detection (code vs actual infrastructure)
  - Security audit (checkov, tfsec)
  - Cost analysis (current and projected costs)
  - IAM health check (permissions, policies)
  - Compliance check (organizational policies)
- **Audit Scope**: What infrastructure components to include
- **Security Severity Threshold**: Minimum severity level to report (low/medium/high/critical)
- **Compliance Policies**: Which organizational policies to check
- **Expected Deliverables**: What the audit should produce
- **Additional Context**: Special focus areas or concerns

**Use Cases**:
- Regular security and compliance audits
- Cost optimization analysis
- Drift detection (code vs deployed state)
- IAM permission reviews
- Pre-deployment validation
- Post-incident infrastructure review

---

### infrastructure-deploy.yml
Maps to the `infrastructure-deploy` workflow for standard infrastructure deployments.

**Labels**: `type:infrastructure`, `workflow:infrastructure-deploy`, `terraform`

**Workflow**: Frame → Architect (design) → Build (Terraform) → Evaluate (test/scan) → Release (deploy)

**Autonomy**: Guarded (pauses before deployment for approval)

**Fields**:
- **Change Type**: Type of infrastructure change (new/update/migration/refactor)
- **Target Environment**: Which environment to deploy to (dev/staging/production)
- **Cloud Platform**: AWS/GCP/Azure/Multi-cloud
- **Infrastructure Description**: What infrastructure to create/modify
- **Infrastructure Resources**: Specific resource types and configurations
- **Architecture Overview**: High-level design and approach
- **Expected Cost Impact**: Monthly cost estimate and budget approval
- **Security Requirements**: Security checklist (encryption, IAM, network security)
- **Compliance & Standards**: Organizational policy validation
  - Naming conventions
  - Resource tagging (owner, cost-center, environment)
  - Backup and retention policies
  - Monitoring and alerting
  - Documentation
- **Testing Plan**: How infrastructure will be validated
- **Rollback Plan**: How to revert changes if needed
- **Dependencies**: What this infrastructure depends on
- **Deployment Window**: Preferred timing and constraints

**Use Cases**:
- New infrastructure provisioning
- Infrastructure updates and modifications
- Environment migrations
- Infrastructure refactoring
- Capacity planning and scaling

---

### infrastructure-teardown.yml
Maps to the `infrastructure-teardown` workflow for safe infrastructure destruction.

**Labels**: `type:teardown`, `workflow:infrastructure-teardown`, `destructive`, `requires-approval`

**Workflow**: Frame → Architect (analyze) → Build (plan) → Evaluate (backup) → Release (destroy)

**Autonomy**: Assist (requires approval at each major step for safety)

**⚠️ CRITICAL**: This is a **destructive workflow** - resources will be permanently deleted!

**Fields**:
- **Target Environment**: Which environment contains resources to destroy
- **Urgency**: Routine/Urgent/Emergency
- **Resources to Destroy**: Detailed list of all resources (IDs, names, types)
- **Teardown Justification**: Business reason for destruction
- **Data Inventory**: Complete inventory of persistent data
- **Data Handling Plan**: How data will be preserved or disposed
  - Backup to long-term storage
  - Export and archive
  - Migrate to new infrastructure
  - Approve deletion (retention expired)
  - Create snapshots before destruction
- **Backup Strategy**: Detailed backup plan with validation approach
- **Dependency Analysis**: What depends on these resources
- **Expected Cost Savings**: Monthly and annual savings estimate
- **Safety Checklist**: Pre-teardown verification (required)
  - Environment verification (NOT production or have approval)
  - No active users/traffic
  - Data backed up or approved for deletion
  - Dependencies checked
  - Rollback plan documented
  - Stakeholders notified
  - Maintenance window scheduled
- **Rollback Plan**: Feasibility and approach for reversing teardown
- **Required Approvals**: Approval chain (technical, product, security, finance, compliance)
- **Additional Context**: Historical context and special considerations

**Use Cases**:
- Decommissioning unused infrastructure
- Cleaning up test/development environments
- Infrastructure replacement (teardown + deploy)
- Cost optimization (removing underutilized resources)
- Security incident response (destroy compromised resources)

**Production Protection**:
- Production teardowns require additional approvals
- Workflow runs in dry-run mode for production by default
- Extra environment verification hooks
- Mandatory backup validation

---

## Installation

These templates are automatically installed when you run `/fractary-faber-cloud:init` in a project.

**Files created:**
```
.github/ISSUE_TEMPLATE/
├── infrastructure-audit.yml
├── infrastructure-deploy.yml
└── infrastructure-teardown.yml
```

**Files modified:**
```
.fractary/plugins/faber/config.json (workflow references added)
.fractary/plugins/faber/workflows/*.json (workflow definitions copied)
```

## Usage

After running `/fractary-faber-cloud:init`, users can:

1. **Create an issue** using GitHub's issue template selector
   - Go to: GitHub → Issues → New Issue
   - Select the appropriate template:
     - "Infrastructure Audit" for audits
     - "Infrastructure Deployment" for deployments
     - "Infrastructure Teardown" for destruction

2. **Fill out the template** with required information
   - Templates include helpful descriptions and examples
   - Required fields are marked

3. **Issue is created** with appropriate labels
   - `workflow:infrastructure-audit` → audit workflow
   - `workflow:infrastructure-deploy` → deployment workflow
   - `workflow:infrastructure-teardown` → teardown workflow

4. **Run FABER workflow** on the issue
   ```bash
   # Auto-detects workflow from issue labels
   /fractary-faber:run <issue-number>

   # Or explicitly specify workflow
   /fractary-faber:run <issue-number> --workflow infrastructure-audit
   /fractary-faber:run <issue-number> --workflow infrastructure-deploy
   /fractary-faber:run <issue-number> --workflow infrastructure-teardown
   ```

## Workflow Selection

FABER automatically selects the workflow based on issue labels:

| Issue Label | FABER Workflow | Autonomy Level |
|-------------|----------------|----------------|
| `workflow:infrastructure-audit` | infrastructure-audit | Autonomous |
| `workflow:infrastructure-deploy` | infrastructure-deploy | Guarded |
| `workflow:infrastructure-teardown` | infrastructure-teardown | Assist |

## Customization

To customize templates for your organization:

1. **Edit templates** in `.github/ISSUE_TEMPLATE/`:
   ```bash
   # Add organization-specific fields
   vim .github/ISSUE_TEMPLATE/infrastructure-deploy.yml
   ```

2. **Update labels** to match your workflow:
   ```yaml
   labels: ["type:infrastructure", "workflow:infrastructure-deploy", "team:platform"]
   ```

3. **Add custom fields** for your requirements:
   ```yaml
   - type: dropdown
     id: cost-center
     attributes:
       label: Cost Center
       options: ["Engineering", "Product", "Research"]
   ```

4. **Modify checklists** to match your policies:
   ```yaml
   - type: checkboxes
     id: compliance
     attributes:
       options:
         - label: Your custom compliance requirement
   ```

## Best Practices

1. **Use audit workflow regularly** - Run audits on a schedule (weekly/monthly)
2. **Review cost estimates** - Always fill out cost impact fields accurately
3. **Document thoroughly** - Better issue descriptions lead to better infrastructure
4. **Follow safety checklists** - Don't skip required safety verification items
5. **Get approvals early** - For teardown/production, start approval process early
6. **Test in lower environments** - Deploy to dev/staging before production

## See Also

- [Workflow Definitions](../workflows/README.md) - Detailed workflow documentation
- [Plugin Configuration](../../README.md) - faber-cloud plugin overview
- [FABER Documentation](../../../../faber/docs/README.md) - Core FABER framework
