#!/usr/bin/env bash
# Initialize worker pool for parallel execution
# Usage: init-worker-pool.sh {worker_count}
# Returns: Worker pool ID and temp directory

set -euo pipefail

WORKER_COUNT="${1:-5}"

# Validate worker count
if [[ ! "$WORKER_COUNT" =~ ^[0-9]+$ ]] || [[ $WORKER_COUNT -lt 1 ]] || [[ $WORKER_COUNT -gt 20 ]]; then
  echo "ERROR: Invalid worker count: $WORKER_COUNT (must be 1-20)" >&2
  exit 1
fi

# Create temp directory for worker coordination
POOL_ID="worker-pool-$(date +%s)-$$"
POOL_DIR="/tmp/$POOL_ID"
mkdir -p "$POOL_DIR"/{jobs,results,logs}

# Create worker metadata
cat > "$POOL_DIR/metadata.json" <<EOF
{
  "pool_id": "$POOL_ID",
  "worker_count": $WORKER_COUNT,
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "initialized",
  "jobs_dir": "$POOL_DIR/jobs",
  "results_dir": "$POOL_DIR/results",
  "logs_dir": "$POOL_DIR/logs"
}
EOF

# Return pool info
cat "$POOL_DIR/metadata.json"
