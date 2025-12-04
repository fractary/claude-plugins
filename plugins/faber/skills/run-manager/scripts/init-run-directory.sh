#!/usr/bin/env bash
#
# init-run-directory.sh - Initialize a FABER run directory
#
# Usage:
#   init-run-directory.sh --run-id <run_id> --work-id <work_id> [options]
#
# Creates the run directory structure:
#   .fractary/plugins/faber/runs/{org}/{project}/{uuid}/
#   ├── state.json         # Initial workflow state
#   ├── metadata.json      # Run metadata (params, timing, relations)
#   └── events/
#       └── .next-id       # Event sequence counter (starts at 1)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
RUN_ID=""
WORK_ID=""
TARGET=""
WORKFLOW_ID="default"
AUTONOMY="guarded"
SOURCE_TYPE="github"
PHASES=""
PARENT_RUN_ID=""
RERUN_OF=""
BASE_PATH=".fractary/plugins/faber/runs"

print_usage() {
    cat <<EOF
Usage: init-run-directory.sh --run-id <run_id> --work-id <work_id> [options]

Creates the directory structure and initial files for a FABER workflow run.

Required:
  --run-id <id>         Full run ID (org/project/uuid)
  --work-id <id>        Work item ID (issue number)

Optional:
  --target <name>       Target artifact name
  --workflow <id>       Workflow ID (default: default)
  --autonomy <level>    Autonomy level (default: guarded)
  --source-type <type>  Source type (default: github)
  --phases <phases>     Comma-separated phases to execute
  --parent-run <id>     Parent run ID (for resume)
  --rerun-of <id>       Original run ID (for rerun)
  --base-path <path>    Base path for runs (default: .fractary/plugins/faber/runs)

Output:
  JSON object with initialization result
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --run-id)
            RUN_ID="$2"
            shift 2
            ;;
        --work-id)
            WORK_ID="$2"
            shift 2
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        --workflow)
            WORKFLOW_ID="$2"
            shift 2
            ;;
        --autonomy)
            AUTONOMY="$2"
            shift 2
            ;;
        --source-type)
            SOURCE_TYPE="$2"
            shift 2
            ;;
        --phases)
            PHASES="$2"
            shift 2
            ;;
        --parent-run)
            PARENT_RUN_ID="$2"
            shift 2
            ;;
        --rerun-of)
            RERUN_OF="$2"
            shift 2
            ;;
        --base-path)
            BASE_PATH="$2"
            shift 2
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$RUN_ID" ]]; then
    echo "Error: --run-id is required" >&2
    exit 1
fi

if [[ -z "$WORK_ID" ]]; then
    echo "Error: --work-id is required" >&2
    exit 1
fi

# Validate run_id format: org/project/uuid
if [[ ! "$RUN_ID" =~ ^[a-z0-9_-]+/[a-z0-9_-]+/[a-f0-9-]{36}$ ]]; then
    echo "Error: Invalid run_id format: $RUN_ID" >&2
    echo "Expected: {org}/{project}/{uuid}" >&2
    exit 1
fi

# Path traversal protection
if [[ "$RUN_ID" == *".."* ]] || [[ "$RUN_ID" == /* ]]; then
    echo "Error: Path traversal attempt detected in run_id" >&2
    exit 1
fi

# Create run directory path
RUN_DIR="${BASE_PATH}/${RUN_ID}"

# Check if directory already exists
if [[ -d "$RUN_DIR" ]]; then
    echo "Error: Run directory already exists: $RUN_DIR" >&2
    exit 1
fi

# Cleanup function for error handling
cleanup_on_error() {
    if [[ -d "$RUN_DIR" ]]; then
        rm -rf "$RUN_DIR" 2>/dev/null || true
    fi
}

# Set trap for cleanup on error
trap cleanup_on_error ERR

# Create directory structure
mkdir -p "${RUN_DIR}/events"

# Get current timestamp with milliseconds
if date +%N &>/dev/null; then
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
else
    if command -v perl &>/dev/null; then
        TIMESTAMP=$(perl -MTime::HiRes=time -MPOSIX=strftime -e 'my $t = time; my $ms = sprintf("%03d", ($t - int($t)) * 1000); print strftime("%Y-%m-%dT%H:%M:%S", gmtime(int($t))) . "." . $ms . "Z"')
    else
        TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
    fi
fi

# Build phases array for JSON
if [[ -n "$PHASES" ]]; then
    PHASES_JSON=$(echo "$PHASES" | jq -R 'split(",") | map(select(length > 0))')
else
    PHASES_JSON='["frame", "architect", "build", "evaluate", "release"]'
fi

# Create metadata.json
cat > "${RUN_DIR}/metadata.json" <<EOF
{
  "run_id": "$RUN_ID",
  "work_id": "$WORK_ID",
  "target": $(jq -n --arg t "$TARGET" 'if $t == "" then null else $t end'),
  "workflow_id": "$WORKFLOW_ID",
  "autonomy": "$AUTONOMY",
  "source_type": "$SOURCE_TYPE",
  "phases": $PHASES_JSON,
  "created_at": "$TIMESTAMP",
  "created_by": "${USER:-unknown}",
  "relationships": {
    "parent_run_id": $(jq -n --arg p "$PARENT_RUN_ID" 'if $p == "" then null else $p end'),
    "rerun_of": $(jq -n --arg r "$RERUN_OF" 'if $r == "" then null else $r end'),
    "child_runs": []
  },
  "environment": {
    "hostname": "$(hostname)",
    "git_branch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')",
    "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "working_directory": "$PWD"
  }
}
EOF

# Create state.json
cat > "${RUN_DIR}/state.json" <<EOF
{
  "run_id": "$RUN_ID",
  "work_id": "$WORK_ID",
  "workflow_version": "2.1",
  "status": "pending",
  "current_phase": null,
  "last_event_id": 0,
  "started_at": null,
  "updated_at": "$TIMESTAMP",
  "completed_at": null,
  "phases": {
    "frame": {"status": "pending", "steps": []},
    "architect": {"status": "pending", "steps": []},
    "build": {"status": "pending", "steps": []},
    "evaluate": {"status": "pending", "steps": [], "retry_count": 0},
    "release": {"status": "pending", "steps": []}
  },
  "artifacts": {},
  "errors": []
}
EOF

# Initialize event sequence counter
echo "1" > "${RUN_DIR}/events/.next-id"

# Output result
cat <<EOF
{
  "status": "success",
  "operation": "init-run-directory",
  "run_id": "$RUN_ID",
  "run_dir": "$RUN_DIR",
  "work_id": "$WORK_ID",
  "created_at": "$TIMESTAMP",
  "files_created": [
    "${RUN_DIR}/metadata.json",
    "${RUN_DIR}/state.json",
    "${RUN_DIR}/events/.next-id"
  ]
}
EOF

exit 0
