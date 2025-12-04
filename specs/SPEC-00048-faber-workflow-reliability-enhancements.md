# SPEC-00048: FABER Workflow Reliability Enhancements

## Metadata

| Field | Value |
|-------|-------|
| **Status** | Approved |
| **Priority** | Critical |
| **Created** | 2025-12-04 |
| **Author** | Claude Code |
| **Affects** | fractary-faber plugin (all projects) |
| **Estimated Effort** | 48 hours |

## Summary

Critical reliability improvements for the FABER workflow execution engine addressing four systemic issues discovered during `dataset-maintain` workflow execution for `ipeds_hd`. These issues affect all FABER-based projects and must be resolved at the plugin level.

## Problem Statement

### Issue #1: Workflow Continues Despite Critical Phase Failures

**Evidence from Run `81f30a13-5639-4e4d-a2bf-8209dbb56dff`:**

```json
// Event 004-step_complete.json (data-inspect step)
{
  "overall_status": "fail",
  "compliance_score": 62,
  "critical_issues": 2,
  "warnings": 3,
  "issues": [
    "Data status check failed - curated data may be incomplete",
    "Data quality tests have not been run",
    "Field naming standards compliance incomplete"
  ]
}
```

**Problem:** The Frame phase inspection returned `overall_status: "fail"` with `compliance_score: 62` and 2 critical issues, yet the workflow continued to Architect and Build phases.

**Root Cause:** No failure handling mechanism in faber-manager. Skills return results but the manager has no configuration to determine whether to proceed, prompt, or stop based on result status.

**Impact:**
- Corrupts downstream phases with potentially invalid data
- Violates data quality principles
- Makes debugging harder because failures manifest in wrong phase
- Zero reliability in workflow execution

---

### Issue #2: Argument Case Mismatch (Recurring)

**Evidence:**
```
Agent initially used: --VERSION (uppercase)
ETL script expects:   --version (lowercase)
Terraform uses:       --environment (lowercase)
```

The faber-manager agent attempted `--VERSION` and `--ENVIRONMENT` but the ETL script uses `getResolvedOptions(sys.argv, ['JOB_NAME', 'environment', 'version'])` (lowercase).

**Root Cause:** Workflow step definitions don't explicitly specify arguments. The agent guesses argument names based on context, leading to case mismatches.

**Impact:**
- Unpredictable runtime failures
- Not the first occurrence - systemic pattern
- Manual correction required during execution

---

### Issue #3: State File Not Updated During Execution

**Evidence from `state.json`:**

```json
{
  "phases": {
    "frame": {
      "status": "pending",  // Should be "completed"
      "steps": {
        "loader-research": { "status": "pending" },  // Executed but shows pending
        "data-inspect": { "status": "pending" }       // Executed but shows pending
      }
    },
    "architect": {
      "status": "pending",  // Should be "completed"
    }
  }
}
```

**Problem:** Phase and step statuses remained `"pending"` even after successful execution.

**Root Cause:** faber-manager doesn't consistently update state before/after each step execution.

**Impact:**
- Cannot resume interrupted workflows (`--resume` broken)
- No accurate execution history
- State file becomes unreliable

---

### Issue #4: Missing --version in Terraform Default Arguments

**Evidence from `terraform.tf`:**

```hcl
default_arguments = {
  "--environment"   = var.environment
  "--source_bucket" = var.etl_bucket_name
  // "--version" NOT INCLUDED - must be passed at runtime
}
```

But ETL script requires it:
```python
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'environment', 'version'])
VERSION = args['version']  # Required!
```

**Root Cause:** Inconsistent configuration management. Some arguments in Terraform defaults, others expected at runtime with no documentation.

**Impact:**
- Confusion about where arguments come from
- Manual argument passing required
- No central source of truth

---

## Approved Solutions

### Solution #1: Strict Failure Handling (CRITICAL_RULE #8)

**Principle:** NO step or phase proceeds on failure, EVER. Claude NEVER improvises solutions - stop and report.

#### 1.1 Add CRITICAL_RULE #8 to faber-manager.md

```markdown
8. **Strict Failure Handling - NEVER IMPROVISE**
   - ALWAYS expect skills to return a result status: success | failure | warning
   - ALWAYS stop on failure - NO exceptions, NO workarounds
   - NEVER improvise solutions when something fails
   - ALWAYS report the failure clearly with:
     * What failed (phase:step)
     * Why it failed (error message/details)
     * How to resume (--resume command)
   - ALWAYS update state to record the failed step before stopping
   - If a skill doesn't return a result status, treat empty/null as failure
```

#### 1.2 Step Result Structure (Standard for All Skills)

```json
{
  "status": "success | failure | warning",
  "message": "Human-readable result description",
  "details": { },
  "errors": [],
  "warnings": []
}
```

#### 1.3 Add `result_handling` to Workflow Step Schema

```json
{
  "name": "data-inspect",
  "description": "Check dataset status",
  "skill": "corthion:inspector",
  "result_handling": {
    "on_success": "continue",
    "on_warning": "continue",
    "on_failure": "stop"
  }
}
```

**Schema Definition:**

```json
{
  "result_handling": {
    "type": "object",
    "properties": {
      "on_success": {
        "type": "string",
        "enum": ["continue", "prompt"],
        "default": "continue"
      },
      "on_warning": {
        "type": "string",
        "enum": ["continue", "prompt", "stop"],
        "default": "continue"
      },
      "on_failure": {
        "const": "stop",
        "description": "Failure ALWAYS stops - immutable, not configurable"
      }
    }
  }
}
```

**Key:** `on_failure: "stop"` is DEFAULT and IMMUTABLE. No project can override it.

#### 1.4 Hook Result Handling (Same Structure as Steps)

**Problem:** Current hooks use a simple `on_error` property which is inconsistent with steps and doesn't handle warnings.

**Current (deprecated):**
```json
{
  "type": "skill",
  "name": "validate-aws-credentials",
  "skill": "corthion-loader-validator-deploy-pre",
  "on_error": "abort"  // Too simple, no warning handling
}
```

**New (unified with steps):**
```json
{
  "type": "skill",
  "name": "validate-aws-credentials",
  "skill": "corthion-loader-validator-deploy-pre",
  "result_handling": {
    "on_success": "continue",
    "on_warning": "continue",
    "on_failure": "stop"
  }
}
```

**Schema Definition for Hooks:**

```json
{
  "hook": {
    "type": "object",
    "properties": {
      "type": { "type": "string", "enum": ["skill", "script", "document"] },
      "name": { "type": "string" },
      "skill": { "type": "string" },
      "result_handling": {
        "type": "object",
        "properties": {
          "on_success": {
            "type": "string",
            "enum": ["continue", "prompt"],
            "default": "continue"
          },
          "on_warning": {
            "type": "string",
            "enum": ["continue", "prompt", "stop"],
            "default": "continue"
          },
          "on_failure": {
            "type": "string",
            "enum": ["stop", "continue"],
            "default": "stop",
            "description": "Unlike steps, hooks CAN use 'continue' for informational hooks"
          }
        }
      }
    }
  }
}
```

**Key Differences from Steps:**
- Steps: `on_failure: "stop"` is IMMUTABLE (always stops)
- Hooks: `on_failure` defaults to `"stop"` but CAN be set to `"continue"` for informational hooks (e.g., debugging, logging)

**Migration:** Existing `on_error: "abort"` maps to `result_handling.on_failure: "stop"`

#### 1.5 Validation Hooks Best Practice

For validation purposes (like spec output validation), use hooks with strict failure handling:

```json
{
  "post_architect": [
    {
      "type": "skill",
      "name": "validate-spec-output",
      "description": "Validate spec matches command requirements",
      "skill": "fractary-spec:output-validator",
      "result_handling": {
        "on_success": "continue",
        "on_warning": "prompt",
        "on_failure": "stop"
      }
    }
  ]
}
```

**Validation Hook Requirements:**
1. Hooks MUST return the same `{status, message, details}` structure as steps
2. Manager MUST process hook results the same way as step results
3. Hook with `on_failure: "stop"` MUST halt workflow (same as step failure)
4. State MUST be updated to reflect hook failure before stopping

#### 1.6 Manager Hook Execution Flow

Update faber-manager.md hook execution to match step execution:

```
For each hook in phase_hooks:

1. EXECUTE HOOK:
   result = execute_skill(hook.skill, context)

2. VALIDATE RESULT:
   IF result.status is null or undefined THEN
     result.status = "failure"
     result.message = "Hook did not return valid status"

3. HANDLE RESULT:
   IF result.status == "failure" THEN
     IF hook.result_handling.on_failure == "stop" THEN
       Update state to "failed"
       Report failure with resume instructions
       STOP WORKFLOW
     ELSE  // on_failure == "continue"
       Log warning: "Hook {hook.name} failed but configured to continue"
       Continue execution

   ELSE IF result.status == "warning" THEN
     Check hook.result_handling.on_warning
     IF on_warning == "stop" THEN stop workflow
     ELSE IF on_warning == "prompt" THEN ask user
     ELSE continue

   ELSE (success)
     Continue to next hook
```

---

### Solution #2: Explicit Argument Configuration

**Principle:** Arguments defined explicitly in workflow steps - no guessing.

#### 2.1 Add `arguments` Property to Workflow Step Schema

```json
{
  "arguments": {
    "type": "object",
    "description": "Explicit arguments to pass. Keys are argument names (exact), values are literals or {placeholder} references.",
    "additionalProperties": { "type": "string" }
  }
}
```

#### 2.2 Update Workflow Steps with Explicit Arguments

```json
{
  "name": "data-load",
  "description": "Execute AWS Glue ETL job to load data",
  "skill": "fractary-faber-cloud:glue-executor",
  "arguments": {
    "--environment": "{environment}",
    "--version": "{version}"
  },
  "config": {
    "job_name_pattern": "corthion-{dataset}-{table}-etl",
    "wait_for_completion": true,
    "timeout_minutes": 30
  }
}
```

**Why This Solves It:**
1. Arguments defined in workflow config - source of truth
2. Skill receives exact argument names and values
3. Placeholders resolve from context
4. No guessing, no case mismatches

---

### Solution #3: Mandatory State Updates by Manager

**Principle:** Manager ALWAYS updates state - no explicit workflow hooks needed.

#### 3.1 Strengthen CRITICAL_RULE #3 in faber-manager.md

```markdown
3. **State Management - MANDATORY UPDATES**
   - ALWAYS update state BEFORE starting a step (status: "in_progress")
   - ALWAYS update state AFTER completing a step (status: "completed" or "failed")
   - ALWAYS record the step result data in state
   - On failure: Update state to "failed" BEFORE stopping
   - State updates enable --resume to work correctly
   - If state update fails, log error but continue to report actual step failure
```

#### 3.2 Update Step Execution Flow (Section 4.3)

```
For each step in steps_to_execute:

1. MARK STEP IN_PROGRESS:
   faber-state.update-step(run_id, phase, step_name, "in_progress")

2. EXECUTE STEP:
   result = execute_skill(step.skill, context)

3. VALIDATE RESULT:
   IF result.status is null or undefined THEN
     result.status = "failure"
     result.message = "Skill did not return valid status"

4. UPDATE STATE WITH RESULT:
   faber-state.update-step(run_id, phase, step_name, result.status, result)

5. HANDLE RESULT:
   IF result.status == "failure" THEN
     emit step_error event
     report failure with resume instructions
     STOP WORKFLOW

   ELSE IF result.status == "warning" THEN
     check step.result_handling.on_warning
     IF on_warning == "prompt" THEN ask user
     ELSE continue

   ELSE (success)
     continue to next step
```

---

### Solution #4: faber-cloud Integration for Glue Arguments

**Principle:** Centralize Glue job argument configuration in faber-cloud plugin.

#### 4.1 Extend faber-cloud Config Schema

```json
{
  "glue_execution": {
    "type": "object",
    "description": "Configuration for AWS Glue job execution",
    "properties": {
      "argument_patterns": {
        "type": "object",
        "description": "Argument templates with placeholders",
        "properties": {
          "--environment": { "type": "string", "default": "{environment}" },
          "--version": { "type": "string", "default": "{version}" }
        }
      },
      "default_arguments": {
        "type": "object",
        "description": "Static default arguments",
        "additionalProperties": { "type": "string" }
      }
    }
  }
}
```

#### 4.2 Example faber-cloud.json

```json
{
  "version": "2.0",
  "project": { "name": "corthion-etl" },
  "handlers": {
    "hosting": { "active": "aws" },
    "iac": { "active": "terraform" }
  },
  "glue_execution": {
    "argument_patterns": {
      "--environment": "{environment}",
      "--version": "{version}"
    }
  }
}
```

#### 4.3 How It Works

1. `data-load` step calls `faber-cloud:glue-executor`
2. faber-cloud reads its config for `glue_execution.argument_patterns`
3. Resolves placeholders from execution context
4. Builds argument list with correct casing
5. Executes Glue job with proper arguments

---

## Implementation Plan

### Phase 1: Schema Updates (Week 1)

**Files to Change:**
- `~/.claude/plugins/marketplaces/fractary/plugins/faber/schemas/workflow.schema.json`
  - Add `result_handling` property to step definition
  - Add `arguments` property to step definition
  - Enforce `on_failure: "stop"` as immutable for steps
- `~/.claude/plugins/marketplaces/fractary/plugins/faber/schemas/hook.schema.json`
  - Add `result_handling` property to hook definition
  - Deprecate `on_error` property (maintain backwards compatibility)
  - Default `on_failure: "stop"` but allow `"continue"` for informational hooks

### Phase 2: Manager Logic Updates (Week 1-2)

**Files to Change:**
- `~/.claude/plugins/marketplaces/fractary/plugins/faber/agents/faber-manager.md`
  - Add CRITICAL_RULE #8 (Strict Failure Handling)
  - Strengthen CRITICAL_RULE #3 (Mandatory State Updates)
  - Update Section 4.3 (Step Execution) with new flow
  - Update hook execution flow to use `result_handling` (Section 4.1/4.5)

### Phase 3: faber-cloud Extension (Week 2)

**Files to Change:**
- `~/.claude/plugins/marketplaces/fractary/plugins/faber-cloud/config/config.schema.json`
  - Add `glue_execution` section
- Create skill: `faber-cloud:glue-executor`
  - Reads config, resolves arguments, executes Glue job

### Phase 4: Project Workflow Updates (Week 3)

**Files to Change (per project):**
- `.fractary/plugins/faber/workflows/dataset-maintain.json`
  - Add `result_handling` to all steps
  - Add `arguments` to data-load step
  - Migrate hooks from `on_error` to `result_handling`
- `.fractary/plugins/faber-cloud/config/faber-cloud.json`
  - Add `glue_execution` configuration

### Phase 5: Validation & Testing (Week 4)

- Run dataset-maintain workflow for ipeds_hd
- Verify step failure handling stops workflow
- Verify hook failure with `on_failure: "stop"` stops workflow
- Verify hook failure with `on_failure: "continue"` logs and continues
- Verify state updates correctly
- Verify argument passing works
- Test --resume capability after step failure
- Test --resume capability after hook failure

---

## Files Affected

### Plugin Files (fractary-faber)

| File | Change |
|------|--------|
| `plugins/faber/schemas/workflow.schema.json` | Add `result_handling` to steps, add `arguments` to steps |
| `plugins/faber/schemas/hook.schema.json` | Add `result_handling` to hooks (deprecate `on_error`) |
| `plugins/faber/agents/faber-manager.md` | Add CRITICAL_RULE #8, strengthen #3, update Section 4.3, update hook execution flow |

### Plugin Files (fractary-faber-cloud)

| File | Change |
|------|--------|
| `plugins/faber-cloud/config/config.schema.json` | Add `glue_execution` section |
| `plugins/faber-cloud/skills/glue-executor.md` | New skill for Glue job execution |

### Project Files (etl.corthion.ai)

| File | Change |
|------|--------|
| `.fractary/plugins/faber/workflows/dataset-maintain.json` | Add `result_handling`, `arguments` |
| `.fractary/plugins/faber-cloud/config/faber-cloud.json` | Create with `glue_execution` |

---

## Validation Checklist

### Step Failure Handling
- [ ] Skills return `{status, message, details}` structure
- [ ] Manager validates result status exists
- [ ] Manager stops on `status: "failure"`
- [ ] Failure recorded in state before stopping
- [ ] Resume instructions shown on failure

### Hook Failure Handling
- [ ] Hooks return `{status, message, details}` structure (same as steps)
- [ ] Hooks use `result_handling` (not deprecated `on_error`)
- [ ] Hook with `on_failure: "stop"` halts workflow
- [ ] Hook with `on_failure: "continue"` logs warning and continues
- [ ] Hook warnings handled per `on_warning` config
- [ ] Validation hooks use `on_failure: "stop"` by default

### Argument Configuration
- [ ] `arguments` property in schema
- [ ] Workflow steps have explicit arguments
- [ ] Placeholders resolve correctly
- [ ] No argument guessing by agent

### State Management
- [ ] State updated before step (in_progress)
- [ ] State updated after step (completed/failed)
- [ ] Step result data recorded
- [ ] --resume works after interruption

### faber-cloud Integration
- [ ] `glue_execution` in schema
- [ ] Config created for project
- [ ] glue-executor skill created
- [ ] Arguments passed correctly to Glue

---

## Success Criteria

1. **Workflow stops immediately on any step failure** - no exceptions
2. **Agent never improvises** - reports failure with resume instructions
3. **State file always reflects actual execution** - enables --resume
4. **Arguments defined once in config** - no case mismatches
5. **All FABER projects inherit these improvements** - plugin-level changes

---

## References

- Workflow Run: `fractary/etl-corthion-ai/81f30a13-5639-4e4d-a2bf-8209dbb56dff`
- Dataset: `ipeds_hd` (IPEDS Higher Education Directory)
- Event Files: `.fractary/plugins/faber/runs/.../events/`
- faber-manager.md: `~/.claude/plugins/marketplaces/fractary/plugins/faber/agents/faber-manager.md`
