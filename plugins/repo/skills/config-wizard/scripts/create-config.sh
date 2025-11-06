#!/usr/bin/env bash
#
# create-config.sh - Creates repository plugin configuration file
#
# Usage: create-config.sh --platform <platform> --scope <scope> [options]
#
# Arguments:
#   --platform <name>: github|gitlab|bitbucket
#   --scope <type>: project|global
#   --default-branch <name>: Default branch name (default: main)
#   --protected-branches <list>: Comma-separated list (default: main,master,production)
#   --merge-strategy <type>: no-ff|squash|ff-only (default: no-ff)
#   --push-sync-strategy <type>: auto-merge|pull-rebase|pull-merge|manual|fail (default: auto-merge)
#   --force: Overwrite existing config without backup
#
# Environment:
#   GITHUB_TOKEN, GITLAB_TOKEN, or BITBUCKET_TOKEN: Platform API token
#
# Outputs (JSON):
# {
#   "status": "success|failure",
#   "config_path": "/path/to/config.json",
#   "backup_created": true|false
# }
#
# Exit codes:
#   0: Success
#   1: General error
#   2: Invalid arguments
#   3: Configuration error

set -euo pipefail

# Default values
PLATFORM=""
SCOPE=""
DEFAULT_BRANCH="main"
PROTECTED_BRANCHES="main,master,production"
MERGE_STRATEGY="no-ff"
PUSH_SYNC_STRATEGY="auto-merge"
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; then
    case $1 in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --scope)
            SCOPE="$2"
            shift 2
            ;;
        --default-branch)
            DEFAULT_BRANCH="$2"
            shift 2
            ;;
        --protected-branches)
            PROTECTED_BRANCHES="$2"
            shift 2
            ;;
        --merge-strategy)
            MERGE_STRATEGY="$2"
            shift 2
            ;;
        --push-sync-strategy)
            PUSH_SYNC_STRATEGY="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "{\"status\": \"failure\", \"error\": \"Unknown argument: $1\"}" | jq '.'
            exit 2
            ;;
    esac
done

# Validate required arguments
if [ -z "$PLATFORM" ] || [ -z "$SCOPE" ]; then
    echo "{\"status\": \"failure\", \"error\": \"Missing required arguments: --platform and --scope\"}" | jq '.'
    exit 2
fi

# Validate platform
if [[ ! "$PLATFORM" =~ ^(github|gitlab|bitbucket)$ ]]; then
    echo "{\"status\": \"failure\", \"error\": \"Invalid platform: $PLATFORM\"}" | jq '.'
    exit 2
fi

# Validate scope
if [[ ! "$SCOPE" =~ ^(project|global)$ ]]; then
    echo "{\"status\": \"failure\", \"error\": \"Invalid scope: $SCOPE\"}" | jq '.'
    exit 2
fi

# Determine config path based on scope
if [ "$SCOPE" = "project" ]; then
    CONFIG_PATH=".fractary/plugins/repo/config.json"
    mkdir -p .fractary/plugins/repo
else
    CONFIG_PATH="$HOME/.fractary/repo/config.json"
    mkdir -p "$HOME/.fractary/repo"
fi

# Backup existing config if present
BACKUP_CREATED=false
if [ -f "$CONFIG_PATH" ] && [ "$FORCE" = false ]; then
    cp "$CONFIG_PATH" "${CONFIG_PATH}.backup"
    BACKUP_CREATED=true
fi

# Determine token environment variable
case "$PLATFORM" in
    github)
        TOKEN_VAR="\$GITHUB_TOKEN"
        ;;
    gitlab)
        TOKEN_VAR="\$GITLAB_TOKEN"
        ;;
    bitbucket)
        TOKEN_VAR="\$BITBUCKET_TOKEN"
        ;;
esac

# Convert protected branches to JSON array
PROTECTED_BRANCHES_JSON=$(echo "$PROTECTED_BRANCHES" | jq -R 'split(",")')

# Create configuration file
cat > "$CONFIG_PATH" <<EOF
{
  "handlers": {
    "source_control": {
      "active": "$PLATFORM",
      "$PLATFORM": {
        "token": "$TOKEN_VAR"
      }
    }
  },
  "defaults": {
    "default_branch": "$DEFAULT_BRANCH",
    "protected_branches": $PROTECTED_BRANCHES_JSON,
    "merge_strategy": "$MERGE_STRATEGY",
    "push_sync_strategy": "$PUSH_SYNC_STRATEGY"
  }
}
EOF

# Set appropriate permissions (owner read/write only)
chmod 600 "$CONFIG_PATH"

# Output success JSON
cat <<EOF | jq '.'
{
  "status": "success",
  "config_path": "$CONFIG_PATH",
  "backup_created": $BACKUP_CREATED,
  "platform": "$PLATFORM",
  "scope": "$SCOPE"
}
EOF
