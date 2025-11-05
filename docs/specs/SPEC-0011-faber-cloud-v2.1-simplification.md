# faber-cloud v2.1 Simplification Specification

**Status**: Draft
**Version**: 2.1.0
**Date**: 2025-11-04
**Author**: Fractary Team

## Executive Summary

This specification defines the v2.1 update to the faber-cloud plugin, focused on:

1. **Naming Clarity**: Remove all "devops" references, align with Terraform terminology
2. **Command Simplification**: Break out individual lifecycle commands with clear naming
3. **Enhanced Automation**: Implement automated fix-and-continue debugging pattern
4. **Security Improvements**: Add IAM permission audit system with deploy vs resource distinction
5. **Safety Enhancements**: Add environment safety validation to prevent deployment bugs

## Background

### Current State (v2.0.0)

The faber-cloud plugin was renamed from "fractary-devops" in v2.0.0, with operations monitoring moved to helm-cloud. However, significant "devops" references remain throughout:

- Agent: `devops-director`
- Command: `devops-init`
- Skill: `devops-common`
- Config: `devops.json`
- Documentation: `fractary-devops-*.md` files

The command structure uses unclear terminology:
- `architect` (unclear intent)
- `engineer` (unclear intent)
- `preview` (doesn't match Terraform terminology)
- `deploy` (ambiguous - plan or apply?)

### Reference Implementations Analyzed

**core.corthuxa.ai** - Sophisticated debugging with automated fix-and-continue:
- `infrastructure-debugger` with `--complete` flag for full automation
- IAM permission audit system with JSON trails and sync scripts
- Clear delegation chain: deployer → debugger → permission-manager
- Environment safety validation preventing multi-environment bugs

**core.corthovore.ai** - Simple deployment with structured outputs:
- Deployment history logging with timestamps and costs
- Structured JSON outputs from skills

### Goals for v2.1

1. **Eliminate Confusion**: Remove all devops/ops naming artifacts
2. **Improve Discoverability**: Clear, intuitive command names aligned with industry standards
3. **Enhance Automation**: Reduce manual intervention in error scenarios
4. **Strengthen Security**: Enforce permission boundaries with audit trails
5. **Prevent Bugs**: Add safety validations for common deployment errors

## Architecture

### Three-Layer Pattern (Unchanged)

```
Commands (Entry Points)
   ↓
Agents (Workflow Orchestration)
   ↓
Skills (Task Execution)
```

**Critical Principle**:
- Commands invoke agents with parsed arguments
- Agents (cloud-director, infra-manager) orchestrate workflows and invoke skills
- Skills execute tasks via scripts
- **cloud-director does NOT invoke skills** - only routes to infra-manager

### Component Responsibilities

**cloud-director Agent**:
- Parses natural language intent
- Routes to infra-manager with structured request
- **Never invokes skills directly**

**infra-manager Agent**:
- Orchestrates infrastructure workflows
- Invokes appropriate skills based on operation
- Tracks progress with TodoWrite
- Manages error delegation chain

**Skills**:
- Execute specific infrastructure tasks
- Return structured outputs
- Document their work
- Delegate to other skills when needed (e.g., debugger → permission-manager)

## Detailed Changes

### Phase 1: Command Restructuring

See: `faber-cloud-v2.1-phase1-commands.md`

**Renames**:
- `devops-init.md` → `init.md` (frontmatter: `/fractary-faber-cloud:init`)
- `infra-manage.md` → `manage.md` (frontmatter: `/fractary-faber-cloud:manage`)
- `architect.md` → `design.md` (frontmatter: `/fractary-faber-cloud:design`)
- `engineer.md` → `configure.md` (frontmatter: `/fractary-faber-cloud:configure`)
- `preview.md` → `deploy-plan.md` (frontmatter: `/fractary-faber-cloud:deploy-plan`)
- `deploy.md` → `deploy-apply.md` (frontmatter: `/fractary-faber-cloud:deploy-apply`)

**New Commands**:
- `teardown.md` (frontmatter: `/fractary-faber-cloud:teardown`)

**Argument Format Updates**:
- All commands with description arguments use double quotes: `design "<feature description>"`
- Ensures proper parsing when descriptions contain spaces

### Phase 2: Agent Updates

See: `faber-cloud-v2.1-phase2-agents.md`

**Renames**:
- `devops-director.md` → `cloud-director.md`

**Routing Updates**:
- cloud-director: Parse natural language, route to infra-manager (NO skill invocation)
- infra-manager: Add routing for new operation names (design, configure, deploy-plan, deploy-apply, teardown)

### Phase 3: Skill Enhancements

See: `faber-cloud-v2.1-phase3-skills.md`

**Renames**:
- `infra-architect` → `infra-designer`
- `infra-engineer` → `infra-configurator`
- `infra-previewer` → `infra-planner`
- `devops-common` → `cloud-common`

**Major Enhancements**:
- **infra-debugger**: Add `--complete` flag for automated fix-and-continue
- **infra-permission-manager**: Add IAM audit system with JSON trails and scripts
- **infra-deployer**: Add environment safety validation, TodoWrite tracking, error delegation
- **infra-teardown**: New skill for infrastructure destruction

**New Capabilities**:
- Automated error fixing with deployment continuation
- Complete IAM permission audit trail
- Environment safety validation
- Deploy vs resource permission enforcement

### Phase 4: Documentation Updates

See: `faber-cloud-v2.1-phase4-documentation.md`

**File Renames**:
- All `fractary-devops-*.md` → `fractary-faber-cloud-*.md`

**Content Updates**:
- README.md: Remove all devops/ops references
- Add IAM audit system documentation
- Add automated debugging documentation
- Add environment safety validation documentation
- Add deployment history logging
- Document error delegation chain

### Phase 5: Configuration Updates

See: `faber-cloud-v2.1-phase5-configuration.md`

**Renames**:
- `devops.json` → `faber-cloud.json`

**Schema Updates**:
- Support new operation names
- Add IAM audit system configuration
- Add environment safety validation settings

### Phase 6: Testing & Validation

See: `faber-cloud-v2.1-phase6-testing.md`

**Test Coverage**:
- Command layer: routing, argument parsing
- Agent layer: cloud-director → infra-manager → skills
- Skill layer: all operations, new features
- Integration: full workflows, error scenarios

## Implementation Phases

### Phase 1: Commands (1-2 hours)
- Rename 6 command files
- Create 1 new command (teardown)
- Update argument hints with double quotes
- Update manage.md operation list

### Phase 2: Agents (1 hour)
- Rename devops-director → cloud-director
- Update infra-manager routing
- Verify no skill invocation in cloud-director

### Phase 3: Skills (2-3 hours)
- Rename 4 skills
- Enhance infra-debugger (--complete flag)
- Enhance infra-permission-manager (audit system)
- Enhance infra-deployer (safety validation, TodoWrite)
- Create infra-teardown

### Phase 4: Documentation (1-2 hours)
- Rename all doc files
- Update README.md
- Add new documentation sections
- Create deployment history template

### Phase 5: Configuration (30 minutes)
- Rename devops.json
- Update config schema
- Update cloud-common references

### Phase 6: Testing (1 hour)
- Test all command invocations
- Test agent routing
- Test new capabilities
- Integration testing

**Total Estimated Effort**: 6-9 hours

## Breaking Changes

### Command Names
- `/fractary-faber-cloud:devops-init` → `/fractary-faber-cloud:init`
- `/fractary-faber-cloud:architect` → `/fractary-faber-cloud:design`
- `/fractary-faber-cloud:engineer` → `/fractary-faber-cloud:configure`
- `/fractary-faber-cloud:preview` → `/fractary-faber-cloud:deploy-plan`
- `/fractary-faber-cloud:deploy` → `/fractary-faber-cloud:deploy-apply`
- `/fractary-faber-cloud:infra-manage` → `/fractary-faber-cloud:manage`

### Configuration Files
- `.fractary/plugins/faber-cloud/config/devops.json` → `faber-cloud.json`

### Agent Names (internal)
- `devops-director` → `cloud-director`

### Skill Names (internal)
- `infra-architect` → `infra-designer`
- `infra-engineer` → `infra-configurator`
- `infra-previewer` → `infra-planner`
- `devops-common` → `cloud-common`

## Migration Guide

### For Users

**Update command invocations**:
```bash
# Before v2.1
/fractary-faber-cloud:devops-init
/fractary-faber-cloud:architect "Add monitoring"
/fractary-faber-cloud:engineer
/fractary-faber-cloud:preview
/fractary-faber-cloud:deploy --env=test

# After v2.1
/fractary-faber-cloud:init
/fractary-faber-cloud:design "Add monitoring"
/fractary-faber-cloud:configure
/fractary-faber-cloud:deploy-plan
/fractary-faber-cloud:deploy-apply --env=test
```

**Update configuration files**:
```bash
# Rename config file
mv .fractary/plugins/faber-cloud/config/devops.json \
   .fractary/plugins/faber-cloud/config/faber-cloud.json
```

**New capabilities available**:
```bash
# Automated debugging
/fractary-faber-cloud:debug --complete

# Infrastructure teardown
/fractary-faber-cloud:teardown --env=test

# IAM audit system (see documentation)
```

### For Plugin Developers

**Agent invocations**:
```markdown
<!-- Before v2.1 -->
Use the @agent-fractary-faber-cloud:devops-director to architect infrastructure

<!-- After v2.1 -->
Use the @agent-fractary-faber-cloud:cloud-director to design infrastructure
```

**Skill references**:
- Update any references to renamed skills in documentation
- cloud-director routes to infra-manager (never invokes skills directly)

## Success Criteria

- [ ] All commands renamed and functional
- [ ] No "devops" or "ops" references in user-facing names
- [ ] cloud-director routes to infra-manager without invoking skills
- [ ] infra-manager routes to all skills correctly
- [ ] --complete flag works for automated debugging
- [ ] IAM audit system functional with all scripts
- [ ] Environment safety validation prevents multi-environment bugs
- [ ] Deployment history logging works
- [ ] All documentation updated and accurate
- [ ] All tests passing
- [ ] Migration guide validated

## References

- **Reference Implementation 1**: `/mnt/c/GitHub/corthos/core.corthuxa.ai/`
  - infrastructure-debugger with --complete flag
  - IAM permission audit system
  - Environment safety validation

- **Reference Implementation 2**: `/mnt/c/GitHub/corthos/core.corthovore.ai/`
  - Deployment history logging
  - Structured outputs

- **Related Specifications**:
  - `FRACTARY-PLUGIN-STANDARDS.md` - Plugin development standards
  - `SPEC-0002-faber-architecture.md` - FABER framework architecture
  - `faber-cloud-v2.1-phase1-commands.md` - Detailed command specifications
  - `faber-cloud-v2.1-phase2-agents.md` - Detailed agent specifications
  - `faber-cloud-v2.1-phase3-skills.md` - Detailed skill specifications
  - `faber-cloud-v2.1-phase4-documentation.md` - Documentation updates
  - `faber-cloud-v2.1-phase5-configuration.md` - Configuration changes
  - `faber-cloud-v2.1-phase6-testing.md` - Testing specifications

## Approval

- [ ] Architecture Review
- [ ] Security Review (IAM audit system)
- [ ] User Experience Review (command naming)
- [ ] Documentation Review
- [ ] Implementation Ready
