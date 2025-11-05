# Security Posture Audit Workflow

**Check Type**: security
**Expected Duration**: 5-7 seconds
**Purpose**: Security and compliance checks

## Workflow Steps

### 1. Run Security Group Analysis

```bash
# List all security groups for environment
aws ec2 describe-security-groups \
  --filters "Name=tag:Environment,Values=$env" \
  --profile $profile
```

Check for:
- ❌ Ingress rules from 0.0.0.0/0 (open to internet)
- ❌ Egress rules to 0.0.0.0/0 (unrestricted outbound)
- ⚠️  Overly broad port ranges
- ⚠️  Unnecessary services exposed

### 2. Check S3 Bucket Security

```bash
# List S3 buckets for environment
aws s3api list-buckets --profile $profile
```

For each bucket:
```bash
# Check public access
aws s3api get-public-access-block --bucket $bucket --profile $profile
aws s3api get-bucket-acl --bucket $bucket --profile $profile

# Check encryption
aws s3api get-bucket-encryption --bucket $bucket --profile $profile

# Check versioning
aws s3api get-bucket-versioning --bucket $bucket --profile $profile
```

Check for:
- ❌ Public buckets (ACL or policy allows public access)
- ❌ Unencrypted buckets
- ⚠️  Versioning disabled
- ⚠️  No lifecycle policies

### 3. Check RDS Security

```bash
# List RDS instances for environment
aws rds describe-db-instances \
  --filters "Name=tag:Environment,Values=$env" \
  --profile $profile
```

Check for:
- ❌ Publicly accessible databases
- ❌ Unencrypted storage
- ❌ Unencrypted backups
- ⚠️  Automated backups disabled
- ⚠️  Multi-AZ disabled (for prod)
- ⚠️  No deletion protection

### 4. Check EBS Volume Encryption

```bash
# List EBS volumes
aws ec2 describe-volumes \
  --filters "Name=tag:Environment,Values=$env" \
  --profile $profile
```

Check for:
- ❌ Unencrypted volumes
- ⚠️  Snapshots not encrypted

### 5. Check Lambda Function Security

```bash
# List Lambda functions
aws lambda list-functions --profile $profile
```

For each function:
```bash
# Check VPC configuration
aws lambda get-function-configuration --function-name $fn --profile $profile

# Check environment variables (secrets handling)
# Check execution role permissions
```

Check for:
- ⚠️  Functions not in VPC (if accessing RDS/private resources)
- ⚠️  Plaintext secrets in environment variables
- ⚠️  Overprivileged execution roles

### 6. Check IAM Password Policy

```bash
aws iam get-account-password-policy --profile discover-deploy
```

Check for:
- ⚠️  No minimum password length requirement
- ⚠️  No password complexity requirements
- ⚠️  No password expiration
- ⚠️  Password reuse allowed

### 7. Check CloudTrail Logging

```bash
aws cloudtrail describe-trails --profile $profile
aws cloudtrail get-trail-status --name $trail --profile $profile
```

Check for:
- ❌ CloudTrail not enabled
- ⚠️  Log file validation disabled
- ⚠️  Multi-region not enabled

### 8. Run CIS Benchmark Checks

Basic CIS AWS Foundations Benchmark checks:
- ⚠️  Root account usage
- ⚠️  MFA not enabled on root
- ⚠️  Security contact not configured
- ⚠️  IAM policies with full * * permissions

### 9. Check Resource Tagging Compliance

Verify all resources have required tags:
- ❌ Missing Environment tag
- ❌ Missing Project tag
- ⚠️  Missing Owner tag
- ⚠️  Missing CostCenter tag

### 10. Generate Security Report

Format findings:

```markdown
#### ✅ Security Posture: Good

**Security Groups**: {count} groups
- ✅ No open ingress from internet
- ✅ Egress properly restricted

**S3 Buckets**: {count} buckets
- ✅ All buckets private
- ✅ All buckets encrypted (AES-256)
- ✅ Versioning enabled on {count} buckets

**RDS Instances**: {count} instances
- ✅ All private (not publicly accessible)
- ✅ Storage encrypted
- ✅ Automated backups enabled

**EBS Volumes**: {count} volumes
- ✅ All encrypted

**Lambda Functions**: {count} functions
- ✅ Running in VPC
- ✅ No plaintext secrets
- ⚠️  1 function has overprivileged role

**Compliance**:
- ✅ CloudTrail enabled
- ✅ Log file validation enabled
- ⚠️  MFA not enforced on all users

**Tagging**: {percent}% compliant
- ✅ All resources have Environment tag
- ⚠️  2 resources missing Owner tag

**Recommendations**:
1. Review Lambda execution role for api-handler (reduce permissions)
2. Enforce MFA on all IAM users
3. Add Owner tags to untagged resources

**OR if critical issues:**

#### ❌ Security Issues Found

**CRITICAL ISSUES** (must fix immediately):

1. **Security Group: allow-all-ssh**
   - Severity: CRITICAL
   - Issue: SSH (port 22) open to 0.0.0.0/0
   - Risk: Unauthorized access to instances
   - Recommendation: Restrict to specific IP ranges

2. **S3 Bucket: public-uploads**
   - Severity: CRITICAL
   - Issue: Bucket is publicly accessible
   - Risk: Data exposure, unauthorized access
   - Recommendation: Remove public ACL, enforce private access

3. **RDS Instance: main-db**
   - Severity: CRITICAL
   - Issue: Database is publicly accessible
   - Risk: Unauthorized database access
   - Recommendation: Disable public accessibility

**WARNINGS** (should fix soon):

4. **Lambda Function: data-processor**
   - Severity: WARNING
   - Issue: AWS Access Key in environment variables
   - Risk: Secret exposure in logs/errors
   - Recommendation: Use AWS Secrets Manager or Parameter Store

5. **Account Configuration**
   - Severity: WARNING
   - Issue: MFA not enforced
   - Risk: Account compromise
   - Recommendation: Enforce MFA for all IAM users

**Summary**:
- Critical issues: 3 ❌
- Warnings: 2 ⚠️
- Passed checks: 15 ✅

**Immediate Actions Required**:
1. Close security group to internet
2. Make S3 bucket private
3. Disable public access on RDS
```

### 11. Return Status

- Exit 0: No security issues
- Exit 1: Warnings only (non-critical)
- Exit 2: Critical security issues found

## Script Execution

Use: `scripts/audit-security.sh --env={env}`

## Integration

**Pre-deployment**: Verify security posture before deploying
**Post-deployment**: Confirm no security issues introduced
**Regular**: Daily security checks in production
**Compliance**: Weekly/monthly compliance audits
