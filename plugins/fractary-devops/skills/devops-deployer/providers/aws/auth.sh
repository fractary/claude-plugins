#!/bin/bash
# aws/auth.sh
# AWS authentication and credential validation

set -euo pipefail

# Authenticate with AWS for specified environment
authenticate_provider() {
    local environment="$1"

    echo "Authenticating with AWS..."

    # Get AWS profile for environment
    local aws_profile=$(get_aws_profile "$environment")

    if [ -z "$aws_profile" ]; then
        echo "❌ AWS profile not configured for environment: $environment"
        return 1
    fi

    # Set AWS profile
    export AWS_PROFILE="$aws_profile"

    # Validate credentials
    if ! AWS_PROFILE="$aws_profile" aws sts get-caller-identity >/dev/null 2>&1; then
        echo "❌ AWS credentials invalid for profile: $aws_profile"
        echo "   Run: aws configure --profile $aws_profile"
        return 1
    fi

    # Get account info
    local account_id=$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)
    local user_arn=$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Arn --output text)

    echo "✓ Authenticated with AWS"
    echo "  Profile: $aws_profile"
    echo "  Account: $account_id"
    echo "  User: $user_arn"

    return 0
}

# Validate AWS CLI is installed
validate_aws_cli() {
    if ! command -v aws >/dev/null 2>&1; then
        echo "❌ AWS CLI not installed"
        echo "   Install: https://aws.amazon.com/cli/"
        return 1
    fi

    local aws_version=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
    echo "✓ AWS CLI installed: v$aws_version"
    return 0
}

# Check if AWS profile exists
profile_exists() {
    local profile_name="$1"

    if aws configure list-profiles 2>/dev/null | grep -q "^${profile_name}$"; then
        return 0
    else
        return 1
    fi
}

# Get AWS account ID for current credentials
get_aws_account_id() {
    aws sts get-caller-identity --query Account --output text 2>/dev/null || echo ""
}

# Get AWS region from profile or default
get_aws_region() {
    local profile="${1:-$AWS_PROFILE}"

    if [ -n "$profile" ]; then
        aws configure get region --profile "$profile" 2>/dev/null || echo "$AWS_REGION"
    else
        echo "$AWS_REGION"
    fi
}

# Validate AWS credentials for all configured environments
validate_all_profiles() {
    local all_valid=true

    echo "Validating AWS profiles..."

    # Test discover profile
    if [ -n "$PROFILE_DISCOVER" ]; then
        if profile_exists "$PROFILE_DISCOVER"; then
            if AWS_PROFILE="$PROFILE_DISCOVER" aws sts get-caller-identity >/dev/null 2>&1; then
                echo "  ✓ Discover profile valid: $PROFILE_DISCOVER"
            else
                echo "  ❌ Discover profile invalid: $PROFILE_DISCOVER"
                all_valid=false
            fi
        else
            echo "  ⚠️  Discover profile not found: $PROFILE_DISCOVER"
        fi
    fi

    # Test test profile
    if [ -n "$PROFILE_TEST" ]; then
        if profile_exists "$PROFILE_TEST"; then
            if AWS_PROFILE="$PROFILE_TEST" aws sts get-caller-identity >/dev/null 2>&1; then
                echo "  ✓ Test profile valid: $PROFILE_TEST"
            else
                echo "  ❌ Test profile invalid: $PROFILE_TEST"
                all_valid=false
            fi
        else
            echo "  ⚠️  Test profile not found: $PROFILE_TEST"
        fi
    fi

    # Test prod profile
    if [ -n "$PROFILE_PROD" ]; then
        if profile_exists "$PROFILE_PROD"; then
            if AWS_PROFILE="$PROFILE_PROD" aws sts get-caller-identity >/dev/null 2>&1; then
                echo "  ✓ Prod profile valid: $PROFILE_PROD"
            else
                echo "  ❌ Prod profile invalid: $PROFILE_PROD"
                all_valid=false
            fi
        else
            echo "  ⚠️  Prod profile not found: $PROFILE_PROD"
        fi
    fi

    if $all_valid; then
        return 0
    else
        return 1
    fi
}
