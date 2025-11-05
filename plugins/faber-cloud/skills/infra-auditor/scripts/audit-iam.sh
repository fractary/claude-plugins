#!/bin/bash
# audit-iam.sh - Audit IAM users, roles, and permissions health
# Usage: audit-iam.sh --env <environment>

set -euo pipefail

# Source report generator
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/report-generator.sh"

# Check dependencies before proceeding
if ! check_dependencies; then
    exit 1
fi

# Parse arguments
ENVIRONMENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            if [[ $# -lt 2 || "$2" =~ ^-- ]]; then
                echo "Error: --env requires a value" >&2
                exit 2
            fi
            ENVIRONMENT="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: $0 --env <environment>" >&2
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ -z "$ENVIRONMENT" ]]; then
    log_error "Environment not specified"
    exit 1
fi

# Initialize audit report
init_audit_report "$ENVIRONMENT" "iam-health"
generate_report_header "iam-health" "$ENVIRONMENT"
init_json_report "iam-health" "$ENVIRONMENT"

# Validate AWS credentials
if ! validate_aws_credentials; then
    log_error "Cannot proceed without valid AWS credentials"
    exit 1
fi

log_info "Starting IAM health audit for ${ENVIRONMENT}"

# Check 1: Verify deploy user exists
log_info "Checking deploy user..."
DEPLOY_USER="${DEVOPS_PROJECT_NAME}-${DEVOPS_PROJECT_SUBSYSTEM}-${ENVIRONMENT}-deploy"
if aws iam get-user --user-name "$DEPLOY_USER" --profile "$AWS_PROFILE" &>/dev/null; then
    add_check_result "Deploy User Exists" "pass" "User ${DEPLOY_USER} exists"
else
    add_check_result "Deploy User Exists" "fail" "User ${DEPLOY_USER} not found"
    add_recommendation "critical" "Create deploy user: ${DEPLOY_USER}"
fi

# Check 2: Check access key age
log_info "Checking access key age..."
ACCESS_KEYS=$(aws iam list-access-keys --user-name "$DEPLOY_USER" --profile "$AWS_PROFILE" 2>/dev/null || echo '{"AccessKeyMetadata":[]}')
KEY_COUNT=$(echo "$ACCESS_KEYS" | jq '.AccessKeyMetadata | length')

if [[ $KEY_COUNT -eq 0 ]]; then
    add_check_result "Access Keys" "warn" "No access keys found for ${DEPLOY_USER}"
    add_recommendation "important" "Create access keys for deployment user"
else
    add_metric "access_key_count" "$KEY_COUNT"

    # Check key age (warn if > 90 days old)
    CURRENT_DATE=$(date +%s)
    OLD_KEYS=0

    # Use process substitution to avoid subshell variable scope issues
    while read -r key; do
        KEY_ID=$(echo "$key" | jq -r '.AccessKeyId')
        CREATE_DATE=$(echo "$key" | jq -r '.CreateDate')
        CREATE_TIMESTAMP=$(date -d "$CREATE_DATE" +%s 2>/dev/null || echo "0")
        AGE_DAYS=$(( (CURRENT_DATE - CREATE_TIMESTAMP) / 86400 ))

        if [[ $AGE_DAYS -gt 90 ]]; then
            OLD_KEYS=$((OLD_KEYS + 1))
        fi
    done < <(echo "$ACCESS_KEYS" | jq -c '.AccessKeyMetadata[]')

    if [[ $OLD_KEYS -gt 0 ]]; then
        add_check_result "Access Key Age" "warn" "${OLD_KEYS} access keys are older than 90 days"
        add_recommendation "important" "Rotate access keys older than 90 days"
    else
        add_check_result "Access Key Age" "pass" "All access keys are recent (< 90 days)"
    fi
fi

# Check 3: Check for required IAM roles
log_info "Checking IAM roles..."
EXPECTED_ROLES=(
    "${DEVOPS_PROJECT_NAME}-${DEVOPS_PROJECT_SUBSYSTEM}-${ENVIRONMENT}-lambda-role"
    "${DEVOPS_PROJECT_NAME}-${DEVOPS_PROJECT_SUBSYSTEM}-${ENVIRONMENT}-ecs-role"
)

MISSING_ROLES=0
for role in "${EXPECTED_ROLES[@]}"; do
    if aws iam get-role --role-name "$role" --profile "$AWS_PROFILE" &>/dev/null; then
        log_info "  ✓ Role exists: $role"
    else
        log_warning "  ✗ Role missing: $role"
        MISSING_ROLES=$((MISSING_ROLES + 1))
    fi
done

if [[ $MISSING_ROLES -eq 0 ]]; then
    add_check_result "Service Roles" "pass" "All expected service roles exist"
else
    add_check_result "Service Roles" "warn" "${MISSING_ROLES} expected service roles not found"
    add_recommendation "important" "Create missing service roles"
fi

# Check 4: Check for unused IAM resources
log_info "Checking for unused IAM resources..."
ALL_USERS=$(aws iam list-users --profile "$AWS_PROFILE" 2>/dev/null | jq -r '.Users[].UserName' || echo "")
PROJECT_PREFIX="${DEVOPS_PROJECT_NAME}-${DEVOPS_PROJECT_SUBSYSTEM}"
UNUSED_USERS=0

for user in $ALL_USERS; do
    if [[ "$user" =~ ^${PROJECT_PREFIX} ]]; then
        # Check last activity
        LAST_USED=$(aws iam get-user --user-name "$user" --profile "$AWS_PROFILE" 2>/dev/null | jq -r '.User.PasswordLastUsed // "never"')
        if [[ "$LAST_USED" == "never" ]]; then
            UNUSED_USERS=$((UNUSED_USERS + 1))
        fi
    fi
done

if [[ $UNUSED_USERS -eq 0 ]]; then
    add_check_result "Unused IAM Users" "pass" "No unused IAM users detected"
else
    add_check_result "Unused IAM Users" "warn" "${UNUSED_USERS} unused IAM users found"
    add_recommendation "optimization" "Remove or review unused IAM users"
fi

# Check 5: Check MFA on IAM users
log_info "Checking MFA configuration..."
MFA_ENABLED=0
MFA_DISABLED=0

for user in $ALL_USERS; do
    if [[ "$user" =~ ^${PROJECT_PREFIX} ]]; then
        MFA_DEVICES=$(aws iam list-mfa-devices --user-name "$user" --profile "$AWS_PROFILE" 2>/dev/null | jq '.MFADevices | length' || echo "0")
        if [[ $MFA_DEVICES -gt 0 ]]; then
            MFA_ENABLED=$((MFA_ENABLED + 1))
        else
            MFA_DISABLED=$((MFA_DISABLED + 1))
        fi
    fi
done

if [[ $MFA_DISABLED -eq 0 ]]; then
    add_check_result "MFA Configuration" "pass" "All users have MFA enabled"
else
    add_check_result "MFA Configuration" "warn" "${MFA_DISABLED} users without MFA"
    add_recommendation "important" "Enable MFA for all IAM users"
fi

add_metric "mfa_enabled_users" "$MFA_ENABLED"
add_metric "mfa_disabled_users" "$MFA_DISABLED"

# Check 6: Check IAM policy attachments
log_info "Checking IAM policy attachments..."
ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name "$DEPLOY_USER" --profile "$AWS_PROFILE" 2>/dev/null | jq '.AttachedPolicies | length' || echo "0")
add_check_result "IAM Policy Attachments" "pass" "${ATTACHED_POLICIES} policies attached to deploy user"
add_metric "attached_policies" "$ATTACHED_POLICIES"

# Finalize report
finalize_report

log_success "IAM health audit complete"

# Return appropriate exit code
get_exit_code
exit $?
