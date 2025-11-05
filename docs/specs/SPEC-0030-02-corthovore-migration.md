# SPEC-0030-02: Corthovore Infrastructure Migration to faber-cloud

**Issue**: #30
**Phase**: 2 (Corthovore Migration)
**Dependencies**: SPEC-0030-01 (faber-cloud migration features)
**Status**: Draft
**Created**: 2025-01-15

## Overview

Migrate the `core.corthovore.ai` project from its custom infrastructure manager agents to the fractary-faber-cloud plugin. This project manages AWS Batch-based web scraping infrastructure with a modular Terraform structure.

**Project Location**: `C:\GitHub\corthos\core.corthovore.ai` (Windows) or `/mnt/c/GitHub/corthos/core.corthovore.ai` (WSL)

**Goal**: Successfully transition Corthovore to use faber-cloud for all infrastructure operations while preserving existing functionality and gaining enhanced capabilities (audit, debugging, pre-deployment testing).

## Background

### Current Infrastructure

**Purpose**: AWS Batch-based web scraping platform

**Terraform Structure**: Modular architecture with environment separation
- `terraform/environments/prod/` - Production environment
- `terraform/environments/test/` - Test environment
- `terraform/modules/` - Shared reusable modules
  - `storage` - S3 buckets
  - `network` - VPC, subnets, NAT gateways
  - `messaging` - SQS queues, EventBridge
  - `iam` - Task roles, execution roles
  - `compute` - AWS Batch environments, ECS tasks

**AWS Resources** (~48 total):
- **Storage**: S3 buckets (cache, results, configs, entities)
- **Compute**: AWS Batch compute environments, job queues, ECS Fargate tasks
- **Network**: VPC, 3 AZ subnets, NAT gateways, security groups
- **Messaging**: SQS queues (high/standard priority), EventBridge rules
- **Data**: DynamoDB tables (metadata, job registry, entity index)
- **IAM**: Task execution roles, service roles, policies

**State Management**:
- Backend: S3 (currently commented out, using local state)
- Planned backend: `corthovore-terraform-state-{env}` buckets
- DynamoDB locking: Planned but not yet implemented

**Current Custom Agents**:

1. **corthovore-infra-manager** (Lightweight orchestrator)
   - Location: `.claude/agents/corthovore-infra-manager.md`
   - Operations: deploy, status, teardown
   - Workflow: INSPECT → REVIEW → APPROVE → EXECUTE
   - Safety: Multiple confirmations for production
   - Delegates to 3 skills

2. **Skills**:
   - **corthovore-infra-deployer**: Terraform deployment executor
     - Executes: `terraform init`, `plan`, `apply`
     - Reports: Resource count, estimated costs
     - Creates ~48 resources

   - **corthovore-infra-status**: Infrastructure status checker
     - Reports: Deployed resources, health status

   - **corthovore-infra-documenter**: Documentation generator
     - Creates: DEPLOYED.md with resource inventory

**AWS Profiles**:
- `corthovore-core-test-deploy` - Test environment credentials
- `corthovore-core-prod-deploy` - Production environment credentials

**Key Characteristics**:
- Simpler than Corthuxa (3 skills vs 4)
- No audit/architect/debugger capabilities
- Basic error handling (manual intervention required)
- Production safety through confirmation prompts
- Modular Terraform (different from faber-cloud's typical flat structure)

### Current Gaps

1. **No audit capability**: Cannot inspect infrastructure without planning changes
2. **No automated debugging**: Errors require manual diagnosis and fixing
3. **No pre-deployment testing**: No security scans or cost validation
4. **Limited error recovery**: All errors block deployment, no auto-fix
5. **Manual state management**: State backend not configured
6. **No resource tracking**: No registry with ARNs and console URLs
7. **Basic documentation**: Simple resource list, no architectural overview

## Migration Goals

### Primary Goals

1. **Adopt existing infrastructure** with zero downtime and no resource recreation
2. **Migrate to remote state** (S3 backend with DynamoDB locking)
3. **Gain audit capabilities** for read-only infrastructure inspection
4. **Enable automated debugging** for common deployment errors
5. **Add pre-deployment testing** (security scans, cost validation)
6. **Improve documentation** with enhanced DEPLOYED.md generation
7. **Archive custom agents** after successful migration

### Secondary Goals

1. **Validate modular Terraform support** in faber-cloud
2. **Create migration template** for other modular Terraform projects
3. **Document lessons learned** for Corthuxa and future migrations
4. **Establish testing patterns** for production infrastructure changes

## Requirements

### Functional Requirements

**FR-1**: Successfully adopt existing Corthovore infrastructure
- faber-cloud recognizes all 48 existing resources
- No resources recreated or destroyed during adoption
- Terraform state preserved and enhanced with remote backend

**FR-2**: Support modular Terraform structure
- faber-cloud correctly navigates environment-specific directories
- Module dependencies resolved correctly
- Environment variable files loaded properly

**FR-3**: Maintain deployment safety
- Production deployments require explicit confirmation
- Environment validation prevents cross-environment errors
- Cost thresholds enforced before deployment

**FR-4**: Provide enhanced capabilities
- Audit operations work in test and production
- Automated debugging for permission and configuration errors
- Resource registry with AWS console URLs
- Enhanced documentation generation

**FR-5**: Enable rollback capability
- Can revert to custom agents if issues arise
- Terraform state remains compatible
- No loss of infrastructure control

### Non-Functional Requirements

**NFR-1**: Zero Downtime
- No service interruption during migration
- No resource recreation unless explicitly needed
- Deployments work identically before and after

**NFR-2**: Data Preservation
- All Terraform state preserved
- All existing documentation preserved
- Custom agent code archived (not deleted)

**NFR-3**: Performance
- Deployments complete in similar time to custom agents
- Audit operations complete in <30 seconds
- Planning operations complete in <2 minutes

**NFR-4**: Team Training
- Documentation enables self-service usage
- Team comfortable with new commands
- Troubleshooting guide addresses common issues

## Migration Strategy

### Approach: Phased Parallel Migration

Run faber-cloud alongside custom agents during transition, gradually increasing confidence before full cutover.

### Phases

#### Phase 1: Pre-Migration Setup (Week 1)

**Objective**: Prepare infrastructure and environment for migration

**Tasks**:

1. **Migrate Terraform state to S3 backend**
   - Uncomment S3 backend configuration in `terraform/environments/*/backend.tf`
   - Create S3 state buckets: `corthovore-terraform-state-test`, `corthovore-terraform-state-prod`
   - Enable versioning and encryption on state buckets
   - Migrate local state to S3: `terraform init -migrate-state`
   - Verify state migration successful
   - Test Terraform operations with remote state

2. **Enable DynamoDB state locking**
   - Create DynamoDB table: `corthovore-terraform-locks`
   - Configure locking in backend configuration
   - Test lock acquisition and release

3. **Document current infrastructure**
   - Run final deployment with custom agents
   - Generate DEPLOYED.md with corthovore-infra-documenter
   - Capture current resource inventory
   - Document any pending changes or known issues

4. **Backup custom agents**
   - Copy `.claude/` directory to `archived-custom-agents/`
   - Commit to git with tag `pre-faber-cloud-migration`
   - Document custom agent capabilities for comparison

**Success Criteria**:
- [ ] S3 backend active in test and prod
- [ ] DynamoDB locking functional
- [ ] Terraform operations work with remote state
- [ ] Custom agents backed up
- [ ] Current infrastructure documented

**Rollback**: If issues arise, revert backend configuration and continue with local state

#### Phase 2: faber-cloud Installation & Configuration (Week 1-2)

**Objective**: Install faber-cloud and generate configuration for Corthovore

**Tasks**:

1. **Install faber-cloud plugin**
   - Ensure latest version installed (with adoption features from SPEC-0030-01)
   - Verify dependencies (Terraform, AWS CLI, jq)
   - Test basic faber-cloud commands

2. **Run infrastructure adoption workflow**
   ```bash
   cd /mnt/c/GitHub/corthos/core.corthovore.ai
   /fractary-faber-cloud:adopt
   ```

3. **Review and customize generated configuration**
   - Location: `.fractary/plugins/faber-cloud/config/faber-cloud.json`
   - Expected structure:
     ```json
     {
       "version": "1.0",
       "project": {
         "name": "corthovore",
         "subsystem": "core",
         "organization": "corthos"
       },
       "handlers": {
         "hosting": {
           "active": "aws",
           "aws": {
             "region": "us-east-1",
             "profiles": {
               "discover": "corthovore-core-test-deploy",
               "test": "corthovore-core-test-deploy",
               "prod": "corthovore-core-prod-deploy"
             }
           }
         },
         "iac": {
           "active": "terraform",
           "terraform": {
             "directory": "./terraform/environments/{environment}",
             "var_file_pattern": "terraform.tfvars"
           }
         }
       },
       "resource_naming": {
         "pattern": "scraper-{resource}-{environment}",
         "separator": "-"
       },
       "environments": {
         "test": {
           "auto_approve": false,
           "cost_threshold": 100,
           "require_confirmation": false
         },
         "prod": {
           "auto_approve": false,
           "cost_threshold": 500,
           "require_confirmation": true
         }
       },
       "hooks": {}
     }
     ```

4. **Validate configuration**
   - Verify Terraform directory pattern correct
   - Verify AWS profile names match existing profiles
   - Adjust resource naming pattern if needed
   - Set appropriate cost thresholds

5. **Review migration report**
   - Read generated `MIGRATION-REPORT.md`
   - Review custom script mapping
   - Note any gaps or concerns
   - Create migration checklist from report

**Success Criteria**:
- [ ] faber-cloud plugin installed
- [ ] Configuration generated and customized
- [ ] Configuration validated (no errors)
- [ ] Migration report reviewed
- [ ] Team understands new commands

**Rollback**: Simply don't use faber-cloud, continue with custom agents

#### Phase 3: Read-Only Validation (Week 2)

**Objective**: Test faber-cloud's ability to understand existing infrastructure without making changes

**Tasks**:

1. **Run audit on test environment**
   ```bash
   /fractary-faber-cloud:audit --env=test --check=full
   ```

   Expected results:
   - Detects all ~48 resources
   - Reports 0 drift (infrastructure matches state)
   - No errors or warnings
   - Execution time <30 seconds

2. **Run audit on production environment**
   ```bash
   /fractary-faber-cloud:audit --env=prod --check=full
   ```

   Validate:
   - All production resources detected
   - No unexpected drift
   - Health checks pass
   - Cost estimates match expectations

3. **Generate deployment plan (no apply)**
   ```bash
   /fractary-faber-cloud:deploy-plan --env=test
   ```

   Validate:
   - Plan shows "no changes" if infrastructure current
   - If changes pending, verify they match expectations
   - Resource count matches (48 resources)
   - No unexpected destroys or recreates

4. **Compare with custom agent outputs**
   ```bash
   # Custom agent status
   Use the corthovore-infra-manager agent to check status in test environment

   # Compare resource counts, health status, etc.
   ```

5. **Test resource registry generation**
   ```bash
   /fractary-faber-cloud:list --env=test
   ```

   Validate:
   - All resources listed with ARNs
   - Console URLs functional
   - Resource types correctly identified

**Success Criteria**:
- [ ] Audit completes successfully in test
- [ ] Audit completes successfully in prod
- [ ] Deploy-plan matches custom agent plan
- [ ] No unexpected changes or drift detected
- [ ] Resource registry accurate
- [ ] faber-cloud understands modular structure

**Rollback**: Continue with custom agents for deployments, use faber-cloud for read-only operations only

#### Phase 4: Test Environment Migration (Week 3)

**Objective**: Perform first managed deployment via faber-cloud to test environment

**Tasks**:

1. **Select low-risk change for first deployment**
   - Options: Add tag to S3 bucket, update Lambda timeout, adjust CloudWatch retention
   - Avoid: Resource recreation, permission changes, network changes

2. **Run pre-deployment validation**
   ```bash
   /fractary-faber-cloud:validate --env=test
   ```

3. **Generate and review plan**
   ```bash
   /fractary-faber-cloud:deploy-plan --env=test
   ```

   Review carefully:
   - Only expected changes shown
   - No destroys or recreates
   - Cost impact minimal
   - Environment validation passes

4. **Execute deployment**
   ```bash
   /fractary-faber-cloud:deploy-execute --env=test
   ```

   Monitor:
   - Terraform init succeeds
   - Plan matches previous review
   - Apply completes without errors
   - Resource count unchanged (48 resources)

5. **Post-deployment verification**
   ```bash
   # Run audit to verify changes applied
   /fractary-faber-cloud:audit --env=test --check=full

   # Verify resource registry updated
   /fractary-faber-cloud:list --env=test

   # Check DEPLOYED.md generated
   cat infrastructure/DEPLOYED.md
   ```

6. **Compare with custom agent deployment**
   - Run same deployment with custom agent (if safe to repeat)
   - Compare outputs, timing, error handling
   - Document differences

7. **Test error scenarios**
   - Introduce intentional error (e.g., invalid resource name)
   - Verify faber-cloud debugger detects and categorizes error
   - Test `--complete` flag for auto-fix (if applicable)

8. **Keep custom agents as backup**
   - Don't delete or disable custom agents yet
   - Maintain ability to fall back if needed

**Success Criteria**:
- [ ] First deployment via faber-cloud succeeds
- [ ] No resources recreated unexpectedly
- [ ] Resource count remains correct (48)
- [ ] DEPLOYED.md generated correctly
- [ ] Resource registry updated
- [ ] Error debugging works
- [ ] Team confident in faber-cloud operations

**Rollback**: Revert change via custom agent if issues arise, continue using custom agents

#### Phase 5: Production Validation (Week 4)

**Objective**: Validate faber-cloud in production with read-only operations before first deployment

**Tasks**:

1. **Run comprehensive production audit**
   ```bash
   /fractary-faber-cloud:audit --env=prod --check=full
   ```

   Verify:
   - All production resources detected
   - No unexpected drift
   - Security checks pass
   - Cost estimates accurate
   - IAM roles healthy

2. **Generate production deployment plan**
   ```bash
   /fractary-faber-cloud:deploy-plan --env=prod
   ```

   Review:
   - Shows current state accurately
   - If changes pending, verify they're intentional
   - Resource count correct
   - Environment validation passes

3. **Review production safety features**
   - Verify `require_confirmation: true` enforced
   - Verify cost threshold ($500) enforced
   - Test that destructive changes trigger additional warnings
   - Verify environment validation prevents cross-env errors

4. **Document production deployment procedure**
   - Step-by-step guide for production deployments
   - Required approvals and confirmations
   - Emergency rollback procedure
   - Contact list for issues

5. **Conduct team walkthrough**
   - Demonstrate production deployment workflow
   - Review safety features and confirmations
   - Practice emergency scenarios
   - Answer questions and concerns

**Success Criteria**:
- [ ] Production audit successful
- [ ] Production planning accurate
- [ ] Safety features working correctly
- [ ] Team trained on production workflow
- [ ] Documentation complete
- [ ] Rollback procedures tested

**Rollback**: Continue using custom agents for production, use faber-cloud only in test

#### Phase 6: Production Migration (Week 4-5)

**Objective**: Perform first managed production deployment via faber-cloud

**Tasks**:

1. **Select very low-risk change for first prod deployment**
   - Examples: Add tag, update documentation, adjust monitoring
   - Avoid: Any resource changes, permission changes, network changes

2. **Coordinate with stakeholders**
   - Notify team of planned production change
   - Schedule during low-usage period
   - Have rollback plan ready
   - Designate monitor/observer

3. **Run pre-deployment checks**
   ```bash
   /fractary-faber-cloud:audit --env=prod --check=full
   /fractary-faber-cloud:validate --env=prod
   /fractary-faber-cloud:deploy-plan --env=prod
   ```

4. **Review plan extensively**
   - Multiple reviewers if possible
   - Verify only expected changes
   - Confirm cost impact acceptable
   - Document approval

5. **Execute production deployment**
   ```bash
   /fractary-faber-cloud:deploy-execute --env=prod
   ```

   Monitor carefully:
   - Terraform execution progress
   - No unexpected prompts or errors
   - Resource count unchanged
   - Deployment completes successfully

6. **Post-deployment verification**
   ```bash
   # Immediate audit
   /fractary-faber-cloud:audit --env=prod --check=full

   # Verify resource registry
   /fractary-faber-cloud:list --env=prod

   # Check DEPLOYED.md
   cat infrastructure/DEPLOYED.md

   # Monitor services
   # (Use existing monitoring/alerting)
   ```

7. **Monitor for 24-48 hours**
   - Watch for any unexpected behavior
   - Monitor scraping jobs continue normally
   - Check error rates and logs
   - Verify no resource drift

8. **Document outcomes**
   - Record deployment success/issues
   - Note any differences from test environment
   - Document lessons learned
   - Update procedures if needed

**Success Criteria**:
- [ ] Production deployment via faber-cloud succeeds
- [ ] No service disruption
- [ ] All resources healthy post-deployment
- [ ] No unexpected drift or changes
- [ ] Team confident in production usage
- [ ] Documentation updated

**Rollback**: If critical issues, revert via Terraform directly or custom agent, investigate before retry

#### Phase 7: Full Adoption & Custom Agent Archival (Week 5-6)

**Objective**: Make faber-cloud the primary infrastructure tool and archive custom agents

**Tasks**:

1. **Expand faber-cloud usage**
   - Use faber-cloud for regular deployments in test
   - Use faber-cloud for regular deployments in prod
   - Use audit regularly for drift detection
   - Test debug capabilities on real errors

2. **Validate all capabilities**
   - Architecture design (if needed for new features)
   - Deployment with various change types
   - Error debugging and auto-fix
   - Resource registry maintenance
   - Documentation generation
   - Cost estimation

3. **Update all documentation**
   - **README.md**: Replace custom agent commands with faber-cloud
   - **deployment docs**: Update procedures and workflows
   - **runbooks**: Update infrastructure management sections
   - **team wiki**: Update infrastructure guides

4. **Archive custom agents**
   ```bash
   # Move custom agents to archive
   mkdir -p archived/custom-agents
   mv .claude/agents/corthovore-infra-* archived/custom-agents/
   mv .claude/skills/corthovore-infra-* archived/custom-agents/

   # Create README in archive
   echo "These custom agents were replaced by fractary-faber-cloud on $(date)" > archived/custom-agents/README.md
   echo "Retained for reference and potential rollback." >> archived/custom-agents/README.md

   # Commit archival
   git add .
   git commit -m "Archive custom infra agents, migrated to faber-cloud"
   git tag -a "faber-cloud-migration-complete" -m "Completed migration to faber-cloud plugin"
   ```

5. **Create migration retrospective**
   - What went well
   - What was challenging
   - Lessons learned for Corthuxa migration
   - Recommendations for future migrations
   - Feature requests for faber-cloud

6. **Share learnings**
   - Update SPEC-0030-01 based on experience
   - Document Corthovore as migration case study
   - Create template for modular Terraform migrations
   - Contribute improvements to faber-cloud

**Success Criteria**:
- [ ] faber-cloud used exclusively for 2+ weeks
- [ ] All team members comfortable with new workflow
- [ ] Custom agents archived (not deleted)
- [ ] Documentation fully updated
- [ ] Migration retrospective complete
- [ ] Lessons shared with team

**Rollback**: Can restore custom agents from archive if absolutely necessary

## Configuration Details

### faber-cloud.json (Corthovore-Specific)

```json
{
  "version": "1.0",
  "project": {
    "name": "corthovore",
    "subsystem": "core",
    "organization": "corthos"
  },
  "handlers": {
    "hosting": {
      "active": "aws",
      "aws": {
        "region": "us-east-1",
        "profiles": {
          "discover": "corthovore-core-test-deploy",
          "test": "corthovore-core-test-deploy",
          "prod": "corthovore-core-prod-deploy"
        }
      }
    },
    "iac": {
      "active": "terraform",
      "terraform": {
        "directory": "./terraform/environments/{environment}",
        "var_file_pattern": "terraform.tfvars",
        "backend_config": {
          "bucket": "corthovore-terraform-state-{environment}",
          "key": "corthovore/terraform.tfstate",
          "region": "us-east-1",
          "encrypt": true,
          "dynamodb_table": "corthovore-terraform-locks"
        }
      }
    }
  },
  "resource_naming": {
    "pattern": "scraper-{resource}-{environment}",
    "separator": "-",
    "examples": [
      "scraper-cache-bucket-prod",
      "scraper-results-bucket-test",
      "scraper-high-priority-queue-prod"
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
        "Project": "corthovore"
      }
    },
    "prod": {
      "auto_approve": false,
      "cost_threshold": 500,
      "require_confirmation": true,
      "tags": {
        "Environment": "prod",
        "ManagedBy": "faber-cloud",
        "Project": "corthovore"
      }
    }
  },
  "hooks": {
    "pre-deploy": [
      {
        "name": "validate-batch-configuration",
        "command": "bash ./scripts/validate-batch.sh",
        "critical": false,
        "timeout": 30,
        "description": "Validates AWS Batch configuration before deployment"
      }
    ],
    "post-deploy": [
      {
        "name": "verify-scraping-queues",
        "command": "bash ./scripts/verify-queues.sh",
        "critical": false,
        "timeout": 60,
        "description": "Verifies SQS queues are accessible and properly configured"
      }
    ]
  },
  "monitoring": {
    "drift_detection": true,
    "cost_tracking": true,
    "security_scanning": true
  }
}
```

### Terraform Backend Configuration

Update `terraform/environments/test/backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "corthovore-terraform-state-test"
    key            = "corthovore/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "corthovore-terraform-locks"
  }
}
```

Update `terraform/environments/prod/backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "corthovore-terraform-state-prod"
    key            = "corthovore/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "corthovore-terraform-locks"
  }
}
```

## Testing Strategy

### Pre-Migration Testing

1. **State Migration Validation**
   - Test state migration in test environment first
   - Verify `terraform plan` shows no changes after migration
   - Confirm state locking works
   - Test state rollback procedure

2. **Configuration Validation**
   - Validate generated faber-cloud.json
   - Test configuration with dry-run operations
   - Verify AWS profile access
   - Confirm Terraform directory resolution

### Migration Testing

1. **Read-Only Operations**
   - Test audit in test environment
   - Test audit in prod environment
   - Test plan generation
   - Test resource listing
   - Verify no state modifications

2. **Test Environment Deployment**
   - Deploy simple change (tag addition)
   - Deploy moderate change (config update)
   - Deploy complex change (new resource)
   - Test error scenario and debugging
   - Verify rollback capability

3. **Production Validation**
   - Extensive read-only testing
   - Multiple plan generations
   - Safety feature validation
   - Team walkthrough

4. **Production Deployment**
   - Very low-risk change first
   - Monitor extensively
   - Verify no service impact
   - Test rollback readiness

### Post-Migration Testing

1. **Ongoing Usage**
   - Regular deployments via faber-cloud
   - Periodic audits for drift
   - Error debugging as issues arise
   - Documentation generation on each deploy

2. **Capability Validation**
   - Test all faber-cloud commands
   - Validate audit types (config, drift, cost, security)
   - Test debug with real errors
   - Verify resource registry accuracy

## Success Metrics

### Migration Success

- [ ] faber-cloud successfully manages all Corthovore infrastructure
- [ ] Zero resources recreated during migration
- [ ] Zero service disruption during migration
- [ ] Terraform state migrated to S3 with locking
- [ ] Custom agents archived (available for rollback)
- [ ] Team trained and comfortable with faber-cloud

### Capability Gains

- [ ] Audit capability functional (test and prod)
- [ ] Automated debugging available
- [ ] Pre-deployment testing active
- [ ] Enhanced documentation generated
- [ ] Resource registry maintained
- [ ] Cost tracking enabled

### Operational Metrics

- [ ] Deployment time similar to custom agents (<10% difference)
- [ ] Audit operations complete in <30 seconds
- [ ] Planning operations complete in <2 minutes
- [ ] Error resolution time reduced (via auto-debug)
- [ ] Zero failed deployments in first month

### Team Metrics

- [ ] All team members can deploy via faber-cloud independently
- [ ] Documentation sufficient for self-service
- [ ] Team satisfaction rating >4/5
- [ ] Incident response time unchanged or improved

## Risks & Mitigations

### Risk 1: Modular Terraform Structure Compatibility

**Likelihood**: Medium
**Impact**: High
**Description**: faber-cloud may not correctly handle `terraform/environments/{environment}/` structure

**Mitigation**:
- Test extensively in read-only mode first
- Validate configuration pattern thoroughly
- Have custom agents ready as fallback
- Contribute fix to faber-cloud if issue found

**Contingency**: Use custom agents while faber-cloud is enhanced

### Risk 2: State Migration Issues

**Likelihood**: Low
**Impact**: High
**Description**: State migration to S3 could corrupt state or cause resource loss

**Mitigation**:
- Backup local state before migration
- Test migration in test environment first
- Use `terraform init -migrate-state` (safe operation)
- Verify plan shows no changes after migration

**Contingency**: Restore from backup, troubleshoot migration issue

### Risk 3: Production Deployment Errors

**Likelihood**: Low
**Impact**: High
**Description**: First production deployment via faber-cloud could fail or cause issues

**Mitigation**:
- Choose very low-risk change for first deployment
- Extensive testing in test environment first
- Multiple reviews of production plan
- Have custom agent ready for emergency rollback

**Contingency**: Rollback via custom agent, investigate, retry when fixed

### Risk 4: Team Adoption Resistance

**Likelihood**: Low
**Impact**: Medium
**Description**: Team may prefer familiar custom agents

**Mitigation**:
- Involve team in migration planning
- Provide comprehensive training
- Highlight capability gains (audit, debug, testing)
- Keep custom agents available during transition

**Contingency**: Extended parallel operation period, additional training

### Risk 5: Feature Gaps in faber-cloud

**Likelihood**: Medium
**Impact**: Medium
**Description**: faber-cloud may lack features present in custom agents

**Mitigation**:
- Thorough gap analysis before migration
- Use hooks for custom script preservation
- Contribute features to faber-cloud
- Document workarounds

**Contingency**: Keep custom agents for specific features, partial migration

## Rollback Plan

### Immediate Rollback (same day)

If critical issues during deployment:

1. **Stop using faber-cloud immediately**
2. **Use custom agent for recovery**:
   ```bash
   Use the corthovore-infra-manager agent to deploy in {environment}
   ```
3. **Investigate issue** - Check logs, errors, state
4. **Document problem** - What went wrong, why, how to fix
5. **Restore from backup** if state corrupted (unlikely)

**Impact**: Minimal, Terraform state unchanged, custom agents still available

### Gradual Rollback (1-2 weeks)

If ongoing issues after deployment:

1. **Use faber-cloud for read-only operations only** (audit, plan)
2. **Use custom agents for all deployments**
3. **Identify root cause** of issues
4. **Determine if fixable** or fundamental incompatibility
5. **Decide**: Retry migration after fixes, or abandon migration

**Impact**: Moderate, lose migration progress, but infrastructure stable

### Permanent Rollback

If migration proves unfeasible:

1. **Remove faber-cloud configuration**
2. **Continue with custom agents indefinitely**
3. **Document lessons learned**
4. **Contribute feedback** to faber-cloud project
5. **Consider alternative approaches** (different plugin, enhance custom agents)

**Impact**: High (time invested lost), but infrastructure operations continue normally

## Timeline

### Estimated Duration: 5-6 weeks

- **Week 1**: Pre-migration setup, state migration, faber-cloud installation
- **Week 2**: Read-only validation, configuration refinement
- **Week 3**: Test environment migration, first deployments
- **Week 4**: Production validation, first production deployment
- **Week 5-6**: Full adoption, custom agent archival, documentation

### Milestones

- **Week 1 End**: Remote state active, faber-cloud configured
- **Week 2 End**: Read-only operations validated in test and prod
- **Week 3 End**: First successful test deployment via faber-cloud
- **Week 4 End**: First successful prod deployment via faber-cloud
- **Week 6 End**: Custom agents archived, migration complete

## Documentation Updates

### Files to Update

1. **README.md** - Replace custom agent commands with faber-cloud
2. **docs/infrastructure.md** - Update deployment procedures
3. **docs/runbooks/infrastructure-deployment.md** - New faber-cloud workflow
4. **docs/troubleshooting.md** - Add faber-cloud debugging procedures
5. **.github/workflows/*** - Update CI/CD if applicable

### New Documentation

1. **MIGRATION-RETROSPECTIVE.md** - Lessons learned from migration
2. **archived/custom-agents/README.md** - Archive documentation
3. **docs/faber-cloud-usage.md** - Guide for Corthovore-specific usage

## Dependencies

### External

- **SPEC-0030-01**: faber-cloud migration features (hooks, adoption, validation)
- **Terraform**: >= 1.0
- **AWS CLI**: >= 2.0
- **jq**: Latest version

### Internal

- Corthovore infrastructure operational
- AWS accounts and credentials available
- Team availability for testing and validation

## Next Steps

After successful Corthovore migration:

1. **Document lessons learned** for Corthuxa
2. **Update SPEC-0030-01** based on real-world experience
3. **Create modular Terraform migration template**
4. **Share case study** with faber-cloud community
5. **Begin planning Corthuxa migration** (SPEC-0030-03)

## Conclusion

This specification provides a comprehensive, phased approach to migrating Corthovore from custom infrastructure agents to faber-cloud. The strategy prioritizes safety through parallel operation, extensive testing, and maintained rollback capability. Success will validate faber-cloud's ability to handle modular Terraform structures and provide a proven template for migrating Corthuxa and future projects.

**Key Success Factors**:
- Thorough pre-migration preparation (state migration)
- Extensive read-only validation before changes
- Very low-risk first deployments
- Maintained rollback capability throughout
- Team involvement and training
- Comprehensive documentation
