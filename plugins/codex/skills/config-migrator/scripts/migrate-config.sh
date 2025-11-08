#!/usr/bin/env bash
# migrate-config.sh - Migrate codex configuration from v2.0 to v3.0 format
#
# Usage: migrate-config.sh <config_path> <dry_run> <force> <backup_path>
#
# Arguments:
#   config_path  - Path to config file (e.g., .fractary/plugins/codex/config.json)
#   dry_run      - "true" to preview only, "false" to apply
#   force        - "true" to migrate even if already v3.0
#   backup_path  - Directory for backups (e.g., .backup)
#
# Returns: JSON with migration result

set -euo pipefail

config_path="${1:-.fractary/plugins/codex/config.json}"
dry_run="${2:-false}"
force="${3:-false}"
backup_dir="${4:-.backup}"

# Ensure config exists
if [[ ! -f "$config_path" ]]; then
  echo '{"success": false, "error": "Configuration file not found", "path": "'"$config_path"'"}'
  exit 1
fi

# Read current config
if ! config=$(cat "$config_path" 2>/dev/null); then
  echo '{"success": false, "error": "Failed to read configuration file"}'
  exit 1
fi

# Validate JSON
if ! echo "$config" | jq empty 2>/dev/null; then
  echo '{"success": false, "error": "Invalid JSON in configuration file"}'
  exit 1
fi

# Check if already v3.0 (has sources array)
has_sources=$(echo "$config" | jq 'has("sources")' 2>/dev/null || echo "false")

if [[ "$has_sources" == "true" ]] && [[ "$force" != "true" ]]; then
  echo '{
    "success": true,
    "action": "already_migrated",
    "message": "Configuration is already v3.0 format (has sources array)",
    "hint": "Use --force to re-migrate"
  }'
  exit 0
fi

# Extract v2.0 fields
organization=$(echo "$config" | jq -r '.organization // "unknown"')
codex_repo=$(echo "$config" | jq -r '.codex_repo // "codex.fractary.com"')
version=$(echo "$config" | jq -r '.version // "1.0"')
sync_patterns=$(echo "$config" | jq -c '.sync_patterns // null')

# Build v3.0 configuration
new_config=$(jq -n \
  --arg org "$organization" \
  --arg repo "$codex_repo" \
  --arg ver "$version" \
  --argjson patterns "$sync_patterns" \
  '{
    "version": $ver,
    "organization": $org,
    "codex_repo": $repo,
    "sources": [
      {
        "name": "fractary-codex",
        "type": "codex",
        "handler": "github",
        "permissions": {
          "enabled": true,
          "default_policy": "allow"
        },
        "cache": {
          "enabled": true,
          "ttl_days": 7,
          "max_size_mb": 1000,
          "compression": false
        }
      }
    ],
    "performance": {
      "parallel_fetches": 10,
      "cache_strategy": "disk",
      "compression_level": 6
    }
  }' | \
  if [[ "$sync_patterns" != "null" ]]; then
    jq --argjson patterns "$sync_patterns" \
      '. + {"_migration_note": "Old sync_patterns preserved here for reference. Use frontmatter permissions instead.", "_old_sync_patterns": $patterns}'
  else
    cat
  fi
)

# Validate new config
if ! echo "$new_config" | jq empty 2>/dev/null; then
  echo '{"success": false, "error": "Generated invalid JSON during conversion"}'
  exit 1
fi

# Calculate changes
added=()
preserved=()
deprecated=()

added+=("sources array with 1 source (fractary-codex)")
added+=("performance configuration")
if [[ "$sync_patterns" != "null" ]]; then
  added+=("cache configuration with TTL")
fi

preserved+=("organization: $organization")
preserved+=("codex_repo: $codex_repo")
preserved+=("version: $version")

if [[ "$sync_patterns" != "null" ]]; then
  deprecated+=("sync_patterns (preserved as _old_sync_patterns for reference)")
fi

# Dry-run mode: show preview
if [[ "$dry_run" == "true" ]]; then
  added_json=$(printf '%s\n' "${added[@]}" | jq -R . | jq -s .)
  preserved_json=$(printf '%s\n' "${preserved[@]}" | jq -R . | jq -s .)
  deprecated_json=$(printf '%s\n' "${deprecated[@]}" | jq -R . | jq -s .)

  echo '{
    "success": true,
    "action": "preview",
    "old_format": "v2.0 (SPEC-0012)",
    "new_format": "v3.0 (SPEC-0030)",
    "changes": {
      "added": '"$added_json"',
      "preserved": '"$preserved_json"',
      "deprecated": '"$deprecated_json"'
    },
    "preview": '"$(echo "$new_config" | jq -c .)"'
  }'
  exit 0
fi

# Create backup
timestamp=$(date +%Y%m%d_%H%M%S)
mkdir -p "$backup_dir"
backup_path="$backup_dir/$(basename "$config_path").backup.$timestamp"

if ! cp "$config_path" "$backup_path" 2>/dev/null; then
  echo '{"success": false, "error": "Failed to create backup"}'
  exit 1
fi

# Write new configuration
if ! echo "$new_config" | jq . > "$config_path" 2>/dev/null; then
  # Restore backup on failure
  cp "$backup_path" "$config_path" 2>/dev/null || true
  echo '{"success": false, "error": "Failed to write new configuration, backup restored"}'
  exit 1
fi

# Verify new config is readable
if ! cat "$config_path" | jq empty 2>/dev/null; then
  # Restore backup on failure
  cp "$backup_path" "$config_path" 2>/dev/null || true
  echo '{"success": false, "error": "New configuration is invalid, backup restored"}'
  exit 1
fi

# Success!
added_json=$(printf '%s\n' "${added[@]}" | jq -R . | jq -s .)
preserved_json=$(printf '%s\n' "${preserved[@]}" | jq -R . | jq -s .)
deprecated_json=$(printf '%s\n' "${deprecated[@]}" | jq -R . | jq -s .)

echo '{
  "success": true,
  "action": "migrated",
  "backup_path": "'"$backup_path"'",
  "config_path": "'"$config_path"'",
  "old_format": "v2.0 (SPEC-0012)",
  "new_format": "v3.0 (SPEC-0030)",
  "changes": {
    "added": '"$added_json"',
    "preserved": '"$preserved_json"',
    "deprecated": '"$deprecated_json"'
  },
  "rollback_command": "cp '"$backup_path"' '"$config_path"'",
  "next_steps": [
    "Test retrieval: /codex:fetch @codex/PROJECT/PATH",
    "View cache: /codex:cache-list",
    "Read guide: plugins/codex/docs/MIGRATION-PHASE4.md"
  ]
}'
