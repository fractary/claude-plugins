# Specification: Status Line Context Free % and Token Cost Display

**Work ID:** 277
**Title:** Consider adding % context free to status line and estimated token cost
**Branch:** feat/277-status-line-context-and-cost
**Component:** Status Plugin

---

## Overview

Enhance the status line (`plugins/status/scripts/status-line.sh`) to display:
1. **Percent context free** - Current available context window as a percentage
2. **Estimated token cost** - Approximate cost of tokens used in the current session

Both values should be displayed in a de-emphasized (gray) color on the right side of the status line, separated by a pipe character.

---

## Current Implementation

**File:** `plugins/status/scripts/status-line.sh`

Current status line format:
```
[project] branch ±changes ↑ahead ↓behind WORK#123 PR#456
last: previous-user-prompt
```

The script:
- Uses ANSI color codes for formatting
- Reads git status from repo plugin cache
- Displays branch, file changes, issue/PR numbers
- Shows last prompt on second line (dim color)

---

## Requirements

### Functional Requirements

**FR1: Display Context Free Percentage**
- Show available context window as percentage (e.g., 45%, 78%)
- Source: Claude API session data (if available) or estimated from token usage
- Update frequency: Real-time (per session)
- Position: Right side of status line
- Color: Gray (dimmed)
- Fallback: If context % not available, omit from display

**FR2: Display Token Cost**
- Show estimated cost of tokens used in current session (e.g., $0.42)
- Calculation: Based on token counts and Claude pricing model
- Update frequency: Real-time (per session)
- Position: Right side of status line (after context %)
- Color: Gray (dimmed)
- Format: `$X.XX` (two decimal places)
- Fallback: If cost not available, omit from display

**FR3: Layout and Formatting**
- Place context % and cost at right end of status line
- Separate with pipe character: `XX%FREE | $XX.XX`
- Use gray/dim color for de-emphasis
- Do not interfere with existing status line components (left-aligned)
- Support both terminal (with ANSI codes) and web IDE modes

**FR4: Backward Compatibility**
- Script must work without access to context/cost data
- If environment variables not set, gracefully omit the new display
- Existing status line functionality unchanged when new data unavailable
- No breaking changes to status line format when data is available

### Non-Functional Requirements

**NFR1: Context Efficiency**
- Script remains <250 lines (currently ~238)
- No additional skill invocations
- All calculations performed in-script
- Minimal performance impact on status line rendering

**NFR2: No Changes to Status Line Hook**
- Status line is invoked via `.claude/settings.json` statusLine hook
- Do not modify hook configuration or invocation mechanism
- Enhancement is purely script-level

**NFR3: Data Source Strategy**
- Primary: FABER workflow state tracking (token counts)
- Secondary: Environment variables (if set by Claude Code)
- Tertiary: Estimation based on prompt length (fallback)
- No external API calls

---

## Design

### Data Sources

**Context Free % Calculation:**

```bash
# Option A: From Claude Code environment variables
CONTEXT_FREE="${CLAUDE_CONTEXT_FREE:-}"  # e.g., "45"

# Option B: From FABER state (if running in workflow)
if [ -z "$CONTEXT_FREE" ]; then
  CONTEXT_FREE=$(jq -r '.context_metrics.free_percent // empty' \
    .fractary/plugins/faber/runs/*/state.json 2>/dev/null | head -1)
fi

# Option C: Estimation (placeholder)
# Calculate based on .fractary/plugins/faber/runs/*/events/*.json
```

**Token Cost Calculation:**

```bash
# Option A: From Claude Code environment variables
TOKEN_COST="${CLAUDE_SESSION_COST:-}"  # e.g., "0.42"

# Option B: From FABER state
if [ -z "$TOKEN_COST" ]; then
  TOKEN_COST=$(jq -r '.metrics.token_cost // empty' \
    .fractary/plugins/faber/runs/*/state.json 2>/dev/null | head -1)
fi

# Option C: Estimation (placeholder)
# Calculate from token counts in workflow state
```

### Display Logic

**Position:** Right-aligned at end of first line

```bash
# Build right-side metrics (only if data available)
METRICS_LINE=""
if [ -n "$CONTEXT_FREE" ] && [ "$CONTEXT_FREE" != "0" ]; then
  METRICS_LINE="${METRICS_LINE}${DIM}${CONTEXT_FREE}%FREE${NC}"
fi

if [ -n "$TOKEN_COST" ] && [ "$TOKEN_COST" != "0" ]; then
  if [ -n "$METRICS_LINE" ]; then
    METRICS_LINE="${METRICS_LINE} ${DIM}|${NC}"
  fi
  METRICS_LINE="${METRICS_LINE}${DIM}\$${TOKEN_COST}${NC}"
fi

# Append to status line (right-aligned)
if [ -n "$METRICS_LINE" ]; then
  STATUS_LINE="${STATUS_LINE}  ${METRICS_LINE}"
fi
```

### Color Scheme

- **Existing colors** (unchanged): Cyan, Yellow, Green, Magenta, Blue
- **New color** (metrics): DIM (dark gray, already defined in script as `\033[2m`)
- Terminal format: `\033[2m` prefix + content + `${NC}` suffix
- Web IDE: Same formatting (DIM ANSI codes work in web IDE)

---

## Implementation Details

### File to Modify

**File:** `/plugins/status/scripts/status-line.sh`

**Changes:**
1. Add context free % data source logic (after line ~160, with last prompt logic)
2. Add token cost data source logic (after context free logic)
3. Build metrics display string (after status line is built, before output)
4. Append metrics to STATUS_LINE (right-aligned)
5. No changes to color definitions or existing logic

### Code Structure

```bash
# Around line 160, after LAST_PROMPT logic:

# Read context free percentage (from environment or FABER state)
CONTEXT_FREE=""
if [ -n "${CLAUDE_CONTEXT_FREE:-}" ]; then
  CONTEXT_FREE="$CLAUDE_CONTEXT_FREE"
elif [ -d ".fractary/plugins/faber/runs" ]; then
  # Try to read from FABER state (newest run)
  CONTEXT_FREE=$(find .fractary/plugins/faber/runs -name "state.json" -type f \
    -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- | \
    xargs jq -r '.metrics.context_free_percent // empty' 2>/dev/null)
fi

# Read token cost (from environment or FABER state)
TOKEN_COST=""
if [ -n "${CLAUDE_SESSION_COST:-}" ]; then
  TOKEN_COST="$CLAUDE_SESSION_COST"
elif [ -d ".fractary/plugins/faber/runs" ]; then
  # Try to read from FABER state (newest run)
  TOKEN_COST=$(find .fractary/plugins/faber/runs -name "state.json" -type f \
    -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- | \
    xargs jq -r '.metrics.token_cost // empty' 2>/dev/null)
fi

# Around line 220, after STATUS_LINE is fully built and before output:

# Build metrics display (right-aligned)
METRICS_LINE=""
if [ -n "$CONTEXT_FREE" ] && [ "$CONTEXT_FREE" != "0" ]; then
  METRICS_LINE="${DIM}${CONTEXT_FREE}%FREE${NC}"
fi

if [ -n "$TOKEN_COST" ] && [ "$TOKEN_COST" != "0" ]; then
  if [ -n "$METRICS_LINE" ]; then
    METRICS_LINE="${METRICS_LINE} ${DIM}|${NC}"
  fi
  METRICS_LINE="${METRICS_LINE} ${DIM}\$${TOKEN_COST}${NC}"
fi

# Append metrics to status line (with spacing for right-alignment)
if [ -n "$METRICS_LINE" ]; then
  STATUS_LINE="${STATUS_LINE}  ${METRICS_LINE}"
fi
```

---

## Testing Strategy

### Test Cases

**TC1: No data available**
- Precondition: No `CLAUDE_CONTEXT_FREE` or `CLAUDE_SESSION_COST` env vars
- Precondition: No FABER state file
- Expected: Status line displays normally without metrics
- Result: Backward compatible

**TC2: Context free % only**
- Precondition: `CLAUDE_CONTEXT_FREE="45"` set
- Precondition: No cost data
- Expected: Status line shows `45%FREE` at right in gray
- Result: Partial metrics displayed

**TC3: Token cost only**
- Precondition: `CLAUDE_SESSION_COST="0.42"` set
- Precondition: No context free data
- Expected: Status line shows `$0.42` at right in gray
- Result: Partial metrics displayed

**TC4: Both metrics available**
- Precondition: `CLAUDE_CONTEXT_FREE="78"` and `CLAUDE_SESSION_COST="1.23"` set
- Expected: Status line shows `78%FREE | $1.23` at right in gray
- Result: Both metrics displayed with pipe separator

**TC5: Terminal vs Web IDE**
- Precondition: Running in terminal with colors enabled
- Precondition: Running in Claude Code web IDE (CLAUDE_CODE_REMOTE set)
- Expected: Metrics display correctly in both environments
- Result: Terminal has ANSI codes, web IDE handles them gracefully

**TC6: Zero values handling**
- Precondition: `CLAUDE_CONTEXT_FREE="0"` or `CLAUDE_SESSION_COST="0"`
- Expected: Zero values are skipped (treated as unavailable)
- Result: Zero values not displayed

### Manual Testing

```bash
# Test 1: View status line without metrics
./plugins/status/scripts/status-line.sh

# Test 2: View status line with metrics
CLAUDE_CONTEXT_FREE="67" CLAUDE_SESSION_COST="2.15" \
  ./plugins/status/scripts/status-line.sh

# Test 3: Check output in NO_COLOR mode
NO_COLOR=1 CLAUDE_CONTEXT_FREE="45" ./plugins/status/scripts/status-line.sh
```

---

## Integration Points

### FABER State Integration

If FABER workflow is running, metrics can be read from:
```
.fractary/plugins/faber/runs/{run_id}/state.json
  .metrics.context_free_percent (example: 45)
  .metrics.token_cost (example: 0.42)
```

The script should:
1. Check if FABER runs directory exists
2. Find the most recently created state file
3. Extract metrics if present
4. Fall back to environment variables if not found

### Environment Variables (Claude Code Integration)

If Claude Code exposes context metrics via environment variables:
- `CLAUDE_CONTEXT_FREE` - Context free percentage (0-100)
- `CLAUDE_SESSION_COST` - Session cost in dollars (format: X.XX)

The script checks these first before looking at FABER state.

---

## Migration Path

### Phase 1: Initial Implementation
- Add metrics display logic to status-line.sh
- Support environment variables as data source
- Gray color, right-aligned format
- Graceful fallback when data unavailable

### Phase 2: FABER Integration (Future)
- Update FABER state schema to include `metrics` object
- Add token counting to build and evaluate phases
- Calculate context free % based on token budget
- FABER skills populate metrics in state

### Phase 3: Cost Estimation (Future)
- Implement Claude pricing lookup
- Calculate session cost based on token counts
- Support multiple Claude models with different pricing

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Metrics data not available | Silent failure | Gracefully omit from display, keep existing status line |
| Performance degradation | Slow status line render | Cache metrics data, avoid expensive lookups per render |
| Color support varies | Display issues | Use existing `NO_COLOR` env var support |
| FABER state format changes | Parsing failures | Use `jq` safely with `// empty` fallback |
| Token cost calculation errors | Wrong display | Validate format, skip if invalid |

---

## Success Criteria

- [x] Status line displays context free % when available
- [x] Status line displays token cost when available
- [x] Metrics are gray/dimmed color
- [x] Metrics are right-aligned, pipe-separated
- [x] Backward compatible (works without metrics data)
- [x] No breaking changes to existing status line
- [x] Tested in terminal and web IDE modes
- [x] Script remains <250 lines
- [x] No performance degradation

---

## References

- **Issue:** #277 - Consider adding % context free to status line and estimated token cost
- **Current Implementation:** `/plugins/status/scripts/status-line.sh`
- **Related Files:**
  - `.claude/settings.json` (statusLine hook configuration)
  - `.fractary/plugins/faber/runs/*/state.json` (FABER metrics)
- **Pricing Reference:** Claude pricing model (future integration)

