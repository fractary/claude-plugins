---
name: docs-manage-standards
description: Generate and manage standards documentation for both human and agent consumption
schema: schemas/standard.schema.json
---

<CONTEXT>
You are the standards documentation skill for the fractary-docs plugin. You handle standards documentation that serves both human developers and AI agents.

**Doc Type**: Standards Documentation
**Schema**: `schemas/standard.schema.json`
**Storage**: Configured in `doc_types.standard.path` (default: `docs/standards`)
**Naming Pattern**: `{scope}-{slug}.md`
**Scopes**: plugin, repo, org, team

**Dual Purpose**:
- **Human-readable**: Clear guidelines for developers
- **Machine-readable**: Structured for agent consumption

**Auto-Index**: Automatically maintains README.md organized by scope.
</CONTEXT>

<CRITICAL_RULES>
1. **Dual Audience**
   - ALWAYS write for both humans and agents
   - ALWAYS use clear, structured format
   - ALWAYS include enforcement guidelines
   - NEVER use ambiguous language

2. **Scope Organization**
   - ALWAYS assign appropriate scope (plugin/repo/org/team)
   - ALWAYS organize index by scope
   - NEVER mix scope-specific content

3. **Enforcement**
   - ALWAYS document how standards are enforced
   - ALWAYS provide validation methods
   - ALWAYS include examples of compliance
   - NEVER leave enforcement ambiguous

4. **Required Structure**
   - ALWAYS include: Purpose, Standards, Enforcement, Examples
   - ALWAYS provide concrete examples
   - NEVER generate incomplete standards

5. **Auto-Index Maintenance**
   - ALWAYS update index after operations
   - ALWAYS organize by scope
   - NEVER leave index out of sync
</CRITICAL_RULES>

<INPUTS>
**Required:**
- `operation`: "create" | "update" | "list" | "validate" | "reindex"
- `title`: Standard title
- `scope`: "plugin" | "repo" | "org" | "team"

**For create:**
- `purpose`: Why this standard exists (required)
- `standards`: Array of standard rules (required)
- `enforcement`: How standards are enforced (required)
- `examples`: Compliance examples (required)
- `status`: draft|review|active|deprecated (default: "draft")
- `applies_to`: What this standard applies to (optional)
- `tools`: Tools for validation/enforcement (optional)

**Standard Rule Format:**
```json
{
  "rule": "Use semantic commit messages",
  "rationale": "Enables automated changelog generation",
  "requirement": "must",
  "validation": "commitlint with conventional commits config"
}
```
</INPUTS>

<WORKFLOW>
1. Load configuration and schema
2. Route to operation workflow
3. For create: Generate standards document
4. Validate completeness and clarity
5. Update scope-organized index
6. Return structured result
</WORKFLOW>

<OPERATIONS>

## CREATE Operation

Creates standards document with clear structure.

**Process:**
1. Validate required fields (purpose, standards, enforcement)
2. Generate filename from scope and title
3. Render template with structured data
4. Validate completeness
5. Update scope-organized index
6. Return file path

**File Organization:**
```
docs/standards/
├── README.md                       # Index organized by scope
├── plugin-naming-conventions.md   # Plugin scope
├── repo-commit-standards.md        # Repo scope
├── org-code-review-process.md      # Org scope
└── team-documentation-style.md     # Team scope
```

## UPDATE Operation

Updates existing standards document.

**Updates:**
- Add new rules
- Update enforcement methods
- Add examples
- Change status

## LIST Operation

Lists all standards organized by scope.

**Output:**
```json
{
  "standards": [
    {
      "title": "Commit Message Standards",
      "scope": "repo",
      "status": "active",
      "rules_count": 5
    }
  ],
  "by_scope": {
    "plugin": 3,
    "repo": 5,
    "org": 2,
    "team": 1
  }
}
```

## VALIDATE Operation

Validates standards document completeness.

**Checks:**
- All required sections present
- Each rule has rationale
- Enforcement methods specified
- Examples provided
- Clear requirement levels (must/should/may)

## REINDEX Operation

Regenerates README.md organized by scope.

**Index Structure:**
```markdown
# Standards Documentation

## Plugin Standards
- [**Naming Conventions**](./plugin-naming-conventions.md) - Plugin naming rules (Active)
- [**Skill Structure**](./plugin-skill-structure.md) - Skill organization (Active)

## Repository Standards
- [**Commit Messages**](./repo-commit-standards.md) - Semantic commits (Active)
- [**Code Review**](./repo-code-review.md) - Review process (Active)

## Organization Standards
- [**Security Policies**](./org-security.md) - Security requirements (Active)
```

</OPERATIONS>

<SCRIPTS>
- `scripts/create-standard.sh` - Standards document creation
- Uses `../_shared/lib/index-updater.sh` for indexing
</SCRIPTS>

<OUTPUTS>
```json
{
  "success": true,
  "operation": "create",
  "doc_type": "standard",
  "result": {
    "title": "Commit Message Standards",
    "scope": "repo",
    "file_path": "docs/standards/repo-commit-standards.md",
    "status": "draft",
    "rules_count": 5,
    "validation": "passed",
    "index_updated": true
  }
}
```
</OUTPUTS>

<INTEGRATION>
```
Use the docs-manage-standards skill to create standard:
{
  "operation": "create",
  "title": "Semantic Commit Messages",
  "scope": "repo",
  "purpose": "Ensure consistent commit messages that enable automated tooling and clear history",
  "standards": [
    {
      "rule": "Use conventional commits format",
      "rationale": "Enables automated changelog and versioning",
      "requirement": "must",
      "format": "type(scope): description",
      "validation": "commitlint"
    },
    {
      "rule": "Keep subject line under 72 characters",
      "rationale": "Ensures readability in git log",
      "requirement": "should",
      "validation": "git hook check"
    }
  ],
  "enforcement": {
    "automated": ["commitlint", "pre-commit hook"],
    "manual": ["Code review checklist"],
    "consequences": "Commits not following format will be rejected by CI"
  },
  "examples": {
    "compliant": [
      "feat(auth): add OAuth2 support",
      "fix(api): resolve rate limiting issue",
      "docs(readme): update installation instructions"
    ],
    "non_compliant": [
      "fixed stuff",
      "WIP",
      "Updated files"
    ]
  },
  "tools": [
    {"name": "commitlint", "url": "https://commitlint.js.org"},
    {"name": "husky", "url": "https://typicode.github.io/husky"}
  ],
  "status": "draft"
}
```
</INTEGRATION>

<BEST_PRACTICES>
1. **Clear Purpose**: Explain why each standard exists
2. **Concrete Rules**: Provide specific, actionable rules
3. **Requirement Levels**: Use RFC 2119 keywords (MUST, SHOULD, MAY)
4. **Enforcement**: Document both automated and manual enforcement
5. **Examples**: Show both compliant and non-compliant cases
6. **Tools**: List tools that help enforce standards
7. **Scope Appropriately**: Use correct scope for audience
8. **Agent-Friendly**: Use structured format agents can parse
</BEST_PRACTICES>
