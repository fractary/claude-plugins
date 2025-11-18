#!/bin/bash
# production-safety-confirm.sh - Production deployment confirmation protocol
#
# Enforces production safety by requiring explicit user confirmation before
# deploying to production environments. Implements 2-question protocol.
#
# Usage: production-safety-confirm.sh <environment> <operation> [plan_summary]
#
# Arguments:
#   environment    - Target environment (prod, production, live, etc.)
#   operation      - Operation being performed (deploy, apply, etc.)
#   plan_summary   - Optional: Path to file containing plan summary
#
# Exit Codes:
#   0 - User confirmed, safe to proceed
#   1 - User declined or invalid response, abort operation
#   2 - Invalid arguments or configuration error
#
# Environment Variables:
#   DEVOPS_REQUIRE_CONFIRMATION - Set by config-loader.sh from environments.{env}.require_confirmation
#   DEVOPS_AUTO_APPROVE        - If "true", bypass interactive confirmation (CI/CD use)
#   CI                         - If set, indicates CI/CD environment (requires explicit bypass)
#
# Variable Distinction:
#   DEVOPS_REQUIRE_CONFIRMATION - Configuration setting (should confirmation be required?)
#   DEVOPS_AUTO_APPROVE         - Runtime override (bypass confirmation in CI/CD)
#
# Audit Logging:
#   All confirmation attempts are logged to stderr with timestamp and decision

set -euo pipefail

# Timeouts (in seconds)
readonly CONFIRMATION_TIMEOUT=300  # 5 minutes per question

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Max plan summary size to display (1MB)
readonly MAX_PLAN_SIZE=$((1024 * 1024))

# Audit log function
audit_log() {
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local message="$*"
  echo "[AUDIT] [$timestamp] $message" >&2
}

# Signal handler for graceful exit
handle_signal() {
  local signal=$1
  audit_log "Received signal $signal - aborting confirmation"
  echo ""
  log_error "Confirmation interrupted by signal $signal"
  display_abort_message "User interrupted confirmation (signal $signal)"
  exit 1
}

# Set up signal handlers
trap 'handle_signal SIGINT' INT
trap 'handle_signal SIGTERM' TERM

# Function: Display usage
usage() {
  cat <<EOF
Usage: production-safety-confirm.sh <environment> <operation> [plan_summary]

Production deployment confirmation protocol - requires explicit user approval.

Arguments:
  environment    Target environment (prod, production, etc.)
  operation      Operation being performed (deploy, apply, etc.)
  plan_summary   Optional: Path to file containing plan summary

Exit Codes:
  0 - User confirmed, safe to proceed
  1 - User declined or invalid response
  2 - Invalid arguments

Examples:
  production-safety-confirm.sh prod deploy
  production-safety-confirm.sh prod apply /tmp/plan-summary.txt
EOF
  exit 2
}

# Function: Log with color
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[✓]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[⚠]${NC} $*"
}

log_error() {
  echo -e "${RED}[✗]${NC} $*"
}

# Function: Display production warning banner
display_warning_banner() {
  local environment="$1"
  local operation="$2"

  echo ""
  echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}${BOLD}║                                                               ║${NC}"
  echo -e "${RED}${BOLD}║            🚨  PRODUCTION OPERATION DETECTED  🚨              ║${NC}"
  echo -e "${RED}${BOLD}║                                                               ║${NC}"
  echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}Target Environment:${NC} ${RED}${BOLD}${environment^^}${NC}"
  echo -e "${YELLOW}Operation:${NC}          ${operation}"
  echo ""
  echo -e "${RED}${BOLD}This will affect the ${environment^^} environment.${NC}"
  echo ""
}

# Function: Ask yes/no question with timeout
ask_yes_no() {
  local question="$1"
  local response

  echo -e "${YELLOW}${question}${NC}"

  # Use read with timeout
  if read -r -t "$CONFIRMATION_TIMEOUT" -p "Answer (yes/no): " response; then
    # Normalize response
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]' | xargs)

    if [[ "$response" == "yes" || "$response" == "y" ]]; then
      audit_log "User answered: yes"
      return 0
    elif [[ "$response" == "no" || "$response" == "n" ]]; then
      audit_log "User answered: no"
      return 1
    else
      audit_log "Invalid response: $response"
      log_error "Invalid response: '$response' (expected: yes/no)"
      return 1
    fi
  else
    # Timeout occurred
    audit_log "Timeout waiting for user response ($CONFIRMATION_TIMEOUT seconds)"
    echo ""
    log_error "Timeout waiting for response ($CONFIRMATION_TIMEOUT seconds)"
    return 1
  fi
}

# Function: Ask for typed confirmation with timeout
ask_typed_confirmation() {
  local expected="$1"
  local prompt="$2"
  local response

  echo ""
  echo -e "${YELLOW}${prompt}${NC}"

  # Use read with timeout
  if read -r -t "$CONFIRMATION_TIMEOUT" -p "Type exactly: " response; then
    if [[ "$response" == "$expected" ]]; then
      audit_log "Typed confirmation successful: $expected"
      return 0
    else
      audit_log "Typed confirmation failed: expected '$expected', got '$response'"
      log_error "Confirmation failed. Expected '${expected}', got '${response}'"
      return 1
    fi
  else
    # Timeout occurred
    audit_log "Timeout waiting for typed confirmation ($CONFIRMATION_TIMEOUT seconds)"
    echo ""
    log_error "Timeout waiting for confirmation ($CONFIRMATION_TIMEOUT seconds)"
    return 1
  fi
}

# Function: Display plan summary if available
display_plan_summary() {
  local plan_file="$1"

  if [[ -z "$plan_file" || ! -f "$plan_file" ]]; then
    log_info "No plan summary available"
    return 0
  fi

  # Check if file is readable
  if [[ ! -r "$plan_file" ]]; then
    log_warning "Plan summary file exists but is not readable: $plan_file"
    return 0
  fi

  # Check file size
  local file_size=$(stat -f%z "$plan_file" 2>/dev/null || stat -c%s "$plan_file" 2>/dev/null || echo "0")

  if [[ "$file_size" -gt "$MAX_PLAN_SIZE" ]]; then
    log_warning "Plan summary is too large to display (${file_size} bytes > ${MAX_PLAN_SIZE} bytes)"
    log_info "Showing first 100 lines only..."
    echo ""
    echo "─────────────────────────────────────────────────────────────"
    echo -e "${BLUE}Deployment Plan Summary (truncated):${NC}"
    echo "─────────────────────────────────────────────────────────────"
    head -n 100 "$plan_file" || log_error "Failed to read plan file"
    echo "..."
    echo "(Plan truncated - file too large)"
    echo "─────────────────────────────────────────────────────────────"
    echo ""
  else
    echo ""
    echo "─────────────────────────────────────────────────────────────"
    echo -e "${BLUE}Deployment Plan Summary:${NC}"
    echo "─────────────────────────────────────────────────────────────"
    cat "$plan_file" || log_error "Failed to read plan file"
    echo "─────────────────────────────────────────────────────────────"
    echo ""
  fi
}

# Function: Display abort message
display_abort_message() {
  local reason="$1"

  audit_log "DEPLOYMENT ABORTED: $reason"

  echo ""
  echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║                                                               ║${NC}"
  echo -e "${RED}║              ❌  PRODUCTION OPERATION CANCELLED  ❌            ║${NC}"
  echo -e "${RED}║                                                               ║${NC}"
  echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}Reason:${NC} ${reason}"
  echo ""
  echo -e "${BLUE}Recommended next steps:${NC}"
  echo "  1. Validate this deployment in TEST environment first"
  echo "  2. Review the deployment plan carefully"
  echo "  3. Ensure all stakeholders have approved this change"
  echo "  4. When ready, retry the production deployment"
  echo ""
}

# Function: Check if running in CI/CD
check_ci_environment() {
  if [[ -n "${CI:-}" ]]; then
    log_warning "CI/CD environment detected"

    if [[ "${DEVOPS_AUTO_APPROVE:-false}" != "true" ]]; then
      log_error "Production deployments in CI/CD require explicit DEVOPS_AUTO_APPROVE=true"
      log_error "This is a safety measure to prevent accidental production deployments"
      log_error ""
      log_error "To deploy to production from CI/CD:"
      log_error "  1. Set DEVOPS_AUTO_APPROVE=true in your CI/CD environment"
      log_error "  2. Ensure this is ONLY set for approved production deployment jobs"
      log_error "  3. Document the approval process in your CI/CD configuration"
      return 1
    fi

    log_warning "DEVOPS_AUTO_APPROVE=true detected - bypassing interactive confirmation"
    log_warning "Ensure this deployment has been approved through your change management process"
    return 0
  fi

  return 1
}

# Function: Execute confirmation protocol
execute_confirmation_protocol() {
  local environment="$1"
  local operation="$2"
  local plan_summary="${3:-}"

  audit_log "Starting confirmation protocol for environment=$environment operation=$operation"

  # Display warning banner
  display_warning_banner "$environment" "$operation"

  # Show plan summary if available
  if [[ -n "$plan_summary" ]]; then
    display_plan_summary "$plan_summary"
  fi

  # Question 1: Initial production confirmation
  echo ""
  echo -e "${BOLD}CONFIRMATION 1 of 2${NC}"
  echo ""

  if ! ask_yes_no "Have you validated this deployment in TEST environment and are ready to deploy to ${environment^^}?"; then
    display_abort_message "User declined at initial confirmation"
    return 1
  fi

  echo ""
  log_success "Initial confirmation received"
  echo ""

  # Brief pause for user to reconsider
  sleep 1

  # Question 2: Typed confirmation
  echo ""
  echo -e "${BOLD}CONFIRMATION 2 of 2${NC}"
  echo ""
  echo -e "${YELLOW}Final confirmation required.${NC}"
  echo -e "${YELLOW}This deployment will affect live ${environment^^} systems.${NC}"
  echo ""

  local env_lower=$(echo "$environment" | tr '[:upper:]' '[:lower:]')
  if ! ask_typed_confirmation "$env_lower" "Type '${env_lower}' to confirm deployment to ${environment^^}:"; then
    display_abort_message "User failed typed confirmation"
    return 1
  fi

  echo ""
  log_success "Production deployment confirmed"
  audit_log "DEPLOYMENT APPROVED: environment=$environment operation=$operation"
  echo ""

  return 0
}

# Main execution
main() {
  # Validate arguments
  if [[ $# -lt 2 ]]; then
    usage
  fi

  local environment="$1"
  local operation="$2"
  local plan_summary="${3:-}"

  audit_log "Script invoked: environment=$environment operation=$operation plan_summary=${plan_summary:-none} user=${USER:-unknown} pwd=$PWD"

  # Normalize environment name
  local env_lower=$(echo "$environment" | tr '[:upper:]' '[:lower:]')

  # NOTE: We accept ANY environment name. The calling skill (infra-deployer) is responsible
  # for determining whether confirmation is required based on the require_confirmation config.
  # This script assumes it's being called for an environment that needs confirmation.

  # Log common production environment names if detected
  case "$env_lower" in
    prod|production|live|prd)
      log_info "Detected common production environment name: $environment"
      ;;
    *)
      log_warning "Environment name '$environment' - ensure this is correct"
      log_warning "This confirmation protocol is intended for production environments"
      ;;
  esac

  # Check for CI/CD environment bypass
  if check_ci_environment; then
    audit_log "DEPLOYMENT APPROVED: CI/CD bypass via DEVOPS_AUTO_APPROVE=true"
    log_success "Production deployment approved via CI/CD configuration"
    exit 0
  fi

  # Execute confirmation protocol
  if execute_confirmation_protocol "$environment" "$operation" "$plan_summary"; then
    # Success
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║              ✅  PRODUCTION DEPLOYMENT APPROVED  ✅            ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_success "Proceeding with production deployment..."
    echo ""
    exit 0
  else
    # User declined or failed confirmation
    exit 1
  fi
}

# Run main function
main "$@"
