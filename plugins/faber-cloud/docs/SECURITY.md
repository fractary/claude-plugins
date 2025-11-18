# Security Considerations for Faber-Cloud Hooks

```
╔═══════════════════════════════════════════════════════════════════════╗
║                    ⚠️  CRITICAL SECURITY WARNING ⚠️                    ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  HOOKS EXECUTE ARBITRARY CODE WITH DEPLOYMENT PERMISSIONS             ║
║                                                                       ║
║  🚨 NEVER include user-provided input in hook configurations         ║
║  🚨 NEVER execute hooks from untrusted sources                        ║
║  🚨 NEVER use dynamic hook commands with external data                ║
║                                                                       ║
║  COMMAND INJECTION RISK:                                              ║
║  Hook commands execute with bash and have full access to:            ║
║  - AWS credentials (production if deploying to production)            ║
║  - Terraform state files (may contain secrets)                        ║
║  - Project source code and configuration                              ║
║  - Environment variables (including sensitive data)                   ║
║                                                                       ║
║  SAFE PRACTICES:                                                      ║
║  ✅ Use explicit script paths: {"type": "script", "path": "..."}     ║
║  ✅ Store all hook scripts in version control                         ║
║  ✅ Review all hook configurations before deployment                  ║
║  ✅ Use skill hooks for complex logic (validated interface)           ║
║  ✅ Apply principle of least privilege to AWS profiles                ║
║                                                                       ║
║  UNSAFE PRACTICES (DO NOT USE):                                       ║
║  ❌ String hooks with variables: "curl $USER_PROVIDED_URL"           ║
║  ❌ Hooks from environment variables                                  ║
║  ❌ Dynamic hook generation from user input                           ║
║  ❌ Unvetted scripts downloaded at runtime                            ║
║                                                                       ║
║  If you accept user input that affects deployments, ensure hooks     ║
║  are STATICALLY CONFIGURED and cannot be modified by users.          ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
```

## Overview

The faber-cloud hook system allows execution of custom logic at infrastructure lifecycle points. This document outlines security considerations and best practices.

**Read the warning box above carefully before configuring hooks.**

## Hook Types and Security Implications

### Script Hooks

**Execution Model:**
- Execute arbitrary bash commands
- Run with same permissions as hook executor
- Access to all environment variables
- Can modify filesystem

**Security Risks:**

1. **Command Injection**
   - Legacy string hooks execute arbitrary commands
   - User-provided configuration could contain malicious commands
   - Template variables could be exploited if not properly escaped

2. **Privilege Escalation**
   - Hooks run with same AWS credentials as deployment
   - Could access/modify resources beyond intended scope
   - Production hooks have production credentials

3. **Credential Exposure**
   - Environment variables may contain sensitive data
   - AWS credentials available via AWS_PROFILE
   - Terraform state may contain secrets

**Mitigation:**

```json
{
  "hooks": {
    "pre-deploy": [
      {
        "type": "script",
        "path": "./scripts/vetted-script.sh",  // Use explicit paths
        "required": true,
        "timeout": 300  // Enforce timeouts
      }
    ]
  }
}
```

**Best Practices:**
- ✅ Use explicit script paths, not commands
- ✅ Store hook scripts in version control
- ✅ Review all hook scripts before deployment
- ✅ Use least-privilege AWS profiles
- ✅ Set restrictive timeouts
- ✅ Avoid passing secrets via command line
- ✅ Log all hook executions

**Anti-Patterns:**
- ❌ String hooks with user input: `"curl $USER_URL"`
- ❌ Wildcard permissions on hook scripts
- ❌ Executing downloaded scripts without verification
- ❌ Long or unlimited timeouts
- ❌ Hooks that require manual input

### Skill Hooks

**Execution Model:**
- Invoke Claude Code skills
- Run in Claude Code runtime environment
- Receive structured WorkflowContext JSON
- Return structured WorkflowResult JSON

**Security Risks:**

1. **Skill Tampering**
   - Malicious skills could be placed in `.claude/skills/`
   - Skills have access to project files and environment
   - Could exfiltrate data or modify infrastructure

2. **Context Exposure**
   - WorkflowContext may contain sensitive paths
   - Configuration could include internal details
   - Artifacts passed between hooks

3. **Privilege Scope**
   - Skills run with same permissions as hook executor
   - Could invoke other Claude Code tools
   - May access Claude Code API if available

**Mitigation:**

```json
{
  "hooks": {
    "pre-deploy": [
      {
        "type": "skill",
        "name": "approved-validator",  // Only use vetted skills
        "required": true,
        "failureMode": "stop",
        "timeout": 300  // Enforce timeouts
      }
    ]
  }
}
```

**Best Practices:**
- ✅ Only use skills from trusted sources
- ✅ Review skill code before installation
- ✅ Store skills in version control
- ✅ Validate WorkflowContext before passing to skills
- ✅ Audit skill invocations
- ✅ Use sandbox/restricted runtime if available (future)

**Anti-Patterns:**
- ❌ Installing skills from untrusted sources
- ❌ Skills that make external network calls
- ❌ Skills that modify production resources directly
- ❌ Unlimited timeouts

## Temporary Files and Permissions

### WorkflowContext Files

The `invoke-skill-hook.sh` script creates temporary files for WorkflowContext:

```bash
# Creates with restrictive permissions (600 - owner only)
context_file=$(mktemp /tmp/workflow-context.XXXXXX.json)
chmod 600 "$context_file"
trap "rm -f $context_file" EXIT
```

**Why this matters:**
- WorkflowContext contains project paths, environment names
- Other users on system could read without restrictive permissions
- Temporary files persist until cleanup

**Best Practices:**
- ✅ Always set `chmod 600` on temp files with sensitive data
- ✅ Use trap to ensure cleanup on exit
- ✅ Avoid storing secrets in WorkflowContext
- ✅ Minimize data passed via temp files

## Production Deployment Safety

### Overview

The faber-cloud plugin includes a **production safety confirmation protocol** to prevent accidental production deployments. This is separate from hooks security and provides explicit user confirmation before any production deployment.

### Configuration

Production safety is controlled by the `require_confirmation` setting in your environment configuration:

```json
{
  "environments": {
    "test": {
      "auto_approve": false,
      "require_confirmation": false
    },
    "prod": {
      "auto_approve": false,
      "require_confirmation": true
    }
  }
}
```

**Settings:**
- `require_confirmation: true` - Requires explicit 2-step user confirmation
- `require_confirmation: false` - No confirmation required (use for test environments)
- `auto_approve: true` - Bypasses all confirmations (NOT recommended)

### Two-Question Confirmation Protocol

When `require_confirmation: true` for production environments, users must answer two questions:

**Question 1: Validation Confirmation**
```
Have you validated this deployment in TEST environment
and are ready to deploy to PRODUCTION?
Answer (yes/no): _
```

**Question 2: Typed Confirmation**
```
Type 'prod' to confirm deployment to PROD:
Type exactly: _
```

Both confirmations must succeed for deployment to proceed.

### Implementation

Production safety confirmation is executed by:
```bash
bash plugins/faber-cloud/skills/cloud-common/scripts/production-safety-confirm.sh \
  <environment> <operation> [plan_summary_file]
```

This script:
- Displays prominent warning banner
- Shows deployment plan summary (if provided)
- Requires two explicit confirmations
- Aborts deployment if user declines
- Provides clear guidance on next steps

### CI/CD Integration

**Problem:** Interactive confirmations don't work in automated CI/CD pipelines.

**Solution:** Set `DEVOPS_AUTO_APPROVE=true` environment variable in your CI/CD configuration:

```yaml
# Example GitHub Actions
deploy-to-production:
  environment: production
  steps:
    - name: Deploy Infrastructure
      env:
        DEVOPS_AUTO_APPROVE: true  # Bypass interactive confirmation
      run: |
        /faber-cloud:deploy-apply --env=prod
```

**IMPORTANT CI/CD Security:**
- ✅ Only set `DEVOPS_AUTO_APPROVE=true` for approved production deployment jobs
- ✅ Use environment protection rules (GitHub Actions, GitLab Protected Environments)
- ✅ Require manual approval before CI/CD runs production deployment
- ✅ Document approval requirements in CI/CD configuration
- ✅ Audit all production deployments

**Anti-Patterns:**
- ❌ Setting `DEVOPS_AUTO_APPROVE=true` globally
- ❌ Using same job for test and production without environment gates
- ❌ No approval process before automated production deployment

### Bypass Mechanisms (Use with Caution)

**1. Configuration-Level Bypass**
```json
{
  "environments": {
    "prod": {
      "require_confirmation": false  // ⚠️ Not recommended
    }
  }
}
```

**2. Environment Variable Bypass**
```bash
DEVOPS_AUTO_APPROVE=true /faber-cloud:deploy-apply --env=prod
```

**3. Auto-Approve Parameter**
```bash
/faber-cloud:deploy-apply --env=prod --auto-approve
```

**When to Use Bypass:**
- CI/CD pipelines with external approval gates
- Emergency deployments (document reason)
- Automated rollback procedures

**When NOT to Use Bypass:**
- Regular manual deployments
- First-time deployments
- Deployments with unknown impact
- When in doubt

### Comparison: Deploy vs Teardown

| Feature | Deploy (infra-deployer) | Teardown (infra-teardown) |
|---------|-------------------------|---------------------------|
| Questions | 2 | 3 |
| Reason | Deployments reversible | Destruction permanent |
| Can bypass | Yes (with flags) | NO for production |
| CI/CD support | Yes | Limited |

Teardown is more restrictive because resource destruction cannot be undone.

### Security Best Practices

**For Manual Deployments:**
1. ✅ Always enable `require_confirmation: true` for production
2. ✅ Test in non-production environment first
3. ✅ Review terraform plan before confirming
4. ✅ Know your rollback procedure
5. ✅ Have team member review critical changes

**For Automated Deployments:**
1. ✅ Use environment protection with manual approval
2. ✅ Set `DEVOPS_AUTO_APPROVE=true` only in production job
3. ✅ Require code review before merging
4. ✅ Run automated tests in staging first
5. ✅ Monitor deployments with alerting

**Audit Trail:**
All confirmation prompts and responses should be captured in deployment logs for compliance auditing.

## Production Environment Security

### Profile Separation

The faber-cloud plugin uses separate AWS profiles per environment:

```json
{
  "handlers": {
    "hosting": {
      "aws": {
        "profiles": {
          "discover": "project-discover-deploy",
          "test": "project-test-deploy",
          "prod": "project-prod-deploy"
        }
      }
    }
  }
}
```

**Security Model:**
- **discover**: Temporary profile for IAM management
- **test**: Test environment deployment (no IAM permissions)
- **prod**: Production deployment (no IAM permissions)

**Hooks inherit profile:**
- Pre-deploy hooks run with test/prod credentials
- Could access/modify any resource in that environment
- Must be reviewed carefully for production

### Production Hook Checklist

Before deploying hooks to production:

- [ ] All hook scripts reviewed and approved
- [ ] No hardcoded credentials or secrets
- [ ] Timeouts set appropriately
- [ ] Failure modes configured (required hooks should block)
- [ ] Hooks tested in test environment first
- [ ] Audit logging enabled
- [ ] Least-privilege principle applied
- [ ] No external network calls (or approved and documented)
- [ ] Skills from trusted sources only

## Audit and Monitoring

### Hook Execution Logging

All hook executions are logged with:
- Hook name and type
- Environment and operation
- Start time and duration
- Success/failure status
- Exit code

**Log location:** Output of hook executor

**Recommendations:**
- ✅ Capture hook executor output
- ✅ Send to centralized logging (CloudWatch, etc.)
- ✅ Alert on hook failures
- ✅ Monitor for suspicious patterns (unusual execution times, repeated failures)

### Audit Trail

For production environments, maintain audit trail:

```json
{
  "timestamp": "2025-11-07T12:00:00Z",
  "environment": "prod",
  "hook_type": "pre-deploy",
  "hook_name": "build-lambdas",
  "success": true,
  "duration_ms": 45000,
  "user": "deploy-user"
}
```

## Incident Response

### Compromised Hook Script

If a hook script is compromised:

1. **Immediate Actions:**
   - Disable hook in configuration
   - Review recent hook executions
   - Check for unauthorized resource access
   - Rotate AWS credentials if needed

2. **Investigation:**
   - Identify when script was modified
   - Review git history
   - Check for data exfiltration
   - Assess blast radius

3. **Remediation:**
   - Replace with known-good version
   - Update access controls
   - Strengthen review process
   - Document incident

### Suspicious Hook Activity

Signs of compromise:
- ❌ Hook execution times unusually long
- ❌ Hook failures after working previously
- ❌ Unexpected network activity
- ❌ New hooks added without approval
- ❌ Modified hook scripts in version control

**Response:**
1. Investigate immediately
2. Disable suspicious hooks
3. Review CloudWatch logs for resource access
4. Check CloudTrail for API calls
5. Assess damage and contain

## Compliance Considerations

### GDPR / Data Privacy

WorkflowContext may contain:
- Project names (could be customer names)
- Environment names
- File paths
- Configuration data

**Recommendations:**
- ✅ Minimize data in WorkflowContext
- ✅ Don't include customer PII
- ✅ Secure temporary files (chmod 600)
- ✅ Clean up temp files promptly

### SOC 2 / Security Audits

For compliance audits:
- ✅ Document all hooks and their purpose
- ✅ Maintain audit trail of executions
- ✅ Review process for new hooks
- ✅ Approval workflow for production hooks
- ✅ Regular security reviews
- ✅ Access controls on hook scripts

## Security Testing

### Testing Hooks Before Production

1. **Test Environment First:**
   ```bash
   # Test in test environment
   /fractary-faber-cloud:deploy-apply --env=test

   # Review hook output
   # Verify no security issues
   ```

2. **Security Review:**
   - Static analysis of hook scripts
   - Check for command injection vulnerabilities
   - Review AWS API calls
   - Verify no secrets in code

3. **Permission Testing:**
   - Verify hooks work with least-privilege profile
   - Test failure modes
   - Confirm timeouts enforced

### Automated Security Checks

**Pre-commit hooks:**
```bash
# Check for secrets in hook scripts
git diff --cached --name-only | grep 'scripts/' | xargs grep -E 'password|secret|key'

# Verify no hardcoded credentials
git diff --cached --name-only | grep 'scripts/' | xargs grep -E 'AKIA|aws_access_key'
```

## Resources

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [OWASP Command Injection](https://owasp.org/www-community/attacks/Command_Injection)
- [Principle of Least Privilege](https://en.wikipedia.org/wiki/Principle_of_least_privilege)

## Contact

For security concerns or to report vulnerabilities:
- Create issue: https://github.com/fractary/claude-plugins/issues
- Email: [security contact if available]

---

**Last Updated:** 2025-11-07
**Applies To:** faber-cloud plugin v2.3.1+
