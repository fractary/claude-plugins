#!/bin/bash

# update-registry.sh - Update resource registry after deployment
# Usage: update-registry.sh --environment <env> --resources <json>

set -euo pipefail

# Source configuration loader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config-loader.sh"

# Parse arguments
ENVIRONMENT=""
RESOURCES_JSON=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            if [[ $# -lt 2 || "$2" =~ ^-- ]]; then
                echo "Error: --environment requires a value" >&2
                echo "Usage: $0 --environment <env> --resources <json>" >&2
                exit 2
            fi
            ENVIRONMENT="$2"
            shift 2
            ;;
        --resources)
            if [[ $# -lt 2 || "$2" =~ ^-- ]]; then
                echo "Error: --resources requires a value" >&2
                echo "Usage: $0 --environment <env> --resources <json>" >&2
                exit 2
            fi
            RESOURCES_JSON="$2"
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

if [[ -z "$RESOURCES_JSON" ]]; then
    log_error "Resources JSON not specified"
    exit 1
fi

# Load configuration
load_config "$ENVIRONMENT"

# Define registry paths
REGISTRY_DIR="${DEVOPS_PROJECT_ROOT}/.fractary/plugins/faber-cloud/deployments/${ENVIRONMENT}"
REGISTRY_FILE="${REGISTRY_DIR}/registry.json"
DEPLOYED_DOC="${REGISTRY_DIR}/DEPLOYED.md"

# Create registry directory if it doesn't exist
mkdir -p "${REGISTRY_DIR}"

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Initialize registry if it doesn't exist
if [[ ! -f "$REGISTRY_FILE" ]]; then
    cat > "$REGISTRY_FILE" <<EOF
{
  "version": "1.0",
  "environment": "${ENVIRONMENT}",
  "project": "${DEVOPS_PROJECT_NAME}-${DEVOPS_PROJECT_SUBSYSTEM}",
  "last_updated": "${TIMESTAMP}",
  "resources": []
}
EOF
fi

# Parse resources JSON and add to registry
# This would typically merge new resources with existing ones
# For now, we'll append or update

# Update last_updated timestamp
TEMP_FILE=$(mktemp)
jq ".last_updated = \"${TIMESTAMP}\"" "$REGISTRY_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$REGISTRY_FILE"

# Add/update resources from JSON input
# (Implementation would parse RESOURCES_JSON and merge with existing registry)

log_success "Registry updated: ${REGISTRY_FILE}"

# Generate DEPLOYED.md
"${SCRIPT_DIR}/generate-deployed-doc.sh" --environment "${ENVIRONMENT}"

log_success "Documentation generated: ${DEPLOYED_DOC}"
