# SPEC-0030-01: faber-cloud Infrastructure Adoption & Migration Features

**Issue**: #30
**Phase**: 1 (faber-cloud Enhancement)
**Dependencies**: None
**Status**: Draft
**Created**: 2025-01-15

## Overview

Enhance the fractary-faber-cloud plugin with capabilities to adopt and manage existing infrastructure that was previously managed by custom agents or manual processes. This includes infrastructure discovery, configuration generation, pre/post-deployment hooks, and enhanced environment validation to prevent common deployment errors.

**Goal**: Make faber-cloud the standard for infrastructure management by providing smooth migration paths from custom implementations, reducing the barrier to adoption for projects with existing infrastructure.

## Background

Many projects have already deployed infrastructure using:
- Custom infrastructure manager agents
- Manual Terraform workflows
- Other IaC tools

Currently, faber-cloud assumes greenfield deployments. Adopting existing infrastructure requires:
- Manual configuration file creation
- Understanding faber-cloud's expectations
- Trial-and-error to match existing patterns
- No guidance on migration from custom agents

This creates a high barrier to adoption and risks deployment errors during transition.

## Requirements

### Functional Requirements

#### 1. Infrastructure Discovery & Adoption

**FR-1.1**: Detect and analyze existing Terraform infrastructure
- Discover Terraform directory structure (flat, modular, multi-environment)
- Analyze Terraform state files (local or remote backends)
- Identify managed resources and their types
- Detect environment separation patterns

**FR-1.2**: Analyze existing AWS configuration
- Discover AWS CLI profiles
- Detect region configuration
- Identify credential sources (profiles, environment, IAM roles)
- Map profiles to environments (test, prod, etc.)

**FR-1.3**: Detect custom infrastructure management patterns
- Identify custom agents in `.claude/`, `.fractary/`, etc.
- Analyze custom scripts and their purposes
- Map custom script capabilities to faber-cloud features
- Identify gaps requiring hooks or custom preservation

**FR-1.4**: Generate faber-cloud configuration automatically
- Create valid `faber-cloud.json` from discovered infrastructure
- Map Terraform directory patterns to configuration
- Configure AWS profiles based on existing setup
- Infer resource naming patterns from existing resources
- Set appropriate environment configurations

**FR-1.5**: Produce migration report
- List all discovered resources and their states
- Identify custom scripts and their faber-cloud equivalents
- Highlight features needing manual configuration
- Provide migration checklist with steps
- Estimate migration complexity and timeline

#### 2. Pre/Post-Deployment Hook System

**FR-2.1**: Support hook configuration
- Define hooks in `faber-cloud.json` configuration
- Support multiple hook types: `pre-plan`, `post-plan`, `pre-deploy`, `post-deploy`, `pre-destroy`, `post-destroy`
- Allow per-environment hook overrides
- Support both commands and script file paths

**FR-2.2**: Execute hooks at appropriate lifecycle points
- Execute `pre-plan` hooks before `terraform plan`
- Execute `post-plan` hooks after successful plan generation
- Execute `pre-deploy` hooks before `terraform apply`
- Execute `post-deploy` hooks after successful deployment
- Execute `pre-destroy` and `post-destroy` for teardown operations

**FR-2.3**: Hook execution features
- Pass environment context to hooks (env name, terraform dir, etc.)
- Capture and log hook output
- Fail deployment if critical hooks fail
- Support optional hooks that don't block on failure
- Set timeout for hook execution (configurable, default 5 minutes)

**FR-2.4**: Common hook use cases
- Pre-deploy: Lambda builds, asset compilation, dependency checks
- Post-deploy: Smoke tests, health checks, notification webhooks
- Pre-plan: Credential validation, prerequisite checks
- Post-plan: Cost estimation, security scanning, approval workflows

#### 3. Enhanced Environment Validation

**FR-3.1**: Prevent multi-environment deployment bugs
- Detect environment from multiple sources (tfvars file, workspace, config)
- Validate all environment indicators match
- Prevent deploying test resources to prod or vice versa
- Warn if environment mismatch detected

**FR-3.2**: Resource naming validation
- Validate resources follow configured naming pattern
- Check for environment suffix consistency
- Warn about resources with ambiguous names
- Prevent accidental cross-environment resource references

**FR-3.3**: State file validation
- Verify Terraform state matches intended environment
- Detect if state has resources from different environments
- Warn about unexpected resource counts
- Check state backend configuration matches environment

**FR-3.4**: Production safety enhancements
- Require explicit environment confirmation for prod
- Additional validation steps for production deployments
- Cost threshold validation (fail if exceeds limit)
- Require manual approval for destructive changes in prod

#### 4. Migration Workflow Command

**FR-4.1**: New `/fractary-faber-cloud:adopt` command
- Interactive wizard for infrastructure adoption
- Guides user through discovery and configuration
- Validates discovered infrastructure before proceeding
- Generates migration checklist

**FR-4.2**: Migration phases
- **Phase 1: Discovery** - Analyze existing infrastructure
- **Phase 2: Configuration** - Generate and customize faber-cloud.json
- **Phase 3: Validation** - Read-only testing (audit, plan)
- **Phase 4: Adoption** - First managed deployment
- **Phase 5: Verification** - Confirm adoption success

**FR-4.3**: Rollback and safety
- Provide rollback instructions at each phase
- Never modify Terraform state during adoption
- Work with existing state (no re-imports needed)
- Maintain backup of custom agents before archival

### Non-Functional Requirements

#### NFR-1: Backward Compatibility
- Existing faber-cloud configurations continue working
- No breaking changes to current commands or workflows
- Hook system is optional (empty hooks = no change in behavior)

#### NFR-2: Performance
- Discovery process completes in <2 minutes for typical projects
- Hook execution doesn't add >10% to deployment time
- Validation checks add <30 seconds to deployment workflow

#### NFR-3: Reliability
- Discovery never modifies infrastructure or state
- Failed hooks provide clear error messages
- Migration process can be restarted at any phase
- All operations are idempotent

#### NFR-4: Documentation
- Comprehensive migration guide
- Hook system documentation with examples
- Configuration templates for common patterns
- Troubleshooting guide for migration issues

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  /fractary-faber-cloud:adopt                 │
│                     (New Command)                            │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   cloud-director Agent                       │
│              (Routes to infra-adoption)                      │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  infra-adoption Skill                        │
│                    (New Skill)                               │
│                                                              │
│  Capabilities:                                               │
│  • Terraform structure discovery                            │
│  • AWS profile detection                                    │
│  • Custom agent analysis                                    │
│  • Configuration generation                                 │
│  • Migration report creation                                │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Discovery Scripts (Shell)                       │
│                                                              │
│  • discover-terraform.sh - Analyze TF structure             │
│  • discover-aws-profiles.sh - Find AWS configs              │
│  • discover-custom-agents.sh - Analyze custom infra code    │
│  • generate-config.sh - Create faber-cloud.json             │
│  • generate-migration-report.sh - Create checklist          │
└─────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────┐
│            Enhanced infra-deployer Skill                     │
│         (Modified for Hooks & Validation)                    │
│                                                              │
│  Workflow:                                                   │
│  1. Load configuration (including hooks)                    │
│  2. Enhanced environment validation                         │
│  3. Execute pre-plan hooks                                  │
│  4. Run terraform plan                                      │
│  5. Execute post-plan hooks                                 │
│  6. Environment/cost/security validation                    │
│  7. Request approval (if needed)                            │
│  8. Execute pre-deploy hooks                                │
│  9. Run terraform apply                                     │
│  10. Execute post-deploy hooks                              │
│  11. Verify deployment                                      │
│  12. Update resource registry                               │
└─────────────────────────────────────────────────────────────┘
```

### Hook System Architecture

#### Configuration Schema

```json
{
  "hooks": {
    "pre-plan": [
      {
        "name": "validate-prerequisites",
        "command": "bash ./scripts/validate-prereqs.sh",
        "critical": true,
        "timeout": 60
      }
    ],
    "post-plan": [
      {
        "name": "cost-check",
        "command": "bash ./scripts/check-cost.sh",
        "critical": false,
        "timeout": 30
      }
    ],
    "pre-deploy": [
      {
        "name": "build-lambda",
        "command": "bash .claude/skills/custom/scripts/build-lambda.sh",
        "critical": true,
        "timeout": 300,
        "environments": ["test", "prod"]
      },
      {
        "name": "notify-deployment-start",
        "command": "curl -X POST $SLACK_WEBHOOK -d '{\"text\":\"Deployment starting\"}'",
        "critical": false,
        "timeout": 10,
        "environments": ["prod"]
      }
    ],
    "post-deploy": [
      {
        "name": "smoke-test",
        "command": "bash ./scripts/smoke-test.sh",
        "critical": true,
        "timeout": 120
      },
      {
        "name": "notify-deployment-complete",
        "command": "curl -X POST $SLACK_WEBHOOK -d '{\"text\":\"Deployment complete\"}'",
        "critical": false,
        "timeout": 10
      }
    ],
    "pre-destroy": [
      {
        "name": "backup-data",
        "command": "bash ./scripts/backup-prod-data.sh",
        "critical": true,
        "timeout": 600,
        "environments": ["prod"]
      }
    ],
    "post-destroy": [
      {
        "name": "confirm-cleanup",
        "command": "bash ./scripts/verify-cleanup.sh",
        "critical": false,
        "timeout": 60
      }
    ]
  }
}
```

#### Hook Execution Context

Hooks receive environment variables:
- `FABER_CLOUD_ENV` - Environment name (test, prod, etc.)
- `FABER_CLOUD_TERRAFORM_DIR` - Terraform working directory
- `FABER_CLOUD_PROJECT` - Project name
- `FABER_CLOUD_SUBSYSTEM` - Subsystem name
- `FABER_CLOUD_OPERATION` - Operation type (plan, deploy, destroy)
- `FABER_CLOUD_HOOK_TYPE` - Hook type (pre-plan, post-deploy, etc.)
- `AWS_PROFILE` - Active AWS profile for this environment

#### Hook Execution Flow

```bash
# Example: execute-hooks.sh script

HOOK_TYPE=$1  # pre-plan, post-plan, pre-deploy, post-deploy, pre-destroy, post-destroy
ENV_NAME=$2
TERRAFORM_DIR=$3

# Load hooks from configuration
HOOKS=$(jq -r ".hooks[\"$HOOK_TYPE\"][]?" "$CONFIG_FILE")

# Execute each hook
for hook in $HOOKS; do
  HOOK_NAME=$(echo "$hook" | jq -r '.name')
  HOOK_COMMAND=$(echo "$hook" | jq -r '.command')
  HOOK_CRITICAL=$(echo "$hook" | jq -r '.critical // true')
  HOOK_TIMEOUT=$(echo "$hook" | jq -r '.timeout // 300')
  HOOK_ENVS=$(echo "$hook" | jq -r '.environments[]? // empty')

  # Check if hook applies to this environment
  if [ -n "$HOOK_ENVS" ] && ! echo "$HOOK_ENVS" | grep -q "$ENV_NAME"; then
    echo "Skipping hook '$HOOK_NAME' (not configured for $ENV_NAME)"
    continue
  fi

  echo "Executing hook: $HOOK_NAME ($HOOK_TYPE)"

  # Set environment context
  export FABER_CLOUD_ENV="$ENV_NAME"
  export FABER_CLOUD_TERRAFORM_DIR="$TERRAFORM_DIR"
  export FABER_CLOUD_HOOK_TYPE="$HOOK_TYPE"

  # Execute with timeout
  timeout "$HOOK_TIMEOUT" bash -c "$HOOK_COMMAND"
  EXIT_CODE=$?

  if [ $EXIT_CODE -ne 0 ]; then
    if [ "$HOOK_CRITICAL" = "true" ]; then
      echo "ERROR: Critical hook '$HOOK_NAME' failed with exit code $EXIT_CODE"
      exit $EXIT_CODE
    else
      echo "WARNING: Optional hook '$HOOK_NAME' failed with exit code $EXIT_CODE (continuing)"
    fi
  else
    echo "Hook '$HOOK_NAME' completed successfully"
  fi
done
```

### Enhanced Environment Validation

#### Validation Script: `enhanced-validate-plan.sh`

```bash
#!/bin/bash
# Enhanced environment validation with multi-source detection

TERRAFORM_DIR=$1
ENVIRONMENT=$2
PLAN_FILE=$3

# 1. Detect environment from multiple sources
DETECTED_ENV_TFVARS=""
DETECTED_ENV_WORKSPACE=""
DETECTED_ENV_STATE=""

# Check tfvars file name
TFVARS_FILE=$(find "$TERRAFORM_DIR" -name "*.tfvars" | grep -o '[^/]*\.tfvars$')
if [[ "$TFVARS_FILE" =~ ^(test|prod|staging)\.tfvars$ ]]; then
  DETECTED_ENV_TFVARS="${BASH_REMATCH[1]}"
fi

# Check Terraform workspace
DETECTED_ENV_WORKSPACE=$(terraform workspace show 2>/dev/null)

# Check state file for environment indicators
if [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
  # Look for environment tags or name patterns in resources
  DETECTED_ENV_STATE=$(jq -r '.resources[].instances[].attributes.tags.Environment // .resources[].instances[].attributes.name' "$TERRAFORM_DIR/terraform.tfstate" 2>/dev/null | grep -oE '(test|prod|staging)' | head -1)
fi

# 2. Validate all environment indicators match
MISMATCHES=0

if [ -n "$DETECTED_ENV_TFVARS" ] && [ "$DETECTED_ENV_TFVARS" != "$ENVIRONMENT" ]; then
  echo "ERROR: Environment mismatch - tfvars indicates '$DETECTED_ENV_TFVARS' but deploying to '$ENVIRONMENT'"
  MISMATCHES=$((MISMATCHES + 1))
fi

if [ -n "$DETECTED_ENV_WORKSPACE" ] && [ "$DETECTED_ENV_WORKSPACE" != "$ENVIRONMENT" ]; then
  echo "ERROR: Environment mismatch - Terraform workspace is '$DETECTED_ENV_WORKSPACE' but deploying to '$ENVIRONMENT'"
  MISMATCHES=$((MISMATCHES + 1))
fi

if [ -n "$DETECTED_ENV_STATE" ] && [ "$DETECTED_ENV_STATE" != "$ENVIRONMENT" ]; then
  echo "WARNING: State file contains resources tagged for '$DETECTED_ENV_STATE' but deploying to '$ENVIRONMENT'"
fi

# 3. Check resource naming patterns in plan
PLAN_JSON="$PLAN_FILE.json"
terraform show -json "$PLAN_FILE" > "$PLAN_JSON"

WRONG_ENV_RESOURCES=$(jq -r '.resource_changes[]? | select(.change.actions[] | contains("create") or contains("update")) | select(.address | contains("'$ENVIRONMENT'") | not) | .address' "$PLAN_JSON" 2>/dev/null)

if [ -n "$WRONG_ENV_RESOURCES" ]; then
  echo "WARNING: Found resources without '$ENVIRONMENT' in name:"
  echo "$WRONG_ENV_RESOURCES"
fi

# 4. Production-specific validation
if [ "$ENVIRONMENT" = "prod" ]; then
  echo "Production deployment detected - performing additional validation..."

  # Check for destructive changes
  DESTROY_COUNT=$(jq '[.resource_changes[]? | select(.change.actions[] | contains("delete"))] | length' "$PLAN_JSON")

  if [ "$DESTROY_COUNT" -gt 0 ]; then
    echo "WARNING: This deployment will DESTROY $DESTROY_COUNT resource(s) in PRODUCTION"
    echo "Please review carefully before proceeding."
  fi

  # Check for recreate (replace) changes
  REPLACE_COUNT=$(jq '[.resource_changes[]? | select(.change.actions[] | contains("replace"))] | length' "$PLAN_JSON")

  if [ "$REPLACE_COUNT" -gt 0 ]; then
    echo "WARNING: This deployment will REPLACE $REPLACE_COUNT resource(s) in PRODUCTION"
    echo "Please review carefully before proceeding."
  fi
fi

# Exit with error if critical mismatches found
if [ $MISMATCHES -gt 0 ]; then
  echo "VALIDATION FAILED: Environment mismatch detected"
  exit 1
fi

echo "Environment validation passed"
exit 0
```

### Infrastructure Discovery & Adoption

#### New Skill: `infra-adoption`

**Location**: `plugins/faber-cloud/skills/infra-adoption/`

**Purpose**: Discover existing infrastructure and generate faber-cloud configuration

**Workflow**:

```markdown
<WORKFLOW>

## Step 1: Discover Terraform Structure

Execute: `scripts/discover-terraform.sh [project-root]`

Detects:
- Terraform directory location (./terraform, ./infrastructure/terraform, ./tf, etc.)
- Structure type (flat, modular, multi-environment)
- Terraform version
- Backend configuration (local, S3, remote)
- Variable file patterns (*.tfvars, environment-specific)
- Module usage and dependencies

Outputs: `discovery-report-terraform.json`

## Step 2: Discover AWS Configuration

Execute: `scripts/discover-aws-profiles.sh`

Detects:
- AWS CLI profiles from ~/.aws/config
- Profiles with project-related names
- Default region per profile
- Credential sources (static, SSO, IAM role)
- Profile naming patterns (env suffixes, project prefixes)

Outputs: `discovery-report-aws.json`

## Step 3: Analyze Custom Infrastructure Agents

Execute: `scripts/discover-custom-agents.sh [project-root]`

Detects:
- Custom agent files in .claude/, .fractary/
- Custom skill directories and scripts
- Script purposes (deploy, audit, validate, etc.)
- Version control status (committed vs local)
- Dependencies and requirements

Outputs: `discovery-report-custom-agents.json`

## Step 4: Generate faber-cloud Configuration

Execute: `scripts/generate-config.sh [discovery-reports-dir]`

Process:
1. Analyze all discovery reports
2. Map Terraform structure to faber-cloud.json
3. Configure handler settings (AWS region, profiles)
4. Infer resource naming patterns from existing resources
5. Set environment configurations
6. Generate hooks for scripts needing preservation
7. Validate generated configuration

Outputs: `.fractary/plugins/faber-cloud/config/faber-cloud.json`

## Step 5: Generate Migration Report

Execute: `scripts/generate-migration-report.sh [discovery-reports-dir] [generated-config]`

Creates comprehensive migration report with:
- Infrastructure summary (resource counts, types, costs)
- Custom script mapping (script → faber-cloud feature)
- Configuration review (what was auto-configured)
- Migration checklist (steps to complete migration)
- Risk assessment (complexity, timeline estimate)
- Rollback procedures

Outputs: `MIGRATION-REPORT.md`

## Step 6: Present Findings to User

Display:
- Summary of discovered infrastructure
- Generated configuration (with explanation)
- Migration report highlights
- Next steps and recommendations

Ask user:
- Review generated faber-cloud.json - any adjustments needed?
- Review migration checklist - ready to proceed?
- Confirm read-only testing phase can begin

</WORKFLOW>
```

#### Discovery Scripts

**`discover-terraform.sh`**
```bash
#!/bin/bash
# Discover Terraform infrastructure structure

PROJECT_ROOT=$1
OUTPUT_FILE="discovery-report-terraform.json"

# Find Terraform directories
TF_DIRS=$(find "$PROJECT_ROOT" -type f -name "*.tf" -exec dirname {} \; | sort -u)

# Analyze each directory
for TF_DIR in $TF_DIRS; do
  # Detect structure type
  if [ -d "$TF_DIR/modules" ]; then
    STRUCTURE="modular"
  elif [ -d "$TF_DIR/environments" ]; then
    STRUCTURE="multi-environment"
  else
    STRUCTURE="flat"
  fi

  # Check for state backend
  BACKEND=$(grep -r "backend" "$TF_DIR"/*.tf 2>/dev/null | grep -oE '"(s3|local|remote)"' | head -1 | tr -d '"')

  # Find tfvars files
  TFVARS_FILES=$(find "$TF_DIR" -name "*.tfvars" -o -name "*.tfvars.json")

  # Detect Terraform version
  TF_VERSION=$(grep -r "required_version" "$TF_DIR"/*.tf 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)

  # Count resources
  RESOURCE_COUNT=$(grep -r "^resource " "$TF_DIR"/*.tf 2>/dev/null | wc -l)

  # Output JSON report
  jq -n \
    --arg dir "$TF_DIR" \
    --arg structure "$STRUCTURE" \
    --arg backend "${BACKEND:-local}" \
    --arg version "${TF_VERSION:-unknown}" \
    --arg resources "$RESOURCE_COUNT" \
    '{
      directory: $dir,
      structure: $structure,
      backend: $backend,
      terraform_version: $version,
      resource_count: ($resources | tonumber)
    }' >> "$OUTPUT_FILE"
done
```

**`generate-config.sh`**
```bash
#!/bin/bash
# Generate faber-cloud.json from discovery reports

DISCOVERY_DIR=$1
OUTPUT_FILE=".fractary/plugins/faber-cloud/config/faber-cloud.json"

# Load discovery reports
TF_REPORT=$(cat "$DISCOVERY_DIR/discovery-report-terraform.json")
AWS_REPORT=$(cat "$DISCOVERY_DIR/discovery-report-aws.json")
CUSTOM_REPORT=$(cat "$DISCOVERY_DIR/discovery-report-custom-agents.json")

# Extract key information
TF_DIR=$(echo "$TF_REPORT" | jq -r '.directory')
TF_STRUCTURE=$(echo "$TF_REPORT" | jq -r '.structure')
AWS_REGION=$(echo "$AWS_REPORT" | jq -r '.profiles[0].region // "us-east-1"')

# Detect project name from directory
PROJECT_NAME=$(basename "$(pwd)")

# Detect AWS profiles for environments
TEST_PROFILE=$(echo "$AWS_REPORT" | jq -r '.profiles[] | select(.name | contains("test")) | .name' | head -1)
PROD_PROFILE=$(echo "$AWS_REPORT" | jq -r '.profiles[] | select(.name | contains("prod")) | .name' | head -1)

# Generate configuration
mkdir -p "$(dirname "$OUTPUT_FILE")"

jq -n \
  --arg project "$PROJECT_NAME" \
  --arg tf_dir "$TF_DIR" \
  --arg region "$AWS_REGION" \
  --arg test_profile "${TEST_PROFILE:-${PROJECT_NAME}-test-deploy}" \
  --arg prod_profile "${PROD_PROFILE:-${PROJECT_NAME}-prod-deploy}" \
  '{
    version: "1.0",
    project: {
      name: $project,
      subsystem: "core",
      organization: "default"
    },
    handlers: {
      hosting: {
        active: "aws",
        aws: {
          region: $region,
          profiles: {
            discover: $test_profile,
            test: $test_profile,
            prod: $prod_profile
          }
        }
      },
      iac: {
        active: "terraform",
        terraform: {
          directory: $tf_dir,
          var_file_pattern: "{environment}.tfvars"
        }
      }
    },
    environments: {
      test: {
        auto_approve: false,
        cost_threshold: 100
      },
      prod: {
        auto_approve: false,
        require_confirmation: true,
        cost_threshold: 1000
      }
    },
    hooks: {}
  }' > "$OUTPUT_FILE"

echo "Generated configuration: $OUTPUT_FILE"
```

## Implementation Plan

### Phase 1: Hook System (Week 1-2)

**Tasks**:
1. Add hook configuration schema to faber-cloud.json
2. Create `execute-hooks.sh` script
3. Update `infra-deployer` skill to execute hooks
4. Update `infra-planner` skill to execute pre/post-plan hooks
5. Update `infra-teardown` skill to execute pre/post-destroy hooks
6. Add hook execution logging and error handling
7. Create documentation with examples

**Files Modified**:
- `plugins/faber-cloud/config/faber-cloud.example.json` - Add hooks section
- `plugins/faber-cloud/skills/infra-deployer/SKILL.md` - Add hook execution steps
- `plugins/faber-cloud/skills/infra-deployer/scripts/execute-hooks.sh` - New script
- `plugins/faber-cloud/skills/infra-planner/SKILL.md` - Add hook execution
- `plugins/faber-cloud/skills/infra-teardown/SKILL.md` - Add hook execution
- `plugins/faber-cloud/docs/HOOKS.md` - New documentation

**Success Criteria**:
- Hooks execute at correct lifecycle points
- Critical hook failures block deployment
- Optional hook failures log warnings but continue
- Hook output captured in deployment logs
- Documentation includes 5+ common hook examples

### Phase 2: Enhanced Environment Validation (Week 2)

**Tasks**:
1. Create `enhanced-validate-plan.sh` script
2. Implement multi-source environment detection
3. Add resource naming pattern validation
4. Enhance production-specific checks
5. Integrate into infra-deployer workflow
6. Add validation reporting

**Files Modified**:
- `plugins/faber-cloud/skills/infra-deployer/scripts/enhanced-validate-plan.sh` - New script
- `plugins/faber-cloud/skills/infra-deployer/scripts/deploy-infrastructure.sh` - Call validation
- `plugins/faber-cloud/skills/infra-deployer/SKILL.md` - Document validation step

**Success Criteria**:
- Environment mismatches detected and blocked
- Production deployments have additional safeguards
- Validation completes in <30 seconds
- Clear error messages for validation failures

### Phase 3: Infrastructure Discovery (Week 3-4)

**Tasks**:
1. Create `infra-adoption` skill directory structure
2. Implement `discover-terraform.sh` script
3. Implement `discover-aws-profiles.sh` script
4. Implement `discover-custom-agents.sh` script
5. Create JSON report formats
6. Test discovery on various project structures

**Files Created**:
- `plugins/faber-cloud/skills/infra-adoption/SKILL.md`
- `plugins/faber-cloud/skills/infra-adoption/scripts/discover-terraform.sh`
- `plugins/faber-cloud/skills/infra-adoption/scripts/discover-aws-profiles.sh`
- `plugins/faber-cloud/skills/infra-adoption/scripts/discover-custom-agents.sh`

**Success Criteria**:
- Successfully discovers Terraform in flat, modular, multi-env structures
- Detects AWS profiles with >90% accuracy
- Identifies custom agents and their purposes
- Discovery completes in <2 minutes

### Phase 4: Configuration Generation (Week 4-5)

**Tasks**:
1. Implement `generate-config.sh` script
2. Create configuration templates for common patterns
3. Implement intelligent defaults
4. Add configuration validation
5. Test with discovered infrastructure

**Files Created**:
- `plugins/faber-cloud/skills/infra-adoption/scripts/generate-config.sh`
- `plugins/faber-cloud/config/templates/modular-terraform.json`
- `plugins/faber-cloud/config/templates/flat-terraform.json`
- `plugins/faber-cloud/config/templates/multi-environment.json`

**Success Criteria**:
- Generated configurations are valid
- Configurations work without manual edits for simple cases
- Complex cases require minimal adjustments
- Template library covers 80% of common patterns

### Phase 5: Migration Reporting (Week 5)

**Tasks**:
1. Implement `generate-migration-report.sh` script
2. Create migration report template
3. Add custom script mapping logic
4. Generate migration checklists
5. Add risk assessment and timeline estimation

**Files Created**:
- `plugins/faber-cloud/skills/infra-adoption/scripts/generate-migration-report.sh`
- `plugins/faber-cloud/skills/infra-adoption/templates/MIGRATION-REPORT.md.template`

**Success Criteria**:
- Migration reports are comprehensive and actionable
- Script mapping identifies faber-cloud equivalents
- Checklists guide users through migration phases
- Risk assessment is accurate

### Phase 6: Adoption Command & Workflow (Week 6)

**Tasks**:
1. Create `/fractary-faber-cloud:adopt` command
2. Update `cloud-director` agent to route adoption requests
3. Complete `infra-adoption` skill workflow
4. Add interactive prompts and user guidance
5. Integrate all discovery, generation, and reporting

**Files Created**:
- `plugins/faber-cloud/commands/adopt.md`

**Files Modified**:
- `plugins/faber-cloud/agents/cloud-director.md` - Add adoption routing
- `plugins/faber-cloud/skills/infra-adoption/SKILL.md` - Complete workflow

**Success Criteria**:
- `/fractary-faber-cloud:adopt` successfully adopts existing infrastructure
- User can complete adoption workflow without external help
- Generated configuration works for first deployment
- Migration report provides clear next steps

### Phase 7: Documentation (Week 6-7)

**Tasks**:
1. Create comprehensive migration guide
2. Document hook system with examples
3. Create configuration templates documentation
4. Add troubleshooting guide
5. Update main README and plugin docs

**Files Created**:
- `plugins/faber-cloud/docs/MIGRATION-FROM-CUSTOM-AGENTS.md`
- `plugins/faber-cloud/docs/HOOKS.md`
- `plugins/faber-cloud/docs/CONFIGURATION-TEMPLATES.md`
- `plugins/faber-cloud/docs/TROUBLESHOOTING-MIGRATION.md`

**Files Modified**:
- `plugins/faber-cloud/README.md` - Add migration section
- `plugins/faber-cloud/docs/GETTING-STARTED.md` - Add adoption workflow

**Success Criteria**:
- Documentation covers all migration scenarios
- Hook examples for 10+ common use cases
- Troubleshooting guide addresses common issues
- Migration guide can be followed independently

## Testing Strategy

### Unit Testing

**Hook System**:
- Test hook execution with valid/invalid commands
- Test critical vs optional hook behavior
- Test timeout enforcement
- Test environment filtering
- Test environment variable passing

**Environment Validation**:
- Test with matching environments (pass)
- Test with mismatched tfvars (fail)
- Test with mismatched workspace (fail)
- Test with ambiguous state (warn)
- Test production-specific checks

**Discovery Scripts**:
- Test with flat Terraform structure
- Test with modular Terraform structure
- Test with multi-environment structure
- Test with various AWS profile naming patterns
- Test with different custom agent structures

**Configuration Generation**:
- Test with discovered flat structure
- Test with discovered modular structure
- Test validation of generated config
- Test template application

### Integration Testing

**End-to-End Adoption Workflow**:
1. Start with project with custom agents
2. Run `/fractary-faber-cloud:adopt`
3. Verify discovery reports are accurate
4. Verify generated configuration is valid
5. Verify migration report is comprehensive
6. Run audit with generated config (read-only)
7. Run deploy-plan with generated config
8. Verify outputs match custom agent outputs

**Hook Integration**:
1. Configure pre-deploy hook (Lambda build simulation)
2. Run deployment
3. Verify hook executed before apply
4. Verify hook failure blocks deployment
5. Configure optional post-deploy hook
6. Verify optional hook failure doesn't block

**Validation Integration**:
1. Create environment mismatch scenario (test.tfvars, prod env)
2. Run deployment
3. Verify deployment is blocked
4. Fix mismatch
5. Verify deployment succeeds

### Test Projects

Create test projects with various structures:

**Test Project 1: Simple Flat Structure** (like basic use case)
- Flat Terraform directory
- test.tfvars and prod.tfvars
- Local state
- No custom agents

**Test Project 2: Modular Structure** (like Corthovore)
- terraform/modules/ and terraform/environments/
- Module dependencies
- S3 backend
- Custom deployer agent

**Test Project 3: Complex Multi-Site** (like Corthuxa)
- Flat but multi-feature Terraform
- Lambda functions
- S3 backend with locking
- Full custom agent suite (audit, architect, deploy, debug)
- Custom build scripts

**Success Criteria**:
- All test projects successfully adopt
- Generated configurations are valid
- First deployment via faber-cloud succeeds
- All hooks execute correctly
- All validations pass/fail as expected

## Success Metrics

### Adoption Metrics
- [ ] Discovery process completes in <2 minutes
- [ ] Generated configuration valid for 90% of projects
- [ ] Migration report comprehensive (>5 sections, >10 checklist items)
- [ ] Adoption workflow completable in <30 minutes

### Hook System Metrics
- [ ] Hook execution adds <10% to deployment time
- [ ] Critical hook failures block deployment 100% of time
- [ ] Optional hook failures log warnings 100% of time
- [ ] Hook output captured in logs 100% of time

### Validation Metrics
- [ ] Environment mismatches detected 100% of time
- [ ] False positive rate <5%
- [ ] Validation adds <30 seconds to deployment
- [ ] Production deployments have >3 additional safety checks

### Migration Success Metrics
- [ ] Users can complete migration without external help (80% success rate)
- [ ] Generated configs work for first deployment (70% success rate)
- [ ] Migration time reduced by 50% vs manual process
- [ ] User satisfaction rating >4/5

## Documentation Deliverables

1. **MIGRATION-FROM-CUSTOM-AGENTS.md** - Complete migration guide
2. **HOOKS.md** - Hook system documentation with examples
3. **CONFIGURATION-TEMPLATES.md** - Template library documentation
4. **TROUBLESHOOTING-MIGRATION.md** - Common issues and solutions
5. **README.md updates** - Add adoption workflow section
6. **GETTING-STARTED.md updates** - Include adoption as entry point

## Dependencies

**External**:
- None (all functionality built into faber-cloud)

**Internal**:
- Existing faber-cloud infrastructure (auditor, deployer, planner)
- Terraform handler (existing)
- AWS handler (existing)

## Risks & Mitigations

### Risk 1: Discovery Inaccuracy
**Impact**: Generated config doesn't match existing infrastructure
**Mitigation**:
- Extensive testing with various structures
- Manual review step before adoption
- Clear documentation of what discovery detects

### Risk 2: Hook System Complexity
**Impact**: Users struggle to configure hooks correctly
**Mitigation**:
- Comprehensive examples for common use cases
- Auto-generation of hooks for detected custom scripts
- Validation of hook configuration

### Risk 3: Environment Validation False Positives
**Impact**: Valid deployments blocked by overzealous validation
**Mitigation**:
- Tunable validation strictness
- Clear explanation of why validation failed
- Override mechanism for edge cases

### Risk 4: Migration Report Incompleteness
**Impact**: Users miss critical migration steps
**Mitigation**:
- Template-based report generation
- Review migration reports from test projects
- User feedback loop to improve reports

## Future Enhancements

### Post-v1.0 Features

1. **Automated Hook Generation**
   - Analyze custom scripts and generate equivalent hooks automatically
   - Suggest hook configuration based on script analysis

2. **Multi-IaC Support**
   - Extend discovery to CDK, Pulumi, CloudFormation
   - Generate appropriate handler configurations

3. **Cloud Provider Expansion**
   - Discovery for GCP, Azure configurations
   - Multi-cloud adoption support

4. **Continuous Validation**
   - Background drift detection with hooks
   - Scheduled compliance checks
   - Automated remediation suggestions

5. **Migration Assistant**
   - Interactive CLI wizard for migration
   - Step-by-step guidance with validation
   - Automated rollback on errors

## Conclusion

This specification provides the foundation for making faber-cloud the standard infrastructure management tool by removing barriers to adoption for projects with existing infrastructure. The hook system, enhanced validation, and automated discovery/configuration generation enable smooth transitions from custom implementations while preserving project-specific requirements.

**Timeline**: 6-7 weeks
**Effort**: 1 developer full-time
**Priority**: High (enables SPEC-0030-02 and SPEC-0030-03)
