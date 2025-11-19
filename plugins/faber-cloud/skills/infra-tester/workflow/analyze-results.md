# Test Results Analysis Workflow

## Overview
Analyze test results, categorize findings, determine overall status, and generate actionable recommendations.

## Result Categorization

### Severity Levels

**CRITICAL:**
- Security vulnerabilities allowing unauthorized access
- Missing required tags or naming violations in production
- Resources in failed state
- Data encryption disabled for sensitive data
- Public access to private resources

**HIGH:**
- Security best practices violations
- Configuration drift from expected state
- Missing monitoring for critical resources
- Cost significantly exceeds budget
- Integration tests failing

**MEDIUM:**
- Optional security hardening opportunities
- Non-critical configuration differences
- Missing optional tags
- Cost approaching budget threshold
- Performance optimization opportunities

**LOW:**
- Documentation inconsistencies
- Minor naming convention deviations
- Optional features not enabled
- Informational findings

### Status Determination

**Overall test status logic:**

```
FAIL if:
  - Any CRITICAL findings
  - 3+ HIGH findings
  - Any resource missing (post-deployment)
  - Terraform validation fails
  - Required integration tests fail

WARN if:
  - 1-2 HIGH findings
  - 5+ MEDIUM findings
  - Cost 80-100% of budget
  - Resources still initializing (post-deployment)
  - Optional tests skipped

PASS if:
  - No CRITICAL or HIGH findings
  - < 5 MEDIUM findings
  - All required tests passed
  - Cost within budget
```

## Analysis Steps

### 1. Aggregate Test Results

```bash
# Collect results from all test phases
test_results_dir="${output_dir}/test-results"
all_findings=()

# Merge findings from all tests
for test_result in ${test_results_dir}/*.json; do
  test_name=$(basename ${test_result} .json)
  test_status=$(jq -r '.status' ${test_result})
  test_findings=$(jq -r '.findings[]' ${test_result})

  # Add to aggregated findings
  all_findings+=("${test_findings}")
done
```

### 2. Categorize Findings

```bash
# Categorize by severity
critical_findings=$(echo "${all_findings}" | jq '[.[] | select(.severity == "CRITICAL")]')
high_findings=$(echo "${all_findings}" | jq '[.[] | select(.severity == "HIGH")]')
medium_findings=$(echo "${all_findings}" | jq '[.[] | select(.severity == "MEDIUM")]')
low_findings=$(echo "${all_findings}" | jq '[.[] | select(.severity == "LOW")]')

# Count findings
critical_count=$(echo "${critical_findings}" | jq 'length')
high_count=$(echo "${high_findings}" | jq 'length')
medium_count=$(echo "${medium_findings}" | jq 'length')
low_count=$(echo "${low_findings}" | jq 'length')
```

### 3. Determine Overall Status

```bash
overall_status="PASS"

# Check for FAIL conditions
if [[ ${critical_count} -gt 0 ]]; then
  overall_status="FAIL"
  reason="Critical findings detected"
elif [[ ${high_count} -ge 3 ]]; then
  overall_status="FAIL"
  reason="Multiple high-severity findings"
elif [[ "${validation_failed}" == "true" ]]; then
  overall_status="FAIL"
  reason="Terraform validation failed"
fi

# Check for WARN conditions
if [[ "${overall_status}" == "PASS" ]]; then
  if [[ ${high_count} -ge 1 ]] && [[ ${high_count} -le 2 ]]; then
    overall_status="WARN"
    reason="High-severity findings detected"
  elif [[ ${medium_count} -ge 5 ]]; then
    overall_status="WARN"
    reason="Multiple medium-severity findings"
  elif [[ "${cost_warning}" == "true" ]]; then
    overall_status="WARN"
    reason="Cost approaching budget threshold"
  fi
fi
```

### 4. Generate Recommendations

```bash
recommendations=()

# Critical findings → Immediate action required
if [[ ${critical_count} -gt 0 ]]; then
  for finding in $(echo "${critical_findings}" | jq -c '.[]'); do
    issue=$(echo "${finding}" | jq -r '.description')
    resource=$(echo "${finding}" | jq -r '.resource')

    case "${issue}" in
      *"public access"*)
        recommendations+=("URGENT: Enable S3 public access block for ${resource}")
        ;;
      *"encryption"*)
        recommendations+=("URGENT: Enable encryption at rest for ${resource}")
        ;;
      *"security group"*)
        recommendations+=("URGENT: Restrict security group ${resource} from 0.0.0.0/0")
        ;;
    esac
  done
fi

# High findings → Action recommended
if [[ ${high_count} -gt 0 ]]; then
  for finding in $(echo "${high_findings}" | jq -c '.[]'); do
    issue=$(echo "${finding}" | jq -r '.description')
    resource=$(echo "${finding}" | jq -r '.resource')

    recommendations+=("Review and address: ${issue} for ${resource}")
  done
fi

# Medium findings → Suggestions
if [[ ${medium_count} -gt 0 ]]; then
  # Group by category
  security_medium=$(echo "${medium_findings}" | jq '[.[] | select(.category == "security")] | length')
  cost_medium=$(echo "${medium_findings}" | jq '[.[] | select(.category == "cost")] | length')
  config_medium=$(echo "${medium_findings}" | jq '[.[] | select(.category == "configuration")] | length')

  if [[ ${security_medium} -gt 0 ]]; then
    recommendations+=("Consider ${security_medium} security hardening opportunities")
  fi
  if [[ ${cost_medium} -gt 0 ]]; then
    recommendations+=("Review ${cost_medium} cost optimization suggestions")
  fi
  if [[ ${config_medium} -gt 0 ]]; then
    recommendations+=("Review ${config_medium} configuration improvements")
  fi
fi

# Cost-specific recommendations
if [[ -n "${estimated_cost}" ]]; then
  if (( $(echo "${estimated_cost} > ${budget_threshold}" | bc -l) )); then
    recommendations+=("URGENT: Estimated cost \$${estimated_cost}/month exceeds budget \$${budget_threshold}/month")
  elif (( $(echo "${estimated_cost} > ${budget_threshold} * 0.8" | bc -l) )); then
    recommendations+=("Cost \$${estimated_cost}/month is approaching budget limit")
  fi

  # Top cost drivers
  top_costs=$(jq -r '.cost_breakdown | to_entries | sort_by(.value) | reverse | .[0:3] | .[] | "\(.key): $\(.value)"' ${cost_report})
  recommendations+=("Top cost drivers: ${top_costs}")
fi
```

### 5. Threshold Checks

```bash
# Check against configured thresholds from config
config_path=".fractary/plugins/faber-cloud/devops.json"

# Security thresholds
max_critical=$(jq -r '.testing.thresholds.max_critical_findings // 0' ${config_path})
max_high=$(jq -r '.testing.thresholds.max_high_findings // 2' ${config_path})

if [[ ${critical_count} -gt ${max_critical} ]]; then
  overall_status="FAIL"
  threshold_violations+=("Critical findings (${critical_count}) exceed threshold (${max_critical})")
fi

if [[ ${high_count} -gt ${max_high} ]]; then
  if [[ "${overall_status}" == "PASS" ]]; then
    overall_status="WARN"
  fi
  threshold_violations+=("High findings (${high_count}) exceed threshold (${max_high})")
fi

# Cost threshold
cost_threshold=$(jq -r '.testing.thresholds.max_monthly_cost // 1000' ${config_path})
if (( $(echo "${estimated_cost} > ${cost_threshold}" | bc -l) )); then
  overall_status="FAIL"
  threshold_violations+=("Estimated cost (\$${estimated_cost}) exceeds threshold (\$${cost_threshold})")
fi
```

## Analysis Output Format

```json
{
  "analysis": {
    "timestamp": "2025-10-28T10:30:45Z",
    "overall_status": "PASS|WARN|FAIL",
    "reason": "Primary reason for status",

    "findings_summary": {
      "critical": 0,
      "high": 1,
      "medium": 3,
      "low": 5,
      "total": 9
    },

    "findings_by_category": {
      "security": 4,
      "cost": 2,
      "configuration": 2,
      "compliance": 1
    },

    "threshold_violations": [
      "Description of any threshold violations"
    ],

    "recommendations": [
      "Prioritized list of actions",
      "Most critical first",
      "Specific and actionable"
    ],

    "cost_analysis": {
      "estimated_monthly_cost": "45.30",
      "budget_threshold": "100.00",
      "percentage_of_budget": "45.3%",
      "top_cost_drivers": [
        {"resource": "RDS", "cost": "25.00"},
        {"resource": "Lambda", "cost": "12.30"},
        {"resource": "S3", "cost": "8.00"}
      ]
    },

    "next_steps": {
      "if_pass": "Proceed with deployment",
      "if_warn": "Review warnings and confirm deployment",
      "if_fail": "Address critical issues before deployment"
    }
  }
}
```

## Environment-Specific Analysis

### Production Environment
- **Stricter thresholds**: Zero tolerance for critical findings
- **Required tags**: All tags must be present
- **Monitoring**: All monitoring must be configured
- **Cost**: More rigorous cost analysis

### Test Environment
- **Relaxed thresholds**: Allow some medium findings
- **Optional tags**: Warnings for missing tags
- **Monitoring**: Optional monitoring allowed
- **Cost**: Less strict cost limits

## Trend Analysis

Compare current results with historical test data:

```bash
# Load historical test results
history_file=".fractary/plugins/faber-cloud/test-reports/${environment}/history.json"

# Calculate trends
previous_critical=$(jq -r '.[-1].findings_summary.critical' ${history_file})
trend_critical=$((critical_count - previous_critical))

if [[ ${trend_critical} -gt 0 ]]; then
  recommendations+=("WARNING: Security posture degrading - ${trend_critical} more critical findings than last test")
elif [[ ${trend_critical} -lt 0 ]]; then
  recommendations+=("POSITIVE: Security posture improving - ${trend_critical} fewer critical findings")
fi
```

## Report Generation

Generate final report combining all analysis:

```bash
# Create comprehensive report
report_path=".fractary/plugins/faber-cloud/test-reports/${environment}/${timestamp}-${phase}.json"

jq -n \
  --arg status "${overall_status}" \
  --arg phase "${phase}" \
  --arg env "${environment}" \
  --argjson findings "${all_findings}" \
  --argjson recommendations "${recommendations}" \
  --argjson cost_analysis "${cost_analysis}" \
  '{
    phase: $phase,
    environment: $env,
    timestamp: now | todate,
    overall_status: $status,
    findings: $findings,
    recommendations: $recommendations,
    cost_analysis: $cost_analysis
  }' > ${report_path}

echo "Report generated: ${report_path}"
```
