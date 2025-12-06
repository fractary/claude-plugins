---
spec_id: WORK-00247-codex-sync-environment-aware
work_id: 247
issue_url: https://github.com/fractary/claude-plugins/issues/247
title: Make codex-sync environment aware
type: feature
status: draft
created: 2025-12-06
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: Make codex-sync environment aware

**Issue**: [#247](https://github.com/fractary/claude-plugins/issues/247)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-06

## Summary

Add environment awareness to the codex sync system, enabling documentation to be synced to either a `test` or `production` (main) branch in the codex repository. This allows downstream systems working in test environments to receive documentation for unreleased features, while production environments only see documentation for released features.

## Problem Statement

Currently, codex sync operations work against a single branch (typically `main`) in the codex repository. This creates a timing issue:

1. Documentation for features in test/staging environments needs to be available to downstream test systems
2. Production documentation should only contain released features
3. There's no mechanism to separate test vs production documentation in codex

## User Stories

### Story 1: Developer syncing test documentation
**As a** developer working on a feature in test
**I want** to sync documentation to the codex test branch
**So that** downstream test systems can access my feature documentation

**Acceptance Criteria**:
- [ ] Can specify `--env test` or no env flag (test is default)
- [ ] Documentation syncs to `test` branch in codex repository
- [ ] Test branch receives documentation before PR merge

### Story 2: Release manager promoting to production
**As a** release manager
**I want** to sync documentation to the codex production branch
**So that** only released features are visible in production documentation

**Acceptance Criteria**:
- [ ] Can specify `--env prod` or `--env production`
- [ ] Documentation syncs to `main` branch in codex repository
- [ ] Production sync only happens after feature release

### Story 3: Downstream system consuming environment-specific docs
**As a** downstream system
**I want** to fetch documentation from the appropriate environment branch
**So that** my test instance uses test docs and my prod instance uses prod docs

**Acceptance Criteria**:
- [ ] Fetch command supports `--env` flag
- [ ] Cache maintains separate entries per environment
- [ ] Environment is included in cache key

## Functional Requirements

- **FR1**: Add `--env <test|prod|production>` argument to sync commands (`sync-project`, `sync-org`)
- **FR2**: Default environment to `test` when not specified (fail-safe: test documentation is less critical than production)
- **FR3**: Map environment to codex repository branch (`test` → `test` branch, `prod/production` → `main` branch)
- **FR4**: Add `--env` argument to fetch command for cache retrieval
- **FR5**: Include environment in cache key to maintain separate caches per environment
- **FR6**: Support environment configuration in `.fractary/plugins/codex/config.json`

## Non-Functional Requirements

- **NFR1**: Environment switching must not require re-cloning entire repository (use branch checkout) (performance)
- **NFR2**: Environment flag must be validated before any sync operations begin (validation)
- **NFR3**: Clear error messages when attempting invalid environment operations (usability)

## Technical Design

### Architecture Changes

The environment awareness will be implemented at three layers:

1. **Command Layer**: Parse `--env` argument, validate, pass to agent
2. **Skill Layer**: Use environment to determine target branch in codex repo
3. **Handler Layer**: Clone/checkout appropriate branch based on environment

```
┌─────────────────────────────────────────────────────────────┐
│ Command: sync-project --env test                            │
│   ↓ parses --env, defaults to "test"                        │
├─────────────────────────────────────────────────────────────┤
│ Agent: codex-manager                                        │
│   ↓ passes environment in operation parameters              │
├─────────────────────────────────────────────────────────────┤
│ Skill: project-syncer                                       │
│   ↓ maps environment to branch: test→test, prod→main        │
├─────────────────────────────────────────────────────────────┤
│ Handler: handler-sync-github                                │
│   ↓ clones codex repo, checks out target branch             │
│   ↓ performs file sync                                      │
└─────────────────────────────────────────────────────────────┘
```

### Data Model

**Configuration Schema Extension** (`.fractary/plugins/codex/config.json`):

```json
{
  "environments": {
    "default": "test",
    "branches": {
      "test": "test",
      "prod": "main",
      "production": "main"
    }
  }
}
```

**Cache Key Format Change**:
- Current: `<org>/<project>/<path>`
- New: `<org>/<project>/<env>/<path>` (e.g., `fractary/claude-plugins/test/docs/README.md`)

### API Design

**Command Arguments**:
- `--env <environment>`: Specify target environment (test, prod, production)
- Default: `test`
- Alias: `--environment`

**Examples**:
```bash
# Sync to test environment (default)
/fractary-codex:sync-project
/fractary-codex:sync-project --env test

# Sync to production environment
/fractary-codex:sync-project --env prod
/fractary-codex:sync-project --env production

# Fetch from specific environment
/fractary-codex:fetch @codex/project/docs/README.md --env prod
```

### UI/UX Changes

Output messages should clearly indicate the target environment:

```
🎯 STARTING: Project Sync
Project: claude-plugins
Codex: codex.fractary.com
Environment: test (branch: test)
Direction: bidirectional
───────────────────────────────────────
```

## Implementation Plan

### Phase 1: Configuration and Command Layer
Add environment support to configuration and commands

**Tasks**:
- [ ] Update config schema to include `environments` section
- [ ] Update `sync-project.md` command to parse `--env` argument
- [ ] Update `sync-org.md` command to parse `--env` argument
- [ ] Add environment validation (test/prod/production only)
- [ ] Default to `test` when no environment specified

### Phase 2: Skill Layer Integration
Pass environment through skill chain

**Tasks**:
- [ ] Update `codex-manager.md` agent to accept and pass environment parameter
- [ ] Update `project-syncer/SKILL.md` to map environment to branch
- [ ] Update workflow files to use environment-specific branch
- [ ] Add environment to operation logging

### Phase 3: Handler Layer Branch Support
Implement branch checkout in sync handler

**Tasks**:
- [ ] Update `handler-sync-github/SKILL.md` to accept branch parameter
- [ ] Update sync workflow to checkout target branch after clone
- [ ] Update `sync-files.md` workflow with branch handling
- [ ] Handle branch creation if test branch doesn't exist

### Phase 4: Fetch Command and Cache
Add environment support to fetch operations

**Tasks**:
- [ ] Update `fetch.md` command to accept `--env` argument
- [ ] Update `document-fetcher/SKILL.md` to use environment-aware cache keys
- [ ] Update cache structure to segregate by environment
- [ ] Update `cache-list.md` to show environment column

### Phase 5: Documentation and Testing
Update documentation and verify functionality

**Tasks**:
- [ ] Update QUICK-START.md with environment examples
- [ ] Update README.md with environment section
- [ ] Add migration notes for existing users
- [ ] Test sync-project with both environments
- [ ] Test fetch with both environments
- [ ] Test cache segregation

## Files to Create/Modify

### New Files

None required - all changes are modifications to existing files.

### Modified Files

- `plugins/codex/commands/sync-project.md`: Add --env argument parsing
- `plugins/codex/commands/sync-org.md`: Add --env argument parsing
- `plugins/codex/commands/fetch.md`: Add --env argument parsing
- `plugins/codex/agents/codex-manager.md`: Pass environment in operations
- `plugins/codex/skills/project-syncer/SKILL.md`: Map environment to branch
- `plugins/codex/skills/project-syncer/workflow/sync-to-codex.md`: Use target branch
- `plugins/codex/skills/project-syncer/workflow/sync-from-codex.md`: Use source branch
- `plugins/codex/skills/handler-sync-github/SKILL.md`: Add branch parameter support
- `plugins/codex/skills/handler-sync-github/workflow/sync-files.md`: Checkout target branch
- `plugins/codex/skills/document-fetcher/SKILL.md`: Environment-aware cache keys
- `plugins/codex/QUICK-START.md`: Document environment usage
- `plugins/codex/README.md`: Add environment section

## Testing Strategy

### Unit Tests

Test environment argument parsing:
- Valid values: test, prod, production
- Invalid values should error: staging, dev, etc.
- Default behavior when no --env provided

### Integration Tests

Test sync operations:
- Sync to test environment creates commits on test branch
- Sync to prod environment creates commits on main branch
- Bidirectional sync respects environment

### E2E Tests

Full workflow test:
1. Create feature documentation
2. Sync to test environment
3. Verify test branch has documentation
4. "Release" feature
5. Sync to prod environment
6. Verify main branch has documentation

### Performance Tests

Verify branch checkout is faster than fresh clone:
- Measure time for environment switch via branch checkout
- Compare to baseline clone time

## Dependencies

- `fractary-repo` plugin for git operations (branch checkout)
- GitHub API access for branch creation (if test branch doesn't exist)

## Risks and Mitigations

- **Risk**: Test branch doesn't exist in codex repository
  - **Likelihood**: Medium (first-time setup)
  - **Impact**: Low (can be created)
  - **Mitigation**: Auto-create test branch from main if it doesn't exist

- **Risk**: Users accidentally sync test docs to production
  - **Likelihood**: Low (production requires explicit flag)
  - **Impact**: Medium (incorrect docs in prod)
  - **Mitigation**: Default to test; require explicit --env prod

- **Risk**: Cache collision between environments
  - **Likelihood**: Low (design prevents this)
  - **Impact**: High (wrong docs served)
  - **Mitigation**: Include environment in cache key

## Documentation Updates

- `plugins/codex/QUICK-START.md`: Add environment usage examples
- `plugins/codex/README.md`: Add "Environment Awareness" section
- `plugins/codex/docs/MIGRATION-v3.md`: Add notes about environment feature

## Rollout Plan

1. **Phase 1**: Implement and test locally
2. **Phase 2**: Deploy to fractary org test repositories
3. **Phase 3**: Document and announce to team
4. **Phase 4**: Monitor for issues during first week
5. **Phase 5**: General availability

## Success Metrics

- **Adoption**: % of sync operations using explicit --env flag
- **Accuracy**: Zero incidents of wrong environment documentation served
- **Performance**: Environment switch < 5 seconds (vs clone baseline)

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

### Decision: Direct Branch Approach

The implementation uses direct branch operations:
- `test` environment → `test` branch
- `prod` environment → `main` branch

This is simpler, doesn't require conflict resolution, and lets multiple projects sync simultaneously without coordination.

### Default Environment Rationale

`test` is chosen as the default because:
1. Fail-safe: test documentation being wrong is less impactful than production
2. Common case: most development work targets test first
3. Explicit action: requiring `--env prod` prevents accidental production sync

### Source Context

This specification was created from issue #247 discussion, which identified the core problem of needing environment separation for documentation sync operations. The solution focuses on simplicity (branch-based separation) over complexity (PR-based merging).
