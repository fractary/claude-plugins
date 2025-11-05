#!/usr/bin/env bash
#
# upload-to-cloud.sh - Upload spec to cloud storage
#
# Usage: upload-to-cloud.sh <spec_path> <cloud_path>
#
# Outputs JSON with upload results
#
# CRITICAL: This script requires fractary-file plugin integration.
# Cloud upload is NOT implemented yet. This is a safe placeholder that:
# 1. Creates a local backup in .fractary/plugins/spec/backups/
# 2. Fails with clear error if SPEC_ALLOW_MOCK_UPLOAD not set
# 3. Prevents data loss by blocking archival without real upload

set -euo pipefail

SPEC_PATH="${1:?Spec path required}"
CLOUD_PATH="${2:?Cloud path required}"

# Validate spec exists
if [[ ! -f "$SPEC_PATH" ]]; then
    echo '{"error": "Spec file not found"}' >&2
    exit 1
fi

# Get file info (portable across macOS and Linux)
FILENAME=$(basename "$SPEC_PATH")
if command -v stat >/dev/null 2>&1; then
    # Try GNU stat first, fall back to BSD stat (macOS)
    SIZE=$(stat -c %s "$SPEC_PATH" 2>/dev/null || stat -f %z "$SPEC_PATH" 2>/dev/null || wc -c < "$SPEC_PATH" | tr -d ' ')
else
    SIZE=$(wc -c < "$SPEC_PATH" | tr -d ' ')
fi
CHECKSUM=$(sha256sum "$SPEC_PATH" 2>/dev/null || shasum -a 256 "$SPEC_PATH" | awk '{print $1}')

# CRITICAL SAFETY CHECK: Prevent data loss
# Cloud upload is NOT yet implemented. Block archival unless explicitly allowed.
if [[ "${SPEC_ALLOW_MOCK_UPLOAD:-false}" != "true" ]]; then
    cat >&2 <<'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                        CRITICAL: CLOUD UPLOAD NOT IMPLEMENTED             ║
╚═══════════════════════════════════════════════════════════════════════════╝

ERROR: Cloud upload functionality is not yet implemented.

This is a PLACEHOLDER implementation that prevents data loss by blocking
archival operations until real cloud storage integration is complete.

WHY THIS MATTERS:
  - Archival process deletes local spec files after "upload"
  - Without real upload, specs would be permanently lost
  - This safety check prevents that data loss

WHAT YOU NEED TO DO:

Option 1 - RECOMMENDED: Implement fractary-file integration
  See: plugins/file/ for cloud storage integration
  TODO: Implement actual upload using fractary-file plugin

Option 2 - Testing/Development Only (DATA LOSS RISK):
  Set SPEC_ALLOW_MOCK_UPLOAD=true to bypass this check
  Example: SPEC_ALLOW_MOCK_UPLOAD=true /fractary-spec:archive 123

  WARNING: Specs will NOT be uploaded to cloud!
  WARNING: Specs will be deleted from local storage!
  WARNING: You will lose your specifications!

Option 3 - Use local backup mode:
  Specs will be copied to .fractary/plugins/spec/backups/ instead
  No cloud upload, but no data loss
  Set SPEC_USE_LOCAL_BACKUP=true

CURRENT STATUS: Blocking archival to prevent data loss
EOF
    exit 1
fi

# If we get here, user explicitly allowed mock upload (TESTING ONLY)
echo "⚠️  WARNING: Mock upload mode - specs will NOT be uploaded to cloud!" >&2
echo "⚠️  WARNING: This is for TESTING ONLY - data loss will occur!" >&2

# Create local backup as safety net
BACKUP_DIR=".fractary/plugins/spec/backups"
mkdir -p "$BACKUP_DIR"
BACKUP_PATH="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)-$FILENAME"
cp "$SPEC_PATH" "$BACKUP_PATH"
echo "ℹ️  Safety backup created: $BACKUP_PATH" >&2

# Generate mock cloud URL (NOT A REAL UPLOAD)
CLOUD_URL="https://storage.example.com/${CLOUD_PATH}"

# Output result (marked as mock)
cat <<EOF
{
  "filename": "$FILENAME",
  "local_path": "$SPEC_PATH",
  "cloud_path": "$CLOUD_PATH",
  "cloud_url": "$CLOUD_URL",
  "size_bytes": $SIZE,
  "checksum": "sha256:$CHECKSUM",
  "uploaded_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mock_upload": true,
  "backup_path": "$BACKUP_PATH"
}
EOF
