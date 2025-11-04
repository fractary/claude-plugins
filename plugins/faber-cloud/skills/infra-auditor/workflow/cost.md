# Cost Analysis Audit Workflow

**Check Type**: cost
**Expected Duration**: 3-5 seconds
**Purpose**: Analyze infrastructure cost and identify optimization opportunities

## Workflow Steps

### 1. Query AWS Cost Explorer

```bash
# Get cost for last 30 days for this environment
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://filter.json \
  --profile $profile
```

Filter by environment tags to isolate this deployment.

### 2. Get Cost by Service

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --filter file://filter.json \
  --profile $profile
```

Identify:
- Most expensive services (Lambda, RDS, EC2, S3, etc.)
- Cost breakdown by resource type

### 3. Estimate Monthly Recurring Cost

Based on current resource configuration:
- Lambda: invocations * duration * rate
- RDS: instance hours * rate
- S3: storage GB * rate
- Data transfer costs

### 4. Compare to Budget (if configured)

```bash
# Check if budget is configured for this environment
if [ -n "$BUDGET_MONTHLY" ]; then
  percentage=$((current_cost * 100 / BUDGET_MONTHLY))
  if [ $percentage -gt 80 ]; then
    # Warning: approaching budget
  fi
fi
```

### 5. Identify Cost Optimization Opportunities

Analyze resources for:

**EC2/RDS Rightsizing**:
- Oversized instances (low CPU utilization)
- Underutilized reserved instances
- Idle instances

**S3 Optimization**:
- Objects in expensive storage class
- Eligible for lifecycle policies
- Unoptimized storage (compression, deduplication)

**Lambda Optimization**:
- Over-provisioned memory
- Long-running functions (could be Fargate)
- High invocation costs (could cache results)

**Data Transfer**:
- Cross-region traffic
- Public internet egress
- Could use VPC endpoints

### 6. Check for Cost Anomalies

Compare current month to previous months:
- ⚠️  Cost increased >20% without deployment
- ⚠️  Unexpected charges (new service, unexpected usage)
- ⚠️  Runaway costs (broken loop, DOS attack)

### 7. Generate Cost Report

Format findings:

```markdown
#### ✅ Cost Analysis Complete

**Current Month Cost**: $142.37
**Estimated Monthly Recurring**: $155.00
**Budget**: $200.00 (78% used)

**Cost by Service**:
- Lambda: $62.00 (40%)
- RDS: $48.00 (31%)
- S3: $18.00 (12%)
- CloudWatch: $12.00 (8%)
- Other: $14.37 (9%)

**Cost by Resource** (top 5):
1. RDS instance (db.t3.medium): $48.00/mo
2. Lambda function (api-handler): $35.00/mo
3. Lambda function (background-worker): $27.00/mo
4. S3 bucket (uploads): $18.00/mo
5. CloudWatch logs: $12.00/mo

**Optimization Opportunities**:
1. ⚠️  RDS instance underutilized (20% CPU avg)
   - Recommendation: Downsize to db.t3.small (save ~$24/mo)
2. ⚠️  S3 bucket using Standard storage
   - Recommendation: Add lifecycle policy for objects >30 days → Infrequent Access (save ~$4/mo)
3. ✅ Lambda functions optimized (right-sized memory)

**Cost Trend**:
- Last month: $138.00
- This month: $142.37 (+3%)
- Trend: Stable ✅

**Recommendations**:
1. Consider downsizing RDS instance (potential $24/mo savings)
2. Implement S3 lifecycle policies (potential $4/mo savings)
3. Total potential savings: $28/mo (18%)

**OR if issues:**

#### ⚠️ Cost Concerns Detected

**Current Month Cost**: $287.45 ⚠️
**Estimated Monthly Recurring**: $310.00 ⚠️
**Budget**: $200.00 (144% used) ❌ OVER BUDGET

**Cost Anomaly Detected**:
- Cost increased 65% vs last month
- Cause: Lambda invocations increased 10x
- Investigation: Check for broken retry loop or traffic spike

**Immediate Actions**:
1. Review Lambda invocation logs for anomalies
2. Check for retry loops or error cascades
3. Consider temporary throttling limits
```

### 8. Return Status

- Exit 0: Cost within budget, no anomalies
- Exit 1: Optimization opportunities or approaching budget (warning)
- Exit 2: Over budget or cost anomaly detected (failure)

## Script Execution

Use: `scripts/audit-cost.sh --env={env}`

## Integration

**Weekly Monitoring**: Track cost trends
**Pre-deployment**: Estimate cost impact of changes
**Post-deployment**: Verify cost impact matches estimate
**Budget Reviews**: Monthly cost optimization reviews
