# Specification: Fix Context Usage and Session Cost Display

**Work ID:** 335
**Title:** % context usage and session cost not working
**Branch:** fix/335-context-usage
**Component:** Status Plugin

---

## Problem Statement

Issue #277 implemented the status-line.sh script to display context window percentage and estimated session cost. However, the feature is not working because:

1. **No data sources exist** - The script looks for:
   - Environment variables `CLAUDE_CONTEXT_FREE` and `CLAUDE_SESSION_COST` (not provided by Claude Code)
   - FABER state metrics `.metrics.context_free_percent` and `.metrics.token_cost` (not populated)

2. **No mechanism to calculate/estimate these values** - There's no code that actually generates or tracks token usage.

---

## Root Cause Analysis

**status-line.sh** (lines 172-198) attempts to read metrics from:
```bash
# Option 1: Environment variables (not set by Claude Code)
CONTEXT_FREE="${CLAUDE_CONTEXT_FREE:-}"
TOKEN_COST="${CLAUDE_SESSION_COST:-}"

# Option 2: FABER state file (metrics field doesn't exist)
CONTEXT_FREE=$(jq -r '.metrics.context_free_percent // empty' state.json)
TOKEN_COST=$(jq -r '.metrics.token_cost // empty' state.json)
```

Since neither data source exists, the metrics never display.

---

## Solution Design

### Approach: Token Estimation via Prompt Tracking

Since Claude Code doesn't expose context usage via API, we'll estimate it by:
1. Tracking prompts via the existing `UserPromptSubmit` hook
2. Estimating tokens from prompt character count (rough: ~4 chars = 1 token)
3. Accumulating totals in a session metrics cache file
4. Reading from this cache in status-line.sh

### Architecture

```
UserPromptSubmit hook
        |
        v
capture-prompt.sh (existing)
        |
        +-- last-prompt.json (existing)
        |
        +-- session-metrics.json (NEW)
             {
               "session_id": "...",
               "started_at": "...",
               "input_tokens_est": 12500,
               "output_tokens_est": 45000,
               "total_tokens_est": 57500,
               "context_free_percent": 71,  // (200k - 57.5k) / 200k * 100
               "estimated_cost": 0.42       // based on Claude pricing
             }
        |
        v
status-line.sh (reads session-metrics.json)
```

### Key Design Decisions

1. **Session-based tracking**: Metrics reset on new Claude Code session
2. **Estimation accuracy**: Accept ~20% error margin (better than nothing)
3. **Claude 3.5 Sonnet context**: Use 200K tokens as default context window
4. **Pricing**: Claude 3.5 Sonnet pricing ($3/M input, $15/M output)

---

## Implementation Details

### File Changes

#### 1. Modify `capture-prompt.sh` to track token estimates

**File:** `plugins/status/scripts/capture-prompt.sh`

Add after prompt capture:
```bash
# Session metrics tracking
METRICS_CACHE="$PLUGIN_DIR/session-metrics.json"

# Get current session ID (use Claude process start time as session ID)
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%Y%m%d)}"

# Estimate tokens from prompt length (rough: ~4 chars = 1 token)
PROMPT_LENGTH=${#PROMPT}
PROMPT_TOKENS_EST=$((PROMPT_LENGTH / 4))

# Read existing metrics or initialize
if [ -f "$METRICS_CACHE" ]; then
  EXISTING_SESSION=$(jq -r '.session_id // ""' "$METRICS_CACHE" 2>/dev/null)
  if [ "$EXISTING_SESSION" != "$SESSION_ID" ]; then
    # New session - reset metrics
    echo '{}' > "$METRICS_CACHE"
  fi
fi

# Update metrics
INPUT_TOKENS=$(jq -r '.input_tokens_est // 0' "$METRICS_CACHE" 2>/dev/null || echo 0)
INPUT_TOKENS=$((INPUT_TOKENS + PROMPT_TOKENS_EST))

# Estimate output tokens (assume 3:1 output:input ratio based on typical usage)
OUTPUT_TOKENS=$((INPUT_TOKENS * 3))
TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))

# Context window: 200K tokens for Claude 3.5 Sonnet
CONTEXT_WINDOW=200000
CONTEXT_FREE_PCT=$(( (CONTEXT_WINDOW - TOTAL_TOKENS) * 100 / CONTEXT_WINDOW ))
if [ $CONTEXT_FREE_PCT -lt 0 ]; then CONTEXT_FREE_PCT=0; fi

# Cost calculation: Claude 3.5 Sonnet ($3/M input, $15/M output)
# Cost in millicents, divide by 100000 for dollars
INPUT_COST_MCENTS=$((INPUT_TOKENS * 3))      # $3/M = 0.003/K = 3 mcents/K
OUTPUT_COST_MCENTS=$((OUTPUT_TOKENS * 15))   # $15/M = 0.015/K = 15 mcents/K
TOTAL_COST_MCENTS=$((INPUT_COST_MCENTS + OUTPUT_COST_MCENTS))
# Convert to dollars with 2 decimals
COST_DOLLARS=$(awk "BEGIN {printf \"%.2f\", $TOTAL_COST_MCENTS / 100000}")

# Write metrics
jq -n \
  --arg session_id "$SESSION_ID" \
  --arg started_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson input_tokens "$INPUT_TOKENS" \
  --argjson output_tokens "$OUTPUT_TOKENS" \
  --argjson total_tokens "$TOTAL_TOKENS" \
  --argjson context_free_percent "$CONTEXT_FREE_PCT" \
  --arg estimated_cost "$COST_DOLLARS" \
  '{
    session_id: $session_id,
    started_at: $started_at,
    input_tokens_est: $input_tokens,
    output_tokens_est: $output_tokens,
    total_tokens_est: $total_tokens,
    context_free_percent: $context_free_percent,
    estimated_cost: $estimated_cost
  }' > "$METRICS_CACHE.tmp" && mv "$METRICS_CACHE.tmp" "$METRICS_CACHE"
```

#### 2. Modify `status-line.sh` to read session metrics

**File:** `plugins/status/scripts/status-line.sh`

Replace lines 172-198 with:
```bash
# Get context free percentage and token cost from session metrics
CONTEXT_FREE=""
TOKEN_COST=""
METRICS_CACHE="$PLUGIN_DIR/session-metrics.json"

# Primary: Read from session metrics cache (populated by capture-prompt.sh)
if [ -f "$METRICS_CACHE" ]; then
  CONTEXT_FREE=$(jq -r '.context_free_percent // empty' "$METRICS_CACHE" 2>/dev/null)
  TOKEN_COST=$(jq -r '.estimated_cost // empty' "$METRICS_CACHE" 2>/dev/null)
fi

# Fallback: Environment variables (if Claude Code ever provides them)
if [ -z "$CONTEXT_FREE" ] && [ -n "${CLAUDE_CONTEXT_FREE:-}" ]; then
  CONTEXT_FREE="$CLAUDE_CONTEXT_FREE"
fi
if [ -z "$TOKEN_COST" ] && [ -n "${CLAUDE_SESSION_COST:-}" ]; then
  TOKEN_COST="$CLAUDE_SESSION_COST"
fi
```

---

## Testing Strategy

### Test Cases

**TC1: Fresh session (no prompts yet)**
- Expected: No metrics displayed (session-metrics.json doesn't exist)

**TC2: After first prompt**
- Run `capture-prompt.sh` with sample prompt
- Expected: session-metrics.json created with initial estimates
- Expected: status-line.sh displays `XX%FREE | $0.XX`

**TC3: Accumulated prompts**
- Run multiple prompts through capture-prompt.sh
- Expected: Metrics accumulate correctly
- Expected: context_free_percent decreases, estimated_cost increases

**TC4: Session reset**
- Simulate new session (change SESSION_ID)
- Expected: Metrics reset to initial values

### Manual Testing

```bash
# Test prompt capture with metrics
echo "Test prompt for issue #335" | ./plugins/status/scripts/capture-prompt.sh
cat .fractary/plugins/status/session-metrics.json

# Test status line display
./plugins/status/scripts/status-line.sh

# Test accumulated usage
for i in {1..5}; do
  echo "Accumulated test prompt $i with more content to increase token count" | \
    ./plugins/status/scripts/capture-prompt.sh
done
./plugins/status/scripts/status-line.sh
```

---

## Limitations & Future Improvements

### Current Limitations

1. **Estimation accuracy**: Token count is approximate (~4 chars/token is a rough heuristic)
2. **Output estimation**: We can't know actual LLM output tokens, so we estimate 3:1 ratio
3. **Model-specific**: Pricing assumes Claude 3.5 Sonnet; different models have different prices
4. **Session detection**: Uses date-based session ID as Claude Code doesn't expose session info

### Future Improvements

1. **Claude Code API integration**: If/when Claude Code exposes context usage via API/env vars
2. **Per-model pricing**: Support different Claude models with their specific pricing
3. **Response tracking**: If hook data includes response length, use actual output tokens
4. **Persistent history**: Track usage across sessions for cost reporting

---

## Success Criteria

- [ ] Session metrics cache is created on first prompt
- [ ] context_free_percent is calculated and displayed in status line
- [ ] estimated_cost is calculated and displayed in status line
- [ ] Metrics accumulate correctly across prompts in same session
- [ ] No errors when session-metrics.json doesn't exist
- [ ] Status line degrades gracefully (no metrics) when capture-prompt.sh hasn't run

---

## References

- **Related Issue:** #277 - Original feature request
- **Original Spec:** `specs/WORK-00277-status-line-context-and-cost.md`
- **Files:**
  - `plugins/status/scripts/capture-prompt.sh` - UserPromptSubmit hook
  - `plugins/status/scripts/status-line.sh` - StatusLine display script
  - `.fractary/plugins/status/session-metrics.json` - NEW metrics cache

