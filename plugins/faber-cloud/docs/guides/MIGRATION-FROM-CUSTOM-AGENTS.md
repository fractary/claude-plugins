# Migration from Custom Agents Guide

This guide helps you migrate from custom infrastructure management scripts and agents to faber-cloud's standardized lifecycle management.

## Table of Contents

- [Overview](#overview)
- [Before You Start](#before-you-start)
- [Migration Strategy](#migration-strategy)
- [Script Type Mappings](#script-type-mappings)
- [Step-by-Step Migration](#step-by-step-migration)
- [Hook Integration Examples](#hook-integration-examples)
- [Testing Your Migration](#testing-your-migration)
- [Rollback Plan](#rollback-plan)
- [Common Patterns](#common-patterns)
- [FAQ](#faq)

## Overview

### Why Migrate?

Custom infrastructure scripts often:
- Lack standardization across projects
- Have inconsistent error handling
- Missing validation and safety checks
- Difficult to maintain and evolve
- No built-in approval workflows

faber-cloud provides:
- ✅ Standardized lifecycle management
- ✅ Enhanced environment validation
- ✅ Production safety with approvals
- ✅ Lifecycle hooks at every stage
- ✅ Built-in auditing and compliance
- ✅ Comprehensive error handling

### What Gets Migrated?

**Custom scripts typically fall into categories:**

1. **Deployment scripts** → faber-cloud infra-deployer + hooks
2. **Validation scripts** → faber-cloud infra-validator + post-plan hooks
3. **Audit scripts** → faber-cloud infra-auditor + post-deploy hooks
4. **Backup scripts** → pre-destroy hooks (critical)
5. **Configuration scripts** → Replaced by faber-cloud.json
6. **Monitoring scripts** → Keep standalone (not replaced)

## Before You Start

### Prerequisites

1. **Inventory your scripts**
   ```bash
   # Find all infrastructure-related scripts
   find . -type f \( -name "*.sh" -o -name "*.py" \) | grep -E "(deploy|infra|terraform|aws)"
   ```

2. **Understand current workflow**
   - Document when each script runs
   - Identify dependencies between scripts
   - Note manual steps required
   - List environment-specific behaviors

3. **Version control everything**
   ```bash
   # Commit all scripts before migration
   git add scripts/
   git commit -m "chore: Backup all custom scripts before faber-cloud migration"
   ```

4. **Run discovery**
   ```bash
   /fractary-faber-cloud:adopt --dry-run
   # Review generated MIGRATION.md
   ```

### Risk Assessment

**Low Risk:**
- Scripts with clear, single purposes
- Well-documented scripts
- Scripts already in version control
- Non-production-critical operations

**High Risk:**
- Undocumented scripts
- Scripts not in version control
- Production-only scripts
- Scripts with complex dependencies

## Migration Strategy

### Three-Phase Approach

**Phase 1: Discovery & Planning** (1-2 hours)
1. Run `/fractary-faber-cloud:adopt --dry-run`
2. Review MIGRATION.md report
3. Identify script categories
4. Plan hook integrations
5. Create rollback plan

**Phase 2: Test Environment Migration** (2-4 hours)
1. Install faber-cloud configuration
2. Migrate test environment scripts
3. Test all workflows
4. Validate deployments
5. Document lessons learned

**Phase 3: Production Migration** (1-2 hours)
1. Apply learnings from test
2. Migrate production configurations
3. Update team documentation
4. Archive old scripts
5. Train team on new workflow

### Decision Tree

```
For each custom script:
├─ Is it deployment-related?
│  ├─ YES → Use infra-deployer, preserve custom logic as hooks
│  └─ NO → Continue
├─ Is it validation-related?
│  ├─ YES → Integrate as post-plan hook
│  └─ NO → Continue
├─ Is it audit-related?
│  ├─ YES → Use infra-auditor, add custom checks as hooks
│  └─ NO → Continue
├─ Is it backup/teardown-related?
│  ├─ YES → Integrate as pre-destroy hook (critical: true)
│  └─ NO → Continue
├─ Is it configuration-related?
│  ├─ YES → Replace with faber-cloud.json
│  └─ NO → Continue
└─ Is it monitoring-related?
   ├─ YES → Keep standalone, not replaced by faber-cloud
   └─ NO → Evaluate case-by-case
```

## Script Type Mappings

### 1. Deployment Scripts

**Before (Custom):**
```bash
#!/bin/bash
# deploy.sh - Custom deployment script

set -euo pipefail

ENVIRONMENT=$1
AWS_PROFILE="myapp-${ENVIRONMENT}-deploy"

echo "Deploying to $ENVIRONMENT..."

# Custom pre-deployment checks
./scripts/validate-environment.sh "$ENVIRONMENT"

# Terraform deployment
cd terraform/
terraform init
terraform workspace select "$ENVIRONMENT"
terraform apply -var-file="${ENVIRONMENT}.tfvars" -auto-approve

# Custom post-deployment verification
./scripts/smoke-test.sh "$ENVIRONMENT"

echo "Deployment complete!"
```

**After (faber-cloud + hooks):**

**faber-cloud.json:**
```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "validate-environment",
        "command": "bash ./scripts/validate-environment.sh {{environment}}",
        "critical": true,
        "timeout": 300
      }
    ],
    "post_deploy": [
      {
        "name": "smoke-test",
        "command": "bash ./scripts/smoke-test.sh {{environment}}",
        "critical": false,
        "timeout": 600
      }
    ]
  }
}
```

**Deployment:**
```bash
# New simplified workflow
/fractary-faber-cloud:deploy-execute --env=test
```

**Benefits:**
- ✅ Built-in environment validation
- ✅ Approval workflow for production
- ✅ State management handled
- ✅ Error handling and rollback
- ✅ Custom logic preserved in hooks

### 2. Validation Scripts

**Before (Custom):**
```bash
#!/bin/bash
# validate-terraform.sh

set -euo pipefail

ENVIRONMENT=$1

# Terraform validation
cd terraform/
terraform fmt -check
terraform validate

# Custom business logic validation
if [ "$ENVIRONMENT" = "prod" ]; then
  # Ensure certain resources are protected
  terraform plan -var-file="prod.tfvars" | grep -q "protected = true" || {
    echo "ERROR: Production resources must be protected!"
    exit 1
  }
fi

echo "Validation passed!"
```

**After (faber-cloud + hook):**

**scripts/custom-validation.sh:**
```bash
#!/bin/bash
# Preserve custom business logic validation
set -euo pipefail

ENVIRONMENT=$1

if [ "$ENVIRONMENT" = "prod" ]; then
  # Custom production validation
  terraform plan -var-file="prod.tfvars" | grep -q "protected = true" || {
    echo "ERROR: Production resources must be protected!"
    exit 1
  }
fi

echo "Custom validation passed!"
```

**faber-cloud.json:**
```json
{
  "hooks": {
    "post_plan": [
      {
        "name": "custom-validation",
        "command": "bash ./scripts/custom-validation.sh {{environment}}",
        "critical": true,
        "timeout": 180,
        "environments": ["prod"]
      }
    ]
  }
}
```

**Usage:**
```bash
# Validation now automatic
/fractary-faber-cloud:deploy-plan --env=prod
# → Runs terraform validate
# → Runs terraform plan
# → Executes custom-validation hook
```

### 3. Audit Scripts

**Before (Custom):**
```bash
#!/bin/bash
# audit-infrastructure.sh

set -euo pipefail

ENVIRONMENT=$1

echo "Auditing $ENVIRONMENT infrastructure..."

# Check for drift
terraform plan -detailed-exitcode -var-file="${ENVIRONMENT}.tfvars" || {
  echo "WARNING: Configuration drift detected!"
}

# Check IAM permissions
aws iam list-users --profile "myapp-${ENVIRONMENT}" | \
  jq '.Users[] | select(.CreateDate | fromdateiso8601 < (now - 90*86400))'

# Custom security checks
./scripts/check-s3-encryption.sh "$ENVIRONMENT"
./scripts/check-unused-security-groups.sh "$ENVIRONMENT"

echo "Audit complete!"
```

**After (faber-cloud + hooks):**

**scripts/security-checks.sh:**
```bash
#!/bin/bash
# Preserve custom security checks
set -euo pipefail

ENVIRONMENT=$1

echo "Running custom security checks..."

./scripts/check-s3-encryption.sh "$ENVIRONMENT"
./scripts/check-unused-security-groups.sh "$ENVIRONMENT"

echo "Security checks passed!"
```

**faber-cloud.json:**
```json
{
  "hooks": {
    "post_deploy": [
      {
        "name": "security-audit",
        "command": "bash ./scripts/security-checks.sh {{environment}}",
        "critical": false,
        "timeout": 300
      }
    ]
  }
}
```

**Usage:**
```bash
# Built-in drift detection
/fractary-faber-cloud:audit --env=prod --check=drift

# Comprehensive audit with custom security checks
/fractary-faber-cloud:deploy-execute --env=prod
# → post_deploy hooks run automatically
```

### 4. Backup/Teardown Scripts

**Before (Custom):**
```bash
#!/bin/bash
# backup-before-destroy.sh

set -euo pipefail

ENVIRONMENT=$1

if [ "$ENVIRONMENT" = "prod" ]; then
  echo "Backing up production state..."

  # Backup Terraform state
  aws s3 cp s3://myapp-tfstate/prod/terraform.tfstate \
    ./backups/terraform.tfstate.$(date +%Y%m%d-%H%M%S)

  # Backup critical data
  ./scripts/backup-database.sh
  ./scripts/backup-s3-data.sh

  echo "Backups complete!"
fi
```

**After (faber-cloud + hook):**

**faber-cloud.json:**
```json
{
  "hooks": {
    "pre_destroy": [
      {
        "name": "backup-production",
        "command": "bash ./scripts/backup-before-destroy.sh {{environment}}",
        "critical": true,
        "timeout": 1800,
        "environments": ["prod"]
      }
    ]
  }
}
```

**Usage:**
```bash
# Backup runs automatically before destroy
/fractary-faber-cloud:deploy-destroy --env=prod
# → Confirms with user
# → Runs pre_destroy hooks (backup)
# → Only destroys if backup succeeds
```

**Critical:** Backup hooks should always be `"critical": true` so failures prevent destruction.

### 5. Configuration Scripts

**Before (Custom):**
```bash
#!/bin/bash
# configure-environment.sh

cat > terraform/backend.tf <<EOF
terraform {
  backend "s3" {
    bucket = "myapp-tfstate"
    key    = "${ENVIRONMENT}/terraform.tfstate"
    region = "us-west-2"
    profile = "myapp-${ENVIRONMENT}"
  }
}
EOF
```

**After (faber-cloud.json):**

```json
{
  "environments": [
    {
      "name": "test",
      "aws_profile": "myapp-test",
      "terraform_dir": "./terraform",
      "terraform_workspace": "test"
    },
    {
      "name": "prod",
      "aws_profile": "myapp-prod",
      "terraform_dir": "./terraform",
      "terraform_workspace": "prod",
      "protected": true
    }
  ],
  "terraform": {
    "backend_type": "s3",
    "version": "1.5.0"
  }
}
```

**Benefits:**
- ✅ Configuration in version control
- ✅ No code generation needed
- ✅ Declarative vs imperative
- ✅ Easier to review and maintain

## Step-by-Step Migration

### Step 1: Run Adoption Discovery

```bash
# Generate comprehensive migration analysis
/fractary-faber-cloud:adopt --dry-run

# Review generated reports
cat .fractary/adoption/MIGRATION.md
cat .fractary/adoption/faber-cloud.json
```

**Review:**
- Complexity assessment
- Risk identification
- Timeline estimation
- Script capability mapping

### Step 2: Categorize Your Scripts

Create a mapping spreadsheet:

| Script | Purpose | faber-cloud Feature | Integration Method | Keep/Replace |
|--------|---------|-------------------|-------------------|--------------|
| deploy.sh | Deploy infra | infra-deployer | Core workflow | Replace |
| validate.sh | Validate config | infra-validator | Core workflow | Replace |
| custom-check.sh | Business validation | N/A | post_plan hook | Keep |
| backup.sh | Backup state | N/A | pre_destroy hook | Keep |
| smoke-test.sh | Post-deploy test | N/A | post_deploy hook | Keep |
| configure.sh | Setup backend | faber-cloud.json | Configuration | Replace |

### Step 3: Install faber-cloud Configuration

```bash
# Install generated configuration
/fractary-faber-cloud:adopt

# Review and approve installation
# → Select "yes" when prompted
```

### Step 4: Migrate Scripts to Hooks

**For each script marked "Keep":**

1. **Move to hooks directory:**
   ```bash
   mkdir -p scripts/hooks
   cp scripts/custom-check.sh scripts/hooks/
   ```

2. **Update faber-cloud.json:**
   ```json
   {
     "hooks": {
       "post_plan": [
         {
           "name": "custom-validation",
           "command": "bash ./scripts/hooks/custom-check.sh {{environment}}",
           "critical": true
         }
       ]
     }
   }
   ```

3. **Test the hook:**
   ```bash
   /fractary-faber-cloud:deploy-plan --env=test
   # Verify hook executes
   ```

### Step 5: Test in Test Environment

**Complete workflow test:**

```bash
# 1. Audit (read-only)
/fractary-faber-cloud:audit --env=test --check=full

# 2. Plan changes
/fractary-faber-cloud:deploy-plan --env=test
# → Verify all hooks execute
# → Review plan output

# 3. Deploy
/fractary-faber-cloud:deploy-execute --env=test
# → Verify deployment succeeds
# → Verify post-deploy hooks run

# 4. Validate deployment
/fractary-faber-cloud:audit --env=test --check=full
```

**Verify:**
- ✅ All hooks execute successfully
- ✅ Deployment completes
- ✅ Resources match expectations
- ✅ No regressions from old workflow

### Step 6: Update Team Documentation

**Update README.md:**
```markdown
## Infrastructure Deployment

We use [faber-cloud](link) for infrastructure lifecycle management.

### Quick Start

```bash
# Audit infrastructure
/fractary-faber-cloud:audit --env=test

# Deploy changes
/fractary-faber-cloud:deploy-execute --env=test
```

### Custom Hooks

Our deployment includes custom hooks:
- **post_plan:** Custom business validation
- **post_deploy:** Smoke tests
- **pre_destroy:** Production backups
```

**Update runbooks:**
- Document new commands
- Remove old script references
- Add troubleshooting steps
- Include rollback procedures

### Step 7: Migrate Production

**Pre-production checklist:**

- [ ] Test environment fully migrated and validated
- [ ] Team trained on new workflow
- [ ] Documentation updated
- [ ] Rollback plan documented
- [ ] Backup of current state created
- [ ] Stakeholders notified

**Production migration:**

```bash
# 1. Final audit before migration
/fractary-faber-cloud:audit --env=prod --check=full

# 2. Test plan (read-only)
/fractary-faber-cloud:deploy-plan --env=prod

# 3. Deploy to production
/fractary-faber-cloud:deploy-execute --env=prod
# → Review plan carefully
# → Approve when ready

# 4. Post-migration validation
/fractary-faber-cloud:audit --env=prod --check=full
```

### Step 8: Archive Old Scripts

```bash
# Move old scripts to archive
mkdir -p archive/pre-faber-cloud
mv scripts/deploy.sh archive/pre-faber-cloud/
mv scripts/validate.sh archive/pre-faber-cloud/
# ... etc

# Keep for 30 days, then can remove
git add archive/
git commit -m "chore: Archive pre-faber-cloud scripts"
```

## Hook Integration Examples

### Example 1: Build Lambda Functions Before Deploy

**Scenario:** Build Lambda functions before Terraform applies changes.

**scripts/hooks/build-lambdas.sh:**
```bash
#!/bin/bash
set -euo pipefail

echo "Building Lambda functions..."

cd lambdas/
for func in */; do
  echo "Building ${func}..."
  cd "$func"
  npm install --production
  zip -r "../${func%/}.zip" .
  cd ..
done

echo "Lambda functions built successfully!"
```

**faber-cloud.json:**
```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "build-lambdas",
        "command": "bash ./scripts/hooks/build-lambdas.sh",
        "critical": true,
        "timeout": 600,
        "environments": ["test", "prod"]
      }
    ]
  }
}
```

### Example 2: Notify Team on Deployment

**Scenario:** Send Slack notification after successful deployment.

**scripts/hooks/notify-deployment.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1
WEBHOOK_URL="${SLACK_WEBHOOK_URL}"

curl -X POST "$WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d "{
    \"text\": \"🚀 Infrastructure deployed to *${ENVIRONMENT}*\",
    \"channel\": \"#infrastructure\"
  }"
```

**faber-cloud.json:**
```json
{
  "hooks": {
    "post_deploy": [
      {
        "name": "notify-team",
        "command": "bash ./scripts/hooks/notify-deployment.sh {{environment}}",
        "critical": false,
        "timeout": 30
      }
    ]
  }
}
```

### Example 3: Validate Database Migrations

**Scenario:** Ensure database migrations are ready before infrastructure changes.

**scripts/hooks/check-migrations.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1

echo "Checking database migrations for $ENVIRONMENT..."

# Check for pending migrations
PENDING=$(./scripts/check-pending-migrations.sh "$ENVIRONMENT")

if [ "$PENDING" -gt 0 ]; then
  echo "ERROR: $PENDING pending database migrations!"
  echo "Run migrations before deploying infrastructure."
  exit 1
fi

echo "All database migrations applied!"
```

**faber-cloud.json:**
```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "check-migrations",
        "command": "bash ./scripts/hooks/check-migrations.sh {{environment}}",
        "critical": true,
        "timeout": 120,
        "environments": ["prod"]
      }
    ]
  }
}
```

## Testing Your Migration

### Test Checklist

**Pre-deployment:**
- [ ] Configuration valid (`/fractary-faber-cloud:audit --env=test`)
- [ ] All hooks executable (`chmod +x scripts/hooks/*.sh`)
- [ ] Environment variables set
- [ ] AWS credentials configured

**During deployment:**
- [ ] Pre-deploy hooks execute
- [ ] Terraform plan generated
- [ ] Plan reviewed and approved
- [ ] Deployment succeeds
- [ ] Post-deploy hooks execute

**Post-deployment:**
- [ ] Resources deployed correctly
- [ ] Applications functioning
- [ ] Monitoring working
- [ ] No regressions

### Common Issues

**Hook fails to execute:**
```bash
# Check permissions
ls -la scripts/hooks/

# Make executable
chmod +x scripts/hooks/*.sh

# Test hook manually
bash scripts/hooks/your-hook.sh test
```

**Environment variable not available:**
```bash
# Add to hook script
export AWS_PROFILE="myapp-${ENVIRONMENT}"
export AWS_REGION="us-west-2"
```

**Timeout too short:**
```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "long-running-task",
        "timeout": 1800  // Increase from default 300
      }
    ]
  }
}
```

## Rollback Plan

### If Issues Occur

**During migration:**
1. Stop the migration process
2. Do not install faber-cloud configuration
3. Continue using existing scripts
4. Review issues and adjust plan

**After partial migration:**
1. Identify failing component
2. Revert to old script for that component
3. Keep working components on faber-cloud
4. Fix issues, then migrate again

**Complete rollback:**
```bash
# Remove faber-cloud configuration
rm -rf .fractary/plugins/faber-cloud/

# Restore old scripts
cp -r archive/pre-faber-cloud/* scripts/

# Use old workflow
./scripts/deploy.sh test
```

### Gradual Migration

**Recommended approach:**
1. Migrate test environment completely
2. Run in parallel for 1 week
3. Migrate staging environment
4. Run in parallel for 1 week
5. Migrate production environment
6. Archive old scripts after 30 days

## Common Patterns

### Pattern: Multi-Step Build Process

```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "install-dependencies",
        "command": "npm install",
        "critical": true
      },
      {
        "name": "run-tests",
        "command": "npm test",
        "critical": true
      },
      {
        "name": "build-artifacts",
        "command": "npm run build",
        "critical": true
      }
    ]
  }
}
```

### Pattern: Environment-Specific Hooks

```json
{
  "hooks": {
    "post_deploy": [
      {
        "name": "smoke-test-basic",
        "command": "bash ./scripts/smoke-test.sh",
        "environments": ["test"]
      },
      {
        "name": "smoke-test-comprehensive",
        "command": "bash ./scripts/smoke-test-full.sh",
        "environments": ["prod"],
        "timeout": 1200
      }
    ]
  }
}
```

### Pattern: Conditional Hooks

```bash
#!/bin/bash
# conditional-hook.sh

ENVIRONMENT=$1

# Only run in production
if [ "$ENVIRONMENT" != "prod" ]; then
  echo "Skipping in non-production environment"
  exit 0
fi

# Production-specific logic
echo "Running production-only validation..."
```

## FAQ

**Q: Can I keep some old scripts?**
A: Yes! You don't have to migrate everything. Start with core workflows (deploy, plan) and keep custom scripts as hooks.

**Q: What if my script is too complex for a hook?**
A: Break it down:
- Core deployment → Use infra-deployer
- Pre-checks → pre_deploy hook
- Post-validation → post_deploy hook

**Q: How do I pass parameters to hooks?**
A: Use template variables:
```json
{
  "command": "bash ./script.sh {{environment}} {{aws_profile}}"
}
```

Available variables: `{{environment}}`, `{{aws_profile}}`, `{{terraform_dir}}`

**Q: Can hooks fail without stopping deployment?**
A: Yes! Set `"critical": false` for non-essential hooks.

**Q: How do I debug a failing hook?**
A: Run it manually:
```bash
bash ./scripts/hooks/your-hook.sh test
# Check exit code
echo $?
```

**Q: Can I have multiple hooks of the same type?**
A: Yes! They execute in array order:
```json
{
  "hooks": {
    "pre_deploy": [
      {"name": "check-1", "command": "..."},
      {"name": "check-2", "command": "..."},
      {"name": "check-3", "command": "..."}
    ]
  }
}
```

**Q: What happens if a critical hook fails?**
A: Deployment stops immediately. Fix the issue and retry.

**Q: Can I use hooks in other languages?**
A: Yes! Any executable:
```json
{
  "command": "python ./scripts/check.py {{environment}}"
}
{
  "command": "node ./scripts/notify.js {{environment}}"
}
```

---

**Need Help?**
- Review [Hook System Documentation](HOOKS.md)
- Check [Troubleshooting Guide](TROUBLESHOOTING.md)
- Open an issue on GitHub
