#!/usr/bin/env bash
# Install MCP server reference in project settings
#
# Usage: ./install-mcp.sh [options]
# Output: JSON with installation status
#
# Options:
#   --marketplace <path>   Override marketplace path
#   --settings <path>      Override settings.json path
#   --backup               Create backup of existing settings (default: true)
#   --no-backup            Skip backup creation
#
# Adds mcpServers.fractary-codex configuration to .claude/settings.json

set -euo pipefail

# Default paths
marketplace_path="${CLAUDE_MARKETPLACE_PATH:-$HOME/.claude/plugins/marketplaces/fractary/plugins/codex}"
settings_path=".claude/settings.json"
create_backup="true"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --marketplace)
      marketplace_path="$2"
      shift 2
      ;;
    --settings)
      settings_path="$2"
      shift 2
      ;;
    --backup)
      create_backup="true"
      shift
      ;;
    --no-backup)
      create_backup="false"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Verify MCP server exists
mcp_server_path="$marketplace_path/mcp-server/dist/index.js"

if [[ ! -f "$mcp_server_path" ]]; then
  # Try alternative path (development mode - in plugin directory)
  alt_path="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/mcp-server/dist/index.js"
  if [[ -f "$alt_path" ]]; then
    mcp_server_path="$alt_path"
  else
    jq -n \
      --arg path "$mcp_server_path" \
      --arg alt "$alt_path" \
      '{
        success: false,
        error: "mcp_not_found",
        message: "MCP server not found. Build the MCP server first.",
        details: {
          expected_path: $path,
          alt_path: $alt
        }
      }'
    exit 1
  fi
fi

# Create .claude directory if needed
settings_dir=$(dirname "$settings_path")
if [[ ! -d "$settings_dir" ]]; then
  mkdir -p "$settings_dir"
fi

# Initialize or read existing settings
existing_settings="{}"
backup_path=""

if [[ -f "$settings_path" ]]; then
  existing_settings=$(cat "$settings_path")

  # Create backup if requested
  if [[ "$create_backup" == "true" ]]; then
    backup_path="${settings_path}.backup.$(date +%Y%m%d%H%M%S)"
    cp "$settings_path" "$backup_path"
  fi
fi

# Check if already installed
if echo "$existing_settings" | jq -e '.mcpServers["fractary-codex"]' >/dev/null 2>&1; then
  # Already installed - check if update needed
  existing_command=$(echo "$existing_settings" | jq -r '.mcpServers["fractary-codex"].args[0] // ""')

  if [[ "$existing_command" == "$mcp_server_path" ]]; then
    jq -n \
      --arg path "$mcp_server_path" \
      --arg settings "$settings_path" \
      '{
        success: true,
        status: "already_installed",
        message: "MCP server already configured",
        details: {
          mcp_server: $path,
          settings: $settings
        }
      }'
    exit 0
  fi
fi

# Build MCP server configuration
mcp_config=$(jq -n \
  --arg server_path "$mcp_server_path" \
  '{
    command: "node",
    args: [$server_path],
    env: {
      CODEX_CACHE_PATH: "./.fractary/plugins/codex/cache",
      CODEX_CONFIG_PATH: "./.fractary/plugins/codex/config.json"
    }
  }')

# Merge into existing settings
new_settings=$(echo "$existing_settings" | jq \
  --argjson mcp "$mcp_config" \
  '.mcpServers = (.mcpServers // {}) | .mcpServers["fractary-codex"] = $mcp')

# Write updated settings
echo "$new_settings" | jq . > "$settings_path"

# Output result
jq -n \
  --arg mcp_path "$mcp_server_path" \
  --arg settings "$settings_path" \
  --arg backup "$backup_path" \
  --argjson had_existing "$(echo "$existing_settings" | jq 'has("mcpServers")')" \
  '{
    success: true,
    status: "installed",
    message: "MCP server configured successfully",
    details: {
      mcp_server: $mcp_path,
      settings: $settings,
      backup: (if $backup == "" then null else $backup end),
      updated_existing: $had_existing
    },
    next_steps: [
      "Restart Claude Code to load the MCP server",
      "Run /fractary-codex:validate-setup to verify configuration"
    ]
  }'
