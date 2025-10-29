# Pre-Deployment Testing Workflow

## Overview
Execute comprehensive tests before infrastructure deployment to catch issues early.

## Test Suite

### 1. Security Scanning

**Test: Checkov Security Scan**
```bash
# Install checkov if not available
if ! command -v checkov &> /dev/null; then
  echo "Installing Checkov..."
  pip install checkov --quiet
fi

# Run Checkov scan
echo "Running Checkov security scan..."
checkov -d ${terraform_dir} --output json --quiet > ${test_output_dir}/checkov-results.json

# Parse results
critical_count=$(jq '[.results.failed_checks[] | select(.check_class == "checkov.terraform")] | length' ${test_output_dir}/checkov-results.json)
```

**Test: tfsec Security Scan**
```bash
# Install tfsec if not available
if ! command -v tfsec &> /dev/null; then
  echo "Installing tfsec..."
  curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
fi

# Run tfsec scan
echo "Running tfsec security scan..."
tfsec ${terraform_dir} --format json --out ${test_output_dir}/tfsec-results.json --soft-fail

# Parse results
high_severity=$(jq '[.results[] | select(.severity == "HIGH" or .severity == "CRITICAL")] | length' ${test_output_dir}/tfsec-results.json)
```

**Security Test Criteria:**
- ✅ PASS: No critical or high severity issues
- ⚠️ WARN: Medium severity issues only
- ❌ FAIL: Any critical or high severity issues

### 2. Cost Estimation

**Test: Terraform Cost Estimation**
```bash
# Use terraform show to get planned resources
cd ${terraform_dir}
terraform init -input=false > /dev/null 2>&1
terraform plan -out=tfplan.binary > /dev/null 2>&1
terraform show -json tfplan.binary > ${test_output_dir}/plan.json

# Analyze resources for cost estimation
# Extract resource types and counts
resource_summary=$(jq '[.planned_values.root_module.resources[] | {type: .type, name: .name}]' ${test_output_dir}/plan.json)

# Cost estimation logic (simplified - real implementation would use AWS Pricing API)
# For now, provide resource counts and estimated ranges
```

**Cost Estimation Method:**
1. Extract resource types from plan
2. Count instances of each resource type
3. Apply approximate cost per resource type:
   - S3 buckets: $0.023/GB + requests
   - Lambda: $0.20 per 1M requests
   - EC2: varies by instance type
   - RDS: varies by instance type
   - API Gateway: $3.50 per million API calls
4. Sum total estimated monthly cost

**Cost Test Criteria:**
- ✅ PASS: Cost within configured budget threshold
- ⚠️ WARN: Cost 80-100% of budget threshold
- ❌ FAIL: Cost exceeds budget threshold

### 3. Terraform Validation

**Test: Terraform Syntax Validation**
```bash
cd ${terraform_dir}
terraform init -input=false > /dev/null 2>&1
terraform validate -json > ${test_output_dir}/validate-results.json

validation_status=$(jq -r '.valid' ${test_output_dir}/validate-results.json)
```

**Validation Criteria:**
- ✅ PASS: valid == true
- ❌ FAIL: valid == false

### 4. Configuration Compliance

**Test: Naming Convention Check**
```bash
# Extract resource names from plan
resource_names=$(jq -r '[.planned_values.root_module.resources[] | .values.tags.Name // .name] | .[]' ${test_output_dir}/plan.json)

# Check against naming pattern from config
naming_pattern="${project}-${subsystem}-${environment}-"

# Verify all resources follow pattern
non_compliant=()
for name in ${resource_names}; do
  if [[ ! $name =~ ^${naming_pattern} ]]; then
    non_compliant+=("$name")
  fi
done
```

**Compliance Criteria:**
- ✅ PASS: All resources follow naming convention
- ❌ FAIL: Any resources violate naming convention

### 5. Tagging Compliance

**Test: Required Tags Check**
```bash
# Extract tags from planned resources
resources_with_tags=$(jq '[.planned_values.root_module.resources[] | {name: .name, tags: .values.tags}]' ${test_output_dir}/plan.json)

# Required tags from config
required_tags=("Environment" "Project" "Subsystem" "ManagedBy")

# Check each resource has required tags
missing_tags=()
for resource in $(echo "$resources_with_tags" | jq -c '.[]'); do
  resource_name=$(echo "$resource" | jq -r '.name')
  for tag in "${required_tags[@]}"; do
    has_tag=$(echo "$resource" | jq -r ".tags.${tag} // empty")
    if [[ -z "$has_tag" ]]; then
      missing_tags+=("${resource_name}:${tag}")
    fi
  done
done
```

**Tagging Criteria:**
- ✅ PASS: All resources have all required tags
- ⚠️ WARN: Some optional tags missing
- ❌ FAIL: Required tags missing

## Test Execution Order

1. Terraform Validation (must pass to continue)
2. Security Scanning (Checkov + tfsec in parallel)
3. Configuration Compliance (naming + tagging)
4. Cost Estimation

## Result Aggregation

```json
{
  "phase": "pre-deployment",
  "environment": "${environment}",
  "timestamp": "${timestamp}",
  "overall_status": "PASS|WARN|FAIL",
  "tests": [
    {
      "name": "checkov_security",
      "status": "PASS|FAIL",
      "findings": [...],
      "duration_ms": 1234
    },
    {
      "name": "tfsec_security",
      "status": "PASS|FAIL",
      "findings": [...],
      "duration_ms": 987
    },
    {
      "name": "terraform_validation",
      "status": "PASS|FAIL",
      "errors": [...],
      "duration_ms": 456
    },
    {
      "name": "naming_compliance",
      "status": "PASS|FAIL",
      "non_compliant": [...],
      "duration_ms": 123
    },
    {
      "name": "tagging_compliance",
      "status": "PASS|FAIL",
      "missing_tags": [...],
      "duration_ms": 234
    },
    {
      "name": "cost_estimation",
      "status": "PASS|WARN|FAIL",
      "estimated_monthly_cost": "45.30",
      "cost_threshold": "100.00",
      "resource_breakdown": {...},
      "duration_ms": 567
    }
  ],
  "summary": {
    "total_tests": 6,
    "passed": 5,
    "warnings": 1,
    "failed": 0,
    "critical_issues": 0,
    "total_duration_ms": 3601
  },
  "recommendations": [
    "Consider enabling S3 bucket versioning for backup",
    "Review Lambda memory allocation for cost optimization"
  ]
}
```

## Critical Issues List

**Block deployment if:**
- Critical or HIGH security vulnerabilities
- Terraform validation fails
- Required tags missing
- Cost exceeds threshold (unless user override)

**Warn but allow deployment if:**
- Medium security findings
- Optional tags missing
- Cost approaching threshold (80-100%)
