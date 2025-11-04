#!/bin/bash
# Repo Manager: GitHub Push Branch
# Pushes branch to remote repository with auto-sync support

set -euo pipefail

# Check arguments
# If branch name not provided, use current branch
if [ $# -lt 1 ] || [ -z "$1" ]; then
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -z "$BRANCH_NAME" ] || [ "$BRANCH_NAME" = "HEAD" ]; then
        echo "Error: Not on a branch and no branch name provided" >&2
        exit 2
    fi
    FORCE="${1:-false}"
    SET_UPSTREAM="${2:-false}"
    SYNC_STRATEGY="${3:-auto-merge}"
else
    BRANCH_NAME="$1"
    FORCE="${2:-false}"
    SET_UPSTREAM="${3:-false}"
    SYNC_STRATEGY="${4:-auto-merge}"
fi

# Validate sync strategy - only allow known values
case "$SYNC_STRATEGY" in
    auto-merge|pull-rebase|pull-merge|manual|fail)
        # Valid strategy
        ;;
    *)
        echo "Error: Invalid sync strategy: $SYNC_STRATEGY" >&2
        echo "Valid options: auto-merge, pull-rebase, pull-merge, manual, fail" >&2
        exit 2
        ;;
esac

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 3
fi

# Check if branch exists
if ! git rev-parse --verify "$BRANCH_NAME" > /dev/null 2>&1; then
    echo "Error: Branch '$BRANCH_NAME' does not exist" >&2
    exit 1
fi

# Function to attempt push
attempt_push() {
    # Build git push arguments array to avoid eval and ensure proper quoting
    local -a git_args=(push)

    # Add force flag if requested
    if [ "$FORCE" = "true" ]; then
        git_args+=(--force-with-lease)
    fi

    # Add upstream flag if requested
    if [ "$SET_UPSTREAM" = "true" ]; then
        git_args+=(-u)
    fi

    # Add remote and branch (using -- to separate options from arguments)
    git_args+=(origin "$BRANCH_NAME")

    # Capture push output and return code
    local push_output
    local push_rc=0
    push_output=$(git "${git_args[@]}" 2>&1) || push_rc=$?

    if [ "${push_rc}" -eq 0 ]; then
        echo "Branch '$BRANCH_NAME' pushed to origin"
        return 0
    fi

    # Check if failure is due to non-fast-forward (out of sync)
    if echo "$push_output" | grep -q "non-fast-forward\|rejected\|fetch first"; then
        echo "$push_output" >&2
        return 13  # Exit code 13 for non-fast-forward
    else
        # Other error
        echo "$push_output" >&2
        echo "Error: Failed to push branch '$BRANCH_NAME'" >&2
        return 12
    fi
}

# Function to sync branch based on strategy
sync_branch() {
    local strategy="$1"

    echo "Branch is out of sync with remote. Applying sync strategy: $strategy" >&2

    case "$strategy" in
        auto-merge)
            echo "Pulling and merging remote changes..." >&2
            if ! git pull origin "$BRANCH_NAME" --no-edit 2>&1; then
                echo "Error: Auto-merge failed. Manual intervention required." >&2
                echo "Run: git pull origin \"$BRANCH_NAME\"" >&2
                return 13
            fi
            echo "✓ Auto-merge successful" >&2
            return 0
            ;;

        pull-rebase)
            echo "Pulling and rebasing local commits..." >&2
            if ! git pull origin "$BRANCH_NAME" --rebase 2>&1; then
                echo "Error: Rebase failed. Manual intervention required." >&2
                echo "Run: git pull origin \"$BRANCH_NAME\" --rebase" >&2
                echo "Resolve conflicts and run: git rebase --continue" >&2
                return 13
            fi
            echo "✓ Rebase successful" >&2
            return 0
            ;;

        pull-merge)
            echo "Pulling with merge commit..." >&2
            if ! git pull origin "$BRANCH_NAME" 2>&1; then
                echo "Error: Pull merge failed. Manual intervention required." >&2
                echo "Run: git pull origin \"$BRANCH_NAME\"" >&2
                return 13
            fi
            echo "✓ Pull merge successful" >&2
            return 0
            ;;

        manual)
            echo "Manual sync required. Please resolve the conflict manually:" >&2
            echo "  git fetch origin" >&2
            echo "  git merge origin/\"$BRANCH_NAME\"  # or git rebase origin/\"$BRANCH_NAME\"" >&2
            echo "  git push origin \"$BRANCH_NAME\"" >&2
            return 13
            ;;

        fail)
            echo "Push failed due to out-of-sync branch. Sync strategy is 'fail'." >&2
            echo "Please sync manually before pushing:" >&2
            echo "  git pull origin \"$BRANCH_NAME\"" >&2
            return 13
            ;;

        *)
            # This should never happen due to earlier validation, but included for defense in depth
            echo "Error: Unknown sync strategy: $strategy" >&2
            return 2
            ;;
    esac
}

# Attempt initial push
attempt_push
push_result=$?

# If push failed due to non-fast-forward, try to sync
if [ $push_result -eq 13 ]; then
    # Only attempt sync if not forcing (force push shouldn't trigger sync)
    if [ "$FORCE" = "true" ]; then
        echo "Error: Force push with lease failed. Remote branch may have changed." >&2
        echo "Fetch latest changes and try again: git fetch origin" >&2
        exit 13
    fi

    # Apply sync strategy
    sync_branch "$SYNC_STRATEGY"
    sync_result=$?

    if [ $sync_result -ne 0 ]; then
        exit $sync_result
    fi

    # Retry push after sync
    echo "Retrying push after sync..." >&2
    attempt_push
    retry_result=$?

    if [ $retry_result -ne 0 ]; then
        echo "Error: Push still failed after sync. Manual intervention required." >&2
        exit $retry_result
    fi

    echo "✓ Branch successfully synced and pushed" >&2
    exit 0
else
    # Initial push succeeded or failed with different error
    exit $push_result
fi
