#!/bin/bash
# audit-security.sh - Security posture and compliance checks
# Usage: audit-security.sh --env <environment>

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
init_audit_report "$ENVIRONMENT" "security"
generate_report_header "security" "$ENVIRONMENT"
init_json_report "security" "$ENVIRONMENT"

# Validate AWS credentials
if ! validate_aws_credentials; then
    log_error "Cannot proceed without valid AWS credentials"
    exit 1
fi

log_info "Starting security posture audit for ${ENVIRONMENT}"

# Check 1: Open security groups
log_info "Checking security groups for overly permissive rules..."
SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Project,Values=${DEVOPS_PROJECT_NAME}" \
    --profile "$AWS_PROFILE" 2>/dev/null || echo '{"SecurityGroups":[]}')

OPEN_SSH=0
OPEN_RDP=0
OPEN_ALL=0

# Use process substitution to avoid subshell variable scope issues
while read -r sg; do
    SG_ID=$(echo "$sg" | jq -r '.GroupId')
    SG_NAME=$(echo "$sg" | jq -r '.GroupName')

    # Check for 0.0.0.0/0 or ::/0 rules
    OPEN_RULES=$(echo "$sg" | jq -c '.IpPermissions[] | select(.IpRanges[]?.CidrIp == "0.0.0.0/0" or .Ipv6Ranges[]?.CidrIpv6 == "::/0")')

    if [[ -n "$OPEN_RULES" ]]; then
        # Check specific ports
        SSH_OPEN=$(echo "$OPEN_RULES" | jq -r 'select(.FromPort == 22 or .ToPort == 22)' 2>/dev/null || echo "")
        RDP_OPEN=$(echo "$OPEN_RULES" | jq -r 'select(.FromPort == 3389 or .ToPort == 3389)' 2>/dev/null || echo "")
        ALL_OPEN=$(echo "$OPEN_RULES" | jq -r 'select(.IpProtocol == "-1")' 2>/dev/null || echo "")

        if [[ -n "$SSH_OPEN" ]]; then
            OPEN_SSH=$((OPEN_SSH + 1))
            log_warning "  SSH (port 22) open to internet in ${SG_NAME} (${SG_ID})"
        fi

        if [[ -n "$RDP_OPEN" ]]; then
            OPEN_RDP=$((OPEN_RDP + 1))
            log_warning "  RDP (port 3389) open to internet in ${SG_NAME} (${SG_ID})"
        fi

        if [[ -n "$ALL_OPEN" ]]; then
            OPEN_ALL=$((OPEN_ALL + 1))
            log_warning "  All ports open to internet in ${SG_NAME} (${SG_ID})"
        fi
    fi
done < <(echo "$SECURITY_GROUPS" | jq -c '.SecurityGroups[]')

if [[ $OPEN_SSH -gt 0 || $OPEN_RDP -gt 0 || $OPEN_ALL -gt 0 ]]; then
    add_check_result "Security Group Rules" "fail" "Open to internet: ${OPEN_SSH} SSH, ${OPEN_RDP} RDP, ${OPEN_ALL} all ports"
    add_recommendation "critical" "Restrict security groups to specific IP ranges, not 0.0.0.0/0"
else
    add_check_result "Security Group Rules" "pass" "No overly permissive security group rules detected"
fi

add_metric "open_ssh_rules" "$OPEN_SSH"
add_metric "open_rdp_rules" "$OPEN_RDP"
add_metric "open_all_rules" "$OPEN_ALL"

# Check 2: S3 bucket public access
log_info "Checking S3 buckets for public access..."
S3_BUCKETS=$(aws s3api list-buckets --profile "$AWS_PROFILE" 2>/dev/null | \
    jq -r '.Buckets[] | select(.Name | startswith("'${DEVOPS_PROJECT_NAME}'")) | .Name' || echo "")

PUBLIC_BUCKETS=0
for bucket in $S3_BUCKETS; do
    # Check public access block
    PUBLIC_ACCESS=$(aws s3api get-public-access-block --bucket "$bucket" --profile "$AWS_PROFILE" 2>/dev/null || echo '{"PublicAccessBlockConfiguration":{"BlockPublicAcls":false}}')

    BLOCK_PUBLIC_ACLS=$(echo "$PUBLIC_ACCESS" | jq -r '.PublicAccessBlockConfiguration.BlockPublicAcls')
    BLOCK_PUBLIC_POLICY=$(echo "$PUBLIC_ACCESS" | jq -r '.PublicAccessBlockConfiguration.BlockPublicPolicy')

    if [[ "$BLOCK_PUBLIC_ACLS" == "false" || "$BLOCK_PUBLIC_POLICY" == "false" ]]; then
        PUBLIC_BUCKETS=$((PUBLIC_BUCKETS + 1))
        log_warning "  Bucket ${bucket} may allow public access"
    fi
done

if [[ $PUBLIC_BUCKETS -gt 0 ]]; then
    add_check_result "S3 Public Access" "fail" "${PUBLIC_BUCKETS} buckets may allow public access"
    add_recommendation "critical" "Enable S3 public access block on all buckets"
else
    add_check_result "S3 Public Access" "pass" "All S3 buckets have public access blocked"
fi

add_metric "public_s3_buckets" "$PUBLIC_BUCKETS"

# Check 3: S3 bucket encryption
log_info "Checking S3 bucket encryption..."
UNENCRYPTED_BUCKETS=0
for bucket in $S3_BUCKETS; do
    ENCRYPTION=$(aws s3api get-bucket-encryption --bucket "$bucket" --profile "$AWS_PROFILE" 2>/dev/null || echo "none")

    if [[ "$ENCRYPTION" == "none" ]]; then
        UNENCRYPTED_BUCKETS=$((UNENCRYPTED_BUCKETS + 1))
        log_warning "  Bucket ${bucket} is not encrypted"
    fi
done

if [[ $UNENCRYPTED_BUCKETS -gt 0 ]]; then
    add_check_result "S3 Encryption" "warn" "${UNENCRYPTED_BUCKETS} buckets without encryption"
    add_recommendation "important" "Enable default encryption on all S3 buckets"
else
    add_check_result "S3 Encryption" "pass" "All S3 buckets have encryption enabled"
fi

add_metric "unencrypted_s3_buckets" "$UNENCRYPTED_BUCKETS"

# Check 4: RDS encryption
log_info "Checking RDS encryption..."
RDS_INSTANCES=$(aws rds describe-db-instances --profile "$AWS_PROFILE" 2>/dev/null | \
    jq -r '.DBInstances[] | select(.DBInstanceIdentifier | startswith("'${DEVOPS_PROJECT_NAME}'")) | .DBInstanceIdentifier' || echo "")

UNENCRYPTED_RDS=0
for instance in $RDS_INSTANCES; do
    ENCRYPTED=$(aws rds describe-db-instances \
        --db-instance-identifier "$instance" \
        --profile "$AWS_PROFILE" 2>/dev/null | \
        jq -r '.DBInstances[0].StorageEncrypted')

    if [[ "$ENCRYPTED" != "true" ]]; then
        UNENCRYPTED_RDS=$((UNENCRYPTED_RDS + 1))
        log_warning "  RDS instance ${instance} is not encrypted"
    fi
done

if [[ $UNENCRYPTED_RDS -gt 0 ]]; then
    add_check_result "RDS Encryption" "fail" "${UNENCRYPTED_RDS} RDS instances without encryption"
    add_recommendation "critical" "Enable encryption on all RDS instances"
else
    add_check_result "RDS Encryption" "pass" "All RDS instances are encrypted"
fi

add_metric "unencrypted_rds_instances" "$UNENCRYPTED_RDS"

# Check 5: IAM password policy
log_info "Checking IAM password policy..."
PASSWORD_POLICY=$(aws iam get-account-password-policy --profile "$AWS_PROFILE" 2>/dev/null || echo '{"PasswordPolicy":{}}')

MIN_LENGTH=$(echo "$PASSWORD_POLICY" | jq -r '.PasswordPolicy.MinimumPasswordLength // 0')
REQUIRE_SYMBOLS=$(echo "$PASSWORD_POLICY" | jq -r '.PasswordPolicy.RequireSymbols // false')
REQUIRE_NUMBERS=$(echo "$PASSWORD_POLICY" | jq -r '.PasswordPolicy.RequireNumbers // false')
REQUIRE_UPPERCASE=$(echo "$PASSWORD_POLICY" | jq -r '.PasswordPolicy.RequireUppercaseCharacters // false')
REQUIRE_LOWERCASE=$(echo "$PASSWORD_POLICY" | jq -r '.PasswordPolicy.RequireLowercaseCharacters // false')

POLICY_WEAK=false
if [[ $MIN_LENGTH -lt 12 ]]; then
    POLICY_WEAK=true
fi

if [[ "$REQUIRE_SYMBOLS" != "true" || "$REQUIRE_NUMBERS" != "true" || "$REQUIRE_UPPERCASE" != "true" || "$REQUIRE_LOWERCASE" != "true" ]]; then
    POLICY_WEAK=true
fi

if [[ "$POLICY_WEAK" == "true" ]]; then
    add_check_result "IAM Password Policy" "warn" "Password policy is weak (min length: ${MIN_LENGTH}, complexity requirements not met)"
    add_recommendation "important" "Strengthen IAM password policy: min 12 chars, require symbols, numbers, upper/lowercase"
else
    add_check_result "IAM Password Policy" "pass" "Strong password policy configured"
fi

# Check 6: CloudTrail logging
log_info "Checking CloudTrail configuration..."
TRAILS=$(aws cloudtrail describe-trails --profile "$AWS_PROFILE" 2>/dev/null | jq -r '.trailList | length' || echo "0")

if [[ $TRAILS -eq 0 ]]; then
    add_check_result "CloudTrail Logging" "fail" "No CloudTrail trails configured"
    add_recommendation "critical" "Enable CloudTrail for audit logging and compliance"
else
    add_check_result "CloudTrail Logging" "pass" "${TRAILS} CloudTrail trail(s) configured"
fi

add_metric "cloudtrail_trails" "$TRAILS"

# Check 7: Resource tagging compliance
log_info "Checking resource tagging compliance..."
REQUIRED_TAGS=("Environment" "Project" "ManagedBy")
UNTAGGED_RESOURCES=0

# Check EC2 instances
EC2_INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --profile "$AWS_PROFILE" 2>/dev/null || echo '{"Reservations":[]}')

# Use process substitution to avoid subshell variable scope issues
while read -r instance; do
    TAGS=$(echo "$instance" | jq -r '.Tags[]? | .Key')

    for required_tag in "${REQUIRED_TAGS[@]}"; do
        if ! echo "$TAGS" | grep -q "^${required_tag}$"; then
            UNTAGGED_RESOURCES=$((UNTAGGED_RESOURCES + 1))
            break
        fi
    done
done < <(echo "$EC2_INSTANCES" | jq -c '.Reservations[].Instances[]')

if [[ $UNTAGGED_RESOURCES -gt 0 ]]; then
    add_check_result "Resource Tagging" "warn" "${UNTAGGED_RESOURCES} resources missing required tags"
    add_recommendation "optimization" "Add required tags (Environment, Project, ManagedBy) to all resources"
else
    add_check_result "Resource Tagging" "pass" "All resources have required tags"
fi

add_metric "untagged_resources" "$UNTAGGED_RESOURCES"

# Finalize report
finalize_report

log_success "Security posture audit complete"

# Return appropriate exit code
get_exit_code
exit $?
