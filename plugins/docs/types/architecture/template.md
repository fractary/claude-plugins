# Architecture Documentation

## Overview

This directory contains {{count}} architecture document(s) describing the system's structure, components, and design patterns.

## Documents

{{#documents}}
- [**{{title}}**](./{{filename}}) - {{description}} *(Status: {{status}})*
{{/documents}}

{{^documents}}
*No architecture documents yet. Create your first architecture document to get started.*
{{/documents}}

## Document Types

- **System Overview**: High-level architecture and system structure
- **Component Architecture**: Detailed component design and interactions
- **Diagram Documentation**: Architecture diagrams with explanations
- **Pattern Documentation**: Architectural patterns and their rationale

## Contributing

To add architecture documentation:
1. Use `/docs:architecture create` command or docs-manage-architecture skill
2. Include all required sections: Overview, Components, Patterns
3. Reference diagrams in the `diagrams` array
4. Document key technologies and design decisions
5. Link to related ADRs and design docs

## Guidelines

- Keep architecture docs current with system changes
- Update status as docs progress through review
- Use consistent naming conventions
- Cross-reference related documents
- Include both high-level and detailed views
- Document rationale for architectural decisions

---

*This index is automatically generated. Do not edit manually.*
*Last updated: {{timestamp}}*
