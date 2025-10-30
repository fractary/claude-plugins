# Fractary DevOps Plugin - Permission Management

**Version:** 1.0.0

---

## Permission Philosophy

**Principle of Least Privilege with Audit Trail**

### AWS Profile Separation

**Three profiles with strict duties:**

1. **discover-deploy**: `{project}-{subsystem}-discover-deploy`
   - **ONLY** grants IAM permissions
   - **NEVER** deploys infrastructure
   - Used temporarily during development
   - Can be revoked after system stable

2. **test-deploy**: `{project}-{subsystem}-test-deploy`
   - **ONLY** deploys to test environment
   - **NEVER** grants IAM permissions
   - **NEVER** accesses prod resources

3. **prod-deploy**: `{project}-{subsystem}-prod-deploy`
   - **ONLY** deploys to prod environment
   - **NEVER** grants IAM permissions
   - **NEVER** accesses test resources

### Permission Scoping Strategy

**Environment-scoped from start:**

```json
{
  "Resource": "arn:aws:s3:::corthovore-core-test-*"
}
```

**Pattern:** `{project}-{subsystem}-{environment}-*`

**Benefits:**
- Prevents cross-environment accidents
- Works with AWS managed policies
- Avoids policy size limits
- Sufficient for most use cases

**Optional refinement** to specific resources post-deploy:
```json
{
  "Resource": [
    "arn:aws:s3:::corthovore-core-test-uploads",
    "arn:aws:lambda:*:*:function:corthovore-core-test-api"
  ]
}
```

### IAM Audit Trail

**Location:** `.fractary/plugins/faber-cloud/deployments/iam-audit.json`

**Structure:**
```json
{
  "profiles": {
    "test_deploy": {
      "permissions": [
        {
          "action": "s3:PutBucketPolicy",
          "granted_at": "2025-10-28T14:30:00Z",
          "granted_by": "discover-deploy",
          "reason": "Required for terraform to configure S3 bucket policy",
          "terraform_error": "User is not authorized to perform: s3:PutBucketPolicy",
          "environment": "test"
        }
      ]
    }
  }
}
```

### Permission Workflow

1. Deployment fails with permission error
2. `infra-debugger` categorizes as permission error
3. Extract required permission from error
4. Switch to `discover-deploy` profile
5. `infra-permission-manager` grants permission
6. Log in audit trail
7. Switch back to deployment profile
8. Retry deployment

### Enforcement

**Multiple levels:**
- Commands validate profile
- Managers validate profile
- Skills validate profile before AWS operations
- Scripts validate profile

**IMPORTANT keyword used throughout:**
```markdown
**IMPORTANT:** NEVER use discover-deploy for deployment
**IMPORTANT:** NEVER use test/prod-deploy to grant permissions
```

---

See implementation phases for permission system build plan.
