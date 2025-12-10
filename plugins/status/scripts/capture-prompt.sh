#!/usr/bin/env bash
# capture-prompt.sh - Captures user prompts for display in status line
# Called by UserPromptSubmit hook
# Also tracks session metrics for context % and estimated cost display
# Usage: Called automatically by Claude Code hooks system

set -euo pipefail

# Configuration
PLUGIN_DIR="${FRACTARY_PLUGINS_DIR:-.fractary/plugins}/status"
PROMPT_CACHE="$PLUGIN_DIR/last-prompt.json"
METRICS_CACHE="$PLUGIN_DIR/session-metrics.json"
MAX_PROMPT_LENGTH=40
MAX_INPUT_SIZE=10000  # 10KB limit for safety

# Context window and pricing configuration
# Claude 3.5 Sonnet / Claude 4 context window
CONTEXT_WINDOW=200000
# Pricing: Claude 3.5 Sonnet ($3/M input, $15/M output)
# Values in micro-dollars (millionths of a dollar) per token
INPUT_PRICE_PER_TOKEN=3      # $3/M = 0.000003/token = 3 micro-dollars
OUTPUT_PRICE_PER_TOKEN=15    # $15/M = 0.000015/token = 15 micro-dollars

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

# ============================================================================
# Session Metrics Tracking
# Track estimated token usage and cost for status line display
# ============================================================================

# Get current session ID (use date as session identifier)
# This resets metrics each day, approximating session boundaries
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%Y%m%d)}"

# Estimate tokens from prompt length
# Rough heuristic: ~4 characters per token for English text
# This is approximate but provides useful estimates
PROMPT_LENGTH=${#CLEAN_PROMPT}
PROMPT_TOKENS_EST=$(( (PROMPT_LENGTH + 3) / 4 ))  # Round up

# Initialize or read existing metrics
INPUT_TOKENS=0
OUTPUT_TOKENS=0
STARTED_AT="$TIMESTAMP"

if [ -f "$METRICS_CACHE" ]; then
  # Check if this is the same session
  EXISTING_SESSION=$(jq -r '.session_id // ""' "$METRICS_CACHE" 2>/dev/null || echo "")

  if [ "$EXISTING_SESSION" = "$SESSION_ID" ]; then
    # Same session - accumulate
    INPUT_TOKENS=$(jq -r '.input_tokens_est // 0' "$METRICS_CACHE" 2>/dev/null || echo 0)
    OUTPUT_TOKENS=$(jq -r '.output_tokens_est // 0' "$METRICS_CACHE" 2>/dev/null || echo 0)
    STARTED_AT=$(jq -r '.started_at // ""' "$METRICS_CACHE" 2>/dev/null || echo "$TIMESTAMP")
  fi
  # If different session, we start fresh (INPUT_TOKENS and OUTPUT_TOKENS stay at 0)
fi

# Add this prompt's estimated tokens
INPUT_TOKENS=$((INPUT_TOKENS + PROMPT_TOKENS_EST))

# Estimate output tokens based on typical LLM response patterns
# Assumption: Responses are typically 2-4x the input length
# Using 3x as a reasonable middle ground
# This is updated per-prompt to provide running estimates
OUTPUT_TOKENS_EST=$((INPUT_TOKENS * 3))

# Calculate total tokens used
TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS_EST))

# Calculate context free percentage
# context_free_percent = (context_window - total_tokens) / context_window * 100
if [ $TOTAL_TOKENS -ge $CONTEXT_WINDOW ]; then
  CONTEXT_FREE_PCT=0
else
  CONTEXT_FREE_PCT=$(( (CONTEXT_WINDOW - TOTAL_TOKENS) * 100 / CONTEXT_WINDOW ))
fi

# Calculate estimated cost
# Cost = (input_tokens * input_price + output_tokens * output_price) / 1,000,000
# Using awk for floating point math
COST_DOLLARS=$(awk -v input="$INPUT_TOKENS" -v output="$OUTPUT_TOKENS_EST" \
  -v input_price="$INPUT_PRICE_PER_TOKEN" -v output_price="$OUTPUT_PRICE_PER_TOKEN" \
  'BEGIN {
    cost = (input * input_price + output * output_price) / 1000000
    printf "%.2f", cost
  }')

# Write metrics to cache
jq -n \
  --arg session_id "$SESSION_ID" \
  --arg started_at "$STARTED_AT" \
  --arg updated_at "$TIMESTAMP" \
  --argjson input_tokens "$INPUT_TOKENS" \
  --argjson output_tokens_est "$OUTPUT_TOKENS_EST" \
  --argjson total_tokens_est "$TOTAL_TOKENS" \
  --argjson context_free_percent "$CONTEXT_FREE_PCT" \
  --arg estimated_cost "$COST_DOLLARS" \
  --argjson context_window "$CONTEXT_WINDOW" \
  '{
    session_id: $session_id,
    started_at: $started_at,
    updated_at: $updated_at,
    input_tokens_est: $input_tokens,
    output_tokens_est: $output_tokens_est,
    total_tokens_est: $total_tokens_est,
    context_free_percent: $context_free_percent,
    estimated_cost: $estimated_cost,
    context_window: $context_window,
    note: "Estimates based on ~4 chars/token heuristic and 3x output ratio"
  }' > "$METRICS_CACHE.tmp" 2>/dev/null && {
  mv "$METRICS_CACHE.tmp" "$METRICS_CACHE" 2>/dev/null || true
}

# Exit silently (hook should not produce output)
exit 0
