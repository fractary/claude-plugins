# ADR-001: Operation-Specific Architecture for Docs Plugin

**Status**: Accepted
**Date**: 2025-01-15
**Context**: fractary-docs plugin v2.0 architecture refactor
**Issue**: https://github.com/fractary/claude-plugins/issues/XXX

## Context

The fractary-docs plugin (v1.x) maintained **11 type-specific skills** (docs-manage-api, docs-manage-adr, docs-manage-architecture, etc.) with **93% code duplication**. Adding new document types required creating entire new skills (~500 lines each), and changes to core operations needed to be replicated across all type skills.

### Problems with v1.x Architecture

1. **Massive Code Duplication**: 93% of code was duplicated across type-specific skills
2. **High Maintenance Burden**: Changes required updates in 11+ places
3. **Large Codebase**: ~7,000 lines of code for relatively simple operations
4. **Difficult to Extend**: Adding new doc type = new 500-line skill
5. **Context Inefficiency**: Separate skills loaded into context independently
6. **Inconsistent Behavior**: Type-specific implementations diverged over time

### Example of Duplication

**v1.x Pattern** (repeated 11 times):
```markdown
# docs-manage-api/SKILL.md
<CRITICAL_RULES>
1. ALWAYS generate frontmatter with required fields
2. ALWAYS use template.md for structure
3. ALWAYS validate before completion
4. ALWAYS update index after creation
</CRITICAL_RULES>

<WORKFLOW>
1. Load template
2. Render with context
3. Validate document
4. Update index
</WORKFLOW>
```

Same exact workflow in `docs-manage-adr`, `docs-manage-architecture`, etc. Only difference: template content and schema fields.

## Decision

We will **refactor from type-specific skills to operation-specific skills** with data-driven type context.

### New Architecture (v2.0)

**Before**:
```
11 type-specific skills
   ├─ docs-manage-api (500 lines)
   ├─ docs-manage-adr (500 lines)
   ├─ docs-manage-architecture (500 lines)
   └─ ... (8 more)
```

**After**:
```
4 operation-specific skills (universal)
   ├─ doc-writer (handles ANY doc_type)
   ├─ doc-validator (handles ANY doc_type)
   ├─ doc-classifier (handles ANY doc_type)
   └─ doc-lister (handles ANY doc_type)

+ Type context in types/{doc_type}/
   ├─ schema.json
   ├─ template.md
   ├─ standards.md
   ├─ validation-rules.md
   └─ index-config.json
```

### Key Principles

1. **Separate Data from Logic**
   - Type-specific behavior = data files in `types/{doc_type}/`
   - Universal operations = skills in `skills/doc-*/`

2. **Single Responsibility**
   - Each skill handles ONE operation (write, validate, classify, list)
   - Each skill works with ANY document type

3. **Data-Driven Behavior**
   - Skills load type context at runtime
   - No hardcoded type logic in skills

4. **Consistent Coordination**
   - `docs-manager-skill` orchestrates single-doc workflows
   - `docs-director-skill` handles multi-doc with parallelization

5. **3-Layer Architecture**
   ```
   Commands (Layer 1)
      ↓
   Coordination (Layer 2: manager/director)
      ↓
   Operations (Layer 3: writer/validator/classifier/lister)
      ↓
   Type Context (Data: 5 files per type)
   ```

### Type Context Structure

Each document type defined by exactly 5 files:

1. **schema.json** - JSON Schema (Draft 7) for frontmatter validation
2. **template.md** - Mustache template for content generation
3. **standards.md** - Writing guidelines and best practices
4. **validation-rules.md** - Type-specific quality checks
5. **index-config.json** - Index organization configuration

### Implementation Strategy

**Phase 1**: Extract type context to `types/{doc_type}/` directories
**Phase 2**: Build operation-specific skills (doc-writer, doc-validator, etc.)
**Phase 3**: Enhance shared scripts (index-updater, dual-format-generator)
**Phase 4**: Build coordination skills (manager, director)
**Phase 5**: Update commands to use new routing
**Phase 6**: Test all features and doc types
**Phase 7**: Delete old type-specific skills
**Phase 8**: Documentation and migration guide

## Consequences

### Positive

✅ **93% less code duplication** - From ~7,000 to ~2,500 lines
✅ **Easier to extend** - Adding new type = 5 data files (~200 lines) vs new skill (500+ lines)
✅ **Easier to maintain** - Changes in 1-4 places instead of 11+
✅ **Lower context usage** - Shared operation skills vs separate type skills
✅ **Consistent behavior** - Single implementation guarantees consistency
✅ **Better separation of concerns** - Data vs logic clearly separated
✅ **Testable** - Test operations once, not per type

### Negative

⚠️ **Migration required** - Frontmatter field change: `type:` → `fractary_doc_type:`
⚠️ **Breaking changes** - Commands renamed: `/fractary-docs:*` → `/docs:*`
⚠️ **New mental model** - Users need to understand type context vs skills
⚠️ **Indirection** - Skills load type context dynamically (less obvious)

### Risks and Mitigations

**Risk**: Type context loading adds complexity
**Mitigation**: Clear error messages, validation of type directories

**Risk**: Breaking changes disrupt existing workflows
**Mitigation**: Migration guide, backward compatibility warnings

**Risk**: Performance overhead from dynamic loading
**Mitigation**: Type context is small (~1-5KB per type), loaded once per operation

## Alternatives Considered

### Alternative 1: Keep Type-Specific Skills, Extract Common Functions

**Approach**: Create shared library, call from type skills
**Rejected**: Still requires maintaining 11 skills, doesn't solve duplication fundamentally

### Alternative 2: Template-Based Skill Generation

**Approach**: Generate type skills from templates at install time
**Rejected**: Generated code still needs maintenance, obscures actual behavior

### Alternative 3: Single Mega-Skill with Type Switch Statements

**Approach**: One skill with if/else branching for each type
**Rejected**: Would create massive, unreadable skill file (1000+ lines)

### Alternative 4: Hybrid (Common Operations + Type-Specific Extensions)

**Approach**: Base operation skills + optional type-specific overrides
**Rejected**: More complex, harder to reason about, loses consistency benefit

## Implementation Details

### Critical Design Decisions

1. **Frontmatter Field**: `fractary_doc_type` (not `type`)
   - Reason: Avoid collision with generic `type` field in user schemas
   - Trade-off: Longer name, breaking change from v1.x

2. **Type Directory Location**: `plugins/docs/types/{doc_type}/`
   - Reason: Clear separation from skills, easy to find/add types
   - Trade-off: Not in skills directory (less obvious relationship)

3. **Index Organization**: Configurable via `index-config.json`
   - Reason: Different types need flat vs hierarchical organization
   - Trade-off: Adds configuration complexity

4. **Coordination Split**: manager (single-doc) vs director (multi-doc)
   - Reason: Different concerns (pipeline vs parallelization)
   - Trade-off: Two coordination skills instead of one

### Code Quality Metrics

| Metric | v1.x | v2.0 | Change |
|--------|------|------|--------|
| **Total Lines** | ~7,000 | ~2,500 | -64% |
| **Duplication** | 93% | <7% | -86pp |
| **Skills** | 14 | 6 | -57% |
| **To Add Type** | 500+ lines | 200 lines | -60% |
| **Maintenance Points** | 11+ files | 1-4 files | -73% |

## Validation

### Success Criteria

✅ All 11 existing doc types work with new architecture
✅ Can add new type by creating 5 data files (no skill changes)
✅ Write → validate → index pipeline works automatically
✅ Batch operations work with parallel execution
✅ Migration guide available for v1.x users

### Testing Strategy

- **Unit tests**: Each operation skill tested independently
- **Integration tests**: Full pipeline (write → validate → index)
- **Type coverage**: Test all 11 document types
- **Regression tests**: Ensure v1.x functionality preserved
- **Performance tests**: Verify no significant slowdown

## References

- **Specification**: `docs/specs/SPEC-docs-plugin-refactor.md`
- **Implementation Issue**: https://github.com/fractary/claude-plugins/issues/XXX
- **Migration Guide**: `plugins/docs/README.md#migration-from-v1x`
- **Plugin Standards**: `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`

## Version History

- **2025-01-15**: Initial ADR (v2.0.0 architecture)
