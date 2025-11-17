---
spec_id: SPEC-00106-expand-doc-types-custom-skills
issue_number: 106
issue_url: https://github.com/fractary/claude-plugins/issues/106
title: expand doc types with custom skills in docs plugin
type: feature
status: draft
created: 2025-11-13
author: jmcwilliam
validated: false
---

# Feature Specification: expand doc types with custom skills in docs plugin

**Issue**: [#106](https://github.com/fractary/claude-plugins/issues/106)
**Type**: Feature
**Status**: Draft
**Created**: 2025-11-13

## Summary

Enhance the docs plugin to include specialized skills for managing different types of documentation. Each skill will handle a specific document type with its own templates, guidelines, validation checklists, and directory structure. Skills will maintain README.md files as indices and automatically update them when sub-documents are created.

## User Stories

### Documentation Type Management
**As a** developer working on the plugin ecosystem
**I want** dedicated skills for each documentation type
**So that** documentation is consistently structured and automatically maintained across all plugins

**Acceptance Criteria**:
- [ ] Each documentation type has its own skill
- [ ] Each skill follows the same pattern for structure and maintenance
- [ ] Skills automatically update index files when new documents are created
- [ ] Each skill has templates and validation checklists
- [ ] Documentation is organized in standardized directory structures

### Architecture Documentation
**As a** developer or architect
**I want** architecture documentation to be easily maintainable
**So that** system design decisions are well-documented and discoverable

**Acceptance Criteria**:
- [ ] Architecture documents stored in `/docs/architecture/`
- [ ] README.md provides overview/index of architecture docs
- [ ] Support for ADRs with sequential numbering (ADR-00000-title.md)
- [ ] ADR index maintained automatically

### Standards and Guidelines
**As a** developer or AI agent
**I want** standards documents to be centrally managed
**So that** implementation adheres to consistent patterns and best practices

**Acceptance Criteria**:
- [ ] Standards stored in `/docs/standards/`
- [ ] Machine-readable for agent consumption
- [ ] Human-readable for developer reference
- [ ] Index automatically maintained

### API Documentation
**As a** API consumer or developer
**I want** both human and machine-readable API documentation
**So that** I can understand and integrate with APIs effectively

**Acceptance Criteria**:
- [ ] Both README.md (human) and .json (machine) formats
- [ ] Organized by endpoint
- [ ] Index maintained automatically

### Schema Documentation
**As a** data engineer or developer
**I want** structured data schema documentation
**So that** data structures are well-defined and validated

**Acceptance Criteria**:
- [ ] README.md for human consumption
- [ ] schema.json for machine consumption
- [ ] Hierarchical organization by dataset
- [ ] Optional data-specific changelog

## Functional Requirements

- **FR1**: Create `docs-manage-architecture` skill for system architecture documentation in `/docs/architecture/`
- **FR2**: Rename existing `doc-manage-adr` to `docs-manage-architecture-adr` for Architecture Decision Records in `/docs/architecture/ADR/` with format `ADR-00000-title.md`
- **FR3**: Create `docs-manage-guides` skill for user guides in `/docs/guides/`
- **FR4**: Create `docs-manage-schema` skill for data schema documentation in `/docs/schema/` with both README.md and schema.json
- **FR5**: Create `docs-manage-api` skill for API documentation with README.md and .json files per endpoint
- **FR6**: Create `docs-manage-standards` skill for standards documentation in `/docs/standards/`
- **FR7**: Each skill maintains a README.md index in its directory
- **FR8**: Skills automatically update README.md when sub-documents are created
- **FR9**: Each skill has its own template structure
- **FR10**: Each skill has guidelines and validation checklists
- **FR11**: Skills maintain data-specific changelogs where relevant (e.g., schema changes)

## Non-Functional Requirements

- **NFR1**: Consistency - All skills follow the same architectural pattern (template, guidelines, validation)
- **NFR2**: Automation - Index files update automatically without manual intervention
- **NFR3**: Maintainability - Skills are independently maintainable and testable
- **NFR4**: Discoverability - README.md files provide clear navigation and overview
- **NFR5**: Dual-format support - Critical documentation types provide both human and machine-readable formats

## Technical Design

### Architecture Changes

The docs plugin will expand from a single monolithic skill to a suite of specialized skills:

**Current Structure**:
```
plugins/docs/
└── skills/
    └── doc-manage-adr/  (single skill)
```

**New Structure**:
```
plugins/docs/
└── skills/
    ├── docs-manage-architecture/
    ├── docs-manage-architecture-adr/  (renamed from doc-manage-adr)
    ├── docs-manage-guides/
    ├── docs-manage-schema/
    ├── docs-manage-api/
    └── docs-manage-standards/
```

Each skill follows the standard plugin skill structure:
```
skills/{skill-name}/
├── SKILL.md                    # Skill definition
├── templates/                  # Document templates
│   ├── README.md.template
│   └── {type}-specific.template
├── workflows/                  # Multi-step workflows
└── scripts/                    # Automation scripts
    ├── create-doc.sh
    ├── update-index.sh
    └── validate.sh
```

### Data Model

**README Index Structure** (all types):
```markdown
# {Type} Documentation

## Overview
Brief description of this documentation type

## Documents
- [{Document Name}](./{path}.md) - Brief description
- [{Document Name}](./{path}.md) - Brief description

## Contributing
Guidelines for adding new documents
```

**ADR Format**:
```
Filename: ADR-{5-digit}-{kebab-case-title}.md
Location: /docs/architecture/ADR/
Index: /docs/architecture/ADR/README.md
```

**Schema Format**:
```
Directory structure:
/docs/schema/{dataset}/
  ├── README.md          # Human-readable
  ├── schema.json        # Machine-readable
  └── CHANGELOG.md       # Optional data changelog
```

**API Format**:
```
Directory structure:
/docs/api/{endpoint}/
  ├── README.md          # Human-readable
  └── endpoint.json      # Machine-readable (OpenAPI fragment)
```

### API Design

Skills are invoked via commands:
```bash
/docs:architecture create "{title}" --type overview|diagram|component
/docs:architecture-adr create "{title}" --decision "{decision}"
/docs:guides create "{title}" --audience developer|user|admin
/docs:schema create "{dataset}" --format table|json|proto
/docs:api create "{endpoint}" --method GET|POST|PUT|DELETE
/docs:standards create "{title}" --scope plugin|repo|org
```

Each skill provides operations:
- `create` - Create new document with template
- `update` - Update existing document
- `list` - List all documents of this type
- `validate` - Validate document structure
- `reindex` - Regenerate README.md index

### UI/UX Changes

N/A - CLI interface only

## Implementation Plan

### Phase 1: Core Infrastructure
Establish the common patterns and refactor existing ADR skill

**Tasks**:
- [ ] Design common skill template structure
- [ ] Create base templates for README.md indices
- [ ] Develop index update automation pattern
- [ ] Rename `doc-manage-adr` to `docs-manage-architecture-adr`
- [ ] Update ADR skill to follow new pattern
- [ ] Test ADR skill with new structure

### Phase 2: Architecture Documentation
Implement architecture and guides skills

**Tasks**:
- [ ] Create `docs-manage-architecture` skill
- [ ] Implement architecture templates (overview, diagrams, components)
- [ ] Create architecture README.md index template
- [ ] Implement index automation for architecture docs
- [ ] Create `docs-manage-guides` skill
- [ ] Implement guide templates (developer, user, admin)
- [ ] Create guides README.md index template
- [ ] Test both skills

### Phase 3: Data and API Documentation
Implement schema and API skills with dual-format support

**Tasks**:
- [ ] Create `docs-manage-schema` skill
- [ ] Implement schema templates (README + schema.json)
- [ ] Implement schema validation
- [ ] Add optional changelog support
- [ ] Create `docs-manage-api` skill
- [ ] Implement API templates (README + OpenAPI fragment)
- [ ] Implement API validation against OpenAPI spec
- [ ] Test both skills with dual formats

### Phase 4: Standards Documentation
Implement standards skill for both human and agent consumption

**Tasks**:
- [ ] Create `docs-manage-standards` skill
- [ ] Implement standards templates
- [ ] Ensure machine-readable format for agent consumption
- [ ] Ensure human-readable format for developer reference
- [ ] Add validation for standards documents
- [ ] Test standards skill

### Phase 5: Integration and Testing
Integrate all skills and perform end-to-end testing

**Tasks**:
- [ ] Update plugin.json manifest with all skills
- [ ] Update plugin README.md with skill documentation
- [ ] Create comprehensive examples for each skill
- [ ] Perform end-to-end testing across all skills
- [ ] Document usage patterns and best practices
- [ ] Update CLAUDE.md with docs plugin patterns

## Files to Create/Modify

### New Files
- `plugins/docs/skills/docs-manage-architecture/SKILL.md`: Architecture documentation skill definition
- `plugins/docs/skills/docs-manage-architecture/templates/README.md.template`: Architecture index template
- `plugins/docs/skills/docs-manage-architecture/templates/overview.md.template`: Architecture overview template
- `plugins/docs/skills/docs-manage-architecture/workflows/create-doc.md`: Architecture doc creation workflow
- `plugins/docs/skills/docs-manage-architecture/scripts/update-index.sh`: Index automation script
- `plugins/docs/skills/docs-manage-guides/SKILL.md`: Guides skill definition
- `plugins/docs/skills/docs-manage-guides/templates/README.md.template`: Guides index template
- `plugins/docs/skills/docs-manage-guides/templates/guide.md.template`: Guide template
- `plugins/docs/skills/docs-manage-schema/SKILL.md`: Schema documentation skill definition
- `plugins/docs/skills/docs-manage-schema/templates/README.md.template`: Schema README template
- `plugins/docs/skills/docs-manage-schema/templates/schema.json.template`: JSON schema template
- `plugins/docs/skills/docs-manage-schema/workflows/create-schema.md`: Schema creation workflow
- `plugins/docs/skills/docs-manage-api/SKILL.md`: API documentation skill definition
- `plugins/docs/skills/docs-manage-api/templates/README.md.template`: API README template
- `plugins/docs/skills/docs-manage-api/templates/endpoint.json.template`: OpenAPI fragment template
- `plugins/docs/skills/docs-manage-api/workflows/create-api-doc.md`: API doc creation workflow
- `plugins/docs/skills/docs-manage-standards/SKILL.md`: Standards skill definition
- `plugins/docs/skills/docs-manage-standards/templates/standard.md.template`: Standards template
- `plugins/docs/skills/docs-manage-standards/templates/README.md.template`: Standards index template

### Modified Files
- `plugins/docs/skills/doc-manage-adr/`: Rename directory to `docs-manage-architecture-adr/`
- `plugins/docs/skills/docs-manage-architecture-adr/SKILL.md`: Update skill name references
- `plugins/docs/.claude-plugin/plugin.json`: Add all new skills to manifest
- `plugins/docs/README.md`: Document all skills and their usage
- `CLAUDE.md`: Add docs plugin patterns and examples

## Testing Strategy

### Unit Tests
- Each skill's template rendering
- Index update logic
- Filename generation and validation
- Sequential numbering (ADR)

### Integration Tests
- Create document → verify index updates
- Create multiple documents → verify index maintains order
- Create nested schemas → verify hierarchy
- Create API endpoints → verify dual-format generation

### E2E Tests
- Complete workflow: Install plugin → Create docs → Verify structure
- Cross-skill integration: Create architecture → Reference from guide
- Index integrity: Create/delete/update documents → Verify index accuracy

### Performance Tests
- Index update time with 100+ documents
- Concurrent document creation
- Large schema file handling

## Dependencies

- Existing `doc-manage-adr` skill (for rename/refactor)
- Bash scripting for automation
- JSON parsing tools (jq) for schema validation
- Markdown linting tools (optional, for validation)

## Risks and Mitigations

- **Risk**: Breaking changes to existing ADR skill when renaming
  - **Likelihood**: Medium
  - **Impact**: High
  - **Mitigation**: Provide migration guide, maintain backward compatibility with alias, thorough testing

- **Risk**: Index update failures due to concurrent modifications
  - **Likelihood**: Low
  - **Impact**: Medium
  - **Mitigation**: Implement file locking or atomic updates, add retry logic

- **Risk**: Schema validation complexity for diverse data types
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Use JSON Schema standard, provide schema.json examples, make validation optional

- **Risk**: Inconsistent patterns across different skills
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Create common base templates and shared scripts, document patterns clearly

## Documentation Updates

- `plugins/docs/README.md`: Complete rewrite documenting all skills
- `CLAUDE.md`: Add docs plugin section with usage examples
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`: Add docs plugin as reference implementation
- Each skill's SKILL.md: Comprehensive usage documentation

## Rollout Plan

1. **Phase 1** (Week 1): Core infrastructure + ADR rename
2. **Phase 2** (Week 2): Architecture and guides skills
3. **Phase 3** (Week 3): Schema and API skills
4. **Phase 4** (Week 4): Standards skill
5. **Phase 5** (Week 5): Integration, testing, documentation

**Backward Compatibility**:
- Maintain `doc-manage-adr` as deprecated alias pointing to `docs-manage-architecture-adr`
- Add migration guide for existing users
- Update all references in existing docs

**Communication**:
- Announce rename in CHANGELOG.md
- Update all example commands in documentation
- Provide migration checklist

## Success Metrics

- **Adoption**: All 6 skills implemented and tested
- **Consistency**: 100% of skills follow common pattern
- **Automation**: Index files auto-update in <1 second
- **Coverage**: Each skill has templates, workflows, and validation
- **Documentation**: Each skill documented with examples
- **Quality**: Zero index corruption or inconsistencies in testing

## Implementation Notes

### Key Design Decisions

1. **Skill naming convention**: Use `docs-manage-{type}` pattern for all skills to maintain consistency and clarity

2. **Index automation**: Each skill should check and update its README.md as the final step of document creation

3. **Template variables**: Use consistent variable names across templates:
   - `{{title}}` - Document title
   - `{{date}}` - Creation date
   - `{{author}}` - Author name
   - `{{type}}` - Document type
   - `{{description}}` - Brief description

4. **Dual-format support**: Schema and API documentation require both:
   - README.md: Human-readable overview, usage examples, context
   - {format}.json: Machine-readable structure, validation, automation

5. **Validation approach**: Each skill should validate:
   - Filename format
   - Required sections present
   - Template variables filled
   - Index consistency

### Migration Path for ADR

The existing `doc-manage-adr` skill should be renamed following these steps:
1. Copy `doc-manage-adr/` to `docs-manage-architecture-adr/`
2. Update all internal references to new name
3. Keep old directory as deprecated alias with warning
4. Update plugin.json to reference new name
5. Add migration notice to plugin README

### Extension Points

Future enhancements could include:
- `docs-manage-troubleshooting` - Troubleshooting guides and FAQs
- `docs-manage-changelog` - Structured changelog management
- `docs-manage-runbook` - Operational runbooks
- `docs-manage-rfc` - Request for Comments documents
