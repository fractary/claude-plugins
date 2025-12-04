#!/usr/bin/env bash
# Validate codex plugin setup
#
# Usage: ./validate-setup.sh [options]
# Output: JSON with validation results
#
# Options:
#   --json              Output in JSON format
#   --verbose           Show detailed status
#
# Checks for:
#   - Config file exists and is valid
#   - Cache directory exists and is writable
#   - MCP server is installed
#   - Cache index is valid

set -euo pipefail

# Defaults
json_output="false"
verbose="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      json_output="true"
      shift
      ;;
    --verbose)
      verbose="true"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Paths
config_path=".fractary/plugins/codex/config.json"
cache_dir=".fractary/plugins/codex/cache"
cache_index="$cache_dir/index.json"
mcp_settings=".claude/settings.json"

# Status tracking
config_exists="false"
config_valid="false"
config_version=""
config_org=""
config_errors=""

cache_exists="false"
cache_writable="false"
cache_size=0

index_exists="false"
index_valid="false"
index_entries=0

mcp_installed="false"
mcp_server_name=""

issues=()
warnings=()

# Check config file
if [[ -f "$config_path" ]]; then
  config_exists="true"

  # Validate JSON
  if jq empty "$config_path" 2>/dev/null; then
    config_valid="true"
    config_version=$(jq -r '.version // "unknown"' "$config_path")
    config_org=$(jq -r '.organization // ""' "$config_path")

    # Check required fields
    if [[ -z "$config_org" ]]; then
      config_errors="Missing required field: organization"
      issues+=("Config: Missing 'organization' field")
    fi

    codex_repo=$(jq -r '.codex_repo // ""' "$config_path")
    if [[ -z "$codex_repo" ]]; then
      issues+=("Config: Missing 'codex_repo' field")
    fi
  else
    config_valid="false"
    config_errors="Invalid JSON"
    issues+=("Config: Invalid JSON format")
  fi
else
  issues+=("Config: File not found at $config_path")
fi

# Check cache directory
if [[ -d "$cache_dir" ]]; then
  cache_exists="true"

  # Check if writable
  if [[ -w "$cache_dir" ]]; then
    cache_writable="true"
  else
    issues+=("Cache: Directory not writable")
  fi

  # Calculate size (in KB)
  cache_size=$(du -sk "$cache_dir" 2>/dev/null | cut -f1 || echo "0")
else
  issues+=("Cache: Directory not found at $cache_dir")
fi

# Check cache index
if [[ -f "$cache_index" ]]; then
  index_exists="true"

  if jq empty "$cache_index" 2>/dev/null; then
    index_valid="true"
    index_entries=$(jq '.entries | length // 0' "$cache_index" 2>/dev/null || echo "0")
  else
    index_valid="false"
    issues+=("Cache index: Invalid JSON format")
  fi
fi

# Check MCP server installation
if [[ -f "$mcp_settings" ]]; then
  # Look for codex MCP server in settings
  mcp_server_name=$(jq -r '.mcpServers | to_entries[] | select(.key | test("codex"; "i")) | .key' "$mcp_settings" 2>/dev/null | head -1 || true)

  if [[ -n "$mcp_server_name" ]]; then
    mcp_installed="true"
  else
    warnings+=("MCP: Server not found in $mcp_settings")
  fi
else
  warnings+=("MCP: Settings file not found at $mcp_settings")
fi

# Determine overall status
issue_count=${#issues[@]}
warning_count=${#warnings[@]}

if [[ $issue_count -eq 0 ]]; then
  overall_status="ready"
  status_emoji="✅"
  status_message="Codex plugin is properly configured"
elif [[ $issue_count -le 2 ]]; then
  overall_status="partial"
  status_emoji="⚠️"
  status_message="Codex plugin has configuration issues"
else
  overall_status="not_configured"
  status_emoji="❌"
  status_message="Codex plugin is not configured"
fi

# Output results
if [[ "$json_output" == "true" ]]; then
  jq -n \
    --argjson config_exists "$config_exists" \
    --argjson config_valid "$config_valid" \
    --arg config_version "$config_version" \
    --arg config_org "$config_org" \
    --argjson cache_exists "$cache_exists" \
    --argjson cache_writable "$cache_writable" \
    --argjson cache_size "$cache_size" \
    --argjson index_exists "$index_exists" \
    --argjson index_valid "$index_valid" \
    --argjson index_entries "$index_entries" \
    --argjson mcp_installed "$mcp_installed" \
    --arg mcp_server_name "$mcp_server_name" \
    --arg overall_status "$overall_status" \
    --argjson issue_count "$issue_count" \
    --argjson warning_count "$warning_count" \
    --argjson issues "$(printf '%s\n' "${issues[@]:-}" | jq -R . | jq -s .)" \
    --argjson warnings "$(printf '%s\n' "${warnings[@]:-}" | jq -R . | jq -s .)" \
    '{
      success: true,
      status: $overall_status,
      config: {
        exists: $config_exists,
        valid: $config_valid,
        version: $config_version,
        organization: $config_org
      },
      cache: {
        exists: $cache_exists,
        writable: $cache_writable,
        size_kb: $cache_size,
        index: {
          exists: $index_exists,
          valid: $index_valid,
          entries: $index_entries
        }
      },
      mcp: {
        installed: $mcp_installed,
        server_name: $mcp_server_name
      },
      issues: $issues,
      warnings: $warnings,
      issue_count: $issue_count,
      warning_count: $warning_count
    }'
else
  echo "$status_emoji Codex Plugin Setup Validation"
  echo ""
  echo "Status: $status_message"
  echo ""

  # Config section
  echo "Configuration:"
  if [[ "$config_exists" == "true" ]]; then
    if [[ "$config_valid" == "true" ]]; then
      echo "  ✅ Config file valid (v$config_version)"
      echo "     Organization: $config_org"
    else
      echo "  ❌ Config file invalid"
    fi
  else
    echo "  ❌ Config file not found"
  fi
  echo ""

  # Cache section
  echo "Cache:"
  if [[ "$cache_exists" == "true" ]]; then
    if [[ "$cache_writable" == "true" ]]; then
      echo "  ✅ Cache directory ready"
      echo "     Size: ${cache_size}KB"
      if [[ "$index_valid" == "true" ]]; then
        echo "     Index entries: $index_entries"
      fi
    else
      echo "  ⚠️ Cache directory not writable"
    fi
  else
    echo "  ❌ Cache directory not found"
  fi
  echo ""

  # MCP section
  echo "MCP Server:"
  if [[ "$mcp_installed" == "true" ]]; then
    echo "  ✅ Installed as '$mcp_server_name'"
  else
    echo "  ⚠️ Not installed"
    echo "     Run: /fractary-codex:init to install"
  fi
  echo ""

  # Issues
  if [[ $issue_count -gt 0 ]]; then
    echo "Issues ($issue_count):"
    for issue in "${issues[@]}"; do
      echo "  • $issue"
    done
    echo ""
  fi

  # Warnings
  if [[ $warning_count -gt 0 ]] && [[ "$verbose" == "true" ]]; then
    echo "Warnings ($warning_count):"
    for warning in "${warnings[@]}"; do
      echo "  • $warning"
    done
    echo ""
  fi

  # Next steps
  if [[ "$overall_status" != "ready" ]]; then
    echo "Next Steps:"
    echo "  Run: /fractary-codex:init to configure the plugin"
  fi
fi
