#!/bin/bash
# Work Initializer: Interactive Configuration Wizard
# Gathers platform-specific configuration through interactive prompts

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Configuration constants
CONFIG_DIR=".fractary/plugins/work"
CONFIG_FILE="$CONFIG_DIR/config.json"
TEMPLATE_FILE="$PLUGIN_ROOT/config/config.example.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage
usage() {
    cat <<EOF
Usage: $0 <platform> [options]

Interactive wizard to gather work plugin configuration.

Arguments:
  platform              Platform to configure (github, jira, linear)

Options:
  --owner <name>        GitHub repository owner (for non-interactive)
  --repo <name>         GitHub repository name (for non-interactive)
  --api-url <url>       GitHub API URL (default: https://api.github.com)
  --jira-url <url>      Jira instance URL
  --project-key <key>   Jira project key
  --email <email>       Jira email address
  --workspace-id <id>   Linear workspace ID
  --team-id <id>        Linear team ID
  --team-key <key>      Linear team key
  --token <value>       Authentication token (GitHub/Jira/Linear)
  --yes, -y             Use detected/provided values without prompting

Examples:
  $0 github
  $0 github --owner myorg --repo myproject --yes
  $0 jira --jira-url https://domain.atlassian.net --project-key PROJ
  $0 linear --workspace-id abc123 --team-id xyz789 --team-key ENG

EOF
    exit 2
}

# Logging functions
info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*" >&2
}

# Print banner
print_banner() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Fractary Work Plugin Setup Wizard"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Prompt for input with default value
prompt() {
    local prompt_text="$1"
    local default_value="${2:-}"
    local is_secret="${3:-false}"

    if [ -n "$default_value" ]; then
        if [ "$is_secret" = "true" ]; then
            read -rsp "$prompt_text [$default_value]: " input
            echo "" # New line after secret input
        else
            read -rp "$prompt_text [$default_value]: " input
        fi
        echo "${input:-$default_value}"
    else
        if [ "$is_secret" = "true" ]; then
            read -rsp "$prompt_text: " input
            echo "" # New line after secret input
        else
            read -rp "$prompt_text: " input
        fi
        echo "$input"
    fi
}

# Detect environment (git repository, remote URL, platform)
detect_environment() {
    local detected_platform=""
    local detected_owner=""
    local detected_repo=""

    # Check if in git repository
    if git rev-parse --git-dir >/dev/null 2>&1; then
        success "Git repository detected"

        # Get remote URL
        if git remote get-url origin >/dev/null 2>&1; then
            local remote_url
            remote_url=$(git remote get-url origin)
            success "Remote: $remote_url"

            # Detect GitHub
            if [[ "$remote_url" =~ github\.com|github ]]; then
                detected_platform="github"
                success "Detected platform: GitHub"

                # Extract owner and repo
                if [[ "$remote_url" =~ ^git@.*:([^/]+)/(.+)\.git$ ]]; then
                    # SSH format: git@github.com:owner/repo.git
                    detected_owner="${BASH_REMATCH[1]}"
                    detected_repo="${BASH_REMATCH[2]}"
                elif [[ "$remote_url" =~ https?://[^/]+/([^/]+)/(.+)(\.git)?$ ]]; then
                    # HTTPS format: https://github.com/owner/repo.git
                    detected_owner="${BASH_REMATCH[1]}"
                    detected_repo="${BASH_REMATCH[2]}"
                    detected_repo="${detected_repo%.git}" # Remove .git suffix
                fi

                if [ -n "$detected_owner" ] && [ -n "$detected_repo" ]; then
                    success "Detected repository: $detected_owner/$detected_repo"
                fi
            fi
        else
            warn "No remote URL configured"
        fi
    else
        warn "Not in a git repository"
    fi

    # Export detected values
    export DETECTED_PLATFORM="$detected_platform"
    export DETECTED_OWNER="$detected_owner"
    export DETECTED_REPO="$detected_repo"
}

# Configure GitHub
configure_github() {
    local owner="$1"
    local repo="$2"
    local api_url="${3:-https://api.github.com}"
    local token="$4"
    local yes_mode="$5"

    info "GitHub Configuration"
    echo ""

    # Use detected values as defaults
    if [ -z "$owner" ]; then
        owner="${DETECTED_OWNER:-}"
    fi
    if [ -z "$repo" ]; then
        repo="${DETECTED_REPO:-}"
    fi

    # Prompt for values if not provided and not in yes mode
    if [ "$yes_mode" = "false" ]; then
        owner=$(prompt "Repository owner" "$owner")
        repo=$(prompt "Repository name" "$repo")
        api_url=$(prompt "GitHub API URL" "$api_url")
    fi

    # Validate required fields
    if [ -z "$owner" ]; then
        error "Repository owner is required"
        exit 2
    fi
    if [ -z "$repo" ]; then
        error "Repository name is required"
        exit 2
    fi

    # Check for token in environment
    if [ -z "$token" ]; then
        if [ -n "${GITHUB_TOKEN:-}" ]; then
            if [ "$yes_mode" = "false" ]; then
                echo ""
                local use_env_token
                use_env_token=$(prompt "Use GITHUB_TOKEN from environment? (y/n)" "y")
                if [[ "$use_env_token" =~ ^[Yy] ]]; then
                    token="$GITHUB_TOKEN"
                fi
            else
                token="$GITHUB_TOKEN"
            fi
        fi
    fi

    # Prompt for token if still not provided
    if [ -z "$token" ] && [ "$yes_mode" = "false" ]; then
        echo ""
        info "GitHub Personal Access Token required for API operations"
        info "Required scopes: repo, read:org"
        info "Generate token: https://github.com/settings/tokens"
        echo ""
        token=$(prompt "GitHub token" "" "true")
    fi

    if [ -z "$token" ]; then
        error "GitHub token is required"
        exit 2
    fi

    # Output configuration as JSON
    jq -n \
        --arg owner "$owner" \
        --arg repo "$repo" \
        --arg api_url "$api_url" \
        --arg token "$token" \
        '{
            owner: $owner,
            repo: $repo,
            api_url: $api_url,
            token: $token
        }'
}

# Configure Jira
configure_jira() {
    local url="$1"
    local project_key="$2"
    local email="$3"
    local token="$4"
    local yes_mode="$5"

    info "Jira Configuration"
    echo ""

    # Prompt for values if not provided and not in yes mode
    if [ "$yes_mode" = "false" ]; then
        url=$(prompt "Jira URL (e.g., https://your-domain.atlassian.net)" "$url")
        project_key=$(prompt "Project key (e.g., PROJ)" "$project_key")
        email=$(prompt "Email address" "$email")
    fi

    # Validate required fields
    if [ -z "$url" ]; then
        error "Jira URL is required"
        exit 2
    fi
    if [ -z "$project_key" ]; then
        error "Project key is required"
        exit 2
    fi
    if [ -z "$email" ]; then
        error "Email address is required"
        exit 2
    fi

    # Check for token in environment
    if [ -z "$token" ]; then
        if [ -n "${JIRA_TOKEN:-}" ]; then
            if [ "$yes_mode" = "false" ]; then
                echo ""
                local use_env_token
                use_env_token=$(prompt "Use JIRA_TOKEN from environment? (y/n)" "y")
                if [[ "$use_env_token" =~ ^[Yy] ]]; then
                    token="$JIRA_TOKEN"
                fi
            else
                token="$JIRA_TOKEN"
            fi
        fi
    fi

    # Prompt for token if still not provided
    if [ -z "$token" ] && [ "$yes_mode" = "false" ]; then
        echo ""
        info "Jira API token required for authentication"
        info "Generate token: https://id.atlassian.com/manage-profile/security/api-tokens"
        echo ""
        token=$(prompt "Jira API token" "" "true")
    fi

    if [ -z "$token" ]; then
        error "Jira API token is required"
        exit 2
    fi

    # Output configuration as JSON
    jq -n \
        --arg url "$url" \
        --arg project_key "$project_key" \
        --arg email "$email" \
        --arg token "$token" \
        '{
            url: $url,
            project_key: $project_key,
            email: $email,
            token: $token
        }'
}

# Configure Linear
configure_linear() {
    local workspace_id="$1"
    local team_id="$2"
    local team_key="$3"
    local token="$4"
    local yes_mode="$5"

    info "Linear Configuration"
    echo ""

    # Prompt for values if not provided and not in yes mode
    if [ "$yes_mode" = "false" ]; then
        workspace_id=$(prompt "Workspace ID" "$workspace_id")
        team_id=$(prompt "Team ID" "$team_id")
        team_key=$(prompt "Team key (e.g., ENG)" "$team_key")
    fi

    # Validate required fields
    if [ -z "$workspace_id" ]; then
        error "Workspace ID is required"
        exit 2
    fi
    if [ -z "$team_id" ]; then
        error "Team ID is required"
        exit 2
    fi
    if [ -z "$team_key" ]; then
        error "Team key is required"
        exit 2
    fi

    # Check for token in environment
    if [ -z "$token" ]; then
        if [ -n "${LINEAR_API_KEY:-}" ]; then
            if [ "$yes_mode" = "false" ]; then
                echo ""
                local use_env_token
                use_env_token=$(prompt "Use LINEAR_API_KEY from environment? (y/n)" "y")
                if [[ "$use_env_token" =~ ^[Yy] ]]; then
                    token="$LINEAR_API_KEY"
                fi
            else
                token="$LINEAR_API_KEY"
            fi
        fi
    fi

    # Prompt for token if still not provided
    if [ -z "$token" ] && [ "$yes_mode" = "false" ]; then
        echo ""
        info "Linear API key required for authentication"
        info "Generate key: https://linear.app/settings/api"
        echo ""
        token=$(prompt "Linear API key" "" "true")
    fi

    if [ -z "$token" ]; then
        error "Linear API key is required"
        exit 2
    fi

    # Output configuration as JSON
    jq -n \
        --arg workspace_id "$workspace_id" \
        --arg team_id "$team_id" \
        --arg team_key "$team_key" \
        --arg token "$token" \
        '{
            workspace_id: $workspace_id,
            team_id: $team_id,
            team_key: $team_key,
            token: $token
        }'
}

# Main execution
main() {
    # Parse arguments
    if [ $# -lt 1 ]; then
        usage
    fi

    local platform="$1"
    shift

    # Validate platform
    if [[ ! "$platform" =~ ^(github|jira|linear)$ ]]; then
        error "Invalid platform: $platform"
        error "Valid platforms: github, jira, linear"
        exit 13
    fi

    # Parse options
    local owner=""
    local repo=""
    local api_url="https://api.github.com"
    local jira_url=""
    local project_key=""
    local email=""
    local workspace_id=""
    local team_id=""
    local team_key=""
    local token=""
    local yes_mode="false"

    while [ $# -gt 0 ]; do
        case "$1" in
            --owner)
                owner="$2"
                shift 2
                ;;
            --repo)
                repo="$2"
                shift 2
                ;;
            --api-url)
                api_url="$2"
                shift 2
                ;;
            --jira-url)
                jira_url="$2"
                shift 2
                ;;
            --project-key)
                project_key="$2"
                shift 2
                ;;
            --email)
                email="$2"
                shift 2
                ;;
            --workspace-id)
                workspace_id="$2"
                shift 2
                ;;
            --team-id)
                team_id="$2"
                shift 2
                ;;
            --team-key)
                team_key="$2"
                shift 2
                ;;
            --token)
                token="$2"
                shift 2
                ;;
            --yes|-y)
                yes_mode="true"
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Print banner
    print_banner

    # Detect environment
    info "Detecting environment..."
    detect_environment
    echo ""

    # Configure platform
    case "$platform" in
        github)
            configure_github "$owner" "$repo" "$api_url" "$token" "$yes_mode"
            ;;
        jira)
            configure_jira "$jira_url" "$project_key" "$email" "$token" "$yes_mode"
            ;;
        linear)
            configure_linear "$workspace_id" "$team_id" "$team_key" "$token" "$yes_mode"
            ;;
    esac
}

# Run main
main "$@"
