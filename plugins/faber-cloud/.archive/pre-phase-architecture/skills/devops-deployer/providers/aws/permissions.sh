#!/bin/bash
# aws/permissions.sh
# AWS IAM permission management for deploy users

set -euo pipefail

# Add permission to deploy user
add_deployment_permission() {
    local permission="$1"
    local environment="$2"
    local reason="${3:-Required for deployment}"
    local terraform_error="${4:-}"

    echo "Adding deployment permission: $permission"

    # Resolve IAM user and policy names
    local user_name=$(resolve_pattern "$USER_NAME_PATTERN" "$environment")
    local policy_name=$(resolve_pattern "$POLICY_NAME_PATTERN" "$environment")

    # Use discover profile for IAM operations
    local original_profile="$AWS_PROFILE"
    export AWS_PROFILE="$PROFILE_DISCOVER"

    echo "  User: $user_name"
    echo "  Policy: $policy_name"

    # Call update-audit.sh script if it exists
    local audit_script="$IAM_POLICIES_DIR/scripts/update-audit.sh"

    if [ -f "$audit_script" ]; then
        bash "$audit_script" \
            "$environment" \
            "[\"$permission\"]" \
            "$reason" \
            "$terraform_error"
    else
        echo "⚠️  IAM audit script not found: $audit_script"
        echo "   Adding permission directly to AWS..."

        # Fetch current policy
        local policy_doc=$(aws iam get-user-policy \
            --user-name "$user_name" \
            --policy-name "$policy_name" \
            --query 'PolicyDocument' \
            --output json 2>/dev/null || echo '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":[],"Resource":"*"}]}')

        # Add permission to actions array
        local updated_policy=$(echo "$policy_doc" | jq ".Statement[0].Action += [\"$permission\"] | .Statement[0].Action |= unique")

        # Update policy
        aws iam put-user-policy \
            --user-name "$user_name" \
            --policy-name "$policy_name" \
            --policy-document "$updated_policy"

        echo "✓ Permission added to AWS"
    fi

    # Restore original profile
    export AWS_PROFILE="$original_profile"

    return 0
}

# Verify permission exists for deploy user
verify_permission() {
    local permission="$1"
    local environment="$2"

    local user_name=$(resolve_pattern "$USER_NAME_PATTERN" "$environment")
    local policy_name=$(resolve_pattern "$POLICY_NAME_PATTERN" "$environment")

    # Use discover profile
    export AWS_PROFILE="$PROFILE_DISCOVER"

    # Get policy document
    local policy_doc=$(aws iam get-user-policy \
        --user-name "$user_name" \
        --policy-name "$policy_name" \
        --query 'PolicyDocument.Statement[0].Action' \
        --output json 2>/dev/null || echo '[]')

    # Check if permission exists
    if echo "$policy_doc" | jq -e ". | index(\"$permission\")" >/dev/null; then
        return 0
    else
        return 1
    fi
}

# List all permissions for deploy user
list_permissions() {
    local environment="$1"

    local user_name=$(resolve_pattern "$USER_NAME_PATTERN" "$environment")
    local policy_name=$(resolve_pattern "$POLICY_NAME_PATTERN" "$environment")

    echo "Permissions for $user_name:"

    # Use discover profile
    export AWS_PROFILE="$PROFILE_DISCOVER"

    # Get policy document
    local actions=$(aws iam get-user-policy \
        --user-name "$user_name" \
        --policy-name "$policy_name" \
        --query 'PolicyDocument.Statement[0].Action' \
        --output json 2>/dev/null || echo '[]')

    # Display permissions
    echo "$actions" | jq -r '.[]' | sort | sed 's/^/  - /'
}

# Check if user has required permissions
check_required_permissions() {
    local environment="$1"
    shift
    local required_permissions=("$@")

    local user_name=$(resolve_pattern "$USER_NAME_PATTERN" "$environment")
    local policy_name=$(resolve_pattern "$POLICY_NAME_PATTERN" "$environment")

    echo "Checking required permissions for $user_name..."

    # Use discover profile
    export AWS_PROFILE="$PROFILE_DISCOVER"

    # Get policy document
    local actions=$(aws iam get-user-policy \
        --user-name "$user_name" \
        --policy-name "$policy_name" \
        --query 'PolicyDocument.Statement[0].Action' \
        --output json 2>/dev/null || echo '[]')

    local missing=()

    for perm in "${required_permissions[@]}"; do
        if ! echo "$actions" | jq -e ". | index(\"$perm\")" >/dev/null; then
            missing+=("$perm")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        echo "✓ All required permissions present"
        return 0
    else
        echo "❌ Missing permissions:"
        for perm in "${missing[@]}"; do
            echo "  - $perm"
        done
        return 1
    fi
}
