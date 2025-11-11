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
#   --pull-sync-strategy <type>: auto-merge-prefer-remote|auto-merge-prefer-local|rebase|manual|fail (default: auto-merge-prefer-remote)
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
PULL_SYNC_STRATEGY="auto-merge-prefer-remote"
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
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
        --pull-sync-strategy)
            PULL_SYNC_STRATEGY="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            jq -n --arg err "Unknown argument: $1" '{status: "failure", error: $err}'
            exit 2
            ;;
    esac
done

# Validate required arguments
if [ -z "$PLATFORM" ] || [ -z "$SCOPE" ]; then
    jq -n '{status: "failure", error: "Missing required arguments: --platform and --scope"}'
    exit 2
fi

# Validate platform
if [[ ! "$PLATFORM" =~ ^(github|gitlab|bitbucket)$ ]]; then
    jq -n --arg p "$PLATFORM" '{status: "failure", error: ("Invalid platform: " + $p)}'
    exit 2
fi

# Validate scope
if [[ ! "$SCOPE" =~ ^(project|global)$ ]]; then
    jq -n --arg s "$SCOPE" '{status: "failure", error: ("Invalid scope: " + $s)}'
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

# Convert protected branches to JSON array using jq
PROTECTED_BRANCHES_JSON=$(echo "$PROTECTED_BRANCHES" | jq -R 'split(",")')

# Create configuration file using jq for safe JSON generation
jq -n \
    --arg platform "$PLATFORM" \
    --arg token_var "$TOKEN_VAR" \
    --arg default_branch "$DEFAULT_BRANCH" \
    --argjson protected_branches "$PROTECTED_BRANCHES_JSON" \
    --arg merge_strategy "$MERGE_STRATEGY" \
    --arg push_sync "$PUSH_SYNC_STRATEGY" \
    --arg pull_sync "$PULL_SYNC_STRATEGY" \
    '{
        handlers: {
            source_control: {
                active: $platform,
                ($platform): {
                    token: $token_var
                }
            }
        },
        defaults: {
            default_branch: $default_branch,
            protected_branches: $protected_branches,
            merge_strategy: $merge_strategy,
            push_sync_strategy: $push_sync,
            pull_sync_strategy: $pull_sync
        }
    }' > "$CONFIG_PATH"

# Set appropriate permissions (owner read/write only)
chmod 600 "$CONFIG_PATH"

# Output success JSON using jq --arg for safety
jq -n \
    --arg status "success" \
    --arg config_path "$CONFIG_PATH" \
    --argjson backup_created "$BACKUP_CREATED" \
    --arg platform "$PLATFORM" \
    --arg scope "$SCOPE" \
    '{
        status: $status,
        config_path: $config_path,
        backup_created: $backup_created,
        platform: $platform,
        scope: $scope
    }'
