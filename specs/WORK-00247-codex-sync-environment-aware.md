---
spec_id: WORK-00247-codex-sync-environment-aware
work_id: 247
issue_url: https://github.com/fractary/claude-plugins/issues/247
title: Make codex-sync environment aware
type: feature
status: implemented
created: 2025-12-06
updated: 2025-12-06
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: Make codex-sync environment aware

**Issue**: [#247](https://github.com/fractary/claude-plugins/issues/247)
**Type**: Feature
**Status**: Implemented
**Created**: 2025-12-06
**Updated**: 2025-12-06

## Summary

Add environment awareness to the codex sync system, enabling documentation to be synced to environment-specific branches (`dev`, `test`, `staging`, `prod`) in the codex repository. The system auto-detects the target environment from the source project's current branch, with explicit `--env` flag available for override. This allows downstream systems working in test environments to receive documentation for unreleased features, while production environments only see documentation for released features.

## Problem Statement

Currently, codex sync operations work against a single branch (typically `main`) in the codex repository. This creates a timing issue:

1. Documentation for features in test/staging environments needs to be available to downstream test systems
2. Production documentation should only contain released features
3. There's no mechanism to separate test vs production documentation in codex

## User Stories

### Story 1: Developer syncing test documentation
**As a** developer working on a feature branch
**I want** documentation to automatically sync to the codex test branch
**So that** downstream test systems can access my feature documentation without explicit flags

**Acceptance Criteria**:
- [ ] When on a feature/fix branch, sync defaults to `test` environment
- [ ] Documentation syncs to `test` branch in codex repository
- [ ] Can override with explicit `--env` flag if needed

### Story 2: Release manager promoting to production
**As a** release manager on the main branch
**I want** to sync documentation to the codex production branch with confirmation
**So that** only released features are visible in production documentation

**Acceptance Criteria**:
- [ ] When on main/master branch, sync prompts for confirmation before proceeding to prod
- [ ] Can specify explicit `--env prod` to skip confirmation
- [ ] Documentation syncs to `main` branch in codex repository

### Story 3: Developer without test branch
**As a** developer whose organization doesn't use a separate test environment
**I want** to configure codex to treat test as production
**So that** all syncs go to main branch without needing explicit flags

**Acceptance Criteria**:
- [ ] Can configure `test` environment to use `main` branch
- [ ] Default behavior then syncs to main (with appropriate warnings)
- [ ] No need to create separate test branch

## Functional Requirements

- **FR1**: Add `--env <dev|test|staging|prod>` argument to sync commands (`sync-project`, `sync-org`)
- **FR2**: Auto-detect environment from source project's current branch:
  - Feature/fix/etc branches → `test` environment
  - Main/master branch → `prod` environment (with confirmation prompt)
- **FR3**: Map environments to configurable codex repository branches (defaults: dev→test, test→test, staging→main, prod→main)
- **FR4**: Prompt for confirmation when syncing to prod environment is **assumed** (not explicit)
- **FR5**: Prompt for confirmation when test environment is configured to use same branch as prod (effectively going to prod)
- **FR6**: Support environment configuration in `.fractary/plugins/codex/config.json` with customizable branch mappings
- **FR7**: When target branch doesn't exist, display helpful error with branch creation command
- **FR8**: MCP server always fetches from production branch (single cache, no environment segregation)
- **FR9**: Manual sync commands can pull from any environment for local development

## Non-Functional Requirements

- **NFR1**: Environment switching must not require re-cloning entire repository (use branch checkout) (performance)
- **NFR2**: Environment flag must be validated before any sync operations begin (validation)
- **NFR3**: Clear error messages when attempting invalid environment operations (usability)
- **NFR4**: Breaking change is acceptable - this is the right time to make it (maintainability)

## Technical Design

### Architecture Changes

The environment awareness will be implemented at three layers:

1. **Command Layer**: Parse `--env` argument, auto-detect from branch if not provided, handle confirmation prompts
2. **Skill Layer**: Use environment to determine target branch in codex repo via config lookup
3. **Handler Layer**: Clone/checkout appropriate branch based on environment

```
┌─────────────────────────────────────────────────────────────┐
│ Command: sync-project                                       │
│   ↓ no --env provided                                       │
│   ↓ detects current branch: feat/247-environment-aware      │
│   ↓ auto-maps to: test environment                          │
├─────────────────────────────────────────────────────────────┤
│ Agent: codex-manager                                        │
│   ↓ passes environment in operation parameters              │
├─────────────────────────────────────────────────────────────┤
│ Skill: project-syncer                                       │
│   ↓ reads config: environments.test.branch = "test"         │
│   ↓ target branch: test                                     │
├─────────────────────────────────────────────────────────────┤
│ Handler: handler-sync-github                                │
│   ↓ clones codex repo, checks out "test" branch             │
│   ↓ performs file sync                                      │
└─────────────────────────────────────────────────────────────┘
```

### Environment Auto-Detection Logic

```
IF --env explicitly provided THEN
  use provided environment
  skip confirmation (user was explicit)
ELSE
  detect current branch
  IF branch is main/master THEN
    environment = prod
    PROMPT: "You are on main branch. Sync to PRODUCTION? [y/N]"
    IF user declines: abort
  ELSE (feature/fix/etc branch)
    environment = test

    # Check if test effectively equals prod
    IF config.environments.test.branch == config.environments.prod.branch THEN
      PROMPT: "Test environment is configured to use production branch. Continue? [y/N]"
      IF user declines: abort
    END
  END
END

# After environment determined, check branch exists
target_branch = config.environments[environment].branch
IF target_branch does not exist in codex repo THEN
  ERROR with helpful message (see Error Handling section)
END
```

### Data Model

**Configuration Schema Extension** (`.fractary/plugins/codex/config.json`):

```json
{
  "environments": {
    "dev": {
      "branch": "test",
      "description": "Development environment"
    },
    "test": {
      "branch": "test",
      "description": "Test/QA environment"
    },
    "staging": {
      "branch": "main",
      "description": "Staging environment (defaults to prod branch)"
    },
    "prod": {
      "branch": "main",
      "description": "Production environment"
    }
  }
}
```

**Default Configuration**:
- `dev` → `test` branch (assumes dev uses same as test)
- `test` → `test` branch
- `staging` → `main` branch (assumes no separate staging; if staging exists, user changes to "staging")
- `prod` → `main` branch

**Custom Environment Names**: Users can add custom environments by adding new keys to the `environments` object. They must ensure consistency across other configs (e.g., faber-cloud deployment profiles use environment names).

**Cache Format**: No change - single cache, no environment segregation. MCP server always fetches from prod. Manual sync commands specify which environment to pull from.

### API Design

**Command Arguments**:
- `--env <environment>`: Specify target environment (dev, test, staging, prod, or custom)
- Default: Auto-detected from current branch
- Alias: `--environment`

**Examples**:
```bash
# Auto-detect environment from current branch
# On feat/123-feature branch → syncs to test
# On main branch → prompts, then syncs to prod
/fractary-codex:sync-project

# Explicit environment (skips confirmation)
/fractary-codex:sync-project --env test
/fractary-codex:sync-project --env prod
/fractary-codex:sync-project --env staging

# Sync org with explicit environment
/fractary-codex:sync-org --env test
```

### UI/UX Changes

**Standard output** (environment auto-detected):
```
🎯 STARTING: Project Sync
Project: claude-plugins
Codex: codex.fractary.com
Environment: test (auto-detected from branch: feat/247-environment-aware)
Target Branch: test
Direction: bidirectional
───────────────────────────────────────
```

**Production confirmation prompt** (on main branch, no explicit --env):
```
⚠️  PRODUCTION SYNC CONFIRMATION

You are on the main branch. This will sync documentation to PRODUCTION.

Target: codex.fractary.com (main branch)
Direction: bidirectional

Are you sure you want to sync to production? [y/N]:
```

**Test-equals-prod warning** (test configured to use main branch):
```
⚠️  ENVIRONMENT CONFIGURATION WARNING

The test environment is configured to use the production branch (main).
This means your sync will go directly to production.

If you want a separate test environment:
1. Create test branch: /fractary-repo:branch-create test --base main
2. Update config: .fractary/plugins/codex/config.json
   Set environments.test.branch = "test"

Continue syncing to production? [y/N]:
```

**Branch doesn't exist error**:
```
❌ TARGET BRANCH NOT FOUND

The target branch 'test' does not exist in the codex repository.

To create the test branch:
  /fractary-repo:branch-create test --base main

Or, if you don't need a separate test environment:
  Edit .fractary/plugins/codex/config.json
  Set environments.test.branch = "main"

This will make all syncs go to the main (production) branch.
```

## Implementation Plan

### Phase 1: Configuration Schema
Add environment configuration support

**Tasks**:
- [ ] Update config schema to include `environments` section with dev/test/staging/prod
- [ ] Set default branch mappings (dev→test, test→test, staging→main, prod→main)
- [ ] Update `/fractary-codex:init` to create default environments config
- [ ] Add config validation for environment entries

### Phase 2: Command Layer - Auto-Detection & Prompts
Implement branch detection and confirmation flow

**Tasks**:
- [ ] Update `sync-project.md` command to:
  - [ ] Parse `--env` argument (optional)
  - [ ] Auto-detect environment from current git branch
  - [ ] Implement confirmation prompt for assumed prod (on main branch)
  - [ ] Implement warning prompt when test==prod in config
- [ ] Update `sync-org.md` command with same logic
- [ ] Add helper function/script to detect current branch and map to environment

### Phase 3: Skill Layer Integration
Pass environment through skill chain and resolve to branch

**Tasks**:
- [ ] Update `codex-manager.md` agent to accept and pass environment parameter
- [ ] Update `project-syncer/SKILL.md` to:
  - [ ] Read environment config
  - [ ] Map environment name to target branch
  - [ ] Pass target branch to handler
- [ ] Update workflow files to use environment-specific branch
- [ ] Add environment and branch to operation logging

### Phase 4: Handler Layer Branch Support
Implement branch checkout and error handling

**Tasks**:
- [ ] Update `handler-sync-github/SKILL.md` to accept branch parameter
- [ ] Update sync workflow to checkout target branch after clone
- [ ] Update `sync-files.md` workflow with branch handling
- [ ] Implement branch existence check with helpful error message
- [ ] Include `/fractary-repo:branch-create` command in error output

### Phase 5: FABER Integration
Document environment usage in FABER workflow

**Tasks**:
- [ ] Document that Evaluate phase should sync to test environment
- [ ] Document that Release phase should sync to prod environment (with `--env prod`)
- [ ] Update any FABER workflow configs that invoke codex sync

### Phase 6: Fetch Command Deprecation Assessment
Evaluate fetch vs sync command overlap

**Tasks**:
- [ ] Audit fetch command functionality vs sync command
- [ ] Determine if fetch provides unique value beyond sync
- [ ] If redundant: deprecate fetch commands in favor of sync
- [ ] If unique: document distinction and keep both
- [ ] Update MCP server to always fetch from prod branch

### Phase 7: Documentation and Testing
Update documentation and verify functionality

**Tasks**:
- [ ] Update QUICK-START.md with environment examples
- [ ] Update README.md with "Environment Awareness" section
- [ ] Add migration notes explaining breaking change (default now auto-detects)
- [ ] Test auto-detection from feature branch → test
- [ ] Test auto-detection from main branch → prod (with prompt)
- [ ] Test explicit --env flag skips confirmation
- [ ] Test test==prod config warning
- [ ] Test branch-not-found error message

## Files to Create/Modify

### New Files

- `plugins/codex/skills/project-syncer/scripts/detect-environment.sh`: Helper script to detect current branch and map to environment

### Modified Files

**Commands**:
- `plugins/codex/commands/sync-project.md`: Add --env parsing, auto-detection, confirmation prompts
- `plugins/codex/commands/sync-org.md`: Add --env parsing, auto-detection, confirmation prompts
- `plugins/codex/commands/init.md`: Add default environments config generation

**Agent**:
- `plugins/codex/agents/codex-manager.md`: Accept and pass environment parameter

**Skills**:
- `plugins/codex/skills/project-syncer/SKILL.md`: Map environment to branch via config
- `plugins/codex/skills/project-syncer/workflow/sync-to-codex.md`: Use target branch from environment
- `plugins/codex/skills/project-syncer/workflow/sync-from-codex.md`: Use source branch from environment
- `plugins/codex/skills/handler-sync-github/SKILL.md`: Add branch parameter, implement checkout
- `plugins/codex/skills/handler-sync-github/workflow/sync-files.md`: Checkout target branch after clone

**MCP Server**:
- `plugins/codex/mcp-server/`: Ensure always fetches from prod branch

**Documentation**:
- `plugins/codex/QUICK-START.md`: Add environment examples and auto-detection explanation
- `plugins/codex/README.md`: Add "Environment Awareness" section
- `plugins/codex/docs/MIGRATION-v3.md`: Add breaking change notes

**Potentially Deprecated**:
- `plugins/codex/commands/fetch.md`: Evaluate for deprecation (Phase 6)
- `plugins/codex/skills/document-fetcher/SKILL.md`: Evaluate for deprecation (Phase 6)

## Testing Strategy

### Unit Tests

Test environment auto-detection:
- Feature branch (feat/*, fix/*, etc.) → test environment
- Main/master branch → prod environment
- Explicit --env flag overrides auto-detection
- Invalid environment names error appropriately
- Custom environment names from config work

Test confirmation logic:
- Assumed prod (on main, no --env) → prompts
- Explicit --env prod → no prompt
- Test==prod config → prompts even on feature branch
- User decline → aborts sync

### Integration Tests

Test sync operations:
- Sync from feature branch → commits on test branch in codex
- Sync with `--env prod` → commits on main branch in codex
- Bidirectional sync respects environment (same branch both directions)
- Branch doesn't exist → helpful error with command suggestion

### E2E Tests

Full FABER workflow test:
1. Create feature branch, make documentation changes
2. Run Evaluate phase → auto-syncs to test (no prompt)
3. Verify test branch has documentation
4. Run Release phase with `--env prod` → syncs to prod (no prompt - explicit)
5. Verify main branch has documentation

### Performance Tests

Verify branch checkout is faster than fresh clone:
- Measure time for environment switch via branch checkout
- Compare to baseline clone time

## Dependencies

- `fractary-repo` plugin for git operations (branch detection, branch checkout)
- GitHub API access for branch existence check

## Risks and Mitigations

- **Risk**: Test branch doesn't exist in codex repository
  - **Likelihood**: Medium (first-time setup)
  - **Impact**: Low (clear error message)
  - **Mitigation**: Display helpful error with `/fractary-repo:branch-create` command and config alternative

- **Risk**: Users accidentally sync to production
  - **Likelihood**: Low (requires being on main branch OR explicit flag)
  - **Impact**: Medium (incorrect docs in prod)
  - **Mitigation**: Confirmation prompt when prod is assumed (not explicit)

- **Risk**: Test configured to equal prod without user awareness
  - **Likelihood**: Low (explicit config change)
  - **Impact**: Medium (unexpected prod sync)
  - **Mitigation**: Warning prompt explaining the config situation

- **Risk**: Custom environment names inconsistent across configs
  - **Likelihood**: Medium (user error)
  - **Impact**: Medium (deployment profile mismatches)
  - **Mitigation**: Document importance of consistency; consider validation tooling

## Documentation Updates

- `plugins/codex/QUICK-START.md`: Add environment auto-detection examples
- `plugins/codex/README.md`: Add "Environment Awareness" section with config examples
- `plugins/codex/docs/MIGRATION-v3.md`: Add breaking change notes (old behavior synced to main, new auto-detects)

## Rollout Plan

1. **Phase 1**: Implement and test locally on fractary/claude-plugins
2. **Phase 2**: Create test branch in codex.fractary.com
3. **Phase 3**: Test full workflow (feature branch → test, release → prod)
4. **Phase 4**: Document and update QUICK-START
5. **Phase 5**: Monitor for issues, iterate on prompts if needed

## Success Metrics

- **Safety**: Zero accidental production syncs (all prod syncs are intentional)
- **Usability**: Users don't need to remember --env flag for normal development
- **FABER Integration**: Evaluate and Release phases use correct environments automatically

## Implementation Notes

### Considered Alternatives

**Alternative A: PR-based workflow for production**

The issue mentions considering a PR-based workflow where changes on test branch are merged to main via PR. This was rejected because:
- Adds complexity (multiple projects syncing simultaneously would create branch conflicts)
- Requires coordination between different Claude sessions
- The simpler direct-branch approach achieves the same goal

**Alternative B: Separate codex repositories per environment**

This was rejected because:
- Doubles infrastructure/maintenance
- Harder to track divergence between environments
- Single repo with branches is more maintainable

**Alternative C: Environment-segregated cache**

Initial design had separate cache directories per environment. This was rejected because:
- MCP server should always serve production docs
- Manual sync commands can specify environment for pull operations
- Simpler single cache is sufficient

**Alternative D: Require explicit --env flag (no default)**

This was considered but rejected because:
- Adds friction to normal development workflow
- Auto-detection from branch is intuitive
- Confirmation prompts provide safety net for prod

### Decision: Auto-Detection with Confirmation

The implementation uses branch-based auto-detection:
- Feature/fix branches → `test` environment (no confirmation)
- Main/master branch → `prod` environment (confirmation required unless explicit)
- Explicit `--env` flag → specified environment (no confirmation)

This balances convenience (no flags needed for normal dev) with safety (can't accidentally sync to prod).

### FABER Integration

In FABER workflow:
- **Evaluate phase**: Sync to test environment happens automatically (on feature branch)
- **Release phase**: Sync to prod with explicit `--env prod` flag

This ensures documentation follows the same release cadence as code.

### Sync vs Fetch Command Decision

The original v3.0 design introduced fetch commands for pull-based retrieval. After review:
- Sync commands already support bidirectional operations (push and pull)
- Fetch commands appear redundant
- MCP server handles real-time fetching

**Decision**: Phase 6 will evaluate fetch commands for potential deprecation. Sync commands are the primary interface.

### Source Context

This specification was created from issue #247 discussion and follow-up clarification, which identified:
1. Core problem: environment separation for documentation sync
2. Auto-detection from branch is preferred (suggested by Claude, approved by user)
3. Confirmation prompts for assumed prod (user requirement)
4. Four environments with configurable branches (dev, test, staging, prod)
5. Single cache, MCP always uses prod (user decision)
