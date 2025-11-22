#!/bin/bash
# invoke-skill-hook.sh - Invoke a Claude Code skill as a hook handler
#
# This script prepares the WorkflowContext and invokes a skill for hook execution.
# Skills receive structured context about the workflow and return structured results.
#
# IMPORTANT: This is a RUNTIME PLACEHOLDER for testing purposes.
# In production Claude Code environments, skills are invoked via the Skill tool.
# This script demonstrates the interface and validates skill existence.
#
# Production behavior:
# - Claude Code runtime invokes skills directly via Skill tool
# - WorkflowContext is passed automatically
# - WorkflowResult is parsed from skill output
#
# Test/Development behavior:
# - Validates skill directory exists
# - Shows expected interface
# - Returns success if skill found

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function: Log with color
log_info() {
  echo -e "${BLUE}[SKILL-HOOK]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SKILL-HOOK]${NC} $*"
}

log_error() {
  echo -e "${RED}[SKILL-HOOK]${NC} $*"
}

# Function: Display usage
usage() {
  cat <<EOF
Usage: invoke-skill-hook.sh <skill_name> [context_json_file]

Invoke a Claude Code skill as a hook handler.

Arguments:
  skill_name        Name of skill to invoke (e.g., "dataset-validator-deploy-pre")
  context_json_file Optional path to WorkflowContext JSON file (defaults to temp file)

Environment Variables (used to build WorkflowContext):
  FABER_CLOUD_ENV             - Environment name
  FABER_CLOUD_TERRAFORM_DIR   - Terraform working directory
  FABER_CLOUD_PROJECT         - Project name
  FABER_CLOUD_SUBSYSTEM       - Subsystem name
  FABER_CLOUD_OPERATION       - Operation type (plan, deploy, destroy)
  FABER_CLOUD_HOOK_TYPE       - Hook type (pre-plan, post-deploy, etc.)
  AWS_PROFILE                 - Active AWS profile for this environment

Examples:
  invoke-skill-hook.sh dataset-validator-deploy-pre
  invoke-skill-hook.sh custom-validator /tmp/context.json

Exit Codes:
  0 - Skill executed successfully
  1 - Skill failed or returned error
  2 - Invalid arguments or configuration error
EOF
  exit 2
}

# Function: Create WorkflowContext JSON
create_workflow_context() {
  local context_file="$1"

  # Validate required environment variables
  local missing_vars=()

  if [ -z "${FABER_CLOUD_ENV:-}" ]; then
    missing_vars+=("FABER_CLOUD_ENV")
  fi

  if [ -z "${FABER_CLOUD_OPERATION:-}" ]; then
    missing_vars+=("FABER_CLOUD_OPERATION")
  fi

  if [ -z "${FABER_CLOUD_HOOK_TYPE:-}" ]; then
    missing_vars+=("FABER_CLOUD_HOOK_TYPE")
  fi

  # Fail fast if critical variables are missing
  if [ ${#missing_vars[@]} -gt 0 ]; then
    log_error "Critical environment variables missing: ${missing_vars[*]}"
    log_error "These variables should be set by the hook executor"
    log_error "Expected: FABER_CLOUD_ENV, FABER_CLOUD_OPERATION, FABER_CLOUD_HOOK_TYPE"
    return 1
  fi

  # SECURITY: Sanitize environment variables for JSON
  # Escape quotes and backslashes to prevent JSON injection
  local safe_env="${FABER_CLOUD_ENV//\\/\\\\}"
  safe_env="${safe_env//\"/\\\"}"

  local safe_operation="${FABER_CLOUD_OPERATION//\\/\\\\}"
  safe_operation="${safe_operation//\"/\\\"}"

  local safe_hook_type="${FABER_CLOUD_HOOK_TYPE//\\/\\\\}"
  safe_hook_type="${safe_hook_type//\"/\\\"}"

  local safe_project="${FABER_CLOUD_PROJECT:-unknown}"
  safe_project="${safe_project//\\/\\\\}"
  safe_project="${safe_project//\"/\\\"}"

  # Build WorkflowContext JSON
  # ERROR HANDLING: Check if write succeeds
  if ! cat > "$context_file" <<EOF
{
  "workflowType": "infrastructure-${safe_operation}",
  "workflowPhase": "${safe_hook_type}",
  "pluginName": "faber-cloud",
  "pluginVersion": "2.3.1",
  "projectName": "${safe_project}",
  "projectRoot": "$(pwd)",
  "environment": "${safe_env}",
  "operation": "${safe_operation}",
  "targetResources": [],
  "projectConfig": {},
  "workflowConfig": {},
  "extensionConfig": {},
  "flags": {
    "dryRun": false,
    "complete": false,
    "productionConfirmed": $([ "${FABER_CLOUD_ENV}" = "prod" ] && echo "true" || echo "false"),
    "force": false
  },
  "artifacts": {}
}
EOF
  then
    log_error "Failed to write WorkflowContext to $context_file"
    log_error "Possible causes: disk full, permission denied, or invalid path"
    return 1
  fi

  # Validate JSON was written correctly
  if ! jq empty "$context_file" 2>/dev/null; then
    log_error "WorkflowContext JSON is malformed in $context_file"
    log_error "This may indicate environment variable contains invalid characters"
    # Show the file content for debugging
    cat "$context_file" >&2
    return 1
  fi

  # Verify file is not empty
  if [ ! -s "$context_file" ]; then
    log_error "WorkflowContext file is empty: $context_file"
    return 1
  fi

  log_info "WorkflowContext created: $context_file"
  log_info "Environment: ${FABER_CLOUD_ENV}"
  log_info "Operation: ${FABER_CLOUD_OPERATION}"
  log_info "Hook Type: ${FABER_CLOUD_HOOK_TYPE}"
}

# Function: Invoke skill via Claude Code
invoke_skill() {
  local skill_name="$1"
  local context_file="$2"

  log_info "Invoking skill: $skill_name"
  log_info "Context: $context_file"

  # RUNTIME DETECTION: Check if we're in Claude Code environment
  # In production, the Skill tool would be available and skills would be invoked directly
  # In test/dev, we validate the interface and skill existence

  # Check if skill exists in .claude/skills/
  if [ ! -d ".claude/skills/$skill_name" ]; then
    log_error "Skill not found: .claude/skills/$skill_name"
    log_error "Skills should be located in: .claude/skills/$skill_name/"
    return 1
  fi

  log_info "✓ Skill found: .claude/skills/$skill_name"

  # PRODUCTION MODE (Claude Code runtime with Skill tool):
  # This is where the actual skill invocation would happen via the Skill tool
  # The Skill tool is only available in the Claude Code runtime environment
  #
  # Expected invocation:
  #   - Skill tool invoked with skill name
  #   - WorkflowContext passed as JSON input
  #   - WorkflowResult received as JSON output
  #   - Exit code determines success/failure

  # TEST/DEV MODE (current implementation):
  # Demonstrate the interface without actual skill execution
  cat <<EOF

╔══════════════════════════════════════════════════════════════╗
║  SKILL HOOK INVOCATION (TEST MODE)                          ║
╚══════════════════════════════════════════════════════════════╝

Skill:    $skill_name
Context:  $context_file

⚠️  RUNTIME PLACEHOLDER ACTIVE
This script validates the skill hook interface but does not invoke skills.
In Claude Code production environments, skills are invoked via the Skill tool.

WorkflowContext prepared:
$(cat "$context_file" | jq '.')

─────────────────────────────────────────────────────────────

Production behavior (Claude Code runtime):
  1. Skill tool invokes: $skill_name
  2. WorkflowContext passed as input
  3. Skill executes validation logic
  4. WorkflowResult returned as JSON
  5. Exit code: 0 (success) or 1 (failure)

Expected WorkflowResult format:
{
  "success": true/false,
  "messages": ["Validation messages"],
  "warnings": ["Warning messages"],
  "errors": ["Error messages"],
  "artifacts": {"key": "value"},
  "executionTime": 1234,
  "timestamp": "2025-11-07T12:00:00Z",
  "skillName": "$skill_name"
}

─────────────────────────────────────────────────────────────

Test mode result: PASS (skill found, interface validated)

EOF

  log_success "Skill hook interface validated (test mode)"
  log_info "In production, skill would be invoked via Claude Code Skill tool"
  return 0
}

# Main execution
main() {
  # Check dependencies
  if ! command -v jq &> /dev/null; then
    log_error "Required dependency 'jq' not found"
    log_error "Install jq: https://stedolan.github.io/jq/download/"
    exit 2
  fi

  # Validate arguments
  if [ $# -lt 1 ]; then
    usage
  fi

  local skill_name="$1"
  local context_file="${2:-}"

  # SECURITY: Validate skill name to prevent path traversal attacks
  # Only allow alphanumeric, hyphens, and underscores
  if [[ ! "$skill_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "SECURITY: Invalid skill name: $skill_name"
    log_error "Skill names must contain only alphanumeric characters, hyphens, and underscores"
    log_error "Rejected characters: slashes (/), dots (.), or other special characters"
    exit 2
  fi

  # Additional validation: Prevent path traversal patterns
  if [[ "$skill_name" == *".."* ]] || [[ "$skill_name" == *"/"* ]]; then
    log_error "SECURITY: Skill name contains path traversal patterns: $skill_name"
    exit 2
  fi

  # Create temp context file if not provided
  if [ -z "$context_file" ]; then
    context_file=$(mktemp /tmp/workflow-context.XXXXXX.json)
    # Set restrictive permissions for security
    chmod 600 "$context_file"
    trap "rm -f $context_file" EXIT
  fi

  # Create WorkflowContext
  if ! create_workflow_context "$context_file"; then
    log_error "Failed to create WorkflowContext"
    exit 2
  fi

  # Invoke skill
  if invoke_skill "$skill_name" "$context_file"; then
    log_success "Skill hook completed successfully"
    exit 0
  else
    log_error "Skill hook failed"
    exit 1
  fi
}

# Run main function
main "$@"
