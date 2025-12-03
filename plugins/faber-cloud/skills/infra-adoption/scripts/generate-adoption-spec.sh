#!/bin/bash
# generate-adoption-spec.sh - Generate detailed, actionable faber-cloud adoption spec
#
# This script generates a comprehensive migration plan with:
# - Specific files to create (with full content)
# - Specific commands to convert (with before/after)
# - Specific hooks to configure (with actual skill code)
# - Complete configuration ready to use

set -euo pipefail

# Get script directory for sourcing shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared complexity assessment
# shellcheck source=./shared/assess-complexity.sh
source "$SCRIPT_DIR/shared/assess-complexity.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[✓]${NC} $*" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" >&2; }
log_error() { echo -e "${RED}[✗]${NC} $*" >&2; }

# Usage
usage() {
  cat <<'USAGE'
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
  - config.json (generated config)

Exit Codes:
  0 - Success
  1 - Error during generation
  2 - Invalid arguments
USAGE
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
CONFIG_FILE="$OUTPUT_DIR/config.json"

for report in "$TF_REPORT" "$AWS_REPORT" "$AGENTS_REPORT" "$CONFIG_FILE"; do
  if [ ! -f "$report" ]; then
    log_error "Required file not found: $report"
    exit 2
  fi
done

log_info "Generating adoption spec..."

# Extract project information using jq --arg for safety
PROJECT_NAME=$(jq -r '.project.name // "unknown"' "$CONFIG_FILE")
TERRAFORM_DIR=$(jq -r '.summary.primary_directory // "./terraform"' "$TF_REPORT")
TF_STRUCTURE=$(jq -r '.summary.primary_structure // "flat"' "$TF_REPORT")
RESOURCE_COUNT=$(jq -r '.summary.total_resources // 0' "$TF_REPORT")

ENV_COUNT=$(jq -r '.summary.project_related_profiles // 0' "$AWS_REPORT")
ENVIRONMENTS=$(jq -r '.summary.environments_detected | join(", ") // "test, prod"' "$AWS_REPORT")

SCRIPTS_COUNT=$(jq -r '.summary.total_files // 0' "$AGENTS_REPORT")

# Use shared complexity assessment
COMPLEXITY_INFO=$(assess_complexity "$TF_REPORT" "$AWS_REPORT" "$AGENTS_REPORT")
IFS='|' read -r COMPLEXITY COMPLEXITY_SCORE ESTIMATED_HOURS <<< "$COMPLEXITY_INFO"

DATE=$(date -u +"%Y-%m-%d")

log_info "Project: $PROJECT_NAME"
log_info "Complexity: $COMPLEXITY (score: $COMPLEXITY_SCORE)"
log_info "Estimated: $ESTIMATED_HOURS hours"

# Build spec content in memory (more efficient than 1000+ appends)
SPEC_CONTENT=""

# Helper to append content
append() {
  SPEC_CONTENT+="$1"
}

# Generate spec header
append "$(cat <<HEADER
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
**Target State**: Standardized faber-cloud deployment with project-specific hooks
**Migration Approach**: Incremental migration with testing at each phase

### Key Metrics

| Metric | Value |
|--------|-------|
| **Infrastructure Structure** | ${TF_STRUCTURE} |
| **Terraform Resources** | ${RESOURCE_COUNT} |
| **Environments** | ${ENV_COUNT} (${ENVIRONMENTS}) |
| **Custom Scripts** | ${SCRIPTS_COUNT} |
| **Estimated Time** | ${ESTIMATED_HOURS} hours |
| **Complexity** | ${COMPLEXITY} |

---

## Phase 1: Project Documentation (2 hours)

Create structured documentation that faber-cloud will reference during deployments.

### Task 1.1: Create Architecture Documentation

**Create File**: \`docs/infrastructure/ARCHITECTURE.md\`

\`\`\`markdown
# Infrastructure Architecture for ${PROJECT_NAME}

## Overview

${PROJECT_NAME} infrastructure managed by Terraform.

## Components

HEADER
)"

# Extract and add discovered components
log_info "Extracting Terraform components..."

# Use jq --arg for safe variable passing
RESOURCE_TYPES=$(jq -r '
  [.terraform_directories[0].structure_analysis.resources[]? |
   split(".")[0]] |
  unique |
  .[]
' "$TF_REPORT" 2>/dev/null || {
  log_warning "Could not extract resource types from Terraform discovery"
  echo ""
})

if [ -n "$RESOURCE_TYPES" ]; then
  append "
Based on Terraform discovery, your infrastructure includes:

"

  while IFS= read -r resource_type; do
    [ -z "$resource_type" ] && continue

    # Safe jq usage with --arg
    count=$(jq --arg type "$resource_type" '
      [.terraform_directories[0].structure_analysis.resources[]? |
       select(startswith($type + "."))] |
      length
    ' "$TF_REPORT" 2>/dev/null || echo "0")

    append "- **${resource_type}**: ${count} resource(s)
"
  done <<< "$RESOURCE_TYPES"
fi

# Continue building spec with proper escaping using different heredoc delimiter
append "$(cat <<'ARCHITECTURE'

## Architecture Decisions

### Infrastructure as Code
- **Tool**: Terraform
- **Structure**: Modular design with environment-specific variables
- **State**: Managed via Terraform state file

### Environment Strategy
- Test: Development and testing
- Production: Live environment

---

**How to complete this file:**
1. Review Terraform files in your terraform directory
2. Document each component's purpose
3. Explain architecture decisions
4. Include environment differences
```

---

### Task 1.2: Create Deployment Standards

**Create File**: `docs/infrastructure/DEPLOYMENT-STANDARDS.md`

```markdown
# Deployment Standards

## Pre-Deployment Requirements

1. **AWS Credentials**
   - Must use correct AWS profile for environment
   - Credentials must be valid

2. **Terraform Validation**
   - All files must pass `terraform validate`

## Resource Naming Pattern

`{project}-{resource}-{environment}`

### Examples
- S3: `${PROJECT_NAME}-data-test`
- Lambda: `${PROJECT_NAME}-processor-test`

## Environment Rules

### Test
- Auto-approve: Allowed
- Backups: Not required

### Production
- Auto-approve: NEVER
- Backups: REQUIRED
- Manual approval required

## Tags Required

```
Environment = "test" | "prod"
Project = "${PROJECT_NAME}"
ManagedBy = "faber-cloud"
```
```

---

ARCHITECTURE
)"

# Add Phase 2: Commands
log_info "Generating Phase 2: Commands..."

append "## Phase 2: Convert Custom Commands (1 hour)

Convert infrastructure commands to delegate to faber-cloud.

"

# Find commands safely
COMMANDS_FOUND=$(jq -r '
  [.files[]? | select(.path | contains("/commands/"))] |
  if length > 0 then .[].path else "" end
' "$AGENTS_REPORT" 2>/dev/null || {
  log_warning "Could not extract commands from discovery"
  echo ""
})

if [ -n "$COMMANDS_FOUND" ]; then
  COMMAND_NUM=1
  while IFS= read -r cmd_path; do
    [ -z "$cmd_path" ] && continue

    cmd_name=$(basename "$cmd_path" .md)

    # Use different heredoc delimiter to avoid escaping
    append "$(cat <<COMMAND

### Task 2.${COMMAND_NUM}: Convert \`/${cmd_name}\` Command

**Current File**: \`${cmd_path}\`

**Replace with**:

**File**: \`${cmd_path}\`

\`\`\`markdown
---
name: ${cmd_name}
description: Deploy infrastructure using faber-cloud
---

Use the @agent-fractary-faber-cloud:infra-manager agent to deploy infrastructure.

**Project Context:**
- Read \`docs/infrastructure/ARCHITECTURE.md\`
- Read \`docs/infrastructure/DEPLOYMENT-STANDARDS.md\`

**Environment**: \${environment:-test}

**Request**: "Deploy ${PROJECT_NAME} infrastructure to \${environment}"
\`\`\`

**Testing**:
\`\`\`bash
/${cmd_name} --env test
\`\`\`

---

COMMAND
)"

    COMMAND_NUM=$((COMMAND_NUM + 1))
  done <<< "$COMMANDS_FOUND"
else
  append "### No Existing Commands Found

Create new deployment command:

**File**: \`.claude/commands/deploy.md\`

\`\`\`markdown
---
name: deploy
---

Use @agent-fractary-faber-cloud:infra-manager to deploy infrastructure.

**Project Context:**
- Read \`docs/infrastructure/ARCHITECTURE.md\`
- Read \`docs/infrastructure/DEPLOYMENT-STANDARDS.md\`

**Request**: \"Deploy ${PROJECT_NAME} infrastructure\"
\`\`\`

---

"
fi

# Add Phase 3: Skill Hooks
log_info "Generating Phase 3: Skill Hooks..."

append "## Phase 3: Create Skill Hooks (3 hours)

Convert validation scripts to skill hooks.

"

# Find validation scripts safely
VALIDATION_SCRIPTS=$(jq -r '
  [.files[]? | select(.purposes[]? == "validate")] |
  if length > 0 then .[].path else "" end
' "$AGENTS_REPORT" 2>/dev/null || {
  log_warning "Could not extract validation scripts"
  echo ""
})

if [ -n "$VALIDATION_SCRIPTS" ]; then
  SKILL_NUM=1
  while IFS= read -r script_path; do
    [ -z "$script_path" ] && continue

    script_name=$(basename "$script_path" | sed 's/\.sh$//' | sed 's/^validate-//')
    skill_name="${script_name}-validator-deploy-pre"

    append "$(cat <<SKILL

### Task 3.${SKILL_NUM}: Convert \`${script_path}\` to Skill Hook

**Purpose**: Validation before deployment

**Create File**: \`.claude/skills/${skill_name}/SKILL.md\`

\`\`\`markdown
---
name: ${skill_name}
description: Validate ${script_name} before deployment
tools: Read, Bash
---

# ${script_name} Validator

<CONTEXT>
Validate ${script_name} requirements before deploying infrastructure.
Receives WorkflowContext from faber-cloud.
</CONTEXT>

<WORKFLOW>
## Step 1: Parse WorkflowContext
Read environment from WorkflowContext.

## Step 2: Run Validation
\\\`\\\`\\\`bash
bash ${script_path} \\\${environment}
\\\`\\\`\\\`

## Step 3: Return Result
Return success/failure status.
</WORKFLOW>
\`\`\`

**Testing**:
\`\`\`bash
export FABER_CLOUD_ENV="test"
/skill ${skill_name}
\`\`\`

---

SKILL
)"

    SKILL_NUM=$((SKILL_NUM + 1))
  done <<< "$VALIDATION_SCRIPTS"
else
  append "### No Validation Scripts Found

Skip Phase 3 or add validation hooks later.

---

"
fi

# Add Phase 4: Configuration
log_info "Generating Phase 4: Configuration..."

append "## Phase 4: Configure Faber-Cloud (1 hour)

### Task 4.1: Install Configuration

\`\`\`bash
mkdir -p .fractary/plugins/faber-cloud
cp ${OUTPUT_DIR}/config.json .fractary/plugins/faber-cloud/
\`\`\`

### Task 4.2: Review Configuration

See the generated \`config.json\` in the output directory.

---

## Phase 5: Test Integration (2 hours)

### Task 5.1: Test Deployment

\`\`\`bash
/deploy --env test
\`\`\`

**Expected**: Deployment succeeds with hooks executing.

---

## Success Criteria

- [ ] \`/deploy --env test\` deploys successfully
- [ ] Deployed resources match previous infrastructure
- [ ] Validation hooks execute
- [ ] Team can use new workflow

---

## Timeline

| Phase | Time |
|-------|------|
| Phase 1: Documentation | 2h |
| Phase 2: Commands | 1h |
| Phase 3: Skill Hooks | 3h |
| Phase 4: Configuration | 1h |
| Phase 5: Testing | 2h |
| **Total** | **${ESTIMATED_HOURS}h** |

---

## Appendix: Discovery Summary

### Terraform
\`\`\`json
$(jq '.summary' "$TF_REPORT")
\`\`\`

### AWS
\`\`\`json
$(jq '.summary' "$AWS_REPORT")
\`\`\`

---

**End of Adoption Spec**

*Hand this to another Claude Code session for implementation.*
"

# Write spec to file atomically
log_info "Writing spec to $SPEC_OUTPUT..."
echo "$SPEC_CONTENT" > "$SPEC_OUTPUT"

log_success "Adoption spec generated: $SPEC_OUTPUT"

exit 0
