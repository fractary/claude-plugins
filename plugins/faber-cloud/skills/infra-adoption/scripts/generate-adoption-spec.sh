#!/bin/bash
# generate-adoption-spec.sh - Generate detailed, actionable faber-cloud adoption spec
#
# This script generates a comprehensive migration plan with:
# - Specific files to create (with full content)
# - Specific commands to convert (with before/after)
# - Specific hooks to configure (with actual skill code)
# - Complete configuration ready to use
#
# The output is a markdown spec that can be handed to another session for implementation.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function: Log with color
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
  echo -e "${GREEN}[✓]${NC} $*" >&2
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
  echo -e "${RED}[✗]${NC} $*" >&2
}

# Function: Display usage
usage() {
  cat <<EOF
Usage: generate-adoption-spec.sh <project_root> <output_dir> <spec_output_file>

Generate detailed, actionable faber-cloud adoption specification.

Arguments:
  project_root        Root directory of project being adopted
  output_dir          Directory containing discovery reports
  spec_output_file    Output path for adoption spec (markdown)

Required Discovery Reports (in output_dir):
  - discovery-terraform.json
  - discovery-aws.json
  - discovery-custom-agents.json
  - faber-cloud.json (generated config)

Output:
  Comprehensive adoption spec with:
  - Complete file contents ready to create
  - Before/after for commands to convert
  - Full skill implementations
  - Complete faber-cloud configuration
  - Step-by-step testing instructions
  - Rollback procedures

Examples:
  generate-adoption-spec.sh . .fractary/adoption adoption-spec.md
  generate-adoption-spec.sh /path/to/project .fractary/adoption /specs/adoption-plan.md

Exit Codes:
  0 - Spec generated successfully
  1 - Error during generation
  2 - Invalid arguments or missing reports
EOF
  exit 2
}

# Validate arguments
if [ $# -lt 3 ]; then
  usage
fi

PROJECT_ROOT="$1"
OUTPUT_DIR="$2"
SPEC_OUTPUT="$3"

# Validate reports exist
TF_REPORT="$OUTPUT_DIR/discovery-terraform.json"
AWS_REPORT="$OUTPUT_DIR/discovery-aws.json"
AGENTS_REPORT="$OUTPUT_DIR/discovery-custom-agents.json"
CONFIG_FILE="$OUTPUT_DIR/faber-cloud.json"

if [ ! -f "$TF_REPORT" ]; then
  log_error "Terraform discovery report not found: $TF_REPORT"
  exit 2
fi

if [ ! -f "$AWS_REPORT" ]; then
  log_error "AWS discovery report not found: $AWS_REPORT"
  exit 2
fi

if [ ! -f "$AGENTS_REPORT" ]; then
  log_error "Custom agents discovery report not found: $AGENTS_REPORT"
  exit 2
fi

if [ ! -f "$CONFIG_FILE" ]; then
  log_error "Generated config not found: $CONFIG_FILE"
  exit 2
fi

log_info "Generating detailed adoption spec..."
log_info "Project: $PROJECT_ROOT"
log_info "Reports: $OUTPUT_DIR"
log_info "Output: $SPEC_OUTPUT"

# Extract project information
PROJECT_NAME=$(jq -r '.project.name // "unknown"' "$CONFIG_FILE")
TERRAFORM_DIR=$(jq -r '.summary.primary_directory // "./terraform"' "$TF_REPORT")
TF_STRUCTURE=$(jq -r '.summary.primary_structure // "flat"' "$TF_REPORT")
RESOURCE_COUNT=$(jq -r '.summary.total_resources // 0' "$TF_REPORT")
BACKEND_TYPE=$(jq -r '.terraform_directories[0].backend.type // "local"' "$TF_REPORT")

# Extract AWS info
ENV_COUNT=$(jq -r '.summary.project_related_profiles // 0' "$AWS_REPORT")
ENVIRONMENTS=$(jq -r '.summary.environments_detected | join(", ")' "$AWS_REPORT")

# Extract custom agents info
SCRIPTS_COUNT=$(jq -r '.summary.total_files // 0' "$AGENTS_REPORT")

# Complexity assessment (same logic as generate-migration-report.sh)
COMPLEXITY_SCORE=0

# Structure complexity
case "$TF_STRUCTURE" in
  flat) COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 1)) ;;
  modular) COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 3)) ;;
  multi-environment) COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 5)) ;;
esac

# Resource count
if [ "$RESOURCE_COUNT" -gt 50 ]; then
  COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 3))
elif [ "$RESOURCE_COUNT" -gt 20 ]; then
  COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 2))
elif [ "$RESOURCE_COUNT" -gt 10 ]; then
  COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 1))
fi

# Environments
if [ "$ENV_COUNT" -gt 3 ]; then
  COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 2))
elif [ "$ENV_COUNT" -gt 1 ]; then
  COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 1))
fi

# Scripts
if [ "$SCRIPTS_COUNT" -gt 10 ]; then
  COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 3))
elif [ "$SCRIPTS_COUNT" -gt 5 ]; then
  COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 2))
elif [ "$SCRIPTS_COUNT" -gt 0 ]; then
  COMPLEXITY_SCORE=$((COMPLEXITY_SCORE + 1))
fi

# Determine complexity level
if [ "$COMPLEXITY_SCORE" -le 3 ]; then
  COMPLEXITY="SIMPLE"
  ESTIMATED_HOURS=4
elif [ "$COMPLEXITY_SCORE" -le 7 ]; then
  COMPLEXITY="MODERATE"
  ESTIMATED_HOURS=12
else
  COMPLEXITY="COMPLEX"
  ESTIMATED_HOURS=24
fi

DATE=$(date -u +"%Y-%m-%d")

log_info "Project Name: $PROJECT_NAME"
log_info "Complexity: $COMPLEXITY (score: $COMPLEXITY_SCORE)"
log_info "Estimated Hours: $ESTIMATED_HOURS"

# Generate spec content
# This is a simplified version - the full implementation would use mustache/handlebars
# or similar templating, but for now we'll generate markdown directly

cat > "$SPEC_OUTPUT" <<EOF
---
spec_id: adoption-${PROJECT_NAME}-${DATE}
project: ${PROJECT_NAME}
type: faber-cloud-adoption
status: draft
created: ${DATE}
complexity: ${COMPLEXITY}
estimated_hours: ${ESTIMATED_HOURS}
---

# Faber-Cloud Adoption Plan: ${PROJECT_NAME}

**Project**: ${PROJECT_NAME}
**Generated**: ${DATE}
**Complexity**: ${COMPLEXITY}
**Estimated Time**: ${ESTIMATED_HOURS} hours

---

## Executive Summary

This document provides a detailed, step-by-step migration plan to adopt faber-cloud infrastructure lifecycle management for the ${PROJECT_NAME} project.

**Current State**: Manual/custom infrastructure deployment
**Target State**: Standardized faber-cloud deployment with project-specific hooks and documentation
**Migration Approach**: Incremental migration with testing at each phase

### Key Metrics

| Metric | Value |
|--------|-------|
| **Infrastructure Structure** | ${TF_STRUCTURE} |
| **Terraform Resources** | ${RESOURCE_COUNT} |
| **Environments** | ${ENV_COUNT} (${ENVIRONMENTS}) |
| **Custom Scripts to Migrate** | ${SCRIPTS_COUNT} |
| **Estimated Migration Time** | ${ESTIMATED_HOURS} hours |
| **Complexity Level** | ${COMPLEXITY} |

---

## Phase 1: Project Documentation (2 hours)

Create structured documentation that faber-cloud will reference during deployments.

### Task 1.1: Create Architecture Documentation

**Create File**: \`docs/infrastructure/ARCHITECTURE.md\`

\`\`\`markdown
# Infrastructure Architecture

## Overview

${PROJECT_NAME} infrastructure managed by Terraform.

## Components

EOF

# Extract components from Terraform discovery
log_info "Extracting Terraform components..."

# Get unique resource types
RESOURCE_TYPES=$(jq -r '.terraform_directories[0].structure_analysis.resources[]? | split(".")[0]' "$TF_REPORT" 2>/dev/null | sort -u)

if [ -n "$RESOURCE_TYPES" ]; then
  cat >> "$SPEC_OUTPUT" <<EOF
Based on Terraform discovery, your infrastructure includes:

EOF

  while IFS= read -r resource_type; do
    [ -z "$resource_type" ] && continue

    # Count resources of this type
    count=$(jq -r "[.terraform_directories[0].structure_analysis.resources[]? | select(startswith(\"${resource_type}.\"))] | length" "$TF_REPORT" 2>/dev/null || echo "0")

    cat >> "$SPEC_OUTPUT" <<EOF
- **${resource_type}**: ${count} resource(s)
EOF
  done <<< "$RESOURCE_TYPES"
fi

cat >> "$SPEC_OUTPUT" <<'EOF'

## Architecture Decisions

### Infrastructure as Code
- **Tool**: Terraform
- **Structure**: Modular design with environment-specific variables
- **State**: Managed via Terraform state file

### Environment Strategy
- **Test**: Development and testing environment
- **Production**: Live production environment

## Data Flow

[Document how data flows through your infrastructure]

## Environment Differences

### Test Environment
- Resources are smaller/cheaper
- Less restrictive security for testing
- Can be destroyed and recreated

### Production Environment
- Production-sized resources
- Strict security policies
- Requires approval for changes
- Backups enabled

---

**How to complete this file:**
1. Review your Terraform files in `${TERRAFORM_DIR}`
2. Document each major component purpose
3. Explain why you chose specific AWS services
4. Include any architecture diagrams
5. Document dependencies between components
```

---

### Task 1.2: Create Deployment Standards

**Create File**: `docs/infrastructure/DEPLOYMENT-STANDARDS.md`

```markdown
# Deployment Standards for ${PROJECT_NAME}

## Pre-Deployment Requirements

1. **AWS Credentials**
   - Must use correct AWS profile for environment
   - Credentials must be valid and have required permissions

2. **Terraform Validation**
   - All Terraform files must pass \`terraform validate\`
   - No syntax errors allowed

3. **Environment Validation**
   - Terraform workspace must match target environment
   - Variable file must exist for environment
   - AWS profile must match environment

## Resource Naming Conventions

### Pattern
EOF

# Try to infer naming pattern from discovered resources
NAMING_PATTERN=$(jq -r '.terraform_directories[0].structure_analysis.resources[0]? // ""' "$TF_REPORT" 2>/dev/null)

if [ -n "$NAMING_PATTERN" ]; then
  cat >> "$SPEC_OUTPUT" <<EOF
Based on discovered resources: \`${PROJECT_NAME}-{resource}-{environment}\`

EOF
else
  cat >> "$SPEC_OUTPUT" <<EOF
\`{project}-{resource}-{environment}\`

EOF
fi

cat >> "$SPEC_OUTPUT" <<'EOF'
### Examples
- S3 bucket: `${PROJECT_NAME}-data-test`
- Lambda function: `${PROJECT_NAME}-processor-test`
- IAM role: `${PROJECT_NAME}-lambda-role-test`

## Environment-Specific Rules

### Test Environment
- **Auto-approve**: Allowed for terraform apply
- **Backups**: Not required before deployment
- **Approval workflow**: None required

### Production Environment
- **Auto-approve**: NEVER allowed
- **Backups**: REQUIRED before any destructive changes
- **Approval workflow**: Manual approval required

## Post-Deployment Validation

1. **Resource Health**
   - All resources must be in "Active" or "Available" state
   - No errors in CloudWatch logs

2. **Access Validation**
   - Verify permissions are correct
   - Test basic functionality

## Tags Required

All resources must have:
- `Environment`: test | prod
- `Project`: ${PROJECT_NAME}
- `ManagedBy`: faber-cloud

---

**How to complete this file:**
1. Review your current deployment process
2. Document any validation you currently do manually
3. Add project-specific requirements
4. Document naming conventions you follow
```

---

### Task 1.3: Create Naming Conventions

**Create File**: `docs/infrastructure/NAMING-CONVENTIONS.md`

```markdown
# Resource Naming Conventions for ${PROJECT_NAME}

## Pattern

\`{project}-{resource}-{environment}\`

## Components

- **project**: ${PROJECT_NAME}
- **resource**: Resource type or purpose (lowercase, hyphenated)
- **environment**: test | prod

## Examples by Resource Type

### S3 Buckets
- Test: \`${PROJECT_NAME}-data-test\`
- Prod: \`${PROJECT_NAME}-data-prod\`

### Lambda Functions
- Test: \`${PROJECT_NAME}-processor-test\`
- Prod: \`${PROJECT_NAME}-processor-prod\`

### IAM Roles
- Test: \`${PROJECT_NAME}-lambda-role-test\`
- Prod: \`${PROJECT_NAME}-lambda-role-prod\`

### Glue Jobs (if applicable)
- Test: \`${PROJECT_NAME}-etl-job-test\`
- Prod: \`${PROJECT_NAME}-etl-job-prod\`

## Tags

All resources must have:
\`\`\`
Environment = "test" | "prod"
Project = "${PROJECT_NAME}"
ManagedBy = "faber-cloud"
\`\`\`

---

**How to complete this file:**
1. Review your existing resources in AWS
2. Document the pattern you're already using
3. Add examples for each resource type you use
4. Document any exceptions to the pattern
```

---

### Task 1.4: Create Security Requirements (Optional)

**Create File**: `docs/infrastructure/SECURITY-REQUIREMENTS.md`

```markdown
# Security Requirements for ${PROJECT_NAME}

## Data Encryption

### S3 Buckets
- All buckets must use server-side encryption (SSE-S3 or SSE-KMS)
- Bucket policies must enforce encryption

### At-Rest
- All data stored must be encrypted

### In-Transit
- All data transfer must use TLS/HTTPS

## IAM Policies

- Follow principle of least privilege
- No wildcard (*) permissions in production
- Regular review and cleanup of unused policies

## Access Control

- Multi-factor authentication required for production access
- Separate credentials for test and production

## Compliance

[Document any compliance requirements: HIPAA, SOC2, etc.]

---

**How to complete this file:**
1. Document your security requirements
2. Add any compliance needs
3. Document encryption requirements
4. Add access control policies
```

---

EOF

# Continue with Phase 2: Commands
log_info "Generating Phase 2: Commands..."

cat >> "$SPEC_OUTPUT" <<'EOF'
## Phase 2: Convert Custom Commands (1 hour)

Convert your custom infrastructure commands to delegate to faber-cloud.

EOF

# Check for custom commands in discovery
COMMANDS_FOUND=$(jq -r '.files[]? | select(.path | contains("commands/")) | .path' "$AGENTS_REPORT" 2>/dev/null || echo "")

if [ -n "$COMMANDS_FOUND" ]; then
  COMMAND_NUM=1
  while IFS= read -r cmd_path; do
    [ -z "$cmd_path" ] && continue

    cmd_name=$(basename "$cmd_path" .md)

    cat >> "$SPEC_OUTPUT" <<EOF
### Task 2.${COMMAND_NUM}: Convert \`/${cmd_name}\` Command

**Current File**: \`${cmd_path}\`
**Current Approach**: Custom deployment logic

**Replace with**:

**File**: \`${cmd_path}\`

\`\`\`markdown
---
name: ${cmd_name}
description: Deploy infrastructure using faber-cloud with project-specific context
argument-hint: "[--env <environment>]"
---

# Deploy Infrastructure

Use the @agent-fractary-faber-cloud:infra-manager agent to deploy infrastructure.

**Project Context:**

Read and provide these project-specific documents to the agent:
- \\\`docs/infrastructure/ARCHITECTURE.md\\\` - Infrastructure design and components
- \\\`docs/infrastructure/DEPLOYMENT-STANDARDS.md\\\` - Deployment requirements and standards
- \\\`docs/infrastructure/NAMING-CONVENTIONS.md\\\` - Resource naming patterns

**Environment**: \\\${environment:-test}

**Request**: "Deploy ${PROJECT_NAME} infrastructure to \\\${environment} environment following our project standards documented above."

## What Happens

1. **Pre-deployment hooks execute** (validation, credential checks)
2. **Faber-cloud deploys infrastructure** (terraform init, plan, apply)
3. **Post-deployment hooks execute** (health checks, verification)

## Usage

\\\`\\\`\\\`bash
# Deploy to test
/${cmd_name} --env test

# Deploy to production (requires approval)
/${cmd_name} --env prod
\\\`\\\`\\\`
\`\`\`

**What Changed**:
- ❌ **Removed**: Custom deployment logic
- ✅ **Added**: Delegation to faber-cloud infra-manager
- ✅ **Preserved**: Project-specific context via documentation

**Testing**:
\`\`\`bash
# Test the converted command
/${cmd_name} --env test

# Expected: Delegates to faber-cloud with project context
\`\`\`

---

EOF

    COMMAND_NUM=$((COMMAND_NUM + 1))
  done <<< "$COMMANDS_FOUND"
else
  cat >> "$SPEC_OUTPUT" <<EOF
### No Existing Commands Found

You don't have custom commands to convert. Create a new deployment command:

**Create File**: \`.claude/commands/deploy.md\`

\`\`\`markdown
---
name: deploy
description: Deploy infrastructure using faber-cloud
argument-hint: "[--env <environment>]"
---

# Deploy Infrastructure

Use the @agent-fractary-faber-cloud:infra-manager agent to deploy infrastructure.

**Project Context:**

Read and provide these project-specific documents:
- \\\`docs/infrastructure/ARCHITECTURE.md\\\`
- \\\`docs/infrastructure/DEPLOYMENT-STANDARDS.md\\\`
- \\\`docs/infrastructure/NAMING-CONVENTIONS.md\\\`

**Environment**: \\\${environment:-test}

**Request**: "Deploy ${PROJECT_NAME} infrastructure to \\\${environment} environment."
\`\`\`

---

EOF
fi

# Phase 3: Skill Hooks
log_info "Generating Phase 3: Skill Hooks..."

cat >> "$SPEC_OUTPUT" <<'EOF'
## Phase 3: Create Skill Hooks (3 hours)

Convert your validation scripts to skill hooks that integrate with faber-cloud lifecycle.

EOF

# Check for validation scripts
VALIDATION_SCRIPTS=$(jq -r '.files[]? | select(.purposes[]? == "validate") | .path' "$AGENTS_REPORT" 2>/dev/null || echo "")

if [ -n "$VALIDATION_SCRIPTS" ]; then
  SKILL_NUM=1
  while IFS= read -r script_path; do
    [ -z "$script_path" ] && continue

    script_name=$(basename "$script_path" | sed 's/\.sh$//' | sed 's/^validate-//')
    skill_name="${script_name}-validator-deploy-pre"

    cat >> "$SPEC_OUTPUT" <<EOF
### Task 3.${SKILL_NUM}: Convert \`${script_path}\` to Skill Hook

**Current Script**: \`${script_path}\`
**Purpose**: Validation before deployment
**Lifecycle Hook Point**: pre-deploy

**Create Skill**:

**File**: \`.claude/skills/${skill_name}/SKILL.md\`

\`\`\`markdown
---
name: ${skill_name}
description: Validate ${script_name} before infrastructure deployment
tools: Read, Bash
---

# ${script_name} Validator

<CONTEXT>
You validate ${script_name} requirements before deploying infrastructure.
You receive WorkflowContext from faber-cloud containing environment and operation details.
</CONTEXT>

<CRITICAL_RULES>
**IMPORTANT:** Validation Failures Block Deployment
- If validation fails, return failure status
- Deployment will be blocked until issues resolved
- Provide clear error messages with remediation steps

**IMPORTANT:** Environment-Specific Validation
- Test environment: Validate test-specific requirements
- Prod environment: Validate production-specific requirements
- Use environment from WorkflowContext
</CRITICAL_RULES>

<INPUTS>
Receives WorkflowContext from faber-cloud:
\\\`\\\`\\\`json
{
  "environment": "test",
  "operation": "deploy",
  "project": "${PROJECT_NAME}",
  "terraform_dir": "${TERRAFORM_DIR}",
  "hook_type": "pre-deploy"
}
\\\`\\\`\\\`
</INPUTS>

<WORKFLOW>
## Step 1: Parse WorkflowContext

Read environment from WorkflowContext.

## Step 2: Run Validation

Use your existing validation script:

\\\`\\\`\\\`bash
# Run existing validation logic
bash ${script_path} \\\${environment}
validation_result=\$?

if [ \$validation_result -ne 0 ]; then
  echo "ERROR: Validation failed"
  exit 1
fi
\\\`\\\`\\\`

## Step 3: Return WorkflowResult

Return validation status:

**Success**:
\\\`\\\`\\\`json
{
  "status": "success",
  "message": "${script_name} validation passed",
  "details": {
    "environment": "\\\${environment}",
    "validation_type": "${script_name}"
  }
}
\\\`\\\`\\\`

**Failure**:
\\\`\\\`\\\`json
{
  "status": "failure",
  "message": "${script_name} validation failed",
  "details": {
    "environment": "\\\${environment}",
    "errors": ["list of errors"],
    "remediation": "Steps to fix issues"
  }
}
\\\`\\\`\\\`
</WORKFLOW>

<COMPLETION_CRITERIA>
✅ WorkflowContext parsed
✅ Validation executed
✅ WorkflowResult returned
</COMPLETION_CRITERIA>

<OUTPUTS>
Return WorkflowResult in JSON format.
</OUTPUTS>
\`\`\`

**Testing**:
\`\`\`bash
# Test skill independently
export FABER_CLOUD_ENV="test"
export FABER_CLOUD_OPERATION="deploy"
/skill ${skill_name}

# Expected: Validation runs and returns success/failure
\`\`\`

---

EOF

    SKILL_NUM=$((SKILL_NUM + 1))
  done <<< "$VALIDATION_SCRIPTS"
else
  cat >> "$SPEC_OUTPUT" <<'EOF'
### No Validation Scripts Found

Your project doesn't have custom validation scripts. You can skip Phase 3 or add validation hooks later.

**Optional Hooks to Consider**:
- Pre-deploy data validation
- Post-deploy health checks
- Pre-destroy backups
- Post-deploy smoke tests

---

EOF
fi

# Phase 4: Configuration
log_info "Generating Phase 4: Configuration..."

cat >> "$SPEC_OUTPUT" <<EOF
## Phase 4: Configure Faber-Cloud (1 hour)

Create the faber-cloud configuration.

### Task 4.1: Install Generated Configuration

The adoption process generated a configuration file. Install it:

\`\`\`bash
# Create config directory
mkdir -p .fractary/plugins/faber-cloud/config

# Copy generated configuration
cp ${OUTPUT_DIR}/faber-cloud.json \\
   .fractary/plugins/faber-cloud/config/
\`\`\`

### Task 4.2: Review Configuration

**File**: \`.fractary/plugins/faber-cloud/config/faber-cloud.json\`

Review the generated configuration:

\`\`\`json
$(cat "$CONFIG_FILE")
\`\`\`

### Task 4.3: Customize Configuration

Update the configuration:

1. **Add skill hooks**:
   - Add your skills from Phase 3 to \`hooks.pre-deploy\`
   - Add post-deployment verification hooks to \`hooks.post-deploy\`

2. **Verify AWS profiles**:
   - Ensure profile names match your \`~/.aws/config\`
   - Test profiles work: \`aws sts get-caller-identity --profile {profile-name}\`

3. **Verify environment settings**:
   - Check terraform workspace names
   - Check var file names
   - Verify auto-approve settings

### Task 4.4: Validate Configuration

\`\`\`bash
# Validate the configuration
bash plugins/faber-cloud/skills/infra-adoption/scripts/validate-generated-config.sh \\
  .fractary/plugins/faber-cloud/config/faber-cloud.json

# Expected: ✅ Configuration valid
\`\`\`

---

## Phase 5: Test Integration (2 hours)

Test the complete migration before production.

### Task 5.1: Test Individual Skill Hooks

EOF

# List skills to test
if [ -n "$VALIDATION_SCRIPTS" ]; then
  while IFS= read -r script_path; do
    [ -z "$script_path" ] && continue
    script_name=$(basename "$script_path" | sed 's/\.sh$//' | sed 's/^validate-//')
    skill_name="${script_name}-validator-deploy-pre"

    cat >> "$SPEC_OUTPUT" <<EOF
\`\`\`bash
# Test ${skill_name}
export FABER_CLOUD_ENV="test"
export FABER_CLOUD_OPERATION="deploy"
/skill ${skill_name}

# Expected: Skill validates and returns success
\`\`\`

EOF
  done <<< "$VALIDATION_SCRIPTS"
else
  cat >> "$SPEC_OUTPUT" <<'EOF'
No skill hooks to test (none created in Phase 3).

EOF
fi

cat >> "$SPEC_OUTPUT" <<'EOF'
---

### Task 5.2: Test Deploy Command

```bash
# Test deploy command delegates to faber-cloud
/deploy --env test

# Expected:
# 1. Command reads project documentation
# 2. Command invokes faber-cloud infra-manager
# 3. Faber-cloud receives project context
```

---

### Task 5.3: Test Full Deployment (Test Environment)

**⚠️ IMPORTANT**: This will deploy to your test environment.

```bash
# Deploy to test
/deploy --env test
```

**Expected Flow**:
1. ✅ Pre-plan hooks (AWS credential validation)
2. ✅ Terraform plan
3. ✅ Approval (auto for test)
4. ✅ Pre-deploy hooks (validation scripts)
5. ✅ Terraform apply
6. ✅ Post-deploy hooks (health checks)
7. ✅ Deployment complete

**Verification**:
```bash
# List deployed resources
/fractary-faber-cloud:list --env test

# Verify resources in AWS
aws s3 ls --profile ${PROJECT_NAME}-test-deploy
```

---

EOF

# Phase 6: Production
log_info "Generating Phase 6: Production..."

cat >> "$SPEC_OUTPUT" <<EOF
## Phase 6: Production Migration (2 hours)

Deploy to production using faber-cloud.

### Task 6.1: Validate Production

\`\`\`bash
# Validate production config
/fractary-faber-cloud:validate --env prod
\`\`\`

---

### Task 6.2: Review Production Plan

\`\`\`bash
# Generate plan (don't apply)
/fractary-faber-cloud:deploy-plan --env prod
\`\`\`

**Review**:
- [ ] Same resources as current production
- [ ] No unexpected deletions
- [ ] Configuration matches current state

---

### Task 6.3: Backup Production State

\`\`\`bash
# Backup terraform state
cp ${TERRAFORM_DIR}/terraform.tfstate \\
   ${TERRAFORM_DIR}/terraform.tfstate.pre-faber-cloud-${DATE}
\`\`\`

---

### Task 6.4: Deploy to Production

\`\`\`bash
# Deploy to production
/deploy --env prod
\`\`\`

**Post-Deployment**:
\`\`\`bash
# Verify resources
/fractary-faber-cloud:list --env prod

# Check application functionality
# [Add your smoke tests here]
\`\`\`

---

## Phase 7: Finalization (1 hour)

### Task 7.1: Update README

Add to \`README.md\`:

\`\`\`markdown
## Infrastructure Management

This project uses faber-cloud for infrastructure lifecycle management.

### Deploy

\\\`\\\`\\\`bash
/deploy --env test    # Test environment
/deploy --env prod    # Production (requires approval)
\\\`\\\`\\\`

### Documentation

- Architecture: \\\`docs/infrastructure/ARCHITECTURE.md\\\`
- Standards: \\\`docs/infrastructure/DEPLOYMENT-STANDARDS.md\\\`
- Naming: \\\`docs/infrastructure/NAMING-CONVENTIONS.md\\\`
\`\`\`

---

## Rollback Plan

### If Migration Fails

1. **Restore old commands**:
   \`\`\`bash
   # Use old deployment process
   \`\`\`

2. **Disable faber-cloud config**:
   \`\`\`bash
   mv .fractary/plugins/faber-cloud/config/faber-cloud.json \\
      .fractary/plugins/faber-cloud/config/faber-cloud.json.disabled
   \`\`\`

### If Production Deployment Has Issues

1. **Restore terraform state**:
   \`\`\`bash
   cp ${TERRAFORM_DIR}/terraform.tfstate.pre-faber-cloud-${DATE} \\
      ${TERRAFORM_DIR}/terraform.tfstate
   \`\`\`

2. **Review changes**:
   \`\`\`bash
   terraform plan -var-file=prod.tfvars
   \`\`\`

---

## Success Criteria

- [ ] \`/deploy --env test\` deploys infrastructure successfully
- [ ] Deployed resources match previous infrastructure
- [ ] Validation hooks execute correctly
- [ ] \`/deploy --env prod\` works in production
- [ ] Team can use new workflow
- [ ] Documentation complete

---

## Timeline

| Phase | Time | Status |
|-------|------|--------|
| Phase 1: Documentation | 2h | ⏳ |
| Phase 2: Commands | 1h | ⏳ |
| Phase 3: Skill Hooks | 3h | ⏳ |
| Phase 4: Configuration | 1h | ⏳ |
| Phase 5: Testing | 2h | ⏳ |
| Phase 6: Production | 2h | ⏳ |
| Phase 7: Finalization | 1h | ⏳ |
| **Total** | **${ESTIMATED_HOURS}h** | |

---

## Appendix: Discovery Summary

### Terraform Discovery
\`\`\`json
$(jq '.summary' "$TF_REPORT")
\`\`\`

### AWS Discovery
\`\`\`json
$(jq '.summary' "$AWS_REPORT")
\`\`\`

### Custom Scripts Discovery
\`\`\`json
$(jq '.summary' "$AGENTS_REPORT")
\`\`\`

---

**End of Adoption Spec**

*This spec provides complete step-by-step migration guidance with all code ready to use.*
*Hand this to another Claude Code session for implementation.*
EOF

log_success "Adoption spec generated successfully: $SPEC_OUTPUT"

exit 0
