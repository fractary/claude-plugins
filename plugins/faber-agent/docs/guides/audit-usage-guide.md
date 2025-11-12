# Audit System Usage Guide

## Overview

The FABER Agent audit system detects architectural anti-patterns in plugins and generates conversion specifications to fix them. This guide shows how to use the audit system to improve plugin architecture.

---

## Quick Start

### Run an Audit

```bash
/fractary-faber-agent:audit /path/to/plugin
```

**Example output:**
```
🔍 FABER Agent Audit Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plugin: fractary-my-plugin
Path: /plugins/my-plugin
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Summary:
  Total components: 12
  Issues found: 4 critical, 2 warnings
  Conversion specs: 3 generated

❌ Critical Issues (4):
  1. Manager-as-Skill Inversion
     - skills/deployment-orchestrator/SKILL.md
     - Has <WORKFLOW> with 7 phases
     - Should be Agent, not Skill

  2. Agent Chain Detected
     - agents/data-fetcher.md → agents/data-processor.md
     - Sequential agent invocations
     - Should use Manager + Skills pattern

  3. Hybrid Agent
     - agents/deployment-manager.md
     - Mixes orchestration with execution
     - Should delegate all execution to skills

  4. Script Logic in Agent
     - agents/build-manager.md
     - Contains 15 bash commands
     - Should extract to skill scripts

⚠ Warnings (2):
  1. Missing State Management
     - agents/workflow-manager.md
     - No state persistence across phases

  2. No User Approval Gates
     - agents/deployment-manager.md
     - Proceeds with deployment without approval

📋 Conversion Specifications Generated:
  - /tmp/conversion-specs/manager-inversion-fix-20250111.json
  - /tmp/conversion-specs/agent-chain-refactor-20250111.json
  - /tmp/conversion-specs/hybrid-split-20250111.json

Next: Review conversion specs with:
  /fractary-faber-agent:review-conversion <spec-file>
```

---

## Audit Command Reference

### Basic Audit

```bash
/fractary-faber-agent:audit <plugin-path>
```

Audits a single plugin for anti-patterns.

**Example:**
```bash
/fractary-faber-agent:audit /plugins/my-plugin
```

### Audit with Options

```bash
/fractary-faber-agent:audit <plugin-path> [options]
```

**Options:**

#### `--severity <level>`

Filter by severity level:
- `critical`: Only critical issues
- `warning`: Critical + warnings
- `all`: All issues including suggestions (default)

**Example:**
```bash
/fractary-faber-agent:audit /plugins/my-plugin --severity critical
```

#### `--pattern <pattern>`

Filter by specific anti-pattern:
- `manager-as-skill`: Manager-as-Skill inversions
- `agent-chain`: Agent chain patterns
- `hybrid-agent`: Hybrid agents
- `inline-scripts`: Inline bash in agents/skills

**Example:**
```bash
/fractary-faber-agent:audit /plugins/my-plugin --pattern manager-as-skill
```

#### `--output <format>`

Output format:
- `text`: Human-readable text (default)
- `json`: Structured JSON
- `markdown`: Markdown report

**Example:**
```bash
/fractary-faber-agent:audit /plugins/my-plugin --output json > audit-report.json
```

#### `--generate-specs`

Automatically generate conversion specifications:

**Example:**
```bash
/fractary-faber-agent:audit /plugins/my-plugin --generate-specs
```

**Generates:**
- One spec per anti-pattern detected
- Saved to `/tmp/conversion-specs/`
- Ready for review and execution

---

## Anti-Pattern Detection

### 1. Manager-as-Skill Inversion

**What it detects:**
- Orchestration logic in skills/ directory
- Skills with <WORKFLOW> sections
- Skills with Phase 1-7 structure
- Skills coordinating other skills

**Example detection:**
```
❌ Manager-as-Skill Inversion Detected

File: skills/deployment-orchestrator/SKILL.md

Evidence:
  ✗ Location: skills/ directory (should be agents/)
  ✗ Has <WORKFLOW> section
  ✗ Has 7 phases (Phase 1: PREPARE ... Phase 7: REPORT)
  ✗ Coordinates 4 other skills
  ✗ Needs AskUserQuestion (but skills can't use it)

Impact:
  - Cannot ask user questions (missing tool)
  - Poor context efficiency
  - Wrong architectural pattern

Recommended fix:
  - Move to agents/deployment-orchestrator.md
  - Add full tool access (7 tools)
  - Add state management
  - Add user approval gates

Conversion spec: manager-inversion-fix-deployment-20250111.json
```

**Migration guide:** [Manager Inversion Fix](../migration/manager-inversion-fix.md)

### 2. Agent Chain

**What it detects:**
- Sequential agent invocations (Agent A → B → C)
- Agents invoking other agents
- Context accumulation across agents
- State passed between agents

**Example detection:**
```
❌ Agent Chain Detected

Chain:
  agents/data-fetcher.md
    └→ agents/data-validator.md
         └→ agents/data-processor.md

Evidence:
  ✗ data-fetcher invokes data-validator (line 45)
  ✗ data-validator invokes data-processor (line 78)
  ✗ Sequential invocations (not parallel)
  ✗ Each agent duplicates context

Impact:
  - Context accumulation: ~60K tokens (should be ~15K)
  - Complex state management
  - Difficult error recovery

Recommended fix:
  - Create data-processing-manager agent
  - Convert 3 agents to skills
  - Manager orchestrates skills
  - Extract bash to skill scripts

Estimated savings: ~45K tokens (75% reduction)

Conversion spec: agent-chain-refactor-data-20250111.json
```

**Migration guide:** [Agent Chain to Skills](../migration/agent-chain-to-skills.md)

### 3. Hybrid Agent

**What it detects:**
- Agents doing execution work directly
- Bash commands in agent files
- Read/Write operations (not for config/state)
- Data transformations in agents
- Parsing output in agents

**Example detection:**
```
❌ Hybrid Agent Detected

File: agents/deployment-manager.md

Evidence:
  ✗ Contains 15 bash commands
  ✗ Reads/writes files directly (8 operations)
  ✗ Parses JSON output inline
  ✗ Transforms data in agent context
  ✗ Mixed orchestration and execution

Execution ratio: 65% execution, 35% orchestration

Impact:
  - ~8K tokens for execution logic (should be 0)
  - Not reusable across workflows
  - Hard to test execution independently

Recommended fix:
  - Extract bash to skill scripts
  - Create execution skills:
    * infra-deployer skill
    * app-deployer skill
    * deployment-verifier skill
  - Agent delegates all execution

Estimated savings: ~6K tokens (75% reduction)

Conversion spec: hybrid-split-deployment-20250111.json
```

**Migration guide:** [Hybrid Agent Splitting](../migration/hybrid-agent-splitting.md)

### 4. Inline Scripts

**What it detects:**
- Bash commands in markdown (not scripts/)
- Data processing logic in agent/skill files
- Deterministic operations in LLM context

**Example detection:**
```
⚠ Inline Scripts Detected

File: skills/data-processor/SKILL.md

Evidence:
  ⚠ 12 bash commands inline (lines: 23, 34, 45, ...)
  ⚠ No scripts/ directory
  ⚠ Operations implemented in markdown

Impact:
  - ~2K tokens for bash logic (should be 0)
  - Not independently testable
  - No error handling

Recommended fix:
  - Create scripts/ directory
  - Extract operations to scripts:
    * scripts/process-data.sh
    * scripts/validate-output.sh
  - Skill invokes scripts
  - Scripts return structured JSON

Estimated savings: ~1.5K tokens (75% reduction)

Conversion spec: script-extraction-data-processor-20250111.json
```

**Migration guide:** [Script Extraction](../migration/script-extraction.md)

---

## Conversion Specifications

### What is a Conversion Spec?

A conversion specification is a JSON file describing:
- What anti-pattern was detected
- Which files are affected
- How to fix it (step-by-step)
- What files to create/modify/delete
- Expected results after conversion

### Spec Structure

```json
{
  "conversion_id": "conv-20250111-001",
  "type": "manager-as-skill-inversion",
  "severity": "critical",
  "plugin": "fractary-my-plugin",
  "detected_at": "2025-01-11T16:30:00Z",
  "affected_files": [
    "skills/deployment-orchestrator/SKILL.md",
    "agents/deployment-director.md"
  ],
  "conversion_plan": {
    "steps": [
      {
        "step": 1,
        "action": "create",
        "file": "agents/deployment-orchestrator.md",
        "reason": "Convert orchestrator from Skill to Agent"
      },
      {
        "step": 2,
        "action": "modify",
        "file": "agents/deployment-director.md",
        "changes": "Update routing to use agent not skill"
      },
      {
        "step": 3,
        "action": "delete",
        "file": "skills/deployment-orchestrator/SKILL.md",
        "reason": "Moved to agents/"
      }
    ]
  },
  "estimated_impact": {
    "context_reduction": "~5K tokens",
    "files_affected": 3,
    "new_capabilities": [
      "User approval gates (AskUserQuestion)",
      "Proper state management",
      "Full tool access"
    ]
  },
  "migration_guide": "docs/migration/manager-inversion-fix.md"
}
```

### Review a Conversion Spec

```bash
/fractary-faber-agent:review-conversion /tmp/conversion-specs/manager-inversion-fix-20250111.json
```

**Output:**
```
📋 Conversion Specification Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ID: conv-20250111-001
Type: Manager-as-Skill Inversion
Severity: Critical

📁 Affected Files (3):
  - skills/deployment-orchestrator/SKILL.md (delete)
  - agents/deployment-orchestrator.md (create)
  - agents/deployment-director.md (modify)

🔧 Conversion Plan (3 steps):

  Step 1: Create agents/deployment-orchestrator.md
    Reason: Convert orchestrator from Skill to Agent
    Template: manager-agent-7-phase.md.template
    Changes:
      - Add frontmatter with all 7 tools
      - Add <CRITICAL_RULES> section
      - Add state management
      - Add user approval gates

  Step 2: Modify agents/deployment-director.md
    Line 45: Route to @skill-deployment-orchestrator
    Change to: Route to @agent-my-plugin:deployment-orchestrator

  Step 3: Delete skills/deployment-orchestrator/SKILL.md
    Reason: Moved to agents/

📊 Estimated Impact:
  - Context reduction: ~5K tokens
  - New capabilities: User approval gates, State management
  - Files affected: 3

Next: Apply conversion with:
  /fractary-faber-agent:apply-conversion <spec-file>
```

### Apply a Conversion

```bash
/fractary-faber-agent:apply-conversion /tmp/conversion-specs/manager-inversion-fix-20250111.json
```

**Interactive mode:**
```
📋 Applying Conversion: Manager-as-Skill Inversion Fix
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1/3: Create agents/deployment-orchestrator.md

Preview:
---
name: deployment-orchestrator
description: Orchestrates deployment workflow
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
model: inherit
---
...

? Proceed with this step? (Y/n) y

✓ Created agents/deployment-orchestrator.md

Step 2/3: Modify agents/deployment-director.md

Changes:
  Line 45:
    - Route to @skill-deployment-orchestrator
    + Route to @agent-my-plugin:deployment-orchestrator

? Proceed with this step? (Y/n) y

✓ Modified agents/deployment-director.md

Step 3/3: Delete skills/deployment-orchestrator/SKILL.md

? Proceed with deletion? (Y/n) y

✓ Deleted skills/deployment-orchestrator/SKILL.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Conversion Complete!

Files modified: 3
  - Created: agents/deployment-orchestrator.md
  - Modified: agents/deployment-director.md
  - Deleted: skills/deployment-orchestrator/SKILL.md

Next steps:
  1. Review generated agent file
  2. Test workflow end-to-end
  3. Run audit again to verify fix:
     /fractary-faber-agent:audit /plugins/my-plugin
```

---

## Batch Auditing

### Audit Multiple Plugins

```bash
/fractary-faber-agent:audit-all
```

Audits all plugins in the repository.

**Output:**
```
🔍 Batch Audit Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Audited plugins: 5

plugins/my-plugin-1:
  ✓ No issues found

plugins/my-plugin-2:
  ❌ 2 critical issues
  ⚠ 1 warning

plugins/my-plugin-3:
  ❌ 1 critical issue

plugins/my-plugin-4:
  ✓ No issues found

plugins/my-plugin-5:
  ⚠ 3 warnings

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary:
  Total plugins: 5
  Compliant: 2 (40%)
  With issues: 3 (60%)
  Critical issues: 3
  Warnings: 4
  Conversion specs: 3

Next: Review individual audit reports
```

### Audit with Filters

```bash
/fractary-faber-agent:audit-all --severity critical --pattern manager-as-skill
```

Only shows critical Manager-as-Skill inversions across all plugins.

---

## Interpreting Results

### Severity Levels

**Critical (❌):**
- Breaks architectural patterns
- Prevents core functionality
- Requires immediate fix

Examples:
- Manager-as-Skill inversion (can't ask questions)
- Director-as-Agent (wrong pattern entirely)

**Warning (⚠):**
- Suboptimal but functional
- Should be fixed eventually
- Doesn't break functionality

Examples:
- Missing state management
- No user approval gates
- Inline scripts (works but inefficient)

**Suggestion (💡):**
- Best practice recommendations
- Optimization opportunities
- Not urgent

Examples:
- Could use common.sh library
- Consider extracting to reusable skill

### Context Impact

Audit reports show estimated context savings:

```
Estimated savings: ~45K tokens (75% reduction)
```

**How calculated:**
- Before: Sum of all agent contexts in chain
- After: Single manager + skills (skills in context, scripts not)
- Reduction: Before - After

**Example:**
- Agent Chain: 60K tokens (3 agents × ~20K each)
- Manager + Skills: 15K tokens (manager 8K + 3 skills × 2K)
- Savings: 45K tokens (75%)

### Fix Priority

**High priority (fix first):**
1. Manager-as-Skill inversions (functionality broken)
2. Agent chains (major context waste)
3. Hybrid agents (context inefficiency)

**Medium priority:**
4. Inline scripts (optimization)
5. Missing user approvals (safety)

**Low priority:**
6. Suggestions (best practices)

---

## Integration with CI/CD

### Pre-commit Hook

Add audit check to prevent anti-patterns:

**.git/hooks/pre-commit:**
```bash
#!/bin/bash

# Run audit on changed plugin
CHANGED_PLUGIN=$(git diff --name-only --cached | grep "plugins/" | head -1 | cut -d/ -f1-2)

if [[ -n "$CHANGED_PLUGIN" ]]; then
  echo "Running FABER audit on $CHANGED_PLUGIN..."

  /fractary-faber-agent:audit "$CHANGED_PLUGIN" --severity critical --output json > /tmp/audit.json

  CRITICAL_COUNT=$(jq '.issues | map(select(.severity == "critical")) | length' /tmp/audit.json)

  if [[ $CRITICAL_COUNT -gt 0 ]]; then
    echo "❌ Audit failed: $CRITICAL_COUNT critical issues found"
    echo "Run: /fractary-faber-agent:audit $CHANGED_PLUGIN"
    exit 1
  fi
fi

echo "✓ Audit passed"
```

### GitHub Action

**.github/workflows/audit.yml:**
```yaml
name: FABER Audit

on:
  pull_request:
    paths:
      - 'plugins/**'

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run FABER Audit
        run: |
          /fractary-faber-agent:audit-all --severity critical --output json > audit-report.json

      - name: Check Results
        run: |
          CRITICAL=$(jq '[.plugins[].issues[] | select(.severity == "critical")] | length' audit-report.json)
          if [[ $CRITICAL -gt 0 ]]; then
            echo "::error::Found $CRITICAL critical issues"
            exit 1
          fi

      - name: Upload Report
        uses: actions/upload-artifact@v3
        with:
          name: audit-report
          path: audit-report.json
```

---

## Best Practices

### 1. Run Audits Regularly

```bash
# Weekly audit
/fractary-faber-agent:audit-all

# After major changes
git commit && /fractary-faber-agent:audit /plugins/my-plugin
```

### 2. Fix Critical Issues First

Don't try to fix everything at once:
1. Fix Manager-as-Skill inversions (broken functionality)
2. Refactor agent chains (major impact)
3. Split hybrid agents (medium impact)
4. Extract inline scripts (optimization)

### 3. Review Conversion Specs Before Applying

Always review specs:
```bash
/fractary-faber-agent:review-conversion <spec-file>
```

Don't blindly apply:
- Understand the changes
- Verify affected files
- Check estimated impact
- Review migration guide

### 4. Test After Conversions

After applying a conversion:
```bash
# 1. Run audit again
/fractary-faber-agent:audit /plugins/my-plugin

# 2. Test workflow
/my-plugin:test-workflow

# 3. Validate generated files
/fractary-faber-agent:validate my-workflow
```

### 5. Generate Specs for Documentation

Even if not applying immediately:
```bash
/fractary-faber-agent:audit /plugins/my-plugin --generate-specs
```

Specs serve as:
- Documentation of issues
- Plan for future refactoring
- Evidence of technical debt

---

## Troubleshooting

### Issue: "No anti-patterns detected" but workflow has issues

**Possible causes:**
1. Custom patterns not in detection rules
2. Anti-pattern too subtle for automated detection
3. Plugin structure unusual

**Solution:**
Manual review using migration guides:
- [Agent Chain Migration](../migration/agent-chain-to-skills.md)
- [Hybrid Agent Splitting](../migration/hybrid-agent-splitting.md)
- [Manager Inversion Fix](../migration/manager-inversion-fix.md)

### Issue: "False positive - this is correct"

Some patterns may appear like anti-patterns but are intentional.

**Example:**
```
❌ Agent has bash commands

File: agents/repo-manager.md
  Contains: git commit, git push
```

**Explanation:**
This is correct - repo managers use git CLI (not a skill).

**Solution:**
Add exception to audit config:
```json
{
  "audit": {
    "exceptions": {
      "inline-bash": [
        "agents/repo-manager.md",
        "agents/work-manager.md"
      ]
    }
  }
}
```

### Issue: "Conversion spec won't apply"

**Error:**
```
❌ Cannot apply conversion: File already exists
  File: agents/deployment-orchestrator.md
```

**Solution:**
Resolve manually or use `--force`:
```bash
/fractary-faber-agent:apply-conversion <spec> --force
```

---

## Next Steps

- Run audit on your plugins
- Review generated conversion specs
- Follow migration guides to fix issues
- Re-run audit to verify fixes
- Integrate audit into CI/CD

For detailed migration instructions, see:
- [Workflow Creation Guide](workflow-creation-guide.md)
- [Conversion Spec Guide](conversion-spec-guide.md)
- [Migration Guides](../migration/)
