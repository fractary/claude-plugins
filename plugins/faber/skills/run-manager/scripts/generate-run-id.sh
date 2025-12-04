#!/usr/bin/env bash
#
# generate-run-id.sh - Generate a unique FABER Run ID
#
# Usage:
#   generate-run-id.sh [--org <org>] [--project <project>]
#
# Output:
#   Prints the full run_id to stdout: {org}/{project}/{uuid}
#
# The run_id format is designed for:
# - Uniqueness: UUID v4 ensures no collisions
# - Discoverability: org/project prefix allows listing by scope
# - S3 compatibility: Valid S3 key path
#

set -euo pipefail

# Parse arguments
ORG=""
PROJECT=""
UUID_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --org)
            ORG="$2"
            shift 2
            ;;
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --uuid-only)
            UUID_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: generate-run-id.sh [--org <org>] [--project <project>] [--uuid-only]"
            echo ""
            echo "Generates a unique FABER run ID in format: {org}/{project}/{uuid}"
            echo ""
            echo "Options:"
            echo "  --org <org>         Organization name (default: auto-detected from git remote)"
            echo "  --project <project> Project name (default: auto-detected from git repo name)"
            echo "  --uuid-only         Output only the UUID (no org/project prefix)"
            echo ""
            echo "Auto-detection:"
            echo "  - Org: Extracted from git remote origin URL"
            echo "  - Project: Git repository name or directory name"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Auto-detect organization from git remote
if [[ -z "$ORG" ]]; then
    # Try to get org from git remote URL
    # Supports: git@github.com:org/repo.git, https://github.com/org/repo.git
    if GIT_URL=$(git config --get remote.origin.url 2>/dev/null); then
        # Extract org from SSH URL: git@github.com:org/repo.git -> org
        if [[ "$GIT_URL" =~ git@[^:]+:([^/]+)/ ]]; then
            ORG="${BASH_REMATCH[1]}"
        # Extract org from HTTPS URL: https://github.com/org/repo.git -> org
        elif [[ "$GIT_URL" =~ https://[^/]+/([^/]+)/ ]]; then
            ORG="${BASH_REMATCH[1]}"
        fi
    fi

    # Fallback to "local" if no git remote
    if [[ -z "$ORG" ]]; then
        ORG="local"
    fi
fi

# Auto-detect project name from git repo or directory
if [[ -z "$PROJECT" ]]; then
    # Try git repo name first
    if GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
        PROJECT=$(basename "$GIT_ROOT")
    else
        # Fallback to current directory name
        PROJECT=$(basename "$PWD")
    fi
fi

# Sanitize org and project names for filesystem/S3 compatibility
# Allow: a-z, 0-9, -, _
sanitize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

ORG=$(sanitize "$ORG")
PROJECT=$(sanitize "$PROJECT")

# Generate UUID v4
generate_uuid() {
    # Try uuidgen first (most common)
    if command -v uuidgen &>/dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
        return
    fi

    # Try Python as fallback
    if command -v python3 &>/dev/null; then
        python3 -c "import uuid; print(uuid.uuid4())"
        return
    fi

    # Try /proc/sys/kernel/random/uuid on Linux
    if [[ -f /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
        return
    fi

    # Last resort: generate from /dev/urandom
    # Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx (UUID v4)
    local hex
    hex=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')

    # Set version (4) and variant (8, 9, a, or b)
    local uuid
    uuid="${hex:0:8}-${hex:8:4}-4${hex:13:3}-"

    # Set variant bits (10xx)
    local variant_byte="${hex:16:2}"
    local variant_int=$((16#$variant_byte))
    local variant_masked=$(( (variant_int & 0x3f) | 0x80 ))
    uuid+="$(printf '%02x' $variant_masked)${hex:18:2}-${hex:20:12}"

    echo "$uuid"
}

UUID=$(generate_uuid)

# If --uuid-only, just output the UUID
if [[ "$UUID_ONLY" == true ]]; then
    echo "$UUID"
    exit 0
fi

# Construct and output the full run_id
RUN_ID="${ORG}/${PROJECT}/${UUID}"

# Validate the run_id format
if [[ ! "$RUN_ID" =~ ^[a-z0-9_-]+/[a-z0-9_-]+/[a-f0-9-]{36}$ ]]; then
    echo "Error: Generated invalid run_id: $RUN_ID" >&2
    exit 1
fi

echo "$RUN_ID"
