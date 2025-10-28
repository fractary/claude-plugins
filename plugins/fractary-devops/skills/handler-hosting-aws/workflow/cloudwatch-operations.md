# CloudWatch Operations Workflow

## Overview
CloudWatch operations for monitoring, logging, and metrics in AWS.

## Operations

### 1. Get Resource Status
```bash
# Get current status of Lambda
aws lambda get-function --function-name ${function_name} --query 'Configuration.State'

# Get RDS instance status
aws rds describe-db-instances --db-instance-identifier ${db_id} --query 'DBInstances[0].DBInstanceStatus'

# Get ECS service status
aws ecs describe-services --cluster ${cluster} --services ${service} --query 'services[0].status'
```

### 2. Query Metrics
```bash
# Get Lambda invocation metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=${function_name} \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum,Average,Maximum

# Get Lambda error metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=${function_name} \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### 3. Query Logs
```bash
# Query CloudWatch logs with filter
aws logs filter-log-events \
  --log-group-name /aws/lambda/${function_name} \
  --start-time $(($(date +%s) - 3600)) \
  --filter-pattern "${filter_pattern}" \
  --query 'events[*].[timestamp,message]' \
  --output text
```

### 4. Restart Service
```bash
# Update Lambda configuration (triggers restart)
aws lambda update-function-configuration \
  --function-name ${function_name} \
  --description "Restarted at $(date)"

# Restart ECS service
aws ecs update-service \
  --cluster ${cluster} \
  --service ${service} \
  --force-new-deployment
```

### 5. Scale Service
```bash
# Scale ECS service
aws ecs update-service \
  --cluster ${cluster} \
  --service ${service} \
  --desired-count ${new_count}

# Update Lambda concurrency
aws lambda put-function-concurrency \
  --function-name ${function_name} \
  --reserved-concurrent-executions ${concurrency}
```

## Permissions Required

CloudWatch operations require:
- `cloudwatch:GetMetricStatistics`
- `cloudwatch:ListMetrics`
- `logs:FilterLogEvents`
- `logs:DescribeLogGroups`
- `lambda:GetFunction`
- `lambda:UpdateFunctionConfiguration`
- `ecs:DescribeServices`
- `ecs:UpdateService`
- `rds:DescribeDBInstances`
