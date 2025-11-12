# Hook System Guide

The faber-cloud hook system allows you to execute custom scripts at key points in the infrastructure lifecycle, extending faber-cloud's capabilities while maintaining standardized workflows.

## Table of Contents

- [Overview](#overview)
- [Hook Types](#hook-types)
- [Configuration](#configuration)
- [Hook Examples](#hook-examples)
- [Advanced Usage](#advanced-usage)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

### What are Hooks?

Hooks are custom scripts that execute at specific lifecycle stages:

```
┌─────────────────────────────────────────────────┐
│           Infrastructure Lifecycle              │
├─────────────────────────────────────────────────┤
│                                                 │
│  pre_plan → PLAN → post_plan                   │
│     ↓                    ↓                      │
│  pre_deploy → DEPLOY → post_deploy             │
│     ↓                    ↓                      │
│  pre_destroy → DESTROY → post_destroy          │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Why Use Hooks?

**Extend without forking:**
- Add custom validation logic
- Integrate with existing tools
- Preserve business-specific workflows
- Gradually migrate from custom scripts

**Examples:**
- Build artifacts before deployment
- Run smoke tests after deployment
- Backup state before destruction
- Send notifications to team
- Validate compliance requirements

### Hook Execution Model

**Sequential execution:**
1. Hooks execute in array order
2. Critical hooks must succeed (exit code 0)
3. Non-critical hooks can fail without stopping workflow
4. Timeout enforced per hook
5. Output captured and logged

## Hook Types

### pre_plan

**Executes:** Before `terraform plan`
**Use for:** Pre-validation, setup, preparation

**Example use cases:**
- Validate environment variables
- Check prerequisites
- Generate dynamic configuration
- Lint Terraform code

### post_plan

**Executes:** After `terraform plan` (before approval)
**Use for:** Plan validation, analysis, reporting

**Example use cases:**
- Custom business logic validation
- Cost estimation analysis
- Security policy checks
- Generate plan summary

### pre_deploy

**Executes:** After approval, before `terraform apply`
**Use for:** Build steps, final checks, backups

**Example use cases:**
- Build Lambda functions
- Compile assets
- Create backups
- Final safety checks

### post_deploy

**Executes:** After `terraform apply` succeeds
**Use for:** Verification, testing, notifications

**Example use cases:**
- Smoke tests
- Integration tests
- Send notifications
- Update documentation

### pre_destroy

**Executes:** Before `terraform destroy`
**Use for:** Backups, safety checks, data preservation

**Example use cases:**
- Backup Terraform state
- Export data
- Create snapshots
- Validate destruction is safe

### post_destroy

**Executes:** After `terraform destroy` succeeds
**Use for:** Cleanup, notifications, verification

**Example use cases:**
- Verify resources deleted
- Clean up artifacts
- Notify team
- Archive logs

## Hook Types: Scripts, Skills, and Prompts

The faber-cloud hook system supports **three types of hooks**:

### 1. Script Hooks (Traditional)

Execute shell scripts or commands at lifecycle points.

**Best for:**
- Build steps (compile, package)
- Simple validations
- Shell commands and CLI tools
- Quick one-off operations

**Format:**
```json
{
  "type": "script",
  "path": "./scripts/build.sh",
  "required": true,
  "timeout": 300
}
```

### 2. Skill Hooks (New)

Invoke Claude Code skills as hook handlers with structured interfaces.

**Best for:**
- Complex validation logic
- Reusable workflows across projects
- Structured data handling
- Integration with Claude Code ecosystem
- Testable, discoverable extensions

**Format:**
```json
{
  "type": "skill",
  "name": "dataset-validator-deploy-pre",
  "required": true,
  "failureMode": "stop",
  "timeout": 300
}
```

**Key Differences:**

| Feature | Script Hooks | Skill Hooks |
|---------|-------------|-------------|
| Execution | Shell commands | Claude Code skills |
| Input | Environment variables | Structured WorkflowContext JSON |
| Output | Exit codes | Structured WorkflowResult JSON |
| Discoverability | Hidden in scripts | Visible via `/help` |
| Testability | Manual testing | `/skill skill-name` |
| Reusability | Copy files | Install skill package |
| Type Safety | None | Structured interfaces |

### 3. Prompt Hooks (Flexible Context Injection)

Provide flexible text-based guidance that can reference documentation, suggest scripts, or invoke skills.

**Best for:**
- Injecting project-specific context and standards
- Referencing documentation during workflow execution
- Providing environment-specific guidance
- Combining multiple instructions in natural language

**Format:**
```json
{
  "type": "prompt",
  "name": "deployment-guidance",
  "prompt": "Review the deployment checklist in docs/DEPLOYMENT.md before proceeding. Run ./scripts/pre-deploy-checks.sh to validate readiness. Use the security-scanner skill to check for vulnerabilities."
}
```

**Key Features:**
- **File Reference Detection**: Automatically detects and loads referenced files (*.md, *.txt, etc.)
- **Natural Language**: Write instructions in plain English
- **Flexible**: Can suggest scripts, reference docs, invoke skills - all in one prompt
- **Context Injection**: Loaded content is injected into the agent's context
- **No Failures**: Prompt hooks always succeed (they provide context, not validation)

**Example with File References:**
```json
{
  "type": "prompt",
  "name": "architecture-context",
  "prompt": "Apply the architecture standards from docs/architecture/STANDARDS.md when reviewing infrastructure changes. Pay attention to resource naming in docs/NAMING_CONVENTIONS.md."
}
```

When this hook executes:
1. Detects file references: `docs/architecture/STANDARDS.md`, `docs/NAMING_CONVENTIONS.md`
2. Loads these files from the project
3. Builds a context block with the prompt text + file contents
4. Saves to `/tmp/faber-cloud-hook-context-{name}.txt`
5. Skills can read this context and apply it

**When to use prompt hooks:**
- **Injecting standards**: Reference coding standards, architecture guides, API patterns
- **Environment-specific warnings**: Critical reminders for production deployments
- **Combining actions**: "Do X, then Y, then check Z" in natural language
- **Project documentation**: Make project-specific docs available during workflow

**When to use each:**
- **Script hooks:** For deterministic operations (build, deploy, test)
- **Skill hooks:** For complex validation requiring AI reasoning
- **Prompt hooks:** For context injection and flexible guidance

### Backward Compatibility

Legacy string hooks are still supported:
```json
{
  "hooks": {
    "pre_deploy": ["bash ./scripts/build.sh"]  // Still works!
  }
}
```

These are automatically treated as script hooks with default settings.

## Configuration

### Basic Hook Configuration

**Script Hook (Legacy Format):**
```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "build-lambdas",
        "command": "bash ./scripts/build-lambdas.sh",
        "critical": true,
        "timeout": 600
      }
    ]
  }
}
```

**Script Hook (New Format):**
```json
{
  "hooks": {
    "pre_deploy": [
      {
        "type": "script",
        "path": "./scripts/build-lambdas.sh",
        "name": "build-lambdas",
        "required": true,
        "failureMode": "stop",
        "timeout": 600
      }
    ]
  }
}
```

**Skill Hook:**
```json
{
  "hooks": {
    "pre_deploy": [
      {
        "type": "skill",
        "name": "custom-validator",
        "required": true,
        "failureMode": "stop",
        "timeout": 300
      }
    ]
  }
}
```

### Hook Properties

**Common Properties (all hook types):**

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `type` | string | No | (inferred) | "script" or "skill" - type of hook |
| `name` | string | Conditional | - | Human-readable identifier (required for skills) |
| `required` | boolean | No | `true` | If true, failure stops workflow |
| `failureMode` | string | No | `"stop"` | "stop" or "warn" - action on failure |
| `timeout` | number | No | `300` | Timeout in seconds |
| `environments` | array | No | all | Environments where hook runs |
| `description` | string | No | - | Documentation for the hook |

**Script Hook Properties:**

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `command` | string | Yes (legacy) | - | Shell command to execute (legacy format) |
| `path` | string | Yes (new) | - | Path to script file (new format) |

**Skill Hook Properties:**

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `name` | string | Yes | - | Name of Claude Code skill to invoke |

**Note:** Retry logic for skill hooks is planned for a future release.

### Template Variables

Use template variables in commands:

```json
{
  "command": "bash ./script.sh {{environment}} {{aws_profile}} {{terraform_dir}}"
}
```

**Available variables:**
- `{{environment}}` - Current environment (test, prod)
- `{{aws_profile}}` - AWS profile for environment
- `{{terraform_dir}}` - Terraform working directory
- `{{aws_region}}` - AWS region for environment

## Hook Examples

### Example 1: Build Lambda Functions

**Scenario:** Build and package Lambda functions before deployment.

**scripts/hooks/build-lambdas.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1

echo "Building Lambda functions for ${ENVIRONMENT}..."

cd lambdas/

for func_dir in */; do
  func_name="${func_dir%/}"
  echo "  Building ${func_name}..."

  cd "$func_name"

  # Install dependencies
  npm install --production --silent

  # Run tests
  npm test

  # Create deployment package
  zip -q -r "../${func_name}.zip" . -x "*.test.js" "node_modules/aws-sdk/*"

  cd ..

  echo "  ✓ ${func_name} built successfully"
done

echo "All Lambda functions built!"
```

**Configuration:**
```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "build-lambdas",
        "command": "bash ./scripts/hooks/build-lambdas.sh {{environment}}",
        "critical": true,
        "timeout": 600,
        "description": "Build and package Lambda functions"
      }
    ]
  }
}
```

### Example 2: Validate Security Compliance

**Scenario:** Ensure infrastructure meets security standards.

**scripts/hooks/security-validation.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1

echo "Validating security compliance for ${ENVIRONMENT}..."

# Check S3 bucket encryption
terraform show -json | jq -e '
  .values.root_module.resources[] |
  select(.type == "aws_s3_bucket") |
  select(.values.server_side_encryption_configuration | length == 0)
' && {
  echo "ERROR: S3 buckets must have encryption enabled!"
  exit 1
}

# Check security group rules
terraform show -json | jq -e '
  .values.root_module.resources[] |
  select(.type == "aws_security_group") |
  select(.values.ingress[] | select(.cidr_blocks[] == "0.0.0.0/0"))
' && {
  echo "WARNING: Security groups with 0.0.0.0/0 ingress detected"
}

# Check IAM policies
terraform show -json | jq -e '
  .values.root_module.resources[] |
  select(.type == "aws_iam_policy") |
  select(.values.policy | contains("*"))
' && {
  echo "ERROR: IAM policies must not use wildcard actions!"
  exit 1
}

echo "✓ Security compliance validated"
```

**Configuration:**
```json
{
  "hooks": {
    "post_plan": [
      {
        "name": "security-validation",
        "command": "bash ./scripts/hooks/security-validation.sh {{environment}}",
        "critical": true,
        "timeout": 180,
        "description": "Validate security compliance requirements"
      }
    ]
  }
}
```

### Example 3: Cost Estimation

**Scenario:** Estimate infrastructure costs before deployment.

**scripts/hooks/cost-estimate.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1

echo "Estimating infrastructure costs for ${ENVIRONMENT}..."

# Generate Terraform plan JSON
terraform plan -out=tfplan -var-file="${ENVIRONMENT}.tfvars" > /dev/null
terraform show -json tfplan > plan.json

# Use infracost to estimate
infracost breakdown \
  --path plan.json \
  --format table \
  --show-skipped

# Check if cost exceeds threshold
MONTHLY_COST=$(infracost breakdown --path plan.json --format json | jq -r '.totalMonthlyCost')

if (( $(echo "$MONTHLY_COST > 1000" | bc -l) )); then
  echo "WARNING: Monthly cost estimate: \$${MONTHLY_COST} exceeds \$1000 threshold"

  if [ "$ENVIRONMENT" = "prod" ]; then
    echo "Production deployment - proceeding with caution"
  else
    echo "ERROR: Test environment cost too high!"
    exit 1
  fi
fi

# Cleanup
rm -f tfplan plan.json

echo "✓ Cost estimation complete: \$${MONTHLY_COST}/month"
```

**Configuration:**
```json
{
  "hooks": {
    "post_plan": [
      {
        "name": "cost-estimate",
        "command": "bash ./scripts/hooks/cost-estimate.sh {{environment}}",
        "critical": false,
        "timeout": 300,
        "description": "Estimate monthly infrastructure costs"
      }
    ]
  }
}
```

### Example 4: Smoke Tests

**Scenario:** Verify deployment health immediately after applying changes.

**scripts/hooks/smoke-test.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1

echo "Running smoke tests for ${ENVIRONMENT}..."

# Get outputs from Terraform
API_ENDPOINT=$(terraform output -raw api_endpoint)
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test API health endpoint
echo "  Testing API health endpoint..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${API_ENDPOINT}/health")

if [ "$HTTP_STATUS" -ne 200 ]; then
  echo "ERROR: API health check failed (HTTP ${HTTP_STATUS})"
  exit 1
fi

echo "  ✓ API responding (HTTP 200)"

# Test ALB
echo "  Testing ALB..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${ALB_DNS}/")

if [ "$HTTP_STATUS" -ne 200 ]; then
  echo "ERROR: ALB health check failed (HTTP ${HTTP_STATUS})"
  exit 1
fi

echo "  ✓ ALB responding (HTTP 200)"

# Test database connectivity
echo "  Testing database connectivity..."
./scripts/test-db-connection.sh "$ENVIRONMENT" || {
  echo "ERROR: Database connection failed"
  exit 1
}

echo "  ✓ Database connection successful"

echo "✓ All smoke tests passed!"
```

**Configuration:**
```json
{
  "hooks": {
    "post_deploy": [
      {
        "name": "smoke-tests",
        "command": "bash ./scripts/hooks/smoke-test.sh {{environment}}",
        "critical": true,
        "timeout": 300,
        "description": "Run smoke tests to verify deployment health"
      }
    ]
  }
}
```

### Example 5: Backup Before Destroy

**Scenario:** Create comprehensive backups before destroying production infrastructure.

**scripts/hooks/backup-before-destroy.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1

if [ "$ENVIRONMENT" != "prod" ]; then
  echo "Skipping backups for non-production environment"
  exit 0
fi

echo "Creating backups before destroying production infrastructure..."

BACKUP_DIR="./backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup Terraform state
echo "  Backing up Terraform state..."
terraform state pull > "${BACKUP_DIR}/terraform.tfstate"
echo "  ✓ State backed up"

# Backup RDS databases
echo "  Creating RDS snapshots..."
DB_INSTANCES=$(aws rds describe-db-instances \
  --query 'DBInstances[?TagList[?Key==`Environment` && Value==`prod`]].DBInstanceIdentifier' \
  --output text)

for db in $DB_INSTANCES; do
  SNAPSHOT_ID="${db}-final-$(date +%Y%m%d-%H%M%S)"
  aws rds create-db-snapshot \
    --db-instance-identifier "$db" \
    --db-snapshot-identifier "$SNAPSHOT_ID"
  echo "  ✓ Snapshot created: $SNAPSHOT_ID"
done

# Backup S3 data
echo "  Backing up S3 data..."
S3_BUCKETS=$(aws s3 ls | grep "prod-" | awk '{print $3}')

for bucket in $S3_BUCKETS; do
  aws s3 sync "s3://${bucket}" "${BACKUP_DIR}/s3/${bucket}" --quiet
  echo "  ✓ Bucket backed up: $bucket"
done

# Save resource inventory
echo "  Saving resource inventory..."
terraform show -json > "${BACKUP_DIR}/resources.json"

echo "✓ All backups complete!"
echo "Backup location: ${BACKUP_DIR}"
```

**Configuration:**
```json
{
  "hooks": {
    "pre_destroy": [
      {
        "name": "backup-production",
        "command": "bash ./scripts/hooks/backup-before-destroy.sh {{environment}}",
        "critical": true,
        "timeout": 1800,
        "environments": ["prod"],
        "description": "Create comprehensive backups before destruction"
      }
    ]
  }
}
```

### Example 6: Slack Notifications

**Scenario:** Send deployment notifications to team Slack channel.

**scripts/hooks/notify-slack.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1
PHASE=$2  # pre-deploy, post-deploy, etc.
WEBHOOK_URL="${SLACK_WEBHOOK_URL}"

# Determine message and color
case "$PHASE" in
  "pre-deploy")
    MESSAGE="🚀 Starting deployment to *${ENVIRONMENT}*"
    COLOR="warning"
    ;;
  "post-deploy")
    MESSAGE="✅ Successfully deployed to *${ENVIRONMENT}*"
    COLOR="good"
    ;;
  "pre-destroy")
    MESSAGE="⚠️  Starting infrastructure destruction in *${ENVIRONMENT}*"
    COLOR="danger"
    ;;
  *)
    MESSAGE="ℹ️  Infrastructure operation in *${ENVIRONMENT}*: ${PHASE}"
    COLOR="#808080"
    ;;
esac

# Get deployment details
CHANGES=$(terraform show -json | jq -r '.values.root_module.resources | length')
USER=$(whoami)
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Send to Slack
curl -X POST "$WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d "{
    \"attachments\": [{
      \"color\": \"${COLOR}\",
      \"text\": \"${MESSAGE}\",
      \"fields\": [
        {\"title\": \"Environment\", \"value\": \"${ENVIRONMENT}\", \"short\": true},
        {\"title\": \"User\", \"value\": \"${USER}\", \"short\": true},
        {\"title\": \"Resources\", \"value\": \"${CHANGES}\", \"short\": true},
        {\"title\": \"Time\", \"value\": \"${TIMESTAMP}\", \"short\": true}
      ]
    }]
  }"

echo "Notification sent to Slack"
```

**Configuration:**
```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "notify-deployment-start",
        "command": "bash ./scripts/hooks/notify-slack.sh {{environment}} pre-deploy",
        "critical": false,
        "timeout": 30
      }
    ],
    "post_deploy": [
      {
        "name": "notify-deployment-success",
        "command": "bash ./scripts/hooks/notify-slack.sh {{environment}} post-deploy",
        "critical": false,
        "timeout": 30
      }
    ]
  }
}
```

### Example 7: Check Database Migrations

**Scenario:** Ensure database migrations are applied before infrastructure changes.

**scripts/hooks/check-migrations.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1

echo "Checking database migrations for ${ENVIRONMENT}..."

# Get database connection string
DB_HOST=$(terraform output -raw db_host 2>/dev/null || echo "")

if [ -z "$DB_HOST" ]; then
  echo "No database found, skipping migration check"
  exit 0
fi

# Check pending migrations
PENDING=$(./scripts/get-pending-migrations.sh "$ENVIRONMENT" | wc -l)

if [ "$PENDING" -gt 0 ]; then
  echo "ERROR: ${PENDING} pending database migration(s) detected!"
  echo ""
  echo "Pending migrations:"
  ./scripts/get-pending-migrations.sh "$ENVIRONMENT"
  echo ""
  echo "Please run migrations before deploying infrastructure:"
  echo "  ./scripts/run-migrations.sh ${ENVIRONMENT}"
  exit 1
fi

echo "✓ All database migrations applied"
```

**Configuration:**
```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "check-migrations",
        "command": "bash ./scripts/hooks/check-migrations.sh {{environment}}",
        "critical": true,
        "timeout": 120,
        "description": "Ensure database migrations are up to date"
      }
    ]
  }
}
```

### Example 8: Terraform Format Check

**Scenario:** Enforce Terraform formatting standards.

**scripts/hooks/terraform-format.sh:**
```bash
#!/bin/bash
set -euo pipefail

echo "Checking Terraform formatting..."

# Check if terraform fmt would make changes
if ! terraform fmt -check -recursive; then
  echo ""
  echo "ERROR: Terraform files are not properly formatted!"
  echo ""
  echo "Run the following to fix:"
  echo "  terraform fmt -recursive"
  echo ""
  exit 1
fi

echo "✓ Terraform formatting is correct"
```

**Configuration:**
```json
{
  "hooks": {
    "pre_plan": [
      {
        "name": "terraform-format",
        "command": "bash ./scripts/hooks/terraform-format.sh",
        "critical": true,
        "timeout": 60,
        "description": "Enforce Terraform formatting standards"
      }
    ]
  }
}
```

### Example 9: Resource Tagging Validation

**Scenario:** Ensure all resources have required tags.

**scripts/hooks/validate-tags.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1

echo "Validating resource tags for ${ENVIRONMENT}..."

REQUIRED_TAGS=("Environment" "Project" "ManagedBy")

# Check each resource in plan
terraform show -json | jq -r '
  .values.root_module.resources[] |
  select(.values.tags != null) |
  {type: .type, name: .name, tags: .values.tags}
' | while read -r resource; do
  for tag in "${REQUIRED_TAGS[@]}"; do
    if ! echo "$resource" | jq -e ".tags.${tag}" > /dev/null; then
      echo "ERROR: Resource missing required tag '${tag}'"
      echo "$resource" | jq .
      exit 1
    fi
  done
done

# Ensure Environment tag matches
terraform show -json | jq -e "
  .values.root_module.resources[] |
  select(.values.tags.Environment != \"${ENVIRONMENT}\")
" && {
  echo "ERROR: Some resources have incorrect Environment tag!"
  exit 1
}

echo "✓ All resources properly tagged"
```

**Configuration:**
```json
{
  "hooks": {
    "post_plan": [
      {
        "name": "validate-tags",
        "command": "bash ./scripts/hooks/validate-tags.sh {{environment}}",
        "critical": true,
        "timeout": 120,
        "description": "Validate all resources have required tags"
      }
    ]
  }
}
```

### Example 10: CDN Cache Invalidation

**Scenario:** Invalidate CloudFront cache after deploying static assets.

**scripts/hooks/invalidate-cdn.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1

echo "Invalidating CDN cache for ${ENVIRONMENT}..."

# Get CloudFront distribution ID from Terraform output
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")

if [ -z "$DISTRIBUTION_ID" ]; then
  echo "No CloudFront distribution found, skipping cache invalidation"
  exit 0
fi

# Create invalidation
INVALIDATION_ID=$(aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "/*" \
  --query 'Invalidation.Id' \
  --output text)

echo "Cache invalidation created: ${INVALIDATION_ID}"

# Wait for invalidation to complete (optional)
if [ "${WAIT_FOR_INVALIDATION:-false}" = "true" ]; then
  echo "Waiting for invalidation to complete..."
  aws cloudfront wait invalidation-completed \
    --distribution-id "$DISTRIBUTION_ID" \
    --id "$INVALIDATION_ID"
  echo "✓ Cache invalidation complete"
else
  echo "✓ Cache invalidation initiated (not waiting)"
fi
```

**Configuration:**
```json
{
  "hooks": {
    "post_deploy": [
      {
        "name": "invalidate-cdn",
        "command": "bash ./scripts/hooks/invalidate-cdn.sh {{environment}}",
        "critical": false,
        "timeout": 600,
        "description": "Invalidate CDN cache after deployment"
      }
    ]
  }
}
```

### Example 11: Update Documentation

**Scenario:** Auto-generate infrastructure documentation after deployment.

**scripts/hooks/generate-docs.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1

echo "Generating infrastructure documentation for ${ENVIRONMENT}..."

DOCS_DIR="./docs/infrastructure"
mkdir -p "$DOCS_DIR"

# Generate resource inventory
terraform show -json | jq -r '
  .values.root_module.resources[] |
  "- \(.type): \(.name) (\(.values.id // "pending"))"
' > "${DOCS_DIR}/${ENVIRONMENT}-resources.md"

# Generate outputs documentation
cat > "${DOCS_DIR}/${ENVIRONMENT}-outputs.md" <<EOF
# ${ENVIRONMENT} Infrastructure Outputs

Generated: $(date)

EOF

terraform output -json | jq -r '
  to_entries[] |
  "## \(.key)\n\nValue: \(.value.value)\n"
' >> "${DOCS_DIR}/${ENVIRONMENT}-outputs.md"

# Generate architecture diagram (using terraform-graph or similar)
terraform graph | dot -Tpng > "${DOCS_DIR}/${ENVIRONMENT}-architecture.png"

echo "✓ Documentation generated in ${DOCS_DIR}/"
```

**Configuration:**
```json
{
  "hooks": {
    "post_deploy": [
      {
        "name": "generate-docs",
        "command": "bash ./scripts/hooks/generate-docs.sh {{environment}}",
        "critical": false,
        "timeout": 180,
        "description": "Generate infrastructure documentation"
      }
    ]
  }
}
```

### Example 12: Skill Hook for Dataset Validation

**Scenario:** Validate datasets before and after deployment using a reusable Claude Code skill.

**Skill Location:** `.claude/skills/dataset-validator-deploy-pre/SKILL.md`

```markdown
---
name: dataset-validator-deploy-pre
description: Validate datasets before infrastructure deployment
tools: Read, Bash
---

# Dataset Validator - Pre-Deployment

<CONTEXT>
You are a dataset validator that runs before infrastructure deployments.
You receive structured WorkflowContext and validate datasets are ready for deployment.
</CONTEXT>

<INPUTS>
WorkflowContext (via environment or file):
- environment: test, prod
- operation: deploy
- projectRoot: Project directory
- artifacts: Previous step outputs
</INPUTS>

<WORKFLOW>
1. Read WorkflowContext from environment variables
2. Check dataset files exist
3. Validate dataset schemas
4. Verify data quality metrics
5. Return structured WorkflowResult
</WORKFLOW>

<OUTPUTS>
WorkflowResult (JSON to stdout):
```json
{
  "success": true/false,
  "messages": ["validation messages"],
  "warnings": ["warning messages"],
  "errors": ["error messages"],
  "artifacts": {
    "validationReport": "/path/to/report.json"
  },
  "executionTime": 1234,
  "timestamp": "2025-11-07T12:00:00Z",
  "skillName": "dataset-validator-deploy-pre"
}
```
</OUTPUTS>
</SKILL.md>
```

**Configuration:**
```json
{
  "hooks": {
    "pre-deploy": [
      {
        "type": "skill",
        "name": "dataset-validator-deploy-pre",
        "required": true,
        "failureMode": "stop",
        "timeout": 300,
        "description": "Validate datasets before deployment"
      }
    ],
    "post-deploy": [
      {
        "type": "skill",
        "name": "dataset-validator-deploy-post",
        "required": true,
        "failureMode": "stop",
        "timeout": 300,
        "description": "Validate datasets after deployment"
      }
    ]
  }
}
```

**Benefits of Skill Hooks:**
- ✅ Reusable across projects
- ✅ Testable independently: `/skill dataset-validator-deploy-pre`
- ✅ Discoverable via `/help`
- ✅ Structured input/output interfaces
- ✅ Version controlled with project
- ✅ Can leverage Claude Code ecosystem

**Testing the Skill:**
```bash
# Test skill independently
/skill dataset-validator-deploy-pre

# Test with specific context
echo '{"environment": "test", "operation": "deploy"}' | /skill dataset-validator-deploy-pre
```

### Example 13: Mixed Script and Skill Hooks

**Scenario:** Use script hooks for simple operations and skill hooks for complex validation.

**Configuration:**
```json
{
  "hooks": {
    "pre-deploy": [
      {
        "type": "script",
        "path": "./scripts/build-lambda.sh",
        "name": "build-lambdas",
        "required": true,
        "timeout": 300
      },
      {
        "type": "skill",
        "name": "security-compliance-validator",
        "required": true,
        "failureMode": "stop",
        "timeout": 180
      },
      {
        "type": "script",
        "path": "./scripts/backup-state.sh",
        "name": "backup-state",
        "required": false,
        "failureMode": "warn",
        "timeout": 60
      }
    ],
    "post-deploy": [
      {
        "type": "script",
        "path": "./scripts/smoke-test.sh",
        "name": "smoke-tests",
        "required": true,
        "timeout": 120
      },
      {
        "type": "skill",
        "name": "deployment-verifier",
        "required": true,
        "failureMode": "stop",
        "timeout": 300
      }
    ]
  }
}
```

**Execution Order:**
1. Build Lambda functions (script)
2. Validate security compliance (skill)
3. Backup state (script - optional)
4. Deploy infrastructure
5. Run smoke tests (script)
6. Verify deployment (skill)

## Advanced Usage

### Conditional Execution

**Environment-specific hooks:**
```json
{
  "hooks": {
    "post_deploy": [
      {
        "name": "production-only-check",
        "command": "bash ./scripts/prod-check.sh",
        "environments": ["prod"]
      },
      {
        "name": "test-only-check",
        "command": "bash ./scripts/test-check.sh",
        "environments": ["test"]
      }
    ]
  }
}
```

**Within a script:**
```bash
#!/bin/bash
ENVIRONMENT=$1

if [ "$ENVIRONMENT" = "prod" ]; then
  # Production-specific logic
  run_comprehensive_checks
else
  # Non-production logic
  run_basic_checks
fi
```

### Chaining Multiple Hooks

```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "1-install-deps",
        "command": "npm install",
        "critical": true
      },
      {
        "name": "2-run-tests",
        "command": "npm test",
        "critical": true
      },
      {
        "name": "3-build",
        "command": "npm run build",
        "critical": true
      },
      {
        "name": "4-upload-assets",
        "command": "aws s3 sync ./dist s3://bucket/",
        "critical": true
      }
    ]
  }
}
```

**Execution order:** 1 → 2 → 3 → 4 (stops if any critical hook fails)

### Parallel Execution

Hooks execute sequentially by default. For parallel execution, use a wrapper script:

**scripts/hooks/parallel-checks.sh:**
```bash
#!/bin/bash
set -euo pipefail

# Run checks in parallel
./scripts/check-security.sh &
PID1=$!

./scripts/check-compliance.sh &
PID2=$!

./scripts/check-costs.sh &
PID3=$!

# Wait for all to complete
wait $PID1 || exit 1
wait $PID2 || exit 1
wait $PID3 || exit 1

echo "All parallel checks passed!"
```

### Dynamic Hook Configuration

Load hooks from external config:

**scripts/hooks/dynamic-hooks.sh:**
```bash
#!/bin/bash
set -euo pipefail

ENVIRONMENT=$1
HOOKS_CONFIG="./config/${ENVIRONMENT}-hooks.json"

if [ -f "$HOOKS_CONFIG" ]; then
  # Execute hooks from environment-specific config
  jq -r '.hooks[]' "$HOOKS_CONFIG" | while read -r hook_cmd; do
    echo "Executing: $hook_cmd"
    eval "$hook_cmd" || exit 1
  done
fi
```

## Best Practices

### 1. Make Hooks Idempotent

Hooks should be safe to run multiple times:

```bash
# Good: Idempotent
if [ ! -f "./dist/bundle.js" ]; then
  npm run build
fi

# Bad: Not idempotent
npm run build  # May fail if already built
```

### 2. Use Proper Exit Codes

```bash
# Success
echo "✓ Check passed"
exit 0

# Failure
echo "ERROR: Check failed"
exit 1
```

### 3. Set Appropriate Timeouts

```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "quick-check",
        "timeout": 60  // 1 minute for fast checks
      },
      {
        "name": "build-process",
        "timeout": 600  // 10 minutes for builds
      },
      {
        "name": "comprehensive-test",
        "timeout": 1800  // 30 minutes for thorough tests
      }
    ]
  }
}
```

### 4. Use Critical Flag Wisely

```json
{
  "hooks": {
    "post_deploy": [
      {
        "name": "smoke-test",
        "critical": true  // Must pass for deployment to succeed
      },
      {
        "name": "send-notification",
        "critical": false  // Nice to have, but not essential
      }
    ]
  }
}
```

### 5. Log Verbosely

```bash
#!/bin/bash
set -euo pipefail

echo "Starting validation..."
echo "  Checking requirement 1..."
check_requirement_1
echo "  ✓ Requirement 1 passed"

echo "  Checking requirement 2..."
check_requirement_2
echo "  ✓ Requirement 2 passed"

echo "✓ All validations passed!"
```

### 6. Handle Errors Gracefully

```bash
#!/bin/bash
set -euo pipefail

# Function with error handling
run_check() {
  if ! some_command; then
    echo "ERROR: Check failed"
    echo "Suggestion: Try running 'fix-command'"
    return 1
  fi
}

# Run with proper error handling
if ! run_check; then
  exit 1
fi
```

### 7. Document Your Hooks

```json
{
  "hooks": {
    "pre_deploy": [
      {
        "name": "build-assets",
        "command": "bash ./scripts/build.sh {{environment}}",
        "critical": true,
        "timeout": 600,
        "description": "Build and minify frontend assets. Requires Node.js 18+. Output: ./dist/"
      }
    ]
  }
}
```

## Troubleshooting

### Hook Not Executing

**Check:**
1. Hook defined in correct section
2. Environment filter not excluding current environment
3. Script has execute permissions: `chmod +x script.sh`
4. Command path is correct (use absolute or relative from project root)

### Hook Timing Out

**Solutions:**
1. Increase timeout value
2. Optimize script performance
3. Move long-running tasks to background with status checks

### Hook Failing Silently

**Check:**
1. Exit codes: Use `exit 1` on failure
2. Error output: Write to stderr for errors: `echo "ERROR" >&2`
3. Critical flag: Set `"critical": true` if failures should stop workflow

### Template Variables Not Substituted

**Ensure:**
1. Using double curly braces: `{{variable}}`
2. Variable name is correct (see available variables)
3. Configuration is valid JSON

### Permission Errors

**Solutions:**
```bash
# Make script executable
chmod +x ./scripts/hooks/*.sh

# Check AWS credentials
aws sts get-caller-identity

# Check Terraform permissions
terraform validate
```

---

**See Also:**
- [Migration from Custom Agents](MIGRATION-FROM-CUSTOM-AGENTS.md)
- [Configuration Templates](CONFIGURATION-TEMPLATES.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
