# Troubleshooting Guide

Common issues and solutions for the fractary-faber-cloud plugin.

## Permission Errors

### Issue: "AccessDenied" during deployment

**Error:**
```
Error: User is not authorized to perform: s3:PutBucketPolicy
```

**Solution:**
The plugin can auto-fix permission errors:

1. When error occurs, debugger analyzes it
2. Plugin offers to auto-grant permission
3. Accept the automated fix: "yes"
4. Deployment retries automatically

**Manual fix:**
```bash
/fractary-faber-cloud:infra-manage debug --error="<error message>"
# Follow instructions to grant permission manually
```

### Issue: Wrong AWS profile being used

**Error:**
```
Error: Using test profile for production deployment
```

**Solution:**
1. Check your AWS profile configuration:
   ```bash
   aws configure list-profiles
   ```

2. Verify config file has correct profiles:
   ```bash
   cat .fractary/plugins/faber-cloud/config/devops.json
   ```

3. Update profiles in config if needed:
   ```json
   {
     "handlers": {
       "hosting": {
         "aws": {
           "profiles": {
             "test": "correct-test-profile",
             "prod": "correct-prod-profile"
           }
         }
       }
     }
   }
   ```

## Configuration Errors

### Issue: Terraform syntax errors

**Error:**
```
Error: Invalid resource block on main.tf line 45
```

**Solution:**
1. View the specific error in the file:
   ```bash
   cat infrastructure/terraform/main.tf | sed -n '40,50p'
   ```

2. Fix the syntax error

3. Validate before deploying:
   ```bash
   /fractary-faber-cloud:director "validate configuration"
   ```

### Issue: Configuration file not found

**Error:**
```
Error: Configuration file not found at .fractary/plugins/faber-cloud/config/devops.json
```

**Solution:**
Initialize the configuration:
```bash
/fractary-faber-cloud:init --provider=aws --iac=terraform
```

## Deployment Errors

### Issue: State lock errors

**Error:**
```
Error: state is locked. Lock ID: abc123
```

**Solution:**
1. Wait for other operation to complete (5-10 minutes)

2. If still locked after 15 minutes, force unlock:
   ```bash
   cd infrastructure/terraform
   terraform force-unlock abc123
   ```

3. Retry deployment

### Issue: Resource already exists

**Error:**
```
Error: S3 bucket "my-bucket" already exists
```

**Solutions:**

**Option 1: Import existing resource**
```bash
cd infrastructure/terraform
terraform import aws_s3_bucket.my_bucket my-bucket
```

**Option 2: Remove existing resource** (careful!)
```bash
aws s3 rb s3://my-bucket --force
```

**Option 3: Rename in Terraform**
Change the resource name in your `main.tf`

### Issue: Deployment timeout

**Error:**
```
Error: Timeout waiting for resource to be ready
```

**Solution:**
1. Check AWS Console to see resource status

2. If resource is creating, wait and retry

3. If resource failed, check CloudWatch logs:
   ```bash
   /fractary-faber-cloud:director "show me logs from <service>"
   ```

## Director Routing Issues

### Issue: Director doesn't understand request

**Error:**
```
I don't understand that request. Please rephrase.
```

**Solution:**
Use more specific keywords:

**Instead of:** "do something with my app"
**Try:** "deploy my infrastructure to test"

**Instead of:** "check stuff"
**Try:** "check health of my services"

**Keywords that work:**
- Infrastructure: deploy, design, validate, preview, engineer
- Operations: check, health, investigate, logs, remediate, audit

### Issue: Ambiguous routing

**Response:**
```
Your request could mean:
1. Check health (ops-manager)
2. Validate config (infra-manager)
Choose one:
```

**Solution:**
Be more specific or choose from options:
- "check health" for operations
- "validate config" for infrastructure

## Operations Errors

### Issue: No CloudWatch metrics found

**Error:**
```
Error: No metrics found for resource
```

**Causes:**
1. Resource just deployed (wait 5-10 minutes for metrics)
2. CloudWatch not enabled
3. Wrong resource name

**Solution:**
1. Wait 10 minutes after deployment

2. Verify resource exists:
   ```bash
   /fractary-faber-cloud:director "show deployed resources"
   ```

3. Check CloudWatch permissions:
   ```bash
   aws cloudwatch describe-alarms --region us-east-1
   ```

### Issue: Cannot restart service

**Error:**
```
Error: Cannot restart Lambda function
```

**Solution:**
1. Check if resource exists:
   ```bash
   aws lambda get-function --function-name my-function
   ```

2. Verify permissions:
   ```bash
   aws lambda update-function-code --help
   ```

3. Use correct service name from registry

## Testing Errors

### Issue: Security scan fails

**Error:**
```
Checkov not found
```

**Solution:**
Install security scanning tools:
```bash
pip install checkov
pip install tfsec
```

Or skip tests (not recommended):
```bash
/fractary-faber-cloud:infra-manage deploy --env=test --skip-tests
```

### Issue: Cost estimation errors

**Error:**
```
Cannot estimate costs
```

**Solution:**
1. Ensure Terraform files have resource counts

2. Check AWS Pricing API access

3. Cost estimation is best-effort, continue if needed

## Performance Issues

### Issue: Operations too slow

**Symptoms:**
- Health checks take >60 seconds
- Deployments take >10 minutes

**Solutions:**

1. **Reduce resources checked:**
   Check specific services instead of all:
   ```bash
   /fractary-faber-cloud:ops-manage check-health --env=test --service=api-lambda
   ```

2. **Optimize Terraform:**
   - Use targeted applies: `terraform apply -target=resource`
   - Reduce unnecessary resources

3. **Check AWS region:**
   Use region closest to you:
   ```json
   {
     "handlers": {
       "hosting": {
         "aws": {
           "region": "us-east-1"
         }
       }
     }
   }
   ```

## Common Error Messages

### "Handler not found"

**Cause:** Invalid handler configuration

**Fix:**
```json
{
  "handlers": {
    "hosting": {"active": "aws"},
    "iac": {"active": "terraform"}
  }
}
```

### "Skill invocation failed"

**Cause:** Skill encountered unrecoverable error

**Fix:**
1. Read the error details
2. Follow specific guidance
3. Check logs at `.fractary/plugins/faber-cloud/logs/`

### "Environment not configured"

**Cause:** Missing environment configuration

**Fix:**
Add environment to config:
```json
{
  "environments": {
    "test": {
      "auto_approve": false
    }
  }
}
```

### "Pattern substitution failed"

**Cause:** Missing variable in pattern

**Fix:**
Ensure all pattern variables are defined:
```json
{
  "project": {
    "name": "my-project",
    "subsystem": "core"
  },
  "resource_naming": {
    "pattern": "{project}-{subsystem}-{environment}-{resource}"
  }
}
```

## Debug Mode

Enable detailed logging:

```bash
# Set debug mode in config
{
  "debug": true,
  "log_level": "debug"
}
```

Check logs:
```bash
tail -f .fractary/plugins/faber-cloud/logs/debug.log
```

## Getting Additional Help

If you're still stuck:

1. **Check documentation:**
   - [Getting Started](getting-started.md)
   - [User Guide](user-guide.md)
   - [README](../../README.md)
   - [Architecture](../architecture/ARCHITECTURE.md)

2. **Review generated docs:**
   - Registry: `.fractary/plugins/faber-cloud/deployments/{env}/registry.json`
   - Deployed: `.fractary/plugins/faber-cloud/deployments/{env}/DEPLOYED.md`
   - Issue log: `.fractary/plugins/faber-cloud/deployments/issue-log.json`

3. **File an issue:**
   - GitHub: https://github.com/fractary/claude-plugins/issues
   - Include: Error message, command used, relevant config

## Prevention Tips

**Avoid common issues:**

1. **Always test first:**
   ```bash
   /fractary-faber-cloud:director "deploy to test"
   # Verify everything works before production
   ```

2. **Use natural language:**
   It's more forgiving and easier to understand

3. **Review previews:**
   Always check what will change before deploying

4. **Let errors auto-fix:**
   Accept automated fixes for permission errors

5. **Keep config updated:**
   Ensure profiles and paths are correct

6. **Monitor regularly:**
   Catch issues before they become problems

7. **Read error messages:**
   They contain specific guidance and solutions

## Quick Diagnostic Commands

```bash
# Check configuration
cat .fractary/plugins/faber-cloud/config/devops.json

# Verify AWS credentials
aws sts get-caller-identity

# List AWS profiles
aws configure list-profiles

# Check Terraform
terraform version
cd infrastructure/terraform && terraform validate

# View deployed resources
/fractary-faber-cloud:director "show resources"

# Check recent errors
cat .fractary/plugins/faber-cloud/deployments/issue-log.json | jq '.statistics'
```

## FAQ

**Q: Can I skip pre-deployment tests?**
A: Yes, use `--skip-tests` flag, but not recommended.

**Q: How do I use a different AWS region?**
A: Update config file `handlers.hosting.aws.region`

**Q: Can I deploy without approval?**
A: For test: yes. For production: no (safety feature).

**Q: What if auto-fix fails?**
A: Follow manual instructions provided in error message.

**Q: How do I roll back a deployment?**
A: Use Terraform: `cd infrastructure/terraform && terraform destroy -target=<resource>`

**Q: Can I use multiple AWS accounts?**
A: Yes, configure different profiles per environment.

**Q: How often should I run health checks?**
A: Recommended: Every hour for production, daily for test.

---

For more information, see:
- [Getting Started](getting-started.md)
- [User Guide](user-guide.md)
- [README](../../README.md)
