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
ACTIVE_SESSION_FILE=""

if [[ -n "${XDG_RUNTIME_DIR:-}" && -f "$XDG_RUNTIME_DIR/fractary-logs/active-session" ]]; then
    # Preferred: XDG_RUNTIME_DIR (secure per-user temp)
    ACTIVE_SESSION_FILE="$XDG_RUNTIME_DIR/fractary-logs/active-session"
else
    # Try to find temp dir from session marker
    LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE" 2>/dev/null || echo "/logs")
    if [[ -f "${LOG_DIR}/.session-tmp-dir" ]]; then
        SESSION_TMP=$(cat "${LOG_DIR}/.session-tmp-dir")
        if [[ -f "$SESSION_TMP/active-session" ]]; then
            ACTIVE_SESSION_FILE="$SESSION_TMP/active-session"
        fi
    fi
fi

# Check for active session - FAIL HARD if not found in secure location
if [[ -z "$ACTIVE_SESSION_FILE" || ! -f "$ACTIVE_SESSION_FILE" ]]; then
    echo "Error: No active session found in secure temp directory." >&2
    echo "       Please start a new session with: /fractary-logs:capture <issue>" >&2
    echo "" >&2
    echo "       If you previously started a session, it may have been created" >&2
    echo "       with an older version using insecure temp storage." >&2
    echo "       Restart the session for security." >&2
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
    # Redact AWS Access Key IDs (starts with AKIA, ASIA, AIDA, AROA, AIPA, ANPA, ANVA)
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/(A[KSI][ID][AAP])[A-Z0-9]{16}/**AWS_KEY**/g')

    # Redact AWS Secret Access Keys (40 char base64)
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/['\''"]?[A-Za-z0-9/+=]{40}['\''"]?/**AWS_SECRET**/g')

    # Redact AWS Session Tokens (longer base64 strings with AWS context)
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/(aws_session_token|SessionToken)['\''"]?[:=]['\''"]?[A-Za-z0-9/+=]{100,}['\''"]?/\1=**AWS_SESSION**/gi')

    # Redact GitHub tokens (ghp_, gho_, ghs_, ghu_, ghr_)
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/gh[poshur]_[A-Za-z0-9]{36,}/**GITHUB_TOKEN**/g')

    # Redact Cloudflare API tokens (starts with various prefixes)
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/[A-Za-z0-9_-]{40}/**CF_TOKEN**/g')

    # Redact JWT tokens (3 base64 segments)
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*/**JWT**/g')

    # Redact generic API keys (with context: "api_key", "apiKey", "token" followed by value)
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/(api[_-]?key|apikey|token|secret)['\''"]?[:=]['\''"]?[A-Za-z0-9_-]{20,}['\''"]?/\1=**API_KEY**/gi')

    # Redact password values (with context)
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/(password|passwd|pwd)['\''"]?[:=]['\''"]?[^'\''" \n]{6,}['\''"]?/\1=**PASSWORD**/gi')

    # Redact credit card numbers (with basic Luhn check context)
    # Only match if surrounded by spaces/boundaries to avoid matching random 16-digit numbers
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/(^|[^0-9])[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}($|[^0-9])/\1**CARD**\2/g')

    # Redact private keys (BEGIN PRIVATE KEY markers)
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/-----BEGIN [A-Z ]+ PRIVATE KEY-----[^-]*-----END [A-Z ]+ PRIVATE KEY-----/**PRIVATE_KEY**/g')

    # Redact Bearer tokens
    REDACTED_MESSAGE=$(echo "$REDACTED_MESSAGE" | sed -E 's/Bearer [A-Za-z0-9_-]{20,}/Bearer **TOKEN**/gi')
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
