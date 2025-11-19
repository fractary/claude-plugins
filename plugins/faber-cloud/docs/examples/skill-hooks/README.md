# Skill Hook Examples

This directory contains example Claude Code skills that demonstrate the skill hook interface for the faber-cloud plugin.

## What are Skill Hooks?

Skill hooks allow you to invoke Claude Code skills at lifecycle points in your infrastructure deployments. Unlike script hooks (which run shell commands), skill hooks:

- ✅ Receive structured **WorkflowContext** (environment, operation, flags, etc.)
- ✅ Return structured **WorkflowResult** (success, messages, errors, artifacts)
- ✅ Are **testable independently** via `/skill skill-name`
- ✅ Are **discoverable** via `/help`
- ✅ Are **reusable** across projects
- ✅ Have **type-safe interfaces**

## Examples

### 1. Dataset Validator (Pre-Deployment)

**File:** `dataset-validator-deploy-pre-SKILL.md`

**Purpose:** Validate datasets before infrastructure deployment

**Hook Type:** `pre-deploy`

**What it does:**
- Checks dataset files exist
- Validates CSV schemas
- Verifies data quality metrics
- Blocks deployment if validation fails

**Usage:**
```json
{
  "hooks": {
    "pre-deploy": [
      {
        "type": "skill",
        "name": "dataset-validator-deploy-pre",
        "required": true,
        "failureMode": "stop",
        "timeout": 300
      }
    ]
  }
}
```

**Test independently:**
```bash
export FABER_CLOUD_ENV="test"
export FABER_CLOUD_OPERATION="deploy"
/skill dataset-validator-deploy-pre
```

## Creating Your Own Skill Hooks

### Step 1: Create Skill File

Create `.claude/skills/{skill-name}/SKILL.md`:

```markdown
---
name: my-custom-validator
description: Custom validation logic
tools: Read, Bash
---

# My Custom Validator

<CONTEXT>
You are a custom validator that runs as a faber-cloud hook.
</CONTEXT>

<INPUTS>
WorkflowContext (environment variables):
- FABER_CLOUD_ENV
- FABER_CLOUD_OPERATION
- FABER_CLOUD_HOOK_TYPE
</INPUTS>

<WORKFLOW>
1. Read context
2. Perform validation
3. Return WorkflowResult JSON
</WORKFLOW>

<OUTPUTS>
```json
{
  "success": true/false,
  "messages": [],
  "warnings": [],
  "errors": [],
  "artifacts": {},
  "executionTime": 0,
  "timestamp": "2025-11-07T12:00:00Z",
  "skillName": "my-custom-validator"
}
```
</OUTPUTS>
```

### Step 2: Configure Hook

Add to `.fractary/plugins/faber-cloud/faber-cloud.json`:

```json
{
  "hooks": {
    "pre-deploy": [
      {
        "type": "skill",
        "name": "my-custom-validator",
        "required": true,
        "failureMode": "stop",
        "timeout": 300
      }
    ]
  }
}
```

### Step 3: Test

```bash
# Test skill independently
/skill my-custom-validator

# Test in deployment
/fractary-faber-cloud:deploy-apply --env=test
```

## WorkflowContext Interface

Skills receive context via environment variables:

```bash
FABER_CLOUD_ENV="test"              # Environment name
FABER_CLOUD_OPERATION="deploy"      # Operation type
FABER_CLOUD_HOOK_TYPE="pre-deploy"  # Hook type
FABER_CLOUD_PROJECT="myproject"     # Project name
FABER_CLOUD_SUBSYSTEM="core"        # Subsystem name
FABER_CLOUD_TERRAFORM_DIR="./infra" # Terraform directory
AWS_PROFILE="myproject-core-test"   # AWS profile
```

Or as JSON file (passed as argument):

```json
{
  "workflowType": "infrastructure-deploy",
  "workflowPhase": "pre-deploy",
  "pluginName": "faber-cloud",
  "pluginVersion": "2.0.0",
  "projectName": "myproject",
  "projectRoot": "/path/to/project",
  "environment": "test",
  "operation": "deploy",
  "targetResources": [],
  "flags": {
    "dryRun": false,
    "productionConfirmed": false
  }
}
```

## WorkflowResult Interface

Skills must output JSON to stdout:

```json
{
  "success": true,
  "messages": [
    "Validation started",
    "Checked 10 items",
    "All checks passed"
  ],
  "warnings": [
    "Item X approaching threshold"
  ],
  "errors": [],
  "artifacts": {
    "validationReport": "/path/to/report.json",
    "itemsChecked": 10
  },
  "executionTime": 1234,
  "timestamp": "2025-11-07T12:00:00Z",
  "skillName": "my-validator"
}
```

**Required fields:**
- `success` (boolean)
- `messages` (array)
- `errors` (array)
- `skillName` (string)

**Optional fields:**
- `warnings` (array)
- `artifacts` (object)
- `executionTime` (number, milliseconds)
- `timestamp` (ISO 8601 string)

## Exit Codes

- `0` - Success (validation passed)
- `1` - Failure (validation failed)
- Other - Error (execution problem)

## Best Practices

### 1. Clear Validation Logic

```bash
# Good: Clear success/failure criteria
if [ $ISSUES_FOUND -eq 0 ]; then
  SUCCESS=true
  exit 0
else
  SUCCESS=false
  exit 1
fi
```

### 2. Detailed Messages

```json
{
  "messages": [
    "Validation started for test environment",
    "Checked 5 dataset files",
    "Validated 3 schemas",
    "All quality metrics passed"
  ]
}
```

### 3. Actionable Errors

```json
{
  "errors": [
    "Dataset 'users.csv' schema validation failed",
    "Expected columns: id, name, email",
    "Found columns: id, name (missing: email)",
    "Fix: Add 'email' column to users.csv"
  ]
}
```

### 4. Useful Artifacts

```json
{
  "artifacts": {
    "validationReport": ".fractary/validation-report.json",
    "datasetsValidated": 5,
    "schemasChecked": 3,
    "issuesFound": 0,
    "executionLog": ".fractary/validation.log"
  }
}
```

## Troubleshooting

### Skill Not Found

**Error:** "Skill not found: my-skill"

**Fix:** Ensure skill exists in `.claude/skills/my-skill/SKILL.md`

### Invalid JSON Output

**Error:** "Skill output couldn't be parsed"

**Fix:** Ensure skill outputs valid JSON to stdout

```bash
# Test JSON validity
/skill my-skill | jq .
```

### Timeout

**Error:** "Skill hook timed out"

**Fix:** Increase timeout in configuration

```json
{
  "type": "skill",
  "name": "my-skill",
  "timeout": 600  // Increase from 300
}
```

### Wrong Exit Code

**Error:** "Skill failed but exit code was 0"

**Fix:** Ensure exit code matches success field

```bash
if [ "$SUCCESS" = "true" ]; then
  exit 0
else
  exit 1
fi
```

## See Also

- [Faber-Cloud Hook System Guide](../../guides/HOOKS.md)
- [SPEC-00034: Skill Hook Enhancement](../../../../specs/SPEC-00034-faber-cloud-skill-hooks.md)
- [Hook Configuration Template](../../../templates/config/hooks-example.json)
- [invoke-skill-hook.sh](../../../skills/cloud-common/scripts/invoke-skill-hook.sh)
