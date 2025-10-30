# Phase 2 Implementation Prompt - Testing & Debugging

Use this prompt to start Phase 2 implementation in a fresh Claude Code session.

---

## Prompt for Claude Code

I want to implement Phase 2 (Testing & Debugging) of the fractary-faber-cloud plugin. Phase 1 is complete and committed.

**Context Documents to Read:**
1. `PHASE-1-COMPLETE.md` - Summary of what's already implemented
2. `../fractary-faber-cloud-implementation-phases.md` - Full phase specifications
3. `../fractary-faber-cloud-architecture.md` - Architecture patterns
4. `../../../../FRACTARY-PLUGIN-STANDARDS.md` - Plugin development standards

**Phase 2 Goal:**
Add testing and intelligent debugging capabilities to the DevOps plugin.

**Phase 2 Deliverables:**

1. **infra-tester Skill**
   - Pre-deployment: Security scanning (Checkov, tfsec), cost estimation
   - Post-deployment: Resource verification, integration tests
   - Test results documentation
   - Integration into deploy workflow

2. **infra-debugger Skill**
   - Error categorization (permission/config/resource/state)
   - Issue log system
   - Solution search and matching
   - Proposed solution generation
   - Historical learning

3. **Issue Log System**
   - `issue-log.json` structure at `.fractary/plugins/faber-cloud/deployments/issue-log.json`
   - Log resolution script
   - Search and ranking logic
   - Success rate tracking

**Implementation Order:**

1. Start with `infra-tester` skill:
   - Create skill structure in `skills/infra-tester/`
   - Implement pre-deployment security scanning workflow
   - Implement cost estimation workflow
   - Implement post-deployment verification workflow
   - Add integration points for infra-deployer

2. Create issue log system:
   - Design `issue-log.json` schema
   - Create `log-issue.sh` script in `devops-common/scripts/`
   - Create `search-solutions.sh` script
   - Create `update-issue.sh` script for tracking resolution success

3. Implement `infra-debugger` skill:
   - Create skill structure in `skills/infra-debugger/`
   - Implement error categorization logic
   - Implement issue log search and ranking
   - Implement solution generation workflow
   - Add integration points for infra-manager error handling

**Success Criteria:**

✅ Security scans run before deployment
✅ Cost estimates generated
✅ Post-deployment verification tests pass
✅ Errors categorized correctly
✅ Historical solutions found and ranked
✅ Issue log grows with each resolved issue
✅ Recurring issues solved faster

**Integration Points:**

- `infra-deployer` should invoke `infra-tester` before and after deployment
- `infra-manager` should invoke `infra-debugger` when deployment fails
- `infra-debugger` should log all resolutions to issue log
- All skills should follow existing patterns from Phase 1

**Reference Implementation:**
Use Phase 1 skills as reference for:
- Skill structure (SKILL.md, workflow/, docs/)
- XML markup standards (CONTEXT, CRITICAL_RULES, WORKFLOW, etc.)
- Handler invocation patterns
- Error handling patterns
- Documentation standards

**Standards to Follow:**
- Manager Pattern: Skills are invoked by manager, never work independently
- Single-Purpose: Each skill does one thing well
- Documentation Atomicity: Skills document their own work
- Configuration-Driven: Use config-loader.sh for all configuration
- Defense in Depth: Validate at multiple levels

Let me know when you've reviewed the context documents and are ready to begin Phase 2 implementation.

---

## Quick Start Commands (for Claude)

```bash
# Review Phase 1 completion
cat plugins/faber-cloud/docs/specs/status/PHASE-1-COMPLETE.md

# Review Phase 2 specifications
cat plugins/faber-cloud/docs/specs/fractary-faber-cloud-implementation-phases.md

# Check current structure
ls -la plugins/faber-cloud/skills/

# Start implementation
# (Claude will create skill directories and implement files)
```

---

## Expected Deliverables

By end of Phase 2, the following should exist:

**New Skills:**
- `skills/infra-tester/SKILL.md`
- `skills/infra-tester/workflow/security-scan.md`
- `skills/infra-tester/workflow/cost-estimate.md`
- `skills/infra-tester/workflow/verify-deployment.md`
- `skills/infra-debugger/SKILL.md`
- `skills/infra-debugger/workflow/categorize-error.md`
- `skills/infra-debugger/workflow/search-solutions.md`
- `skills/infra-debugger/workflow/generate-solution.md`

**New Scripts:**
- `skills/devops-common/scripts/log-issue.sh`
- `skills/devops-common/scripts/search-solutions.sh`
- `skills/devops-common/scripts/update-issue.sh`

**Documentation:**
- Issue log at `.fractary/plugins/faber-cloud/deployments/issue-log.json` (not committed)
- Test results in deployment directory
- Updated integration in infra-deployer

**Testing:**
- Deploy sample terraform to AWS test account
- Trigger permission error, verify debugger analyzes it
- Verify issue log captures and learns from error
- Verify security scans run on terraform code
- Verify cost estimates generated

---

## Notes for Implementation

1. **Security Scanning Tools:**
   - Check if Checkov or tfsec are installed
   - Provide installation instructions if not
   - Parse scan output and report findings

2. **Cost Estimation:**
   - Use terraform plan output to estimate resources
   - Provide approximate monthly costs
   - Reference Phase 1 cost estimation guide in infra-architect

3. **Issue Log Schema:**
   ```json
   {
     "version": "1.0",
     "issues": [
       {
         "id": "issue-001",
         "timestamp": "2025-10-28T12:00:00Z",
         "category": "permission",
         "error_pattern": "AccessDenied: s3:PutObject",
         "solution_applied": "Granted s3:PutObject to test-deploy",
         "success": true,
         "recurrence_count": 1
       }
     ]
   }
   ```

4. **Error Categories:**
   - `permission`: IAM/permission errors
   - `config`: Terraform configuration errors
   - `resource`: AWS resource errors (quotas, conflicts)
   - `state`: Terraform state errors

5. **Solution Ranking:**
   - Rank by success rate (solutions that worked before)
   - Rank by recency (recent solutions more relevant)
   - Rank by similarity (exact match > partial match)

---

## Commit Message Template

When Phase 2 is complete:

```
feat: Implement fractary-faber-cloud plugin Phase 2 - Testing & Debugging

Phase 2 Complete - Testing and intelligent debugging capabilities added:

**Deliverables:**
- infra-tester skill: Pre/post-deployment testing and validation
- infra-debugger skill: Error analysis with historical learning
- Issue log system: Track and learn from past errors

**Features:**
- Security scanning with Checkov/tfsec
- Cost estimation before deployment
- Post-deployment resource verification
- Error categorization (permission/config/resource/state)
- Solution search with ranking by success rate
- Issue log persistence and learning

**Integration:**
- infra-deployer invokes infra-tester before/after deployment
- infra-manager invokes infra-debugger on failures
- All resolutions logged for future reference

**Success Criteria Met:**
✅ Security scans run before deployment
✅ Cost estimates generated
✅ Post-deployment verification tests pass
✅ Errors categorized correctly
✅ Historical solutions found and ranked
✅ Issue log grows with each resolved issue
✅ Recurring issues solved faster

Addresses Phase 2 deliverables from fractary-faber-cloud-implementation-phases.md
```

---

## Ready to Start

Copy the prompt section above and paste it into a fresh Claude Code session to begin Phase 2 implementation!
