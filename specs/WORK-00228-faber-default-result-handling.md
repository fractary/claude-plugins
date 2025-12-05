# FABER Default Result Handling Configuration

**Issue**: [#228](https://github.com/fractary/claude-plugins/issues/228)
**Status**: Complete
**Phase**: Build
**Created**: 2025-12-05  

---

## Executive Summary

Implement default `result_handling` configuration for FABER workflow steps and hooks to reduce repetitive configuration. Currently, every step requires explicit result_handling like `{"on_success": "continue", "on_warning": "prompt", "on_failure": "stop"}`. This specification provides sensible defaults so steps only specify result_handling when diverging from defaults. Additionally, enhance warning and failure handling with analytical prompts that suggest solutions and present prioritized options.

---

## Problem Statement

### Current State

Each workflow step must explicitly define result_handling:

```json
{
  "name": "implement",
  "description": "Implement solution",
  "skill": "fractary-repo:commit-creator",
  "result_handling": {
    "on_success": "continue",
    "on_warning": "prompt",
    "on_failure": "stop"
  }
}
```

This is repetitive because 90% of steps use the same defaults. Workflow configurations become verbose and the defaults are implicit rather than explicit.

### Target State

Steps omit result_handling unless customizing defaults:

```json
{
  "name": "implement",
  "description": "Implement solution",
  "skill": "fractary-repo:commit-creator"
}
```

Defaults are applied automatically by faber-manager. When customizing, only modified fields are required:

```json
{
  "name": "critical-operation",
  "description": "Critical operation",
  "skill": "some:skill",
  "result_handling": {
    "on_warning": "stop"
  }
}
```

### Enhanced Response Handling

When warnings or failures occur, provide intelligent user prompts:

**For Warnings** (on_warning: "prompt"):
1. Display warning details and analysis
2. Propose solutions if available
3. Present options in priority order:
   - First: "Ignore and continue" (safest default)
   - Middle: Suggested corrective actions
   - Last: "Stop workflow" (safest if uncertain)

**For Failures** (on_failure: "stop"):
1. Display failure details and analysis
2. Propose solutions if available
3. Present options in priority order:
   - First: Suggested corrective actions
   - Middle: Diagnostic steps
   - Last: "Continue anyway (NOT RECOMMENDED)" (last resort)

---

## Acceptance Criteria

### 1. Default Configuration System

- [x] **AC1.1**: Schema validates optional result_handling (not required)
- [x] **AC1.2**: faber-manager applies defaults to all steps and hooks:
  - `on_success: "continue"` (proceed automatically)
  - `on_warning: "continue"` (proceed, log warning)
  - `on_failure: "stop"` (always stop on failure - IMMUTABLE)
- [x] **AC1.3**: Hooks inherit same defaults as steps
- [x] **AC1.4**: Workflow files can omit result_handling entirely
- [x] **AC1.5**: Backward compatibility: existing configs with explicit result_handling still work

### 2. Intelligent Warning Handling

- [x] **AC2.1**: When step/hook completes with warnings and on_warning: "prompt":
  - [x] Display warning summary (what happened)
  - [x] Show warning details and context
  - [x] If analysis available, show proposed solution
  - [x] Present user options starting with safest:
    - "Ignore and continue" (default, highlighted)
    - "Fix and retry" (if fixable)
    - "Stop workflow" (conservative choice)
- [x] **AC2.2**: Warning analysis can be sourced from:
  - Step/skill result data (e.g., `result.warning_analysis`)
  - Context inspection (analyze what went wrong)
  - Common patterns (retry timeout, resource warning, etc.)
- [x] **AC2.3**: User selection properly continues/stops workflow based on choice

### 3. Intelligent Failure Handling

- [x] **AC3.1**: When step/hook fails and on_failure: "stop":
  - [x] Display failure summary (what happened)
  - [x] Show error details and context
  - [x] If analysis available, show proposed solution
  - [x] Present user options in priority order:
    - "Suggested fix: [specific action]" (if available)
    - "Run diagnostic: [diagnostic command]" (if available)
    - "Continue anyway (NOT RECOMMENDED)" (last resort, explicitly discouraged)
- [x] **AC3.2**: Failure analysis can be sourced from:
  - Step/skill result data (e.g., `result.error_analysis`)
  - Error classification (known error patterns)
  - Suggested recovery actions
- [x] **AC3.3**: If user selects "continue anyway", log disclaimer warning
- [x] **AC3.4**: Workflow state tracks all failure recovery attempts

### 4. Response Type Validation

- [x] **AC4.1**: Code validates step result status: "success", "warning", "failure"
- [x] **AC4.2**: Response handling implements all three status types:
  - "success" with on_success: "continue" → proceed to next step
  - "success" with on_success: "prompt" → ask user before proceeding
  - "warning" with on_warning: "continue" → log warning, proceed
  - "warning" with on_warning: "prompt" → ask user with options
  - "warning" with on_warning: "stop" → abort workflow
  - "failure" with on_failure: "stop" → abort workflow (IMMUTABLE)
- [x] **AC4.3**: Invalid response types are rejected with clear error message

### 5. Configuration Schema Updates

- [x] **AC5.1**: workflow.schema.json updated:
  - result_handling is optional (not required)
  - Default structure documented
  - Individual fields optional within result_handling
- [x] **AC5.2**: Default result_handling documented in schema comments
- [x] **AC5.3**: Examples show both with and without result_handling

### 6. Documentation

- [x] **AC6.1**: docs/CONFIGURATION.md updated with:
  - Default result_handling behavior
  - When to customize defaults
  - Examples of customization
- [x] **AC6.2**: docs/RESULT-HANDLING.md created with:
  - Complete result_handling documentation
  - Response types (success, warning, failure)
  - User prompt behavior for each type
  - Examples and best practices
- [x] **AC6.3**: docs/HOOKS.md updated to reference result_handling defaults

### 7. Code Quality

- [x] **AC7.1**: All response types tested:
  - success → continue and prompt
  - warning → continue, prompt, and stop
  - failure → stop (IMMUTABLE)
- [x] **AC7.2**: Default application logic tested:
  - Merges user config with defaults
  - Preserves explicit values
  - Doesn't modify IMMUTABLE values
- [x] **AC7.3**: Backward compatibility tested with existing configs
- [x] **AC7.4**: User prompts tested with various scenarios

---

## Technical Design

### 1. Default Configuration

Define default result_handling as constant in faber-manager:

```javascript
const DEFAULT_RESULT_HANDLING = {
  on_success: "continue",      // Proceed automatically
  on_warning: "continue",       // Log warning, proceed
  on_failure: "stop"            // IMMUTABLE - always stop
};

const DEFAULT_HOOK_RESULT_HANDLING = {
  on_success: "continue",      // Proceed automatically
  on_warning: "continue",       // Log warning, proceed
  on_failure: "stop"            // Default; can be "continue" for informational hooks
};
```

### 2. Default Application Logic

When loading step/hook configuration:

```javascript
function applyResultHandlingDefaults(stepOrHook, defaults) {
  // Return early if no result_handling defined
  if (!stepOrHook.result_handling) {
    return defaults;
  }

  // Merge step's result_handling with defaults
  // User's explicit values override defaults
  // on_failure for steps is IMMUTABLE - always "stop"
  return {
    on_success: stepOrHook.result_handling.on_success ?? defaults.on_success,
    on_warning: stepOrHook.result_handling.on_warning ?? defaults.on_warning,
    on_failure: stepOrHook.result_handling.on_failure ?? defaults.on_failure
  };
}
```

### 3. Response Status Handling

Enhance result handling logic in faber-manager to:

1. **Validate** step result status: "success", "warning", or "failure"
2. **Get result_handling** config (with defaults applied)
3. **Handle each status**:

```javascript
// Simplified pseudocode
switch (result.status) {
  case "success":
    if (result_handling.on_success === "prompt") {
      promptUser("Step completed. Continue?", ["Continue", "Pause"]);
    } else {
      continueWorkflow();
    }
    break;

  case "warning":
    if (result_handling.on_warning === "stop") {
      stopWorkflow("Warning escalated to stop", result.warnings);
    } else if (result_handling.on_warning === "prompt") {
      promptWarning(result.warnings, result.analysis);
    } else {
      logWarning(result.warnings);
      continueWorkflow();
    }
    break;

  case "failure":
    if (result_handling.on_failure === "stop") {
      stopWorkflow("Step failed", result.error, result.analysis);
    }
    // Note: on_failure is IMMUTABLE - no other options
    break;
}
```

### 4. Warning Prompt Template

When `on_warning: "prompt"`:

```
STEP WARNING
────────────────────────────────────────

Step: {step.name}
Status: Completed with warnings

Warnings:
  - {warning 1}
  - {warning 2}

Analysis:
{result.warning_analysis || "No analysis available"}

Options:
  1. Ignore and continue (default)
  2. {Suggested action 1}
  3. {Suggested action 2}
  4. Stop workflow

Choose an option (1-4):
```

### 5. Failure Prompt Template

When `on_failure: "stop"`:

```
STEP FAILURE
────────────────────────────────────────

Step: {step.name}
Status: Failed

Error:
  {result.error}

Details:
{result.error_details || "No details available"}

Analysis & Suggestions:
{result.error_analysis || "No analysis available"}

Options:
  1. {Suggested fix (if available)}
  2. Run diagnostic: {diagnostic command}
  3. Continue anyway (NOT RECOMMENDED)
  4. Stop workflow (recommended)

Choose an option (1-4):
```

### 6. Schema Updates

Update `workflow.schema.json`:

```json
{
  "step_result_handling": {
    "type": "object",
    "description": "Defines behavior for step execution outcomes. Omit this field to use defaults: {on_success: continue, on_warning: continue, on_failure: stop}",
    "additionalProperties": false,
    "properties": {
      "on_success": {
        "type": "string",
        "enum": ["continue", "prompt"],
        "description": "Action when step succeeds (default: continue)"
      },
      "on_warning": {
        "type": "string",
        "enum": ["continue", "prompt", "stop"],
        "description": "Action on warnings (default: continue)"
      },
      "on_failure": {
        "type": "string",
        "enum": ["stop"],
        "const": "stop",
        "description": "IMMUTABLE: Failure always stops workflow"
      }
    }
  }
}
```

---

## Implementation Plan

### Phase 1: Core Defaults (High Priority)

1. Update `workflow.schema.json` to make result_handling optional
2. Add DEFAULT_RESULT_HANDLING constant to faber-manager
3. Implement applyResultHandlingDefaults() function
4. Update step/hook loading to apply defaults
5. Test with existing workflows (verify backward compatibility)

### Phase 2: Response Type Validation

1. Add validation for step result status ("success", "warning", "failure")
2. Implement status switch logic
3. Test all status types
4. Test all result_handling combinations

### Phase 3: Intelligent Prompts

1. Implement warning prompt template
2. Implement failure prompt template
3. Add analysis support (parse result.warning_analysis, result.error_analysis)
4. Test prompts with various scenarios
5. Verify options presentation and handling

### Phase 4: Documentation

1. Update docs/CONFIGURATION.md
2. Create docs/RESULT-HANDLING.md
3. Update docs/HOOKS.md
4. Add examples to workflow templates

### Phase 5: Migration & Testing

1. Update default workflow templates to remove explicit result_handling
2. Update all existing workflow configs (if needed)
3. Comprehensive testing of all scenarios
4. Verify no regressions with existing configurations

---

## Files Modified/Created

### Schema Updates
- `/plugins/faber/config/workflow.schema.json` - Make result_handling optional

### Code Changes
- `/plugins/faber/agents/faber-manager.md` - Add default application and enhanced prompts
- `/plugins/faber/skills/faber-config/SKILL.md` - May need applyDefaults helper

### Configuration Examples
- `/plugins/faber/config/faber.example.json` - Update examples
- `/plugins/faber/config/workflows/default.json` - Remove explicit result_handling
- `/plugins/faber/config/templates/*.json` - Remove explicit result_handling

### Documentation
- `/plugins/faber/docs/CONFIGURATION.md` - Update
- `/plugins/faber/docs/RESULT-HANDLING.md` - Create (NEW)
- `/plugins/faber/docs/HOOKS.md` - Update

---

## Expected Outcomes

### Before Implementation

```json
{
  "steps": [
    {
      "name": "step1",
      "skill": "some:skill",
      "result_handling": {
        "on_success": "continue",
        "on_warning": "continue",
        "on_failure": "stop"
      }
    },
    {
      "name": "step2",
      "skill": "some:skill",
      "result_handling": {
        "on_success": "continue",
        "on_warning": "continue",
        "on_failure": "stop"
      }
    }
  ]
}
```

### After Implementation

```json
{
  "steps": [
    {
      "name": "step1",
      "skill": "some:skill"
    },
    {
      "name": "step2",
      "skill": "some:skill",
      "result_handling": {
        "on_warning": "prompt"
      }
    }
  ]
}
```

Effectively reducing configuration verbosity while maintaining flexibility for custom scenarios.

---

## Testing Checklist

- [x] All response types (success, warning, failure) handled correctly
- [x] All result_handling combinations tested
- [x] Default application logic verified
- [x] Backward compatibility with explicit configs
- [x] Warning prompt displays and user can select options
- [x] Failure prompt displays with "NOT RECOMMENDED" messaging
- [x] User selection properly routes workflow
- [x] Workflow state tracks failure recovery attempts
- [x] Schema validation passes for both with/without result_handling
- [x] Documentation complete and accurate

---

## Success Criteria

This specification is complete when:

1. All acceptance criteria (AC) are satisfied
2. Schema is updated and validates correctly
3. faber-manager applies defaults and validates responses
4. Warning/failure prompts are intelligent and user-friendly
5. All response types tested and working
6. Documentation is comprehensive and clear
7. Backward compatibility maintained
8. No regression in existing workflows

