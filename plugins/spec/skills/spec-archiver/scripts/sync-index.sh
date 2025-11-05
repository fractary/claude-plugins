#!/usr/bin/env bash
#
# sync-index.sh - Sync archive index between local cache and cloud backup
#
# Usage: sync-index.sh <operation> <local_index_path> [cloud_index_path]
#
# Operations:
#   download: Sync from cloud to local (used by init/read)
#   upload: Sync from local to cloud (used after archival)
#   check: Check if cloud index exists
#
# Two-tier storage prevents index loss:
#   - Local cache: .fractary/plugins/spec/archive-index.json (fast, git-ignored)
#   - Cloud backup: archive/specs/.archive-index.json (durable, recoverable)

set -euo pipefail

OPERATION="${1:?Operation required: download|upload|check}"
LOCAL_INDEX="${2:?Local index path required}"
CLOUD_INDEX="${3:-}"

# Helper: Check if fractary-file plugin available
has_fractary_file() {
    # TODO: Check if fractary-file plugin is installed/available
    # For now, return false (not implemented)
    return 1
}

# Helper: Download file from cloud (via fractary-file)
download_from_cloud() {
    local cloud_path="$1"
    local local_path="$2"

    if has_fractary_file; then
        # TODO: Use fractary-file plugin to download
        echo "Would download $cloud_path to $local_path" >&2
        return 1
    else
        echo "fractary-file plugin not available for cloud sync" >&2
        return 1
    fi
}

# Helper: Upload file to cloud (via fractary-file)
upload_to_cloud() {
    local local_path="$1"
    local cloud_path="$2"

    if has_fractary_file; then
        # TODO: Use fractary-file plugin to upload
        echo "Would upload $local_path to $cloud_path" >&2
        return 1
    else
        echo "fractary-file plugin not available for cloud sync" >&2
        return 1
    fi
}

# Helper: Check if file exists in cloud
check_cloud_exists() {
    local cloud_path="$1"

    if has_fractary_file; then
        # TODO: Use fractary-file plugin to check existence
        return 1
    else
        return 1
    fi
}

case "$OPERATION" in
    download)
        # Sync from cloud to local (used on init, or when local missing)
        if [[ -z "$CLOUD_INDEX" ]]; then
            echo "Error: Cloud index path required for download" >&2
            exit 1
        fi

        echo "Syncing archive index from cloud..." >&2

        if download_from_cloud "$CLOUD_INDEX" "$LOCAL_INDEX"; then
            echo "✓ Archive index synced from cloud" >&2
            echo "✓ Local cache updated: $LOCAL_INDEX" >&2
            exit 0
        else
            # Cloud download failed or not available
            if [[ -f "$LOCAL_INDEX" ]]; then
                echo "⚠ Cloud sync unavailable, using existing local cache" >&2
                exit 0
            else
                echo "ℹ No cloud index found, creating new local index" >&2
                mkdir -p "$(dirname "$LOCAL_INDEX")"
                cat > "$LOCAL_INDEX" <<'EOF'
{
  "schema_version": "1.0",
  "last_updated": "",
  "last_synced": "",
  "archives": []
}
EOF
                exit 0
            fi
        fi
        ;;

    upload)
        # Sync from local to cloud (used after archival)
        if [[ -z "$CLOUD_INDEX" ]]; then
            echo "Error: Cloud index path required for upload" >&2
            exit 1
        fi

        if [[ ! -f "$LOCAL_INDEX" ]]; then
            echo "Error: Local index not found: $LOCAL_INDEX" >&2
            exit 1
        fi

        echo "Backing up archive index to cloud..." >&2

        # Update last_synced timestamp in local index
        CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        TEMP_INDEX=$(mktemp)
        jq --arg timestamp "$CURRENT_TIME" \
            '.last_synced = $timestamp' \
            "$LOCAL_INDEX" > "$TEMP_INDEX"
        mv "$TEMP_INDEX" "$LOCAL_INDEX"

        if upload_to_cloud "$LOCAL_INDEX" "$CLOUD_INDEX"; then
            echo "✓ Archive index backed up to cloud" >&2
            echo "✓ Cloud backup: $CLOUD_INDEX" >&2
            exit 0
        else
            echo "⚠ Cloud backup unavailable, index only in local cache" >&2
            echo "⚠ Local cache: $LOCAL_INDEX" >&2
            echo "⚠ Recommendation: Backup .fractary directory or implement cloud sync" >&2
            exit 0  # Non-critical, continue
        fi
        ;;

    check)
        # Check if cloud index exists
        if [[ -z "$CLOUD_INDEX" ]]; then
            echo "Error: Cloud index path required for check" >&2
            exit 1
        fi

        if check_cloud_exists "$CLOUD_INDEX"; then
            echo "✓ Cloud index exists: $CLOUD_INDEX" >&2
            exit 0
        else
            echo "ℹ No cloud index found (first archival will create it)" >&2
            exit 1
        fi
        ;;

    *)
        echo "Error: Unknown operation: $OPERATION" >&2
        echo "Usage: sync-index.sh <download|upload|check> <local_index> [cloud_index]" >&2
        exit 1
        ;;
esac
