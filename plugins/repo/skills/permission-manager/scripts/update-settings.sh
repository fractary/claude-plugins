#!/usr/bin/env bash
# update-settings.sh - Manage Claude Code permissions in .claude/settings.json
# Usage: update-settings.sh --project-path <path> --mode <setup|validate|reset>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default values
PROJECT_PATH="."
MODE="setup"

# Temp file tracking for cleanup
TEMP_FILES=()

# Cleanup function for temp files
cleanup_temp_files() {
    for temp_file in "${TEMP_FILES[@]}"; do
        if [ -f "$temp_file" ]; then
            rm -f "$temp_file"
        fi
    done
}

# Register cleanup on exit
trap cleanup_temp_files EXIT INT TERM

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

# Commands to allow (safe operations, most write operations)
# Total: 56 commands
ALLOW_COMMANDS=(
    # Git read operations (10 commands)
    "git status"
    "git branch"
    "git log"
    "git diff"
    "git show"
    "git rev-parse"
    "git for-each-ref"
    "git ls-remote"
    "git show-ref"
    "git config"

    # Git write operations (13 commands)
    "git add"
    "git checkout"
    "git switch"
    "git fetch"
    "git pull"
    "git remote"
    "git stash"
    "git tag"
    "git commit"
    "git push"
    "git merge"
    "git rebase"
    "git reset"

    # GitHub CLI read operations (7 commands)
    "gh pr view"
    "gh pr list"
    "gh pr status"
    "gh issue view"
    "gh issue list"
    "gh repo view"
    "gh auth status"

    # GitHub CLI write operations (11 commands)
    "gh pr create"
    "gh pr comment"
    "gh pr review"
    "gh pr close"
    "gh issue create"
    "gh issue comment"
    "gh issue close"
    "gh repo clone"
    "gh auth login"
    "gh auth refresh"
    "gh api"

    # Safe utility commands (15 commands)
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

# Commands that require approval (ONLY for protected branches)
# Total: 9 commands
# These use pattern matching to detect operations on main/master/production
REQUIRE_APPROVAL_COMMANDS=(
    # Protected branch push operations (8 commands)
    "git push origin main"
    "git push origin master"
    "git push origin production"
    "git push -u origin main"
    "git push -u origin master"
    "git push -u origin production"
    "git push --set-upstream origin main"
    "git push --set-upstream origin master"
    "git push --set-upstream origin production"
)

# Commands to deny (dangerous operations)
# Total: 39 commands
DENY_COMMANDS=(
    # Destructive file operations (8 commands)
    "rm -rf /"
    "rm -rf *"
    "rm -rf ."
    "rm -rf ~"
    "dd if="
    "mkfs"
    "format"
    "> /dev/sd"

    # Force push to protected branches (9 commands)
    "git push --force origin main"
    "git push --force origin master"
    "git push --force origin production"
    "git push -f origin main"
    "git push -f origin master"
    "git push -f origin production"
    "git push --force-with-lease origin main"
    "git push --force-with-lease origin master"
    "git push --force-with-lease origin production"

    # Other dangerous git operations (6 commands)
    "git reset --hard origin/main"
    "git reset --hard origin/master"
    "git reset --hard origin/production"
    "git clean -fdx"
    "git filter-branch"
    "git rebase --onto"

    # GitHub dangerous operations (3 commands)
    "gh repo delete"
    "gh repo archive"
    "gh secret delete"

    # System operations (9 commands)
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

    # Network operations that pipe to shell (4 commands)
    "curl | sh"
    "wget | sh"
    "curl | bash"
    "wget | bash"
)

# Build associative arrays for O(1) lookup
declare -A ALLOW_MAP
declare -A REQUIRE_MAP
declare -A DENY_MAP

for cmd in "${ALLOW_COMMANDS[@]}"; do
    ALLOW_MAP["$cmd"]=1
done

for cmd in "${REQUIRE_APPROVAL_COMMANDS[@]}"; do
    REQUIRE_MAP["$cmd"]=1
done

for cmd in "${DENY_COMMANDS[@]}"; do
    DENY_MAP["$cmd"]=1
done

# Function to create default settings structure
create_default_settings() {
    cat <<EOF
{
  "permissions": {
    "bash": {
      "allow": [],
      "requireApproval": [],
      "deny": []
    }
  },
  "_comment": "Managed by fractary-repo plugin. Protected branches: main, master, production",
  "_note": "Most operations auto-allowed. Approval required only for protected branch operations."
}
EOF
}

# Function to check if command exists in map (O(1) lookup)
command_in_map() {
    local cmd="$1"
    local -n map_ref=$2
    [[ -n "${map_ref[$cmd]:-}" ]]
}

# Function to detect conflicts (command in multiple categories)
detect_conflicts() {
    local settings_file="$1"
    local conflicts=()

    # Get all commands from each category
    local allows=$(jq -r '.permissions.bash.allow[]?' "$settings_file" 2>/dev/null || echo "")
    local requires=$(jq -r '.permissions.bash.requireApproval[]?' "$settings_file" 2>/dev/null || echo "")
    local denies=$(jq -r '.permissions.bash.deny[]?' "$settings_file" 2>/dev/null || echo "")

    # Check for duplicates across categories
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        if echo "$requires" | grep -qF "$cmd"; then
            conflicts+=("$cmd (in both allow and requireApproval)")
        fi
        if echo "$denies" | grep -qF "$cmd"; then
            conflicts+=("$cmd (in both allow and deny)")
        fi
    done <<< "$allows"

    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        if echo "$denies" | grep -qF "$cmd"; then
            conflicts+=("$cmd (in both requireApproval and deny)")
        fi
    done <<< "$requires"

    if [ ${#conflicts[@]} -gt 0 ]; then
        return 0  # Conflicts found
    fi
    return 1  # No conflicts
}

# Function to show differences from recommended settings
show_differences() {
    local settings_file="$1"

    echo -e "${BLUE}📊 Comparing with Recommended Settings${NC}"
    echo "───────────────────────────────────────"

    # Get current settings
    local current_allows=$(jq -r '.permissions.bash.allow[]?' "$settings_file" 2>/dev/null | sort -u)
    local current_requires=$(jq -r '.permissions.bash.requireApproval[]?' "$settings_file" 2>/dev/null | sort -u)
    local current_denies=$(jq -r '.permissions.bash.deny[]?' "$settings_file" 2>/dev/null | sort -u)

    # Check for custom allows (not in our recommended lists)
    local custom_allows=()
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        if ! command_in_map "$cmd" ALLOW_MAP && ! command_in_map "$cmd" REQUIRE_MAP; then
            custom_allows+=("$cmd")
        fi
    done <<< "$current_allows"

    # Check for custom denies (not in our recommended list)
    local custom_denies=()
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        if ! command_in_map "$cmd" DENY_MAP; then
            custom_denies+=("$cmd")
        fi
    done <<< "$current_denies"

    # Check for commands that should be elsewhere
    local misplaced=()
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        if command_in_map "$cmd" DENY_MAP; then
            misplaced+=("⚠️  $cmd (in allow, should be denied)")
        elif command_in_map "$cmd" REQUIRE_MAP; then
            misplaced+=("ℹ️  $cmd (in allow, recommended: requireApproval for protected branches)")
        fi
    done <<< "$current_allows"

    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        if command_in_map "$cmd" ALLOW_MAP; then
            misplaced+=("⚠️  $cmd (in deny, should be allowed)")
        fi
    done <<< "$current_denies"

    # Show findings
    if [ ${#custom_allows[@]} -gt 0 ]; then
        echo -e "${YELLOW}Custom Allows (not in repo recommendations):${NC}"
        for cmd in "${custom_allows[@]}"; do
            echo "  • $cmd"
        done
        echo ""
    fi

    if [ ${#custom_denies[@]} -gt 0 ]; then
        echo -e "${YELLOW}Custom Denies (not in repo recommendations):${NC}"
        for cmd in "${custom_denies[@]}"; do
            echo "  • $cmd"
        done
        echo ""
    fi

    if [ ${#misplaced[@]} -gt 0 ]; then
        echo -e "${YELLOW}Potentially Misplaced Permissions:${NC}"
        for item in "${misplaced[@]}"; do
            echo "  $item"
        done
        echo ""
    fi

    if [ ${#custom_allows[@]} -eq 0 ] && [ ${#custom_denies[@]} -eq 0 ] && [ ${#misplaced[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No differences from recommended settings${NC}"
        echo ""
    fi
}

# Function to merge arrays (remove duplicates, handle conflicts)
merge_arrays_smart() {
    local settings_file="$1"
    local category="$2"  # allow, requireApproval, or deny
    shift 2
    local new_items=("$@")

    # Get existing items from this category
    local existing=$(jq -r ".permissions.bash.$category[]?" "$settings_file" 2>/dev/null | sort -u)

    # Get items from other categories to avoid conflicts
    local other_categories=()
    if [ "$category" != "allow" ]; then
        mapfile -t other_categories < <(jq -r '.permissions.bash.allow[]?' "$settings_file" 2>/dev/null)
    fi
    if [ "$category" != "requireApproval" ]; then
        mapfile -t -O "${#other_categories[@]}" other_categories < <(jq -r '.permissions.bash.requireApproval[]?' "$settings_file" 2>/dev/null)
    fi
    if [ "$category" != "deny" ]; then
        mapfile -t -O "${#other_categories[@]}" other_categories < <(jq -r '.permissions.bash.deny[]?' "$settings_file" 2>/dev/null)
    fi

    # Build associative array of other category items
    declare -A other_map
    for item in "${other_categories[@]}"; do
        other_map["$item"]=1
    done

    # Combine new items with existing (from this category only)
    local combined=()

    # Add existing items that aren't in other categories
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        if [[ -z "${other_map[$cmd]:-}" ]]; then
            combined+=("$cmd")
        fi
    done <<< "$existing"

    # Add new items that aren't already present and aren't in other categories
    for cmd in "${new_items[@]}"; do
        local already_present=false
        for existing_cmd in "${combined[@]}"; do
            if [ "$cmd" = "$existing_cmd" ]; then
                already_present=true
                break
            fi
        done

        if ! $already_present && [[ -z "${other_map[$cmd]:-}" ]]; then
            combined+=("$cmd")
        fi
    done

    # Sort and output
    printf "%s\n" "${combined[@]}" | sort -u
}

# Function to show permission changes
show_changes() {
    echo -e "${BLUE}🔐 Branch-Aware Permission Configuration${NC}"
    echo "───────────────────────────────────────"
    echo ""
    echo -e "${GREEN}AUTO-ALLOWED (no prompts - fast workflow):${NC}"
    echo "  All git/gh operations on feature branches"
    echo "  Total: ${#ALLOW_COMMANDS[@]} commands"
    echo "  Examples:"
    echo "    ✓ git commit (on feat/123)"
    echo "    ✓ git push origin feat/123"
    echo "    ✓ gh pr create"
    echo "    ✓ gh pr comment/review"
    echo ""
    echo -e "${YELLOW}REQUIRE APPROVAL (protected branch operations only):${NC}"
    echo "  Operations targeting main/master/production"
    echo "  Total: ${#REQUIRE_APPROVAL_COMMANDS[@]} commands"
    for cmd in "${REQUIRE_APPROVAL_COMMANDS[@]}"; do
        echo "    ⚠️  $cmd"
    done
    echo ""
    echo -e "${RED}ALWAYS DENIED (catastrophic operations):${NC}"
    echo "  Dangerous operations that could destroy data/repos"
    echo "  Total: ${#DENY_COMMANDS[@]} commands"
    echo "  Examples:"
    echo "    ✗ rm -rf /"
    echo "    ✗ git push --force origin main/master/production"
    echo "    ✗ gh repo delete"
    echo "    ✗ sudo, shutdown, etc."
    echo ""
    echo "───────────────────────────────────────"
    echo -e "${GREEN}Benefits:${NC}"
    echo "  ✓ Fast workflow on feature branches (no prompts)"
    echo "  ⚠️  Protection for production branches (approval required)"
    echo "  ✗ Safety net for catastrophic mistakes (always blocked)"
    echo ""
    echo -e "${MAGENTA}⚠️  IMPORTANT: --dangerously-skip-permissions bypasses ALL checks${NC}"
    echo -e "${MAGENTA}   Even deny rules won't protect you in skip mode!${NC}"
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

    # Check for conflicts in existing settings
    if detect_conflicts "$SETTINGS_FILE"; then
        echo -e "${RED}⚠️  WARNING: Conflicts detected in existing settings${NC}"
        echo "Some commands appear in multiple categories (allow/requireApproval/deny)"
        echo "These will be resolved by removing duplicates, keeping the most restrictive."
        echo ""
    fi

    # Show differences from recommended settings
    if [ -f "$SETTINGS_FILE" ]; then
        show_differences "$SETTINGS_FILE"
    fi

    # Show what will change
    show_changes

    # Create temporary file for updates
    local temp_file=$(mktemp)
    TEMP_FILES+=("$temp_file")

    # Start with existing settings
    cp "$SETTINGS_FILE" "$temp_file"

    # Ensure permissions.bash structure exists
    jq '.permissions.bash.allow //= [] |
        .permissions.bash.requireApproval //= [] |
        .permissions.bash.deny //= []' "$temp_file" > "${temp_file}.tmp"
    mv "${temp_file}.tmp" "$temp_file"

    # Merge arrays with smart conflict resolution
    local all_allow=$(merge_arrays_smart "$temp_file" "allow" "${ALLOW_COMMANDS[@]}")
    local all_require=$(merge_arrays_smart "$temp_file" "requireApproval" "${REQUIRE_APPROVAL_COMMANDS[@]}")
    local all_deny=$(merge_arrays_smart "$temp_file" "deny" "${DENY_COMMANDS[@]}")

    # Build JSON arrays
    local allow_json=$(echo "$all_allow" | jq -R . | jq -s .)
    local require_json=$(echo "$all_require" | jq -R . | jq -s .)
    local deny_json=$(echo "$all_deny" | jq -R . | jq -s .)

    # Update settings with merged arrays in single jq call
    jq --argjson allow "$allow_json" \
       --argjson require "$require_json" \
       --argjson deny "$deny_json" \
       '.permissions.bash.allow = $allow |
        .permissions.bash.requireApproval = $require |
        .permissions.bash.deny = $deny |
        ._comment = "Managed by fractary-repo plugin. Protected branches: main, master, production" |
        ._note = "Most operations auto-allowed. Approval required only for protected branch operations."' \
       "$temp_file" > "${temp_file}.tmp"

    mv "${temp_file}.tmp" "$temp_file"

    # Validate result
    if ! validate_json "$temp_file"; then
        echo -e "${RED}ERROR:${NC} Generated invalid JSON"
        exit 1
    fi

    # Write to settings file
    mv "$temp_file" "$SETTINGS_FILE"

    # Count changes (consistent with other scripts)
    local allow_count=$(echo "$all_allow" | grep -v '^$' | wc -l | tr -d ' ')
    local require_count=$(echo "$all_require" | grep -v '^$' | wc -l | tr -d ' ')
    local deny_count=$(echo "$all_deny" | grep -v '^$' | wc -l | tr -d ' ')

    echo ""
    echo -e "${GREEN}✅ Updated settings${NC}"
    echo "  Settings file: $SETTINGS_FILE"
    echo "  Backup: $BACKUP_FILE"
    echo ""
    echo "  Commands auto-allowed: $allow_count"
    echo "  Protected branch operations (require approval): $require_count"
    echo "  Dangerous operations (denied): $deny_count"
    echo ""
    echo -e "${GREEN}Fast workflow enabled!${NC} Most operations won't prompt."
    echo -e "${YELLOW}Protected:${NC} Operations on main/master/production require approval."
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

    # Check for conflicts
    if detect_conflicts "$SETTINGS_FILE"; then
        echo -e "${YELLOW}⚠️  Conflicts detected (commands in multiple categories)${NC}"
        echo "Run: /repo:init-permissions --mode setup (to fix)"
        echo ""
    fi

    # Show differences
    show_differences "$SETTINGS_FILE"

    # Check if critical commands are present
    local missing_safe=()
    for cmd in "git status" "git log" "git commit" "git push" "gh auth status" "gh auth login" "gh auth refresh"; do
        if ! jq -e ".permissions.bash.allow | index(\"$cmd\")" "$SETTINGS_FILE" >/dev/null 2>&1; then
            missing_safe+=("$cmd")
        fi
    done

    local missing_protected=()
    for cmd in "git push origin main" "git push origin master" "git push origin production"; do
        if ! jq -e ".permissions.bash.requireApproval | index(\"$cmd\")" "$SETTINGS_FILE" >/dev/null 2>&1; then
            missing_protected+=("$cmd")
        fi
    done

    local missing_denies=()
    for cmd in "rm -rf /" "git push --force origin main" "gh repo delete"; do
        if ! jq -e ".permissions.bash.deny | index(\"$cmd\")" "$SETTINGS_FILE" >/dev/null 2>&1; then
            missing_denies+=("$cmd")
        fi
    done

    if [ ${#missing_safe[@]} -eq 0 ] && [ ${#missing_protected[@]} -eq 0 ] && [ ${#missing_denies[@]} -eq 0 ]; then
        echo -e "${GREEN}✓${NC} All critical permissions configured correctly"
        echo -e "${GREEN}✓${NC} General operations: allowed (fast workflow)"
        echo -e "${YELLOW}✓${NC} Protected branch operations: require approval"
        echo -e "${RED}✓${NC} Dangerous operations: denied"
    else
        echo -e "${YELLOW}⚠${NC} Some permissions missing:"
        if [ ${#missing_safe[@]} -gt 0 ]; then
            echo "  Missing allows: ${missing_safe[*]}"
        fi
        if [ ${#missing_protected[@]} -gt 0 ]; then
            echo "  Missing protected (requireApproval): ${missing_protected[*]}"
        fi
        if [ ${#missing_denies[@]} -gt 0 ]; then
            echo "  Missing denies: ${missing_denies[*]}"
        fi
        echo ""
        echo "Run: /repo:init-permissions --mode setup"
        exit 1
    fi
}

# Function to reset permissions (optimized with single jq pass)
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

    # Build arrays of commands to remove
    local all_repo_commands=()
    all_repo_commands+=("${ALLOW_COMMANDS[@]}")
    all_repo_commands+=("${REQUIRE_APPROVAL_COMMANDS[@]}")
    all_repo_commands+=("${DENY_COMMANDS[@]}")

    # Create JSON array of commands to remove
    local commands_json=$(printf '%s\n' "${all_repo_commands[@]}" | jq -R . | jq -s .)

    # Remove all repo commands in single jq operation
    jq --argjson commands "$commands_json" '
        .permissions.bash.allow = (.permissions.bash.allow - $commands) |
        .permissions.bash.requireApproval = (.permissions.bash.requireApproval - $commands) |
        .permissions.bash.deny = (.permissions.bash.deny - $commands)
    ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"

    # Validate result
    if ! validate_json "${SETTINGS_FILE}.tmp"; then
        echo -e "${RED}ERROR:${NC} Generated invalid JSON"
        rm -f "${SETTINGS_FILE}.tmp"
        exit 1
    fi

    # Write back
    mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

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
