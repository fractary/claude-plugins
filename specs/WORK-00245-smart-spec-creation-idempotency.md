---
spec_id: WORK-00245-smart-spec-creation-idempotency
work_id: 245
issue_url: https://github.com/fractary/claude-plugins/issues/245
title: Smart Spec Creation - Idempotency and Duplicate Prevention
type: feature
status: draft
created: 2025-12-05
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: Smart Spec Creation - Idempotency and Duplicate Prevention

**Issue**: [#245](https://github.com/fractary/claude-plugins/issues/245)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-05

## Summary

Enhance the `fractary-spec:create` command to intelligently detect existing specifications before creating new ones. When a spec already exists for an issue, the system should read and understand the existing spec rather than creating a duplicate. This enables spec creation to be safely embedded in workflows without worrying about duplicate management.

## User Stories

### Idempotent Spec Creation in Workflows
**As a** workflow author
**I want** spec creation to be idempotent
**So that** I can embed spec creation in standard workflows without creating duplicate specs when re-running

**Acceptance Criteria**:
- [ ] Running `/fractary-spec:create --work-id 245` twice does not create duplicate specs
- [ ] System detects existing spec and reports "Spec already exists" with path
- [ ] Existing spec is read and understood for context

### Force Creation for Evolved Requirements
**As a** developer working on evolving requirements
**I want** to force creation of a new spec when requirements have significantly changed
**So that** I can maintain separate specs for different phases of work

**Acceptance Criteria**:
- [ ] `--force` flag creates new spec even if one exists
- [ ] New spec uses same `WORK-XXXXX-` prefix but different slug
- [ ] Both specs remain accessible and valid

### Multi-Spec Awareness
**As a** developer
**I want** the system to find and read ALL existing specs for an issue
**So that** I understand the full context of requirements that have evolved over time

**Acceptance Criteria**:
- [ ] All specs matching `WORK-{issue_id}-*.md` pattern are discovered
- [ ] All discovered specs are read and incorporated into context
- [ ] System reports which specs were found

## Functional Requirements

- **FR1**: Before creating a new spec, check if any specs exist for the given `work_id`
- **FR2**: Search for existing specs using pattern: `WORK-{work_id:05d}-*.md` in `/specs/` directory
- **FR3**: Additionally check issue comments for spec references (links to `/specs/` files)
- **FR4**: If spec(s) found and `--force` not provided, skip creation and read existing spec(s)
- **FR5**: If `--force` flag provided, create new spec with unique slug regardless of existing specs
- **FR6**: When creating secondary spec, generate unique slug to avoid filename collision
- **FR7**: Report all found specs to user with their paths
- **FR8**: If session recently fetched issue (via issue-fetch), avoid redundant fetch

## Non-Functional Requirements

- **NFR1**: Spec detection should add minimal latency (<100ms) to creation flow (performance)
- **NFR2**: Pattern matching must handle edge cases (zero-padded IDs, multiple specs) (reliability)
- **NFR3**: Graceful handling when `/specs/` directory doesn't exist (robustness)

## Technical Design

### Architecture Changes

The spec-generator skill needs modification to add an existence check before generation:

```
Current Flow:
  1. Parse inputs
  2. Auto-detect work_id from branch
  3. Fetch issue data
  4. Generate spec
  5. Save and link

New Flow:
  1. Parse inputs
  2. Auto-detect work_id from branch
  3. **Check for existing specs** ← NEW
  4. **If exists and !force: Read and return** ← NEW
  5. Fetch issue data (if not recently fetched)
  6. Generate spec (with unique slug if force)
  7. Save and link
```

### Existence Check Logic

```bash
# Step 3: Check for existing specs
check_existing_specs() {
    local work_id="$1"
    local padded_id=$(printf "%05d" "$work_id")
    local specs_dir="${PROJECT_ROOT}/specs"

    # Pattern: WORK-{padded_id}-*.md
    local pattern="WORK-${padded_id}-*.md"

    # Find all matching specs
    local existing_specs=()
    if [[ -d "$specs_dir" ]]; then
        while IFS= read -r -d '' file; do
            existing_specs+=("$file")
        done < <(find "$specs_dir" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
    fi

    # Also check issue comments for spec references
    # (Comments may reference specs that have been archived)

    echo "${existing_specs[@]}"
}
```

### Data Model

No new data models required. Existing spec file naming convention is sufficient:
- Primary spec: `WORK-00245-smart-spec-creation.md`
- Secondary spec: `WORK-00245-phase2-refinements.md`
- Tertiary spec: `WORK-00245-updated-requirements.md`

### API Design

Command interface changes:

- `--force` (boolean flag): Force creation of new spec even if one exists

### UI/UX Changes

New output messages:

**When spec exists (no force):**
```
🎯 STARTING: Spec Generator
Work ID: #245 (auto-detected from branch)
───────────────────────────────────────

ℹ Existing spec(s) found for issue #245:
  1. /specs/WORK-00245-smart-spec-creation.md

✓ Reading existing specification(s)...
✓ Spec context loaded into session

⏭ SKIPPED: Spec already exists
Existing spec: /specs/WORK-00245-smart-spec-creation.md
───────────────────────────────────────
Hint: Use --force to create additional spec
```

**When force creating:**
```
🎯 STARTING: Spec Generator (Force Mode)
Work ID: #245
───────────────────────────────────────

⚠ Existing spec(s) found:
  1. /specs/WORK-00245-smart-spec-creation.md

Creating additional specification...
✓ Unique slug generated: phase2-refinements

✅ COMPLETED: Spec Generator
Spec created: /specs/WORK-00245-phase2-refinements.md
Template used: feature
Previous specs: 1 (incorporated into context)
───────────────────────────────────────
```

## Implementation Plan

### Phase 1: Existence Check
Add spec existence detection to spec-generator skill

**Tasks**:
- [ ] Add `check_existing_specs()` function to detect existing specs
- [ ] Implement glob pattern matching for `WORK-{id}-*.md`
- [ ] Return list of existing spec paths

### Phase 2: Skip Logic
Implement skip behavior when spec exists

**Tasks**:
- [ ] Add condition to skip generation if specs exist and `--force` not set
- [ ] Read and output existing spec path(s) to user
- [ ] Ensure existing spec(s) are available in session context

### Phase 3: Force Flag
Implement `--force` flag for intentional duplicate creation

**Tasks**:
- [ ] Add `--force` flag to command argument parsing
- [ ] Pass force parameter through to skill
- [ ] Generate unique slug when force-creating
- [ ] Update output messages for force mode

### Phase 4: Multi-Spec Awareness
Read all existing specs for context

**Tasks**:
- [ ] When multiple specs exist, read all of them
- [ ] Incorporate all spec content into session context
- [ ] Report count of specs found and read

## Files to Create/Modify

### Modified Files
- `plugins/spec/commands/create.md`: Add `--force` flag documentation
- `plugins/spec/skills/spec-generator/SKILL.md`: Update inputs and workflow for existence check
- `plugins/spec/skills/spec-generator/workflow/generate-from-context.md`: Add Step 2.5 for existence check

### New Files
- `plugins/spec/skills/spec-generator/scripts/check-existing-specs.sh`: Script to find existing specs for a work_id

## Testing Strategy

### Unit Tests
- Test `check_existing_specs()` with no specs → returns empty array
- Test `check_existing_specs()` with one spec → returns single path
- Test `check_existing_specs()` with multiple specs → returns all paths
- Test pattern matching with various work_id formats (1, 12, 123, 1234, 12345)

### Integration Tests
- Test full flow: create spec → re-run create → verify no duplicate
- Test force flow: create spec → force create → verify two specs exist
- Test slug uniqueness when force creating

### E2E Tests
- Test workflow integration: embed spec creation in FABER workflow, run twice
- Verify idempotent behavior in real workflow context

### Performance Tests
- Measure latency added by existence check (<100ms target)
- Test with large `/specs/` directory (100+ files)

## Dependencies

- `fractary-repo` plugin (for branch detection)
- `fractary-work` plugin (for issue comment checking, optional)
- `find` command (standard Unix utility)

## Risks and Mitigations

- **Risk**: False positive on spec existence due to archived specs
  - **Likelihood**: Low
  - **Impact**: Medium (user confusion)
  - **Mitigation**: Only check active `/specs/` directory, not archives

- **Risk**: Slug collision when force-creating multiple specs
  - **Likelihood**: Low
  - **Impact**: Low (file write error)
  - **Mitigation**: Generate timestamp-based or incrementing slugs

- **Risk**: Performance degradation with many specs
  - **Likelihood**: Low
  - **Impact**: Low
  - **Mitigation**: Use efficient glob pattern, limit search to `/specs/` root

## Documentation Updates

- `plugins/spec/commands/create.md`: Document `--force` flag and idempotent behavior
- `CLAUDE.md`: Update spec plugin section with idempotency notes

## Rollout Plan

1. Implement existence check (Phase 1)
2. Add skip logic with user messaging (Phase 2)
3. Add `--force` flag (Phase 3)
4. Add multi-spec reading (Phase 4)
5. Update documentation
6. Test in real FABER workflows

## Success Metrics

- Duplicate spec creation rate: 0% (without `--force`)
- Workflow re-run success rate: 100% (spec creation step passes)
- User confusion incidents: Reduced by clear messaging

## Implementation Notes

Key design decisions:

1. **Check before fetch**: Existence check happens before issue fetch to avoid unnecessary API calls
2. **Inclusive reading**: When spec exists, read it so the session has context (don't just skip silently)
3. **Slug uniqueness**: When force-creating, append timestamp or incremental suffix to ensure unique filename
4. **Comment checking optional**: Checking issue comments for spec references is enhancement, not required for MVP
5. **Session awareness**: If issue was recently fetched, don't refetch - rely on session context

The core principle: **Making spec creation safe to include in any workflow without side effects.**
