#!/usr/bin/env bash
# update-settings.sh - Manage Claude Code permissions in .claude/settings.json
# Usage: update-settings.sh --project-path <path> --mode <setup|validate|reset>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROJECT_PATH="."
MODE="setup"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project-path)
            PROJECT_PATH="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

SETTINGS_FILE="$PROJECT_PATH/.claude/settings.json"
BACKUP_FILE="$PROJECT_PATH/.claude/settings.json.backup"

# Commands to allow (repo plugin needs these)
ALLOW_COMMANDS=(
    # Git core operations
    "git status"
    "git branch"
    "git checkout"
    "git switch"
    "git commit"
    "git push"
    "git pull"
    "git fetch"
    "git remote"
    "git tag"
    "git log"
    "git diff"
    "git stash"
    "git merge"
    "git rebase"
    "git rev-parse"
    "git for-each-ref"
    "git ls-remote"
    "git show-ref"
    "git add"
    "git reset"
    "git show"
    "git config"

    # GitHub CLI operations
    "gh pr create"
    "gh pr view"
    "gh pr list"
    "gh pr comment"
    "gh pr review"
    "gh pr merge"
    "gh pr close"
    "gh pr status"
    "gh issue create"
    "gh issue view"
    "gh issue list"
    "gh issue comment"
    "gh issue close"
    "gh repo view"
    "gh repo clone"
    "gh auth status"
    "gh auth login"
    "gh api"

    # Safe utility commands
    "cat"
    "head"
    "tail"
    "grep"
    "find"
    "ls"
    "pwd"
    "which"
    "echo"
    "jq"
    "sed"
    "awk"
    "sort"
    "uniq"
    "wc"
)

# Commands to deny (dangerous operations)
DENY_COMMANDS=(
    # Destructive file operations
    "rm -rf /"
    "rm -rf *"
    "rm -rf ."
    "rm -rf ~"
    "dd if="
    "mkfs"
    "format"
    "> /dev/sd"

    # Git dangerous operations (force push to protected branches)
    "git push --force origin main"
    "git push --force origin master"
    "git push --force origin production"
    "git push -f origin main"
    "git push -f origin master"
    "git push -f origin production"
    "git reset --hard origin/"
    "git clean -fdx"
    "git filter-branch"
    "git rebase --onto"

    # GitHub dangerous operations
    "gh repo delete"
    "gh repo archive"
    "gh secret delete"

    # System operations
    "sudo"
    "su"
    "chmod 777"
    "chown"
    "kill -9"
    "pkill"
    "shutdown"
    "reboot"
    "init"
    "systemctl"

    # Network operations that pipe to shell
    "curl | sh"
    "wget | sh"
    "curl | bash"
    "wget | bash"
)

# Function to create default settings structure
create_default_settings() {
    cat <<EOF
{
  "permissions": {
    "bash": {
      "allow": [],
      "deny": []
    }
  },
  "_comment": "Managed by fractary-repo plugin. Backup: .claude/settings.json.backup"
}
EOF
}

# Function to merge arrays in JSON (remove duplicates, sort)
merge_array() {
    local json_file="$1"
    local path="$2"
    local new_items="$3"

    # Get existing items
    local existing=$(jq -r "$path // [] | .[]" "$json_file" 2>/dev/null || echo "")

    # Combine existing and new, remove duplicates, sort
    local merged=$(echo "$existing"$'\n'"$new_items" | grep -v '^$' | sort -u)

    echo "$merged"
}

# Function to show permission changes
show_changes() {
    echo -e "${BLUE}🔐 Permission Changes${NC}"
    echo "───────────────────────────────────────"
    echo ""
    echo -e "${GREEN}ALLOWING (repo operations):${NC}"
    for cmd in "${ALLOW_COMMANDS[@]}"; do
        echo "  ✓ $cmd"
    done
    echo ""
    echo -e "${RED}DENYING (dangerous operations):${NC}"
    for cmd in "${DENY_COMMANDS[@]}"; do
        echo "  ✗ $cmd"
    done
    echo ""
    echo "───────────────────────────────────────"
    echo "These permissions will:"
    echo "  ✓ Eliminate prompts for repo operations"
    echo "  ✓ Prevent accidental catastrophic commands"
    echo "  ✓ Allow safe git and GitHub operations"
    echo ""
}

# Function to backup existing settings
backup_settings() {
    if [ -f "$SETTINGS_FILE" ]; then
        cp "$SETTINGS_FILE" "$BACKUP_FILE"
        echo -e "${GREEN}✓${NC} Backed up existing settings"
    fi
}

# Function to validate JSON
validate_json() {
    local file="$1"
    if ! jq empty "$file" 2>/dev/null; then
        echo -e "${RED}ERROR:${NC} Invalid JSON in $file"
        return 1
    fi
    return 0
}

# Function to setup permissions
setup_permissions() {
    # Create .claude directory if it doesn't exist
    mkdir -p "$PROJECT_PATH/.claude"

    # Backup existing settings
    backup_settings

    # Create or load existing settings
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo -e "${YELLOW}No existing settings found, creating new...${NC}"
        create_default_settings > "$SETTINGS_FILE"
    fi

    # Validate existing file
    if ! validate_json "$SETTINGS_FILE"; then
        echo -e "${RED}Existing settings.json contains invalid JSON${NC}"
        echo "Backup: $BACKUP_FILE"
        exit 1
    fi

    # Show what will change
    show_changes

    # Create temporary file for updates
    local temp_file=$(mktemp)

    # Start with existing settings
    cp "$SETTINGS_FILE" "$temp_file"

    # Ensure permissions.bash structure exists
    jq '.permissions.bash.allow //= [] | .permissions.bash.deny //= []' "$temp_file" > "${temp_file}.tmp"
    mv "${temp_file}.tmp" "$temp_file"

    # Add allow commands (preserve existing)
    local existing_allow=$(jq -r '.permissions.bash.allow[]' "$temp_file" 2>/dev/null || echo "")
    local all_allow=$(printf "%s\n" "${ALLOW_COMMANDS[@]}" "$existing_allow" | grep -v '^$' | sort -u)

    # Add deny commands (preserve existing)
    local existing_deny=$(jq -r '.permissions.bash.deny[]' "$temp_file" 2>/dev/null || echo "")
    local all_deny=$(printf "%s\n" "${DENY_COMMANDS[@]}" "$existing_deny" | grep -v '^$' | sort -u)

    # Build new allow array
    local allow_json=$(echo "$all_allow" | jq -R . | jq -s .)

    # Build new deny array
    local deny_json=$(echo "$all_deny" | jq -R . | jq -s .)

    # Update settings with merged arrays
    jq --argjson allow "$allow_json" \
       --argjson deny "$deny_json" \
       '.permissions.bash.allow = $allow | .permissions.bash.deny = $deny' \
       "$temp_file" > "${temp_file}.tmp"

    mv "${temp_file}.tmp" "$temp_file"

    # Validate result
    if ! validate_json "$temp_file"; then
        echo -e "${RED}ERROR:${NC} Generated invalid JSON"
        rm -f "$temp_file"
        exit 1
    fi

    # Write to settings file
    mv "$temp_file" "$SETTINGS_FILE"

    # Count changes
    local allow_count=$(echo "$all_allow" | wc -l)
    local deny_count=$(echo "$all_deny" | wc -l)

    echo ""
    echo -e "${GREEN}✅ Updated settings${NC}"
    echo "  Settings file: $SETTINGS_FILE"
    echo "  Backup: $BACKUP_FILE"
    echo "  Commands allowed: $allow_count"
    echo "  Commands denied: $deny_count"
}

# Function to validate permissions
validate_permissions() {
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo -e "${RED}✗${NC} Settings file not found: $SETTINGS_FILE"
        echo "Run: /repo:init-permissions --mode setup"
        exit 1
    fi

    if ! validate_json "$SETTINGS_FILE"; then
        echo -e "${RED}✗${NC} Invalid JSON in settings file"
        exit 1
    fi

    echo -e "${BLUE}🔐 Validating Permissions${NC}"
    echo "───────────────────────────────────────"

    # Check if critical commands are allowed
    local missing_allows=()
    for cmd in "git status" "git commit" "git push" "gh pr create"; do
        if ! jq -e ".permissions.bash.allow | index(\"$cmd\")" "$SETTINGS_FILE" >/dev/null 2>&1; then
            missing_allows+=("$cmd")
        fi
    done

    # Check if critical denies are present
    local missing_denies=()
    for cmd in "rm -rf /" "git push --force origin main" "gh repo delete"; do
        if ! jq -e ".permissions.bash.deny | index(\"$cmd\")" "$SETTINGS_FILE" >/dev/null 2>&1; then
            missing_denies+=("$cmd")
        fi
    done

    if [ ${#missing_allows[@]} -eq 0 ] && [ ${#missing_denies[@]} -eq 0 ]; then
        echo -e "${GREEN}✓${NC} All critical permissions configured correctly"
        echo -e "${GREEN}✓${NC} Git commands: allowed"
        echo -e "${GREEN}✓${NC} GitHub CLI commands: allowed"
        echo -e "${GREEN}✓${NC} Dangerous commands: denied"
    else
        echo -e "${YELLOW}⚠${NC} Some permissions missing:"
        if [ ${#missing_allows[@]} -gt 0 ]; then
            echo "  Missing allows: ${missing_allows[*]}"
        fi
        if [ ${#missing_denies[@]} -gt 0 ]; then
            echo "  Missing denies: ${missing_denies[*]}"
        fi
        echo ""
        echo "Run: /repo:init-permissions --mode setup"
        exit 1
    fi
}

# Function to reset permissions
reset_permissions() {
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo -e "${YELLOW}No settings file to reset${NC}"
        exit 0
    fi

    # Backup current settings
    backup_settings

    echo -e "${YELLOW}⚠ Resetting Permissions${NC}"
    echo "This will remove all repo-specific permissions"
    echo ""

    # Remove repo-specific allow/deny rules
    local temp_file=$(mktemp)

    # Get existing settings
    cp "$SETTINGS_FILE" "$temp_file"

    # Remove commands we added
    for cmd in "${ALLOW_COMMANDS[@]}"; do
        jq --arg cmd "$cmd" '.permissions.bash.allow = (.permissions.bash.allow - [$cmd])' "$temp_file" > "${temp_file}.tmp"
        mv "${temp_file}.tmp" "$temp_file"
    done

    for cmd in "${DENY_COMMANDS[@]}"; do
        jq --arg cmd "$cmd" '.permissions.bash.deny = (.permissions.bash.deny - [$cmd])' "$temp_file" > "${temp_file}.tmp"
        mv "${temp_file}.tmp" "$temp_file"
    done

    # Validate result
    if ! validate_json "$temp_file"; then
        echo -e "${RED}ERROR:${NC} Generated invalid JSON"
        rm -f "$temp_file"
        exit 1
    fi

    # Write back
    mv "$temp_file" "$SETTINGS_FILE"

    echo -e "${GREEN}✅ Reset complete${NC}"
    echo "  Removed repo-specific permissions"
    echo "  Backup: $BACKUP_FILE"
}

# Main execution
case "$MODE" in
    setup)
        setup_permissions
        ;;
    validate)
        validate_permissions
        ;;
    reset)
        reset_permissions
        ;;
    *)
        echo -e "${RED}ERROR:${NC} Unknown mode: $MODE"
        echo "Valid modes: setup, validate, reset"
        exit 1
        ;;
esac
