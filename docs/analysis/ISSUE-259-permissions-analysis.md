# Permissions Analysis: fractary-codex:sync-org

**Issue**: #259 - Reconsider fractary-codex:sync-org
**Date**: 2025-12-07
**Author**: FABER Workflow #259
**Status**: Draft Analysis

## Executive Summary

The `fractary-codex:sync-org` command enables organization-wide synchronization but does not adequately enforce permission boundaries. **Major concern**: Projects executing `sync-org` can inadvertently trigger documentation synchronization across the entire organization, potentially violating the principle of least privilege.

**Finding**: The current permission model relies on git credentials (GitHub organization access) but does not validate project ownership or implement cross-project consent mechanisms.

## Current Permission Model

### How sync-org Works

```
Command: /fractary-codex:sync-org [--env <env>] [--to-codex|--from-codex]
  ↓
Command Router (sync-org.md):
  - Parses arguments
  - Loads config from .fractary/plugins/codex/config.json
  - Invokes codex-manager agent
  ↓
codex-manager Agent:
  - Validates environment
  - Requests sync-org operation with parameters
  ↓
org-syncer Skill:
  - Invokes repo-discoverer (finds ALL org repositories)
  - Invokes project-syncer in parallel for each project
  ↓
For each project (project-syncer Skill):
  - Clones or fetches repository
  - Uses configured credentials (from repo plugin)
  - Syncs documentation based on patterns
  - Commits changes back to project repo
```

### Permission Enforcement Points

| Point | Current Behavior | Concern |
|-------|------------------|---------|
| **Credential Scope** | Uses GitHub organization token/credentials from repo plugin config | Token likely has full org access (read + write on all repos) |
| **Repository Discovery** | Lists ALL repositories in organization | No filtering based on which projects should allow sync-org |
| **Project Modification** | Creates commits in each discovered project | No consent or approval from target project owners |
| **Codex Repository Access** | Reads/writes to codex repo (single source of truth) | Assumes calling project has permission to modify codex (may not validate ownership) |
| **Configuration Authority** | Uses `.fractary/plugins/codex/config.json` from calling project | Config specifies `organization` and `codex_repo`, but not which projects can be synced |
| **Environment Targeting** | Syncs to specified environment (default: test, or --env prod) | All projects hit the same branch regardless of their own environment strategy |

## Permission Boundary Violations

### Issue 1: Cross-Project Writes Without Consent

**Problem**: When `sync-org` executes, it modifies repositories that may not have agreed to participate.

**Scenario**:
```
Project A (CI/CD pipeline) runs:
  /fractary-codex:sync-org --env test

This triggers modifications in:
  - Project B (unaware of sync)
  - Project C (unaware of sync)
  - Project D (unaware of sync)
  - ... all other org projects

Each project gets new commits with synchronized documentation,
without any consent mechanism.
```

**Risk**:
- Projects may have their own documentation policies
- Some projects may not want external documentation pushed into them
- CI/CD breaks if unexpected commits appear in projects
- Audit trails don't clearly show which project initiated the org-wide sync

### Issue 2: Credential Scope Mismatch

**Problem**: The solution uses GitHub org-level credentials that may have excessive scope.

**Current Flow**:
```
repo plugin config (.fractary/plugins/repo/config.json):
  - GitHub token with full organization access
  - Used for: normal repo operations (git clone, push)

sync-org Flow:
  - Uses the SAME credentials
  - These credentials can write to ANY repo in the org
  - No validation that calling project "owns" permission to modify other projects
```

**Risk**:
- A compromised project's credentials could modify any other project
- No way to limit scope to specific projects (e.g., only sync if both projects opt-in)
- Token has permission to do more than sync-org should allow

### Issue 3: Unvalidated Codex Repository Authority

**Problem**: The command doesn't verify that the calling project has authority over the codex repository.

**Current Assumption**:
```
config.json specifies: "codex_repo": "central-docs"

sync-org assumes:
  - Calling project has permission to read/write this repo
  - No validation that codex_repo is the "official" one
  - No check that calling project is authorized as a sync source
```

**Risk**:
- Projects could specify a malicious codex repository
- Could cause documentation from unauthorized sources to be pushed to all org projects
- No audit trail of which project initiated the sync

### Issue 4: No Per-Project Opt-In Mechanism

**Problem**: Target projects have no way to consent or opt-out of org-wide sync.

**Current Model**:
```
sync-org finds all projects via: repo-discoverer

repo-discoverer logic:
  - List all repos in org matching pattern
  - Filter by exclude patterns from config
  - Return all matching repos

Target projects CANNOT:
  - Opt-out of being synced
  - Require approval before receiving synced docs
  - Choose which docs to accept from codex
  - Specify their own sync patterns
```

**Contrast**: `sync-project` (per-project) **does allow**:
- Current project decides its own sync patterns
- Current project can choose environment
- Current project can exclude certain docs
- Per-project configuration in `.fractary/plugins/codex/config.json`

## Architectural Misalignment

### The Fundamental Shift

The Codex v3 architecture is moving toward **pull-based, per-project control**:

```
OLD (v2 - Push-based, what sync-org implements):
  Codex (central)
    ↓ (pushes to all projects)
  Project A ← Project B ← Project C ← ... (projects receive unwanted docs)

NEW (v3 - Pull-based, per-project):
  Project A pulls what it needs
  Project B pulls what it needs
  Project C pulls what it needs
    ↓ (each contributes independently)
  Codex (central, aggregated)
```

**sync-org's push-based model is architecturally misaligned with this shift**.

### Why Pull-Based Is Better

1. **Project Autonomy**: Each project decides what documentation it needs
2. **No Surprise Updates**: Projects pull only when they're ready
3. **Clear Boundaries**: Projects only sync with themselves and codex
4. **Explicit Opt-In**: Pulling is deliberate; pushing is coercive
5. **Self-Service**: Projects don't depend on someone else running sync-org

## Recommended Changes (If Keeping sync-org)

If `sync-org` must be retained, implement these safeguards:

### Option A: Strong Permission Model

```json
{
  "codex": {
    "organization": "fractary",
    "codex_repo": "fractary/codex",
    "sync_auth": {
      "approval_required": true,
      "approved_callers": ["ci-cd-project", "docs-admin"],
      "approval_method": "github-issue-comment",
      "notification_slack_channel": "#codex-syncs"
    },
    "target_projects": {
      "opt_in_required": true,
      "whitelist": ["project-a", "project-b"],
      "require_consent_file": ".codex-sync-consent"
    }
  }
}
```

### Option B: Minimum Permission Credentials

- Use personal access tokens with **specific repository scope** (not org-wide)
- For org-wide sync, require separate elevated credentials
- Log all credentials used and which projects they affect
- Rotate credentials regularly
- Alert on cross-project writes

### Option C: Audit and Transparency

- Log **who triggered** sync-org (GitHub user, CI job, etc.)
- Log **which projects** were modified and what changed
- Create GitHub issues in affected projects listing changes
- Implement rollback mechanism if unintended changes occur

## Workflow Compatibility Analysis

### Current Usage of sync-org in Codex Plugin Ecosystem

Searching through the plugin documentation, the primary use case for `sync-org` is:

**Documented Use Cases**:
1. Organization-wide documentation synchronization
2. Syncing multiple projects to central codex at once
3. Batch operations for infrastructure/config docs

**Ecosystem Integration**:
- No evidence that default FABER workflows use `sync-org`
- New pattern is `sync-project` at start of workflows
- Some organizations may use `sync-org` in CI/CD pipelines manually

### Pull-Based Replacement (New Pattern)

The recommended replacement is per-project sync:

```
FABER Default Workflow:
  Frame Phase:
    - Initialize working environment
    - Fetch issue and context

  → NEW: At start of Architect/Build:
    /fractary-codex:sync-project --env {current_env}
    (pulls relevant docs for THIS project's context)

  Architect Phase:
    - Use synced docs
    - Generate specification

  Build Phase:
    - Implement solution
    - Sync any new docs TO codex (optional)
```

**Each project can embed this pattern** without needing org-wide coordination:
```markdown
<!-- In faber default workflow config -->
"phases": {
  "frame": {
    "pre_steps": [
      {
        "name": "sync-codex",
        "description": "Pull relevant documentation from central codex",
        "skill": "fractary-codex:sync-project",
        "parameters": {
          "direction": "from-codex",
          "auto_detect_env": true
        }
      }
    ]
  }
}
```

### Gap Analysis: What sync-org Provides That sync-project Doesn't

| Need | sync-project Can Handle? | Notes |
|------|--------------------------|-------|
| Pull docs into a single project | YES | Exactly what it's designed for |
| Run sync in multiple projects | YES | Each project runs independently |
| Coordinate documentation updates | YES* | Can be scripted in CI/CD for each project |
| Force consistency across org | NO | But consistency comes from shared docs in codex, not from pushing |
| One-command org-wide sync | NO | Trade-off: you lose safety for convenience |
| Bulk updates to projects | NO | Recommend project-level config changes instead |

**Conclusion**: `sync-org` is a **convenience command**, not a **necessity**. All legitimate use cases can be handled by:
1. Having each project run `sync-project` independently
2. Orchestrating multiple `sync-project` calls in CI/CD
3. Configuration in each project's Codex settings

## Recommendation

### Decision: DEPRECATE sync-org

**Rationale**:
1. ✓ Permissions model has fundamental boundary issues
2. ✓ Architecture is misaligned with v3 pull-based model
3. ✓ All use cases can be covered by per-project `sync-project`
4. ✓ Removes operational risk of unexpected cross-project modifications
5. ✓ Simplifies the permission model significantly

**Benefits of Deprecation**:
- Eliminates cross-project permission boundary
- Aligns with emerging architecture pattern
- Reduces operational complexity
- Makes documentation sync more predictable
- Each project controls its own sync strategy

## Deprecation Plan (Proposed)

### Phase 1: Documentation (Immediate - v3.2)
- Add deprecation notice to sync-org command
- Update documentation to recommend sync-project
- Create migration guide showing how to replace sync-org with sync-project

### Phase 2: Warnings (v3.3 - Q1 2026)
- Display deprecation warning when sync-org is executed
- Suggest using `sync-project` instead
- Continue to function normally

### Phase 3: Removal (v4.0 - Q3 2026)
- Remove sync-org command and related skills
- Keep org-syncer skill for internal use if needed (marked as internal)
- Update CHANGELOG with removal notice

### Migration Guide for Users

```bash
# OLD: Run organization-wide sync
/fractary-codex:sync-org --env test

# NEW: Run per-project sync in each project
for project in $(gh repo list --json name -q '.[].name'); do
  cd $project
  /fractary-codex:sync-project --env test
  cd ..
done

# Or better: Add to each project's FABER workflow:
# "frame": { "pre_steps": [{"skill": "fractary-codex:sync-project"}] }
```

## Files Affected by Deprecation

If `sync-org` is deprecated:

1. **To Remove/Deprecate**:
   - `plugins/codex/commands/sync-org.md` - Main command
   - `plugins/codex/skills/org-syncer/SKILL.md` - Orchestration skill
   - Associated workflow files in `org-syncer/workflow/`

2. **To Keep (Internal Only)**:
   - `plugins/codex/skills/repo-discoverer/` - Useful for other operations

3. **To Update**:
   - `plugins/codex/README.md` - Remove sync-org references
   - `plugins/codex/QUICK-START.md` - Update examples
   - Migration guide documentation

## Conclusion

The `fractary-codex:sync-org` command has **architectural and permission model issues** that make deprecation the recommended path forward. The emerging pull-based, per-project synchronization pattern is safer, more flexible, and aligns with the project's architecture evolution.

Deprecating `sync-org` in favor of per-project `sync-project` patterns removes a significant permission boundary violation while simplifying the overall system.
