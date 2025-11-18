#!/usr/bin/env bash
# capture-prompt.sh - Captures user prompts for display in status line
# Called by UserPromptSubmit hook
# Usage: Called automatically by Claude Code hooks system

set -euo pipefail

# Configuration
PLUGIN_DIR="${FRACTARY_PLUGINS_DIR:-.fractary/plugins}/status"
PROMPT_CACHE="$PLUGIN_DIR/last-prompt.json"
MAX_PROMPT_LENGTH=40
MAX_INPUT_SIZE=10000  # 10KB limit for safety

# Ensure plugin directory exists
mkdir -p "$PLUGIN_DIR"

# Read prompt from stdin or environment with size limit
if [ -n "${PROMPT_TEXT:-}" ]; then
  PROMPT="$PROMPT_TEXT"
else
  # Read with size limit to prevent memory issues
  PROMPT=$(head -c "$MAX_INPUT_SIZE")
fi

# Validate input size
if [ ${#PROMPT} -gt "$MAX_INPUT_SIZE" ]; then
  # Truncate to safe size if exceeded
  PROMPT="${PROMPT:0:$MAX_INPUT_SIZE}"
fi

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
  }' > "$PROMPT_CACHE.tmp" 2>/dev/null || {
  # If jq fails, create a minimal fallback cache
  echo '{"timestamp":"'$TIMESTAMP'","prompt":"","prompt_short":""}' > "$PROMPT_CACHE.tmp" 2>/dev/null || true
}

# Atomic move to prevent race conditions (only if temp file exists)
if [ -f "$PROMPT_CACHE.tmp" ]; then
  mv "$PROMPT_CACHE.tmp" "$PROMPT_CACHE" 2>/dev/null || true
fi

# Exit silently (hook should not produce output)
exit 0
