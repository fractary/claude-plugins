# Step 3: Design Solution

## Design Resource Architecture

For each identified resource, specify:

### 1. Resource Configuration

**Resource Name Pattern:**
Use naming pattern from config: `{project}-{subsystem}-{environment}-{resource}`

**Resource Specifications:**
- Type (S3, Lambda, DynamoDB, etc.)
- Size/capacity
- Configuration settings
- Integration points

### 2. Security Configuration

**Encryption:**
- At rest: Use AWS-managed or customer-managed KMS keys
- In transit: Enforce HTTPS/TLS

**Access Control:**
- IAM roles with least privilege
- Resource policies
- VPC security groups (if applicable)

**Network Security:**
- VPC placement (public/private subnet)
- Security groups
- Network ACLs

### 3. Reliability Configuration

**High Availability:**
- Multi-AZ deployment where applicable
- Redundancy for critical components
- Backup and recovery strategy

**Monitoring:**
- CloudWatch metrics
- Alarms for critical thresholds
- Log aggregation

### 4. Performance Optimization

**Scaling:**
- Auto-scaling configuration
- Reserved capacity planning
- Performance targets

**Caching:**
- CloudFront for static content
- ElastiCache for data
- Application-level caching

## Cost Estimation

Calculate estimated monthly costs:

```bash
# Example calculation for S3 + CloudFront
# S3 Storage: 100 GB * $0.023 = $2.30
# S3 Requests: 1M PUT * $0.005 = $5.00
# CloudFront Transfer: 500 GB * $0.085 = $42.50
# Total: ~$50/month
```

Document cost breakdown:
- Per-resource costs
- Data transfer costs
- Request/invocation costs
- Total estimated monthly cost

## Design Decisions

Document key design decisions:
- Why this approach vs alternatives?
- Trade-offs considered
- Assumptions made
- Future considerations

## Integration Points

Identify how resources interact:
- Event triggers (S3 → Lambda)
- Data flow (API Gateway → Lambda → DynamoDB)
- Authentication flow (API → Cognito)
- Monitoring flow (All → CloudWatch)

## Security Checklist

Verify security requirements:
- [ ] Encryption at rest enabled
- [ ] Encryption in transit enforced
- [ ] IAM roles follow least privilege
- [ ] Logging enabled for audit trail
- [ ] Monitoring and alerts configured
- [ ] Backup strategy defined
- [ ] Disaster recovery plan outlined
