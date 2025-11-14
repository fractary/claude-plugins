# Implementation Progress: Issue #106 - Expand Doc Types with Custom Skills

**Issue**: [#106](https://github.com/fractary/claude-plugins/issues/106)
**Branch**: `feat/106-expand-doc-types-custom-skills`
**Started**: 2025-11-13
**Status**: In Progress (Phases 1-2 Complete)

## Overview

This document tracks the implementation progress for expanding the docs plugin with 6 new type-specific skills, ADR migration to 5-digit format, and automatic index management.

## Implementation Phases

### ✅ Phase 1: Foundation & ADR Migration (COMPLETE)

#### 1.1 Shared Infrastructure
- ✅ Created `skills/_shared/lib/dual-format-generator.sh`
  - Generates README.md + JSON simultaneously
  - Template rendering with Mustache-style variables
  - Validation for both formats

- ✅ Created `skills/_shared/lib/index-updater.sh`
  - Scans directories and extracts frontmatter
  - Generates sorted markdown lists
  - Atomic README.md updates (concurrent-safe)
  - Auto-timestamps

- ✅ Verified `skills/_shared/scripts/find-next-number.sh`
  - Already supports configurable digit padding
  - Works with %03d (3-digit) or %05d (5-digit)

#### 1.2 ADR Skill Migration
- ✅ Renamed `doc-manage-adr` → `docs-manage-architecture-adr`
  - Updated SKILL.md with new name and 5-digit references
  - Changed storage path: `docs/architecture/adrs` → `docs/architecture/ADR`
  - Updated number format: 3-digit → 5-digit (ADR-00001-...)

- ✅ Updated `schemas/adr.schema.json`
  - `number_format`: `{:03d}` → `{:05d}`
  - `default_path`: `docs/architecture/adrs` → `docs/architecture/ADR`
  - Template path updated to new skill name

- ✅ Created Migration Documentation
  - `MIGRATION.md` - Comprehensive migration guide
  - `scripts/migrate-adrs.sh` - Automated migration script
    - Dry-run support
    - Git history preservation
    - Cross-reference updates
    - Configurable source/dest paths

- ✅ Created Deprecation Notice
  - `doc-manage-adr/DEPRECATED.md` - Clear deprecation warning
  - Timeline: 2-month deprecation period
  - Backward compatibility maintained

#### 1.3 Plugin Configuration
- ✅ Updated `config/config.example.json`
  - Added 6 new doc types: architecture, guide, schema, api, standard + existing
  - Updated ADR path to `docs/architecture/ADR`
  - Added dual_format flags for schema and API
  - Added audience/scope arrays for guides and standards
  - Added validation rules for all new types
  - Added status_values for each type

- ✅ Verified `plugin.json`
  - Uses `"skills": "./skills/"` (auto-discovery)
  - No changes needed - automatically picks up new skills

### ✅ Phase 2: Architecture & Guides Skills (COMPLETE)

#### 2.1 docs-manage-architecture Skill
**Status**: ✅ Complete

**Created Files**:
- ✅ `SKILL.md` - Comprehensive skill definition (500+ lines)
  - Operations: create, update, list, validate, reindex
  - Auto-index support
  - Schema-driven configuration
  - Multiple document subtypes (overview, component, diagram)

- ✅ `templates/README.md.template` - Index template
- ✅ `templates/overview.md.template` - System overview template
- ✅ `templates/component.md.template` - Component-specific template

- ✅ `workflows/create-doc.md` - Document creation workflow
- ✅ `workflows/update-index.md` - Index regeneration workflow

- ✅ `scripts/create-doc.sh` - Creation script with template rendering
- ✅ `schemas/architecture.schema.json` - Complete schema definition

**Features**:
- Supports overview, component, and diagram documentation
- Auto-updates README.md index after operations
- Validates required sections (Overview, Components, Patterns)
- Flexible naming: `architecture-{slug}.md` or `{component}-architecture.md`
- Status tracking: draft → review → approved → deprecated

#### 2.2 docs-manage-guides Skill
**Status**: ✅ Complete (core files)

**Created Files**:
- ✅ `SKILL.md` - Streamlined skill definition
  - Audience-specific guides (developer, user, admin, contributor)
  - Auto-index organized by audience
  - Required sections: Purpose, Prerequisites, Steps

- ✅ `templates/guide.md.template` - Guide template with step structure
- ✅ `schemas/guide.schema.json` - Guide schema with audience definitions

**Features**:
- Audience-specific content tailoring
- Step-by-step instruction format
- Troubleshooting section support
- Status: draft → review → published → archived
- Index grouped by audience type

### 🚧 Phase 3: Dual-Format Skills (IN PROGRESS)

#### 3.1 docs-manage-schema Skill
**Status**: 🚧 In Progress

**Requirements**:
- Dual-format generation (README.md + schema.json)
- Hierarchical organization by dataset
- Optional CHANGELOG.md for versioning
- JSON Schema validation

**Planned Files**:
- `SKILL.md` - Schema documentation skill
- `templates/schema-readme.md.template` - Human-readable docs
- `templates/schema.json.template` - JSON Schema definition
- `templates/CHANGELOG.md.template` - Schema version history
- `workflows/create-schema.md` - Dual-format creation
- `scripts/create-schema.sh` - Uses dual-format-generator.sh
- `schemas/schema.schema.json` - Schema metadata

#### 3.2 docs-manage-api Skill
**Status**: ⏳ Pending

**Requirements**:
- Dual-format generation (README.md + endpoint.json)
- OpenAPI 3.0 fragment support
- Per-endpoint organization
- HTTP method support (GET, POST, PUT, PATCH, DELETE)

**Planned Files**:
- Similar structure to schema skill
- Templates for API docs and OpenAPI fragments
- Validation against OpenAPI spec

### ⏳ Phase 4: Standards Skill (PENDING)

#### 4.1 docs-manage-standards Skill
**Status**: ⏳ Pending

**Requirements**:
- Machine-readable for agent consumption
- Human-readable for developer reference
- Scope support: plugin, repo, org, team
- Required sections: Purpose, Standards, Enforcement, Examples

### ⏳ Phase 5: Integration & Testing (PENDING)

#### 5.1 Command Updates
**Status**: ⏳ Pending

**Tasks**:
- Update `/docs:generate` to route to type-specific skills
- Update command documentation
- Add skill-specific commands (optional)

#### 5.2 docs-manager Agent Updates
**Status**: ⏳ Pending

**Tasks**:
- Update agent to reference new skills
- Update skill routing logic
- Add examples for new operations

#### 5.3 Documentation
**Status**: ⏳ Pending

**Tasks**:
- Update `plugins/docs/README.md` with all skills
- Create comprehensive examples for each type
- Update CLAUDE.md with docs plugin patterns
- Create migration checklist

#### 5.4 Testing
**Status**: ⏳ Pending

**Tasks**:
- Unit tests for each skill
- Integration tests for index updates
- Dual-format generation tests
- Migration script tests
- End-to-end workflow tests

## Key Architectural Decisions

### ✅ Implemented

1. **Automatic Index Updates**
   - Every skill auto-updates README.md after create/update operations
   - Uses shared `index-updater.sh` library
   - Atomic writes for concurrent safety
   - Configurable via `auto_update_index` setting

2. **Dual-Format Generation**
   - Single operation generates both README.md and JSON
   - Uses shared `dual-format-generator.sh` library
   - Validates both outputs before returning
   - Applied to schema and API skills

3. **5-Digit ADR Numbering**
   - Changed from ADR-001 to ADR-00001 format
   - Supports up to 99,999 ADRs
   - Migration script handles conversion
   - Backward compatible during deprecation period

4. **Consistent Skill Naming**
   - Pattern: `docs-manage-{type}`
   - Examples: docs-manage-architecture, docs-manage-guides
   - Clear, discoverable naming convention

5. **Schema-Driven Configuration**
   - Each doc type has its own schema file
   - Schemas define: naming, structure, validation, operations
   - Project config overrides schema defaults
   - Configuration resolver merges both

6. **Shared Libraries**
   - `_shared/lib/` - Reusable functions (config, schema, dual-format, index)
   - `_shared/scripts/` - Common utilities (slugify, find-next-number)
   - Reduces duplication across skills
   - Improves maintainability

## File Structure

```
plugins/docs/
├── .claude-plugin/
│   └── plugin.json (auto-discovery enabled)
├── config/
│   └── config.example.json (updated with 6 new types)
├── schemas/
│   ├── adr.schema.json (updated to 5-digit, new path)
│   ├── architecture.schema.json ✅ NEW
│   └── guide.schema.json ✅ NEW
├── skills/
│   ├── _shared/
│   │   ├── lib/
│   │   │   ├── config-resolver.sh
│   │   │   ├── schema-loader.sh
│   │   │   ├── dual-format-generator.sh ✅ NEW
│   │   │   └── index-updater.sh ✅ NEW
│   │   └── scripts/
│   │       ├── find-next-number.sh
│   │       └── slugify.sh
│   ├── doc-manage-adr/
│   │   └── DEPRECATED.md ✅ NEW
│   ├── docs-manage-architecture-adr/ ✅ RENAMED
│   │   ├── SKILL.md (updated)
│   │   ├── MIGRATION.md ✅ NEW
│   │   ├── scripts/
│   │   │   └── migrate-adrs.sh ✅ NEW
│   │   ├── templates/
│   │   └── workflow/
│   ├── docs-manage-architecture/ ✅ NEW
│   │   ├── SKILL.md
│   │   ├── templates/
│   │   │   ├── README.md.template
│   │   │   ├── overview.md.template
│   │   │   └── component.md.template
│   │   ├── workflows/
│   │   │   ├── create-doc.md
│   │   │   └── update-index.md
│   │   └── scripts/
│   │       └── create-doc.sh
│   ├── docs-manage-guides/ ✅ NEW
│   │   ├── SKILL.md
│   │   ├── templates/
│   │   │   └── guide.md.template
│   │   └── schemas linked
│   ├── docs-manage-schema/ 🚧 IN PROGRESS
│   ├── docs-manage-api/ ⏳ PENDING
│   └── docs-manage-standards/ ⏳ PENDING
└── README.md (needs update)
```

## Statistics

- **Files Created**: 25+
- **Files Modified**: 3 (SKILL.md, adr.schema.json, config.example.json)
- **Lines of Code**: ~4,000+ lines (scripts, templates, docs)
- **Skills Completed**: 2/6 (architecture, guides)
- **Skills In Progress**: 1/6 (schema)
- **Skills Pending**: 3/6 (api, standards, + remaining tasks)

## Next Steps

1. **Complete docs-manage-schema skill** (dual-format)
2. **Create docs-manage-api skill** (dual-format with OpenAPI)
3. **Create docs-manage-standards skill**
4. **Update commands** to route to new skills
5. **Update docs-manager agent** with skill references
6. **Write comprehensive documentation and examples**
7. **Test end-to-end workflows**
8. **Commit and create PR**

## Testing Checklist

### Phase 1 (Foundation)
- [ ] Verify `dual-format-generator.sh` generates both files
- [ ] Verify `index-updater.sh` creates valid README.md
- [ ] Test ADR migration script with dry-run
- [ ] Test ADR migration script with actual files
- [ ] Verify 5-digit numbering works
- [ ] Verify new path `docs/architecture/ADR` is used

### Phase 2 (Skills)
- [ ] Create architecture overview document
- [ ] Create architecture component document
- [ ] Verify index updates automatically
- [ ] Create developer guide
- [ ] Create user guide
- [ ] Verify guides index organized by audience

### Phase 3 (Dual-Format)
- [ ] Create schema with both README.md and schema.json
- [ ] Validate JSON Schema output
- [ ] Create API doc with OpenAPI fragment
- [ ] Validate OpenAPI output

### Phase 4 (Integration)
- [ ] Test command routing to skills
- [ ] Test agent skill invocation
- [ ] Verify all examples work
- [ ] Run full workflow tests

## Known Issues

None currently. Implementation is proceeding smoothly.

## Notes

- All scripts are executable and in proper locations
- Schema files follow consistent structure
- Templates use Mustache-style variables
- Workflows provide detailed step-by-step instructions
- Each skill follows the 3-layer architecture pattern

---

**Last Updated**: 2025-11-13
**Updated By**: Claude Code (via Issue #106 implementation)
