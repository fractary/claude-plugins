# ISSUE #259: Reconsider fractary-codex:sync-org

**Issue**: Reconsider fractary-codex:sync-org
**Work ID**: #259
**Author**: Josh McWilliam (@jmcwilliam)
**Status**: Open
**Created**: 2025-12-07

## Summary

Evaluate whether the `sync-org` command in the Codex plugin is aligned with the project's evolving architecture. The current implementation performs organization-wide push operations that may conflict with per-project sync patterns and permissions models.

## Problem Statement

### Current State

The `fractary-codex:sync-org` command enables organization-wide synchronization where:
- One project can trigger documentation syncing across multiple projects
- A central project "pushes" documentation to other projects in the organization
- This requires broad cross-project permissions

### Issues with Current Approach

1. **Architectural Misalignment**: The project is moving toward a pull-based model where:
   - Each project decides which documentation to pull from Codex
   - Each project syncs its own relevant environments (production/test)
   - Projects should NOT have external projects dictating their documentation

2. **Permissions Concerns**:
   - Projects need permission to modify other projects' environments
   - This violates the principle of least privilege
   - Projects should only be able to sync themselves, not trigger syncing in other projects
   - Current permissions may accidentally allow operations that shouldn't be allowed

3. **Workflow Pattern Change**:
   - New default FABER workflows start with per-project Codex sync
   - This replaces the need for organization-wide pushes
   - Each project handles its own documentation needs autonomously

### Proposed Future Pattern

Instead of `sync-org`:
```
Default FABER Workflow → [Frame phase initialization]
  ↓
  Step: Codex sync-project (pull relevant docs from Codex)
  ↓
  Rest of workflow (architect, build, evaluate, release)
```

Each project pulls documentation it needs, eliminating need for external projects to push to it.

## Requirements

### Requirement 1: Validate Permission Model

**User Story**: As an architect, I need to validate whether the current `sync-org` implementation has excessive permissions.

**Acceptance Criteria**:
- [ ] Review the current permission model used by `sync-org`
- [ ] Identify what permissions are required for each operation
- [ ] Determine if projects can inadvertently trigger syncing in other projects
- [ ] Document findings in `docs/analysis/ISSUE-259-permissions-analysis.md`

**Technical Details**:
- Check how `fractary-codex:sync-org` authenticates with other projects
- Review scope of credentials/tokens used
- Identify any cross-project permission boundaries that exist
- Check whether the skill validates ownership before syncing

### Requirement 2: Analyze Workflow Compatibility

**User Story**: As a workflow designer, I need to understand if the pull-based pattern makes `sync-org` obsolete.

**Acceptance Criteria**:
- [ ] Document current `sync-org` use cases in the plugin ecosystem
- [ ] Map those use cases to the new pull-based pattern
- [ ] Identify any legitimate use cases that require `sync-org`
- [ ] Create migration path documentation if needed
- [ ] Document analysis in `docs/analysis/ISSUE-259-workflow-analysis.md`

**Technical Details**:
- Search codex plugin for documentation and examples of `sync-org` usage
- Check if any existing workflows or plugins depend on `sync-org`
- Verify that per-project sync covers all current use cases
- Document any gaps that would need addressing

### Requirement 3: Evaluate Feasibility

**User Story**: As a plugin maintainer, I need to decide whether to deprecate, redesign, or keep `sync-org`.

**Acceptance Criteria**:
- [ ] Based on requirements 1 & 2, determine the best path forward
- [ ] Create decision document with recommendation
- [ ] Document in `docs/decisions/ISSUE-259-sync-org-decision.md`
- [ ] If deprecating: Create deprecation plan with timeline
- [ ] If keeping: Propose security and architectural improvements

**Decision Options**:

1. **Deprecate `sync-org`**
   - Remove from default documentation
   - Mark as deprecated in CHANGELOG
   - Plan removal in v4.0
   - Document migration to per-project sync
   - Recommendation: Likely the right path based on issue description

2. **Redesign with stronger boundaries**
   - Require explicit project consent for syncing
   - Limit permissions to sync own environment only
   - Add org-wide sync event logging/approval
   - Improve access control

3. **Keep as-is**
   - Only valid if Requirement 1 confirms no permission issues
   - Only valid if Requirement 2 finds legitimate cross-org use cases
   - Document recommended usage patterns

## Architecture Context

### Codex Plugin Structure

The Codex plugin provides:
- `sync-project` - Per-project synchronization (pull-based, PREFERRED)
- `sync-org` - Organization-wide synchronization (push-based, UNDER REVIEW)
- Memory management and document retrieval operations

### Related Files

- **Plugin**: `plugins/codex/` (core Codex plugin)
- **Skill**: `plugins/codex/skills/` (check for sync-org implementation)
- **Configuration**: `.fractary/plugins/codex/config.json`
- **Default workflow**: `plugins/faber/config/workflows/default.json`

### Design Principles at Stake

1. **Least Privilege**: Projects should only have permissions they need
2. **Project Autonomy**: Projects decide what documentation they sync
3. **Pull Over Push**: Consumers pull data they need, not providers push
4. **Self-Contained Operations**: Each project syncs itself, doesn't affect others

## Implementation Notes

- Keep design decision-focused, not implementation-focused
- Analysis should inform whether to remove, redesign, or improve the feature
- Document the permission and workflow concerns thoroughly
- Recommend clear decision path for plugin maintainers

## Success Criteria

The issue is resolved when:
1. Permission model is thoroughly analyzed and documented
2. Workflow compatibility is assessed across the ecosystem
3. A clear recommendation is documented with decision rationale
4. If deprecated: deprecation plan is created and socialized
5. If redesigned: security improvements are specified
