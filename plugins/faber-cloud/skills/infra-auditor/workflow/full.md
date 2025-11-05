# Full Comprehensive Audit Workflow

**Check Type**: full
**Expected Duration**: 20-30 seconds
**Purpose**: Comprehensive audit (all checks)

## Workflow Steps

### 1. Initialize Audit

Set start time, initialize report structure.

```bash
start_time=$(date +%s)
report_file="/tmp/audit-full-${env}-$(date +%Y%m%d-%H%M%S).md"
```

### 2. Run All Check Types in Sequence

Execute each audit check type, collecting results:

#### Check 1: Config Valid
```bash
./scripts/audit-config.sh --env=$env
config_status=$?
```

Store results in report.

#### Check 2: IAM Health
```bash
./scripts/audit-iam.sh --env=$env
iam_status=$?
```

Store results in report.

#### Check 3: Drift Detection
```bash
./scripts/audit-drift.sh --env=$env
drift_status=$?
```

Store results in report.

#### Check 4: Security Posture
```bash
./scripts/audit-security.sh --env=$env
security_status=$?
```

Store results in report.

#### Check 5: Cost Analysis
```bash
./scripts/audit-cost.sh --env=$env
cost_status=$?
```

Store results in report.

### 3. Aggregate Results

Calculate overall status:
- **Pass** (0): All checks passed
- **Warning** (1): Some warnings, no failures
- **Fail** (2): One or more checks failed

```bash
max_status=0
for status in $config_status $iam_status $drift_status $security_status $cost_status; do
  if [ $status -gt $max_status ]; then
    max_status=$status
  fi
done
```

### 4. Calculate Summary Metrics

Count totals across all checks:
- Total passing checks
- Total warnings
- Total failures

Example:
- Config: 5 passing, 0 warnings, 0 failures
- IAM: 4 passing, 2 warnings, 0 failures
- Drift: 0 passing, 3 warnings, 0 failures
- Security: 12 passing, 2 warnings, 1 failure
- Cost: 3 passing, 1 warning, 0 failures
**Total: 24 passing, 8 warnings, 1 failure**

### 5. Prioritize Recommendations

Collect all recommendations from individual checks and prioritize:

**Priority 1 (Critical - Must Fix)**:
- Security failures
- Configuration drift with security impact
- IAM permission failures

**Priority 2 (Important - Should Fix)**:
- Cost over budget
- High-risk drift
- Security warnings

**Priority 3 (Optimization - Nice to Have)**:
- Cost optimization opportunities
- Low-risk drift
- IAM cleanup

### 6. Generate Comprehensive Report

Format aggregated findings:

```markdown
## Comprehensive Audit Report: infrastructure/{env}

**Timestamp**: {ISO8601}
**Duration**: {duration}s
**Overall Status**: {PASS/WARN/FAIL}

### Executive Summary
✅ {passing} passing
⚠️  {warnings} warnings
❌ {failures} failures

### Audit Results by Category

#### 1. Configuration Validation ✅
- Status: PASSED
- Terraform configuration valid
- All variables defined
- Backend configured correctly
- Duration: 2.3s

#### 2. IAM Health Check ⚠️
- Status: WARNING
- Deploy user: Healthy
- Service roles: All present
- ⚠️  Access keys >90 days old (rotation recommended)
- ⚠️  1 unused IAM role found
- Duration: 4.1s

#### 3. Drift Detection ⚠️
- Status: WARNING
- Drift items detected: 3
- Low-risk: 2 (tags, descriptions)
- High-risk: 1 (Lambda timeout)
- ⚠️  Manual changes found
- Duration: 7.8s

#### 4. Security Posture ❌
- Status: FAILED
- Security groups: 1 critical issue
- S3 buckets: All secure
- RDS instances: All secure
- ❌ SSH port open to internet (sg-abc123)
- ⚠️  MFA not enforced on all users
- Duration: 5.9s

#### 5. Cost Analysis ⚠️
- Status: WARNING
- Current month: $142.37
- Estimated monthly: $155.00
- Budget: $200.00 (78% used)
- ⚠️  RDS instance underutilized
- Optimization potential: $28/mo
- Duration: 3.2s

### Infrastructure Metrics
- **Total resources**: 42
- **Drift items**: 3
- **Security issues**: 1 critical, 2 warnings
- **Cost**: $142.37 current, $155.00 projected
- **Last deployment**: 2 days ago

### Prioritized Recommendations

**🔴 CRITICAL (Fix Immediately)**:
1. Close SSH security group to internet (security risk)

**🟡 IMPORTANT (Fix Soon)**:
1. Rotate IAM access keys (>90 days old)
2. Address configuration drift (Lambda timeout)
3. Remove unused IAM role

**🟢 OPTIMIZATION (Consider)**:
1. Downsize RDS instance (save $24/mo)
2. Add S3 lifecycle policies (save $4/mo)
3. Import manual tag changes to Terraform

### Next Steps

**Before Deployment**:
- ❌ BLOCKED: Fix critical security issue first
- Address important warnings
- Optimization items can be deferred

**For Production Health**:
- Schedule daily drift detection
- Weekly cost reviews
- Monthly full audits

### Detailed Findings

[Include detailed output from each check type]

---
**End of Comprehensive Audit Report**
```

### 7. Calculate Duration

```bash
end_time=$(date +%s)
duration=$((end_time - start_time))
```

### 8. Return Aggregated Status

- Exit 0: All checks passed
- Exit 1: Warnings found, no failures
- Exit 2: One or more checks failed

## Script Execution

Use: `scripts/audit-full.sh --env={env}`

## Integration

**Pre-deployment**: Complete readiness verification
**Post-deployment**: Complete health validation
**Scheduled**: Weekly/monthly full audits for compliance
**Troubleshooting**: Comprehensive state gathering before debugging
