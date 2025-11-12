---
pattern: Builder-Debugger
category: Skill Organization
difficulty: intermediate
tags: [builder, debugger, inspector, knowledge-base, troubleshooting]
version: 1.0
---

# Pattern: Builder/Debugger with Inspector

## Intent

Organize specialist skills into three focused roles: Observer (Inspector), Analyzer (Debugger), and Executor (Builder), with knowledge base integration for consistent troubleshooting.

## Problem

Complex workflows need:
- **Factual observation** of current state (WHAT IS)
- **Root cause analysis** when issues detected (WHY + HOW TO FIX)
- **Execution** of operations and fixes (DO THE WORK)

Conflating these concerns in a single skill leads to:
- Mixed responsibilities (observation + analysis + execution)
- Hard to test (can't test observation independently)
- Knowledge duplication (fixes scattered across skills)
- Inconsistent troubleshooting (different approaches each time)

## Solution

**Separate into 3 skill types with clear boundaries:**

1. **Inspector**: Observer role - WHAT IS (factual only, no opinions)
2. **Debugger**: Analyzer role - WHY + HOW (knowledge base integration)
3. **Builder**: Executor role - DO THE WORK (operations)

**Plus: Troubleshooting Knowledge Base** for consistent issue resolution

## Structure

### Inspector Skill (Observer)

```markdown
---
skill: {project}-{domain}-inspector
purpose: Observe and report current state factually
layer: Observer
---

# {Project} {Domain} Inspector

## Purpose
Factual observation of current state. Reports WHAT IS, not WHY.

## Operations

### check

**Types of checks:**
- existence: Does entity exist?
- configuration: Is config valid?
- data-quality: Is data correct?
- dependencies: Are dependencies available?
- health: Is system healthy?

**Output:**
```json
{
  "status": "success" | "issues_found",
  "entity": "user-service",
  "checks_run": ["existence", "configuration", "data-quality"],
  "issues": [
    {
      "type": "missing_config_field",
      "severity": "high",
      "location": "config.json:12",
      "details": "Field 'database.connection_string' not found"
    }
  ],
  "facts": {
    "entity_exists": true,
    "config_valid": false,
    "data_quality_score": 0.92
  }
}
```

**Critical Constraints:**
- Reports FACTS ONLY (no opinions, no recommendations)
- Does NOT explain WHY issues exist
- Does NOT recommend HOW to fix
- Observer role only
```

### Debugger Skill (Analyzer)

```markdown
---
skill: {project}-{domain}-debugger
purpose: Analyze issues and recommend fixes using knowledge base
layer: Analyzer
---

# {Project} {Domain} Debugger

## Purpose
Analyze issues from Inspector and recommend fixes with confidence scores.
Uses troubleshooting knowledge base for consistent resolution.

## Operations

### analyze-issues

**Input:** Issues from Inspector

**Process:**
1. For each issue type, query knowledge base
2. Find matching troubleshooting document
3. Extract recommended fix + confidence score
4. Return fix with context

**Output:**
```json
{
  "status": "success",
  "issues_analyzed": 1,
  "recommendations": [
    {
      "issue_type": "missing_config_field",
      "root_cause": "config.json incomplete - missing database section",
      "recommended_fix": "add_database_config",
      "confidence": 0.95,
      "fix_description": "Add database.connection_string to config.json",
      "estimated_time": "30 seconds",
      "risk_level": "low",
      "knowledge_base_ref": "docs/troubleshooting/missing-config.md"
    }
  ]
}
```

**Knowledge Base Integration:**
```markdown
<KNOWLEDGE_BASE>
Location: docs/troubleshooting/{issue-type}.md

For each issue type, reference:
- Symptoms: How to identify
- Root Causes: Why it happens
- Automated Fix: How to fix automatically
- Manual Fix: When manual intervention needed
- Success Rate: Historical fix success %
- Related Issues: Similar problems
</KNOWLEDGE_BASE>
```
```

### Builder Skill (Executor)

```markdown
---
skill: {project}-{domain}-builder
purpose: Execute operations and apply fixes
layer: Executor
---

# {Project} {Domain} Builder

## Purpose
Execute operations. Routes to appropriate operation scripts.

## Operations

### create
Create new entity

### update
Update existing entity

### delete
Remove entity

### fix (from Debugger recommendations)
Apply recommended fix

**Input from Debugger:**
```json
{
  "operation": "fix",
  "fix_operation": "add_database_config",
  "entity": "user-service",
  "parameters": {
    "config_file": "config.json",
    "field": "database.connection_string",
    "value": "${DATABASE_URL}"
  }
}
```

**Implementation:**
Routes to appropriate script based on operation:
- create → scripts/create-entity.sh
- update → scripts/update-entity.sh
- delete → scripts/delete-entity.sh
- fix/add_database_config → scripts/fixes/add-database-config.sh

**Output:**
```json
{
  "status": "success",
  "operation": "fix/add_database_config",
  "changes_made": ["config.json updated"],
  "files_modified": ["config.json"],
  "rollback_available": true,
  "rollback_command": "git checkout config.json"
}
```
```

### Troubleshooting Knowledge Base

```markdown
# docs/troubleshooting/missing-config.md

## Issue Type: missing_config_field

### Symptoms
- Config validation fails
- Field not found errors
- Application startup errors

### Root Causes
1. Config template incomplete (80% of cases)
2. Migration from old config format (15%)
3. Typo in field name (5%)

### Automated Fix

**Operation:** add_database_config
**Confidence:** 95%
**Script:** scripts/fixes/add-database-config.sh

```bash
# Add missing database config field
echo "database:" >> config.json
echo "  connection_string: \${DATABASE_URL}" >> config.json
```

**Success Rate:** 94.1% (based on 127 historical fixes)

### Manual Verification
1. Check config.json has database section
2. Verify connection string format
3. Test database connection

### Prevention
- Use complete config templates
- Validate configs in CI/CD
- Document required fields

### Related Issues
- invalid_connection_string
- database_unreachable
```

## Applicability

Use this pattern when:
- ✅ Complex troubleshooting required
- ✅ Many issue types possible (need knowledge base)
- ✅ Want consistent fix recommendations
- ✅ Historical learning important (confidence scores)
- ✅ Clear separation helpful (observation vs. analysis vs. execution)

Don't use when:
- ❌ Simple CRUD operations only (overkill)
- ❌ No troubleshooting needed
- ❌ Deterministic workflows (no issues to debug)

## Consequences

**Benefits:**
- ✅ Clear separation of concerns (observe/analyze/execute)
- ✅ Testable in isolation (each skill independently)
- ✅ Consistent troubleshooting (knowledge base)
- ✅ Historical learning (confidence scores from success rates)
- ✅ Knowledge capture (fixes documented permanently)

**Trade-offs:**
- ⚠️ More files to maintain (3 skills + knowledge base)
- ⚠️ Knowledge base must stay current

## Implementation

### 1. Create Inspector Skill

Focus on **factual observation only**:

```bash
mkdir -p .claude/skills/{project}-inspector/scripts
```

**Check types:**
- existence-check.sh: Does entity exist?
- config-check.sh: Is config valid?
- data-quality-check.sh: Is data correct?
- health-check.sh: Is system healthy?

**Output:** Facts only, no opinions

### 2. Create Debugger Skill

Focus on **analysis + recommendations**:

```bash
mkdir -p .claude/skills/{project}-debugger/workflow
```

**Workflow file:** `workflow/analyze-issue.md`

```markdown
## Analyze Issue

1. Receive issue from Inspector
2. Query knowledge base for issue type
3. Extract recommended fix
4. Calculate confidence from historical success rate
5. Return recommendation with context
```

### 3. Create Builder Skill

Focus on **execution only**:

```bash
mkdir -p .claude/skills/{project}-builder/scripts/fixes
```

**Operations:**
- Standard: create, update, delete
- Fixes: One script per fix operation from knowledge base

### 4. Create Knowledge Base

```bash
mkdir -p docs/troubleshooting
```

**One file per issue type:**
```
docs/troubleshooting/
├── missing-config.md
├── schema-mismatch.md
├── data-validation-error.md
├── dependency-unavailable.md
└── ...
```

**Template:**
```markdown
## Issue Type: {issue_type}

### Symptoms
How to identify this issue

### Root Causes
Why it happens (with percentages)

### Automated Fix
Operation name, confidence, script

### Manual Verification
Steps to confirm fix

### Prevention
How to avoid in future

### Related Issues
Similar problems
```

## Manager Integration

Manager orchestrates the 3 skills in workflow:

```markdown
<WORKFLOW>

## Phase 1: INSPECT
Invoke: {project}-inspector skill
Receive: Facts about current state

## Phase 2: ANALYZE (if issues)
If inspection found issues:
  Invoke: {project}-debugger skill
  Receive: Recommended fixes with confidence

## Phase 3: PRESENT
Show user:
- Facts from Inspector
- Analysis from Debugger
- Recommended fixes
- Confidence levels

## Phase 4: APPROVE
If confidence >= 80%:
  Ask: "Auto-fix {count} issues?"
If confidence < 80%:
  Ask: "Manual review needed. Investigate?"

## Phase 5: EXECUTE
Invoke: {project}-builder skill
Operation: Recommended fix from Debugger

## Phase 6: VERIFY
Re-invoke: {project}-inspector skill
Compare: Before/after state

## Phase 7: REPORT
Summary with confidence and outcomes

</WORKFLOW>
```

## Examples

### Example: Lake.Corthonomy.AI

**Inspector:**
```markdown
Skills: corthonomy-auditor
Checks: data-exists, catalog-exists, schema-valid, partitions-correct
Output: 7 check types, factual results only
```

**Debugger:**
```markdown
Skill: corthonomy-debugger
Knowledge Base: 26 issue types documented
Confidence: Based on 200+ historical fixes
Success Rate: 94.1% for high-confidence fixes
```

**Builder:**
```markdown
Skill: corthonomy-catalog-builder
Operations: 8 catalog operations
Fix Operations: 26 automated fixes (one per issue type)
Scripts: All deterministic operations in scripts/
```

**Results:**
- 96.2% knowledge base coverage
- 94.1% success rate for high-confidence fixes
- Clear separation: Observer/Analyzer/Executor

## Testing

**Inspector Tests:**
```bash
# Each check type independently
Test: existence-check with entity present
Test: existence-check with entity missing
Test: config-check with valid config
Test: config-check with invalid config
```

**Debugger Tests:**
```bash
# Knowledge base lookup
Test: Known issue type → returns fix + confidence
Test: Unknown issue type → returns "no known fix"
Test: Confidence calculation from success rates
```

**Builder Tests:**
```bash
# Each operation independently
Test: create operation
Test: fix operation (specific fix)
Test: Rollback available after changes
```

## Related Patterns

- **Manager-as-Agent**: Orchestrates Inspector/Debugger/Builder
- **7-Phase Workflow**: Framework for coordinating skills

## Known Uses

- **Lake.Corthonomy.AI**: Data catalog management
- **Infrastructure projects**: Deployment health checking

## Tags

`#builder` `#debugger` `#inspector` `#knowledge-base` `#troubleshooting` `#separation-of-concerns`
