# Health Check Workflow

## Overview
Check health status of all deployed resources in the environment.

## Process

### 1. Load Resources
```bash
# Read resource registry
registry=".fractary/plugins/faber-cloud/deployments/${environment}/registry.json"
resources=$(jq -r '.resources | to_entries[] | {id: .key, type: .value.type, arn: .value.arn}' ${registry})
```

### 2. Check Each Resource
For each resource, delegate to handler:
```bash
**USE SKILL: handler-hosting-${hosting_handler}**
Operation: get-resource-status
Arguments: ${resource_arn}
```

### 3. Query CloudWatch Metrics
```bash
**USE SKILL: handler-hosting-${hosting_handler}**
Operation: query-metrics
Arguments: ${resource_id} ${metric_names} ${timeframe}
```

### 4. Determine Health Status
- HEALTHY: Running, metrics normal
- DEGRADED: Running, metrics approaching thresholds
- UNHEALTHY: Stopped, failed, or metrics exceeding thresholds

### 5. Generate Report
```json
{
  "overall_health": "HEALTHY|DEGRADED|UNHEALTHY",
  "resources": [
    {
      "id": "api-lambda",
      "type": "Lambda",
      "status": "HEALTHY",
      "metrics": {
        "invocations": 1250,
        "errors": 2,
        "error_rate": "0.16%"
      }
    }
  ]
}
```
