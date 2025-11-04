# Phase 6: Testing & Validation - faber-cloud v2.1

**Parent Spec**: `faber-cloud-v2.1-simplification.md`
**Estimated Effort**: 1 hour

## Overview

Comprehensive testing plan to validate all changes across commands, agents, skills, documentation, and configuration.

## Testing Layers

### Layer 1: Command Testing
### Layer 2: Agent Testing
### Layer 3: Skill Testing
### Layer 4: Integration Testing
### Layer 5: Feature Testing

---

## Layer 1: Command Testing

### Objective
Verify all commands route correctly and parse arguments properly.

### Test Cases

#### 1.1 Command Invocation

**Test all renamed commands**:
```bash
# Core commands
/fractary-faber-cloud:init
/fractary-faber-cloud:manage status

# Lifecycle commands
/fractary-faber-cloud:design "Test feature description"
/fractary-faber-cloud:configure
/fractary-faber-cloud:validate
/fractary-faber-cloud:test
/fractary-faber-cloud:deploy-plan
/fractary-faber-cloud:deploy-apply --env=test
/fractary-faber-cloud:status
/fractary-faber-cloud:resources
/fractary-faber-cloud:debug
/fractary-faber-cloud:teardown --env=test

# Natural language interface
/fractary-faber-cloud:director design monitoring for Lambda
```

**Expected Results**:
- [ ] All commands execute without "command not found" errors
- [ ] Commands route to correct agents
- [ ] Help text displays correctly for each command

#### 1.2 Argument Parsing

**Test quoted descriptions** (spaces in arguments):
```bash
/fractary-faber-cloud:design "Add CloudWatch monitoring for Lambda functions"
/fractary-faber-cloud:design "Multi word description with many spaces"
/fractary-faber-cloud:manage design "Another test with spaces"
```

**Expected Results**:
- [ ] Descriptions with spaces parse correctly (not split into multiple args)
- [ ] Full description passed to agent
- [ ] No "unexpected argument" errors

#### 1.3 Flags and Options

**Test command flags**:
```bash
/fractary-faber-cloud:deploy-apply --env=test
/fractary-faber-cloud:deploy-apply --env=prod
/fractary-faber-cloud:debug --complete
/fractary-faber-cloud:teardown --env=test --confirm
/fractary-faber-cloud:resources --env=staging
```

**Expected Results**:
- [ ] Flags parse correctly
- [ ] Environment values passed to agents
- [ ] Boolean flags (--complete, --confirm) recognized
- [ ] Invalid flags rejected with helpful error

#### 1.4 manage Command Operations

**Test all manage operations**:
```bash
/fractary-faber-cloud:manage design "Test"
/fractary-faber-cloud:manage configure
/fractary-faber-cloud:manage validate
/fractary-faber-cloud:manage test
/fractary-faber-cloud:manage deploy-plan
/fractary-faber-cloud:manage deploy-apply --env=test
/fractary-faber-cloud:manage status
/fractary-faber-cloud:manage resources
/fractary-faber-cloud:manage debug
/fractary-faber-cloud:manage teardown --env=test
```

**Expected Results**:
- [ ] All operations recognized
- [ ] Routes to infra-manager correctly
- [ ] Help text shows all operations
- [ ] Invalid operations rejected with error

---

## Layer 2: Agent Testing

### Objective
Verify agent routing and workflow orchestration.

### Test Cases

#### 2.1 cloud-director Routing

**Test natural language parsing**:
```bash
/fractary-faber-cloud:director design infrastructure for monitoring
/fractary-faber-cloud:director can you preview the deployment changes
/fractary-faber-cloud:director deploy to test environment
/fractary-faber-cloud:director debug the errors automatically
/fractary-faber-cloud:director destroy test infrastructure
```

**Expected Results**:
- [ ] cloud-director parses natural language correctly
- [ ] Maps to correct operations (design, deploy-plan, deploy-apply, debug, teardown)
- [ ] Routes to infra-manager (NOT skills directly)
- [ ] Structured request passed to infra-manager

**Validation**:
```bash
# Check agent invocation in output
# Should see: "Use the @agent-fractary-faber-cloud:infra-manager..."
# Should NOT see: "Use the @skill-fractary-faber-cloud:..."
```

#### 2.2 infra-manager Operation Routing

**Test operation → skill routing**:

For each operation, verify it routes to correct skill:

| Operation | Expected Skill |
|-----------|---------------|
| design | infra-designer |
| configure | infra-configurator |
| validate | infra-validator |
| test | infra-tester |
| deploy-plan | infra-planner |
| deploy-apply | infra-deployer |
| status | infra-deployer |
| resources | infra-deployer |
| debug | infra-debugger |
| teardown | infra-teardown |

**Test commands**:
```bash
/fractary-faber-cloud:design "Test" # → infra-designer
/fractary-faber-cloud:configure     # → infra-configurator
/fractary-faber-cloud:deploy-plan   # → infra-planner
/fractary-faber-cloud:debug         # → infra-debugger
```

**Expected Results**:
- [ ] infra-manager receives operation from command/cloud-director
- [ ] Routes to correct skill for each operation
- [ ] Passes parameters correctly to skills
- [ ] Returns structured results

#### 2.3 Architecture Validation

**Critical validation**:
- [ ] cloud-director NEVER invokes skills directly
- [ ] Commands → cloud-director → infra-manager → skills flow correct
- [ ] infra-manager is only agent that invokes skills
- [ ] No commands bypass agents to invoke skills directly

---

## Layer 3: Skill Testing

### Objective
Verify skill renames and enhancements work correctly.

### Test Cases

#### 3.1 Renamed Skills

**Test each renamed skill**:
```bash
# infra-designer (was infra-architect)
/fractary-faber-cloud:design "Add monitoring"

# infra-configurator (was infra-engineer)
/fractary-faber-cloud:configure

# infra-planner (was infra-previewer)
/fractary-faber-cloud:deploy-plan

# cloud-common (was devops-common)
# (tested implicitly by all operations)
```

**Expected Results**:
- [ ] Renamed skills invoked correctly
- [ ] Skill functionality unchanged
- [ ] Start/end messages show correct skill names
- [ ] No references to old skill names in output

#### 3.2 infra-debugger --complete Flag

**Test interactive mode** (default, no flag):
```bash
# Trigger deployment error (e.g., missing IAM permission)
/fractary-faber-cloud:deploy-apply --env=test

# Select Option 1: Run debug (interactive)
/fractary-faber-cloud:debug
```

**Expected Behavior**:
- [ ] Shows error diagnosis
- [ ] Shows proposed fix
- [ ] Prompts for approval before applying fix
- [ ] Waits for user input at each step
- [ ] Does NOT return to parent automatically

**Test automated mode** (with --complete flag):
```bash
# Trigger deployment error
/fractary-faber-cloud:deploy-apply --env=test

# Select Option 2: Run debug --complete
# (or invoke directly)
/fractary-faber-cloud:debug --complete
```

**Expected Behavior**:
- [ ] Auto-fixes all errors without prompts
- [ ] Shows fixes applied
- [ ] Returns control to infra-deployer automatically
- [ ] Deployment continues from where it failed
- [ ] All in one automated flow

#### 3.3 infra-permission-manager Audit System

**Test IAM audit scripts**:
```bash
# Navigate to IAM policies directory
cd infrastructure/iam-policies/

# Test update-audit.sh
../../plugins/faber-cloud/skills/infra-permission-manager/scripts/audit/update-audit.sh \
  test "lambda:CreateFunction,lambda:UpdateFunctionCode" "Deployment requires Lambda"

# Verify audit file updated
cat test-deploy-permissions.json | jq '.audit_trail[-1]'

# Test sync-from-aws.sh (requires AWS credentials)
../../plugins/faber-cloud/skills/infra-permission-manager/scripts/audit/sync-from-aws.sh test

# Test diff-audit-aws.sh
../../plugins/faber-cloud/skills/infra-permission-manager/scripts/audit/diff-audit-aws.sh test

# Test apply-to-aws.sh (requires AWS credentials and caution!)
# ../../plugins/faber-cloud/skills/infra-permission-manager/scripts/audit/apply-to-aws.sh test
```

**Expected Results**:
- [ ] update-audit.sh adds entry to audit_trail
- [ ] Audit file JSON valid after update
- [ ] sync-from-aws.sh fetches current AWS policy
- [ ] diff-audit-aws.sh shows differences
- [ ] apply-to-aws.sh applies permissions (manual verification)

**Test deploy vs resource permission validation**:
```bash
# Request resource permission (should be rejected)
# Manually invoke permission-manager with resource permission request
# Example: "Lambda needs to read from S3 bucket"
```

**Expected Results**:
- [ ] Plugin identifies request as resource permission
- [ ] Rejects request with explanation
- [ ] Provides Terraform example code
- [ ] Does NOT add to audit file

#### 3.4 infra-deployer Environment Safety

**Test environment validation**:
```bash
# Set up mismatch scenario
export ENV=test
cd infrastructure/terraform
terraform workspace select prod

# Attempt deployment (should fail validation)
/fractary-faber-cloud:deploy-apply --env=test
```

**Expected Results**:
- [ ] Safety validation runs before deployment
- [ ] Detects environment mismatch (ENV=test, workspace=prod)
- [ ] STOPS deployment immediately
- [ ] Shows clear error message
- [ ] Does NOT proceed with terraform apply

**Test TodoWrite tracking**:
```bash
# Run deployment and watch for checklist
/fractary-faber-cloud:deploy-apply --env=test
```

**Expected Results**:
- [ ] TodoWrite creates 12-step checklist
- [ ] Each step marked in_progress → completed
- [ ] User can see progress in real-time
- [ ] Completed steps remain visible

#### 3.5 infra-teardown Safety

**Test non-production teardown**:
```bash
/fractary-faber-cloud:teardown --env=test
```

**Expected Results**:
- [ ] State backed up before destruction
- [ ] 1 confirmation requested
- [ ] Shows resources to be destroyed
- [ ] Shows cost savings estimate
- [ ] Executes terraform destroy
- [ ] Verifies all resources removed
- [ ] Documents in deployment history

**Test production teardown** (manual, careful!):
```bash
# DO NOT run on real production!
/fractary-faber-cloud:teardown --env=prod
```

**Expected Results**:
- [ ] 3 separate confirmations required
- [ ] User must type "prod" to confirm
- [ ] --confirm flag rejected for production
- [ ] Extended timeout (30 min vs 10 min)
- [ ] Extra checkpoint after plan review

**Test --confirm flag**:
```bash
# Non-production (should work)
/fractary-faber-cloud:teardown --env=test --confirm

# Production (should be rejected)
/fractary-faber-cloud:teardown --env=prod --confirm
```

**Expected Results**:
- [ ] --confirm works for non-production
- [ ] --confirm rejected for production with error message

---

## Layer 4: Integration Testing

### Objective
Test complete workflows end-to-end.

### Test Cases

#### 4.1 Full Deployment Workflow

**Complete infrastructure lifecycle**:
```bash
# Step 1: Design
/fractary-faber-cloud:design "Add CloudWatch monitoring for Lambda functions"

# Step 2: Configure
/fractary-faber-cloud:configure

# Step 3: Validate
/fractary-faber-cloud:validate

# Step 4: Test
/fractary-faber-cloud:test

# Step 5: Plan
/fractary-faber-cloud:deploy-plan

# Step 6: Apply
/fractary-faber-cloud:deploy-apply --env=test
```

**Expected Results**:
- [ ] Each step completes successfully
- [ ] Output from previous step feeds into next
- [ ] Files created in correct locations (specs/, terraform/, plans/)
- [ ] Deployment history updated
- [ ] DEPLOYED.md generated

#### 4.2 Error Recovery Workflow

**Automated fix-and-continue**:
```bash
# Step 1: Trigger deployment with permission error
# (Remove IAM permission or use fresh environment)
/fractary-faber-cloud:deploy-apply --env=test
# → Deployment fails with AccessDenied

# Step 2: Select Option 2 (automated debugging)
# → Plugin offers 3 options
# → Select: "Run debug --complete"

# Expected flow:
# 1. infra-debugger invoked with --complete flag
# 2. Categorizes error as permission issue
# 3. Delegates to infra-permission-manager
# 4. Permission-manager updates audit file
# 5. Applies permission to AWS
# 6. Returns to infra-debugger
# 7. infra-debugger returns to infra-deployer
# 8. Deployment continues automatically
# 9. Completes successfully
```

**Expected Results**:
- [ ] Error detected and categorized correctly
- [ ] Delegation chain works (deployer → debugger → permission-manager)
- [ ] Permission added to audit file
- [ ] Permission applied to AWS
- [ ] Control returns to deployer
- [ ] Deployment continues and completes
- [ ] All automated without manual intervention

#### 4.3 Teardown Workflow

**Complete destruction**:
```bash
# Step 1: Preview destruction
/fractary-faber-cloud:deploy-plan --destroy

# Step 2: Execute teardown
/fractary-faber-cloud:teardown --env=test

# Step 3: Verify removal
# Check AWS console or CLI
aws lambda list-functions --profile test-deploy
aws s3 ls --profile test-deploy
```

**Expected Results**:
- [ ] State backed up before destruction
- [ ] All resources destroyed
- [ ] Verification confirms removal
- [ ] Teardown documented in deployments.md
- [ ] Backup available at infrastructure/backups/

---

## Layer 5: Feature Testing

### Objective
Validate new features work as designed.

### Test Cases

#### 5.1 Configuration Migration

**Test backward compatibility**:
```bash
# Rename config to old name
mv .fractary/plugins/faber-cloud/config/faber-cloud.json \
   .fractary/plugins/faber-cloud/config/devops.json

# Run command
/fractary-faber-cloud:init
```

**Expected Results**:
- [ ] Deprecation warning shown
- [ ] Offers to migrate to faber-cloud.json
- [ ] If accepted: File renamed automatically
- [ ] If declined: Uses devops.json but warns

**Test migration script**:
```bash
./plugins/faber-cloud/scripts/migrate-config.sh
```

**Expected Results**:
- [ ] Detects devops.json
- [ ] Prompts for confirmation
- [ ] Creates backup (devops.json.backup)
- [ ] Renames to faber-cloud.json
- [ ] Updates schema version to 2.1.0
- [ ] Adds new sections (iam_audit, safety)

#### 5.2 Documentation Validation

**Check all documentation**:
```bash
# Verify README renders correctly
# (Check on GitHub or with markdown viewer)
cat plugins/faber-cloud/README.md

# Verify all links work
# Check cross-references in specs
ls docs/specs/faber-cloud-*

# Verify no broken references
grep -r "devops-director" plugins/faber-cloud/
grep -r "devops.json" plugins/faber-cloud/
grep -r "infra-architect" plugins/faber-cloud/
grep -r "infra-engineer" plugins/faber-cloud/
grep -r "infra-previewer" plugins/faber-cloud/
```

**Expected Results**:
- [ ] No references to old names in user-facing docs
- [ ] All internal links work
- [ ] All examples execute correctly
- [ ] Code snippets syntactically valid
- [ ] README renders properly

#### 5.3 Deployment History

**Test history logging**:
```bash
# Run deployment
/fractary-faber-cloud:deploy-apply --env=test

# Check history file
cat docs/infrastructure/deployments.md
```

**Expected Results**:
- [ ] New entry appended to deployments.md
- [ ] Includes: timestamp, environment, deployer, resources, cost
- [ ] Format matches template
- [ ] Markdown valid

**Test teardown logging**:
```bash
# Run teardown
/fractary-faber-cloud:teardown --env=test

# Check history file
cat docs/infrastructure/deployments.md
```

**Expected Results**:
- [ ] Teardown entry appended
- [ ] Includes: resources removed, cost savings, reason, backup path

---

## Testing Checklist

### Pre-Testing Setup

- [ ] Backup existing configuration
- [ ] Create test AWS environment (or use sandbox)
- [ ] Set up AWS credentials for test environment
- [ ] Initialize test Terraform state
- [ ] Prepare test infrastructure code

### Command Layer

- [ ] All renamed commands execute
- [ ] Argument parsing with quotes works
- [ ] Flags and options parse correctly
- [ ] manage command operations work
- [ ] Help text displays correctly

### Agent Layer

- [ ] cloud-director routes to infra-manager (not skills)
- [ ] infra-manager routes to correct skills
- [ ] Natural language parsing works
- [ ] Structured requests passed correctly

### Skill Layer

- [ ] Renamed skills work (infra-designer, infra-configurator, infra-planner)
- [ ] infra-debugger --complete flag works
- [ ] IAM audit system works (all scripts)
- [ ] Deploy vs resource permission validation works
- [ ] Environment safety validation works
- [ ] TodoWrite tracking works
- [ ] infra-teardown safety features work

### Integration

- [ ] Full deployment workflow completes
- [ ] Error recovery with --complete flag works
- [ ] Teardown workflow completes
- [ ] Delegation chain works (deployer → debugger → permission-manager)

### Features

- [ ] Configuration migration works
- [ ] Backward compatibility works (devops.json)
- [ ] Documentation complete and accurate
- [ ] Deployment history logging works
- [ ] All new features documented

---

## Test Environments

### Recommended Test Setup

1. **Sandbox AWS Account**: Use separate AWS account for testing
2. **Test Infrastructure**: Simple resources (Lambda, S3, CloudWatch)
3. **IAM Roles**: Pre-configured with some permissions, intentionally missing others
4. **Terraform State**: Separate state for testing

### Safety Precautions

- [ ] NEVER test on production infrastructure
- [ ] Use test/sandbox AWS accounts only
- [ ] Back up state files before testing teardown
- [ ] Verify test environment isolated from production
- [ ] Review Terraform plans before applying

---

## Success Criteria

All test cases must pass:

- [ ] All commands execute without errors
- [ ] All agents route correctly
- [ ] All skills function properly
- [ ] All integrations work end-to-end
- [ ] All new features operational
- [ ] No references to old names in output
- [ ] Documentation accurate and complete
- [ ] Configuration migration works
- [ ] IAM audit system functional
- [ ] Environment safety validation works
- [ ] Automated debugging works with --complete flag
- [ ] Teardown safety features work

---

## Bug Reporting

If issues found during testing:

1. **Document the issue**:
   - What were you testing?
   - What command did you run?
   - What was expected?
   - What actually happened?
   - Error messages (full output)

2. **Categorize the issue**:
   - Command layer
   - Agent layer
   - Skill layer
   - Integration
   - Documentation
   - Configuration

3. **Assess severity**:
   - Blocker (prevents release)
   - Critical (major functionality broken)
   - Major (important feature broken)
   - Minor (cosmetic or edge case)

4. **Create fix**:
   - Identify root cause
   - Implement fix
   - Re-test affected area
   - Verify fix doesn't break other areas

---

## Rollback Plan

If critical issues found:

1. **Immediate rollback**:
   ```bash
   git checkout main
   git reset --hard <commit-before-v2.1>
   ```

2. **Document issues**: Create detailed issue report

3. **Revise specifications**: Update specs based on findings

4. **Re-implement**: Address issues and retry

---

## Sign-Off

Testing complete when:

- [ ] All test cases passed
- [ ] All critical bugs fixed
- [ ] Documentation reviewed and approved
- [ ] Migration tested and validated
- [ ] Performance acceptable
- [ ] Security review passed (IAM audit system)
- [ ] User experience validated

**Approvals Required**:
- [ ] Technical Lead
- [ ] Security Review (for IAM audit system)
- [ ] Documentation Review
- [ ] User Experience Review

---

## Next Steps

After Phase 6 completion:

1. **Tag release**: `git tag v2.1.0`
2. **Update changelog**: Document all changes
3. **Release notes**: Prepare user-facing release notes
4. **Announce**: Communicate changes to users
5. **Monitor**: Watch for issues after release
6. **Support**: Provide migration assistance

---

## Related Specifications

- `faber-cloud-v2.1-simplification.md` - Main specification
- `faber-cloud-v2.1-phase1-commands.md` - Command changes
- `faber-cloud-v2.1-phase2-agents.md` - Agent changes
- `faber-cloud-v2.1-phase3-skills.md` - Skill changes
- `faber-cloud-v2.1-phase4-documentation.md` - Documentation changes
- `faber-cloud-v2.1-phase5-configuration.md` - Configuration changes
