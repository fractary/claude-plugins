#!/bin/bash
# production-safety-confirm.sh - Production deployment confirmation protocol
#
# Enforces production safety by requiring explicit user confirmation before
# deploying to production environments. Implements 2-question protocol.
#
# Usage: production-safety-confirm.sh <environment> <operation> [plan_summary]
#
# Arguments:
#   environment    - Target environment (prod, production, etc.)
#   operation      - Operation being performed (deploy, apply, etc.)
#   plan_summary   - Optional: Path to file containing plan summary
#
# Exit Codes:
#   0 - User confirmed, safe to proceed
#   1 - User declined or invalid response, abort operation
#   2 - Invalid arguments or configuration error
#
# Environment Variables (optional):
#   DEVOPS_AUTO_APPROVE - If "true", skip confirmations (NOT recommended for production)
#   CI                  - If set, indicates CI/CD environment (requires explicit bypass)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
  echo -e "${RED}${BOLD}This will affect the PRODUCTION environment.${NC}"
  echo ""
}

# Function: Ask yes/no question
ask_yes_no() {
  local question="$1"
  local response

  echo -e "${YELLOW}${question}${NC}"
  read -r -p "Answer (yes/no): " response

  # Normalize response
  response=$(echo "$response" | tr '[:upper:]' '[:lower:]' | xargs)

  if [[ "$response" == "yes" || "$response" == "y" ]]; then
    return 0
  elif [[ "$response" == "no" || "$response" == "n" ]]; then
    return 1
  else
    log_error "Invalid response: '$response' (expected: yes/no)"
    return 1
  fi
}

# Function: Ask for typed confirmation
ask_typed_confirmation() {
  local expected="$1"
  local prompt="$2"
  local response

  echo ""
  echo -e "${YELLOW}${prompt}${NC}"
  read -r -p "Type exactly: " response

  if [[ "$response" == "$expected" ]]; then
    return 0
  else
    log_error "Confirmation failed. Expected '${expected}', got '${response}'"
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

  echo ""
  echo "─────────────────────────────────────────────────────────────"
  echo -e "${BLUE}Deployment Plan Summary:${NC}"
  echo "─────────────────────────────────────────────────────────────"
  cat "$plan_file"
  echo "─────────────────────────────────────────────────────────────"
  echo ""
}

# Function: Display abort message
display_abort_message() {
  local reason="$1"

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

  if ! ask_yes_no "Have you validated this deployment in TEST environment and are ready to deploy to PRODUCTION?"; then
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
  echo -e "${YELLOW}This deployment will affect live production systems.${NC}"
  echo ""

  local env_lower=$(echo "$environment" | tr '[:upper:]' '[:lower:]')
  if ! ask_typed_confirmation "$env_lower" "Type '${env_lower}' to confirm deployment to ${environment^^}:"; then
    display_abort_message "User failed typed confirmation"
    return 1
  fi

  echo ""
  log_success "Production deployment confirmed"
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

  # Normalize environment name
  local env_lower=$(echo "$environment" | tr '[:upper:]' '[:lower:]')

  # Check if this is actually a production environment
  if [[ "$env_lower" != "prod" && "$env_lower" != "production" ]]; then
    log_error "This script is for production environments only"
    log_error "Environment '$environment' does not appear to be production"
    exit 2
  fi

  # Check for CI/CD environment bypass
  if check_ci_environment; then
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
