#!/bin/bash
# Repo Manager: GitHub List Stale Branches
# Lists branches that are stale (old or already merged)

set -euo pipefail

# Default values
DAYS_THRESHOLD=30
SHOW_MERGED_ONLY=false
SHOW_REMOTE=true
BASE_BRANCH="main"

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --days)
            shift
            DAYS_THRESHOLD="$1"
            ;;
        --merged-only)
            SHOW_MERGED_ONLY=true
            ;;
        --local-only)
            SHOW_REMOTE=false
            ;;
        --base)
            shift
            BASE_BRANCH="$1"
            ;;
        --help)
            echo "Usage: $0 [options]" >&2
            echo "Options:" >&2
            echo "  --days <n>         Show branches older than n days (default: 30)" >&2
            echo "  --merged-only      Show only merged branches" >&2
            echo "  --local-only       Check only local branches" >&2
            echo "  --base <branch>    Base branch for merge check (default: main)" >&2
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            echo "Use --help for usage information" >&2
            exit 2
            ;;
    esac
    shift
done

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 3
fi

# Protected branches that should never be listed as stale
PROTECTED_BRANCHES=("main" "master" "production" "staging" "develop")

# Ensure base branch exists
if ! git rev-parse --verify "$BASE_BRANCH" > /dev/null 2>&1; then
    echo "Error: Base branch '$BASE_BRANCH' does not exist" >&2
    exit 1
fi

# Fetch latest from remote
if [ "$SHOW_REMOTE" = true ]; then
    echo "Fetching latest from remote..." >&2
    git fetch --prune origin > /dev/null 2>&1
fi

# Calculate cutoff date
CUTOFF_DATE=$(date -d "$DAYS_THRESHOLD days ago" +%s 2>/dev/null || date -v-${DAYS_THRESHOLD}d +%s 2>/dev/null)

if [ -z "$CUTOFF_DATE" ]; then
    echo "Error: Failed to calculate cutoff date" >&2
    exit 1
fi

echo "Stale Branches Report"
echo "===================="
echo "Criteria:"
echo "  - Older than: $DAYS_THRESHOLD days"
if [ "$SHOW_MERGED_ONLY" = true ]; then
    echo "  - Filter: Merged to $BASE_BRANCH only"
fi
echo ""

STALE_BRANCHES=()

# Function to check if branch is protected
is_protected() {
    local branch="$1"
    for protected in "${PROTECTED_BRANCHES[@]}"; do
        if [ "$branch" = "$protected" ] || [ "$branch" = "origin/$protected" ]; then
            return 0
        fi
    done
    return 1
}

# Function to get branch last commit date
get_branch_date() {
    local branch="$1"
    git log -1 --format=%ct "$branch" 2>/dev/null
}

# Function to check if branch is merged
is_merged() {
    local branch="$1"
    local base="$2"
    git merge-base --is-ancestor "$branch" "$base" 2>/dev/null
    return $?
}

# Check local branches
echo "Local Branches:"
echo "---------------"

for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
    # Skip protected branches
    if is_protected "$branch"; then
        continue
    fi

    # Get last commit date
    LAST_COMMIT_DATE=$(get_branch_date "$branch")

    if [ -z "$LAST_COMMIT_DATE" ]; then
        continue
    fi

    # Check if stale
    if [ "$LAST_COMMIT_DATE" -lt "$CUTOFF_DATE" ]; then
        # Check if merged (if filter enabled)
        if [ "$SHOW_MERGED_ONLY" = true ]; then
            if is_merged "$branch" "$BASE_BRANCH"; then
                DAYS_OLD=$(( ($(date +%s) - LAST_COMMIT_DATE) / 86400 ))
                echo "  $branch ($DAYS_OLD days old, merged)"
                STALE_BRANCHES+=("$branch")
            fi
        else
            DAYS_OLD=$(( ($(date +%s) - LAST_COMMIT_DATE) / 86400 ))
            MERGED_STATUS="not merged"
            if is_merged "$branch" "$BASE_BRANCH"; then
                MERGED_STATUS="merged"
            fi
            echo "  $branch ($DAYS_OLD days old, $MERGED_STATUS)"
            STALE_BRANCHES+=("$branch")
        fi
    fi
done

if [ ${#STALE_BRANCHES[@]} -eq 0 ]; then
    echo "  (none)"
fi

# Check remote branches
if [ "$SHOW_REMOTE" = true ]; then
    echo ""
    echo "Remote Branches:"
    echo "----------------"

    REMOTE_STALE=()

    for branch in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin/); do
        # Skip protected branches and HEAD
        if is_protected "$branch" || [[ "$branch" == *"/HEAD" ]]; then
            continue
        fi

        # Get last commit date
        LAST_COMMIT_DATE=$(get_branch_date "$branch")

        if [ -z "$LAST_COMMIT_DATE" ]; then
            continue
        fi

        # Check if stale
        if [ "$LAST_COMMIT_DATE" -lt "$CUTOFF_DATE" ]; then
            # Check if merged (if filter enabled)
            if [ "$SHOW_MERGED_ONLY" = true ]; then
                if is_merged "$branch" "origin/$BASE_BRANCH"; then
                    DAYS_OLD=$(( ($(date +%s) - LAST_COMMIT_DATE) / 86400 ))
                    echo "  $branch ($DAYS_OLD days old, merged)"
                    REMOTE_STALE+=("$branch")
                fi
            else
                DAYS_OLD=$(( ($(date +%s) - LAST_COMMIT_DATE) / 86400 ))
                MERGED_STATUS="not merged"
                if is_merged "$branch" "origin/$BASE_BRANCH"; then
                    MERGED_STATUS="merged"
                fi
                echo "  $branch ($DAYS_OLD days old, $MERGED_STATUS)"
                REMOTE_STALE+=("$branch")
            fi
        fi
    done

    if [ ${#REMOTE_STALE[@]} -eq 0 ]; then
        echo "  (none)"
    fi
fi

# Summary
echo ""
echo "Summary:"
echo "--------"
echo "Local stale branches: ${#STALE_BRANCHES[@]}"
if [ "$SHOW_REMOTE" = true ]; then
    echo "Remote stale branches: ${#REMOTE_STALE[@]}"
fi

exit 0
