#!/usr/bin/env bash
#
# init.sh - Initialize work plugin configuration (simple/non-interactive)
#
# Usage: init.sh [--platform <name>] [--force]
#
# Arguments:
#   --platform <name>: github|jira|linear (auto-detected if omitted)
#   --force: Overwrite existing config without prompting
#
# For interactive mode with validation, use init-wizard.sh instead.
#
# Outputs (JSON):
# {
#   "status": "success|failure|exists",
#   "config_path": "/path/to/config.json",
#   "platform": "github|jira|linear",
#   "message": "Human-readable message"
# }
#
# Exit codes:
#   0: Success
#   1: General error
#   10: Config already exists (without --force)

set -euo pipefail

# Default values
PLATFORM=""
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

CONFIG_PATH=".fractary/plugins/work/config.json"

# Check if config already exists
if [ -f "$CONFIG_PATH" ] && [ "$FORCE" = false ]; then
    jq -n \
        --arg status "exists" \
        --arg config_path "$CONFIG_PATH" \
        --arg message "Configuration already exists. Use --force to overwrite." \
        '{status: $status, config_path: $config_path, message: $message}'
    exit 10
fi

# Auto-detect platform and repo info from git remote
OWNER=""
REPO=""
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

if [ -n "$REMOTE_URL" ]; then
    # Detect platform
    if [ -z "$PLATFORM" ]; then
        if echo "$REMOTE_URL" | grep -qi "github"; then
            PLATFORM="github"
        else
            PLATFORM="github"  # Default to GitHub
        fi
    fi

    # Extract owner/repo from GitHub remote
    if [ "$PLATFORM" = "github" ]; then
        if echo "$REMOTE_URL" | grep -q "git@"; then
            # SSH format: git@github.com:owner/repo.git
            OWNER_REPO=$(echo "$REMOTE_URL" | sed 's/.*://' | sed 's/\.git$//')
        else
            # HTTPS format: https://github.com/owner/repo.git
            OWNER_REPO=$(echo "$REMOTE_URL" | sed 's|.*github.com/||' | sed 's/\.git$//')
        fi
        OWNER=$(echo "$OWNER_REPO" | cut -d'/' -f1)
        REPO=$(echo "$OWNER_REPO" | cut -d'/' -f2)
    fi
else
    # Default to GitHub if no remote
    if [ -z "$PLATFORM" ]; then
        PLATFORM="github"
    fi
fi

# Validate platform
if [[ ! "$PLATFORM" =~ ^(github|jira|linear)$ ]]; then
    jq -n \
        --arg status "failure" \
        --arg message "Invalid platform: $PLATFORM. Must be github, jira, or linear." \
        '{status: $status, message: $message}'
    exit 1
fi

# Create directory
mkdir -p "$(dirname "$CONFIG_PATH")"

# Create config file based on platform
case "$PLATFORM" in
    github)
        jq -n \
            --arg owner "$OWNER" \
            --arg repo "$REPO" \
            '{
                version: "2.0",
                project: {
                    issue_system: "github",
                    repository: (if $owner != "" and $repo != "" then ($owner + "/" + $repo) else "OWNER/REPO" end)
                },
                handlers: {
                    "work-tracker": {
                        active: "github",
                        github: {
                            owner: (if $owner != "" then $owner else "OWNER" end),
                            repo: (if $repo != "" then $repo else "REPO" end),
                            api_url: "https://api.github.com",
                            classification: {
                                type_labels: {
                                    feature: "type: feature",
                                    bug: "type: bug",
                                    chore: "type: chore"
                                }
                            },
                            states: {
                                open: "open",
                                in_progress: "in_progress",
                                closed: "closed"
                            }
                        }
                    }
                },
                defaults: {
                    auto_assign: true,
                    template_issue_type: "feature"
                }
            }' > "$CONFIG_PATH"
        ;;
    jira)
        jq -n '{
            version: "2.0",
            handlers: {
                "work-tracker": {
                    active: "jira",
                    jira: {
                        url: "https://your-domain.atlassian.net",
                        project_key: "PROJ",
                        email: "your@email.com"
                    }
                }
            }
        }' > "$CONFIG_PATH"
        ;;
    linear)
        jq -n '{
            version: "2.0",
            handlers: {
                "work-tracker": {
                    active: "linear",
                    linear: {
                        workspace_id: "workspace-id",
                        team_id: "team-id",
                        team_key: "ENG"
                    }
                }
            }
        }' > "$CONFIG_PATH"
        ;;
esac

# Set permissions
chmod 600 "$CONFIG_PATH"

# Verify and output result
if [ -f "$CONFIG_PATH" ]; then
    jq -n \
        --arg status "success" \
        --arg config_path "$CONFIG_PATH" \
        --arg platform "$PLATFORM" \
        --arg owner "$OWNER" \
        --arg repo "$REPO" \
        --arg message "Configuration created successfully." \
        '{status: $status, config_path: $config_path, platform: $platform, owner: $owner, repo: $repo, message: $message}'
    exit 0
else
    jq -n \
        --arg status "failure" \
        --arg message "Failed to create configuration file." \
        '{status: $status, message: $message}'
    exit 1
fi
