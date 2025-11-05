#!/usr/bin/env bash
set -euo pipefail

# load-context.sh
# Loads context from various sources (design docs, FABER specs, direct instructions)
# Usage: ./load-context.sh '{"source_type":"...","file_path":"...","instructions":"...","additional_context":"..."}'
# Output: JSON with source_content, requirements, mode, config

PARSE_RESULT="${1:-}"

if [ -z "$PARSE_RESULT" ]; then
    echo '{"error": "Missing parse result JSON"}' >&2
    exit 1
fi

# Extract values from JSON
SOURCE_TYPE=$(echo "$PARSE_RESULT" | jq -r '.source_type')
FILE_PATH=$(echo "$PARSE_RESULT" | jq -r '.file_path')
INSTRUCTIONS=$(echo "$PARSE_RESULT" | jq -r '.instructions')
ADDITIONAL_CONTEXT=$(echo "$PARSE_RESULT" | jq -r '.additional_context')

# Configuration
CONFIG_FILE=".fractary/plugins/faber-cloud/config/devops.json"
TF_DIR="./infrastructure/terraform"

# Load configuration if available
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        jq -r '{
            project_name: .project.name,
            subsystem: .project.subsystem,
            aws_region: (.cloud.aws.region // "us-east-1")
        }' "$CONFIG_FILE"
    else
        echo '{
            "project_name": "myproject",
            "subsystem": "core",
            "aws_region": "us-east-1"
        }'
    fi
}

# Check if Terraform already exists
check_mode() {
    if [ -d "$TF_DIR" ] && [ -f "$TF_DIR/main.tf" ]; then
        echo "update"
    else
        echo "create"
    fi
}

# Load source content
load_source_content() {
    case "$SOURCE_TYPE" in
        design_file|faber_spec|latest_design)
            if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
                echo '{"error": "Source file not found or empty path"}' >&2
                exit 1
            fi

            # Check file is not empty
            if [ ! -s "$FILE_PATH" ]; then
                echo "{\"error\": \"Source file is empty: $FILE_PATH\"}" >&2
                exit 1
            fi

            # Read file content
            cat "$FILE_PATH"
            ;;

        direct_instructions)
            # No file - return instructions
            echo "$INSTRUCTIONS"
            ;;

        *)
            echo "{\"error\": \"Unknown source type: $SOURCE_TYPE\"}" >&2
            exit 1
            ;;
    esac
}

# Extract infrastructure requirements from source
# This is a simple version - in practice, would be more sophisticated
extract_requirements() {
    local content="$1"
    local source_type="$2"

    # Initialize requirements array
    local resources='[]'

    # Basic keyword detection (simplified - real implementation would be more robust)
    if echo "$content" | grep -qi 's3\|bucket'; then
        resources=$(echo "$resources" | jq '. += ["s3_bucket"]')
    fi

    if echo "$content" | grep -qi 'lambda\|function'; then
        resources=$(echo "$resources" | jq '. += ["lambda_function", "iam_role"]')
    fi

    if echo "$content" | grep -qi 'dynamodb\|table\|database'; then
        resources=$(echo "$resources" | jq '. += ["dynamodb_table"]')
    fi

    if echo "$content" | grep -qi 'api gateway\|api\|endpoint'; then
        resources=$(echo "$resources" | jq '. += ["api_gateway"]')
    fi

    if echo "$content" | grep -qi 'cloudfront\|cdn'; then
        resources=$(echo "$resources" | jq '. += ["cloudfront_distribution"]')
    fi

    if echo "$content" | grep -qi 'iam\|permission\|policy\|role'; then
        resources=$(echo "$resources" | jq '. += ["iam_role", "iam_policy"]')
    fi

    # Deduplicate
    resources=$(echo "$resources" | jq 'unique')

    # Build requirements object
    jq -n \
        --argjson resources "$resources" \
        '{
            resources: $resources,
            relationships: [],
            security: ["encryption", "least_privilege"],
            monitoring: ["cloudwatch_logs"]
        }'
}

# Main logic
main() {
    # Load source content
    local source_content
    source_content=$(load_source_content)

    # Extract requirements
    local requirements
    requirements=$(extract_requirements "$source_content" "$SOURCE_TYPE")

    # Load configuration
    local config
    config=$(load_config)

    # Determine mode
    local mode
    mode=$(check_mode)

    # Build output JSON
    jq -n \
        --arg source_type "$SOURCE_TYPE" \
        --arg source_path "$FILE_PATH" \
        --arg mode "$mode" \
        --arg source_content "$source_content" \
        --argjson requirements "$requirements" \
        --argjson config "$config" \
        --arg additional_context "$ADDITIONAL_CONTEXT" \
        '{
            source_type: $source_type,
            source_path: $source_path,
            mode: $mode,
            source_content: $source_content,
            requirements: $requirements,
            config: $config,
            additional_context: $additional_context
        }'
}

main
