# /docs:list

List and filter documentation files with metadata.

## Usage

```bash
/docs:list [directory] [--doc-type <type>] [--status <status>] [--format <format>]
```

## Arguments

- `[directory]` - Directory to scan (default: docs/)
- `--doc-type <type>` - Filter by document type
- `--status <status>` - Filter by status (draft, published, deprecated)
- `--format <format>` - Output format: table, json, markdown (default: table)

## Examples

```bash
# List all documentation
/docs:list

# List all API documentation
/docs:list --doc-type api

# List draft documents
/docs:list --status draft

# List dataset documentation in JSON format
/docs:list docs/datasets --format json

# List all ADRs in markdown format
/docs:list docs/architecture/adrs --doc-type adr --format markdown

# List published guides
/docs:list docs/guides --status published
```

## Output Formats

### Table (default)
```
+--------+------------------+--------+---------+
| Type   | Title            | Status | Version |
+--------+------------------+--------+---------+
| api    | User Login       | draft  | 1.0.0   |
| api    | User Logout      | pub    | 1.2.0   |
| dataset| User Metrics     | pub    | 2.0.0   |
+--------+------------------+--------+---------+

Total: 3 documents
```

### JSON
```json
{
  "total": 3,
  "documents": [
    {
      "file_path": "docs/api/user-login/README.md",
      "title": "User Login",
      "fractary_doc_type": "api",
      "status": "draft",
      "version": "1.0.0"
    }
  ]
}
```

### Markdown
```markdown
# Documentation List

## API (2 documents)
- [**User Login**](docs/api/user-login/README.md) - draft (v1.0.0)
- [**User Logout**](docs/api/user-logout/README.md) - published (v1.2.0)

## Dataset (1 document)
- [**User Metrics**](docs/datasets/user-metrics/README.md) - published (v2.0.0)
```

## Related Commands

- `/docs:write` - Create or update documentation
- `/docs:validate` - Validate documentation
- `/docs:audit` - Audit all documentation

---

Use the @agent-fractary-docs:docs-manager agent to handle this list request.
