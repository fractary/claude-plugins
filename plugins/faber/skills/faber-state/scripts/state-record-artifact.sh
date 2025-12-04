#!/usr/bin/env bash
#
# state-record-artifact.sh - Record an artifact in workflow state
#
# Usage:
#   state-record-artifact.sh <artifact_type> <artifact_value>
#
# Arguments:
#   artifact_type   - Type of artifact (spec_path, branch_name, pr_url, pr_number, or custom key)
#   artifact_value  - Value to record
#
# Examples:
#   state-record-artifact.sh spec_path "specs/WORK-00123-feature.md"
#   state-record-artifact.sh branch_name "feat/123-add-feature"
#   state-record-artifact.sh pr_url "https://github.com/org/repo/pull/456"
#   state-record-artifact.sh pr_number "456"
#   state-record-artifact.sh custom_key "custom_value"
#
# Common artifact types:
#   - spec_path     : Path to the generated specification
#   - branch_name   : Git branch created for this work
#   - pr_url        : URL to the pull request
#   - pr_number     : Pull request number
#   - worktree_path : Path to git worktree (if using parallel development)

set -euo pipefail

# Arguments
ARTIFACT_TYPE="${1:?Artifact type required}"
ARTIFACT_VALUE="${2:?Artifact value required}"

# Resolve paths robustly (works regardless of execution context)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FABER_ROOT="$(cd "$SKILL_ROOT/../.." && pwd)"
CORE_SCRIPTS="$FABER_ROOT/skills/core/scripts"
STATE_FILE=".fractary/plugins/faber/state.json"

# Verify core scripts exist
if [ ! -d "$CORE_SCRIPTS" ]; then
    echo "Error: Core scripts not found at: $CORE_SCRIPTS" >&2
    exit 1
fi

# Check state file exists
if [ ! -f "$STATE_FILE" ]; then
    echo "Error: State file not found: $STATE_FILE" >&2
    exit 1
fi

# Read current state
CURRENT_STATE=$("$CORE_SCRIPTS/state-read.sh" "$STATE_FILE")

# Update artifacts section
UPDATED_STATE=$(echo "$CURRENT_STATE" | jq \
    --arg type "$ARTIFACT_TYPE" \
    --arg value "$ARTIFACT_VALUE" \
    '
    # Ensure artifacts object exists
    if .artifacts == null then
        .artifacts = {}
    else . end |
    # Set the artifact
    .artifacts[$type] = $value
    ')

# Write updated state
echo "$UPDATED_STATE" | "$CORE_SCRIPTS/state-write.sh" "$STATE_FILE"

echo "Artifact recorded: $ARTIFACT_TYPE = $ARTIFACT_VALUE"
exit 0
