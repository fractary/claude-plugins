# Example: Converting Manager-as-Skill to Manager-as-Agent

## Overview

This example demonstrates detecting and fixing a Manager-as-Skill inversion using the audit and conversion system.

---

## Problem: Manager-as-Skill Inversion

### Initial Structure (Anti-pattern)

```
plugins/my-plugin/
├── agents/
│   └── deployment-director.md         # Just routes to skill
└── skills/
    └── deployment-manager/            # ❌ Manager as Skill (WRONG)
        ├── SKILL.md                   # Has orchestration logic
        └── workflow/
            └── deploy.md              # 7-phase workflow
```

**skills/deployment-manager/SKILL.md:**
```markdown
---
skill: deployment-manager
purpose: Manage deployment workflow
---

<WORKFLOW>

## Phase 1: PREPARE
Use @skill-infra-preparer

## Phase 2: VALIDATE
Use @skill-infra-validator

## Phase 3: PRESENT
Show validation results      # ❌ Can't show to user (no tools)

## Phase 4: APPROVE
Ask user for approval         # ❌ Can't ask (no AskUserQuestion)

## Phase 5: DEPLOY
Use @skill-infra-deployer

## Phase 6: VERIFY
Use @skill-deployment-verifier

## Phase 7: REPORT
Generate report
</WORKFLOW>
```

**Problems:**
- ❌ Orchestration in Skill (should be Agent)
- ❌ Can't ask user questions (no AskUserQuestion tool)
- ❌ Can't manage state properly (limited tool access)
- ❌ 7-phase workflow in Skill file (Agent pattern)

---

## Step 1: Run Audit

```bash
/fractary-faber-agent:audit /plugins/my-plugin
```

**Output:**
```
🔍 FABER Agent Audit Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plugin: my-plugin
Path: /plugins/my-plugin
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

❌ Critical Issues (1):

1. Manager-as-Skill Inversion
   File: skills/deployment-manager/SKILL.md

   Evidence:
     ✗ Location: skills/ directory (should be agents/)
     ✗ Has <WORKFLOW> section with 7 phases
     ✗ Coordinates 4 other skills
     ✗ Needs AskUserQuestion (Phase 4) but skills can't use it

   Impact:
     - Cannot ask user questions (functionality broken)
     - Poor context efficiency
     - Wrong architectural pattern

   Estimated context waste: ~5K tokens

   Recommended fix:
     - Move to agents/deployment-manager.md
     - Add full tool access (7 tools)
     - Add state management
     - Add user approval gates

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Conversion Specification Generated:
  /tmp/conversion-specs/manager-inversion-fix-deployment-20250111.json

Next: Review conversion spec with:
  /fractary-faber-agent:review-conversion <spec-file>
```

---

## Step 2: Review Conversion Spec

```bash
/fractary-faber-agent:review-conversion /tmp/conversion-specs/manager-inversion-fix-deployment-20250111.json
```

**Output:**
```
📋 Conversion Specification Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ID: conv-20250111-001
Type: Manager-as-Skill Inversion
Severity: Critical

📁 Affected Files (3):
  - skills/deployment-manager/SKILL.md (delete)
  - agents/deployment-manager.md (create)
  - agents/deployment-director.md (modify)

🔧 Conversion Plan (3 steps):

  Step 1: Create agents/deployment-manager.md
    Reason: Convert orchestrator from Skill to Agent
    Template: manager-agent-7-phase.md.template

    Changes:
      - Add frontmatter with all 7 tools:
        tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
      - Add <CRITICAL_RULES> section
      - Add state management to workflow
      - Add user approval gates (Phase 4)

    Preview:
    ---
    name: deployment-manager
    description: Orchestrates deployment workflow
    tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
    model: inherit
    ---

    <CONTEXT>
    You are a Manager Agent orchestrating deployment workflows.
    </CONTEXT>

    <CRITICAL_RULES>
    1. **Full Orchestration** - YOU own the complete workflow
    2. **Delegate Execution** - ALWAYS invoke skills
    3. **User Approval** - ALWAYS use AskUserQuestion
    </CRITICAL_RULES>
    ...

  Step 2: Modify agents/deployment-director.md
    Line 45:
      - Route to @skill-deployment-manager
      + Route to @agent-my-plugin:deployment-manager

    Reason: Update routing to use Agent instead of Skill

  Step 3: Delete skills/deployment-manager/SKILL.md
    Reason: Moved to agents/ directory
    Backup: Yes → .backup/skills/deployment-manager/SKILL.md.20250111

📊 Estimated Impact:
  - Context reduction: ~5K tokens (60% reduction)
  - Files affected: 3
  - New capabilities:
    * User approval gates (AskUserQuestion works)
    * Proper state management
    * Full tool access for orchestration

⚠ Manual Review Required:
  - Verify state management strategy
  - Review user approval gate placement
  - Check skill delegation is correct

✅ Testing Required:
  - Test workflow end-to-end
  - Verify user approval flow works
  - Test error handling

📖 Migration Guide: docs/migration/manager-inversion-fix.md

Next: Apply conversion with:
  /fractary-faber-agent:apply-conversion <spec-file>
```

---

## Step 3: Apply Conversion

```bash
/fractary-faber-agent:apply-conversion /tmp/conversion-specs/manager-inversion-fix-deployment-20250111.json
```

**Interactive execution:**
```
📋 Applying Conversion: Manager-as-Skill Inversion Fix
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1/3: Create agents/deployment-manager.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Generating from template: manager-agent-7-phase.md.template

Parameters:
  MANAGER_NAME: deployment-manager
  MANAGER_DESCRIPTION: Orchestrates deployment workflow
  PHASE_COUNT: 7
  SKILLS: [infra-preparer, infra-validator, infra-deployer, deployment-verifier]

Preview (first 20 lines):
───────────────────────────────────────────────
---
name: deployment-manager
description: Orchestrates deployment workflow
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
model: inherit
---

<CONTEXT>
You are a Manager Agent orchestrating deployment workflows.

You coordinate:
- Infrastructure preparation (infra-preparer skill)
- Infrastructure validation (infra-validator skill)
- Deployment execution (infra-deployer skill)
- Deployment verification (deployment-verifier skill)
</CONTEXT>

<CRITICAL_RULES>
1. **Full Orchestration**
   - YOU own the complete workflow
───────────────────────────────────────────────

? Proceed with this step? (Y/n) y

✓ Created agents/deployment-manager.md (342 lines)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 2/3: Modify agents/deployment-director.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Changes to apply:

Line 45:
  - Route to @skill-deployment-manager
  + Route to @agent-my-plugin:deployment-manager

Context (lines 42-48):
───────────────────────────────────────────────
42 | ## expand-to-batch
43 |
44 | Calculate batch parameters.
45 | Route to @skill-deployment-manager
46 |
47 | Returns batch parameters for parallel deployment.
48 | ```json
───────────────────────────────────────────────

After change:
───────────────────────────────────────────────
42 | ## expand-to-batch
43 |
44 | Calculate batch parameters.
45 | Route to @agent-my-plugin:deployment-manager
46 |
47 | Returns batch parameters for parallel deployment.
48 | ```json
───────────────────────────────────────────────

? Proceed with this step? (Y/n) y

✓ Modified agents/deployment-director.md (1 change)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 3/3: Delete skills/deployment-manager/SKILL.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

File to delete: skills/deployment-manager/SKILL.md
Backup: Yes
Backup location: .backup/skills/deployment-manager/SKILL.md.20250111

? Proceed with deletion? (Y/n) y

✓ Backed up to .backup/skills/deployment-manager/SKILL.md.20250111
✓ Deleted skills/deployment-manager/SKILL.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Conversion Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Files modified: 3
  ✓ Created: agents/deployment-manager.md (342 lines)
  ✓ Modified: agents/deployment-director.md (1 change)
  ✓ Deleted: skills/deployment-manager/SKILL.md (backed up)

Next steps:
  1. Review generated agent file
  2. Customize workflow phases if needed
  3. Test workflow end-to-end
  4. Run audit again to verify fix:
     /fractary-faber-agent:audit /plugins/my-plugin
```

---

## Step 4: Verify Fix

```bash
/fractary-faber-agent:audit /plugins/my-plugin
```

**Output:**
```
🔍 FABER Agent Audit Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plugin: my-plugin
Path: /plugins/my-plugin
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Summary:
  Total components: 12
  Issues found: 0
  Conversion specs: 0

✅ No issues found!

All components follow Manager-as-Agent pattern:
  ✓ agents/deployment-manager.md (Manager as Agent)
  ✓ agents/deployment-director.md (Director as Skill)
  ✓ skills/infra-preparer/ (Specialist skill)
  ✓ skills/infra-validator/ (Specialist skill)
  ✓ skills/infra-deployer/ (Specialist skill)
  ✓ skills/deployment-verifier/ (Specialist skill)

Pattern compliance: 100%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## After: Corrected Structure

```
plugins/my-plugin/
├── agents/
│   ├── deployment-director.md         # Routes to Manager agent
│   └── deployment-manager.md          # ✓ Manager as Agent (CORRECT)
└── skills/
    ├── infra-preparer/                # Specialist skill
    ├── infra-validator/               # Specialist skill
    ├── infra-deployer/                # Specialist skill
    └── deployment-verifier/           # Specialist skill
```

**agents/deployment-manager.md:**
```markdown
---
name: deployment-manager
description: Orchestrates deployment workflow
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
model: inherit
---

<CONTEXT>
You are a Manager Agent orchestrating deployment workflows.
</CONTEXT>

<CRITICAL_RULES>
1. **Full Orchestration** - YOU own the complete workflow
2. **Delegate Execution** - ALWAYS invoke skills
3. **User Approval** - ALWAYS use AskUserQuestion
</CRITICAL_RULES>

<WORKFLOW>

## Phase 1: PREPARE
Use @skill-my-plugin:infra-preparer

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
Use @skill-my-plugin:infra-validator

## Phase 3: PRESENT
Present validation results to user:
```
✓ Infrastructure validated
Ready for deployment
```

## Phase 4: APPROVE
Use AskUserQuestion:             # ✓ Now works! Has AskUserQuestion tool

```json
{
  "questions": [{
    "question": "Validation passed. Proceed with deployment?",
    "header": "Deploy",
    "options": [...]
  }]
}
```

## Phase 5: DEPLOY
Use @skill-my-plugin:infra-deployer

## Phase 6: VERIFY
Use @skill-my-plugin:deployment-verifier

## Phase 7: REPORT
Generate final report
</WORKFLOW>
```

**Improvements:**
- ✓ Full tool access (can ask user questions)
- ✓ Proper state management
- ✓ Correct Agent architecture
- ✓ User approval gates work
- ✓ Better context efficiency

---

## Testing the Fix

### Test 1: User Approval Flow

```bash
/my-plugin:deploy infra-config.yaml
```

**Expected flow:**
```
Phase 1: Prepare infrastructure
  ✓ Preparation complete

Phase 2: Validate configuration
  ✓ Validation passed

Phase 3: Present results
  ━━━━━━━━━━━━━━━━━━━━━━
  ✓ Infrastructure: Ready
  ✓ Configuration: Valid
  ━━━━━━━━━━━━━━━━━━━━━━

Phase 4: Approve deployment
  ? Proceed with deployment? (Y/n)    ← Works now!

  User: Y

Phase 5: Deploy infrastructure
  ✓ Deployment in progress...
  ✓ Resources created

Phase 6: Verify deployment
  ✓ All services healthy

Phase 7: Report
  ✅ Deployment complete
```

### Test 2: User Cancellation

```bash
/my-plugin:deploy risky-config.yaml
```

**Expected flow:**
```
Phase 4: Approve deployment
  ? Proceed with production deployment? (Y/n)

  User: n                              ← User declines

Phase 7: Report
  ⚠ Deployment cancelled by user
  No changes made
```

**Before fix:** Would crash at Phase 4 (no AskUserQuestion tool)
**After fix:** Works correctly, respects user decision

---

## Results

**Context efficiency:**
- Before: ~12K tokens (orchestration in skill)
- After: ~7K tokens (agent + skills)
- **Savings: ~5K tokens (42% reduction)**

**New capabilities:**
- ✓ User approval gates functional
- ✓ Proper state management
- ✓ Full tool access for orchestration
- ✓ Complies with Manager-as-Agent pattern

**Time to fix:**
- Audit: 30 seconds
- Review spec: 2 minutes
- Apply conversion: 5 minutes
- Verify fix: 30 seconds
- **Total: ~8 minutes**

---

## Rollback (If Needed)

If conversion causes issues, rollback:

```bash
# Restore original skill
cp .backup/skills/deployment-manager/SKILL.md.20250111 skills/deployment-manager/SKILL.md

# Delete agent
rm agents/deployment-manager.md

# Revert director routing
git checkout agents/deployment-director.md
```

Or use spec rollback:

```bash
/fractary-faber-agent:rollback-conversion /tmp/conversion-specs/manager-inversion-fix-deployment-20250111.json
```

---

## Key Takeaways

1. **Audit detects anti-patterns automatically**
   - Manager-as-Skill inversion found in seconds
   - Evidence and impact clearly shown

2. **Conversion specs provide clear fix plan**
   - Step-by-step instructions
   - Preview before applying
   - Backup before deletion

3. **Interactive application with safety**
   - Review each step
   - Approve/skip individually
   - Can abort at any step

4. **Verification ensures fix worked**
   - Re-run audit after fix
   - Should show 0 issues
   - Test workflow end-to-end

5. **Rollback available if needed**
   - Backups created automatically
   - Can restore original state
   - No permanent damage
