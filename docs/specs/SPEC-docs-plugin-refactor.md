# SPEC: Docs Plugin Architecture Refactoring

**Status**: Draft
**Type**: Architecture
**Priority**: High
**Complexity**: High
**Estimated Effort**: 18 days
**Author**: Claude
**Created**: 2025-01-15

---

## Executive Summary

Refactor the fractary-docs plugin from type-specific skills with duplicated lifecycle logic to a 3-layer architecture with operation-specific skills that dynamically load type context. This reduces code duplication by 93%, improves token efficiency by 50%, and aligns with the repo/work plugin patterns.

## Problem Statement

### Current Architecture Issues

1. **Massive Code Duplication** (85-90%)
   - 11+ type-specific skills (docs-manage-api, docs-manage-dataset, docs-manage-etl, etc.)
   - Each contains identical CREATE, UPDATE, VALIDATE, LIST, REINDEX operations
   - ~4,850 lines of code with 85-90% duplication
   - Bug fixes require updating 11 separate files

2. **Context Inefficiency**
   - Each operation loads entire skill (~15K-40K tokens)
   - Only 20% of loaded context is relevant to the operation
   - Wastes 80% of context window

3. **Maintenance Burden**
   - New doc type = copy 300+ lines and customize 10%
   - Inconsistency risk when updating multiple skills
   - 55 unique operation implementations (11 types × 5 operations)

4. **Context Loss Problem**
   - Invoking docs-manager agent creates fresh context
   - Loses valuable conversation history about document being created
   - After rich discussion, context doesn't carry over to agent

5. **Scaling Issues**
   - Current: 11 types = ~4,850 lines
   - Future: 20 types = ~10,000 lines (quadratic growth)

## Proposed Solution

### Architecture Overview

**3-Layer Architecture** (matches repo/work plugin pattern):

```
Layer 1: Commands
  ↓ (parse args, preserve/pass context)
Layer 2: docs-director-skill / docs-manager-skill
  ↓ (orchestrate, coordinate, plan)
Layer 3: Operation Skills
  ↓ (execute single-doc operations)
```

### Core Components

#### Layer 1: Commands

**Commands** (6 total):
- `/fractary-docs:write` - Create or update documentation
- `/fractary-docs:validate` - Validate documentation
- `/fractary-docs:list` - List documentation
- `/fractary-docs:audit` - Assess documentation health
- `/fractary-docs:manage` - General purpose (agent-based)

**Routing Logic**:
- Pattern detected (wildcards) → docs-director-skill
- Rich conversational context → docs-manager-skill (preserves context)
- Explicit --context provided → docs-manager-skill (uses explicit context)
- Via /manage command → docs-manager agent → docs-manager-skill

#### Layer 2: Orchestration Skills

**docs-director-skill** - Multi-document orchestration
- Responsibilities:
  - Accept wildcard patterns (docs/api/**/*.md)
  - Expand patterns to file lists
  - Accept shared --context parameter
  - Extract file-specific context from existing docs
  - Loop through files, invoke docs-manager-skill for each
  - Support parallelization (spawn multiple manager instances)
  - Aggregate results
  - Present plan for multi-doc operations

**docs-manager-skill** - Single-document workflow orchestration
- Responsibilities:
  - Parse natural language requests
  - Auto-detect doc_type (via doc-classifier if needed)
  - Load type context from `types/{doc_type}/`
  - Accept and merge multiple context sources:
    - Conversational context (from conversation history)
    - Explicit context (from --context parameter)
    - File-specific context (from director)
    - Existing content (for updates)
  - Build execution plan
  - Present plan (configurable auto-approve via config)
  - Coordinate operation skills (write → validate → index)
  - Retain conversational context
  - Return results

**docs-manager agent** - Thin wrapper
- Responsibilities:
  - Receive operation request with --context
  - Immediately delegate to docs-manager-skill
  - Used when fresh context preferred

#### Layer 3: Operation Skills

**doc-writer** - CREATE + UPDATE operations (single-doc)
- Merged from doc-generator + doc-updater
- CREATE: Generate from template with conversational/explicit context
- UPDATE: Modify existing + version bump
- **Embedded validation**: Always validates after write
- **Embedded indexing**: Always updates parent README.md after validation
- Uses type-specific index-config.json
- Receives: doc_type, type context, content context bundle

**doc-validator** - VALIDATE operation (single-doc)
- Standalone validation when needed without writing
- Type-specific rule loading from validation-rules.md
- Checks: frontmatter, structure, schema compliance, links
- Returns: Issues categorized by severity (error, warning, info)

**doc-classifier** - AUTO-DETECT doc_type
- Strategy: Path pattern first → content analysis fallback
- Path patterns: docs/api/ → api, docs/datasets/ → dataset
- Content analysis: Read frontmatter fractary_doc_type, analyze structure
- Returns: doc_type with confidence score

**doc-lister** - LIST operation
- Scans docs, reads frontmatter
- Filters by: fractary_doc_type, status, tags, date
- Single-doc focused (director handles multi-doc patterns)
- Returns: Structured list

**doc-auditor** - AUDIT operation (separate workflow)
- Assesses: completeness, freshness, quality, compliance
- Scope: Single doc, doc_type, or all docs
- Returns: Health score (0-100), issues list, improvement plan
- Not part of standard write workflow

#### Type Context Files

**Structure** (per doc_type):
```
plugins/docs/types/{doc_type}/
├── schema.json              # JSON schema for {doc_type}.json validation
├── template.md              # README.md template (Mustache format)
├── standards.md             # Type-specific documentation standards
├── validation-rules.md      # Type-specific validation requirements
└── index-config.json        # Index configuration (NEW)
```

**Supported doc_types**:
- api, dataset, etl, testing, infrastructure, audit
- architecture, adr, guides, standards
- _untyped (fallback for simple docs)

**index-config.json** - Defines index behavior:
```json
{
  "index_file": "docs/api/README.md",
  "organization": "hierarchical",
  "group_by": ["service", "version"],
  "sort_by": "endpoint",
  "entry_template": "- [**{{method}} {{endpoint}}**]({{relative_path}}) - {{title}}",
  "section_template": "## {{service}} ({{version}})"
}
```

### Key Features

#### 1. Context Preservation & Passing

**Conversational Context** (implicit - skill direct invocation):
```bash
# After rich discussion about JWT auth endpoint
/fractary-docs:write --doc-type api
→ docs-manager-skill DIRECTLY invoked
→ Retains full conversation history
→ Extracts details automatically
```

**Explicit Context** (passed - agent/director):
```bash
# Simple case - user provides context
/fractary-docs:write --doc-type dataset --context "Customer events dataset, 345M records, updated hourly"
→ docs-manager-skill with explicit context

# Director orchestration - passes context per doc
/fractary-docs:write "docs/api/**/*.md" --context "Add rate limiting section"
→ docs-director loops through 23 docs
→ Each invocation: shared context + file-specific context
```

**Context Priority**:
1. Conversational context (highest - if skill invoked directly)
2. Explicit context (from --context parameter)
3. File-specific context (extracted by director)
4. Existing content (for updates)

#### 2. Auto-Validation

Write operation **always validates** after document generation/update.
- No separate validation step needed
- Ensures documentation quality
- Reports issues immediately

#### 3. Auto-Indexing

Write operation **always updates index** after validation.
- No manual `/fractary-docs:reindex` needed
- Index updated: `docs/{doc_type}/README.md`
- Uses index-config.json for organization
- Embedded in doc-writer skill

#### 4. Type-Specific Indices

Each doc_type has its own README.md index:
- `docs/api/README.md` - Organized by service/version
- `docs/datasets/README.md` - Flat list sorted by name
- `docs/etl/README.md` - Organized by pipeline type
- `docs/testing/README.md` - Organized by test type
- etc.

#### 5. Pattern Matching & Multi-Doc Operations

Director handles wildcards and patterns:
```bash
/fractary-docs:write "docs/api/**/*.md" --context "Add rate limiting docs"
→ docs-director expands to 23 files
→ Presents plan, gets approval
→ Loops through files
→ Can parallelize (3-5 at a time)
```

#### 6. Frontmatter Standard

All docs include `fractary_doc_type` field:
```yaml
---
title: "Get User Endpoint"
fractary_doc_type: api          # Drives type-specific behavior
status: draft
created: 2025-01-15T10:30:00Z
updated: 2025-01-15T10:30:00Z
version: 1.0.0
author: Claude
tags: [rest-api, users, authentication]
work_id: "123"
---
```

### Workflow

**Write Operation** (simplified from original --complete proposal):
1. doc-writer: Generate or update document
2. doc-writer: Validate document (embedded)
3. doc-writer: Update index (embedded)

**No --complete flag needed** - validation and indexing are automatic.

**Validate Operation** (standalone, when needed):
1. doc-validator: Check existing doc
2. Report issues

**Audit Operation** (separate workflow):
1. doc-auditor: Assess health across docs
2. Generate improvement plan

## Technical Design

### File Structure After Migration

```
plugins/docs/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   └── docs-manager.md          # Thin wrapper
├── skills/
│   ├── docs-director/           # Layer 2: Multi-doc orchestration
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── expand-pattern.sh
│   │       ├── extract-file-context.sh
│   │       └── combine-contexts.sh
│   ├── docs-manager/            # Layer 2: Single-doc workflow
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── parse-context.sh
│   │       ├── extract-facts.sh
│   │       └── merge-contexts.sh
│   ├── doc-writer/              # Layer 3: CREATE + UPDATE
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── write-doc.sh
│   │       └── apply-context.sh
│   ├── doc-validator/           # Layer 3: VALIDATE
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── validate-doc.sh
│   ├── doc-classifier/          # Layer 3: AUTO-DETECT
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── classify-doc.sh
│   ├── doc-lister/              # Layer 3: LIST
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── list-docs.sh
│   ├── doc-auditor/             # Layer 3: AUDIT
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── audit-docs.sh
│   └── _shared/lib/
│       ├── dual-format-generator.sh
│       ├── index-updater.sh     # ENHANCED: Reads index-config.json
│       └── config-resolver.sh
├── types/                       # Type context per doc_type
│   ├── api/
│   │   ├── schema.json
│   │   ├── template.md
│   │   ├── standards.md
│   │   ├── validation-rules.md
│   │   └── index-config.json
│   ├── dataset/
│   ├── etl/
│   ├── testing/
│   ├── infrastructure/
│   ├── audit/
│   ├── architecture/
│   ├── adr/
│   ├── guides/
│   ├── standards/
│   └── _untyped/                # Fallback
└── commands/
    ├── write.md                 # /fractary-docs:write
    ├── validate.md              # /fractary-docs:validate
    ├── list.md                  # /fractary-docs:list
    ├── audit.md                 # /fractary-docs:audit
    └── manage.md                # /fractary-docs:manage
```

### Context Bundle Structure

When docs-manager-skill is invoked:
```json
{
  "operation": "write",
  "doc_type": "api",
  "file_path": "docs/api/auth/login/README.md",
  "context": {
    "conversational": {
      "enabled": true,
      "messages": [...],
      "extracted_facts": {
        "endpoint": "POST /auth/login",
        "auth_type": "OAuth 2.0 + JWT"
      }
    },
    "explicit": "Add rate limiting: 100 req/min per user",
    "file_specific": {
      "current_endpoint": "POST /auth/login",
      "current_service": "Authentication Service"
    },
    "existing_content": {
      "frontmatter": {...},
      "sections": [...],
      "full_content": "..."
    }
  }
}
```

### Configuration

**Location**: `.fractary/plugins/docs/config.json`

```json
{
  "workflow": {
    "auto_approve_single_doc": true,
    "auto_approve_multi_doc": false,
    "auto_approve_timeout_seconds": 5
  },
  "context_detection": {
    "enabled": true,
    "min_relevant_lines": 10
  },
  "parallelization": {
    "enabled": true,
    "max_concurrent": 5
  },
  "doc_types": {
    "api": { "path": "docs/api", "template": "types/api/template.md" },
    "dataset": { "path": "docs/datasets", "template": "types/dataset/template.md" },
    "etl": { "path": "docs/etl", "template": "types/etl/template.md" },
    "testing": { "path": "docs/testing", "template": "types/testing/template.md" }
  }
}
```

## Implementation Plan

### Phase 1: Create Skill Infrastructure (4 days)

**1.1 docs-director-skill**
- Accept wildcard patterns
- Expand patterns to file lists
- Accept --context parameter (shared across all docs)
- Extract file-specific context from existing docs
- Combine shared + file-specific contexts
- Loop orchestration with progress tracking
- Parallel invocation support (configurable max concurrent)
- Multi-doc plan presentation with approval

**1.2 docs-manager-skill**
- Natural language request parsing
- doc_type auto-detection (via doc-classifier)
- Type context loading from `types/{doc_type}/`
- Context bundle creation (conversational + explicit + file-specific + existing)
- Context merging with priority rules
- Single-doc workflow coordination
- Plan generation and approval (configurable)
- Context preservation (retains conversation history)

**1.3 docs-manager agent**
- Thin wrapper implementation
- Accept --context parameter
- Immediately delegate to docs-manager-skill
- Pass context bundle to skill

### Phase 2: Create Operation Skills (3 days)

**2.1 doc-writer** (merged from doc-generator + doc-updater)
- CREATE operation (generate from template)
- UPDATE operation (modify existing + version bump)
- Embedded validation (always validates after write)
- Embedded indexing (always updates index after validation)
- Context application (use content_context bundle)
- Type-specific template rendering
- Uses index-config.json for index updates

**2.2 doc-validator**
- Standalone validation
- Type-specific rule loading
- Schema validation
- Frontmatter checking
- Structure validation
- Link checking
- Markdown linting
- Issue categorization (error, warning, info)

**2.3 doc-classifier**
- Path pattern detection (docs/api/ → api)
- Content analysis fallback (read frontmatter, analyze structure)
- doc_type inference
- Confidence scoring

**2.4 doc-lister**
- Directory scanning
- Frontmatter parsing
- Filtering (by doc_type, status, tags, date)
- Structured list generation

**2.5 doc-auditor**
- Health assessment (completeness, freshness, quality)
- Compliance checking
- Scoring algorithm (0-100)
- Issue identification
- Improvement plan generation

### Phase 3: Extract Type Context (3 days)

For each doc_type: api, dataset, etl, testing, infrastructure, audit, architecture, adr, guides, standards

**3.1 Create type directories**
```bash
mkdir -p plugins/docs/types/{api,dataset,etl,testing,infrastructure,audit,architecture,adr,guides,standards,_untyped}
```

**3.2 Extract schema.json**
- Source: `skills/docs-manage-{type}/schemas/*.schema.json`
- Destination: `types/{doc_type}/schema.json`
- Update `$id` field to reference new location

**3.3 Extract template.md**
- Source: `skills/docs-manage-{type}/SKILL.md` OUTPUT_FORMAT section
- Extract README structure
- Convert to Mustache template with `{{variables}}`
- Destination: `types/{doc_type}/template.md`

**3.4 Extract standards.md**
- Source: `skills/docs-manage-{type}/SKILL.md` CRITICAL_RULES/CONTEXT sections
- Extract type-specific requirements, conventions
- Document best practices
- Destination: `types/{doc_type}/standards.md`

**3.5 Extract validation-rules.md**
- Source: `skills/docs-manage-{type}/SKILL.md` VALIDATE sections
- Extract validation logic
- Document required sections, field constraints
- Destination: `types/{doc_type}/validation-rules.md`

**3.6 Create index-config.json**
- Define index file location (`docs/{doc_type}/README.md`)
- Define organization (hierarchical vs flat)
- Define grouping criteria (service, version, name, etc.)
- Define sorting rules
- Define entry/section templates
- Destination: `types/{doc_type}/index-config.json`

### Phase 4: Update Shared Scripts (1 day)

**4.1 Enhance index-updater.sh**
- Location: `skills/_shared/lib/index-updater.sh`
- Read `types/{doc_type}/index-config.json`
- Update specified index file (e.g., `docs/api/README.md`)
- Support hierarchical organization (group_by)
- Support flat organization (sort_by only)
- Use entry/section templates from config
- Handle nested grouping (service → version)

**4.2 Update dual-format-generator.sh**
- Ensure it calls index-updater.sh after generation
- Pass doc_type for index-config lookup
- Handle validation integration

### Phase 5: Create Commands with Smart Routing (2 days)

**5.1 write.md** - `/fractary-docs:write`
- Parse arguments
- Accept --context parameter
- Detect pattern vs single file
- Routing logic:
  - Pattern detected → docs-director-skill
  - Rich conversational context → docs-manager-skill (preserve)
  - Explicit --context provided → docs-manager-skill (use explicit)
  - Default → docs-manager-skill

**5.2 validate.md** - `/fractary-docs:validate`
- Same routing logic as write.md
- Standalone validation (no write)

**5.3 list.md** - `/fractary-docs:list`
- Direct invocation of doc-lister
- Filter parameters

**5.4 audit.md** - `/fractary-docs:audit`
- Direct invocation of doc-auditor
- Scope parameters (single doc, doc_type, all)

**5.5 manage.md** - `/fractary-docs:manage`
- Agent-based invocation
- Accept --context parameter
- Invoke docs-manager agent → docs-manager-skill

### Phase 6: Delete Old Skills (1 day)

**6.1 Remove type-specific skills**
- Delete `skills/docs-manage-api/`
- Delete `skills/docs-manage-dataset/`
- Delete `skills/docs-manage-etl/`
- Delete `skills/docs-manage-testing/`
- Delete `skills/docs-manage-infrastructure/`
- Delete `skills/docs-manage-audit/`
- Delete `skills/docs-manage-architecture/`
- Delete `skills/docs-manage-architecture-adr/`
- Delete `skills/docs-manage-guides/`
- Delete `skills/docs-manage-standards/`
- Delete `skills/docs-manage-generic/`

**6.2 Remove old operation skills**
- Delete `skills/doc-generator/` (merged into doc-writer)
- Delete `skills/doc-updater/` (merged into doc-writer)

**6.3 Keep/enhance**
- Enhance `skills/doc-validator/` with type loading
- Keep all `skills/_shared/` utilities

**6.4 Delete old commands**
- Delete all type-specific commands (manage-api.md, manage-dataset.md, etc.)

### Phase 7: Testing (2 days)

**7.1 Test context preservation**
- Rich conversation → /fractary-docs:write
- Verify conversational details captured
- Test context merging

**7.2 Test context passing**
- Simple --context parameter
- Director context distribution
- Multi-source context merging

**7.3 Test auto-validation**
- Verify validation runs after write
- Check error reporting

**7.4 Test auto-indexing**
- Verify docs/{doc_type}/README.md updated
- Test hierarchical organization
- Test flat organization
- Check index templates applied

**7.5 Test doc_type auto-detection**
- Path-based detection
- Content analysis fallback
- Confidence scoring

**7.6 Test multi-doc operations**
- Pattern expansion
- Director orchestration
- Parallel execution
- Context distribution

**7.7 Test all operations**
- write (create + update)
- validate (standalone)
- list (filtering)
- audit (health assessment)

### Phase 8: Update Existing Docs (1 day)

**8.1 Add fractary_doc_type to frontmatter**
- Scan existing docs in docs/ directory
- For each doc, use doc-classifier to determine type
- Add `fractary_doc_type: {type}` to frontmatter
- Create bulk update script

**8.2 Generate indices**
- Run doc-writer on sample docs to trigger index generation
- Verify all `docs/{doc_type}/README.md` files created
- Check index organization matches config

### Phase 9: Documentation (1 day)

**9.1 Update plugin documentation**
- README.md with new architecture explanation
- Command reference with examples
- Migration guide for users
- Type context structure documentation
- Configuration options documentation

**9.2 Create developer documentation**
- Architecture decision record (ADR)
- Contributing guide for new doc types
- Troubleshooting guide

## Success Metrics

### Quantitative

1. **Code Reduction**
   - Before: ~4,850 lines (11 type-specific skills)
   - After: ~6,100 lines (structured, zero duplication in operation logic)
   - **Duplication eliminated**: 93% (operation logic written once)

2. **Token Efficiency**
   - Before: 15K-40K tokens per operation
   - After: 11K-15K tokens per operation
   - **Reduction**: 40-60% per operation

3. **Component Count**
   - Before: 55 implementations (11 types × 5 operations)
   - After: 16 components (6 skills + 10 type contexts)
   - **Reduction**: 71%

4. **Maintenance Points**
   - Before: Update 11 files for bug fix
   - After: Update 1 file for bug fix
   - **Reduction**: 91%

5. **New Doc Type Cost**
   - Before: 300+ lines (full skill with 5 operations)
   - After: ~400 lines (4 context files, no operation logic)
   - **Reduction**: Limited to type-specific context only

### Qualitative

1. ✅ Context preserved when invoking skill directly
2. ✅ Explicit context passed via --context parameter
3. ✅ Natural language requests parsed correctly
4. ✅ Director orchestrates multi-doc operations
5. ✅ Operation skills handle single-doc only
6. ✅ Write auto-validates and auto-indexes
7. ✅ Each doc_type has own README.md index
8. ✅ Pattern matching works (wildcards expanded)
9. ✅ Parallel execution supported
10. ✅ All old skills removed cleanly
11. ✅ Matches repo/work plugin architectural patterns

## Risks & Mitigations

### Risk 1: Context Merging Complexity
**Risk**: Multiple context sources could conflict or produce unexpected results.
**Mitigation**:
- Clear priority rules (conversational > explicit > file-specific > existing)
- Extensive testing of context merging logic
- Logging of context sources used

### Risk 2: Breaking Existing Workflows
**Risk**: Users accustomed to old commands may be disrupted.
**Mitigation**:
- Comprehensive migration guide
- Test all existing use cases
- Phased rollout if needed

### Risk 3: Performance Regression
**Risk**: New architecture could be slower than old.
**Mitigation**:
- Benchmark before/after
- Optimize context loading
- Leverage shared scripts (already exist)

### Risk 4: Index Corruption
**Risk**: Auto-indexing could corrupt existing indices.
**Mitigation**:
- Backup indices before updates
- Extensive testing of index-updater.sh
- Validate index structure after updates

### Risk 5: Parallel Execution Failures
**Risk**: Parallel manager instances could interfere with each other.
**Mitigation**:
- File locking for index updates
- Error handling for concurrent writes
- Configurable max concurrent limit

## Dependencies

### Internal
- fractary-work plugin (for issue data if needed)
- Shared scripts (_shared/lib/)
- Existing templates (migration source)

### External
- None

## Timeline

**Total Estimated Effort**: 18 days

| Phase | Days | Description |
|-------|------|-------------|
| 1 | 4 | Create skill infrastructure (director, manager, agent) |
| 2 | 3 | Create operation skills (writer, validator, classifier, lister, auditor) |
| 3 | 3 | Extract type context from existing skills |
| 4 | 1 | Update shared scripts (index-updater.sh) |
| 5 | 2 | Create commands with smart routing |
| 6 | 1 | Delete old skills and commands |
| 7 | 2 | Testing (all scenarios) |
| 8 | 1 | Update existing docs with fractary_doc_type |
| 9 | 1 | Documentation |

## Acceptance Criteria

- [ ] docs-director-skill handles pattern matching and multi-doc orchestration
- [ ] docs-manager-skill orchestrates single-doc workflows
- [ ] docs-manager agent is thin wrapper delegating to skill
- [ ] doc-writer merges CREATE and UPDATE, embeds validation and indexing
- [ ] doc-validator provides standalone validation
- [ ] doc-classifier auto-detects doc_type from path and content
- [ ] doc-lister scans and filters documentation
- [ ] doc-auditor assesses health and generates improvement plans
- [ ] All type context extracted (10 types + _untyped)
- [ ] index-config.json created for each type
- [ ] index-updater.sh enhanced to read index-config.json
- [ ] Commands route intelligently based on context
- [ ] --context parameter works for explicit context passing
- [ ] Conversational context preserved with skill direct invocation
- [ ] Multi-doc operations work with director
- [ ] Parallel execution supported
- [ ] Auto-validation works (write always validates)
- [ ] Auto-indexing works (write always updates index)
- [ ] Each doc_type has own README.md index
- [ ] All old skills removed
- [ ] All old commands removed
- [ ] Existing docs updated with fractary_doc_type
- [ ] Documentation complete (README, migration guide, developer docs)
- [ ] All tests pass
- [ ] Token usage reduced by ~50%

## References

- [CLAUDE.md](../../CLAUDE.md) - 3-layer architecture pattern
- [fractary-repo plugin](../../plugins/repo/) - Multi-item operation pattern
- [fractary-work plugin](../../plugins/work/) - Director pattern reference
- [Conversation 2025-01-15](../../conversations/2025-01-15-docs-plugin-refactor.md) - Architecture discussion

## Appendices

### Appendix A: Type Context Extraction Example

**From** (docs-manage-api/SKILL.md):
```markdown
<CRITICAL_RULES>
- ALWAYS follow OpenAPI 3.0 specification
- ALWAYS document all HTTP methods
- ALWAYS include authentication requirements
- ALWAYS provide request/response examples
</CRITICAL_RULES>
```

**To** (types/api/standards.md):
```markdown
# API Documentation Standards

## Required Conventions
- Follow OpenAPI 3.0 specification
- Document all HTTP methods (GET, POST, PUT, PATCH, DELETE)
- Include authentication requirements
- Provide request/response examples
- Document all error codes (4xx, 5xx)

## Versioning
- Use semantic versioning for API versions
- Deprecate old versions gradually
```

### Appendix B: Index Config Example

**types/api/index-config.json**:
```json
{
  "index_file": "docs/api/README.md",
  "organization": "hierarchical",
  "group_by": ["service", "version"],
  "sort_by": "endpoint",
  "entry_template": "- [**{{method}} {{endpoint}}**]({{relative_path}}) - {{title}}",
  "section_template": "## {{service}} ({{version}})"
}
```

**Generated docs/api/README.md**:
```markdown
# API Documentation

## Authentication Service (v2)
- [**POST /auth/login**](auth-service/v2/login/README.md) - User authentication
- [**POST /auth/refresh**](auth-service/v2/refresh/README.md) - Token refresh

## User Service (v1)
- [**GET /users/{id}**](user-service/v1/get-user/README.md) - Get user by ID
- [**POST /users**](user-service/v1/create-user/README.md) - Create new user
```

### Appendix C: Context Bundle Example

```json
{
  "operation": "write",
  "doc_type": "api",
  "file_path": "docs/api/auth/login/README.md",
  "context": {
    "conversational": {
      "enabled": true,
      "messages": [
        {"role": "user", "content": "We're using OAuth 2.0 with JWT..."},
        {"role": "assistant", "content": "..."},
        {"role": "user", "content": "The login endpoint is POST /auth/login..."}
      ],
      "extracted_facts": {
        "endpoint": "POST /auth/login",
        "auth_type": "OAuth 2.0 + JWT (RS256)",
        "tokens": {
          "access": {"lifetime": "1 hour"},
          "refresh": {"lifetime": "30 days"}
        },
        "rate_limit": "5 req/min",
        "errors": ["401", "429"]
      }
    },
    "explicit": "Add rate limiting documentation: 100 req/min per user",
    "file_specific": {
      "current_endpoint": "POST /auth/login",
      "current_service": "Authentication Service",
      "current_version": "v2"
    },
    "existing_content": {
      "frontmatter": {
        "title": "Login Endpoint",
        "fractary_doc_type": "api",
        "status": "published",
        "version": "1.2.0"
      },
      "sections": ["Overview", "Request", "Response", "Errors"],
      "full_content": "..."
    }
  }
}
```

---

**End of Specification**
