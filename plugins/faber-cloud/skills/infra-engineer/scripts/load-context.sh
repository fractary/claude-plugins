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

# Configuration (parameterized for testability)
CONFIG_FILE="${FABER_CLOUD_CONFIG_FILE:-.fractary/plugins/faber-cloud/devops.json}"
TF_DIR="${FABER_CLOUD_TF_DIR:-./infrastructure/terraform}"

# Detect stat platform once for performance (LOW PRIORITY optimization)
STAT_FORMAT=""
if command -v stat &> /dev/null; then
    # Test GNU stat format (Linux)
    if stat --format='%Y' /dev/null 2>/dev/null | grep -q '^[0-9]'; then
        STAT_FORMAT="gnu"
    # Test BSD stat format (macOS)
    elif stat -f '%m' /dev/null 2>/dev/null | grep -q '^[0-9]'; then
        STAT_FORMAT="bsd"
    fi
fi

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

            # Validate file size (max 10MB = 10485760 bytes)
            # Use cached platform detection for performance
            local file_size=0
            case "$STAT_FORMAT" in
                gnu)
                    file_size=$(stat --format='%s' "$FILE_PATH" 2>/dev/null || echo "0")
                    ;;
                bsd)
                    file_size=$(stat -f '%z' "$FILE_PATH" 2>/dev/null || echo "0")
                    ;;
                *)
                    # Fallback: use wc -c (portable but slower)
                    file_size=$(wc -c < "$FILE_PATH" 2>/dev/null || echo "0")
                    ;;
            esac

            # Check against 10MB limit
            if [ "$file_size" -gt 10485760 ]; then
                local size_mb=$((file_size / 1048576))
                jq -n \
                    --arg error "Source file too large: ${size_mb}MB (max 10MB)" \
                    --arg path "$FILE_PATH" \
                    --arg suggestion "Split the file into smaller documents or use direct instructions" \
                    '{error: $error, path: $path, suggestion: $suggestion}' >&2
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
# IMPORTANT: This is a basic regex-based extractor with known limitations:
#   - Only detects common AWS services (S3, Lambda, DynamoDB, API Gateway, CloudFront, IAM)
#   - Does NOT detect: VPC, ECS, EKS, RDS, SQS, SNS, EventBridge, Step Functions, etc.
#   - May have false positives despite word boundaries
#   - Primarily used as a fallback; LLM-based generation is more accurate
#
# For production use, consider:
#   - Relying on LLM to interpret requirements during Terraform generation
#   - Expanding this list to cover more AWS services
#   - Using a more sophisticated parser
#
# TODO (LOW PRIORITY): Replace regex-based extraction with HCL parsing
#   - Current approach: grep patterns on natural language
#   - Future approach: Parse HCL/Terraform files using hcl2json or similar
#   - Benefits: More accurate detection, no false positives, structured data
#   - Tools: hcl2json, terraform show -json, or go-hcl parser
#   - Use case: When processing existing Terraform rather than design docs
#
# SECURITY NOTE: source_content is passed via jq --arg which is safe.
# DO NOT use this variable in eval or direct bash substitution as it could be dangerous.
extract_requirements() {
    local content="$1"
    local source_type="$2"

    # Initialize requirements array
    local resources='[]'

    # Performance optimization: Cache lowercase content for large files
    # Using here-string (<<<) instead of piping echo reduces overhead
    local content_lower
    content_lower=$(echo "$content" | tr '[:upper:]' '[:lower:]')

    # Basic keyword detection with word boundaries to prevent false matches
    # Using grep -E for extended regex with \b word boundaries
    # NOTE: This list is intentionally limited - expand as needed

    # S3/Bucket (word boundaries prevent matches in "has3" or "bucketlist")
    if grep -qE '\b(s3|bucket)\b' <<< "$content_lower"; then
        resources=$(echo "$resources" | jq '. += ["s3_bucket"]')
    fi

    # Lambda/Function (prevents matching "dysfunction" or "malfunction")
    if grep -qE '\b(lambda|aws\s+function)\b' <<< "$content_lower"; then
        resources=$(echo "$resources" | jq '. += ["lambda_function", "iam_role"]')
    fi

    # DynamoDB/Table/Database (word boundaries)
    if grep -qE '\b(dynamodb|dynamo\s+db)\b' <<< "$content_lower"; then
        resources=$(echo "$resources" | jq '. += ["dynamodb_table"]')
    fi

    # API Gateway (more specific patterns)
    if grep -qE '\b(api\s+gateway|apigateway|rest\s+api|http\s+api)\b' <<< "$content_lower"; then
        resources=$(echo "$resources" | jq '. += ["api_gateway"]')
    fi

    # CloudFront/CDN (word boundaries)
    if grep -qE '\b(cloudfront|cloud\s+front|cdn)\b' <<< "$content_lower"; then
        resources=$(echo "$resources" | jq '. += ["cloudfront_distribution"]')
    fi

    # IAM (prevents matching "email", "iam" in "diamond", etc.)
    # Look for specific IAM-related terms
    if grep -qE '\b(iam\s+(role|policy|user|group)|permissions?|access\s+control)\b' <<< "$content_lower"; then
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
