# Migration Guide: Manager-as-Skill Inversion Fix

## Overview

**Anti-pattern**: Manager implemented as Skill (Manager-as-Skill Inversion)
**Correct pattern**: Manager as Agent with full tool access

This guide shows how to fix the Manager-as-Skill inversion anti-pattern.

---

## The Problem: Manager-as-Skill Inversion

### What is Manager-as-Skill Inversion?

A Manager-as-Skill inversion occurs when orchestration logic is implemented as a Skill instead of an Agent:

```
skills/workflow-orchestrator/SKILL.md  ❌ WRONG LOCATION
---
skill: workflow-orchestrator
purpose: Orchestrate complete workflow
---

<WORKFLOW>
Phase 1: GATHER
Phase 2: ANALYZE
Phase 3: PRESENT
Phase 4: APPROVE
Phase 5: EXECUTE
Phase 6: VERIFY
Phase 7: REPORT
</WORKFLOW>
```

**Problems:**
- **Skills can't ask questions** (no AskUserQuestion tool)
- **Skills can't manage state** (limited tool access)
- **Skills can't orchestrate** (that's an Agent's job)
- **Context inefficiency** (skill invoked repeatedly, re-reading workflow each time)

### How Does This Happen?

**Common causes:**

1. **Misunderstanding of Agent vs Skill:**
   - "Skills are for work, so I'll make a skill for workflow"
   - Missing that orchestration IS work that requires an Agent

2. **Following a pattern blindly:**
   - Saw other skills, created orchestration as skill
   - Didn't recognize orchestration needs Agent capabilities

3. **Tool limitation workaround:**
   - Needed orchestration but thought Agents were "too powerful"
   - Created skill as "lightweight agent" (doesn't work)

4. **Incremental evolution:**
   - Started as simple skill
   - Added more orchestration over time
   - Never refactored to Agent

### Real-World Example

**DevOps Plugin (Before Fix):**

```
plugins/faber-cloud/
├── agents/
│   └── cloud-director.md          # Just routes to skill ✓
└── skills/
    └── devops-manager/            # ❌ Manager as Skill
        ├── SKILL.md               # Orchestration in skill file
        └── workflow/
            └── deploy.md          # Multi-phase workflow
```

**Problems:**
- `devops-manager` skill has 7-phase workflow
- Can't ask user questions (no AskUserQuestion)
- Can't manage deployment state properly
- Director agent is just routing to skill (not orchestrating)

**After Fix:**

```
plugins/faber-cloud/
├── agents/
│   ├── cloud-director.md          # Lightweight router ✓
│   └── infra-manager.md           # ✓ Manager as Agent
└── skills/
    ├── infra-deployer/            # ✓ Execution skill
    ├── infra-validator/           # ✓ Execution skill
    └── infra-monitor/             # ✓ Execution skill
```

**Improvements:**
- `infra-manager` agent orchestrates workflow
- Has full tool access (Bash, Skill, Read, Write, AskUserQuestion)
- Skills do execution work only
- Director routes to Manager agent

---

## Detection: Is Your Manager a Skill?

### Checklist

Run through these questions:

1. **Is it in `skills/` directory?**
   - If YES and has orchestration → INVERSION

2. **Does it have `<WORKFLOW>` section with phases?**
   - If YES → Should be Agent

3. **Does it coordinate other skills?**
   - If YES → Should be Agent

4. **Does it need to ask user questions?**
   - If YES → Must be Agent (Skills can't use AskUserQuestion)

5. **Does it manage state across phases?**
   - If YES → Should be Agent

6. **Does it have decision logic?**
   - If YES → Should be Agent

### Automated Detection

Use the workflow-validator:

```bash
/fractary-faber-agent:audit

# Output will show:
# ❌ Manager-as-Skill Inversion Detected:
#    - skills/workflow-orchestrator/SKILL.md
#      - Location: Should be in agents/ directory
#      - Has <WORKFLOW> section (orchestration anti-pattern)
#      - Has Phase 1-7 structure
```

### Manual Detection Patterns

**Pattern 1: Skill file with <WORKFLOW> section**

```markdown
---
skill: my-orchestrator  ❌ "orchestrator" in skill
---

<WORKFLOW>              ❌ Workflow in skill
Phase 1: GATHER
Phase 2: ANALYZE
...
```

**Pattern 2: Skill invoking other skills**

```markdown
## orchestrate-deployment

1. Use @skill-infra-deployer    ❌ Skill orchestrating skills
2. Use @skill-app-deployer
3. Use @skill-monitor
```

**Pattern 3: Skill with user interaction needs**

```markdown
## execute-workflow

1. Show results to user
2. Ask for approval          ❌ Skill needs AskUserQuestion
3. If approved, proceed
```

---

## Fix Process

### Step 1: Create Manager Agent File

**Move from:**
```
skills/workflow-orchestrator/SKILL.md
```

**To:**
```
agents/workflow-orchestrator.md
```

### Step 2: Convert Skill to Agent

**Before (Skill):**
```markdown
---
skill: workflow-orchestrator
purpose: Orchestrate complete workflow
---

<CONTEXT>
You orchestrate workflow phases.
</CONTEXT>

<WORKFLOW>
Phase 1: GATHER
Phase 2: ANALYZE
...
</WORKFLOW>
```

**After (Agent):**
```markdown
---
name: workflow-orchestrator
description: Orchestrates complete workflow across phases
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
model: inherit
---

<CONTEXT>
You are a Manager Agent orchestrating complete workflows.

You coordinate execution skills to complete workflows.
You manage state across phases.
You interact with users for approvals.
</CONTEXT>

<CRITICAL_RULES>
1. **Full Orchestration**
   - YOU own the complete workflow
   - YOU manage state across phases
   - YOU handle errors and rollback

2. **Delegate Execution**
   - NEVER do work directly
   - ALWAYS invoke skills for execution
   - Skills return results to YOU

3. **User Approval**
   - ALWAYS present critical results before proceeding
   - ALWAYS use AskUserQuestion for decisions
   - NEVER proceed without approval on critical steps
</CRITICAL_RULES>

<WORKFLOW>
Phase 1: GATHER
Phase 2: ANALYZE
Phase 3: PRESENT
Phase 4: APPROVE
Phase 5: EXECUTE
Phase 6: VERIFY
Phase 7: REPORT
</WORKFLOW>
```

**Key changes:**
- ✓ `skill:` → `name:`
- ✓ `purpose:` → `description:`
- ✓ Added `tools:` with all 7 tools
- ✓ Added `model: inherit`
- ✓ Added <CRITICAL_RULES> section
- ✓ Enhanced <CONTEXT> with Agent role

### Step 3: Add Tool Access

Manager Agents **MUST** have all 7 tools:

```yaml
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
```

**Why each tool:**
- `Bash`: Execute git, gh, infrastructure commands
- `Skill`: Invoke execution skills
- `Read`: Read configuration, state files
- `Write`: Write state, reports
- `Glob`: Find files by pattern
- `Grep`: Search for content
- `AskUserQuestion`: User approval gates

**Don't limit tools** (common mistake):
```yaml
# ❌ Wrong - limiting tools
tools: Skill  # Only Skill? Can't ask user questions!

# ✓ Correct - all tools
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
```

### Step 4: Add State Management

Agents manage state across phases:

```markdown
<WORKFLOW>

## Phase 1: GATHER

Use @skill-data-fetcher:
```json
{
  "operation": "fetch-data",
  "parameters": {"source": "api"}
}
```

Store result in state:
```json
{
  "state": {
    "phase": "gather",
    "data": {
      "record_count": 1000,
      "data_file": "/tmp/data.json"
    }
  }
}
```

## Phase 2: ANALYZE

Use @skill-data-analyzer with data from Phase 1:
```json
{
  "operation": "analyze-data",
  "parameters": {
    "data_file": "{{state.data.data_file}}"  ← Using state
  }
}
```

Store analysis result:
```json
{
  "state": {
    "phase": "analyze",
    "analysis": {
      "issues_found": 5,
      "severity": "medium"
    }
  }
}
```

## Phase 4: APPROVE

Use AskUserQuestion with analysis results:
```json
{
  "questions": [{
    "question": "Found {{state.analysis.issues_found}} issues. Proceed?",
    "header": "Approval",
    "options": [...]
  }]
}
```
</WORKFLOW>
```

### Step 5: Add User Approval Gates

Agents use AskUserQuestion for critical decisions:

```markdown
## Phase 4: APPROVE (Get User Decision)

Present results from Phase 2 and 3.

Use AskUserQuestion:

```json
{
  "questions": [{
    "question": "Analysis complete. Found 5 medium-severity issues. Proceed with fixes?",
    "header": "Approval",
    "multiSelect": false,
    "options": [
      {
        "label": "Yes, proceed with fixes",
        "description": "Apply recommended fixes automatically"
      },
      {
        "label": "No, review manually",
        "description": "Stop for manual review"
      },
      {
        "label": "Cancel workflow",
        "description": "Abort the workflow"
      }
    ]
  }]
}
```

Store decision:
```json
{
  "state": {
    "approval": {
      "decision": "proceed",
      "timestamp": "2025-01-11T16:30:00Z"
    }
  }
}
```

If user cancels → ABORT workflow

## Phase 5: EXECUTE (Only if approved)
...
```

### Step 6: Update Director (If Exists)

If you have a Director that was routing to the Skill, update it to route to the Agent:

**Before:**
```markdown
---
skill: my-director  ❌ Director was also a skill
---

## expand-to-batch

Route to @skill-workflow-orchestrator  ❌ Routing to skill
```

**After:**
```markdown
---
skill: my-director  ✓ Director stays as skill
purpose: Expand patterns and route to manager
---

## expand-to-batch

Calculate batch parameters.

Route to @agent-my-plugin:workflow-orchestrator  ✓ Routing to agent

Returns batch parameters:
```json
{
  "batch_items": [...],
  "parallelism": 3
}
```
```

### Step 7: Move Supporting Files

If the skill had workflow files, keep them with the Agent:

**Before:**
```
skills/workflow-orchestrator/
├── SKILL.md
└── workflow/
    ├── basic.md
    └── advanced.md
```

**After:**
```
agents/workflow-orchestrator.md    ← Main agent file
skills/workflow-orchestrator/      ← Supporting workflows
└── workflow/
    ├── basic.md
    └── advanced.md
```

Agent reads workflow files:
```markdown
<WORKFLOW>

Read workflow steps from `skills/workflow-orchestrator/workflow/{{WORKFLOW_TYPE}}.md`

Execute each phase as defined in workflow file.

Default workflow: `skills/workflow-orchestrator/workflow/basic.md`
</WORKFLOW>
```

---

## Complete Example: Before & After

### Before (Manager-as-Skill)

**Directory structure:**
```
plugins/my-plugin/
├── agents/
│   └── my-director.md         # Just routes to skill
└── skills/
    └── my-manager/            ❌ Manager as Skill
        ├── SKILL.md           # Orchestration here
        └── workflow/
            └── deploy.md      # 7-phase workflow
```

**skills/my-manager/SKILL.md:**
```markdown
---
skill: my-manager
purpose: Manage deployment workflow
---

<WORKFLOW>

## Phase 1: PREPARE
Use @skill-preparer

## Phase 2: VALIDATE
Use @skill-validator

## Phase 3: PRESENT
Show validation results       ❌ Can't interact with user

## Phase 4: APPROVE
Ask user for approval          ❌ No AskUserQuestion tool

## Phase 5: DEPLOY
Use @skill-deployer

## Phase 6: VERIFY
Use @skill-verifier

## Phase 7: REPORT
Generate report
</WORKFLOW>
```

**Problems:**
- ❌ Can't ask user questions (Phase 4 doesn't work)
- ❌ Can't manage state properly
- ❌ Orchestration in skill file (wrong pattern)
- ❌ Poor context efficiency (re-reading workflow each phase)

### After (Manager-as-Agent)

**Directory structure:**
```
plugins/my-plugin/
├── agents/
│   ├── my-director.md         # Routes to manager
│   └── my-manager.md          ✓ Manager as Agent
└── skills/
    ├── preparer/              ✓ Execution skill
    ├── validator/             ✓ Execution skill
    ├── deployer/              ✓ Execution skill
    └── verifier/              ✓ Execution skill
```

**agents/my-manager.md:**
```markdown
---
name: my-manager
description: Orchestrates deployment workflow
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
model: inherit
---

<CONTEXT>
You are a Manager Agent orchestrating deployment workflows.
</CONTEXT>

<CRITICAL_RULES>
1. **Full Orchestration** - YOU own the complete workflow
2. **Delegate Execution** - ALWAYS invoke skills for work
3. **User Approval** - ALWAYS use AskUserQuestion for critical decisions
</CRITICAL_RULES>

<WORKFLOW>

## Phase 1: PREPARE
Use @skill-my-plugin:preparer

Store state:
```json
{
  "state": {
    "phase": "prepare",
    "preparation": {{skill_result}}
  }
}
```

## Phase 2: VALIDATE
Use @skill-my-plugin:validator with preparation results

Store state:
```json
{
  "state": {
    "phase": "validate",
    "validation": {{skill_result}}
  }
}
```

## Phase 3: PRESENT
Present validation results to user:

```
✓ Preparation complete
✓ Validation passed
Ready for deployment
```

## Phase 4: APPROVE
Use AskUserQuestion:              ✓ Has tool access

```json
{
  "questions": [{
    "question": "Validation passed. Proceed with deployment?",
    "header": "Deploy",
    "options": [...]
  }]
}
```

Store decision in state.

If cancelled → ABORT

## Phase 5: DEPLOY
Use @skill-my-plugin:deployer

Store deployment state.

## Phase 6: VERIFY
Use @skill-my-plugin:verifier

## Phase 7: REPORT
Generate final report using state from all phases.
</WORKFLOW>
```

**Improvements:**
- ✓ Full tool access (can ask questions)
- ✓ State management across phases
- ✓ Proper Agent architecture
- ✓ Better context efficiency
- ✓ Clear separation (Agent orchestrates, Skills execute)

---

## Migration Checklist

### Pre-Migration

- [ ] Run `/fractary-faber-agent:audit` to detect inversions
- [ ] Identify all Manager-as-Skill instances
- [ ] Document current workflow and dependencies
- [ ] Identify user interaction points
- [ ] Map state flow across phases

### Conversion

- [ ] Create Agent file in `agents/` directory
- [ ] Convert skill header to agent header
- [ ] Add all 7 tools to frontmatter
- [ ] Add <CRITICAL_RULES> section
- [ ] Add state management to workflow phases
- [ ] Add user approval gates with AskUserQuestion
- [ ] Move skill file from `skills/` to `agents/`
- [ ] Update Director to route to Agent (not Skill)

### Validation

- [ ] Run `manager-agent-validator.sh` on new Agent
- [ ] Verify Agent is in `agents/` directory
- [ ] Verify Agent has all 7 tools
- [ ] Verify <WORKFLOW> section exists
- [ ] Verify <CRITICAL_RULES> section exists
- [ ] Test user approval gates
- [ ] Test state management across phases

### Testing

- [ ] Test complete workflow end-to-end
- [ ] Test user approval (accept path)
- [ ] Test user cancellation (abort path)
- [ ] Test error handling
- [ ] Verify state persists across phases
- [ ] Test skill coordination

---

## Common Mistakes

### Mistake 1: Partial Conversion

**Wrong:**
```yaml
---
name: my-manager       ✓ Correct name
tools: Skill           ❌ Missing other tools
---
```

**Correct:**
```yaml
---
name: my-manager
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
---
```

### Mistake 2: Leaving in Skills Directory

**Wrong:**
```
skills/my-manager.md   ❌ Agent in skills/
```

**Correct:**
```
agents/my-manager.md   ✓ Agent in agents/
```

### Mistake 3: Not Adding User Approval

**Wrong:**
```markdown
## Phase 4: APPROVE
Proceed with deployment  ❌ Auto-proceeding
```

**Correct:**
```markdown
## Phase 4: APPROVE
Use AskUserQuestion to get user approval  ✓ User decision
```

### Mistake 4: Director Still Routing to Skill

**Wrong (after fix):**
```markdown
Route to @skill-my-manager  ❌ Still treating as skill
```

**Correct:**
```markdown
Route to @agent-my-plugin:my-manager  ✓ Routing to agent
```

---

## Validation Scripts

### Check for Inversions

```bash
# Find skills with orchestration patterns
find plugins/*/skills -name "SKILL.md" -exec grep -l "<WORKFLOW>" {} \;

# Check for Phase patterns in skills
find plugins/*/skills -name "SKILL.md" -exec grep -l "Phase [0-9]:" {} \;

# Find skills coordinating other skills
find plugins/*/skills -name "SKILL.md" -exec grep -l "@skill-" {} \;
```

### Validate Fixed Managers

```bash
# Run validator on all agents
for agent in plugins/*/agents/*.md; do
  ./skills/workflow-validator/scripts/manager-agent-validator.sh "$agent"
done

# Check tool access
grep -r "^tools:" plugins/*/agents/*.md | grep -v "Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion"
```

---

## Results

**Pattern Compliance**: Manager-as-Agent pattern enforced
**Tool Access**: Full orchestration capabilities
**User Interaction**: Approval gates work correctly
**State Management**: Proper state persistence
**Context Efficiency**: Better separation of concerns

---

## Next Steps

After fixing Manager-as-Skill inversions:

1. Run `/fractary-faber-agent:audit` to verify no inversions remain
2. Test all converted managers end-to-end
3. Update documentation with new agent locations
4. Review [Agent Chain Migration](agent-chain-to-skills.md) for related patterns
5. Review [Hybrid Agent Splitting](hybrid-agent-splitting.md) if needed
