#!/bin/bash
# Append a message to the active session log
set -euo pipefail

ROLE="${1:?Role required (user|claude|system)}"
MESSAGE="${2:?Message required}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Input validation: Role must be user, claude, or system
if ! [[ "$ROLE" =~ ^(user|claude|system)$ ]]; then
    echo "Error: Role must be 'user', 'claude', or 'system'" >&2
    exit 1
fi

# Find active session file in secure temp directory
if [[ -n "${XDG_RUNTIME_DIR:-}" && -f "$XDG_RUNTIME_DIR/fractary-logs/active-session" ]]; then
    ACTIVE_SESSION_FILE="$XDG_RUNTIME_DIR/fractary-logs/active-session"
else
    # Try to find temp dir from session marker
    LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE" 2>/dev/null || echo "/logs")
    if [[ -f "${LOG_DIR}/.session-tmp-dir" ]]; then
        SESSION_TMP=$(cat "${LOG_DIR}/.session-tmp-dir")
        ACTIVE_SESSION_FILE="$SESSION_TMP/active-session"
    else
        # Fallback to old location for backwards compatibility (but warn)
        ACTIVE_SESSION_FILE="/tmp/fractary-logs/active-session"
        if [[ -f "$ACTIVE_SESSION_FILE" ]]; then
            echo "Warning: Using insecure temp directory. Please restart session." >&2
        fi
    fi
fi

# Check for active session
if [[ ! -f "$ACTIVE_SESSION_FILE" ]]; then
    echo "Error: No active session. Start capture with /fractary-logs:capture <issue>" >&2
    exit 1
fi

# Load session context
SESSION_INFO=$(cat "$ACTIVE_SESSION_FILE")
LOG_FILE=$(echo "$SESSION_INFO" | jq -r '.log_file')

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: Session file not found: $LOG_FILE" >&2
    exit 1
fi

# Load configuration for redaction settings
REDACT_SENSITIVE="true"
if [[ -f "$CONFIG_FILE" ]]; then
    REDACT_SENSITIVE=$(jq -r '.session_logging.redact_sensitive // true' "$CONFIG_FILE")
fi

# Apply redaction if enabled
REDACTED_MESSAGE="$MESSAGE"
if [[ "$REDACT_SENSITIVE" == "true" ]]; then
    # Redact API keys (32+ char alphanumeric strings)
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/['\''"]?[A-Za-z0-9_-]{32,}['\''"]?/**REDACTED**/g')

    # Redact JWT tokens
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*/**JWT**/g')

    # Redact email addresses (configurable)
    # REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[A-Za-z]{2,}/**EMAIL**/g')

    # Redact password values
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/(password|passwd|pwd)[:\s=]+['\''"]?[^'\''" \n]+['\''"]?/\1: **REDACTED**/gi')

    # Redact credit card numbers
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/\b[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}\b/**CARD**/g')
fi

# Format role name
ROLE_NAME=$(echo "$ROLE" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')

# Get timestamp
TIMESTAMP=$(date -u +%H:%M:%S)

# Append to log file
cat >> "$LOG_FILE" <<EOF

### [$TIMESTAMP] $ROLE_NAME
$REDACTED_MESSAGE

EOF

echo "Message appended to session log"
