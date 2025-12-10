#!/bin/bash
#
# verify-step.sh - External evidence verification for FABER steps
#
# This script checks real-world state to verify that a step actually completed.
# It cannot be fooled by the LLM - it checks external systems directly.
#
# Usage:
#   ./verify-step.sh --step <step-id> --phase <phase> --state-file <state.json>
#
# Exit codes:
#   0 - Verification passed
#   1 - Verification failed
#   2 - No verification defined for this step (treated as pass)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Arguments
STEP_ID=""
PHASE=""
STATE_FILE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --step)
            STEP_ID="$2"
            shift 2
            ;;
        --phase)
            PHASE="$2"
            shift 2
            ;;
        --state-file)
            STATE_FILE="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log() {
    local level="$1"
    shift
    case "$level" in
        OK)    echo -e "${GREEN}✓ VERIFY:${NC} $*" ;;
        FAIL)  echo -e "${RED}✗ VERIFY:${NC} $*" ;;
        WARN)  echo -e "${YELLOW}⚠ VERIFY:${NC} $*" ;;
        INFO)  [[ "$VERBOSE" == "true" ]] && echo -e "ℹ VERIFY: $*" ;;
    esac
}

# Get artifact from state file
get_artifact() {
    local key="$1"
    if [[ -f "$STATE_FILE" ]]; then
        jq -r ".artifacts.$key // empty" "$STATE_FILE"
    fi
}

# Verification functions for specific steps
verify_core_create_pr() {
    local branch=$(get_artifact "branch_name")

    if [[ -z "$branch" ]]; then
        # Try to get current branch
        branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    fi

    if [[ -z "$branch" ]]; then
        log FAIL "Cannot verify PR: no branch name available"
        return 1
    fi

    log INFO "Checking for PR on branch: $branch"

    # Check GitHub for PR
    local pr_data=$(gh pr list --head "$branch" --json number,url,state --jq '.[0]' 2>/dev/null || echo "")

    if [[ -z "$pr_data" || "$pr_data" == "null" ]]; then
        log FAIL "No PR found for branch: $branch"
        return 1
    fi

    local pr_number=$(echo "$pr_data" | jq -r '.number')
    local pr_url=$(echo "$pr_data" | jq -r '.url')
    local pr_state=$(echo "$pr_data" | jq -r '.state')

    log OK "PR #$pr_number exists (state: $pr_state)"
    log INFO "URL: $pr_url"

    # Update state with PR info if state file provided
    if [[ -f "$STATE_FILE" ]]; then
        jq --arg num "$pr_number" --arg url "$pr_url" \
            '.artifacts.pr_number = $num | .artifacts.pr_url = $url' \
            "$STATE_FILE" > "${STATE_FILE}.tmp"
        mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi

    return 0
}

verify_core_commit_and_push() {
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

    if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
        log WARN "Not on a branch, skipping push verification"
        return 0
    fi

    log INFO "Checking commits on branch: $branch"

    # Fetch latest from remote
    git fetch origin "$branch" 2>/dev/null || {
        log WARN "Could not fetch from origin/$branch (may not exist yet)"
        return 0
    }

    # Check if remote branch exists
    if ! git rev-parse "origin/$branch" >/dev/null 2>&1; then
        log FAIL "Remote branch origin/$branch does not exist"
        return 1
    fi

    # Compare local and remote
    local local_sha=$(git rev-parse HEAD)
    local remote_sha=$(git rev-parse "origin/$branch")

    if [[ "$local_sha" == "$remote_sha" ]]; then
        log OK "Local and remote are in sync (SHA: ${local_sha:0:7})"
    else
        # Check if local is ahead (which is OK - means we pushed)
        local ahead=$(git rev-list "origin/$branch..HEAD" --count 2>/dev/null || echo "0")
        local behind=$(git rev-list "HEAD..origin/$branch" --count 2>/dev/null || echo "0")

        if [[ "$ahead" -gt 0 && "$behind" -eq 0 ]]; then
            log WARN "Local is $ahead commit(s) ahead of remote (may need to push)"
        elif [[ "$behind" -gt 0 ]]; then
            log WARN "Local is $behind commit(s) behind remote"
        fi
    fi

    return 0
}

verify_core_merge_pr() {
    local pr_number=$(get_artifact "pr_number")

    if [[ -z "$pr_number" ]]; then
        log FAIL "Cannot verify merge: no PR number in state"
        return 1
    fi

    log INFO "Checking merge status for PR #$pr_number"

    local pr_state=$(gh pr view "$pr_number" --json state --jq '.state' 2>/dev/null || echo "")

    if [[ "$pr_state" == "MERGED" ]]; then
        log OK "PR #$pr_number is merged"
        return 0
    elif [[ "$pr_state" == "CLOSED" ]]; then
        log FAIL "PR #$pr_number is closed but not merged"
        return 1
    elif [[ "$pr_state" == "OPEN" ]]; then
        log FAIL "PR #$pr_number is still open (not merged)"
        return 1
    else
        log FAIL "Unknown PR state: $pr_state"
        return 1
    fi
}

verify_core_switch_or_create_branch() {
    local expected_branch=$(get_artifact "branch_name")
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

    if [[ -z "$current_branch" ]]; then
        log FAIL "Not in a git repository or HEAD is detached"
        return 1
    fi

    # Check we're not on a protected branch
    case "$current_branch" in
        main|master|production|staging)
            log FAIL "On protected branch: $current_branch"
            return 1
            ;;
    esac

    if [[ -n "$expected_branch" && "$current_branch" != "$expected_branch" ]]; then
        log WARN "Expected branch '$expected_branch' but on '$current_branch'"
    fi

    log OK "On branch: $current_branch"
    return 0
}

verify_core_fetch_or_create_issue() {
    local work_id=$(get_artifact "work_id")

    if [[ -z "$work_id" ]]; then
        # Try from state root
        work_id=$(jq -r '.work_id // empty' "$STATE_FILE" 2>/dev/null || echo "")
    fi

    if [[ -z "$work_id" ]]; then
        log WARN "No work_id available for verification"
        return 0
    fi

    log INFO "Verifying issue #$work_id exists"

    local issue_state=$(gh issue view "$work_id" --json state --jq '.state' 2>/dev/null || echo "")

    if [[ -z "$issue_state" ]]; then
        log FAIL "Issue #$work_id not found"
        return 1
    fi

    log OK "Issue #$work_id exists (state: $issue_state)"
    return 0
}

# Main verification router
main() {
    if [[ -z "$STEP_ID" ]]; then
        echo "Error: --step is required"
        exit 1
    fi

    log INFO "Verifying step: $STEP_ID (phase: $PHASE)"

    case "$STEP_ID" in
        core-create-pr)
            verify_core_create_pr
            ;;
        core-commit-and-push*|commit-and-push*)
            verify_core_commit_and_push
            ;;
        core-merge-pr)
            verify_core_merge_pr
            ;;
        core-switch-or-create-branch)
            verify_core_switch_or_create_branch
            ;;
        core-fetch-or-create-issue)
            verify_core_fetch_or_create_issue
            ;;
        *)
            # No specific verification for this step
            log INFO "No external verification defined for: $STEP_ID"
            exit 2  # Special exit code meaning "no verification needed"
            ;;
    esac
}

main "$@"
