# Drift Detection Audit Workflow

**Check Type**: drift
**Expected Duration**: 5-10 seconds
**Purpose**: Detect configuration drift between Terraform state and AWS reality

## Workflow Steps

### 1. Locate Infrastructure Directory

```bash
infra_dir=$(get_infra_dir_from_config $env)
cd $infra_dir
```

### 2. Ensure Terraform Initialized

```bash
terraform init -backend-config="key=${project}-${subsystem}-${env}.tfstate"
```

### 3. Run Terraform Plan with Detailed Exit Code

```bash
terraform plan -detailed-exitcode -out=/dev/null 2>&1
exit_code=$?
```

Exit codes:
- **0**: No changes (no drift)
- **1**: Error occurred
- **2**: Changes detected (drift exists)

### 4. If Drift Detected, Get Details

```bash
terraform plan -no-color 2>&1 | tee /tmp/drift-report.txt
```

Parse output to identify:
- Resources modified outside Terraform
- Specific attributes that changed
- Type of change (update, delete, recreate)

### 5. Categorize Drift

**Low-Risk Drift** (warnings):
- Tag changes
- Description updates
- Non-functional metadata

**High-Risk Drift** (failures):
- Security group rule changes
- IAM permission changes
- Resource deletion
- Network configuration changes

### 6. Generate Drift Report

Format findings:

```markdown
#### ✅ No Configuration Drift Detected
- Last deployment: {time_ago}
- Terraform state matches AWS reality
- All resources as configured

**OR if drift:**

#### ⚠️ Configuration Drift Detected
- Drift items: {count}
- Last deployment: {time_ago}

**Changes Detected**:

1. **aws_s3_bucket.uploads** (Low Risk)
   - Attribute: `tags`
   - Terraform: `{"Environment": "test"}`
   - AWS: `{"Environment": "test", "Owner": "manual-addition"}`
   - Type: Update in-place
   - Recommendation: Import tag or re-apply Terraform

2. **aws_lambda_function.api_handler** (High Risk)
   - Attribute: `timeout`
   - Terraform: `30`
   - AWS: `60`
   - Type: Update in-place
   - Recommendation: Update Terraform configuration to match, or re-apply

3. **aws_security_group.allow_ssh** (High Risk)
   - Attribute: `ingress`
   - Terraform: Port 22 from 10.0.0.0/8
   - AWS: Port 22 from 0.0.0.0/0 (SECURITY RISK!)
   - Type: Update in-place
   - Recommendation: URGENT - Re-apply Terraform to close security hole

**Summary**:
- Low-risk drift: {count}
- High-risk drift: {count}
- Security issues: {count}

**Recommendations**:
1. Address high-risk drift immediately
2. Review and import or re-apply low-risk changes
3. Consider drift detection automation
```

### 7. Return Status

- Exit 0: No drift detected
- Exit 1: Low-risk drift only (warnings)
- Exit 2: High-risk drift detected (failures)

## Script Execution

Use: `scripts/audit-drift.sh --env={env}`

## Integration

**Regular Monitoring**: Daily drift checks in production
**Pre-deployment**: Ensure clean state before deploying
**Post-deployment**: Verify deployment didn't introduce unexpected drift
**Troubleshooting**: Identify manual changes causing issues
