# Debugger Command

Invoke the FABER debugger to diagnose workflow issues and propose solutions.

## Usage

```bash
/fractary-faber:debug --run-id <run-id> [options]
/fractary-faber:debug --work-id <work-id> [options]
```

## Options

- `--run-id <id>`: FABER workflow run ID to debug (required if no --work-id)
- `--work-id <id>`: Work item ID (issue number) - will find latest run for this work item
- `--problem "<text>"`: Explicit problem description (targeted debugging mode)
- `--phase <phase>`: Focus analysis on specific phase (frame|architect|build|evaluate|release)
- `--step <step>`: Focus analysis on specific step within phase
- `--create-spec`: Force specification creation for complex issues
- `--learn`: Add successful resolution to knowledge base (after fix is applied)

## Modes

### Automatic Detection Mode
When invoked without `--problem`, the debugger automatically:
1. Reads workflow state and event history
2. Aggregates errors and warnings from step executions
3. Searches knowledge base for similar past issues
4. Proposes solutions based on analysis

```bash
# Debug the latest run for work item 244
/fractary-faber:debug --work-id 244

# Debug a specific run
/fractary-faber:debug --run-id "fractary/claude-plugins/abc123"
```

### Targeted Debugging Mode
When `--problem` is provided, the debugger focuses on the specific issue:

```bash
# Debug a specific problem
/fractary-faber:debug --work-id 244 --problem "Test suite failing with timeout errors"
```

### Learning Mode
After a successful fix, add the resolution to the knowledge base:

```bash
# Add successful resolution to KB
/fractary-faber:debug --run-id "fractary/claude-plugins/abc123" --learn
```

## Examples

### Debug Failed Build
```bash
# Debug why the build failed
/fractary-faber:debug --work-id 244

# Output:
# 🔍 DEBUGGER ANALYSIS COMPLETE
# ───────────────────────────────────────
#
# ## Problem Detected
# Build phase failed due to type errors in auth module
#
# ## Root Cause Analysis
# Type annotations in src/auth.ts:45 are incorrect.
# Confidence: High
# KB Reference: faber-debug-042 (85% match)
#
# ## Proposed Solution
# Fix type annotation in src/auth.ts
#
# ## Recommended Next Step
# /fractary-faber:run --work-id 244 --step builder --prompt "Fix type errors..."
```

### Debug Specific Phase
```bash
# Focus on evaluate phase issues
/fractary-faber:debug --work-id 244 --phase evaluate

# Focus on a specific step
/fractary-faber:debug --work-id 244 --phase build --step commit
```

### Create Spec for Complex Issues
```bash
# Force spec creation for multi-step fix
/fractary-faber:debug --work-id 244 --create-spec
```

## Output

The debugger produces:

1. **Terminal Output**: Complete diagnostic report with analysis and solutions
2. **GitHub Comment**: Summary posted to the linked issue (if --work-id provided)
3. **Debug Log**: Full context saved to `.fractary/plugins/faber/debugger/logs/`

### GitHub Comment Format
```markdown
## 🔍 Debugger Analysis

**Status**: ⚠️ Build failed - type errors detected

### Problem Detected
Build phase failed with 3 type errors in the auth module.

### Root Cause Analysis
Type annotations are incorrect...

### Proposed Solutions
1. **Fix type annotation** (Recommended)
   - Open src/auth.ts and locate line 45
   - Change return type...

### Recommended Next Step
```
/fractary-faber:run --work-id 244 --step builder --prompt "..."
```
```

## Integration

### Automatic Invocation
The debugger can be configured to run automatically when steps fail:

**.faber.config.toml**:
```toml
[workflow.evaluate]
on_failure = "debug"  # Automatically invoke debugger

[debugger]
enabled = true
auto_detect_errors = true
log_to_github = true
```

### Workflow Step
Add debugger as an explicit workflow step:

**workflows/default.json**:
```json
{
  "phases": {
    "evaluate": {
      "steps": [
        { "name": "test", "skill": "..." },
        { "name": "debug", "skill": "faber-debugger", "when": "previous_has_warnings" },
        { "name": "review", "skill": "..." }
      ]
    }
  }
}
```

## Knowledge Base

The debugger maintains a knowledge base at:
`.fractary/plugins/faber/debugger/knowledge-base/`

### View KB Statistics
```bash
# List knowledge base entries
ls .fractary/plugins/faber/debugger/knowledge-base/*/

# View the index
cat .fractary/plugins/faber/debugger/knowledge-base/index.json | jq '.entries | keys'
```

### Manual KB Entry
```bash
# Add a manual entry after resolving an issue
/fractary-faber:debug --run-id "run-id" --learn
```

## See Also

- `/fractary-faber:run` - Run or resume FABER workflow
- `/fractary-faber:status` - View workflow status
- `plugins/faber/skills/faber-debugger/SKILL.md` - Full skill documentation
