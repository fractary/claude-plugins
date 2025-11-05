# SPEC-0029-06: Doc Updater Skill

**Issue**: #29
**Phase**: 2 (fractary-docs Plugin)
**Dependencies**: SPEC-0029-04, SPEC-0029-05
**Status**: Draft
**Created**: 2025-01-15

## Overview

Implement the doc-updater skill for modifying existing documentation while preserving structure, formatting, and non-targeted content. This addresses the common need to update docs as requirements change, without regenerating from scratch.

## Key Capabilities

1. **Section Updates**: Update specific sections (## headings) in markdown
2. **Content Append**: Add new sections without disrupting existing content
3. **Metadata Updates**: Modify front matter while preserving doc body
4. **Smart Merging**: Preserve formatting, code blocks, lists
5. **TOC Regeneration**: Auto-update table of contents

## Operations

### update-section
Update specific section by heading match:
```bash
update-section <doc_path> <section_heading> <new_content>
```

### append-section
Add new section at appropriate location:
```bash
append-section <doc_path> <section_heading> <content> [after_section]
```

### update-metadata
Modify front matter fields:
```bash
update-metadata <doc_path> <field> <value>
```

### replace-content
Pattern-based replacement:
```bash
replace-content <doc_path> <pattern> <replacement>
```

## Implementation

### Parsing Strategy
1. Parse markdown into AST (headings, sections, code blocks)
2. Identify target section
3. Replace content while preserving structure
4. Regenerate document

### Preservation Rules
- Keep existing front matter not being updated
- Preserve code block syntax (```language)
- Maintain list formatting (ordered/unordered)
- Keep inline links and formatting

## Use Cases

1. **Requirements Change**: Update API spec when endpoint changes
2. **Architecture Evolution**: Update design doc with new components
3. **Status Updates**: Change ADR status from "proposed" to "accepted"
4. **Progressive Enhancement**: Add sections as features develop

## Success Criteria

- [ ] Section update without affecting other sections
- [ ] Metadata update preserves document body
- [ ] Formatting preserved after update
- [ ] Validation after each update
- [ ] Git-friendly diffs (minimal changes)

## Timeline

**Estimated**: 1 week

## Next Steps

- **SPEC-0029-07**: Validation and linking skills
