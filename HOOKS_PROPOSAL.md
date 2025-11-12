# Proposal: Simplified Hooks with Context Injection

## Current State

The existing hooks implementation in faber-cloud has:
- **Configuration location**: `.fractary/plugins/{plugin}/config/{plugin}.json`
- **Hook types**: `script` and `skill`
- **Execution**: Via `execute-hooks.sh` script
- **Lifecycle hooks**: pre-plan, post-plan, pre-deploy, post-deploy, etc.

**Example current format**:
```json
{
  "hooks": {
    "pre-deploy": [
      {
        "type": "script",
        "path": "./scripts/build.sh",
        "required": true,
        "failureMode": "stop"
      },
      {
        "type": "skill",
        "name": "dataset-validator",
        "required": true
      }
    ]
  }
}
```

## Problem Statement

You want to:
1. Build on the existing implementation (not replace it)
2. Add ability to inject context/documentation into hooks
3. Simplify the approach - instead of rigid hook types, use flexible text prompts
4. Extend this to FABER workflow phases and potentially other plugins

## Proposed Simplified Approach

### Key Idea: Text-Based Context Injection

Instead of having multiple hook types (script, skill, context, prompt), just have a **single flexible `prompt` field** that can:
- Reference documentation: "Refer to docs/STANDARDS.md for coding standards"
- Execute scripts: "Run ./scripts/setup.sh to prepare the environment"
- Invoke skills: "Use the @skill-security-scanner skill to validate"
- Provide guidance: "Ensure all changes follow our microservices patterns"

**The agent interprets the prompt naturally** and takes appropriate action.

### Configuration Format

Extend the existing JSON format with an optional `prompt` field:

```json
{
  "hooks": {
    "pre-deploy": [
      {
        "name": "project-context",
        "prompt": "Review the architecture standards in docs/ARCHITECTURE.md and ensure this deployment follows our patterns. Pay special attention to the database migration section.",
        "required": false
      },
      {
        "name": "build-and-test",
        "prompt": "Execute ./scripts/build-lambdas.sh to build all Lambda functions, then run ./scripts/test-suite.sh to validate. Both must succeed.",
        "required": true,
        "failureMode": "stop"
      },
      {
        "name": "security-check",
        "prompt": "Use the @skill-fractary-cloud:security-scanner skill to scan for vulnerabilities.",
        "required": true,
        "failureMode": "stop",
        "environments": ["prod"]
      }
    ]
  }
}
```

### Backward Compatibility

Keep existing `type: "script"` and `type: "skill"` hooks working:

```json
{
  "hooks": {
    "pre-deploy": [
      // OLD FORMAT - still works
      {
        "type": "script",
        "path": "./scripts/build.sh",
        "required": true
      },
      // NEW FORMAT - flexible prompt
      {
        "name": "context-injection",
        "prompt": "Apply the coding standards from docs/STANDARDS.md when reviewing changes."
      }
    ]
  }
}
```

**Migration path**:
- Old `type: "script"` → Continue working via execute-hooks.sh
- New `prompt` → Handled by agent that reads and interprets

## Implementation Plan

### Phase 1: Extend Existing Hook Execution

**File to modify**: `plugins/faber-cloud/skills/cloud-common/scripts/execute-hooks.sh`

**Changes**:
1. Detect new `prompt` field in hook configuration
2. When `prompt` exists, instead of executing a script:
   - Load the prompt text
   - If prompt references files (e.g., "docs/X.md"), load those files
   - Build a context block with the prompt + referenced content
   - Return this context to the calling skill
3. The calling skill receives context and applies it

**Example**:
```bash
# In execute-hooks.sh
if hook has "prompt" field:
    # Extract any file references from prompt
    FILES=$(extract_file_refs "$PROMPT")

    # Load referenced files
    CONTEXT="$PROMPT\n\n"
    for file in $FILES; do
        CONTEXT="$CONTEXT\n## Referenced: $file\n$(cat $file)\n"
    done

    # Return context (via stdout or temp file)
    echo "$CONTEXT" > /tmp/hook-context-$$.txt
```

### Phase 2: Modify Skills to Inject Context

**Files to modify**: Skills that invoke hooks (e.g., `infra-deployer/SKILL.md`)

**Current pattern**:
```markdown
6. Execute pre-deploy hooks:
   ```bash
   bash execute-hooks.sh pre-deploy {environment}
   ```
```

**New pattern**:
```markdown
6. Execute pre-deploy hooks and capture context:
   ```bash
   HOOK_CONTEXT=$(bash execute-hooks.sh pre-deploy {environment})
   ```

7. If hook context exists, apply it:
   <INJECTED_CONTEXT>
   $HOOK_CONTEXT
   </INJECTED_CONTEXT>

   Use this context when proceeding with deployment.
```

### Phase 3: Extend to FABER

Add hooks configuration to `.faber.config.toml`:

```toml
[project]
name = "my-app"

# Hooks for FABER workflow phases
[hooks]

[[hooks.architect.pre]]
name = "architecture-guidance"
prompt = """
Review our architecture patterns in docs/architecture/PATTERNS.md.
Ensure the design follows:
- Microservices boundaries as defined in the patterns doc
- API versioning strategy (section: API Design)
- Database access patterns (section: Data Layer)
"""

[[hooks.build.pre]]
name = "coding-standards"
prompt = """
Apply coding standards from docs/CODING_STANDARDS.md.
Run ./scripts/lint.sh to check code style before proceeding.
"""
required = true

[[hooks.release.pre]]
name = "production-checklist"
prompt = """
⚠️ PRODUCTION RELEASE

Before releasing:
1. Review deployment checklist in docs/DEPLOYMENT.md
2. Verify all tests pass: Run ./scripts/test-all.sh
3. Use @skill-security-scanner to scan for vulnerabilities
4. Confirm migrations are backward compatible

Do not proceed until all items complete.
"""
environments = ["prod"]
required = true
```

### Phase 4: Simple File Reference Helper

Add a lightweight helper to detect and load file references:

**File**: `plugins/faber-cloud/skills/cloud-common/scripts/load-context-refs.sh`

```bash
#!/bin/bash
# Extracts file references from prompt and loads content

PROMPT="$1"

# Extract patterns like:
# - "docs/FILE.md"
# - "in docs/FILE.md"
# - "from FILE.md"
# - "see FILE.md"

# Simple approach: Find any .md files mentioned
FILES=$(echo "$PROMPT" | grep -oE '[a-zA-Z0-9_/-]+\.md')

echo "──────────────────────────────────────────────"
echo "INJECTED CONTEXT"
echo "──────────────────────────────────────────────"
echo ""
echo "$PROMPT"
echo ""

for file in $FILES; do
    if [ -f "$file" ]; then
        echo ""
        echo "## Referenced: $file"
        echo ""
        cat "$file"
        echo ""
    fi
done

echo "──────────────────────────────────────────────"
```

## Benefits of This Approach

### 1. Simplicity
- **One concept**: Just a text prompt, not multiple hook types
- **Natural language**: Write what you want in plain English
- **Flexible**: Can combine multiple instructions in one prompt

### 2. Backward Compatible
- Existing `type: "script"` hooks continue working
- Existing `type: "skill"` hooks continue working
- New `prompt` hooks are additive

### 3. No Rigid Structure
- Don't need to classify as "script" vs "skill" vs "context"
- Agent figures it out from natural language
- Easy to add new capabilities without schema changes

### 4. Leverages Existing Patterns
- Builds on faber-cloud's execute-hooks.sh
- Uses same configuration location (.fractary/plugins/*/config.json)
- Same lifecycle hooks (pre-plan, post-deploy, etc.)

### 5. Easy to Extend
- Add to FABER phases: Just add hooks config to .faber.config.toml
- Add to other plugins: Reuse execute-hooks.sh pattern
- Add new hook points: Just add new hook type names

## Example Use Cases

### Use Case 1: Inject Architecture Standards

```json
{
  "hooks": {
    "pre-deploy": [
      {
        "name": "architecture-context",
        "prompt": "Before deploying, review our architecture patterns in docs/architecture/PATTERNS.md, especially the sections on microservices and API design. Ensure this deployment follows those patterns."
      }
    ]
  }
}
```

**Result**: Agent loads PATTERNS.md and applies guidance during deployment

### Use Case 2: Execute Scripts + Provide Context

```json
{
  "hooks": {
    "pre-deploy": [
      {
        "name": "build-and-standards",
        "prompt": "First, run ./scripts/build-all.sh to build artifacts. Then apply our coding standards from docs/STANDARDS.md when reviewing the build output.",
        "required": true
      }
    ]
  }
}
```

**Result**: Agent executes script AND loads documentation

### Use Case 3: Environment-Specific Warnings

```json
{
  "hooks": {
    "pre-deploy": [
      {
        "name": "production-warning",
        "prompt": "⚠️ PRODUCTION DEPLOYMENT\n\nThis is a production deployment. Extra caution required:\n1. All tests must pass\n2. Review deployment checklist in docs/PRODUCTION.md\n3. Notify team in Slack before proceeding\n4. Have rollback plan ready",
        "environments": ["prod"],
        "required": true
      }
    ]
  }
}
```

**Result**: Critical warnings shown only for production

### Use Case 4: Skill Invocation + Context

```json
{
  "hooks": {
    "post-deploy": [
      {
        "name": "validate-with-context",
        "prompt": "Use the @skill-smoke-tester skill to validate the deployment. When interpreting results, refer to our health check standards in docs/MONITORING.md.",
        "required": true
      }
    ]
  }
}
```

**Result**: Skill invoked with additional context

## Open Questions

### Q1: How do we detect file references in prompts?

**Options**:
A. Simple regex: Look for patterns like `*.md`, `docs/*`
B. Natural language: Agent determines what files to load
C. Explicit syntax: Use markers like `[ref:docs/FILE.md]`

**Recommendation**: Start with simple regex (A), evolve to (B) if needed

### Q2: Should we keep separate script/skill types?

**Options**:
A. Keep them for backward compatibility, but discourage new usage
B. Keep them as shortcuts (less verbose than prompt)
C. Deprecate and migrate everything to prompts

**Recommendation**: (A) - Keep for backward compatibility, new hooks use prompts

### Q3: How do we handle prompt hooks in FABER?

**Options**:
A. Same execute-hooks.sh pattern, adapted for FABER
B. New FABER-specific hook executor
C. Reuse faber-cloud's scripts

**Recommendation**: (A) - Adapt existing pattern, keep consistency

### Q4: Where do FABER hooks config live?

**Options**:
A. `.faber.config.toml` → `[hooks]` section
B. `.fractary/plugins/faber/config.json` → `hooks` object
C. Both (TOML for convenience, JSON for plugins)

**Recommendation**: (A) - Use TOML in .faber.config.toml for consistency

## Next Steps (If Approved)

1. **Modify execute-hooks.sh** to detect and handle `prompt` field
2. **Add load-context-refs.sh** helper script for loading referenced files
3. **Update infra-deployer skill** to inject hook context
4. **Create FABER example** in .faber.config.toml
5. **Adapt for FABER workflow-manager** to execute hooks
6. **Document the pattern** in existing HOOKS.md guide
7. **Test with real projects** to validate approach

## File Changes Required

### Modify Existing
- `plugins/faber-cloud/skills/cloud-common/scripts/execute-hooks.sh` - Add prompt support
- `plugins/faber-cloud/skills/infra-deployer/SKILL.md` - Inject hook context
- `plugins/faber-cloud/skills/infra-planner/SKILL.md` - Inject hook context
- `plugins/faber-cloud/docs/guides/HOOKS.md` - Document prompt hooks

### Add New
- `plugins/faber-cloud/skills/cloud-common/scripts/load-context-refs.sh` - Helper
- Example config with prompt hooks
- FABER hooks documentation

### For FABER Extension
- `plugins/faber/agents/workflow-manager.md` - Add hook execution
- `plugins/faber/config/faber.example.toml` - Add hooks examples

---

**Question for you**: Does this simplified approach align with what you had in mind? Should we proceed with this plan, or would you like to adjust the approach?
