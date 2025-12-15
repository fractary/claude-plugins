#!/usr/bin/env bash
# Uninstall SDK-based MCP server reference from project settings
#
# Usage: ./uninstall-mcp.sh [options]
# Output: JSON with uninstallation status
#
# Options:
#   --settings <path>      Override settings.json path
#   --clean-cache          Also remove cache directory
#   --restore-backup       Restore from most recent backup
#
# Removes mcpServers.fractary-codex configuration from .claude/settings.json
# Works with both SDK-based and legacy custom MCP server configurations

set -euo pipefail

# Default paths
settings_path=".claude/settings.json"
clean_cache="false"
restore_backup="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --settings)
      settings_path="$2"
      shift 2
      ;;
    --clean-cache)
      clean_cache="true"
      shift
      ;;
    --restore-backup)
      restore_backup="true"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Check if settings file exists
if [[ ! -f "$settings_path" ]]; then
  jq -n \
    --arg path "$settings_path" \
    '{
      success: true,
      status: "not_found",
      message: "Settings file not found - nothing to uninstall",
      details: {
        settings: $path
      }
    }'
  exit 0
fi

# Read existing settings
existing_settings=$(cat "$settings_path")

# Check if MCP server is configured
if ! echo "$existing_settings" | jq -e '.mcpServers["fractary-codex"]' >/dev/null 2>&1; then
  jq -n \
    --arg path "$settings_path" \
    '{
      success: true,
      status: "not_installed",
      message: "MCP server not configured - nothing to uninstall",
      details: {
        settings: $path
      }
    }'
  exit 0
fi

# Handle restore backup option
if [[ "$restore_backup" == "true" ]]; then
  # Find most recent backup
  backup_file=$(ls -t "${settings_path}.backup."* 2>/dev/null | head -1 || true)

  if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
    cp "$backup_file" "$settings_path"
    jq -n \
      --arg settings "$settings_path" \
      --arg backup "$backup_file" \
      '{
        success: true,
        status: "restored",
        message: "Settings restored from backup",
        details: {
          settings: $settings,
          restored_from: $backup
        }
      }'
    exit 0
  else
    jq -n \
      --arg path "$settings_path" \
      '{
        success: false,
        error: "no_backup",
        message: "No backup file found to restore",
        details: {
          settings: $path
        }
      }'
    exit 1
  fi
fi

# Remove MCP server configuration
new_settings=$(echo "$existing_settings" | jq 'del(.mcpServers["fractary-codex"])')

# Clean up empty mcpServers object
new_settings=$(echo "$new_settings" | jq 'if .mcpServers == {} then del(.mcpServers) else . end')

# Write updated settings
echo "$new_settings" | jq . > "$settings_path"

# Track removed items
removed_items=(".claude/settings.json (mcpServers.fractary-codex)")

# Clean cache if requested
cache_removed="false"
cache_path=".fractary/plugins/codex/cache"

if [[ "$clean_cache" == "true" ]] && [[ -d "$cache_path" ]]; then
  rm -rf "$cache_path"
  cache_removed="true"
  removed_items+=("$cache_path")
fi

# Output result
jq -n \
  --arg settings "$settings_path" \
  --argjson cache_removed "$cache_removed" \
  --arg cache_path "$cache_path" \
  --argjson removed "$(printf '%s\n' "${removed_items[@]}" | jq -R . | jq -s .)" \
  '{
    success: true,
    status: "uninstalled",
    message: "MCP server configuration removed",
    details: {
      settings: $settings,
      cache_removed: $cache_removed,
      cache_path: (if $cache_removed then $cache_path else null end),
      removed_items: $removed
    },
    next_steps: [
      "Restart Claude Code to unload the MCP server",
      "Run /fractary-codex:init to reinstall if needed"
    ]
  }'
