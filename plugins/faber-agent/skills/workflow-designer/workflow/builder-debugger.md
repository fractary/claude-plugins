# Design Builder/Debugger Workflow Architecture

**Purpose:** Design architecture for iterative workflows with observation, diagnosis, and fixing patterns

**Pattern:** Manager-as-Agent with Builder/Debugger/Inspector specialization

## Overview

Builder/Debugger pattern is for workflows that:
- Iteratively build or fix something
- Require observation and diagnosis
- Loop until success criteria met
- Integrate knowledge bases for troubleshooting
- Track issues and resolutions

**Example Use Cases:**
- Code generation and debugging
- Infrastructure deployment with healing
- Data quality improvement loops
- Configuration management with validation

## Step 1: Analyze Requirements

From requirements, extract:
- Workflow name
- What is being built/fixed
- Success criteria (when to stop)
- Maximum iterations
- Knowledge base needs
- Issue tracking requirements

## Step 2: Design Specialist Roles

**Three specialist roles:**

### 1. Inspector Skill (Observer - WHAT IS)

**Role:** Observe and report facts without analysis

**Responsibilities:**
- Gather current state
- Run checks and tests
- Collect evidence
- Report observations factually
- NO diagnosis or recommendations

**Example Operations:**
- `inspect-code`: Scan codebase for syntax errors
- `run-tests`: Execute test suite, report results
- `check-deployment`: Verify deployment status
- `scan-logs`: Collect error logs

### 2. Debugger Skill (Analyzer - WHY + HOW)

**Role:** Analyze issues and provide solutions

**Responsibilities:**
- Analyze Inspector findings
- Diagnose root causes
- Consult knowledge base
- Recommend fixes
- Score confidence in diagnosis

**Example Operations:**
- `diagnose-failure`: Analyze test failures, find root cause
- `analyze-errors`: Parse error messages, suggest fixes
- `recommend-fix`: Provide step-by-step fix instructions
- `confidence-score`: Rate fix recommendation confidence

### 3. Builder Skill (Executor - DO)

**Role:** Execute changes and fixes

**Responsibilities:**
- Implement fixes from Debugger
- Apply changes to code/infrastructure
- Execute build/deploy operations
- Verify immediate success

**Example Operations:**
- `apply-fix`: Implement recommended fix
- `rebuild-code`: Rebuild with changes
- `redeploy`: Deploy updated version
- `rollback`: Revert changes if needed

## Step 3: Design Workflow Loop

**Standard Builder/Debugger Loop:**

```
Phase 1: INSPECT (Inspector skill)
  ↓
Phase 2: ANALYZE (Debugger skill)
  ↓
  Decision: Issues found?
  ├─ NO → Phase 7: REPORT (success)
  └─ YES ↓
Phase 3: PRESENT (Manager presents findings)
  ↓
Phase 4: APPROVE (User approves fix)
  ↓
Phase 5: BUILD (Builder skill applies fix)
  ↓
Phase 6: VERIFY (Inspector re-checks)
  ↓
  Iteration check:
  ├─ Max iterations? → Phase 7: REPORT (partial success)
  ├─ Success? → Phase 7: REPORT (success)
  └─ Retry → Phase 1: INSPECT (loop)
```

**Typical Phases:**

1. **INSPECT** - Inspector gathers current state
2. **ANALYZE** - Debugger diagnoses issues
3. **PRESENT** - Manager shows findings to user
4. **APPROVE** - User approves fix plan
5. **BUILD** - Builder applies fix
6. **VERIFY** - Inspector checks fix worked
7. **REPORT** - Manager reports final results

**Loop continues until:**
- Success criteria met (no issues)
- Max iterations reached
- User cancels
- Unrecoverable error

## Step 4: Design Knowledge Base Integration

**Knowledge Base Structure:**

```
knowledge-base/
├── common-issues/
│   ├── build-failures.md
│   ├── deployment-errors.md
│   └── test-failures.md
└── troubleshooting/
    ├── error-patterns.md
    └── resolution-guide.md
```

**Integration in Debugger:**
- Search knowledge base for similar issues
- Match error patterns
- Retrieve recommended solutions
- Score solution confidence

## Step 5: Design Issue Log Tracking

**Issue Log:** `.{plugin}/workflow/{workflow-name}/{timestamp}/issues.json`

**Structure:**
```json
{
  "issues": [
    {
      "iteration": 1,
      "discovered_at": "2025-01-11T15:30:00Z",
      "type": "test_failure",
      "description": "3 unit tests failing in data-processor module",
      "evidence": {
        "test_results": "...",
        "error_messages": ["..."]
      },
      "diagnosis": {
        "root_cause": "Invalid schema validation logic",
        "confidence": 0.85,
        "kb_reference": "common-issues/test-failures.md#schema-validation"
      },
      "fix_applied": {
        "description": "Update schema validation to handle nullable fields",
        "files_modified": ["src/validator.js"],
        "timestamp": "2025-01-11T15:35:00Z"
      },
      "resolution": {
        "resolved": true,
        "verified_at": "2025-01-11T15:40:00Z",
        "verification": "All tests passing"
      }
    }
  ],
  "summary": {
    "total_issues": 5,
    "resolved": 4,
    "unresolved": 1,
    "iterations": 3
  }
}
```

## Step 6: Determine Components Needed

**Manager Agent (ALWAYS required):**
- Name: `{workflow-name}-manager`
- Location: `agents/{workflow-name}-manager.md`
- Type: **AGENT** (not skill)
- Tool Access: **FULL** (Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion)
- Pattern: Builder/Debugger loop
- Responsibilities:
  - Orchestrate inspection → analysis → build loop
  - Track iterations and issues
  - Present findings to user
  - Get approval for fixes
  - Decide when to stop (success/max iterations)

**Inspector Skill (REQUIRED):**
- Name: `{workflow-name}-inspector`
- Location: `skills/{workflow-name}-inspector/SKILL.md`
- Type: **SKILL**
- Role: Observer (factual reporting only)
- Scripts: Check operations, test execution

**Debugger Skill (REQUIRED):**
- Name: `{workflow-name}-debugger`
- Location: `skills/{workflow-name}-debugger/SKILL.md`
- Type: **SKILL**
- Role: Analyzer (diagnosis and recommendations)
- Scripts: Pattern matching, KB search, analysis

**Builder Skill (REQUIRED):**
- Name: `{workflow-name}-builder`
- Location: `skills/{workflow-name}-builder/SKILL.md`
- Type: **SKILL**
- Role: Executor (apply fixes)
- Scripts: Code modification, rebuild, deploy

**Director Skill (if batch operations):**
- Name: `{workflow-name}-director`
- Location: `skills/{workflow-name}-director/SKILL.md`
- Type: **SKILL**
- Purpose: Pattern expansion for batch operations

## Step 7: Build Architecture Object

Return complete architecture:

```json
{
  "status": "success",
  "architecture": {
    "workflow_name": "code-fixer",
    "pattern": "builder-debugger",
    "components": {
      "manager_agent": {
        "name": "code-fixer-manager",
        "file": "agents/code-fixer-manager.md",
        "pattern": "builder-debugger",
        "tool_access": ["Bash", "Skill", "Read", "Write", "Glob", "Grep", "AskUserQuestion"],
        "workflow_type": "iterative_loop",
        "max_iterations": 5,
        "phases": [
          {
            "number": 1,
            "name": "INSPECT",
            "description": "Inspector checks code for issues",
            "skills_invoked": ["code-inspector"],
            "repeatable": true
          },
          {
            "number": 2,
            "name": "ANALYZE",
            "description": "Debugger diagnoses issues",
            "skills_invoked": ["code-debugger"],
            "repeatable": true
          },
          {
            "number": 3,
            "name": "PRESENT",
            "description": "Present diagnosis and fix plan",
            "skills_invoked": [],
            "user_interaction": false
          },
          {
            "number": 4,
            "name": "APPROVE",
            "description": "User approves fix",
            "skills_invoked": [],
            "user_interaction": true
          },
          {
            "number": 5,
            "name": "BUILD",
            "description": "Builder applies fix",
            "skills_invoked": ["code-builder"],
            "repeatable": true
          },
          {
            "number": 6,
            "name": "VERIFY",
            "description": "Inspector re-checks",
            "skills_invoked": ["code-inspector"],
            "repeatable": true
          },
          {
            "number": 7,
            "name": "REPORT",
            "description": "Report final results",
            "skills_invoked": [],
            "user_interaction": false
          }
        ],
        "loop_logic": {
          "loop_phases": [1, 2, 5, 6],
          "continue_if": "issues_found && iterations < max_iterations",
          "success_criteria": "no_issues_found",
          "exit_conditions": ["success", "max_iterations", "user_cancel", "unrecoverable_error"]
        },
        "state_management": {
          "enabled": true,
          "location": ".{plugin}/workflow/code-fixer/{timestamp}/state.json",
          "tracks": ["iteration", "issues", "fixes_applied"]
        },
        "issue_log": {
          "enabled": true,
          "location": ".{plugin}/workflow/code-fixer/{timestamp}/issues.json"
        }
      },
      "director_skill": {
        "name": "code-fixer-director",
        "file": "skills/code-fixer-director/SKILL.md",
        "needed": false,
        "purpose": "Batch operation support (if needed)"
      },
      "specialist_skills": [
        {
          "name": "code-inspector",
          "file": "skills/code-inspector/SKILL.md",
          "role": "inspector",
          "purpose": "Observe code state and run checks",
          "type": "inspector",
          "scripts": [
            "run-lint.sh",
            "run-tests.sh",
            "check-syntax.sh",
            "collect-errors.sh"
          ],
          "guidelines": {
            "report_facts_only": true,
            "no_analysis": true,
            "no_recommendations": true,
            "targeted_checks": true
          }
        },
        {
          "name": "code-debugger",
          "file": "skills/code-debugger/SKILL.md",
          "role": "debugger",
          "purpose": "Analyze issues and recommend fixes",
          "type": "debugger",
          "scripts": [
            "analyze-error.sh",
            "search-kb.sh",
            "recommend-fix.sh",
            "confidence-score.sh"
          ],
          "knowledge_base": {
            "enabled": true,
            "location": "knowledge-base/",
            "search": true
          },
          "guidelines": {
            "provide_analysis": true,
            "recommend_solutions": true,
            "score_confidence": true,
            "cite_kb_sources": true
          }
        },
        {
          "name": "code-builder",
          "file": "skills/code-builder/SKILL.md",
          "role": "builder",
          "purpose": "Apply fixes and rebuild code",
          "type": "builder",
          "scripts": [
            "apply-fix.sh",
            "rebuild-code.sh",
            "run-tests.sh",
            "rollback.sh"
          ],
          "guidelines": {
            "execute_fixes_only": true,
            "no_analysis": true,
            "verify_immediate": true,
            "support_rollback": true
          }
        }
      ],
      "command": {
        "name": "fix-code",
        "file": "commands/fix-code.md",
        "description": "Iteratively fix code issues",
        "routes_to": "code-fixer-manager (agent)"
      }
    },
    "file_structure": {
      "agents": [
        "agents/code-fixer-manager.md"
      ],
      "skills": [
        "skills/code-inspector/SKILL.md",
        "skills/code-debugger/SKILL.md",
        "skills/code-builder/SKILL.md"
      ],
      "commands": [
        "commands/fix-code.md"
      ],
      "scripts": [
        "skills/code-inspector/scripts/run-lint.sh",
        "skills/code-inspector/scripts/run-tests.sh",
        "skills/code-inspector/scripts/check-syntax.sh",
        "skills/code-inspector/scripts/collect-errors.sh",
        "skills/code-debugger/scripts/analyze-error.sh",
        "skills/code-debugger/scripts/search-kb.sh",
        "skills/code-debugger/scripts/recommend-fix.sh",
        "skills/code-debugger/scripts/confidence-score.sh",
        "skills/code-builder/scripts/apply-fix.sh",
        "skills/code-builder/scripts/rebuild-code.sh",
        "skills/code-builder/scripts/run-tests.sh",
        "skills/code-builder/scripts/rollback.sh"
      ],
      "knowledge_base": [
        "knowledge-base/common-issues/",
        "knowledge-base/troubleshooting/"
      ]
    },
    "totals": {
      "agents": 1,
      "skills": 3,
      "commands": 1,
      "scripts": 12,
      "total_files": 17
    }
  }
}
```

## Validation Checklist

Before returning architecture, verify:

- [ ] Manager is **Agent** (not Skill)
- [ ] Manager has **full tool access** (all 7 tools)
- [ ] Manager has Builder/Debugger loop structure
- [ ] Inspector skill exists (Observer role)
- [ ] Debugger skill exists (Analyzer role)
- [ ] Builder skill exists (Executor role)
- [ ] Inspector reports facts ONLY (no analysis)
- [ ] Debugger provides analysis and recommendations
- [ ] Builder executes fixes ONLY (no analysis)
- [ ] Max iterations defined
- [ ] Success criteria defined
- [ ] Issue log tracking enabled
- [ ] Knowledge base integration (if needed)
- [ ] Command routes to **Agent** (not Skill)
- [ ] All file paths valid

## Output

Return architecture object as shown in Step 7.
