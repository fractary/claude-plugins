#!/usr/bin/env bash
#
# generate-request-id.sh - Generate a unique feedback request ID
#
# Usage:
#   generate-request-id.sh
#
# Output: Feedback request ID in format: fr-YYYYMMDD-xxxxxx
#
# Exit Codes:
#   0 - Success
#   1 - Error generating ID

set -euo pipefail

# Generate date component
DATE_PART=$(date -u +"%Y%m%d")

# Generate random hex component (6 chars)
if command -v openssl &>/dev/null; then
    RANDOM_PART=$(openssl rand -hex 3)
elif [[ -f /dev/urandom ]]; then
    RANDOM_PART=$(head -c 3 /dev/urandom | xxd -p)
else
    # Fallback using $RANDOM
    RANDOM_PART=$(printf '%06x' $((RANDOM * RANDOM % 16777216)))
fi

# Output the request ID
echo "fr-${DATE_PART}-${RANDOM_PART}"
