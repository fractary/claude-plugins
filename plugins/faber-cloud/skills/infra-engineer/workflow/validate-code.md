# Validate Terraform Code

This workflow step validates the generated Terraform code using terraform fmt and terraform validate.

**IMPORTANT:** This step is ALWAYS executed - validation is not optional.

**IMPORTANT:** This step uses the `validate-terraform.sh` script for deterministic validation operations, keeping them outside LLM context to reduce token usage.

## Input

- Generated Terraform files in `./infrastructure/terraform/`
- Configuration for AWS credentials and backend

## Process

### 1. Invoke Validation Script

Execute the validate-terraform.sh script:

```bash
TF_DIR="./infrastructure/terraform"

# Run validation script
VALIDATE_RESULT=$(./scripts/validate-terraform.sh "$TF_DIR")
VALIDATE_EXIT=$?

if [ $VALIDATE_EXIT -ne 0 ]; then
    echo "❌ Terraform validation failed"
    echo "$VALIDATE_RESULT"
    exit 1
fi

echo "✅ Terraform validation passed"
```

The script handles all validation steps:
- Terraform fmt (formatting)
- Terraform init (if needed)
- Terraform validate (syntax/config)
- Common issue checks
- Report generation

### 2. What the Script Does

**Step 1: Format Code**
- Run `terraform fmt -recursive`
- Fixes indentation, aligns equals signs, sorts arguments
- Ensures consistent style

**Step 2: Initialize Terraform (if needed)**
- Check for .terraform directory
- Load backend config from devops.json
- Run terraform init with backend or local state

**Step 3: Validate Syntax**
- Run `terraform validate -json`
- Check HCL syntax correctness
- Verify resource attributes
- Validate variable references
- Check module configuration

**What terraform validate checks:**
- HCL syntax correctness
- Resource attribute validity
- Variable references
- Module configuration
- Provider requirements

### 4. Check for Common Issues

Perform additional checks:

```bash
echo "🔍 Checking for common issues..."

# Check for hardcoded values that should be variables
HARDCODED=$(grep -r "us-east-1" *.tf | grep -v "variable\|default" || true)
if [ -n "$HARDCODED" ]; then
    echo "⚠️  Warning: Found potentially hardcoded values:"
    echo "$HARDCODED"
fi

# Check for missing tags
UNTAGGED=$(grep -r "resource \"aws_" *.tf | grep -v "tags" || true)
if [ -n "$UNTAGGED" ]; then
    echo "⚠️  Warning: Some resources may be missing tags"
fi

# Check for missing encryption
NO_ENCRYPTION=$(grep -r "aws_s3_bucket\"" main.tf | grep -v "encryption" || true)
if [ -n "$NO_ENCRYPTION" ] && grep -q "aws_s3_bucket\"" main.tf; then
    echo "⚠️  Warning: Check S3 buckets have encryption enabled"
fi

echo "✅ Common issue checks complete"
```

### 5. Generate Validation Report

Create summary of validation results:

```bash
cat > validation-report.txt <<EOF
Terraform Validation Report
===========================
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Formatting: ✅ PASSED (terraform fmt)
Syntax: ✅ PASSED (terraform validate)
Common Issues: See warnings above

Files Validated:
$(find . -name "*.tf" -type f)

Resource Count: $(grep -c "^resource " main.tf)

Next Steps:
- Review generated code
- Test with: /fractary-faber-cloud:test
- Preview changes: /fractary-faber-cloud:deploy-plan
EOF

echo "📄 Validation report saved to: validation-report.txt"
```

## Common Validation Errors

### Syntax Errors

**Error: Invalid HCL syntax**
```
Error: Argument or block definition required
  on main.tf line 45:
  45:   bucket ${var.bucket_name}
```
**Fix:** Missing equals sign or incorrect syntax

**Error: Unsupported block type**
```
Error: Unsupported block type
  on main.tf line 30:
  30:   foo {
```
**Fix:** Invalid block name or provider issue

### Reference Errors

**Error: Reference to undeclared variable**
```
Error: Reference to undeclared input variable
  on main.tf line 12:
  12:   region = var.aws_region
```
**Fix:** Add variable declaration to variables.tf

**Error: Reference to undeclared resource**
```
Error: Reference to undeclared resource
  on main.tf line 25:
  25:   bucket_id = aws_s3_bucket.missing.id
```
**Fix:** Resource doesn't exist or typo in name

### Configuration Errors

**Error: Missing required argument**
```
Error: Missing required argument
  on main.tf line 20:
  20: resource "aws_s3_bucket" "example" {
```
**Fix:** Add required attributes (though AWS provider has made most optional)

**Error: Invalid attribute value**
```
Error: Invalid value for variable
  on main.tf line 15:
  15:   environment = "development"
```
**Fix:** Value doesn't match validation constraint

## Output

Return validation results:
```json
{
  "validation_status": "passed|failed",
  "terraform_fmt": "passed",
  "terraform_validate": "passed",
  "issues_found": [],
  "warnings": [
    "Some resources may be missing tags"
  ],
  "report_file": "validation-report.txt"
}
```

## Success Criteria

✅ Terraform fmt completed
✅ Terraform init successful
✅ Terraform validate passed
✅ No critical syntax errors
✅ Validation report generated

## Failure Handling

If validation fails:
1. Show exact error messages
2. Identify which file and line
3. Suggest fix based on error type
4. Do NOT proceed to next steps
5. Return failure status to agent

**The engineer skill MUST NOT complete successfully if validation fails.**
