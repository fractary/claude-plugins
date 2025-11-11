#!/bin/bash
# Repo Manager: GitHub Pull Branch
# Pulls branch from remote repository with intelligent conflict resolution
#
# Requirements:
#   - Git 2.18+ (for merge-tree command support)
#   - Bash 4.0+ (for regex support)
#
# Security:
#   - Branch and remote names are validated against injection patterns
#   - Only known merge strategies are accepted
#
# Behavior Notes:
#   - Auto-switches to target branch if not currently on it
#   - Preserves uncommitted changes during pull operations
#   - Uses git merge-tree for conflict detection (Git 2.18+ feature)

set -euo pipefail

# Check arguments
# Usage: pull-branch.sh [branch_name] [remote] [strategy]
if [ $# -lt 1 ] || [ -z "$1" ]; then
    # No arguments provided - use current branch and defaults
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -z "$BRANCH_NAME" ] || [ "$BRANCH_NAME" = "HEAD" ]; then
        echo "Error: Not on a branch and no branch name provided" >&2
        exit 2
    fi
    REMOTE="origin"
    STRATEGY="auto-merge-prefer-remote"
else
    # Arguments provided - parse them
    BRANCH_NAME="$1"
    REMOTE="${2:-origin}"
    STRATEGY="${3:-auto-merge-prefer-remote}"
fi

# Validate branch name - prevent injection and invalid characters
if [[ ! "$BRANCH_NAME" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
    echo "Error: Invalid branch name: $BRANCH_NAME" >&2
    echo "Branch names can only contain: letters, numbers, /, _, ., -" >&2
    exit 2
fi

# Validate remote name - prevent injection
if [[ ! "$REMOTE" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    echo "Error: Invalid remote name: $REMOTE" >&2
    echo "Remote names can only contain: letters, numbers, _, ., -" >&2
    exit 2
fi

# Validate strategy - only allow known values
case "$STRATEGY" in
    auto-merge-prefer-remote|auto-merge-prefer-local|rebase|manual|fail)
        # Valid strategy
        ;;
    *)
        echo "Error: Invalid pull strategy: $STRATEGY" >&2
        echo "Valid options: auto-merge-prefer-remote, auto-merge-prefer-local, rebase, manual, fail" >&2
        exit 2
        ;;
esac

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 3
fi

# Check if branch exists locally
if ! git rev-parse --verify "$BRANCH_NAME" > /dev/null 2>&1; then
    echo "Error: Branch '$BRANCH_NAME' does not exist locally" >&2
    exit 1
fi

# Check if remote exists
if ! git remote | grep -q "^${REMOTE}$"; then
    echo "Error: Remote '$REMOTE' does not exist" >&2
    echo "Available remotes:" >&2
    git remote -v >&2
    exit 1
fi

# Ensure we're on the specified branch
# NOTE: This auto-switches branches. Users should be aware of this behavior.
# This is intentional to ensure pull happens on the correct branch.
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
    echo "⚠️  Switching to branch '$BRANCH_NAME'..." >&2
    if ! git checkout "$BRANCH_NAME" 2>&1; then
        echo "Error: Failed to checkout branch '$BRANCH_NAME'" >&2
        exit 1
    fi
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "Warning: You have uncommitted changes. They will be preserved during pull." >&2
fi

# Fetch latest changes from remote
echo "Fetching latest changes from '$REMOTE'..." >&2
if ! git fetch "$REMOTE" 2>&1; then
    echo "Error: Failed to fetch from remote '$REMOTE'" >&2
    exit 12
fi

# Check if remote branch exists
if ! git rev-parse --verify "${REMOTE}/${BRANCH_NAME}" > /dev/null 2>&1; then
    echo "Error: Remote branch '${REMOTE}/${BRANCH_NAME}' does not exist" >&2
    echo "Tip: Push this branch first with: /repo:push --set-upstream" >&2
    exit 1
fi

# Get commit counts
LOCAL_COMMIT=$(git rev-parse "$BRANCH_NAME" 2>/dev/null)
REMOTE_COMMIT=$(git rev-parse "${REMOTE}/${BRANCH_NAME}" 2>/dev/null)

# Check if we're already up to date
if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
    echo "Already up to date. Nothing to pull." >&2
    echo "Branch '$BRANCH_NAME' is in sync with '${REMOTE}/${BRANCH_NAME}'" >&2
    exit 0
fi

# Count commits to pull
COMMITS_TO_PULL=$(git rev-list --count "${BRANCH_NAME}..${REMOTE}/${BRANCH_NAME}" 2>/dev/null || echo "0")
echo "Found ${COMMITS_TO_PULL} commit(s) to pull from '${REMOTE}/${BRANCH_NAME}'" >&2

# Function to check for potential conflicts
# Note: Requires Git 2.18+ for merge-tree command
# The conflict detection may not catch all conflict types across Git versions
check_conflicts() {
    # Try a test merge to see if there would be conflicts
    # This doesn't modify the working tree
    # Note: Output format may vary across Git versions
    local merge_base
    merge_base=$(git merge-base "$BRANCH_NAME" "${REMOTE}/${BRANCH_NAME}" 2>/dev/null || echo "")

    if [ -z "$merge_base" ]; then
        # No common ancestor, likely new branch
        return 1
    fi

    # Check for conflicts in merge-tree output
    # Look for multiple patterns to improve reliability
    local merge_output
    merge_output=$(git merge-tree "$merge_base" "$BRANCH_NAME" "${REMOTE}/${BRANCH_NAME}" 2>/dev/null || echo "")

    if echo "$merge_output" | grep -qE "^changed in both|^both modified|^both added"; then
        return 0  # Conflicts detected
    else
        return 1  # No conflicts
    fi
}

# Function to apply strategy
apply_strategy() {
    local strategy="$1"

    case "$strategy" in
        auto-merge-prefer-remote)
            echo "Applying strategy: auto-merge-prefer-remote (remote changes win)" >&2
            if ! git pull "$REMOTE" "$BRANCH_NAME" -X theirs --no-edit 2>&1; then
                echo "Error: Pull with prefer-remote strategy failed" >&2
                echo "This usually means there are complex conflicts that need manual resolution" >&2
                return 13
            fi
            echo "✓ Pull successful (remote changes preferred in conflicts)" >&2
            return 0
            ;;

        auto-merge-prefer-local)
            echo "Applying strategy: auto-merge-prefer-local (local changes win)" >&2
            if ! git pull "$REMOTE" "$BRANCH_NAME" -X ours --no-edit 2>&1; then
                echo "Error: Pull with prefer-local strategy failed" >&2
                echo "This usually means there are complex conflicts that need manual resolution" >&2
                return 13
            fi
            echo "✓ Pull successful (local changes preferred in conflicts)" >&2
            return 0
            ;;

        rebase)
            echo "Applying strategy: rebase (replaying local commits)" >&2
            if ! git pull "$REMOTE" "$BRANCH_NAME" --rebase 2>&1; then
                echo "Error: Rebase failed" >&2
                echo "Resolve conflicts and run: git rebase --continue" >&2
                echo "Or abort with: git rebase --abort" >&2
                return 13
            fi
            echo "✓ Rebase successful" >&2
            return 0
            ;;

        manual)
            echo "Applying strategy: manual (you'll resolve conflicts)" >&2
            if ! git pull "$REMOTE" "$BRANCH_NAME" --no-edit 2>&1; then
                # Check if it's a conflict or other error
                if git ls-files -u | grep -q .; then
                    echo "✓ Pull completed with conflicts requiring manual resolution" >&2
                    echo "" >&2
                    echo "Files with conflicts:" >&2
                    git diff --name-only --diff-filter=U >&2
                    echo "" >&2
                    echo "To resolve:" >&2
                    echo "  1. Edit conflicted files" >&2
                    echo "  2. git add <resolved-files>" >&2
                    echo "  3. git commit" >&2
                    return 13
                else
                    echo "Error: Pull failed for non-conflict reason" >&2
                    return 12
                fi
            fi
            echo "✓ Pull successful (no conflicts)" >&2
            return 0
            ;;

        fail)
            echo "Applying strategy: fail (abort on conflicts)" >&2
            # Check for potential conflicts first
            if check_conflicts; then
                echo "Error: Merge conflicts detected. Strategy is 'fail'." >&2
                echo "Conflicted files:" >&2
                git diff --name-only "$BRANCH_NAME" "${REMOTE}/${BRANCH_NAME}" >&2
                echo "" >&2
                echo "Use a different strategy:" >&2
                echo "  /repo:pull --strategy auto-merge-prefer-remote" >&2
                echo "  /repo:pull --strategy manual" >&2
                return 13
            fi

            # No conflicts, safe to pull
            if ! git pull "$REMOTE" "$BRANCH_NAME" --no-edit 2>&1; then
                echo "Error: Pull failed unexpectedly" >&2
                return 12
            fi
            echo "✓ Pull successful (no conflicts detected)" >&2
            return 0
            ;;

        *)
            # This should never happen due to earlier validation
            echo "Error: Unknown strategy: $strategy" >&2
            return 2
            ;;
    esac
}

# Apply the selected strategy
apply_strategy "$STRATEGY"
pull_result=$?

if [ $pull_result -eq 0 ]; then
    # Success
    NEW_LOCAL_COMMIT=$(git rev-parse "$BRANCH_NAME" 2>/dev/null)
    echo "✓ Branch '$BRANCH_NAME' successfully updated from '${REMOTE}/${BRANCH_NAME}'" >&2
    echo "Previous: ${LOCAL_COMMIT:0:8}, Current: ${NEW_LOCAL_COMMIT:0:8}" >&2
    exit 0
else
    # Failed
    exit $pull_result
fi
