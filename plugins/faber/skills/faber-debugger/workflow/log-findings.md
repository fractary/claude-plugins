# Log Findings

This workflow step documents the diagnosis and solutions to appropriate destinations.

## Overview

Debug findings should be logged to multiple destinations for visibility and audit:

1. **Terminal/Session** - Immediate feedback to user
2. **GitHub Issue** - Permanent record linked to work item
3. **Debug Log File** - Full context for audit trail

## Steps

### 1. Format Terminal Output

Create structured output for the Claude session:

**Output Template:**
```
🔍 DEBUGGER ANALYSIS COMPLETE
───────────────────────────────────────

## Problem Detected
{problem_summary}

## Root Cause Analysis
{root_cause}
Confidence: {confidence}
{kb_reference_if_any}

## Contributing Factors
{contributing_factors_list}

## Proposed Solution
{solution_title}

Steps:
{solution_steps}

## Files to Modify
{files_list}

## Recommended Next Step
```
{faber_run_command}
```

───────────────────────────────────────
Diagnosis logged to: {log_file}
{github_comment_status}
```

**Example Output:**
```
🔍 DEBUGGER ANALYSIS COMPLETE
───────────────────────────────────────

## Problem Detected
Build phase failed due to type errors in auth module

## Root Cause Analysis
Type annotations in src/auth.ts:45 are incorrect. The function returns
`AuthResult` but is annotated as returning `string`.
Confidence: High
KB Reference: faber-debug-042 (85% match, verified solution)

## Contributing Factors
- Incomplete specification from architect phase
- Missing @types/xyz package for full type coverage

## Proposed Solution
Fix type annotation in src/auth.ts

Steps:
1. Open src/auth.ts and locate line 45
2. Change return type from `string` to `AuthResult`
3. Run `npm run typecheck` to verify
4. Run `npm test` to ensure no regressions

## Files to Modify
- src/auth.ts

## Recommended Next Step
```
/fractary-faber:run --work-id 244 --step builder --prompt "Fix type errors in src/auth.ts as identified by debugger"
```

───────────────────────────────────────
Diagnosis logged to: .fractary/plugins/faber/debugger/logs/2025-12-05.log
GitHub comment: Added to issue #244
```

---

### 2. Post GitHub Comment

If work_id is provided and logging enabled, post to GitHub issue:

```bash
scripts/log-to-issue.sh "$WORK_ID" "$COMMENT_BODY"
```

**Comment Template:**
```markdown
## 🔍 Debugger Analysis

**Status**: {status_emoji} {diagnosis_summary}

### Problem Detected
{problem_description}

### Root Cause Analysis
{root_cause}

**Confidence**: {confidence}
{kb_reference_if_any}

### Proposed Solutions

{solutions_list_numbered}

### Recommended Next Step

\`\`\`
{faber_run_command}
\`\`\`

### Debug Context

| Metric | Value |
|--------|-------|
| Run ID | `{run_id}` |
| Failed Phase | {failed_phase} |
| Failed Step | {failed_step} |
| Errors Analyzed | {error_count} |
| KB Matches | {kb_match_count} |

---
*Analyzed by faber-debugger at {timestamp}*
```

**Example Comment:**
```markdown
## 🔍 Debugger Analysis

**Status**: ⚠️ Build failed - type errors detected

### Problem Detected
Build phase failed with 3 type errors in the auth module.

### Root Cause Analysis
Type annotations in `src/auth.ts:45` are incorrect. The function returns `AuthResult` but is annotated as returning `string`.

**Confidence**: High
**KB Reference**: [faber-debug-042] Similar issue resolved 7 times previously

### Proposed Solutions

1. **Fix type annotation in src/auth.ts** (Recommended)
   - Open src/auth.ts and locate line 45
   - Change return type from `string` to `AuthResult`
   - Run `npm run typecheck` to verify

2. **Install missing type definitions** (If needed)
   - Run `npm install -D @types/xyz`

### Recommended Next Step

```
/fractary-faber:run --work-id 244 --step builder --prompt "Fix type errors in src/auth.ts as identified by debugger"
```

### Debug Context

| Metric | Value |
|--------|-------|
| Run ID | `fractary/claude-plugins/abc123` |
| Failed Phase | build |
| Failed Step | implement |
| Errors Analyzed | 3 |
| KB Matches | 1 (85% similar) |

---
*Analyzed by faber-debugger at 2025-12-05T16:00:00Z*
```

---

### 3. Write Debug Log File

Create detailed log entry for audit trail:

**Log Location:** `.fractary/plugins/faber/debugger/logs/{YYYY-MM-DD}.log`

**Log Format (JSONL):**
```json
{
  "timestamp": "2025-12-05T16:00:00Z",
  "run_id": "fractary/claude-plugins/abc123",
  "work_id": "244",
  "mode": "automatic",

  "context": {
    "failed_phase": "build",
    "failed_step": "implement",
    "errors_count": 3,
    "warnings_count": 1
  },

  "diagnosis": {
    "root_cause": "Incorrect type annotation",
    "confidence": "high",
    "category": "type_system",
    "kb_match": {
      "id": "faber-debug-042",
      "score": 0.85
    }
  },

  "solution": {
    "title": "Fix type annotation",
    "complexity": "simple",
    "source": "knowledge_base",
    "steps_count": 4
  },

  "output": {
    "github_comment_posted": true,
    "github_comment_url": "https://github.com/.../issues/244#issuecomment-123",
    "spec_created": false,
    "continuation_command": "/fractary-faber:run --work-id 244 --step builder..."
  }
}
```

**Write Operation:**
```bash
LOG_DIR=".fractary/plugins/faber/debugger/logs"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).log"

mkdir -p "$LOG_DIR"
echo "$LOG_ENTRY_JSON" >> "$LOG_FILE"
```

---

### 4. Update Knowledge Base Index (Preparation)

If this is a novel issue (no high-relevance KB match), prepare for KB update:

```json
{
  "kb_update_candidate": {
    "eligible": true,
    "reason": "No high-relevance KB match found",
    "proposed_entry": {
      "category": "build",
      "issue_pattern": "Type mismatch in implementation",
      "symptoms": ["Type error: Expected string got AuthResult"],
      "keywords": ["type error", "type mismatch", "annotation"],
      "solutions": [
        {
          "title": "Fix type annotation",
          "steps": ["..."]
        }
      ]
    },
    "pending_verification": true,
    "note": "Will be added to KB after solution is verified successful"
  }
}
```

**Note:** Actual KB addition happens via separate "learn" operation after solution success.

---

### 5. Compile Log Summary

Return summary of logging operations:

```json
{
  "logging_summary": {
    "terminal_output": "displayed",
    "github_comment": {
      "posted": true,
      "url": "https://github.com/fractary/claude-plugins/issues/244#issuecomment-123456",
      "work_id": "244"
    },
    "log_file": {
      "path": ".fractary/plugins/faber/debugger/logs/2025-12-05.log",
      "entry_added": true
    },
    "kb_update": {
      "candidate_prepared": true,
      "pending_verification": true
    }
  }
}
```

## Error Handling

**GitHub API Failure:**
```
IF gh issue comment fails:
  Log warning: "Failed to post GitHub comment: {error}"
  Continue with terminal output
  Set github_comment.posted = false
  Do NOT fail the overall operation
```

**Log Directory Not Writable:**
```
IF cannot write to log directory:
  Try creating directory
  IF still fails:
    Log to /tmp as fallback
    Warn user about log location
```

**Large Context:**
```
IF full context > 50KB:
  Truncate error details in GitHub comment
  Keep full details in log file only
  Note: "Full context available in debug log"
```

## Output

Return logging status:

```json
{
  "status": "success",
  "message": "Findings logged successfully",
  "details": {
    "terminal": "displayed",
    "github": "posted",
    "log_file": ".fractary/plugins/faber/debugger/logs/2025-12-05.log"
  }
}
```
