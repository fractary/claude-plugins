#!/bin/bash

# generate-deployed-doc.sh - Generate DEPLOYED.md from registry
# Usage: generate-deployed-doc.sh --environment <env>

set -euo pipefail

# Source configuration loader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config-loader.sh"

# Parse arguments
ENVIRONMENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            if [[ $# -lt 2 || "$2" =~ ^-- ]]; then
                echo "Error: --environment requires a value" >&2
                echo "Usage: $0 --environment <env>" >&2
                exit 2
            fi
            ENVIRONMENT="$2"
            shift 2
            ;;
        --*=*)
            # Reject equals syntax with helpful error
            FLAG_NAME="${1%%=*}"
            echo "Error: Use space-separated syntax, not equals syntax" >&2
            echo "Use: $FLAG_NAME <value>" >&2
            echo "Not: $1" >&2
            exit 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ -z "$ENVIRONMENT" ]]; then
    log_error "Environment not specified"
    exit 1
fi

# Load configuration
load_config "$ENVIRONMENT"

# Define paths
REGISTRY_DIR="${DEVOPS_PROJECT_ROOT}/.fractary/plugins/faber-cloud/deployments/${ENVIRONMENT}"
REGISTRY_FILE="${REGISTRY_DIR}/registry.json"
DEPLOYED_DOC="${REGISTRY_DIR}/DEPLOYED.md"

# Check if registry exists
if [[ ! -f "$REGISTRY_FILE" ]]; then
    log_error "Registry file not found: ${REGISTRY_FILE}"
    exit 1
fi

# Extract data from registry
PROJECT=$(jq -r '.project' "$REGISTRY_FILE")
LAST_UPDATED=$(jq -r '.last_updated' "$REGISTRY_FILE")
RESOURCE_COUNT=$(jq '.resources | length' "$REGISTRY_FILE")

# Generate DEPLOYED.md
cat > "$DEPLOYED_DOC" <<EOF
# Deployed Resources - ${ENVIRONMENT^} Environment

**Last Updated:** ${LAST_UPDATED}
**Project:** ${PROJECT}
**Environment:** ${ENVIRONMENT}
**Resource Count:** ${RESOURCE_COUNT}

---

## Resources

EOF

# Group resources by type
RESOURCE_TYPES=$(jq -r '.resources[].type' "$REGISTRY_FILE" | sort -u)

for TYPE in $RESOURCE_TYPES; do
    # Add section header for resource type
    echo "" >> "$DEPLOYED_DOC"
    echo "### ${TYPE^} Resources" >> "$DEPLOYED_DOC"
    echo "" >> "$DEPLOYED_DOC"

    # Get resources of this type
    jq -c ".resources[] | select(.type == \"${TYPE}\")" "$REGISTRY_FILE" | while read -r resource; do
        NAME=$(echo "$resource" | jq -r '.aws_name')
        ARN=$(echo "$resource" | jq -r '.arn')
        CONSOLE_URL=$(echo "$resource" | jq -r '.console_url // "N/A"')
        CREATED=$(echo "$resource" | jq -r '.created')

        cat >> "$DEPLOYED_DOC" <<RESOURCE
#### ${NAME}
- **ARN:** \`${ARN}\`
- **Created:** ${CREATED}
- **Console:** [View in AWS Console](${CONSOLE_URL})

RESOURCE
    done
done

# Add footer
cat >> "$DEPLOYED_DOC" <<EOF

---

## Management Commands

\`\`\`bash
# View all resources
/fractary-faber-cloud:infra-manage show-resources --env=${ENVIRONMENT}

# Deploy changes
/fractary-faber-cloud:infra-manage deploy --env=${ENVIRONMENT}

# Check status
/fractary-faber-cloud:infra-manage status
\`\`\`

**Registry File:** \`.fractary/plugins/faber-cloud/deployments/${ENVIRONMENT}/registry.json\`
EOF

log_success "Documentation generated: ${DEPLOYED_DOC}"
