# Generate Continuation Command

This workflow step creates the appropriate `/fractary-faber:run` command for continuing the workflow after applying fixes.

## Overview

After diagnosing issues and proposing solutions, generate a FABER continuation command that:

1. Resumes from the appropriate step
2. Includes context about the debugging session
3. Provides clear instructions for the next phase

## Steps

### 1. Determine Resume Point

Analyze where the workflow should resume:

**Resume Logic:**

| Failed Phase | Failed Step | Resume From |
|--------------|-------------|-------------|
| build | implement | build.implement |
| build | commit | build.commit (or implement if code changes needed) |
| evaluate | test | evaluate.test (or build if implementation fix) |
| evaluate | review | evaluate.review |
| release | create-pr | release.create-pr |

**Decision Tree:**
```
IF solution requires code changes:
  Resume from: build.implement
ELSE IF solution requires test fixes only:
  Resume from: evaluate.test
ELSE IF solution is config/dependency only:
  Resume from: failed step
ELSE:
  Resume from: failed step
```

```json
{
  "resume_analysis": {
    "failed_phase": "build",
    "failed_step": "implement",
    "solution_type": "code_fix",
    "resume_phase": "build",
    "resume_step": "implement",
    "reason": "Solution requires code changes to fix type errors"
  }
}
```

---

### 2. Build Prompt Content

Create a focused prompt for the continuation:

**Prompt Structure:**
```
Review the issues and proposed solutions identified by faber-debugger and implement the recommended fixes.

## Debugger Analysis Summary
{diagnosis_summary}

## Recommended Fix
{solution_title}

## Steps to Implement
{solution_steps}

## Files to Modify
{files_list}

## Verification
After implementing, run:
- {verification_commands}
```

**Example Prompt:**
```
Review the issues and proposed solutions identified by faber-debugger and implement the recommended fixes.

## Debugger Analysis Summary
Build failed due to type mismatches in auth module. Root cause: incorrect type annotation.

## Recommended Fix
Fix type annotation in src/auth.ts

## Steps to Implement
1. Open src/auth.ts and locate line 45
2. Change return type from `string` to `AuthResult`
3. Run `npm run typecheck` to verify

## Files to Modify
- src/auth.ts

## Verification
After implementing, run:
- npm run typecheck
- npm test
```

---

### 3. Add Relevant Flags

Determine additional flags for the command:

**Available Flags:**

| Flag | When to Use |
|------|-------------|
| `--retry` | Resuming a failed step |
| `--skip-to` | Jumping to a specific step |
| `--force` | Override guardrails (use carefully) |
| `--workflow` | If different workflow needed |

**Flag Selection:**
```json
{
  "flags": {
    "retry": false,
    "skip_to": null,
    "workflow": "default",
    "reason": "Standard resume from failed step"
  }
}
```

---

### 4. Generate Command

Assemble the complete command:

**Template:**
```bash
scripts/generate-command.sh \
  --work-id "$WORK_ID" \
  --phase "$RESUME_PHASE" \
  --step "$RESUME_STEP" \
  --prompt "$PROMPT_CONTENT" \
  --workflow "$WORKFLOW_ID"
```

**Output Format:**
```
/fractary-faber:run --work-id 244 --workflow default --step builder --prompt "Review the issues and proposed solutions identified by faber-debugger and implement the recommended fixes.

## Debugger Analysis Summary
Build failed due to type mismatches in auth module.

## Recommended Fix
Fix type annotation in src/auth.ts:45 - change return type from string to AuthResult

## Verification
After implementing, run: npm run typecheck && npm test"
```

---

### 5. Handle Multi-Step Solutions

For complex solutions requiring multiple steps:

**Sequential Commands:**
```json
{
  "commands": [
    {
      "order": 1,
      "description": "Install dependencies",
      "command": "/fractary-faber:run --work-id 244 --step builder --prompt 'Install missing @types/xyz package'",
      "expected_outcome": "Types installed successfully"
    },
    {
      "order": 2,
      "description": "Fix type errors",
      "command": "/fractary-faber:run --work-id 244 --step builder --prompt 'Fix type errors with newly available types'",
      "expected_outcome": "Type check passes"
    }
  ],
  "recommendation": "Execute commands in order. If step 1 succeeds, proceed to step 2."
}
```

**Or Create Spec:**
If 3+ sequential commands needed, recommend creating a spec:
```
Multiple coordinated fixes needed. A specification has been created:
specs/WORK-00244-debugger-fixes.md

Continue with:
/fractary-faber:run --work-id 244 --step builder --prompt 'Implement fixes per debugger specification'
```

---

### 6. Validate Command

Ensure command is valid before returning:

**Validation Checks:**
- [ ] work_id is present and valid
- [ ] workflow exists
- [ ] step is valid for the workflow
- [ ] prompt is not empty
- [ ] prompt is properly escaped for shell

```bash
# Escape special characters in prompt
escaped_prompt=$(printf '%s' "$PROMPT" | sed "s/'/'\\\\''/g")

# Validate workflow exists
if ! jq -e ".phases.${RESUME_PHASE}" ".fractary/plugins/faber/workflows/${WORKFLOW_ID}.json" >/dev/null 2>&1; then
  echo "Warning: Could not validate phase '$RESUME_PHASE' in workflow"
fi
```

---

### 7. Format Output

Return formatted command with context:

```json
{
  "continuation": {
    "command": "/fractary-faber:run --work-id 244 --step builder --prompt '...'",
    "parsed": {
      "work_id": "244",
      "workflow": "default",
      "phase": "build",
      "step": "implement",
      "prompt_summary": "Fix type errors in auth module"
    },
    "context": {
      "resuming_from": "build.implement (failed)",
      "solution_applied": "Fix type annotation",
      "kb_reference": "faber-debug-042"
    },
    "alternatives": [],
    "next_step_after_success": "build.commit → evaluate → release"
  }
}
```

**Display Format:**
```
## Recommended Next Step

\`\`\`
/fractary-faber:run --work-id 244 --step builder --prompt "Review the issues and proposed solutions identified by faber-debugger and implement the recommended fixes.

## Debugger Analysis Summary
Build failed due to type mismatches in auth module.

## Recommended Fix
Fix type annotation in src/auth.ts:45

## Verification
After implementing: npm run typecheck && npm test"
\`\`\`

This will resume the Build phase and implement the fix. After success, the workflow will continue to Evaluate and Release phases.
```

## Error Handling

**Invalid Step:**
```
IF step not found in workflow:
  Fall back to phase start
  Log warning: "Step not found, resuming from phase start"
```

**Prompt Too Long:**
```
IF prompt > 2000 characters:
  Summarize diagnosis
  Reference spec if created
  Log: "Prompt condensed for command line compatibility"
```

**Multiple Workflows:**
```
IF run used non-default workflow:
  Include --workflow flag
  Warn if workflow definition changed
```

## Output

Save continuation command:

```bash
echo "$CONTINUATION_JSON" >> /tmp/faber-debugger-context.json
```

Return command for display:

```
Continuation Command:
/fractary-faber:run --work-id 244 --step builder --prompt 'Fix type errors as identified by debugger'
```
