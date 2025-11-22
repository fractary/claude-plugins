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
# Total: 61 commands
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

    # GitHub Actions workflow operations - read only (2 commands)
    "gh workflow list"
    "gh workflow view"

    # GitHub secrets management - read only (1 command)
    "gh secret list"

    # GitHub Apps management (2 commands)
    "gh app list"
    "gh app view"

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

# Commands that require approval
# Total: 13 commands
# Includes protected branch operations and potentially risky workflow/secrets operations
REQUIRE_APPROVAL_COMMANDS=(
    # Protected branch push operations (9 commands)
    "git push origin main"
    "git push origin master"
    "git push origin production"
    "git push -u origin main"
    "git push -u origin master"
    "git push -u origin production"
    "git push --set-upstream origin main"
    "git push --set-upstream origin master"
    "git push --set-upstream origin production"

    # GitHub Actions workflow write operations (3 commands)
    # These could trigger CI/CD runs or disable critical workflows
    "gh workflow run"
    "gh workflow enable"
    "gh workflow disable"

    # GitHub secrets write operations (1 command)
    # Could overwrite important secrets
    "gh secret set"
)

# Commands to deny (dangerous operations)
# Total: 40 commands
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

    # GitHub dangerous operations (4 commands)
    "gh repo delete"
    "gh repo archive"
    "gh secret delete"
    "gh secret remove"

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

    # Check for MISSING commands (should be present but aren't)
    local missing_allows=()
    for cmd in "${ALLOW_COMMANDS[@]}"; do
        if ! echo "$current_allows" | grep -qxF "$cmd"; then
            missing_allows+=("$cmd")
        fi
    done

    local missing_requires=()
    for cmd in "${REQUIRE_APPROVAL_COMMANDS[@]}"; do
        if ! echo "$current_requires" | grep -qxF "$cmd"; then
            missing_requires+=("$cmd")
        fi
    done

    local missing_denies=()
    for cmd in "${DENY_COMMANDS[@]}"; do
        if ! echo "$current_denies" | grep -qxF "$cmd"; then
            missing_denies+=("$cmd")
        fi
    done

    # Show findings
    if [ ${#missing_allows[@]} -gt 0 ]; then
        echo -e "${YELLOW}Missing from ALLOW list (${#missing_allows[@]} commands):${NC}"
        local show_count=$((${#missing_allows[@]} > 10 ? 10 : ${#missing_allows[@]}))
        for ((i=0; i<$show_count; i++)); do
            echo "  • ${missing_allows[$i]}"
        done
        if [ ${#missing_allows[@]} -gt 10 ]; then
            echo "  ... and $((${#missing_allows[@]} - 10)) more"
        fi
        echo ""
    fi

    if [ ${#missing_requires[@]} -gt 0 ]; then
        echo -e "${YELLOW}Missing from REQUIRE APPROVAL list (${#missing_requires[@]} commands):${NC}"
        for cmd in "${missing_requires[@]}"; do
            echo "  • $cmd"
        done
        echo ""
    fi

    if [ ${#missing_denies[@]} -gt 0 ]; then
        echo -e "${RED}Missing from DENY list (${#missing_denies[@]} commands):${NC}"
        local show_count=$((${#missing_denies[@]} > 10 ? 10 : ${#missing_denies[@]}))
        for ((i=0; i<$show_count; i++)); do
            echo "  • ${missing_denies[$i]}"
        done
        if [ ${#missing_denies[@]} -gt 10 ]; then
            echo "  ... and $((${#missing_denies[@]} - 10)) more"
        fi
        echo ""
    fi

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

    if [ ${#missing_allows[@]} -eq 0 ] && [ ${#missing_requires[@]} -eq 0 ] && [ ${#missing_denies[@]} -eq 0 ] && [ ${#custom_allows[@]} -eq 0 ] && [ ${#custom_denies[@]} -eq 0 ] && [ ${#misplaced[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ No differences from recommended settings${NC}"
        echo ""
    fi
}

# Function to merge arrays (remove duplicates, handle conflicts, respect user overrides)
merge_arrays_smart() {
    local settings_file="$1"
    local category="$2"  # allow, requireApproval, or deny
    shift 2
    local new_items=("$@")

    # Get existing items from this category
    local existing=$(jq -r ".permissions.bash.$category[]?" "$settings_file" 2>/dev/null | sort -u)

    # Get items from other categories to check for user overrides
    local in_allow=()
    local in_require=()
    local in_deny=()

    mapfile -t in_allow < <(jq -r '.permissions.bash.allow[]?' "$settings_file" 2>/dev/null)
    mapfile -t in_require < <(jq -r '.permissions.bash.requireApproval[]?' "$settings_file" 2>/dev/null)
    mapfile -t in_deny < <(jq -r '.permissions.bash.deny[]?' "$settings_file" 2>/dev/null)

    # Build associative arrays for O(1) lookups
    declare -A allow_map require_map deny_map
    for item in "${in_allow[@]}"; do allow_map["$item"]=1; done
    for item in "${in_require[@]}"; do require_map["$item"]=1; done
    for item in "${in_deny[@]}"; do deny_map["$item"]=1; done

    # Combine items respecting user overrides
    local combined=()

    # Add existing items from this category (preserve existing)
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        combined+=("$cmd")
    done <<< "$existing"

    # Add new items with smart conflict resolution
    for cmd in "${new_items[@]}"; do
        local already_in_category=false
        for existing_cmd in "${combined[@]}"; do
            if [ "$cmd" = "$existing_cmd" ]; then
                already_in_category=true
                break
            fi
        done

        # Skip if already in this category
        if $already_in_category; then
            continue
        fi

        # Check if command is in another category (user override)
        local in_other_category=false
        case "$category" in
            allow)
                # We're adding to allow, but check if user has it in require or deny
                if [[ -n "${require_map[$cmd]:-}" ]] || [[ -n "${deny_map[$cmd]:-}" ]]; then
                    in_other_category=true
                    # Special case: if user denied something we recommend allowing, respect their choice
                    # Don't add it to allow
                fi
                ;;
            requireApproval)
                # We're adding to requireApproval, check if user has it in allow or deny
                if [[ -n "${allow_map[$cmd]:-}" ]] || [[ -n "${deny_map[$cmd]:-}" ]]; then
                    in_other_category=true
                    # Respect user's more restrictive choice (deny) or less restrictive (allow)
                fi
                ;;
            deny)
                # We're adding to deny (dangerous commands)
                if [[ -n "${allow_map[$cmd]:-}" ]]; then
                    # CRITICAL: User allowed something dangerous we recommend denying
                    # We should still add it to deny and remove from allow
                    # The duplicate will be resolved by the calling code
                    in_other_category=false  # Force add to deny for safety
                elif [[ -n "${require_map[$cmd]:-}" ]]; then
                    # User requires approval for something we recommend denying
                    # Less critical, but still add to deny
                    in_other_category=false  # Force add to deny for safety
                fi
                ;;
        esac

        # Add if not in another category (respecting user overrides)
        if ! $in_other_category; then
            combined+=("$cmd")
        fi
    done

    # Sort, deduplicate, and output
    printf "%s\n" "${combined[@]}" | sort -u
}

# Function to analyze permission deltas (what's new vs existing)
analyze_permission_deltas() {
    local settings_file="$1"

    # Get current permissions
    local current_allows=()
    local current_requires=()
    local current_denies=()

    if [ -f "$settings_file" ]; then
        mapfile -t current_allows < <(jq -r '.permissions.bash.allow[]?' "$settings_file" 2>/dev/null | sort -u)
        mapfile -t current_requires < <(jq -r '.permissions.bash.requireApproval[]?' "$settings_file" 2>/dev/null | sort -u)
        mapfile -t current_denies < <(jq -r '.permissions.bash.deny[]?' "$settings_file" 2>/dev/null | sort -u)
    fi

    # Build lookup maps for current state
    declare -A current_allow_map current_require_map current_deny_map
    for cmd in "${current_allows[@]}"; do current_allow_map["$cmd"]=1; done
    for cmd in "${current_requires[@]}"; do current_require_map["$cmd"]=1; done
    for cmd in "${current_denies[@]}"; do current_deny_map["$cmd"]=1; done

    # Analyze ALLOW commands
    local new_allows=()
    local preserved_allows=()
    for cmd in "${ALLOW_COMMANDS[@]}"; do
        if [[ -n "${current_allow_map[$cmd]:-}" ]]; then
            preserved_allows+=("$cmd")
        elif [[ -z "${current_require_map[$cmd]:-}" ]] && [[ -z "${current_deny_map[$cmd]:-}" ]]; then
            new_allows+=("$cmd")
        fi
    done

    # Analyze REQUIRE APPROVAL commands
    local new_requires=()
    local preserved_requires=()
    for cmd in "${REQUIRE_APPROVAL_COMMANDS[@]}"; do
        if [[ -n "${current_require_map[$cmd]:-}" ]]; then
            preserved_requires+=("$cmd")
        elif [[ -z "${current_allow_map[$cmd]:-}" ]] && [[ -z "${current_deny_map[$cmd]:-}" ]]; then
            new_requires+=("$cmd")
        fi
    done

    # Analyze DENY commands
    local new_denies=()
    local preserved_denies=()
    for cmd in "${DENY_COMMANDS[@]}"; do
        if [[ -n "${current_deny_map[$cmd]:-}" ]]; then
            preserved_denies+=("$cmd")
        else
            new_denies+=("$cmd")
        fi
    done

    # Count non-repo custom commands (user's own additions)
    local custom_allows=()
    for cmd in "${current_allows[@]}"; do
        if ! command_in_map "$cmd" ALLOW_MAP && ! command_in_map "$cmd" REQUIRE_MAP; then
            custom_allows+=("$cmd")
        fi
    done

    local custom_denies=()
    for cmd in "${current_denies[@]}"; do
        if ! command_in_map "$cmd" DENY_MAP; then
            custom_denies+=("$cmd")
        fi
    done

    # Export results as global variables for use in show_changes
    NEW_ALLOWS=("${new_allows[@]}")
    PRESERVED_ALLOWS=("${preserved_allows[@]}")
    NEW_REQUIRES=("${new_requires[@]}")
    PRESERVED_REQUIRES=("${preserved_requires[@]}")
    NEW_DENIES=("${new_denies[@]}")
    PRESERVED_DENIES=("${preserved_denies[@]}")
    CUSTOM_ALLOWS=("${custom_allows[@]}")
    CUSTOM_DENIES=("${custom_denies[@]}")
}

# Function to categorize and display commands with reasoning
show_command_category() {
    local category_name="$1"
    local category_description="$2"
    local category_reasoning="$3"
    shift 3
    local commands=("$@")

    if [ ${#commands[@]} -eq 0 ]; then
        return
    fi

    echo -e "${BLUE}${category_name}${NC}"
    echo "  ${category_description}"
    echo -e "  ${MAGENTA}Why: ${category_reasoning}${NC}"

    # Show first 5 commands as examples
    local show_count=$((${#commands[@]} > 5 ? 5 : ${#commands[@]}))
    for ((i=0; i<$show_count; i++)); do
        echo "    • ${commands[$i]}"
    done
    if [ ${#commands[@]} -gt 5 ]; then
        echo "    ... and $((${#commands[@]} - 5)) more"
    fi
    echo ""
}

# Function to show permission changes with detailed categorization
show_changes() {
    # High-level philosophy
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║  Permission Configuration Philosophy                               ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "We carefully balance agent autonomy with safety:"
    echo ""
    echo -e "${GREEN}✓ MAXIMIZE AUTONOMY:${NC} Auto-approve safe operations so you're not"
    echo "  constantly clicking 'yes' for routine git/GitHub commands."
    echo ""
    echo -e "${YELLOW}⚠️  PROTECT CRITICAL PATHS:${NC} Require explicit approval for operations"
    echo "  on protected branches (main/master/production) to prevent accidents."
    echo ""
    echo -e "${RED}✗ BLOCK CATASTROPHIC MISTAKES:${NC} Deny destructive operations that could"
    echo "  destroy your repo, system, or execute remote code."
    echo ""
    echo "This configuration lets the agent work efficiently while keeping you safe."
    echo ""

    # Analyze deltas
    analyze_permission_deltas "$SETTINGS_FILE"

    # Show summary of changes
    echo "───────────────────────────────────────────────────────────────────"
    echo -e "${BLUE}📊 Permission Changes Summary${NC}"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    if [ ${#NEW_ALLOWS[@]} -gt 0 ] || [ ${#NEW_REQUIRES[@]} -gt 0 ] || [ ${#NEW_DENIES[@]} -gt 0 ]; then
        echo -e "${GREEN}New Permissions to Add:${NC}"

        # Categorize new allows
        local new_git_read=()
        local new_git_write=()
        local new_gh_read=()
        local new_gh_write=()
        local new_utilities=()

        for cmd in "${NEW_ALLOWS[@]}"; do
            if [[ "$cmd" == git\ * ]]; then
                if [[ "$cmd" =~ ^git\ (status|branch|log|diff|show|rev-parse|for-each-ref|ls-remote|show-ref|config)$ ]]; then
                    new_git_read+=("$cmd")
                else
                    new_git_write+=("$cmd")
                fi
            elif [[ "$cmd" == gh\ * ]]; then
                if [[ "$cmd" =~ ^gh\ (pr\ view|pr\ list|pr\ status|issue\ view|issue\ list|repo\ view|auth\ status)$ ]]; then
                    new_gh_read+=("$cmd")
                else
                    new_gh_write+=("$cmd")
                fi
            else
                new_utilities+=("$cmd")
            fi
        done

        if [ ${#new_git_read[@]} -gt 0 ]; then
            local examples=$(printf ", %s" "${new_git_read[@]:0:5}" | cut -c 3-)
            [ ${#new_git_read[@]} -gt 5 ] && examples="$examples, ..."
            echo "  ✅ ${#new_git_read[@]} safe git read operations"
            echo "     ($examples)"
        fi
        if [ ${#new_git_write[@]} -gt 0 ]; then
            local examples=$(printf ", %s" "${new_git_write[@]:0:5}" | cut -c 3-)
            [ ${#new_git_write[@]} -gt 5 ] && examples="$examples, ..."
            echo "  ✅ ${#new_git_write[@]} git write operations"
            echo "     ($examples)"
        fi
        if [ ${#new_gh_read[@]} -gt 0 ]; then
            local examples=$(printf ", %s" "${new_gh_read[@]:0:5}" | cut -c 3-)
            [ ${#new_gh_read[@]} -gt 5 ] && examples="$examples, ..."
            echo "  ✅ ${#new_gh_read[@]} GitHub read operations"
            echo "     ($examples)"
        fi
        if [ ${#new_gh_write[@]} -gt 0 ]; then
            local examples=$(printf ", %s" "${new_gh_write[@]:0:5}" | cut -c 3-)
            [ ${#new_gh_write[@]} -gt 5 ] && examples="$examples, ..."
            echo "  ✅ ${#new_gh_write[@]} GitHub write operations"
            echo "     ($examples)"
        fi
        if [ ${#new_utilities[@]} -gt 0 ]; then
            local examples=$(printf ", %s" "${new_utilities[@]:0:5}" | cut -c 3-)
            [ ${#new_utilities[@]} -gt 5 ] && examples="$examples, ..."
            echo "  ✅ ${#new_utilities[@]} safe utility commands"
            echo "     ($examples)"
        fi
        if [ ${#NEW_REQUIRES[@]} -gt 0 ]; then
            local examples=$(printf ", %s" "${NEW_REQUIRES[@]:0:3}" | cut -c 3-)
            [ ${#NEW_REQUIRES[@]} -gt 3 ] && examples="$examples, ..."
            echo "  ⚠️  ${#NEW_REQUIRES[@]} protected branch operations (require approval)"
            echo "     ($examples)"
        fi

        # Categorize new denies
        local new_file_destructive=()
        local new_git_dangerous=()
        local new_gh_dangerous=()
        local new_system_ops=()
        local new_network_rce=()

        for cmd in "${NEW_DENIES[@]}"; do
            if [[ "$cmd" =~ ^(rm|dd|mkfs|format) ]]; then
                new_file_destructive+=("$cmd")
            elif [[ "$cmd" =~ ^git\ (push\ .*--force|reset\ --hard|clean|filter-branch|rebase\ --onto) ]]; then
                new_git_dangerous+=("$cmd")
            elif [[ "$cmd" =~ ^gh\ (repo\ delete|repo\ archive|secret\ delete) ]]; then
                new_gh_dangerous+=("$cmd")
            elif [[ "$cmd" =~ ^(sudo|su|chmod|chown|kill|pkill|shutdown|reboot|init|systemctl) ]]; then
                new_system_ops+=("$cmd")
            elif [[ "$cmd" =~ (curl|wget).*\|.*(sh|bash) ]]; then
                new_network_rce+=("$cmd")
            fi
        done

        if [ ${#new_file_destructive[@]} -gt 0 ]; then
            local examples=$(printf ", %s" "${new_file_destructive[@]:0:4}" | cut -c 3-)
            [ ${#new_file_destructive[@]} -gt 4 ] && examples="$examples, ..."
            echo "  ❌ ${#new_file_destructive[@]} destructive file operations"
            echo "     ($examples)"
        fi
        if [ ${#new_git_dangerous[@]} -gt 0 ]; then
            local examples=$(printf ", %s" "${new_git_dangerous[@]:0:4}" | cut -c 3-)
            [ ${#new_git_dangerous[@]} -gt 4 ] && examples="$examples, ..."
            echo "  ❌ ${#new_git_dangerous[@]} dangerous git operations"
            echo "     ($examples)"
        fi
        if [ ${#new_gh_dangerous[@]} -gt 0 ]; then
            local examples=$(printf ", %s" "${new_gh_dangerous[@]:0:3}" | cut -c 3-)
            echo "  ❌ ${#new_gh_dangerous[@]} dangerous GitHub operations"
            echo "     ($examples)"
        fi
        if [ ${#new_system_ops[@]} -gt 0 ]; then
            local examples=$(printf ", %s" "${new_system_ops[@]:0:5}" | cut -c 3-)
            [ ${#new_system_ops[@]} -gt 5 ] && examples="$examples, ..."
            echo "  ❌ ${#new_system_ops[@]} system operations"
            echo "     ($examples)"
        fi
        if [ ${#new_network_rce[@]} -gt 0 ]; then
            local examples=$(printf ", %s" "${new_network_rce[@]}" | cut -c 3-)
            echo "  ❌ ${#new_network_rce[@]} remote code execution patterns"
            echo "     ($examples)"
        fi

        echo ""
    fi

    if [ ${#PRESERVED_ALLOWS[@]} -gt 0 ] || [ ${#PRESERVED_REQUIRES[@]} -gt 0 ] || [ ${#PRESERVED_DENIES[@]} -gt 0 ]; then
        echo -e "${BLUE}Existing Permissions (Preserved):${NC}"
        if [ ${#PRESERVED_ALLOWS[@]} -gt 0 ]; then
            echo "  ✅ ${#PRESERVED_ALLOWS[@]} commands already allowed"
        fi
        if [ ${#PRESERVED_REQUIRES[@]} -gt 0 ]; then
            echo "  ⚠️  ${#PRESERVED_REQUIRES[@]} commands already require approval"
        fi
        if [ ${#PRESERVED_DENIES[@]} -gt 0 ]; then
            echo "  ❌ ${#PRESERVED_DENIES[@]} commands already denied"
        fi
        echo ""
    fi

    if [ ${#CUSTOM_ALLOWS[@]} -gt 0 ] || [ ${#CUSTOM_DENIES[@]} -gt 0 ]; then
        echo -e "${MAGENTA}Custom Permissions (Your additions - will be preserved):${NC}"
        if [ ${#CUSTOM_ALLOWS[@]} -gt 0 ]; then
            echo "  • ${#CUSTOM_ALLOWS[@]} custom allowed commands"
        fi
        if [ ${#CUSTOM_DENIES[@]} -gt 0 ]; then
            echo "  • ${#CUSTOM_DENIES[@]} custom denied commands"
        fi
        echo ""
    fi

    # Show detailed breakdown with reasoning
    echo "───────────────────────────────────────────────────────────────────"
    echo -e "${BLUE}📋 Detailed Permission Breakdown${NC}"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    if [ ${#NEW_ALLOWS[@]} -gt 0 ]; then
        echo -e "${GREEN}══════ NEW AUTO-ALLOWED COMMANDS (No prompts) ══════${NC}"
        echo ""

        show_command_category \
            "Git Read Operations (${#new_git_read[@]} commands)" \
            "Check repository state without modifying anything" \
            "These are 100% safe - they only read info, never modify your repo" \
            "${new_git_read[@]}"

        show_command_category \
            "Git Write Operations (${#new_git_write[@]} commands)" \
            "Normal git workflow operations on any branch" \
            "Safe for daily work - commits, pushes to feature branches, merges, etc." \
            "${new_git_write[@]}"

        show_command_category \
            "GitHub Read Operations (${#new_gh_read[@]} commands)" \
            "View PRs, issues, and repository information" \
            "Read-only GitHub operations - no risk of modifying or deleting anything" \
            "${new_gh_read[@]}"

        show_command_category \
            "GitHub Write Operations (${#new_gh_write[@]} commands)" \
            "Create PRs, add comments, manage issues" \
            "Standard GitHub workflow - these operations are reversible and safe" \
            "${new_gh_write[@]}"

        show_command_category \
            "Safe Utilities (${#new_utilities[@]} commands)" \
            "Read files and process data" \
            "Common Unix tools for viewing and processing files - all read-only" \
            "${new_utilities[@]}"
    fi

    if [ ${#NEW_REQUIRES[@]} -gt 0 ]; then
        echo -e "${YELLOW}══════ NEW REQUIRE APPROVAL (Protected branches) ══════${NC}"
        echo ""
        echo "Operations targeting main/master/production branches"
        echo -e "${MAGENTA}Why: Extra confirmation prevents accidental changes to production${NC}"
        echo ""
        for cmd in "${NEW_REQUIRES[@]}"; do
            echo "  ⚠️  $cmd"
        done
        echo ""
    fi

    if [ ${#NEW_DENIES[@]} -gt 0 ]; then
        echo -e "${RED}══════ NEW BLOCKED COMMANDS (Always denied) ══════${NC}"
        echo ""

        show_command_category \
            "Destructive File Operations (${#new_file_destructive[@]} commands)" \
            "Commands that could destroy your filesystem" \
            "These could wipe your entire disk or critical directories - always blocked" \
            "${new_file_destructive[@]}"

        show_command_category \
            "Dangerous Git Operations (${#new_git_dangerous[@]} commands)" \
            "Git commands that could corrupt or destroy repository history" \
            "Force pushing to protected branches could destroy team's work - blocked" \
            "${new_git_dangerous[@]}"

        show_command_category \
            "Dangerous GitHub Operations (${#new_gh_dangerous[@]} commands)" \
            "GitHub operations that could delete repositories or secrets" \
            "Irreversible repository deletion and secret management - blocked" \
            "${new_gh_dangerous[@]}"

        show_command_category \
            "System Operations (${#new_system_ops[@]} commands)" \
            "Commands requiring root or that could crash your system" \
            "Privilege escalation and system control - blocked for security" \
            "${new_system_ops[@]}"

        show_command_category \
            "Remote Code Execution (${#new_network_rce[@]} commands)" \
            "Download and execute code from the internet" \
            "Classic attack vector (curl | sh) - extremely dangerous, always blocked" \
            "${new_network_rce[@]}"
    fi

    echo "───────────────────────────────────────────────────────────────────"
    echo -e "${GREEN}Benefits of This Configuration:${NC}"
    echo ""
    echo "  ✓ Smooth workflow - No interruptions for routine operations"
    echo "  ✓ Smart protection - Approval required only for risky operations"
    echo "  ✓ Safety net - Catastrophic mistakes blocked automatically"
    echo "  ✓ Team friendly - Prevents accidentally breaking shared branches"
    echo "  ✓ Security first - Blocks common attack patterns and dangerous commands"
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
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

    # Request user confirmation
    echo -e "${YELLOW}Do you want to apply these permission changes?${NC}"
    echo -e "Type ${GREEN}yes${NC} to apply, or ${RED}no${NC} to cancel: "
    read -r confirmation

    if [[ "$confirmation" != "yes" ]]; then
        echo ""
        echo -e "${YELLOW}❌ Permission update cancelled${NC}"
        echo "No changes made to settings.json"
        echo ""
        exit 0
    fi

    echo ""
    echo -e "${GREEN}Applying changes...${NC}"
    echo ""

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
    # User Override Policy:
    # - If user has denied something we recommend allowing: RESPECT their choice (don't add to allow)
    # - If user has allowed something we recommend denying: OVERRIDE for safety (force to deny)
    # - Missing commands: ADD to recommended categories
    # - After merge: cleanup with precedence (deny > requireApproval > allow)
    local all_allow=$(merge_arrays_smart "$temp_file" "allow" "${ALLOW_COMMANDS[@]}")
    local all_require=$(merge_arrays_smart "$temp_file" "requireApproval" "${REQUIRE_APPROVAL_COMMANDS[@]}")
    local all_deny=$(merge_arrays_smart "$temp_file" "deny" "${DENY_COMMANDS[@]}")

    # Cleanup: Remove duplicates across categories with precedence (deny > requireApproval > allow)
    # This ensures dangerous commands end up only in deny, not also in allow
    declare -A deny_set require_set
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        deny_set["$cmd"]=1
    done <<< "$all_deny"

    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        require_set["$cmd"]=1
    done <<< "$all_require"

    # Filter allow: remove anything in deny or require
    local cleaned_allow=()
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        if [[ -z "${deny_set[$cmd]:-}" ]] && [[ -z "${require_set[$cmd]:-}" ]]; then
            cleaned_allow+=("$cmd")
        fi
    done <<< "$all_allow"
    all_allow=$(printf "%s\n" "${cleaned_allow[@]}" | sort -u)

    # Filter require: remove anything in deny
    local cleaned_require=()
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        if [[ -z "${deny_set[$cmd]:-}" ]]; then
            cleaned_require+=("$cmd")
        fi
    done <<< "$all_require"
    all_require=$(printf "%s\n" "${cleaned_require[@]}" | sort -u)

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

# Function to check where a command is currently located in settings
find_command_location() {
    local cmd="$1"
    local settings_file="$2"

    if jq -e ".permissions.bash.allow | index(\"$cmd\")" "$settings_file" >/dev/null 2>&1; then
        echo "allow"
    elif jq -e ".permissions.bash.requireApproval | index(\"$cmd\")" "$settings_file" >/dev/null 2>&1; then
        echo "requireApproval"
    elif jq -e ".permissions.bash.deny | index(\"$cmd\")" "$settings_file" >/dev/null 2>&1; then
        echo "deny"
    else
        echo "missing"
    fi
}

# Function to validate permissions (comprehensive check of ALL commands)
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

    echo -e "${BLUE}🔐 Comprehensive Permissions Validation${NC}"
    echo "───────────────────────────────────────"
    echo ""

    # Check for conflicts (commands in multiple categories simultaneously)
    local has_conflicts=false
    if detect_conflicts "$SETTINGS_FILE"; then
        echo -e "${RED}✗ CONFLICTS DETECTED:${NC} Some commands appear in multiple categories"
        echo "  This should not happen and will be fixed by running setup."
        echo ""
        has_conflicts=true
    fi

    # Track all issues
    local missing_from_allow=()
    local missing_from_require=()
    local missing_from_deny=()
    local wrong_location_allow=()
    local wrong_location_require=()
    local wrong_location_deny=()
    local user_overrides=()

    echo "Checking recommended ALLOW commands..."
    # Check all ALLOW_COMMANDS
    for cmd in "${ALLOW_COMMANDS[@]}"; do
        local location=$(find_command_location "$cmd" "$SETTINGS_FILE")
        case "$location" in
            allow)
                # Correct location, no issue
                ;;
            requireApproval)
                wrong_location_allow+=("$cmd (currently in requireApproval)")
                ;;
            deny)
                # User explicitly denied something we recommend - respect this as override
                user_overrides+=("$cmd (recommended: allow, user chose: deny)")
                ;;
            missing)
                missing_from_allow+=("$cmd")
                ;;
        esac
    done

    echo "Checking recommended REQUIRE APPROVAL commands..."
    # Check all REQUIRE_APPROVAL_COMMANDS
    for cmd in "${REQUIRE_APPROVAL_COMMANDS[@]}"; do
        local location=$(find_command_location "$cmd" "$SETTINGS_FILE")
        case "$location" in
            requireApproval)
                # Correct location, no issue
                ;;
            allow)
                wrong_location_require+=("$cmd (currently in allow)")
                ;;
            deny)
                # User explicitly denied something we recommend requiring approval - respect this
                user_overrides+=("$cmd (recommended: requireApproval, user chose: deny)")
                ;;
            missing)
                missing_from_require+=("$cmd")
                ;;
        esac
    done

    echo "Checking recommended DENY commands..."
    # Check all DENY_COMMANDS
    for cmd in "${DENY_COMMANDS[@]}"; do
        local location=$(find_command_location "$cmd" "$SETTINGS_FILE")
        case "$location" in
            deny)
                # Correct location, no issue
                ;;
            allow)
                # User allowed something dangerous we recommend denying - CRITICAL WARNING
                wrong_location_deny+=("$cmd (currently in allow) ⚠️  DANGEROUS")
                ;;
            requireApproval)
                # User requires approval for something we recommend denying - less critical but still note it
                wrong_location_deny+=("$cmd (currently in requireApproval)")
                ;;
            missing)
                missing_from_deny+=("$cmd")
                ;;
        esac
    done

    echo ""
    echo "───────────────────────────────────────"
    echo ""

    # Report all findings
    local has_issues=false

    if [ ${#missing_from_allow[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Missing from ALLOW list (${#missing_from_allow[@]} commands):${NC}"
        for cmd in "${missing_from_allow[@]}"; do
            echo "  • $cmd"
        done
        echo ""
        has_issues=true
    fi

    if [ ${#missing_from_require[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Missing from REQUIRE APPROVAL list (${#missing_from_require[@]} commands):${NC}"
        for cmd in "${missing_from_require[@]}"; do
            echo "  • $cmd"
        done
        echo ""
        has_issues=true
    fi

    if [ ${#missing_from_deny[@]} -gt 0 ]; then
        echo -e "${RED}⚠ Missing from DENY list (${#missing_from_deny[@]} commands):${NC}"
        for cmd in "${missing_from_deny[@]}"; do
            echo "  • $cmd"
        done
        echo ""
        has_issues=true
    fi

    if [ ${#wrong_location_allow[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Commands in WRONG category (should be in ALLOW):${NC}"
        for cmd in "${wrong_location_allow[@]}"; do
            echo "  • $cmd"
        done
        echo ""
        has_issues=true
    fi

    if [ ${#wrong_location_require[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Commands in WRONG category (should be in REQUIRE APPROVAL):${NC}"
        for cmd in "${wrong_location_require[@]}"; do
            echo "  • $cmd"
        done
        echo ""
        has_issues=true
    fi

    if [ ${#wrong_location_deny[@]} -gt 0 ]; then
        echo -e "${RED}⚠ Commands in WRONG category (should be in DENY):${NC}"
        for cmd in "${wrong_location_deny[@]}"; do
            echo "  • $cmd"
        done
        echo ""
        has_issues=true
    fi

    if [ ${#user_overrides[@]} -gt 0 ]; then
        echo -e "${MAGENTA}ℹ User Overrides Detected (will be preserved):${NC}"
        for cmd in "${user_overrides[@]}"; do
            echo "  • $cmd"
        done
        echo ""
    fi

    # Final verdict
    echo "───────────────────────────────────────"
    if [ "$has_conflicts" = true ] || [ "$has_issues" = true ]; then
        echo ""
        echo -e "${RED}✗ Validation Failed${NC}"
        echo ""
        echo "Your settings differ from the recommended configuration."
        echo ""
        echo -e "${GREEN}To fix:${NC} /repo:init-permissions --mode setup"
        echo ""
        echo "Setup mode will:"
        echo "  • Add all missing commands to correct categories"
        echo "  • Move misplaced commands to correct categories"
        echo "  • Preserve your custom user overrides (deny preferences)"
        echo "  • Create backup before making changes"
        exit 1
    else
        echo ""
        echo -e "${GREEN}✓ Validation Passed${NC}"
        echo ""
        echo "Your permissions match the recommended configuration:"
        echo "  • ${#ALLOW_COMMANDS[@]} commands in ALLOW (auto-approved)"
        echo "  • ${#REQUIRE_APPROVAL_COMMANDS[@]} commands in REQUIRE APPROVAL (protected branches)"
        echo "  • ${#DENY_COMMANDS[@]} commands in DENY (dangerous operations)"
        if [ ${#user_overrides[@]} -gt 0 ]; then
            echo "  • ${#user_overrides[@]} user overrides (preserved)"
        fi
        echo ""
        echo -e "${GREEN}Your repo operations are properly configured!${NC}"
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
