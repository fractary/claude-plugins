# Update Knowledge Base

This workflow step adds new entries to the troubleshooting knowledge base after successful resolution.

## Overview

The knowledge base is a persistent collection of troubleshooting entries that grows over time. This step is triggered separately via a "learn" operation after a solution has been verified successful.

**Trigger:** After successful workflow completion following debugger guidance

## Steps

### 1. Validate Learning Request

Check that the update request is valid:

```json
{
  "operation": "learn",
  "parameters": {
    "run_id": "fractary/claude-plugins/abc123",
    "work_id": "244",
    "diagnosis_id": "debug-session-20251205-160000",
    "solution_applied": "Fix type annotation",
    "verified_success": true
  }
}
```

**Validation Checks:**
- [ ] run_id exists and has completed state
- [ ] work_id matches the original debug session
- [ ] diagnosis_id references a valid debug session
- [ ] solution_applied matches a proposed solution
- [ ] verified_success is true

---

### 2. Load Debug Session Data

Retrieve the original debug session:

```bash
LOG_FILE=".fractary/plugins/faber/debugger/logs/$(date +%Y-%m-%d).log"
SESSION_DATA=$(grep "$DIAGNOSIS_ID" "$LOG_FILE")
```

**Extract from session:**
```json
{
  "original_errors": [...],
  "root_cause": "...",
  "solution": {...},
  "context": {...}
}
```

---

### 3. Check for Existing Entry

Avoid duplicating knowledge base entries:

```bash
scripts/search-kb.sh \
  --exact-match \
  --patterns "$ERROR_PATTERNS" \
  --threshold 0.95
```

**If High Match Found (>= 0.95):**
```json
{
  "duplicate_check": {
    "found": true,
    "existing_entry": "faber-debug-042",
    "similarity": 0.97,
    "action": "update_existing",
    "updates": {
      "usage_count": "+1",
      "last_used": "2025-12-05",
      "references": ["#244"]
    }
  }
}
```

**If No Match:**
```json
{
  "duplicate_check": {
    "found": false,
    "action": "create_new"
  }
}
```

---

### 4. Generate Entry ID

Create unique identifier for new entry:

```bash
# Get next sequence number
LAST_ID=$(jq -r '.entries | keys | map(select(startswith("faber-debug-"))) | sort | last' "$INDEX_FILE")
NEXT_SEQ=$(( ${LAST_ID#faber-debug-} + 1 ))
NEW_ID="faber-debug-$(printf '%03d' $NEXT_SEQ)"
```

**Example:** `faber-debug-048`

---

### 5. Prepare Entry Content

Format the knowledge base entry:

**Template:** `templates/kb-entry.template`

```yaml
---
kb_id: {kb_id}
category: {category}
issue_pattern: "{issue_pattern}"
symptoms:
{symptoms_yaml}
keywords:
{keywords_yaml}
root_causes:
{root_causes_yaml}
solutions:
{solutions_yaml}
status: unverified
created: {date}
last_used: {date}
usage_count: 1
references:
  - "#{work_id}"
---

# {issue_pattern}

## Problem Description

{problem_description}

## Symptoms

{symptoms_detailed}

## Root Cause Analysis

{root_cause_analysis}

## Solution

{solution_detailed}

## Verification

{verification_steps}

## Notes

{additional_notes}
```

**Example Entry:**
```yaml
---
kb_id: faber-debug-048
category: build
issue_pattern: "Type mismatch in implementation - annotation doesn't match return"
symptoms:
  - "Type error: Expected string, got AuthResult"
  - "Type error: Cannot assign type"
keywords:
  - type error
  - type mismatch
  - annotation
  - return type
root_causes:
  - "Function return type annotation doesn't match actual return value"
  - "API contract changed without updating types"
solutions:
  - title: "Fix type annotation"
    steps:
      - "Identify the expected return type from implementation"
      - "Update the type annotation to match"
      - "Run type checker to verify"
    faber_command: "/fractary-faber:run --work-id {id} --step builder --prompt 'Fix type annotation as identified by debugger'"
status: unverified
created: 2025-12-05
last_used: 2025-12-05
usage_count: 1
references:
  - "#244"
---

# Type mismatch in implementation - annotation doesn't match return

## Problem Description

Build phase fails with type errors when a function's return type annotation
doesn't match the actual value being returned.

## Symptoms

- Error messages containing "Type error: Expected X, got Y"
- Build failure in type checking phase
- Typically occurs after refactoring or API changes

## Root Cause Analysis

This commonly occurs when:
1. A function's implementation is changed but the type annotation isn't updated
2. An API response type changes upstream
3. A refactor changes return values without updating signatures

## Solution

1. Locate the function with the type error (file:line in error message)
2. Check what the function actually returns
3. Update the return type annotation to match
4. Run `npm run typecheck` to verify
5. Run tests to ensure no regressions

## Verification

After applying the fix:
- Type checker should pass
- All existing tests should pass
- No new type errors introduced

## Notes

This is a common issue during rapid development. Consider adding
pre-commit type checking to catch earlier.
```

---

### 6. Determine Category

Assign appropriate category based on error type:

| Category | Indicators |
|----------|------------|
| workflow | workflow_start, phase_*, step_* errors |
| build | implement, compile, type errors |
| test | test failures, assertion errors |
| deploy | release, PR, deployment errors |
| general | uncategorized or mixed errors |

```bash
case "$ERROR_CATEGORY" in
  type_system|dependencies|compile)
    CATEGORY="build"
    ;;
  assertion|timeout|test_*)
    CATEGORY="test"
    ;;
  pr_*|release_*|deploy_*)
    CATEGORY="deploy"
    ;;
  workflow_*|phase_*|step_*)
    CATEGORY="workflow"
    ;;
  *)
    CATEGORY="general"
    ;;
esac
```

---

### 7. Write Entry File

Save the entry to the knowledge base:

```bash
KB_PATH=".fractary/plugins/faber/debugger/knowledge-base"
ENTRY_DIR="$KB_PATH/$CATEGORY"
ENTRY_FILE="$ENTRY_DIR/$KB_ID-$SLUG.md"

mkdir -p "$ENTRY_DIR"
echo "$ENTRY_CONTENT" > "$ENTRY_FILE"
```

---

### 8. Update Index

Add entry to the searchable index:

```bash
scripts/kb-add-entry.sh \
  --id "$KB_ID" \
  --path "$CATEGORY/$KB_ID-$SLUG.md" \
  --category "$CATEGORY" \
  --keywords "$KEYWORDS" \
  --patterns "$PATTERNS"
```

**Index Entry:**
```json
{
  "faber-debug-048": {
    "path": "build/faber-debug-048-type-mismatch.md",
    "category": "build",
    "issue_pattern": "Type mismatch in implementation",
    "keywords": ["type error", "type mismatch", "annotation"],
    "patterns": ["Type error: Expected * got *"],
    "status": "unverified",
    "created": "2025-12-05",
    "usage_count": 1
  }
}
```

---

### 9. Commit Changes (Optional)

If auto-commit enabled, commit the KB update:

```bash
if [ "$AUTO_COMMIT_KB" = "true" ]; then
  git add "$ENTRY_FILE" "$INDEX_FILE"
  git commit -m "chore(debugger): Add KB entry $KB_ID for issue #$WORK_ID

Troubleshooting entry for: $ISSUE_PATTERN
Category: $CATEGORY
References: #$WORK_ID"
fi
```

---

### 10. Return Confirmation

```json
{
  "status": "success",
  "message": "Knowledge base updated with new entry",
  "details": {
    "action": "create_new",
    "kb_id": "faber-debug-048",
    "category": "build",
    "path": "build/faber-debug-048-type-mismatch.md",
    "index_updated": true,
    "committed": false,
    "reference": "#244"
  }
}
```

## Error Handling

**Index Locked:**
```
IF index.json is locked:
  Wait up to 5 seconds
  Retry acquisition
  IF still locked: Fail with "Index is locked by another process"
```

**Entry Already Exists:**
```
IF entry file exists at path:
  Check if same issue_pattern
  IF yes: Update instead of create
  IF no: Append sequence number to filename
```

**Write Permission Denied:**
```
IF cannot write to KB directory:
  Log error
  Return failure with suggested fix:
    "Check permissions on .fractary/plugins/faber/debugger/"
```

## Output

```json
{
  "status": "success",
  "message": "Knowledge base entry faber-debug-048 created",
  "details": {
    "kb_id": "faber-debug-048",
    "category": "build",
    "issue_pattern": "Type mismatch in implementation",
    "path": ".fractary/plugins/faber/debugger/knowledge-base/build/faber-debug-048-type-mismatch.md"
  }
}
```

## Verification Workflow

After creating an entry, it starts as "unverified". To verify:

1. Entry is used successfully 3+ times
2. Manual review confirms correctness
3. Update status: `status: verified`

```bash
# Promote to verified after successful uses
scripts/kb-update-status.sh --id faber-debug-048 --status verified
```
