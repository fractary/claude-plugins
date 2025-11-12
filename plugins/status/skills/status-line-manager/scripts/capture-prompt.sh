#!/usr/bin/env bash
# capture-prompt.sh - Captures user prompts for display in status line
# Called by UserPromptSubmit hook
# Usage: Called automatically by Claude Code hooks system

set -euo pipefail

# Configuration
PLUGIN_DIR="${FRACTARY_PLUGINS_DIR:-.fractary/plugins}/status"
PROMPT_CACHE="$PLUGIN_DIR/last-prompt.json"
MAX_PROMPT_LENGTH=40

# Ensure plugin directory exists
mkdir -p "$PLUGIN_DIR"

# Read prompt from stdin or environment
PROMPT="${PROMPT_TEXT:-$(cat)}"

# Get timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Clean and truncate prompt
clean_prompt() {
  local prompt="$1"
  # Strip leading/trailing whitespace
  prompt=$(echo "$prompt" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  # Replace newlines with spaces
  prompt=$(echo "$prompt" | tr '\n' ' ')
  # Collapse multiple spaces
  prompt=$(echo "$prompt" | tr -s ' ')
  echo "$prompt"
}

truncate_prompt() {
  local prompt="$1"
  local max_len="$2"

  if [ ${#prompt} -le "$max_len" ]; then
    echo "$prompt"
    return
  fi

  # Try to truncate at word boundary
  local truncated="${prompt:0:$max_len}"
  local last_space=$(echo "$truncated" | grep -o ' ' | wc -l)

  if [ "$last_space" -gt 0 ]; then
    truncated=$(echo "$truncated" | sed 's/[[:space:]][^[:space:]]*$//')
  fi

  # Ensure we have room for "..."
  if [ ${#truncated} -gt $((max_len - 3)) ]; then
    truncated="${truncated:0:$((max_len - 3))}"
  fi

  echo "${truncated}..."
}

# Process prompt
CLEAN_PROMPT=$(clean_prompt "$PROMPT")
SHORT_PROMPT=$(truncate_prompt "$CLEAN_PROMPT" "$MAX_PROMPT_LENGTH")

# Create JSON using jq for proper escaping
jq -n \
  --arg timestamp "$TIMESTAMP" \
  --arg prompt "$CLEAN_PROMPT" \
  --arg prompt_short "$SHORT_PROMPT" \
  '{
    timestamp: $timestamp,
    prompt: $prompt,
    prompt_short: $prompt_short
  }' > "$PROMPT_CACHE.tmp"

# Atomic move to prevent race conditions
mv "$PROMPT_CACHE.tmp" "$PROMPT_CACHE"

# Exit silently (hook should not produce output)
exit 0
