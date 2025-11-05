# Phase 1: Command Restructuring - faber-cloud v2.1

**Parent Spec**: `faber-cloud-v2.1-simplification.md`
**Estimated Effort**: 1-2 hours

## Overview

Rename and restructure all commands to provide clear, intuitive entry points aligned with Terraform terminology and industry standards.

## Command Naming Philosophy

### Principles

1. **Terraform Alignment**: Use `plan`/`apply` terminology matching Terraform
2. **Clarity Over Brevity**: `design` is clearer than `architect`
3. **Namespace Consistency**: File names simple, frontmatter includes full namespace
4. **Quote Hints**: Show double quotes in argument hints for multi-word values

### File vs Frontmatter Convention

**Pattern**:
- File name: Simple, no prefix (e.g., `init.md`)
- Frontmatter name: Full namespace (e.g., `/fractary-faber-cloud:init`)

**Rationale**: Distinguishes from other plugins' similar commands (work:init, repo:init, faber-cloud:init)

## Command Renames

### Core Commands

#### 1. devops-init.md → init.md

**Current File**: `plugins/faber-cloud/commands/devops-init.md`
**New File**: `plugins/faber-cloud/commands/init.md`

**Frontmatter Changes**:
```yaml
# Before
name: /fractary-faber-cloud:devops-init

# After
name: /fractary-faber-cloud:init
```

**Rationale**: "devops" prefix no longer needed; plugin is faber-cloud focused

**Agent Invocation**: Still routes to infra-manager (previously via devops-director)

---

#### 2. infra-manage.md → manage.md

**Current File**: `plugins/faber-cloud/commands/infra-manage.md`
**New File**: `plugins/faber-cloud/commands/manage.md`

**Frontmatter Changes**:
```yaml
# Before
name: /fractary-faber-cloud:infra-manage

# After
name: /fractary-faber-cloud:manage
```

**Usage Updates**:
```markdown
# Before
Usage: /fractary-faber-cloud:infra-manage architect [--feature <description>] | engineer | validate | preview | deploy --env=<env> | show-resources [--env <env>] | status

# After
Usage: /fractary-faber-cloud:manage <operation> [options]

Operations:
  design "<description>"              Design infrastructure from requirements
  configure                           Generate IaC configuration files
  validate                            Validate configuration files
  test                                Run security and cost tests
  deploy-plan                         Preview deployment changes
  deploy-apply --env=<env>           Execute infrastructure deployment
  status [--env <env>]               Check deployment status
  resources [--env <env>]            Show deployed resources
  debug [--complete]                 Analyze and fix deployment errors
  teardown --env=<env>               Destroy infrastructure

Examples:
  /fractary-faber-cloud:manage design "Add CloudWatch monitoring"
  /fractary-faber-cloud:manage configure
  /fractary-faber-cloud:manage deploy-plan
  /fractary-faber-cloud:manage deploy-apply --env=test
  /fractary-faber-cloud:manage debug --complete
```

**Key Changes**:
- Operations list now matches new command names
- Clear descriptions for each operation
- Double quotes shown in usage for `design "<description>"`
- Examples included for clarity

**Rationale**:
- "infra" prefix redundant (all faber-cloud commands are infrastructure-focused)
- New operation names match individual commands for consistency
- Clearer argument hints prevent parsing errors

**Agent Invocation**: Routes to infra-manager

---

### Lifecycle Commands

#### 3. architect.md → design.md

**Current File**: `plugins/faber-cloud/commands/architect.md`
**New File**: `plugins/faber-cloud/commands/design.md`

**Frontmatter Changes**:
```yaml
# Before
name: /fractary-faber-cloud:architect
description: Design infrastructure solutions from requirements

# After
name: /fractary-faber-cloud:design
description: Design infrastructure solutions from requirements
```

**Usage Updates**:
```markdown
# Before
Usage: /fractary-faber-cloud:architect --feature <description>

# After
Usage: /fractary-faber-cloud:design "<feature description>"

Examples:
  /fractary-faber-cloud:design "Add CloudWatch monitoring for Lambda functions"
  /fractary-faber-cloud:design "Implement S3 bucket lifecycle policies"
```

**Rationale**: "Design" is more intuitive than "architect" as a verb

**Agent Invocation**: Routes to infra-manager with operation="design"

---

#### 4. engineer.md → configure.md

**Current File**: `plugins/faber-cloud/commands/engineer.md`
**New File**: `plugins/faber-cloud/commands/configure.md`

**Frontmatter Changes**:
```yaml
# Before
name: /fractary-faber-cloud:engineer
description: Generate IaC code from architecture

# After
name: /fractary-faber-cloud:configure
description: Generate IaC configuration files from design
```

**Usage Updates**:
```markdown
# Before
Usage: /fractary-faber-cloud:engineer [options]

# After
Usage: /fractary-faber-cloud:configure [options]

Examples:
  /fractary-faber-cloud:configure
  /fractary-faber-cloud:configure --validate
```

**Rationale**:
- "Configure" better describes generating configuration files
- "Engineer" as verb is ambiguous (what type of engineering?)

**Agent Invocation**: Routes to infra-manager with operation="configure"

---

#### 5. preview.md → deploy-plan.md

**Current File**: `plugins/faber-cloud/commands/preview.md`
**New File**: `plugins/faber-cloud/commands/deploy-plan.md`

**Frontmatter Changes**:
```yaml
# Before
name: /fractary-faber-cloud:preview
description: Preview infrastructure changes before deployment

# After
name: /fractary-faber-cloud:deploy-plan
description: Generate and preview deployment plan (terraform plan)
```

**Usage Updates**:
```markdown
# Before
Usage: /fractary-faber-cloud:preview [--env <environment>]

# After
Usage: /fractary-faber-cloud:deploy-plan [--env <environment>]

Examples:
  /fractary-faber-cloud:deploy-plan
  /fractary-faber-cloud:deploy-plan --env=test
```

**Rationale**:
- Matches Terraform terminology (terraform plan)
- Clear distinction from deploy-apply
- "preview" too generic (preview what?)

**Agent Invocation**: Routes to infra-manager with operation="deploy-plan"

---

#### 6. deploy.md → deploy-apply.md

**Current File**: `plugins/faber-cloud/commands/deploy.md`
**New File**: `plugins/faber-cloud/commands/deploy-apply.md`

**Frontmatter Changes**:
```yaml
# Before
name: /fractary-faber-cloud:deploy
description: Deploy infrastructure changes

# After
name: /fractary-faber-cloud:deploy-apply
description: Execute deployment (terraform apply)
```

**Usage Updates**:
```markdown
# Before
Usage: /fractary-faber-cloud:deploy --env=<environment> [options]

# After
Usage: /fractary-faber-cloud:deploy-apply --env=<environment> [options]

Examples:
  /fractary-faber-cloud:deploy-apply --env=test
  /fractary-faber-cloud:deploy-apply --env=prod --auto-approve
```

**Rationale**:
- Matches Terraform terminology (terraform apply)
- Clear distinction from deploy-plan
- Explicit about executing changes (not just planning)

**Agent Invocation**: Routes to infra-manager with operation="deploy-apply"

---

### New Commands

#### 7. teardown.md (NEW)

**File**: `plugins/faber-cloud/commands/teardown.md`

**Frontmatter**:
```yaml
name: /fractary-faber-cloud:teardown
description: Destroy infrastructure (terraform destroy)
```

**Full Content**:
```markdown
---
name: /fractary-faber-cloud:teardown
description: Destroy infrastructure (terraform destroy)
---

# Teardown Infrastructure

Destroy deployed infrastructure in the specified environment.

## Usage

/fractary-faber-cloud:teardown --env=<environment> [options]

## Arguments

- `--env=<environment>` (required): Environment to destroy (test, staging, prod)
- `--confirm` (optional): Skip confirmation prompts (dangerous!)

## Examples

```bash
# Destroy test environment (with confirmation)
/fractary-faber-cloud:teardown --env=test

# Destroy with auto-confirmation (be careful!)
/fractary-faber-cloud:teardown --env=test --confirm
```

## Safety

**Production Safety**: Destroying production infrastructure requires multiple confirmations and cannot use `--confirm` flag.

**State Backup**: Terraform state is automatically backed up before destruction.

**Verification**: After destruction, verifies all resources are removed.

## Workflow

1. Validate environment exists
2. Backup Terraform state
3. Request confirmation (multiple for production)
4. Execute terraform destroy
5. Verify resource removal
6. Document destruction in deployment history

## Agent Invocation

This command invokes the infra-manager agent with operation="teardown".
```

**Rationale**:
- Essential lifecycle operation missing from current commands
- Matches terraform destroy
- Critical safety features for production

**Agent Invocation**: Routes to infra-manager with operation="teardown"

**New Skill Required**: `infra-teardown` (see phase 3)

---

## Existing Commands (No Rename)

These commands remain unchanged:

- **validate.md** - `/fractary-faber-cloud:validate` (clear as-is)
- **test.md** - `/fractary-faber-cloud:test` (clear as-is)
- **status.md** - `/fractary-faber-cloud:status` (clear as-is)
- **resources.md** - `/fractary-faber-cloud:resources` (clear as-is)
- **debug.md** - `/fractary-faber-cloud:debug` (clear as-is)
- **director.md** - `/fractary-faber-cloud:director` (natural language interface)

**Note**: These commands may need minor documentation updates to reference new operation names, but their names and core functionality remain the same.

---

## Implementation Checklist

### File Operations

- [ ] Rename `devops-init.md` → `init.md`
- [ ] Rename `infra-manage.md` → `manage.md`
- [ ] Rename `architect.md` → `design.md`
- [ ] Rename `engineer.md` → `configure.md`
- [ ] Rename `preview.md` → `deploy-plan.md`
- [ ] Rename `deploy.md` → `deploy-apply.md`
- [ ] Create `teardown.md` (new command)

### Content Updates

- [ ] Update frontmatter `name` in all renamed files
- [ ] Update usage strings with double quotes for descriptions
- [ ] Update `manage.md` operation list to match new names
- [ ] Add examples to all commands
- [ ] Update cross-references in unchanged commands

### Validation

- [ ] All command files have correct frontmatter namespace
- [ ] All usage strings show proper argument format
- [ ] All commands route to correct agent (infra-manager or cloud-director)
- [ ] manage.md operation list matches individual commands
- [ ] teardown.md includes all safety features

## Testing

### Manual Testing

```bash
# Test each renamed command
/fractary-faber-cloud:init
/fractary-faber-cloud:design "Test feature"
/fractary-faber-cloud:configure
/fractary-faber-cloud:deploy-plan
/fractary-faber-cloud:deploy-apply --env=test
/fractary-faber-cloud:manage status
/fractary-faber-cloud:teardown --env=test

# Test argument parsing with spaces
/fractary-faber-cloud:design "Multi word description with spaces"
```

### Validation Points

- [ ] All commands invoke without errors
- [ ] Arguments with spaces parse correctly
- [ ] Commands route to correct agents
- [ ] Help text displays correctly
- [ ] manage.md shows updated operation list

## Rollback Plan

If issues arise:

1. Git checkout original command files
2. Revert frontmatter changes
3. Document issues encountered
4. Revise specification before retry

## Next Phase

After Phase 1 completion, proceed to **Phase 2: Agent Updates** (`faber-cloud-v2.1-phase2-agents.md`)
