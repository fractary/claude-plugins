#!/bin/bash

# Process Comment Queue
# This script processes pending comments from the queue file
# Part of fractary-work plugin - enables async comment posting (Option 5)
#
# Usage:
#   process-comment-queue.sh           # Process all pending comments
#   process-comment-queue.sh --daemon  # Run as background daemon
#
# Queue format (JSON lines in pending_comments.queue):
#   {"issue_id": "123", "comment": "...", "handler": "github", "timestamp": "..."}

set -euo pipefail

# Configuration
CACHE_DIR="${HOME}/.fractary/work"
QUEUE_FILE="${CACHE_DIR}/pending_comments.queue"
LOCK_FILE="${CACHE_DIR}/comment-queue.lock"
LOG_FILE="${CACHE_DIR}/comment-queue.log"
FAILED_FILE="${CACHE_DIR}/failed_comments.queue"
MAX_RETRIES=3
RETRY_DELAY=5

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_PLUGIN_ROOT="${SCRIPT_DIR}/.."

mkdir -p "${CACHE_DIR}"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] [$level] $message" >> "${LOG_FILE}"
}

# Process a single comment
process_comment() {
    local issue_id="$1"
    local comment="$2"
    local handler="$3"
    local retry_count="${4:-0}"

    local handler_script="${WORK_PLUGIN_ROOT}/skills/handler-work-tracker-${handler}/scripts/create-comment.sh"

    if [ ! -f "$handler_script" ]; then
        log_message "ERROR" "Handler script not found: $handler_script"
        return 1
    fi

    # Post comment
    if "$handler_script" "$issue_id" "$comment" 2>/dev/null; then
        log_message "INFO" "Successfully posted comment to issue #$issue_id"
        return 0
    else
        local exit_code=$?
        log_message "WARN" "Failed to post comment to issue #$issue_id (exit code: $exit_code, retry: $retry_count)"

        if [ "$retry_count" -lt "$MAX_RETRIES" ]; then
            # Re-queue for retry (atomic write to prevent corruption)
            local retry_entry="{\"issue_id\": \"$issue_id\", \"comment\": $(echo "$comment" | jq -Rs .), \"handler\": \"$handler\", \"retry\": $((retry_count + 1)), \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
            local retry_temp="${QUEUE_FILE}.retry.$$"
            echo "$retry_entry" > "$retry_temp" && cat "$retry_temp" >> "$QUEUE_FILE" && rm -f "$retry_temp"
            log_message "INFO" "Re-queued comment for retry (attempt $((retry_count + 1)))"
        else
            # Move to failed queue (atomic write to prevent corruption)
            local failed_entry="{\"issue_id\": \"$issue_id\", \"comment\": $(echo "$comment" | jq -Rs .), \"handler\": \"$handler\", \"failed_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
            local failed_temp="${FAILED_FILE}.tmp.$$"
            echo "$failed_entry" > "$failed_temp" && cat "$failed_temp" >> "$FAILED_FILE" && rm -f "$failed_temp"
            log_message "ERROR" "Comment to issue #$issue_id failed after $MAX_RETRIES retries, moved to failed queue"
        fi
        return 1
    fi
}

# Process all pending comments
process_queue() {
    if [ ! -f "$QUEUE_FILE" ] || [ ! -s "$QUEUE_FILE" ]; then
        return 0
    fi

    # Acquire lock
    exec 200<>"${LOCK_FILE}"
    if ! flock -n 200; then
        log_message "INFO" "Queue processor already running, skipping"
        return 0
    fi

    log_message "INFO" "Processing comment queue"

    # Read and clear queue atomically
    local temp_queue="${QUEUE_FILE}.processing"
    mv "$QUEUE_FILE" "$temp_queue" 2>/dev/null || return 0

    local processed=0
    local failed=0

    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi

        # Parse JSON (requires jq)
        if ! command -v jq &> /dev/null; then
            log_message "ERROR" "jq not found, cannot process queue"
            mv "$temp_queue" "$QUEUE_FILE"
            return 1
        fi

        local issue_id=$(echo "$line" | jq -r '.issue_id // empty')
        local comment=$(echo "$line" | jq -r '.comment // empty')
        local handler=$(echo "$line" | jq -r '.handler // "github"')
        local retry=$(echo "$line" | jq -r '.retry // 0')

        if [ -z "$issue_id" ] || [ -z "$comment" ]; then
            log_message "WARN" "Skipping malformed queue entry"
            continue
        fi

        if process_comment "$issue_id" "$comment" "$handler" "$retry"; then
            ((processed++))
        else
            ((failed++))
        fi

        # Delay between retries
        if [ "$retry" -gt 0 ]; then
            sleep "$RETRY_DELAY"
        fi
    done < "$temp_queue"

    rm -f "$temp_queue"
    log_message "INFO" "Queue processing complete: $processed successful, $failed failed"

    # Release lock (auto-released on exit)
}

# Daemon mode - continuously process queue
run_daemon() {
    log_message "INFO" "Starting comment queue daemon"

    while true; do
        process_queue
        sleep 30  # Check queue every 30 seconds
    done
}

# Main
case "${1:-}" in
    --daemon)
        run_daemon
        ;;
    *)
        process_queue
        ;;
esac
