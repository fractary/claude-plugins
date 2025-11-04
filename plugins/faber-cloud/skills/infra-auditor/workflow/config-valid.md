# Config Valid Audit Workflow

**Check Type**: config-valid
**Expected Duration**: 2-3 seconds
**Purpose**: Verify Terraform configuration syntax and structure

## Workflow Steps

### 1. Locate Infrastructure Directory

```bash
# Determine infrastructure directory from config
infra_dir=$(get_infra_dir_from_config $env)
```

### 2. Run Terraform Validation

```bash
cd $infra_dir
terraform validate -json
```

### 3. Check Syntax

Verify:
- ✅ Configuration is syntactically valid
- ✅ All required variables are defined
- ✅ No circular dependencies
- ✅ Module sources are accessible
- ✅ Provider requirements met

### 4. Check Backend Configuration

Verify:
- ✅ Backend configured correctly
- ✅ State file accessible (if exists)
- ✅ Locking configured (DynamoDB table exists)

### 5. Check Variable Definitions

Verify:
- ✅ All variables have types
- ✅ Required variables have no defaults
- ✅ Variable files exist (.tfvars)
- ✅ Environment-specific variables defined

### 6. Generate Report

Format findings:

```markdown
#### ✅ Terraform Configuration Valid
- Syntax: Valid
- Variables: All defined ({count} total)
- Backend: Configured (S3 + DynamoDB)
- Modules: All accessible ({count} modules)
- Provider: AWS provider configured

**OR if issues:**

#### ❌ Terraform Configuration Invalid
- Syntax: 3 errors found
- Error 1: {error message}
- Error 2: {error message}
- Recommendation: Fix syntax errors and re-run validation
```

### 7. Return Status

- Exit 0: Configuration valid
- Exit 2: Configuration invalid (critical)

## Script Execution

Use: `scripts/audit-config.sh --env={env}`

## Integration

**Pre-deployment**: Always run before engineering or deploying
**Post-deployment**: Run to verify state is consistent
**Troubleshooting**: First check when debugging issues
