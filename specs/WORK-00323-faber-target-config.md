---
spec_id: WORK-00323-faber-target-config
work_id: 323
issue_url: https://github.com/fractary/claude-plugins/issues/323
title: FABER Target Configuration for Work-ID-Free Planning
type: feature
status: draft
created: 2025-12-10
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: FABER Target Configuration for Work-ID-Free Planning

**Issue**: [#323](https://github.com/fractary/claude-plugins/issues/323)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-10

## Summary

This specification proposes adding a `targets` configuration section to FABER config that allows projects to define named targets with metadata, enabling the planner to work effectively without requiring a `work_id`. This addresses the use case where users want to run `/fractary-faber:plan <target>` on specific entities (files, modules, patterns) without having a linked GitHub issue.

## Problem Statement

Currently, the FABER workflow has two primary invocation patterns:

1. **With work_id**: `/fractary-faber:plan 123` - Clear context from issue title/description
2. **Without work_id**: `/fractary-faber:plan <target>` or `/fractary-faber:plan <pattern>` - Unclear what the target represents

When a `work_id` is provided, the planner fetches issue details and understands what work needs to be done. However, when only a `target` or wildcard pattern is provided, the planner lacks:
- What type of entity the target represents (file, module, component, dataset)
- What context/metadata is relevant
- How to match patterns to actual filesystem or logical entities
- What workflow is appropriate for this target type

## User Stories

### Story 1: Data Engineer Planning on Dataset Patterns
**As a** data engineer
**I want** to run `faber:plan ipeds/*` to plan work on IPEDS datasets
**So that** I can create plans for data processing tasks without creating issues first

**Acceptance Criteria**:
- [ ] FABER config can define `ipeds/*` as a target pattern
- [ ] Config specifies that this pattern matches "datasets"
- [ ] Planner receives metadata about what "datasets" means in this project
- [ ] Generated plan is appropriate for data processing work

### Story 2: Developer Planning on File/Module
**As a** developer
**I want** to run `faber:plan src/auth/**` to plan refactoring of auth module
**So that** I can create technical plans without creating issues for exploratory work

**Acceptance Criteria**:
- [ ] FABER config can define `src/auth/**` as a target pattern
- [ ] Config specifies this matches "modules" with type "code"
- [ ] Planner generates code-appropriate plans

### Story 3: Multi-Type Project Support
**As a** project maintainer
**I want** to define multiple target types in my FABER config
**So that** the same project can handle datasets, code modules, and documentation targets appropriately

**Acceptance Criteria**:
- [ ] FABER config supports multiple target definitions
- [ ] Each target type can have different metadata
- [ ] Each target type can optionally override the default workflow

## Functional Requirements

- **FR1**: FABER config schema must support an optional `targets` section
- **FR2**: Each target definition must include at minimum: `name`, `pattern`, and `type`
- **FR3**: Target matching must support glob patterns (e.g., `ipeds/*`, `src/**/*.ts`)
- **FR4**: Planner must use target metadata when generating plans
- **FR5**: Target definitions may optionally specify a workflow override
- **FR6**: If no target matches and no work_id provided, planner should prompt for clarification
- **FR7**: Provide a `--dry-run` option to test target matching without generating a plan

## Non-Functional Requirements

- **NFR1**: Configuration changes must be backward compatible - existing configs work unchanged (compatibility)
- **NFR2**: Target matching should complete in <100ms even with many patterns (performance)
- **NFR3**: Error messages should clearly indicate when no target matches (usability)

## Technical Design

### Configuration Schema Extension

Add to `.fractary/plugins/faber/config.json`:

```json
{
  "schema_version": "2.1",
  "targets": {
    "definitions": [
      {
        "name": "ipeds-datasets",
        "pattern": "ipeds/*",
        "type": "dataset",
        "description": "IPEDS education datasets for ETL processing",
        "metadata": {
          "entity_type": "dataset",
          "processing_type": "etl",
          "expected_artifacts": ["processed_data", "validation_report"]
        },
        "workflow_override": null
      },
      {
        "name": "source-modules",
        "pattern": "src/**",
        "type": "code",
        "description": "Source code modules",
        "metadata": {
          "entity_type": "module",
          "languages": ["typescript", "javascript"]
        }
      },
      {
        "name": "plugin-implementations",
        "pattern": "plugins/*/",
        "type": "plugin",
        "description": "Plugin implementation directories",
        "metadata": {
          "entity_type": "plugin",
          "structure": "claude-plugin"
        }
      }
    ],
    "default_type": "file",
    "require_match": false
  }
}
```

### Target Definition Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Unique identifier for the target |
| `pattern` | string | Yes | Glob pattern to match |
| `type` | string | Yes | Category: `dataset`, `code`, `plugin`, `docs`, `config` |
| `description` | string | No | Human-readable description |
| `metadata` | object | No | Arbitrary metadata passed to planner |
| `workflow_override` | string | No | Override workflow ID for this target type |

### Planner Context Enhancement

When `/fractary-faber:plan <target>` is invoked without `work_id`:

1. **Match Phase**: Iterate through `targets.definitions` to find matching pattern
2. **Resolve Phase**: If match found, load target metadata
3. **Context Phase**: Inject target info into planner context:
   ```json
   {
     "planning_mode": "target",
     "target": {
       "input": "ipeds/admissions",
       "matched_definition": "ipeds-datasets",
       "type": "dataset",
       "metadata": { ... }
     }
   }
   ```
4. **Generate Phase**: Planner uses context to generate appropriate plan

### Pattern Specificity Rules

When multiple patterns could match a target, specificity is determined by:

1. **Literal Prefix Length**: Patterns with longer non-wildcard prefixes win
   - `src/auth/**` beats `src/**` (prefix "src/auth/" > "src/")
   - `plugins/faber/**` beats `plugins/*/` (literal "faber" > wildcard)

2. **Wildcard Count**: Fewer wildcards indicates higher specificity
   - `src/auth/login.ts` beats `src/auth/*.ts` (0 wildcards > 1)
   - `plugins/repo/**` beats `plugins/**/**` (1 `**` > 2)

3. **Definition Order**: If specificity is equal, first defined pattern wins
   - Allows explicit control via ordering in config

**Implementation**: Use a scoring function:
```
score = (literal_prefix_length * 100) - (wildcard_count * 10) - definition_index
```

### Multiple Match Resolution

When a target matches multiple patterns:
- **Single Match**: Use that definition's metadata
- **Multiple Matches**: Use the most specific match (per rules above)
- **Equal Specificity**: Use first match, log warning about ambiguity

Users can reorder definitions or make patterns more specific to control behavior.

### Logical vs Filesystem Targets

Targets are primarily glob patterns matching filesystem paths. For logical groupings:
- Use the `metadata` field to define logical relationships
- Define a pattern that encompasses the logical entity (e.g., `{src/auth,src/session}/**` for "auth-system")
- Future enhancement: Add `aliases` field for purely logical names

### No Match Behavior

When `targets.require_match` is `true` and no pattern matches:
- Return error: "No target definition matches '<input>'. Configure targets in .fractary/plugins/faber/config.json"

When `targets.require_match` is `false` (default):
- Use `targets.default_type` as the type
- Continue with minimal context

### Type-Specific Plan Templates

Generated plans should adapt their structure based on target type:

| Target Type | Plan Emphasis | Key Sections |
|-------------|---------------|--------------|
| `dataset` | ETL pipeline, data validation | Data sources, transformations, validation rules, output schemas |
| `code` | Implementation, testing | Files to modify, functions/classes, test coverage, refactoring notes |
| `plugin` | Plugin architecture, integration | Commands, skills, agents, config schema, hooks |
| `docs` | Content structure, accuracy | Sections to update, cross-references, examples needed |
| `config` | Schema changes, migration | Breaking changes, defaults, validation rules |

The planner skill uses `target.type` to select appropriate prompts and plan structure.

### FABER Phase Integration

Target-based planning modifies the standard FABER workflow:

| Phase | With work_id | With target (no work_id) |
|-------|--------------|--------------------------|
| **Frame** | Fetch issue, classify work | Skip issue fetch, use target type for classification |
| **Architect** | Generate spec from issue | Generate spec from target metadata |
| **Build** | Create branch linked to issue | Create branch with target-derived name |
| **Evaluate** | Standard review | Standard review |
| **Release** | PR linked to issue | PR with target context (no issue link) |

**Key Differences**:
- Frame phase is minimal (no issue to fetch)
- Work classification comes from `target.type` instead of issue labels
- Branch naming uses target name: `feat/{target-name}-{slug}`
- PRs don't have linked issues unless user creates one

**Optional Auto-Issue Creation**: Add `targets.auto_create_issue: true` to automatically create an issue when target-based planning starts, providing full FABER integration.

## Implementation Plan

### Phase 1: Schema Extension
**Objective**: Add targets configuration schema support

**Tasks**:
- [ ] Update config.schema.json with targets section
- [ ] Add validation for target definitions
- [ ] Update config loading in faber-manager

**Estimated Scope**: Small

### Phase 2: Pattern Matching
**Objective**: Implement target pattern matching logic

**Tasks**:
- [ ] Create target matcher utility
- [ ] Support glob pattern matching (using minimatch or similar)
- [ ] Add match priority (most specific pattern wins)
- [ ] Handle overlapping patterns

**Estimated Scope**: Medium

### Phase 3: Planner Integration
**Objective**: Pass target context to planner skill

**Tasks**:
- [ ] Modify faber-planner to accept target context
- [ ] Update plan generation prompts to use target metadata
- [ ] Adjust generated plan format based on target type

**Estimated Scope**: Medium

### Phase 4: Documentation & Examples
**Objective**: Document the feature and provide examples

**Tasks**:
- [ ] Update FABER config documentation
- [ ] Add example configs for different project types
- [ ] Update planner command documentation

**Estimated Scope**: Small

## Files to Create/Modify

### New Files
- `plugins/faber/config/config.schema.json`: Update schema with targets section
- `plugins/faber/skills/target-matcher/SKILL.md`: New skill for pattern matching

### Modified Files
- `plugins/faber/skills/faber-manager/SKILL.md`: Add target resolution logic
- `plugins/faber/skills/faber-planner/SKILL.md`: Accept and use target context
- `plugins/faber/docs/CONFIGURATION.md`: Document targets configuration
- `plugins/faber/commands/plan.md`: Document target-based invocation

## Testing Strategy

### Unit Tests
- Target pattern matching with various glob patterns
- Schema validation for target definitions
- Edge cases: overlapping patterns, no match, invalid patterns

### Integration Tests
- Full planner flow with target-based invocation
- Verify correct metadata passed to planner
- Test workflow override functionality

### E2E Tests
- `/fractary-faber:plan src/auth/**` with code target defined
- `/fractary-faber:plan ipeds/*` with dataset target defined
- Verify generated plans match target type expectations

## Dependencies

- Glob pattern matching library (minimatch or similar)
- JSON schema validation (already used)

## Risks and Mitigations

- **Risk**: Complex glob patterns may cause performance issues
  - **Likelihood**: Low
  - **Impact**: Medium
  - **Mitigation**: Add pattern complexity limits, cache compiled patterns

- **Risk**: Overlapping patterns may cause confusion
  - **Likelihood**: Medium
  - **Impact**: Low
  - **Mitigation**: Clear priority rules (most specific wins), logging of match decisions

- **Risk**: Backward compatibility issues with existing configs
  - **Likelihood**: Low
  - **Impact**: High
  - **Mitigation**: Targets section is optional, existing behavior unchanged

## Documentation Updates

- `plugins/faber/docs/CONFIGURATION.md`: Add targets section documentation
- `plugins/faber/docs/PLANNING.md`: Document target-based planning workflow
- `README.md`: Add brief mention of target configuration

## Success Metrics

- User can run `faber:plan <target>` without work_id and get appropriate plan: Yes/No
- Plans generated for different target types are contextually appropriate: Review-based
- No regression in work_id-based planning workflow: Test pass rate

## Implementation Notes

**Conversation Context from Issue #323:**

The original issue raises key questions:
1. "How does the planner know what it's planning work on?" - Solved by target metadata
2. "How do I match targets based on wildcard expression?" - Solved by glob pattern matching
3. "What about projects with multiple types of targets?" - Solved by multiple target definitions

The conclusion from the issue author: "The workflow config would need to say what the target is, and provide all the other information the planner would need to work." This specification implements that vision through the `targets` configuration section.

**Alternative Considered**: Using file extensions or directory structure conventions instead of explicit configuration. Rejected because it's not flexible enough for diverse project types (data pipelines, plugins, mixed repos).

---

## Changelog

### 2025-12-10 - Refinement Round 1
**Refined by**: FABER spec-refiner

**Additions**:
- Added "Pattern Specificity Rules" section with scoring algorithm
- Added "Multiple Match Resolution" section
- Added "Logical vs Filesystem Targets" clarification
- Added "Type-Specific Plan Templates" table
- Added "FABER Phase Integration" section with workflow comparison table
- Added FR7: `--dry-run` option for target matching

**Best-Effort Decisions**:
- Pattern specificity uses scoring formula: `(literal_prefix_length * 100) - (wildcard_count * 10) - definition_index`
- Multiple matches resolved by specificity, then definition order
- Logical targets handled via metadata field, not separate alias system
- Target-based planning skips Frame phase issue fetch, uses target type for classification
