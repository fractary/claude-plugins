# SPEC-0029-05: Doc Templates and Generation

**Issue**: #29
**Phase**: 2 (fractary-docs Plugin)
**Dependencies**: SPEC-0029-04
**Status**: Draft
**Created**: 2025-01-15

## Overview

Implement the doc-generator skill with comprehensive template system for generating documentation. Includes 10+ reusable templates covering common documentation types: ADRs, design docs, runbooks, API specs, test reports, deployment docs, changelogs, and more.

## Requirements

1. **Template Engine**: Mustache or similar for variable substitution
2. **Front Matter Injection**: Automatic codex-compatible metadata
3. **Validation**: Check generated docs match template requirements
4. **File Management**: Save to configured paths, avoid overwrites
5. **Git Integration**: Optional commit after generation

## Template Details

### ADR Template (adr.md.template)
```markdown
---
title: "ADR-{{number}}: {{title}}"
type: adr
status: {{status}}
date: {{date}}
author: {{author}}
tags: {{#tags}}[{{.}}]{{/tags}}
codex_sync: true
---

# ADR-{{number}}: {{title}}

**Status**: {{status}}
**Date**: {{date}}
**Deciders**: {{deciders}}

## Context

{{context}}

## Decision

{{decision}}

## Consequences

### Positive
{{#consequences.positive}}
- {{.}}
{{/consequences.positive}}

### Negative
{{#consequences.negative}}
- {{.}}
{{/consequences.negative}}

## Alternatives Considered

{{#alternatives}}
### {{name}}
{{description}}

**Pros**:
{{#pros}}
- {{.}}
{{/pros}}

**Cons**:
{{#cons}}
- {{.}}
{{/cons}}

**Rejected because**: {{rejection_reason}}

{{/alternatives}}

## References

{{#references}}
- [{{title}}]({{url}})
{{/references}}
```

### Other Templates (Summary)

2. **design.md.template**: System/feature design
3. **runbook.md.template**: Operational procedures
4. **api-spec.md.template**: API documentation
5. **test-report.md.template**: Test results
6. **deployment.md.template**: Deployment records
7. **changelog.md.template**: Version changes
8. **architecture.md.template**: System architecture
9. **troubleshooting.md.template**: Debug guides
10. **postmortem.md.template**: Incident reviews

## Implementation

### Scripts

**generate-from-template.sh**: Core generation logic
**add-frontmatter.sh**: Inject codex metadata
**render-template.sh**: Mustache rendering
**validate-output.sh**: Check generated doc

### Workflow

**workflow/generate-adr.md**: Step-by-step ADR creation guide
**workflow/generate-design-doc.md**: Design doc creation

## Success Criteria

- [ ] 10+ templates implemented
- [ ] Generation scripts working
- [ ] Front matter injection automatic
- [ ] Validation after generation
- [ ] Documentation for all templates

## Timeline

**Estimated**: 1 week

## Next Steps

- **SPEC-0029-06**: doc-updater skill
