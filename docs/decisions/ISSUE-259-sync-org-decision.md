# Architecture Decision: Deprecate fractary-codex:sync-org

**Issue**: #259 - Reconsider fractary-codex:sync-org
**Date**: 2025-12-07
**Status**: APPROVED FOR IMPLEMENTATION
**Author**: FABER Workflow Analysis
**References**:
- `docs/analysis/ISSUE-259-permissions-analysis.md`
- `docs/analysis/ISSUE-259-workflow-analysis.md`

## Decision

**DEPRECATE** the `fractary-codex:sync-org` command in favor of per-project `sync-project` operations.

## Context

The `fractary-codex:sync-org` command enables organization-wide synchronization where one project can trigger documentation syncing across the entire organization. Recent architectural evolution and security analysis have raised concerns about this model.

## Problem Statement

### 1. Permission Boundary Violations

The current `sync-org` implementation does not adequately enforce permission boundaries:

- **Cross-project writes without consent**: Projects can be modified by org-wide sync operations without any consent mechanism
- **Credential scope mismatch**: Uses GitHub organization-level credentials with no restriction to projects that should participate
- **No opt-in mechanism**: Target projects cannot choose to participate or opt-out of org-wide sync
- **Unvalidated codex authority**: No verification that the calling project has authority to define the central codex repository

**Impact**: A compromised or rogue project could trigger unwanted documentation changes across the organization.

### 2. Architectural Misalignment

The Codex v3 architecture is evolving toward **pull-based, per-project control**:

```
OLD PATTERN (push-based):
  Central codex pushes docs → Project A
  Central codex pushes docs → Project B
  Central codex pushes docs → Project C
  (Projects receive updates whether they want them or not)

NEW PATTERN (pull-based):
  Project A pulls docs it needs
  Project B pulls docs it needs
  Project C pulls docs it needs
  (Each project controls what it receives and when)
```

The `sync-org` command embodies the old push-based pattern, which conflicts with the emerging architecture.

### 3. Unnecessary Operational Complexity

- Adds another layer of synchronization that users must understand and manage
- Creates audit trail complexity (who triggered the org-wide sync?)
- Requires organization-level coordination for a problem that projects can solve individually
- Increases the attack surface (more ways to accidentally modify all projects)

## Solution

Deprecate `sync-org` in favor of per-project `sync-project` operations, enabling each project to:
1. **Pull documentation** it needs from the central codex at the start of workflows
2. **Push documentation** it wants to contribute when ready
3. **Control its environment** (test vs. prod) independently
4. **Participate explicitly** in documentation synchronization

## How the New Pattern Works

### Per-Project Sync in FABER Workflow

```json
{
  "extends": "fractary-faber:default",
  "phases": {
    "frame": {
      "pre_steps": [
        {
          "id": "sync-codex",
          "name": "Sync documentation from codex",
          "skill": "fractary-codex:sync-project",
          "config": {
            "direction": "from-codex",
            "environment": "auto-detect"
          }
        }
      ]
    }
  }
}
```

This ensures every FABER workflow starts with relevant documentation already available.

### Organization-Wide Sync via CI/CD

When all projects need to sync (e.g., after infrastructure updates), organizations can implement CI/CD orchestration:

```bash
# CI/CD pipeline that runs in central orchestration project
for project in $(gh repo list "$ORG" --json name -q '.[].name'); do
  gh workflow run sync-codex.yml --repo "$project"
  # Each project runs its own sync-project workflow
done
```

**Key difference**: Each project explicitly syncs itself, rather than being synced by external command.

## Benefits

### Security
- ✓ Projects can only modify themselves
- ✓ No cross-project permission boundaries violated
- ✓ Credential scope matches actual needs
- ✓ Each project opts-in explicitly

### Architecture
- ✓ Aligns with v3 pull-based model
- ✓ Single pattern for documentation sync (per-project)
- ✓ Reduces command surface area
- ✓ Makes documentation synchronization predictable

### Operations
- ✓ Each project controls when it syncs
- ✓ No surprises from organization-wide operations
- ✓ Simpler permission model
- ✓ Clearer audit trail (which project synced, which docs changed)

### User Experience
- ✓ More intuitive (project controls its own docs)
- ✓ Fewer commands to learn
- ✓ Better documentation (sync happens in workflows, visible in config)
- ✓ Decentralized decision-making (no org-wide coordination needed)

## Impact Analysis

### Affected Components

| Component | Impact | Mitigation |
|-----------|--------|-----------|
| `sync-org` command | Deprecated | Remove in v4.0 |
| `org-syncer` skill | Deprecated | Remove in v4.0 |
| `sync-project` command | Enhanced | Continues to be used (improved) |
| `project-syncer` skill | No change | Continues to be used (no changes needed) |
| `repo-discoverer` | Keep | Useful for other operations (e.g., analytics) |
| Default FABER workflows | No change | Don't currently use sync-org |
| Core ecosystem | No change | No plugins depend on sync-org |
| User projects using sync-org | Breaking | Migration guide provided |

### Risk Assessment

| Risk | Probability | Severity | Mitigation |
|------|-------------|----------|-----------|
| Organizations using sync-org break | HIGH | MEDIUM | Migration guide, deprecation warnings, long transition window |
| Users misunderstand per-project pattern | MEDIUM | LOW | Documentation, examples, template workflows |
| Reduced convenience for some scenarios | LOW | LOW | Alternative: custom orchestration scripts |
| Core plugins break | VERY LOW | CRITICAL | None needed (no core dependencies) |

## Implementation Plan

### Phase 1: Preparation (v3.2, Week 1-2)

1. Add deprecation notice to `sync-org` command documentation
2. Create migration guide showing how to use `sync-project` instead
3. Update Codex QUICK-START to recommend per-project sync
4. Create example workflow configurations for different scenarios
5. Announce deprecation in CHANGELOG

### Phase 2: Warnings (v3.3, Week 3-8)

1. Display deprecation warning when `sync-org` is executed
2. Suggest using `sync-project` instead in the warning
3. Link to migration guide
4. Continue to function normally
5. Track usage metrics (if possible) to understand adoption

### Phase 3: Removal (v4.0, Week 9+)

1. Remove `sync-org` command
2. Remove `org-syncer` skill and related workflows
3. Update documentation to remove all references
4. Update CHANGELOG with removal notice
5. Consider `repo-discoverer` as internal-only skill (document limitations)

### Transition Window

- **Deprecation announced**: v3.2 (immediate)
- **Final warning version**: v3.3
- **Removal**: v4.0 (approximately 6 months later)

This gives organizations at least 4 months to migrate after deprecation announcement.

## Migration Guide for Users

### For Organizations Using sync-org in Workflows

**Step 1**: Update each project's FABER workflow config

```json
{
  "extends": "fractary-faber:default",
  "phases": {
    "frame": {
      "pre_steps": [
        {
          "id": "codex-sync-project",
          "name": "Sync documentation from codex",
          "skill": "fractary-codex:sync-project",
          "config": {
            "direction": "from-codex",
            "auto_detect_environment": true
          }
        }
      ]
    }
  }
}
```

**Step 2**: Remove any manual `sync-org` calls from CI/CD

Replace:
```bash
/fractary-codex:sync-org --env test
```

With per-project approach:
```bash
# Each project runs in its own workflow
/fractary-codex:sync-project --env test --from-codex
```

### For CI/CD Pipelines Orchestrating Multiple Projects

If you need organization-wide sync in CI/CD, create a custom orchestration script:

```bash
#!/bin/bash
# orchestrate-codex-sync.sh
# Run in a central CI/CD job to sync all projects

ORG="${1:?Organization required}"
ENV="${2:-test}"

echo "Syncing all projects in $ORG to $ENV..."

# Discover all projects
for repo in $(gh repo list "$ORG" --json name -q '.[].name'); do
  echo "→ Syncing $repo..."

  # Trigger sync in each project's workflow
  gh workflow run codex-sync.yml \
    --repo "$ORG/$repo" \
    -f environment="$ENV" \
    || echo "  (skipped - no codex-sync workflow)"
done

echo "Done!"
```

Then in each project's CI/CD, add a workflow:

```yaml
# .github/workflows/codex-sync.yml
name: Sync Codex

on:
  workflow_dispatch:
    inputs:
      environment:
        description: Environment to sync
        required: true
        default: test

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Sync with codex
        run: |
          /fractary-codex:sync-project \
            --env "${{ github.event.inputs.environment }}" \
            --from-codex
```

## Alternatives Considered

### Alternative A: Keep sync-org With Stronger Permissions

**Rejected because**:
- Adds complexity to implement proper permission boundaries
- Still doesn't align with the new pull-based architecture
- Operational safety gain is not worth the maintenance burden
- Per-project approach is inherently safer

### Alternative B: Redesign sync-org to Support Pull-Based Consumption

**Rejected because**:
- Would require significant redesign of the command
- Creates two nearly-identical commands (`sync-org` and `sync-project`)
- Doesn't address the architectural misalignment
- Simpler to just use `sync-project` consistently

### Alternative C: Keep sync-org as-is

**Rejected because**:
- Permission boundary violations are unacceptable
- Architectural misalignment with v3
- No clear use cases that `sync-project` doesn't handle better
- Operational risk not justified by convenience benefit

## Success Criteria

Deprecation is successful when:

1. ✓ Deprecation notice is prominently displayed
2. ✓ Migration guide is available and clear
3. ✓ At least one example FABER workflow configuration uses per-project sync
4. ✓ No internal plugins depend on `sync-org`
5. ✓ Organizations understand the new pattern
6. ✓ Transition window of 4+ months is provided before removal

## Next Steps

1. **Immediately** (v3.2):
   - Review and approve this decision
   - Add deprecation notices to `sync-org` documentation
   - Create migration guide
   - Announce in release notes

2. **Short-term** (v3.3):
   - Display warnings when `sync-org` is used
   - Monitor usage to understand adoption
   - Gather feedback from organizations using `sync-org`

3. **Long-term** (v4.0):
   - Remove `sync-org` command
   - Remove `org-syncer` skill
   - Clean up related documentation

## References

- **Permissions Analysis**: `docs/analysis/ISSUE-259-permissions-analysis.md`
- **Workflow Analysis**: `docs/analysis/ISSUE-259-workflow-analysis.md`
- **Issue**: GitHub issue #259
- **Architecture**: FABER v2.1+ (pull-based pattern)

## Approval

This decision has been analyzed through the FABER workflow system and is recommended for approval by the architecture team.

**Analysis Status**: ✓ COMPLETE
**Decision**: ✓ DEPRECATE sync-org
**Implementation**: → Ready for v3.2 deprecation phase
