# Faber-Cloud Integration Patterns

**Best Practices for Integrating Faber-Cloud into Existing Projects**

This guide documents proven patterns for successfully integrating the faber-cloud plugin into existing infrastructure projects, based on real-world adoption experience.

## Overview

When adopting faber-cloud, you have two primary integration patterns that work together:

1. **Skill-Based Hooks** - For project-specific validation and custom logic
2. **Lightweight Project Commands** - That delegate to faber-cloud agents with project context

These patterns allow you to:
- ✅ Preserve project-specific requirements
- ✅ Leverage faber-cloud's standardized workflows
- ✅ Maintain clean separation between project and plugin
- ✅ Make custom logic reusable and testable

---

## Pattern 1: Skill-Based Hooks

### When to Use

Use skill-based hooks for:
- **Project-specific validation** (dataset schemas, API contracts, compliance)
- **Custom build steps** (Lambda packaging, asset compilation)
- **Integration requirements** (external system validations)
- **Business logic** that's unique to your domain

### How It Works

**Before** (custom scripts embedded everywhere):
```bash
# In your deploy script
terraform plan
./scripts/validate-datasets.sh  # Custom validation
./scripts/check-compliance.sh   # Custom validation
terraform apply
```

**After** (skill hooks at lifecycle points):
```json
{
  "hooks": {
    "pre-deploy": [
      {
        "type": "skill",
        "name": "dataset-validator-deploy-pre",
        "required": true,
        "failureMode": "stop"
      },
      {
        "type": "skill",
        "name": "compliance-checker",
        "required": true,
        "failureMode": "stop"
      }
    ]
  }
}
```

### Implementation Steps

**1. Identify Custom Validation Logic**

Look for scripts that:
- Validate data formats, schemas, or content
- Check compliance with internal standards
- Verify prerequisites before deployment
- Test integrations with external systems

**2. Convert to Skills**

Create `.claude/skills/{skill-name}/SKILL.md`:

```markdown
---
name: dataset-validator-deploy-pre
description: Validate datasets before infrastructure deployment
tools: Read, Bash
---

# Dataset Validator

<CONTEXT>
You validate datasets meet our project requirements before deploying infrastructure.
</CONTEXT>

<WORKFLOW>
1. Read WorkflowContext to get environment and operation
2. Load dataset files from expected locations
3. Validate schemas against standards
4. Check data quality metrics
5. Return WorkflowResult with validation status
</WORKFLOW>
```

**3. Configure Hook**

Add to `.fractary/plugins/faber-cloud/faber-cloud.json`:

```json
{
  "hooks": {
    "pre-deploy": [
      {
        "type": "skill",
        "name": "dataset-validator-deploy-pre",
        "required": true,
        "timeout": 300
      }
    ]
  }
}
```

**4. Test Independently**

```bash
# Test skill in isolation
export FABER_CLOUD_ENV="test"
export FABER_CLOUD_OPERATION="deploy"
/skill dataset-validator-deploy-pre

# Test in full workflow
/fractary-faber-cloud:deploy-apply --env=test
```

### Benefits

- ✅ **Discoverable** - Skills appear in `/help`
- ✅ **Testable** - Can test independently before deployment
- ✅ **Reusable** - Can share across projects
- ✅ **Structured** - Clear input/output interfaces
- ✅ **Versioned** - In git with your project

### Real-World Example

**Project:** ETL pipeline infrastructure
**Challenge:** Dataset validation before deploying infrastructure
**Solution:** Two skill hooks:

1. `dataset-validator-deploy-pre` - Pre-deployment validation
   - Checks dataset schemas
   - Validates data quality
   - Verifies compatibility with infrastructure

2. `dataset-validator-deploy-post` - Post-deployment verification
   - Tests infrastructure can access datasets
   - Validates data pipeline integration
   - Confirms deployment success

**Result:** Automated validation that blocks deployments if data doesn't meet requirements, preventing infrastructure/data mismatches.

---

## Pattern 2: Lightweight Project Commands

### When to Use

Use lightweight commands for:
- **Project-specific deployment flows** with standard infrastructure operations
- **Passing project context** (docs, standards, requirements) to faber-cloud
- **Maintaining familiar CLI** while using faber-cloud underneath
- **Wrapping faber-cloud** with project-specific defaults

### How It Works

**Before** (custom deploy agent):
```markdown
# .claude/agents/deploy-agent.md
You are the deployment agent. You handle all deployment logic:
- Read project requirements
- Validate configurations
- Run terraform
- Verify deployment
- Update documentation
[...100+ lines of custom deployment logic...]
```

**After** (lightweight command delegates to faber-cloud):
```markdown
# .claude/commands/deploy.md
Deploy infrastructure using faber-cloud with project-specific context.

Use the @agent-fractary-faber-cloud:infra-manager agent to deploy infrastructure with the following project context:

**Project:** {{project-name}}
**Environment:** {{environment}}

**Project-Specific Requirements:**
[Read from docs/INFRASTRUCTURE-REQUIREMENTS.md]

**Deployment Standards:**
[Read from docs/DEPLOYMENT-STANDARDS.md]

Execute deployment with these requirements in mind.
```

### Implementation Steps

**1. Identify Existing Commands**

Look for:
- Deploy/apply commands
- Validation commands
- Infrastructure management commands

Example:
```bash
.claude/commands/
  ├── deploy.md
  ├── validate-infra.md
  └── teardown.md
```

**2. Convert to Delegation Pattern**

**Before** (custom logic):
```markdown
---
name: deploy
description: Deploy infrastructure
---

# Deploy Command

You are the deploy command. Execute the following:

1. Load configuration
2. Validate AWS credentials
3. Run terraform init
4. Run terraform plan
5. Get approval
6. Run terraform apply
7. Verify deployment
8. Update docs
```

**After** (delegates to faber-cloud):
```markdown
---
name: deploy
description: Deploy infrastructure using faber-cloud with project context
---

# Deploy Command

Use the @agent-fractary-faber-cloud:infra-manager agent to deploy infrastructure.

**Project Context:**

Read and provide these project-specific documents to the agent:
- `docs/ARCHITECTURE.md` - Infrastructure architecture
- `docs/DEPLOYMENT-STANDARDS.md` - Deployment requirements
- `docs/NAMING-CONVENTIONS.md` - Resource naming rules

**Environment:** ${environment:-test}

**Request:** Deploy infrastructure following our project standards documented above.
```

**3. Extract Project Documentation**

Create focused documentation files that faber-cloud can reference:

```
docs/
  ├── ARCHITECTURE.md          # Infrastructure design decisions
  ├── DEPLOYMENT-STANDARDS.md  # Project-specific requirements
  ├── NAMING-CONVENTIONS.md    # Resource naming patterns
  └── SECURITY-REQUIREMENTS.md # Security policies
```

**4. Test Command**

```bash
# Test with defaults
/deploy

# Test with specific environment
/deploy --env=prod
```

### Benefits

- ✅ **Familiar interface** - Keep existing command names
- ✅ **Project context** - Pass docs/standards to faber-cloud
- ✅ **Leverage faber-cloud** - Use tested workflows underneath
- ✅ **Maintainable** - Minimal custom code to maintain
- ✅ **Upgradeable** - Benefit from faber-cloud improvements

### Real-World Example

**Project:** Multi-environment SaaS infrastructure
**Challenge:** Existing `/deploy` command with custom validation logic
**Solution:**

**Old approach** (900+ lines across custom agents):
- `deploy-agent.md` - 400 lines
- `validate-agent.md` - 300 lines
- `permission-agent.md` - 200 lines

**New approach** (50 lines total):
```markdown
# .claude/commands/deploy.md

Use @agent-fractary-faber-cloud:infra-manager to deploy infrastructure.

**Project Context:**
[Read docs/ARCHITECTURE.md - 200 lines of architecture decisions]
[Read docs/STANDARDS.md - 150 lines of standards]

**Request:** Deploy to {{environment}} following our standards.
```

**Result:**
- 95% reduction in custom agent code
- Leverage faber-cloud's tested deployment workflows
- Preserve project-specific requirements via documentation
- Easier to maintain and upgrade

---

## Combining Both Patterns

The power comes from using **both patterns together**:

### Example: Complete Integration

```
Project Structure:
├── .claude/
│   ├── commands/
│   │   ├── deploy.md              # Lightweight command (Pattern 2)
│   │   └── validate.md            # Lightweight command (Pattern 2)
│   └── skills/
│       ├── dataset-validator-deploy-pre/   # Skill hook (Pattern 1)
│       ├── dataset-validator-deploy-post/  # Skill hook (Pattern 1)
│       └── compliance-checker/             # Skill hook (Pattern 1)
├── docs/
│   ├── ARCHITECTURE.md            # Context for faber-cloud
│   ├── STANDARDS.md               # Context for faber-cloud
│   └── REQUIREMENTS.md            # Context for faber-cloud
└── .fractary/
    └── plugins/
        └── faber-cloud/
            └── config/
                └── faber-cloud.json
```

**Workflow:**

1. **User invokes project command:**
   ```bash
   /deploy --env=test
   ```

2. **Command delegates to faber-cloud:**
   ```markdown
   # .claude/commands/deploy.md
   Use @agent-fractary-faber-cloud:infra-manager to deploy
   with context from docs/ARCHITECTURE.md and docs/STANDARDS.md
   ```

3. **Faber-cloud executes standard workflow:**
   - Frame → Architect → Build → Evaluate → Release

4. **Skill hooks inject at lifecycle points:**
   ```json
   {
     "hooks": {
       "pre-deploy": [
         {"type": "skill", "name": "dataset-validator-deploy-pre"}
       ],
       "post-deploy": [
         {"type": "skill", "name": "dataset-validator-deploy-post"}
       ]
     }
   }
   ```

5. **Result:**
   - Familiar `/deploy` command
   - Project-specific validation (skill hooks)
   - Project-specific requirements (passed via docs)
   - Standard faber-cloud workflows
   - Minimal custom code to maintain

---

## Migration Strategy

### Phase 1: Discovery

Use the enhanced `adopt` command to analyze your project:

```bash
/fractary-faber-cloud:adopt
```

This discovers:
- ✅ Existing infrastructure (Terraform, AWS)
- ✅ Custom scripts and validation logic
- ✅ Deployment commands and agents
- ✅ Project documentation
- ✅ **NEW:** Integration pattern opportunities

### Phase 2: Plan

Review the migration report which now includes:

**Hook Opportunities:**
```
Found 3 validation scripts → Recommend skill hooks:
- scripts/validate-datasets.sh → dataset-validator skill
- scripts/check-compliance.sh → compliance-checker skill
- scripts/verify-api.sh → api-validator skill
```

**Command Delegations:**
```
Found 2 deployment commands → Recommend delegation:
- .claude/commands/deploy.md → Delegate to infra-manager
- .claude/commands/teardown.md → Delegate to infra-manager
```

**Project Documentation:**
```
Found 4 relevant docs → Use as context:
- docs/ARCHITECTURE.md → Pass to infra-manager
- docs/STANDARDS.md → Pass to infra-manager
- docs/NAMING.md → Pass to infra-manager
- README.md → Pass to infra-manager
```

### Phase 3: Implement

**Step 1: Create Skill Hooks**

For each validation script identified:
```bash
# Convert script to skill
mkdir -p .claude/skills/dataset-validator-deploy-pre
# Copy logic to SKILL.md with proper interface
```

**Step 2: Update Commands**

For each deployment command:
```markdown
# Before: Custom agent
Use custom-deploy-agent...

# After: Delegate to faber-cloud
Use @agent-fractary-faber-cloud:infra-manager
with context from docs/ARCHITECTURE.md...
```

**Step 3: Configure Hooks**

Add to `.fractary/plugins/faber-cloud/faber-cloud.json`:
```json
{
  "hooks": {
    "pre-deploy": [
      {"type": "skill", "name": "dataset-validator-deploy-pre"}
    ],
    "post-deploy": [
      {"type": "skill", "name": "dataset-validator-deploy-post"}
    ]
  }
}
```

**Step 4: Test**

```bash
# Test skills independently
/skill dataset-validator-deploy-pre

# Test command (which uses faber-cloud + hooks)
/deploy --env=test

# Verify workflow
# → Command delegates to infra-manager
# → Faber-cloud executes standard workflow
# → Hooks run at lifecycle points
# → Deployment completes with validation
```

### Phase 4: Iterate

- Monitor first few deployments
- Adjust hook timing if needed
- Refine project documentation passed to faber-cloud
- Add more skill hooks as patterns emerge

---

## Decision Matrix

**When should each pattern be used?**

| Scenario | Pattern | Why |
|----------|---------|-----|
| Dataset validation before deploy | Skill Hook | Project-specific, reusable logic |
| Build Lambda functions | Skill Hook or Script Hook | Build step, testable independently |
| Deploy to environment | Lightweight Command | Standard workflow with project context |
| Validate infrastructure | Lightweight Command | Standard workflow, pass requirements |
| Check API contracts | Skill Hook | Project-specific validation |
| Custom resource naming | Pass via docs | Standard pattern, project-specific rules |
| Security compliance | Skill Hook | Custom rules, reusable |
| Cost estimation | Use faber-cloud | Standard functionality |
| Terraform operations | Use faber-cloud | Standard operations |

---

## Anti-Patterns

### ❌ Don't: Recreate Faber-Cloud Logic

```markdown
# .claude/agents/custom-deploy.md
You are the deploy agent.
1. Run terraform init
2. Run terraform plan
3. Run terraform apply
4. Verify resources
[...reimplementing faber-cloud...]
```

Instead: **Delegate to faber-cloud**

### ❌ Don't: Put Business Logic in Commands

```markdown
# .claude/commands/deploy.md
1. Validate datasets (embedded logic)
2. Check schemas (embedded logic)
3. Deploy infrastructure
```

Instead: **Use skill hooks**

### ❌ Don't: Hardcode Project Specifics

```json
{
  "resource_naming": {
    "pattern": "myproject-{resource}-{env}"  // ❌ Hardcoded
  }
}
```

Instead: **Pass via documentation that faber-cloud reads**

---

## FAQ

**Q: Should I convert all my custom scripts to skills?**
A: No. Only convert logic that's:
- Project-specific (not generic infrastructure operations)
- Reusable (could be used in multiple places)
- Testable (benefits from independent testing)

**Q: When should I use script hooks vs skill hooks?**
A:
- **Script hooks:** Simple, one-time operations (build, notify)
- **Skill hooks:** Complex validation, reusable logic, project-specific requirements

**Q: How much project context should I pass to faber-cloud?**
A:
- ✅ Architecture decisions
- ✅ Naming conventions
- ✅ Security requirements
- ✅ Deployment standards
- ❌ Terraform code (faber-cloud generates)
- ❌ AWS credentials (use profiles)

**Q: Can I mix old custom agents with new patterns?**
A: Yes, but migrate incrementally:
1. Start with hooks for validation
2. Convert commands to delegation
3. Remove custom agents as you verify equivalents
4. Test thoroughly at each step

**Q: What if faber-cloud doesn't support my use case?**
A:
1. Check if hooks can address it (most custom logic)
2. Pass requirements via docs (standards, patterns)
3. If truly unique, keep custom agent but isolate it
4. Consider contributing to faber-cloud if it's generally useful

---

## Real-World Case Study

**Project:** ETL Pipeline Infrastructure (Corthos)

**Before Faber-Cloud:**
- Custom deploy agent: 600+ lines
- Custom validation scripts: 5 separate scripts
- Manual deployment process
- No standardized testing

**After Integration (Using Both Patterns):**

**Skill Hooks Created:**
- `dataset-validator-deploy-pre` - Pre-deployment data validation
- `dataset-validator-deploy-post` - Post-deployment verification

**Commands Converted:**
- `/deploy` - Now delegates to faber-cloud with project docs
- `/validate` - Delegates to faber-cloud with standards

**Project Documentation:**
- `docs/DATASET-REQUIREMENTS.md` - Data validation rules
- `docs/INFRASTRUCTURE-STANDARDS.md` - Deployment standards
- `docs/ARCHITECTURE.md` - Infrastructure design

**Results:**
- 90% reduction in custom agent code
- Automated validation at lifecycle points
- Testable validation logic (skills)
- Leverage faber-cloud's tested workflows
- Easier to maintain and upgrade
- Better separation of concerns

**Key Insight:**
> "The two-pattern approach let us keep what was unique about our project (dataset validation) while leveraging battle-tested infrastructure workflows. We went from maintaining 600+ lines of deployment logic to 50 lines of delegation + focused skill hooks."

---

## Next Steps

1. **Run enhanced adopt:**
   ```bash
   /fractary-faber-cloud:adopt
   ```

2. **Review integration recommendations** in the generated migration report

3. **Implement patterns incrementally:**
   - Start with 1-2 skill hooks
   - Convert 1 command to delegation
   - Test thoroughly
   - Expand gradually

4. **Monitor and refine:**
   - Collect feedback from team
   - Adjust hook timing
   - Refine project documentation
   - Share learnings

---

## Resources

- [Hook System Guide](HOOKS.md) - Complete hook documentation
- [Skill Hook Examples](../examples/skill-hooks/) - Working examples
- [Migration from Custom Agents](MIGRATION-FROM-CUSTOM-AGENTS.md) - Full migration guide
- [Security Considerations](../SECURITY.md) - Hook security best practices

---

**Last Updated:** 2025-11-07
**Based On:** Real-world integration experience (Corthos ETL project)
