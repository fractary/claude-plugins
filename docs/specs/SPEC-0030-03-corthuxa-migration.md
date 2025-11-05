# SPEC-0030-03: Corthuxa Infrastructure Migration to faber-cloud

**Issue**: #30
**Phase**: 3 (Corthuxa Migration)
**Dependencies**: SPEC-0030-01 (faber-cloud migration features), SPEC-0030-02 (Corthovore migration - lessons learned)
**Status**: Draft
**Created**: 2025-01-15

## Overview

Migrate the `core.corthuxa.ai` project from its custom infrastructure manager agents to the fractary-faber-cloud plugin. This project manages Astro/Hugo static site generation with Corthography integration, featuring Lambda builds, multi-site management, and a sophisticated 4-skill architecture.

**Project Location**: `C:\GitHub\corthos\core.corthuxa.ai` (Windows) or `/mnt/c/GitHub/corthos/core.corthuxa.ai` (WSL)

**Goal**: Successfully transition Corthuxa to use faber-cloud while preserving Lambda build workflows, multi-site management, Corthography integration, and gaining enhanced capabilities.

## Background

### Current Infrastructure

**Purpose**: Static site generator with Corthography chunk-based builds

**Terraform Structure**: Flat structure with feature-specific files
- Location: `infrastructure/terraform/`
- Files: `main.tf`, `variables.tf`, `outputs.tf`
- Feature files: `corthography-*.tf`, `phase2-*.tf`, `base-*.tf`
- Environment configs: `test.tfvars`, `prod.tfvars`

**AWS Resources** (~60+ total):
- **Storage**: S3 buckets (input, output, site hosting, Corthography chunks)
- **Compute**: Lambda functions (build triggers), AWS Batch (chunk processing)
- **CDN**: CloudFront distributions (multiple for different sites/phases)
- **Workflow**: Step Functions (Corthography orchestration)
- **Container**: ECR repository (Docker images for Batch)
- **Monitoring**: CloudWatch dashboards, alarms, log groups
- **Network**: VPC endpoints (private S3/ECR access)
- **DNS**: Route53 hosted zones (production domains)
- **Security**: ACM certificates, WAF rules

**Multi-Site Management**:
- MediaFactual/NursingFactual
- MediaFactual/OtherFactual (future)
- Single Terraform manages multiple sites
- Site-specific CloudFront distributions and S3 buckets

**State Management**:
- Backend: S3 (active)
- Bucket: `corthuxa-terraform-state`
- Key: `corthuxa/terraform.tfstate`
- Encryption: Enabled
- DynamoDB locking: Temporarily disabled (commented out)

**Current Custom Agents**:

1. **corthuxa-infra-manager** (Sophisticated 7-phase orchestrator)
   - Location: `.claude/agents/corthuxa-infra-manager.md`
   - Operations: setup, audit, deploy, fix
   - Workflow: INSPECT → ANALYZE → PRESENT → APPROVE → EXECUTE → VERIFY → REPORT
   - Delegates to 4 specialized skills

2. **Skills** (Full FABER-like Pattern):

   **corthuxa-infra-auditor** (Read-only observability)
   - Location: `.claude/skills/corthuxa-infra-auditor/`
   - Check types: config-valid, iam-health, drift, cost, security, full
   - Duration: 2-30 seconds depending on check type
   - Non-destructive, safe for production
   - Pre/post-deployment verification

   **corthuxa-infra-architect** (Design and planning)
   - Location: `.claude/skills/corthuxa-infra-architect/`
   - Operations: design, plan
   - Creates architecture documents
   - Cost estimation
   - Implementation plans

   **corthuxa-infra-deployer** (Execution with error recovery)
   - Location: `.claude/skills/corthuxa-infra-deployer/`
   - 12-step deployment workflow with TodoWrite tracking
   - **Lambda build integration**: Runs `build-lambda.sh` before deployment
   - Environment safety validation: `validate-plan.sh`
   - Automated error delegation to debugger
   - Modes: interactive or `--complete` (automated)
   - Registry updates, documentation generation

   **corthuxa-infra-debugger** (Intelligent error fixing)
   - Location: `.claude/skills/corthuxa-infra-debugger/`
   - Analyzes Terraform errors from conversation context
   - Categorizes: Permission, Configuration, State, Resource errors
   - Automated fixing with `--complete` flag
   - Delegates permission errors to `managing-deploy-permissions`
   - Task decomposition for complex failures

3. **Supporting Skills**:

   **managing-deploy-permissions** (IAM permission management)
   - Location: `.claude/skills/managing-deploy-permissions/`
   - Only for deploy users (never resource roles)
   - Complete audit trail: `infrastructure/iam-policies/{env}-deploy-permissions.json`
   - Permission addition with justification tracking

**Custom Scripts** (Critical for Corthuxa):

- **`build-lambda.sh`**: TypeScript/pnpm Lambda build
  - Compiles TypeScript to JavaScript
  - Packages dependencies
  - Validates package size (>1MB check)
  - Creates deployment artifact

- **`validate-prerequisites.sh`**: Pre-deployment checks
  - AWS CLI configuration
  - Terraform version
  - Required tools (jq, etc.)

- **`validate-plan.sh`**: Environment safety validation
  - Prevents multi-environment deployment bugs
  - Detects environment from tfvars, workspace, state
  - Ensures all indicators match

- **`verify-deployment.sh`**: Post-deployment health checks
  - Verifies resources created
  - Checks Lambda function health
  - Validates CloudFront distributions

- **`test-lambda.sh`**: Lambda smoke tests
  - Invokes Lambda with test event
  - Verifies response

- **`configure-terraform.sh`**: Terraform initialization helper
- **`count-resources.sh`**: Resource inventory
- **`generate-documentation.sh`**: DEPLOYED.md generator

**AWS Profiles**:
- `corthuxa-core-test-deploy` - Test environment credentials
- `corthuxa-core-prod-deploy` - Production environment credentials

**Existing fractary-devops Plugin**:
- Directory: `fractary-devops-plugin/` (v0.1.0)
- **Must be removed** before faber-cloud migration
- Old version of what became faber-cloud

**Key Characteristics**:
- Advanced 4-skill architecture (audit, architect, deploy, debug)
- Corthos audit-first pattern (INSPECT before action)
- Sophisticated error recovery with automation
- **Lambda build integration** - Critical dependency
- Environment safety validation (prevents cross-env errors)
- Resource registry with ARNs and console URLs
- Permission audit trail
- Multi-site management in single Terraform
- Corthography-specific workflows

### Current Gaps & Migration Challenges

1. **Lambda Build Integration**:
   - `build-lambda.sh` must run before every deployment
   - faber-cloud needs hook support (from SPEC-0030-01)
   - Build failure must block deployment

2. **Multi-Site Management**:
   - Single Terraform manages multiple sites
   - How to represent in faber-cloud's project/subsystem model?
   - Need strategy for site-specific operations

3. **Old fractary-devops Plugin**:
   - Potential conflicts with faber-cloud
   - Must be cleanly removed
   - Configuration migration needed

4. **Corthography Workflows**:
   - Specialized Step Functions orchestration
   - Chunk-based processing with AWS Batch
   - Must continue working post-migration

5. **Advanced Custom Capabilities**:
   - Already has audit, architect, debug (similar to faber-cloud)
   - Need to ensure faber-cloud equivalents are sufficient
   - Permission audit trail migration

## Migration Goals

### Primary Goals

1. **Adopt existing infrastructure** with zero downtime and no resource recreation
2. **Preserve Lambda build workflow** using hook system
3. **Maintain multi-site management** capability
4. **Re-enable DynamoDB state locking**
5. **Remove old fractary-devops plugin** cleanly
6. **Preserve Corthography workflows** (Step Functions, Batch)
7. **Migrate permission audit trail** or archive appropriately
8. **Archive custom agents** after successful migration

### Secondary Goals

1. **Validate hook system** for complex pre-deployment builds
2. **Apply lessons learned** from Corthovore migration
3. **Create multi-site management pattern** for future projects
4. **Document Lambda integration** as reference implementation
5. **Contribute enhancements** to faber-cloud based on experience

## Requirements

### Functional Requirements

**FR-1**: Successfully adopt existing Corthuxa infrastructure
- faber-cloud recognizes all 60+ existing resources
- No resources recreated or destroyed during adoption
- Terraform state preserved with enhanced locking

**FR-2**: Lambda build integration via hooks
- Pre-deployment hook executes `build-lambda.sh`
- Build failure blocks deployment
- Build artifacts validated before Terraform apply
- Post-deployment hook runs Lambda smoke tests

**FR-3**: Multi-site management support
- Single faber-cloud configuration manages all sites
- Site-specific operations possible (if needed)
- Resource naming patterns accommodate multiple sites
- Documentation reflects multi-site architecture

**FR-4**: Remove old fractary-devops plugin
- Clean removal without affecting infrastructure
- Configuration migrated to faber-cloud format
- No conflicts with new faber-cloud plugin

**FR-5**: Preserve Corthography workflows
- Step Functions orchestration continues working
- AWS Batch chunk processing unaffected
- S3 bucket structure maintained
- ECR repository accessible

**FR-6**: Maintain advanced capabilities
- Audit operations equivalent to custom auditor
- Automated debugging equivalent to custom debugger
- Permission management available
- Resource registry with ARNs and URLs

**FR-7**: Environment safety validation
- Prevent multi-environment deployment bugs
- Validate environment indicators match
- Production safety enhancements
- Cost threshold enforcement

### Non-Functional Requirements

**NFR-1**: Zero Downtime
- No service interruption during migration
- Static sites remain accessible
- Corthography processing continues
- No resource recreation

**NFR-2**: Build Performance
- Lambda builds complete in <5 minutes
- Hook execution doesn't significantly increase deployment time
- Build artifacts cached when possible

**NFR-3**: Data Preservation
- All Terraform state preserved
- Permission audit trail archived or migrated
- Custom agent code archived
- All existing documentation preserved

**NFR-4**: Team Training
- Documentation enables self-service usage
- Lambda build workflow clearly documented
- Multi-site management patterns documented
- Troubleshooting guide addresses Corthuxa-specific issues

## Migration Strategy

### Approach: Phased Parallel Migration with Lambda Build Integration

Similar to Corthovore but with additional complexity around Lambda builds and multi-site management. Apply lessons learned from Corthovore migration.

### Phases

#### Phase 1: Pre-Migration Setup (Week 1)

**Objective**: Prepare infrastructure and environment, remove conflicts

**Tasks**:

1. **Remove old fractary-devops plugin**
   ```bash
   cd /mnt/c/GitHub/corthos/core.corthuxa.ai

   # Backup old plugin
   mkdir -p archived/fractary-devops
   mv fractary-devops-plugin/* archived/fractary-devops/

   # Document removal
   echo "Removed fractary-devops v0.1.0 on $(date)" > archived/fractary-devops/README.md
   echo "Replaced by fractary-faber-cloud (faber-cloud)" >> archived/fractary-devops/README.md

   # Commit removal
   git add .
   git commit -m "Remove old fractary-devops plugin, preparing for faber-cloud"
   ```

2. **Re-enable DynamoDB state locking**
   - Create DynamoDB table: `corthuxa-terraform-locks`
   - Uncomment locking configuration in `infrastructure/terraform/backend.tf`
   - Test lock acquisition and release
   - Verify no conflicts with existing operations

3. **Document current Lambda build workflow**
   - Document `build-lambda.sh` dependencies (Node.js, pnpm, TypeScript)
   - Document build process steps
   - Document artifact validation
   - Capture current build times
   - Document smoke test procedures

4. **Document multi-site structure**
   - List all sites currently managed
   - Document site-specific resources
   - Document shared resources
   - Capture resource naming patterns per site
   - Document any site-specific deployment requirements

5. **Archive permission audit trail**
   ```bash
   # Backup existing permission audits
   mkdir -p archived/iam-audit-trail
   cp infrastructure/iam-policies/*-deploy-permissions.json archived/iam-audit-trail/

   # Document archive
   echo "IAM permission audit trail archived on $(date)" > archived/iam-audit-trail/README.md
   echo "Retained for historical reference." >> archived/iam-audit-trail/README.md
   echo "New audit trail will be managed by faber-cloud." >> archived/iam-audit-trail/README.md
   ```

6. **Backup custom agents**
   ```bash
   # Copy custom agents to archive
   mkdir -p archived/custom-agents
   cp -r .claude/agents/corthuxa-infra-* archived/custom-agents/
   cp -r .claude/skills/corthuxa-infra-* archived/custom-agents/
   cp -r .claude/skills/managing-deploy-permissions archived/custom-agents/

   # Commit backup
   git add archived/
   git commit -m "Archive custom agents and audit trail pre-migration"
   git tag -a "pre-faber-cloud-migration" -m "State before faber-cloud migration"
   ```

7. **Document current infrastructure**
   - Run final audit with custom auditor
   - Generate DEPLOYED.md with custom documenter
   - Capture current resource inventory
   - Document any pending changes or known issues
   - Export CloudWatch metrics for baseline

**Success Criteria**:
- [ ] Old fractary-devops plugin removed
- [ ] DynamoDB locking enabled and tested
- [ ] Lambda build workflow documented
- [ ] Multi-site structure documented
- [ ] Permission audit trail archived
- [ ] Custom agents backed up
- [ ] Current infrastructure fully documented

**Rollback**: Restore fractary-devops and custom agents from archive, continue as before

#### Phase 2: faber-cloud Installation & Configuration (Week 1-2)

**Objective**: Install faber-cloud and generate configuration with Lambda hooks

**Tasks**:

1. **Install faber-cloud plugin**
   - Ensure latest version installed (with hook support from SPEC-0030-01)
   - Verify dependencies (Terraform, AWS CLI, jq, Node.js, pnpm)
   - Test basic faber-cloud commands

2. **Run infrastructure adoption workflow**
   ```bash
   cd /mnt/c/GitHub/corthos/core.corthuxa.ai
   /fractary-faber-cloud:adopt
   ```

3. **Review and customize generated configuration**
   - Location: `.fractary/plugins/faber-cloud/config/faber-cloud.json`
   - Expected base structure (see detailed config below)
   - **Critical**: Add Lambda build hooks
   - Configure multi-site settings
   - Set appropriate cost thresholds

4. **Configure Lambda build hooks**

   Add to `faber-cloud.json`:
   ```json
   {
     "hooks": {
       "pre-deploy": [
         {
           "name": "build-lambda",
           "command": "bash .claude/skills/corthuxa-infra-deployer/scripts/build-lambda.sh",
           "critical": true,
           "timeout": 300,
           "description": "Build TypeScript Lambda functions with pnpm"
         },
         {
           "name": "validate-prerequisites",
           "command": "bash infrastructure/terraform/scripts/validate-prerequisites.sh",
           "critical": true,
           "timeout": 60,
           "description": "Validate deployment prerequisites"
         }
       ],
       "post-deploy": [
         {
           "name": "verify-deployment",
           "command": "bash infrastructure/terraform/scripts/verify-deployment.sh",
           "critical": false,
           "timeout": 120,
           "description": "Verify deployed resources are healthy"
         },
         {
           "name": "test-lambda",
           "command": "bash .claude/skills/corthuxa-infra-deployer/scripts/test-lambda.sh",
           "critical": false,
           "timeout": 60,
           "description": "Run Lambda smoke tests"
         }
       ]
     }
   }
   ```

5. **Configure multi-site management**

   Strategy: Use subsystem field to represent primary site, manage all sites together
   ```json
   {
     "project": {
       "name": "corthuxa",
       "subsystem": "all-sites",
       "organization": "corthos"
     }
   }
   ```

   Alternative: Separate configs per site (not recommended for Corthuxa)

6. **Validate configuration**
   - Verify Terraform directory path correct
   - Verify AWS profile names match
   - Test hook commands manually
   - Validate resource naming pattern
   - Test environment variable substitution

7. **Review migration report**
   - Read generated `MIGRATION-REPORT.md`
   - Review custom script mapping
   - Verify Lambda build hooks captured
   - Note any gaps or concerns
   - Create detailed migration checklist

**Success Criteria**:
- [ ] faber-cloud plugin installed
- [ ] Configuration generated and customized
- [ ] Lambda build hooks configured and tested
- [ ] Multi-site strategy defined
- [ ] Configuration validated (no errors)
- [ ] Migration report reviewed
- [ ] Team understands new workflow

**Rollback**: Don't use faber-cloud, continue with custom agents

#### Phase 3: Read-Only Validation (Week 2-3)

**Objective**: Test faber-cloud's ability to understand existing infrastructure without making changes

**Tasks**:

1. **Run audit on test environment**
   ```bash
   /fractary-faber-cloud:audit --env=test --check=full
   ```

   Expected results:
   - Detects all 60+ resources
   - Reports drift status (should be 0 if current)
   - Security checks pass
   - Cost estimates accurate
   - Execution time <30 seconds

   Compare with custom auditor:
   ```bash
   Use the corthuxa-infra-manager agent to audit test environment
   ```

2. **Run audit on production environment**
   ```bash
   /fractary-faber-cloud:audit --env=prod --check=full
   ```

   Validate:
   - All production resources detected
   - CloudFront distributions healthy
   - Lambda functions accessible
   - Step Functions workflows present
   - No unexpected drift
   - Cost estimates match expectations

3. **Test Lambda build hooks (dry-run)**
   ```bash
   # Test pre-deploy hooks manually
   bash .claude/skills/corthuxa-infra-deployer/scripts/build-lambda.sh

   # Verify build succeeds
   ls -lh infrastructure/terraform/lambda-package.zip

   # Should be >1MB
   ```

4. **Generate deployment plan (no apply)**
   ```bash
   /fractary-faber-cloud:deploy-plan --env=test
   ```

   Validate:
   - Plan shows current state correctly
   - If changes pending, verify they match expectations
   - Resource count matches (~60+ resources)
   - No unexpected destroys or recreates
   - Environment validation passes

5. **Test resource registry generation**
   ```bash
   /fractary-faber-cloud:list --env=test
   ```

   Validate:
   - All resources listed with ARNs
   - Console URLs functional
   - Multi-site resources properly categorized
   - CloudFront URLs accessible
   - Lambda function ARNs correct

6. **Verify Corthography resources detected**
   - Step Functions state machines
   - AWS Batch compute environments
   - ECR repository
   - S3 chunk buckets
   - All workflow components present

**Success Criteria**:
- [ ] Audit completes successfully in test
- [ ] Audit completes successfully in prod
- [ ] Lambda build hooks execute successfully
- [ ] Deploy-plan matches custom agent plan
- [ ] No unexpected changes or drift detected
- [ ] Resource registry accurate for all sites
- [ ] Corthography resources all detected
- [ ] faber-cloud understands flat multi-feature structure

**Rollback**: Continue with custom agents for deployments, use faber-cloud for read-only only

#### Phase 4: Test Environment Migration (Week 3-4)

**Objective**: Perform first managed deployment via faber-cloud to test environment with Lambda builds

**Tasks**:

1. **Select low-risk change for first deployment**
   - Options: Add tag to S3 bucket, update CloudWatch retention, adjust Lambda memory
   - Avoid: Lambda code changes (test build first), CloudFront changes, network changes

2. **Pre-deployment validation**
   ```bash
   # Validate Terraform configuration
   /fractary-faber-cloud:validate --env=test

   # Run audit to establish baseline
   /fractary-faber-cloud:audit --env=test --check=full
   ```

3. **Test Lambda build hook execution**
   ```bash
   # Manually trigger build to verify
   bash .claude/skills/corthuxa-infra-deployer/scripts/build-lambda.sh

   # Verify artifacts created
   ls -lh infrastructure/terraform/lambda-package.zip

   # Check package size
   size=$(stat -f%z infrastructure/terraform/lambda-package.zip 2>/dev/null || stat -c%s infrastructure/terraform/lambda-package.zip)
   if [ $size -gt 1048576 ]; then
     echo "Build successful: ${size} bytes"
   else
     echo "ERROR: Package too small"
     exit 1
   fi
   ```

4. **Generate and review plan**
   ```bash
   /fractary-faber-cloud:deploy-plan --env=test
   ```

   Review carefully:
   - Only expected changes shown
   - No Lambda recreates (unless intended)
   - No CloudFront changes
   - Cost impact minimal
   - Environment validation passes

5. **Execute deployment with hooks**
   ```bash
   /fractary-faber-cloud:deploy-execute --env=test
   ```

   Monitor:
   - Pre-deploy hooks execute (build-lambda, validate-prerequisites)
   - Lambda build succeeds
   - Build artifact validated
   - Terraform init succeeds
   - Plan matches previous review
   - Apply completes without errors
   - Post-deploy hooks execute (verify-deployment, test-lambda)
   - Lambda smoke tests pass
   - Resource count unchanged (~60+)

6. **Post-deployment verification**
   ```bash
   # Run audit to verify changes applied
   /fractary-faber-cloud:audit --env=test --check=full

   # Verify resource registry updated
   /fractary-faber-cloud:list --env=test

   # Check DEPLOYED.md generated
   cat infrastructure/DEPLOYED.md

   # Test Corthography workflow
   # (Trigger chunk processing, verify it works)
   ```

7. **Test Lambda build change scenario**
   - Make small change to Lambda function code
   - Run deployment again
   - Verify build hook detects change
   - Verify new Lambda package deployed
   - Verify function works with new code

8. **Test error scenarios**
   - Introduce build error (invalid TypeScript)
   - Verify build hook fails
   - Verify deployment blocked (critical hook)
   - Fix error, verify deployment succeeds
   - Test debugger with Terraform error
   - Verify auto-fix works (if applicable)

9. **Compare with custom agent deployment**
   - Document differences in workflow
   - Compare deployment times
   - Compare error handling
   - Note any missing capabilities

**Success Criteria**:
- [ ] First deployment via faber-cloud succeeds
- [ ] Lambda build hooks execute correctly
- [ ] Build failures block deployment
- [ ] No resources recreated unexpectedly
- [ ] Resource count remains correct (~60+)
- [ ] Lambda functions work after deployment
- [ ] Corthography workflow unaffected
- [ ] Post-deploy smoke tests pass
- [ ] DEPLOYED.md generated correctly
- [ ] Team confident in workflow

**Rollback**: Revert change via custom agent if issues, continue using custom agents

#### Phase 5: Lambda Code Change Testing (Week 4)

**Objective**: Validate Lambda deployment workflow with actual code changes

**Tasks**:

1. **Make test Lambda code change**
   - Small, safe change (logging, comment, minor logic)
   - Update in TypeScript source
   - Commit to feature branch

2. **Deploy Lambda change via faber-cloud**
   ```bash
   /fractary-faber-cloud:deploy-execute --env=test
   ```

   Verify:
   - Build hook compiles TypeScript
   - New package created
   - Package size validated
   - Lambda function updated in AWS
   - Version/alias updated (if used)
   - Function works with new code

3. **Test Lambda smoke tests**
   ```bash
   # Post-deploy hook should run automatically
   # Manually verify:
   bash .claude/skills/corthuxa-infra-deployer/scripts/test-lambda.sh
   ```

4. **Test rollback scenario**
   - Introduce breaking Lambda change
   - Deploy to test
   - Verify smoke tests detect failure
   - Rollback to previous version
   - Verify rollback works

5. **Document Lambda deployment patterns**
   - Build triggers (code changes, dependency updates)
   - Deployment flow with hooks
   - Testing procedures
   - Rollback procedures
   - Common issues and solutions

**Success Criteria**:
- [ ] Lambda code changes deploy successfully
- [ ] Build process works end-to-end
- [ ] Smoke tests validate deployments
- [ ] Rollback procedure works
- [ ] Documentation complete

**Rollback**: Use custom deployer for Lambda changes if issues persist

#### Phase 6: Production Validation (Week 5)

**Objective**: Validate faber-cloud in production with read-only operations before first deployment

**Tasks**:

1. **Run comprehensive production audit**
   ```bash
   /fractary-faber-cloud:audit --env=prod --check=full
   ```

   Verify:
   - All production resources detected
   - All sites (NursingFactual, etc.) represented
   - CloudFront distributions healthy
   - Lambda functions healthy
   - Step Functions workflows active
   - No unexpected drift
   - Security checks pass
   - Cost estimates accurate

2. **Audit production Corthography infrastructure**
   - Step Functions state machines
   - AWS Batch compute environments
   - ECR repository with images
   - S3 chunk processing buckets
   - CloudWatch log groups
   - All workflow components operational

3. **Generate production deployment plan**
   ```bash
   /fractary-faber-cloud:deploy-plan --env=prod
   ```

   Review:
   - Shows current state accurately
   - Multi-site resources all present
   - If changes pending, verify they're intentional
   - Resource count correct (~60+)
   - Environment validation passes
   - Cost threshold enforced

4. **Test Lambda build in production context**
   ```bash
   # Build with production configuration
   # (Don't deploy, just verify build works)
   bash .claude/skills/corthuxa-infra-deployer/scripts/build-lambda.sh
   ```

5. **Review production safety features**
   - Verify `require_confirmation: true` enforced
   - Verify cost threshold ($1000+) enforced
   - Test that destructive changes trigger multiple warnings
   - Verify environment validation prevents cross-env errors
   - Test production-specific validation rules

6. **Document production deployment procedure**
   - Step-by-step guide for production deployments
   - Lambda code deployment procedures
   - Required approvals and confirmations
   - Emergency rollback procedure
   - Contact list for issues
   - Corthography workflow verification steps

7. **Conduct team walkthrough**
   - Demonstrate production deployment workflow
   - Review Lambda build and deployment process
   - Review multi-site considerations
   - Practice emergency scenarios
   - Review Corthography dependencies
   - Answer questions and concerns

**Success Criteria**:
- [ ] Production audit successful
- [ ] All sites detected correctly
- [ ] Corthography infrastructure validated
- [ ] Production planning accurate
- [ ] Lambda builds work in prod context
- [ ] Safety features working correctly
- [ ] Team trained on production workflow
- [ ] Documentation complete
- [ ] Rollback procedures tested

**Rollback**: Continue using custom agents for production

#### Phase 7: Production Migration (Week 5-6)

**Objective**: Perform first managed production deployment via faber-cloud

**Tasks**:

1. **Select very low-risk change for first prod deployment**
   - Examples: Add tag, update CloudWatch retention, adjust Lambda memory (no code)
   - Avoid: Lambda code changes, CloudFront changes, any changes affecting live sites

2. **Coordinate with stakeholders**
   - Notify team of planned production change
   - Schedule during low-usage period
   - Have rollback plan ready
   - Designate monitor/observer
   - Prepare for Corthography workflow verification

3. **Run comprehensive pre-deployment checks**
   ```bash
   /fractary-faber-cloud:audit --env=prod --check=full
   /fractary-faber-cloud:validate --env=prod
   /fractary-faber-cloud:deploy-plan --env=prod
   ```

4. **Review plan extensively**
   - Multiple reviewers
   - Verify only expected changes
   - Verify no impact to live sites
   - Confirm cost impact acceptable
   - Verify no Lambda or CloudFront changes
   - Document approval

5. **Execute production deployment**
   ```bash
   /fractary-faber-cloud:deploy-execute --env=prod
   ```

   Monitor carefully:
   - Pre-deploy hooks execute (Lambda build may be no-op if no code changes)
   - Terraform execution progress
   - No unexpected prompts or errors
   - Resource count unchanged
   - Deployment completes successfully
   - Post-deploy hooks execute
   - Verification tests pass

6. **Post-deployment verification**
   ```bash
   # Immediate audit
   /fractary-faber-cloud:audit --env=prod --check=full

   # Verify resource registry
   /fractary-faber-cloud:list --env=prod

   # Check DEPLOYED.md
   cat infrastructure/DEPLOYED.md

   # Verify all sites accessible
   curl -I https://nursingfactual.com
   # (Check all production sites)

   # Verify Corthography workflow
   # Trigger chunk processing, verify it works

   # Monitor CloudWatch metrics
   # Check for any anomalies
   ```

7. **Monitor for 24-48 hours**
   - Watch for any unexpected behavior
   - Monitor site uptime and performance
   - Check CloudFront metrics
   - Monitor Lambda invocations and errors
   - Verify Corthography jobs complete
   - Check error rates and logs

8. **Document outcomes**
   - Record deployment success/issues
   - Note any differences from test environment
   - Document lessons learned
   - Update procedures if needed

**Success Criteria**:
- [ ] Production deployment via faber-cloud succeeds
- [ ] No service disruption
- [ ] All sites remain accessible
- [ ] All resources healthy post-deployment
- [ ] Corthography workflows continue working
- [ ] No unexpected drift or changes
- [ ] Team confident in production usage

**Rollback**: If critical issues, revert via Terraform or custom agent

#### Phase 8: Lambda Code Production Deployment (Week 6)

**Objective**: Deploy Lambda code changes to production via faber-cloud

**Tasks**:

1. **Select safe Lambda code change**
   - Small, well-tested change
   - Already deployed and verified in test
   - Low-risk (logging, minor optimization)
   - Avoid: Major logic changes, new dependencies

2. **Pre-deployment preparation**
   - Ensure change tested thoroughly in test environment
   - Document expected behavior change
   - Prepare rollback plan (previous Lambda version)
   - Schedule during low-usage period

3. **Execute deployment with Lambda build**
   ```bash
   /fractary-faber-cloud:deploy-execute --env=prod
   ```

   Monitor:
   - Pre-deploy hook builds Lambda
   - TypeScript compilation succeeds
   - Package size validated (>1MB)
   - Lambda function updated
   - Post-deploy smoke tests pass
   - Function invocations succeed

4. **Verify Lambda deployment**
   ```bash
   # Test Lambda manually
   bash .claude/skills/corthuxa-infra-deployer/scripts/test-lambda.sh

   # Check CloudWatch logs
   # Verify new code is executing
   # Check for errors or warnings

   # Monitor metrics
   # Duration, error rate, throttles
   ```

5. **Monitor Corthography integration**
   - Trigger chunk processing job
   - Verify Lambda processes chunks correctly
   - Check Step Functions execution
   - Monitor AWS Batch jobs
   - Verify output in S3

6. **Extended monitoring (48-72 hours)**
   - Watch Lambda error rates
   - Monitor Corthography job success rates
   - Check site generation still works
   - Verify no regressions

**Success Criteria**:
- [ ] Lambda code change deploys successfully to production
- [ ] Build hooks work in production
- [ ] Smoke tests pass
- [ ] Corthography integration unaffected
- [ ] No increase in errors or failures
- [ ] Sites continue operating normally

**Rollback**: Revert Lambda to previous version if issues detected

#### Phase 9: Full Adoption & Custom Agent Archival (Week 6-7)

**Objective**: Make faber-cloud the primary infrastructure tool and archive custom agents

**Tasks**:

1. **Expand faber-cloud usage**
   - Use faber-cloud for all deployments in test
   - Use faber-cloud for all deployments in prod
   - Use audit regularly for drift detection
   - Test debug capabilities on real errors
   - Deploy Lambda changes regularly

2. **Validate all capabilities**
   - Architecture design (if new features needed)
   - Deployment with various change types
   - Lambda build and deployment workflow
   - Multi-site management
   - Error debugging and auto-fix
   - Resource registry maintenance
   - Documentation generation
   - Cost estimation
   - Security scanning

3. **Update all documentation**
   - **README.md**: Replace custom agent commands with faber-cloud
   - **docs/infrastructure.md**: Update deployment procedures
   - **docs/lambda-deployment.md**: Document Lambda build workflow
   - **docs/corthography-ops.md**: Update Corthography operations
   - **docs/runbooks/**: Update infrastructure management sections
   - **team wiki**: Update infrastructure guides

4. **Archive custom agents**
   ```bash
   # Move custom agents to archive (if not already done)
   mkdir -p archived/custom-agents
   mv .claude/agents/corthuxa-infra-* archived/custom-agents/
   mv .claude/skills/corthuxa-infra-* archived/custom-agents/
   mv .claude/skills/managing-deploy-permissions archived/custom-agents/

   # Keep build scripts referenced by hooks
   # (Don't move .claude/skills/corthuxa-infra-deployer/scripts/build-lambda.sh)

   # Create comprehensive README
   cat > archived/custom-agents/README.md <<EOF
   # Archived Custom Infrastructure Agents

   These custom agents were replaced by fractary-faber-cloud on $(date).

   ## Migration Details
   - Migrated to faber-cloud v2.2+
   - Lambda builds preserved via hook system
   - Permission audit trail archived separately
   - Retained for reference and potential rollback

   ## Custom Capabilities Preserved
   - Audit: faber-cloud infra-auditor
   - Architect: faber-cloud infra-architect
   - Deploy: faber-cloud infra-deployer + hooks
   - Debug: faber-cloud infra-debugger
   - Permissions: faber-cloud infra-permission-manager

   ## Build Scripts
   Build scripts maintained in active codebase:
   - .claude/skills/corthuxa-infra-deployer/scripts/build-lambda.sh
   - infrastructure/terraform/scripts/*.sh

   These are referenced by faber-cloud hooks.
   EOF

   # Commit archival
   git add .
   git commit -m "Archive custom infra agents, migrated to faber-cloud"
   git tag -a "faber-cloud-migration-complete" -m "Completed migration to faber-cloud"
   ```

5. **Create migration retrospective**
   - What went well
   - What was challenging
   - Lambda build integration lessons
   - Multi-site management learnings
   - Differences from Corthovore migration
   - Recommendations for future complex migrations
   - Feature requests for faber-cloud

6. **Share learnings**
   - Update SPEC-0030-01 based on experience
   - Document Corthuxa as complex migration case study
   - Create template for Lambda build integration
   - Create template for multi-site management
   - Contribute improvements to faber-cloud
   - Share with Fractary community

**Success Criteria**:
- [ ] faber-cloud used exclusively for 2+ weeks
- [ ] All deployments successful including Lambda changes
- [ ] All team members comfortable with new workflow
- [ ] Custom agents archived (not deleted)
- [ ] Build scripts preserved and functional
- [ ] Documentation fully updated
- [ ] Migration retrospective complete
- [ ] Lessons shared with team and community

**Rollback**: Can restore custom agents from archive if absolutely necessary

## Configuration Details

### faber-cloud.json (Corthuxa-Specific)

```json
{
  "version": "1.0",
  "project": {
    "name": "corthuxa",
    "subsystem": "all-sites",
    "organization": "corthos",
    "description": "Static site generator with Corthography integration"
  },
  "handlers": {
    "hosting": {
      "active": "aws",
      "aws": {
        "region": "us-east-1",
        "profiles": {
          "discover": "corthuxa-core-test-deploy",
          "test": "corthuxa-core-test-deploy",
          "prod": "corthuxa-core-prod-deploy"
        }
      }
    },
    "iac": {
      "active": "terraform",
      "terraform": {
        "directory": "./infrastructure/terraform",
        "var_file_pattern": "{environment}.tfvars",
        "backend_config": {
          "bucket": "corthuxa-terraform-state",
          "key": "corthuxa/terraform.tfstate",
          "region": "us-east-1",
          "encrypt": true,
          "dynamodb_table": "corthuxa-terraform-locks"
        }
      }
    }
  },
  "resource_naming": {
    "pattern": "corthuxa-{owner}-{site}-{environment}-{resource}",
    "separator": "-",
    "examples": [
      "corthuxa-mediafactual-nursingfactual-prod-site-bucket",
      "corthuxa-mediafactual-nursingfactual-prod-cdn",
      "corthuxa-core-all-test-build-lambda"
    ]
  },
  "environments": {
    "test": {
      "auto_approve": false,
      "cost_threshold": 100,
      "require_confirmation": false,
      "tags": {
        "Environment": "test",
        "ManagedBy": "faber-cloud",
        "Project": "corthuxa"
      }
    },
    "prod": {
      "auto_approve": false,
      "cost_threshold": 1000,
      "require_confirmation": true,
      "tags": {
        "Environment": "prod",
        "ManagedBy": "faber-cloud",
        "Project": "corthuxa"
      }
    }
  },
  "hooks": {
    "pre-plan": [
      {
        "name": "validate-node-environment",
        "command": "which node && which pnpm && node --version && pnpm --version",
        "critical": false,
        "timeout": 10,
        "description": "Verify Node.js and pnpm are available for Lambda builds"
      }
    ],
    "pre-deploy": [
      {
        "name": "validate-prerequisites",
        "command": "bash infrastructure/terraform/scripts/validate-prerequisites.sh",
        "critical": true,
        "timeout": 60,
        "description": "Validate deployment prerequisites (AWS CLI, Terraform, jq)"
      },
      {
        "name": "build-lambda",
        "command": "bash .claude/skills/corthuxa-infra-deployer/scripts/build-lambda.sh",
        "critical": true,
        "timeout": 300,
        "description": "Build TypeScript Lambda functions with pnpm, validate package size"
      }
    ],
    "post-deploy": [
      {
        "name": "verify-deployment",
        "command": "bash infrastructure/terraform/scripts/verify-deployment.sh",
        "critical": false,
        "timeout": 120,
        "description": "Verify deployed resources are healthy (Lambda, CloudFront, Step Functions)"
      },
      {
        "name": "test-lambda",
        "command": "bash .claude/skills/corthuxa-infra-deployer/scripts/test-lambda.sh",
        "critical": false,
        "timeout": 60,
        "description": "Run Lambda smoke tests with test events"
      },
      {
        "name": "verify-corthography",
        "command": "bash infrastructure/terraform/scripts/verify-corthography.sh",
        "critical": false,
        "timeout": 120,
        "description": "Verify Corthography workflow components (Step Functions, Batch, ECR)"
      }
    ],
    "post-plan": [
      {
        "name": "validate-multi-site-changes",
        "command": "bash infrastructure/terraform/scripts/validate-sites.sh",
        "critical": false,
        "timeout": 30,
        "description": "Validate changes don't negatively impact any site"
      }
    ]
  },
  "monitoring": {
    "drift_detection": true,
    "cost_tracking": true,
    "security_scanning": true,
    "custom_checks": [
      "lambda_error_rate",
      "cloudfront_distribution_health",
      "step_functions_execution_success"
    ]
  },
  "multi_site": {
    "enabled": true,
    "sites": [
      {
        "name": "nursingfactual",
        "owner": "mediafactual",
        "domain": "nursingfactual.com",
        "cloudfront_id": "E1234567890ABC"
      }
    ]
  }
}
```

### Terraform Backend Configuration

Update `infrastructure/terraform/backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "corthuxa-terraform-state"
    key            = "corthuxa/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "corthuxa-terraform-locks"
  }
}
```

### Build Script Preservation

**CRITICAL**: Keep Lambda build scripts in active codebase (referenced by hooks):

```
.claude/skills/corthuxa-infra-deployer/scripts/
├── build-lambda.sh          # KEEP - referenced by pre-deploy hook
└── test-lambda.sh           # KEEP - referenced by post-deploy hook

infrastructure/terraform/scripts/
├── validate-prerequisites.sh # KEEP - referenced by pre-deploy hook
├── verify-deployment.sh      # KEEP - referenced by post-deploy hook
├── verify-corthography.sh    # KEEP - referenced by post-deploy hook
└── validate-sites.sh         # KEEP - referenced by post-plan hook
```

## Testing Strategy

### Pre-Migration Testing

1. **Lambda Build Validation**
   - Test `build-lambda.sh` in isolation
   - Verify TypeScript compilation
   - Verify pnpm dependency installation
   - Verify package size validation
   - Test with code changes, dependency updates
   - Measure build times

2. **Hook System Testing**
   - Test pre-deploy hooks in sequence
   - Test critical hook failure blocks deployment
   - Test optional hook failure allows continuation
   - Test hook timeout enforcement
   - Test environment variable passing

3. **Multi-Site Structure Testing**
   - Verify all sites detected in Terraform
   - Test site-specific resource identification
   - Validate resource naming patterns
   - Test that changes to one site don't affect others

### Migration Testing

1. **Read-Only Operations**
   - Test audit in test environment
   - Test audit in prod environment (all sites)
   - Test plan generation
   - Test resource listing (verify all sites)
   - Verify no state modifications
   - Verify Corthography resources detected

2. **Test Environment Deployment**
   - Deploy simple change (no Lambda code)
   - Deploy Lambda code change
   - Deploy with intentional build error (verify blocked)
   - Test error scenario and debugging
   - Verify rollback capability
   - Test Corthography workflow after deployment

3. **Lambda Build Integration**
   - Deploy with no code changes (build should be no-op or use cache)
   - Deploy with code changes (build should compile)
   - Deploy with dependency updates (build should install)
   - Test build failure blocks deployment
   - Test smoke tests catch runtime errors

4. **Production Validation**
   - Extensive read-only testing (all sites)
   - Multiple plan generations
   - Lambda build in prod context
   - Safety feature validation
   - Team walkthrough with focus on Lambda workflow

5. **Production Deployment**
   - Very low-risk change first (no Lambda, no sites)
   - Lambda code change after confidence built
   - Monitor extensively (all sites, Corthography)
   - Verify no service impact
   - Test rollback readiness

### Post-Migration Testing

1. **Ongoing Usage**
   - Regular deployments via faber-cloud
   - Lambda code changes via hook workflow
   - Periodic audits for drift
   - Error debugging as issues arise
   - Multi-site operations

2. **Capability Validation**
   - Test all faber-cloud commands
   - Validate audit types (config, drift, cost, security)
   - Test debug with real errors
   - Verify resource registry accuracy (all sites)
   - Test Lambda smoke tests
   - Verify Corthography workflows

## Success Metrics

### Migration Success

- [ ] faber-cloud successfully manages all Corthuxa infrastructure
- [ ] Lambda build workflow fully integrated via hooks
- [ ] Zero resources recreated during migration
- [ ] Zero service disruption during migration (all sites)
- [ ] DynamoDB state locking enabled
- [ ] Old fractary-devops plugin removed
- [ ] Custom agents archived (available for rollback)
- [ ] Team trained and comfortable with faber-cloud + Lambda workflow

### Lambda Build Integration

- [ ] Lambda builds execute on every deployment
- [ ] Build failures block deployment 100% of time
- [ ] Builds complete in <5 minutes
- [ ] Build artifacts validated (>1MB)
- [ ] Smoke tests run post-deployment
- [ ] Lambda rollback procedure works

### Multi-Site Management

- [ ] All sites detected and managed
- [ ] Site-specific changes possible (if needed)
- [ ] No cross-site impact from changes
- [ ] Resource naming clear per site
- [ ] Documentation reflects multi-site architecture

### Corthography Workflow

- [ ] Step Functions continue operating
- [ ] AWS Batch jobs complete successfully
- [ ] Chunk processing works
- [ ] Site generation completes
- [ ] No performance degradation

### Capability Gains

- [ ] Audit capability functional (test and prod, all sites)
- [ ] Automated debugging available
- [ ] Pre-deployment testing active (security, cost)
- [ ] Enhanced documentation generated
- [ ] Resource registry maintained (all sites)
- [ ] Cost tracking enabled
- [ ] Permission management available

### Operational Metrics

- [ ] Deployment time similar to custom agents (hook overhead <10%)
- [ ] Lambda build adds <5 minutes to deployment
- [ ] Audit operations complete in <30 seconds
- [ ] Planning operations complete in <2 minutes
- [ ] Error resolution time reduced (via auto-debug)
- [ ] Zero failed deployments in first month

### Team Metrics

- [ ] All team members can deploy via faber-cloud independently
- [ ] All team members understand Lambda build workflow
- [ ] Documentation sufficient for self-service
- [ ] Team satisfaction rating >4/5
- [ ] Incident response time unchanged or improved

## Risks & Mitigations

### Risk 1: Lambda Build Integration Complexity

**Likelihood**: Medium
**Impact**: High
**Description**: Lambda build hooks may not integrate smoothly, causing deployment failures

**Mitigation**:
- Test build hooks extensively before migration
- Validate build process in isolation
- Have manual build fallback ready
- Test build error scenarios
- Document build troubleshooting

**Contingency**: Keep custom deployer for Lambda changes, use faber-cloud for infrastructure-only changes

### Risk 2: Multi-Site Management Confusion

**Likelihood**: Low
**Impact**: Medium
**Description**: Managing multiple sites in one configuration may be unclear or error-prone

**Mitigation**:
- Clear documentation of multi-site strategy
- Resource naming patterns distinguish sites
- Validation scripts check for cross-site impacts
- Test site-specific changes carefully

**Contingency**: Create separate faber-cloud configs per site if needed

### Risk 3: Corthography Workflow Disruption

**Likelihood**: Low
**Impact**: High
**Description**: Migration could disrupt Step Functions, Batch, or chunk processing

**Mitigation**:
- Never recreate Corthography resources
- Extensive read-only validation before changes
- Test Corthography workflow after each deployment
- Monitor Step Functions executions closely
- Have rollback plan for Corthography issues

**Contingency**: Rollback to custom agents, investigate, retry when fixed

### Risk 4: Production Deployment Errors

**Likelihood**: Low
**Impact**: Critical
**Description**: First production deployment could impact live sites

**Mitigation**:
- Choose very low-risk change for first prod deployment
- Avoid Lambda, CloudFront, or site-affecting changes initially
- Multiple reviews of production plan
- Schedule during low-usage period
- Monitor all sites post-deployment
- Have emergency rollback ready

**Contingency**: Immediate rollback via custom agent or Terraform directly

### Risk 5: Old fractary-devops Conflicts

**Likelihood**: Low
**Impact**: Medium
**Description**: Removing old plugin could cause issues or confusion

**Mitigation**:
- Remove old plugin early in migration
- Back up before removal
- Test faber-cloud immediately after removal
- Document removal in git history

**Contingency**: Restore old plugin temporarily if conflicts arise (should not be needed)

### Risk 6: Permission Audit Trail Loss

**Likelihood**: Medium
**Impact**: Low
**Description**: Historical permission changes not carried forward to faber-cloud

**Mitigation**:
- Archive existing audit trail before migration
- Document archival location
- Start fresh audit trail with faber-cloud
- Maintain old trail for reference

**Contingency**: Old trail available in archive, no loss of information

### Risk 7: Hook Performance Impact

**Likelihood**: Low
**Impact**: Low
**Description**: Lambda builds may significantly increase deployment time

**Mitigation**:
- Optimize build process (caching, parallelization)
- Set reasonable hook timeouts
- Monitor build times
- Document expected deployment duration

**Contingency**: Accept longer deployment times as trade-off for integration

## Rollback Plan

### Immediate Rollback (same day)

If critical issues during deployment:

1. **Stop using faber-cloud immediately**
2. **Use custom agent for recovery**:
   ```bash
   Use the corthuxa-infra-manager agent to deploy in {environment}
   ```
3. **Investigate issue** - Check logs, errors, state, Lambda builds
4. **Document problem** - What went wrong, why, how to fix
5. **Restore from backup** if state corrupted (unlikely)

**Impact**: Minimal, Terraform state unchanged, custom agents still available

### Lambda Build Rollback

If Lambda build issues:

1. **Use custom deployer for Lambda deployments**
   ```bash
   Use the corthuxa-infra-manager agent to deploy Lambda changes
   ```
2. **Use faber-cloud for non-Lambda infrastructure changes**
3. **Investigate hook issues** - Build script, environment, dependencies
4. **Fix and retry** when ready

**Impact**: Moderate, partial faber-cloud usage, some workflow disruption

### Gradual Rollback (1-2 weeks)

If ongoing issues after deployment:

1. **Use faber-cloud for read-only operations only** (audit, plan)
2. **Use custom agents for all deployments**
3. **Identify root cause** of issues
4. **Determine if fixable** or fundamental incompatibility
5. **Decide**: Retry migration after fixes, or abandon

**Impact**: Moderate, lose migration progress, but infrastructure stable

### Permanent Rollback

If migration proves unfeasible:

1. **Remove faber-cloud configuration**
2. **Continue with custom agents indefinitely**
3. **Restore old fractary-devops** if needed (unlikely)
4. **Document lessons learned**
5. **Contribute feedback** to faber-cloud project

**Impact**: High (time invested lost), but infrastructure operations continue normally

## Timeline

### Estimated Duration: 6-7 weeks

- **Week 1**: Pre-migration setup, remove old plugin, enable locking, faber-cloud installation
- **Week 2-3**: Read-only validation, Lambda hook testing, configuration refinement
- **Week 3-4**: Test environment migration, Lambda deployment testing
- **Week 4**: Lambda code change testing, build workflow validation
- **Week 5**: Production validation, first production deployment (non-Lambda)
- **Week 5-6**: Lambda production deployment, extended monitoring
- **Week 6-7**: Full adoption, custom agent archival, documentation

### Milestones

- **Week 1 End**: Old plugin removed, state locking enabled, faber-cloud configured with hooks
- **Week 3 End**: Read-only operations validated, Lambda hooks tested
- **Week 4 End**: First test deployment via faber-cloud, Lambda changes deployed
- **Week 5 End**: First production deployment via faber-cloud
- **Week 6 End**: Lambda code deployed to production via faber-cloud
- **Week 7 End**: Custom agents archived, migration complete

## Documentation Updates

### Files to Update

1. **README.md** - Replace custom agent commands with faber-cloud
2. **docs/infrastructure.md** - Update deployment procedures
3. **docs/lambda-deployment.md** - Document Lambda build workflow with hooks
4. **docs/corthography-operations.md** - Update Corthography operations
5. **docs/multi-site-management.md** - Document multi-site patterns
6. **docs/runbooks/infrastructure-deployment.md** - New faber-cloud workflow
7. **docs/troubleshooting.md** - Add faber-cloud debugging, Lambda build issues
8. **.github/workflows/*** - Update CI/CD if applicable

### New Documentation

1. **MIGRATION-RETROSPECTIVE.md** - Lessons learned from migration
2. **archived/custom-agents/README.md** - Archive documentation
3. **archived/iam-audit-trail/README.md** - Historical audit trail
4. **docs/faber-cloud-usage.md** - Guide for Corthuxa-specific usage
5. **docs/lambda-build-hooks.md** - Deep dive on Lambda build integration
6. **docs/hooks-reference.md** - All configured hooks and their purposes

## Dependencies

### External

- **SPEC-0030-01**: faber-cloud migration features (hooks, adoption, validation) - **CRITICAL**
- **SPEC-0030-02**: Corthovore migration (lessons learned) - **RECOMMENDED**
- **Terraform**: >= 1.0
- **AWS CLI**: >= 2.0
- **jq**: Latest version
- **Node.js**: >= 18 (for Lambda builds)
- **pnpm**: >= 8 (for Lambda builds)
- **TypeScript**: >= 5 (for Lambda builds)

### Internal

- Corthuxa infrastructure operational
- AWS accounts and credentials available
- Team availability for testing and validation
- Lambda build environment configured

## Next Steps

After successful Corthuxa migration:

1. **Document lessons learned** - Comprehensive retrospective
2. **Update SPEC-0030-01** - Add Lambda hook patterns, multi-site patterns
3. **Create Lambda build integration template** - For other projects
4. **Create multi-site management template** - For other projects
5. **Share case study** - Complex migration with faber-cloud community
6. **Contribute enhancements** - Propose hook improvements, multi-site features
7. **Apply to other Corthos projects** - Use validated patterns

## Conclusion

This specification provides a comprehensive, phased approach to migrating Corthuxa from custom infrastructure agents to faber-cloud. The strategy addresses the unique complexity of Lambda build integration, multi-site management, and Corthography workflows while prioritizing safety through parallel operation, extensive testing, and maintained rollback capability.

**Key Success Factors**:
- Hook system for Lambda build integration (from SPEC-0030-01)
- Thorough pre-migration preparation (remove old plugin, enable locking)
- Extensive Lambda build testing before production
- Clear multi-site management strategy
- Preservation of Corthography workflows
- Team involvement and training
- Comprehensive documentation
- Lessons learned from Corthovore migration applied

**Complexity Level**: High (Lambda builds, multi-site, Corthography)
**Timeline**: 6-7 weeks
**Dependencies**: SPEC-0030-01 (hook system critical)
**Risk Level**: Medium (mitigated by phased approach and testing)

This migration, once successful, will serve as the definitive reference for complex faber-cloud migrations involving build processes, multi-site management, and specialized workflows.
