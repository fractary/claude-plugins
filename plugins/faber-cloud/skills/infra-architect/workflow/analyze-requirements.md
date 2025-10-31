# Step 1: Analyze Requirements

## Parse Feature Description

Extract key information from the feature description:

1. **Core Functionality:** What does this feature do?
2. **Data Requirements:** What data needs to be stored/processed?
3. **Access Patterns:** Who accesses it? How often?
4. **Performance Needs:** Latency requirements? Throughput?
5. **Security Requirements:** Authentication? Authorization? Compliance?

## Identify Infrastructure Needs

Based on the feature, determine what AWS services are needed:

### Storage Needs
- **Object Storage:** S3 for files, media, static content
- **Database:** DynamoDB for NoSQL, RDS for relational
- **Cache:** ElastiCache for frequently accessed data

### Compute Needs
- **Serverless:** Lambda for event-driven, variable load
- **Containers:** ECS/Fargate for containerized apps
- **Instances:** EC2 for specific requirements

### Networking Needs
- **API:** API Gateway for REST/HTTP APIs
- **CDN:** CloudFront for content delivery
- **Load Balancing:** ALB/NLB for traffic distribution

### Security Needs
- **Authentication:** Cognito for user management
- **Secrets:** Secrets Manager for credentials
- **Encryption:** KMS for key management

### Monitoring Needs
- **Logs:** CloudWatch Logs
- **Metrics:** CloudWatch Metrics
- **Alerts:** CloudWatch Alarms, SNS

## List Required Resources

Create a preliminary list of AWS resources needed:

```
Example for "User Uploads Feature":
1. S3 bucket (storage)
2. Lambda function (processing)
3. CloudFront distribution (delivery)
4. IAM role (permissions)
5. CloudWatch log group (monitoring)
```

## Document Requirements

Save analyzed requirements for design phase:
- Functional requirements
- Non-functional requirements (performance, security, etc.)
- Constraints (budget, region, compliance)
- Assumptions made
