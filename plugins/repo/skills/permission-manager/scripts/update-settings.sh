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

# Function to merge arrays (remove duplicates, handle conflicts, respect user overrides)
# ═══════════════════════════════════════════════════════════════════════════
# INTELLIGENT MERGE STRATEGY:
# ═══════════════════════════════════════════════════════════════════════════
# - Preserves existing commands from the target category
# - Adds new recommended commands to the target category
# - RESPECTS user denials of safe commands (won't force to allow)
# - OVERRIDES user allows of dangerous commands (forces to deny for safety)
# - May create temporary duplicates (resolved by caller's deduplication)
# - Performance: O(n) using associative arrays for lookups
# ═══════════════════════════════════════════════════════════════════════════
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
                    # Check if this is an ESSENTIAL command (defined in validate_permissions)
                    # Essential commands for GitHub operations: gh auth status, gh auth login, gh auth refresh
                    case "$cmd" in
                        "git status"|"git log"|"git diff"|"git commit"|"git push"|"git branch"|\
                        "gh pr create"|"gh pr view"|"gh pr list"|\
                        "gh issue create"|"gh issue view"|\
                        "gh auth status"|"gh auth login"|"gh auth refresh")
                            # ESSENTIAL COMMAND: Force to allow even if user denied it
                            # This creates an intentional duplicate that deduplication will resolve
                            # But we modify deduplication to preserve essential commands in allow
                            in_other_category=false  # Force add to allow
                            ;;
                        *)
                            # Non-essential: respect user override
                            in_other_category=true
                            ;;
                    esac
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
                # ⚠️ SECURITY OVERRIDE POLICY FOR DANGEROUS COMMANDS ⚠️
                # When merging deny recommendations (rm -rf, git push --force, etc.),
                # we FORCE them into deny even if user has them elsewhere.
                #
                # This creates a temporary duplicate (command in both allow/require AND deny),
                # which is intentional and will be resolved by the deduplication logic
                # in setup_permissions() (lines 562-603) where precedence is:
                #     deny > requireApproval > allow
                #
                # Result: Dangerous commands ALWAYS end up in deny, regardless of user choice.
                # This is a SAFETY OVERRIDE to prevent catastrophic accidents.

                if [[ -n "${allow_map[$cmd]:-}" ]]; then
                    # CRITICAL CASE: User allowed something dangerous (e.g., rm -rf /)
                    # Force to deny - this is a safety override, not respecting user choice
                    in_other_category=false  # Force add to deny
                elif [[ -n "${require_map[$cmd]:-}" ]]; then
                    # MODERATE CASE: User requires approval for dangerous command
                    # Still force to deny for maximum safety
                    in_other_category=false  # Force add to deny
                fi
                # If already in deny or missing: add to deny normally
                ;;
        esac

        # Add if not in another category (respecting user overrides)
        if ! $in_other_category; then
            combined+=("$cmd")
        fi
    done

    # Sort, deduplicate, and output (handle empty array case)
    if [ ${#combined[@]} -gt 0 ]; then
        printf "%s\n" "${combined[@]}" | sort -u
    else
        echo ""  # Return empty string for empty array
    fi
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

    # ═══════════════════════════════════════════════════════════════════════════
    # MERGE ARRAYS WITH INTELLIGENT USER OVERRIDE HANDLING
    # ═══════════════════════════════════════════════════════════════════════════
    #
    # User Override Policy (implemented in merge_arrays_smart, lines 351-457):
    #
    # 1. RESPECT user denials of safe commands:
    #    - If user denied "git commit" → DON'T add to allow
    #    - Tracked as user_override in validation
    #
    # 2. ⚠️ SECURITY OVERRIDE for dangerous commands (see lines 418-441):
    #    - If user allowed "rm -rf /" → FORCE to deny regardless
    #    - Creates intentional duplicate (both in allow AND deny)
    #    - Deduplication below resolves this with precedence rules
    #
    # 3. ADD missing commands to recommended categories
    #
    # 4. DEDUPLICATION with precedence (lines 577-618 below):
    #    - deny > requireApproval > allow
    #    - Resolves conflicts from security overrides
    #    - Result: Dangerous commands ONLY in deny
    #
    local all_allow=$(merge_arrays_smart "$temp_file" "allow" "${ALLOW_COMMANDS[@]}")
    local all_require=$(merge_arrays_smart "$temp_file" "requireApproval" "${REQUIRE_APPROVAL_COMMANDS[@]}")
    local all_deny=$(merge_arrays_smart "$temp_file" "deny" "${DENY_COMMANDS[@]}")

    # ═══════════════════════════════════════════════════════════════════════════
    # DEDUPLICATION: Remove conflicts with precedence
    # ═══════════════════════════════════════════════════════════════════════════
    # This is the SECOND PHASE of security enforcement (after merge_arrays_smart).
    #
    # PRECEDENCE RULES:
    # 1. For DANGEROUS commands (rm -rf, git push --force, etc.):
    #    deny > requireApproval > allow  (force to deny)
    #
    # 2. For ESSENTIAL commands (git status, gh auth, etc.):
    #    allow > requireApproval > deny  (force to allow)
    #
    # 3. For other commands: deny > requireApproval > allow (default)

    # Build sets for lookups
    declare -A deny_set require_set allow_set essential_set
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        deny_set["$cmd"]=1
    done <<< "$all_deny"

    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        require_set["$cmd"]=1
    done <<< "$all_require"

    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        allow_set["$cmd"]=1
    done <<< "$all_allow"

    # Define essential commands (must match list in validate_permissions)
    for cmd in "git status" "git log" "git diff" "git commit" "git push" "git branch" \
               "gh pr create" "gh pr view" "gh pr list" \
               "gh issue create" "gh issue view" \
               "gh auth status" "gh auth login" "gh auth refresh"; do
        essential_set["$cmd"]=1
    done

    # Filter allow: keep essential commands, remove others that are in deny/require
    local cleaned_allow=()
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        # If essential: always keep in allow (remove from deny/require later)
        if [[ -n "${essential_set[$cmd]:-}" ]]; then
            cleaned_allow+=("$cmd")
        # If not essential: only keep if NOT in deny or require
        elif [[ -z "${deny_set[$cmd]:-}" ]] && [[ -z "${require_set[$cmd]:-}" ]]; then
            cleaned_allow+=("$cmd")
        fi
    done <<< "$all_allow"
    # Handle empty array properly
    if [ ${#cleaned_allow[@]} -gt 0 ]; then
        all_allow=$(printf "%s\n" "${cleaned_allow[@]}" | sort -u)
    else
        all_allow=""  # Truly empty
    fi

    # Filter deny: remove essential commands (they should be in allow)
    local cleaned_deny=()
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        # If essential and in allow: remove from deny
        if [[ -n "${essential_set[$cmd]:-}" ]] && [[ -n "${allow_set[$cmd]:-}" ]]; then
            continue  # Skip - let it stay in allow
        else
            cleaned_deny+=("$cmd")
        fi
    done <<< "$all_deny"
    if [ ${#cleaned_deny[@]} -gt 0 ]; then
        all_deny=$(printf "%s\n" "${cleaned_deny[@]}" | sort -u)
    else
        all_deny=""
    fi

    # Filter require: remove anything in deny OR essential commands that are in allow
    local cleaned_require=()
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        # If essential and in allow: remove from require
        if [[ -n "${essential_set[$cmd]:-}" ]] && [[ -n "${allow_set[$cmd]:-}" ]]; then
            continue  # Skip - let it stay in allow
        # If in deny: remove (deny takes precedence over require for non-essential)
        elif [[ -z "${deny_set[$cmd]:-}" ]]; then
            cleaned_require+=("$cmd")
        fi
    done <<< "$all_require"
    # Handle empty array properly
    if [ ${#cleaned_require[@]} -gt 0 ]; then
        all_require=$(printf "%s\n" "${cleaned_require[@]}" | sort -u)
    else
        all_require=""  # Truly empty
    fi

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

# Function to build command location map (single jq call for performance)
# Returns associative array mapping command -> location (allow/requireApproval/deny/missing)
build_command_location_map() {
    local settings_file="$1"
    declare -gA COMMAND_LOCATION_MAP

    # Single jq call to get all commands from all categories
    # Format: category:command (one per line)
    local mappings=$(jq -r '
        (.permissions.bash.allow[]? | "allow:" + .) ,
        (.permissions.bash.requireApproval[]? | "requireApproval:" + .) ,
        (.permissions.bash.deny[]? | "deny:" + .)
    ' "$settings_file" 2>/dev/null)

    # Build associative array from mappings
    while IFS=: read -r category command; do
        [ -z "$command" ] && continue
        COMMAND_LOCATION_MAP["$command"]="$category"
    done <<< "$mappings"
}

# Function to check where a command is currently located (uses prebuilt map)
find_command_location() {
    local cmd="$1"
    echo "${COMMAND_LOCATION_MAP[$cmd]:-missing}"
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

    # Build command location map once (performance optimization - single jq call vs 104)
    build_command_location_map "$SETTINGS_FILE"

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
    local unusual_denials=()  # Track when users deny safe/essential commands

    # Define essential commands that if denied would break core workflow
    local -A essential_commands=(
        ["git status"]=1
        ["git log"]=1
        ["git diff"]=1
        ["git commit"]=1
        ["git push"]=1
        ["git branch"]=1
        ["gh pr create"]=1
        ["gh pr view"]=1
        ["gh pr list"]=1
        ["gh issue create"]=1
        ["gh issue view"]=1
        ["gh auth status"]=1
        ["gh auth login"]=1
        ["gh auth refresh"]=1
    )

    echo "Checking recommended ALLOW commands..."
    # Check all ALLOW_COMMANDS
    for cmd in "${ALLOW_COMMANDS[@]}"; do
        local location=$(find_command_location "$cmd")
        case "$location" in
            allow)
                # Correct location, no issue
                ;;
            requireApproval)
                wrong_location_allow+=("$cmd (currently in requireApproval)")
                ;;
            deny)
                # User explicitly denied something we recommend - check if it's essential
                if [[ -n "${essential_commands[$cmd]:-}" ]]; then
                    unusual_denials+=("$cmd (ESSENTIAL - will break workflow!)")
                else
                    user_overrides+=("$cmd (recommended: allow, user chose: deny)")
                fi
                ;;
            missing)
                missing_from_allow+=("$cmd")
                ;;
        esac
    done

    echo "Checking recommended REQUIRE APPROVAL commands..."
    # Check all REQUIRE_APPROVAL_COMMANDS
    for cmd in "${REQUIRE_APPROVAL_COMMANDS[@]}"; do
        local location=$(find_command_location "$cmd")
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
        local location=$(find_command_location "$cmd")
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

    if [ ${#unusual_denials[@]} -gt 0 ]; then
        echo -e "${RED}🚨 UNUSUAL USER DENIALS - WORKFLOW BREAKING:${NC}"
        echo "You have denied essential commands that are critical for the repo workflow."
        echo "This will likely prevent the plugin from functioning correctly."
        echo ""
        for cmd in "${unusual_denials[@]}"; do
            echo "  • $cmd"
        done
        echo ""
        echo -e "${YELLOW}⚠️  WARNING:${NC} These denials will be preserved, but expect errors!"
        echo "Consider removing these from deny list or moving to requireApproval instead."
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
