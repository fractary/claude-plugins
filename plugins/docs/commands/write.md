# /docs:write

Create or update documentation with automatic validation and indexing.

## Usage

```bash
/docs:write <doc_type> [file_path] [options]
```

## Arguments

- `<doc_type>` - Document type (api, adr, guide, dataset, etl, testing, infrastructure, audit, architecture, standards, _untyped)
- `[file_path]` - Optional path (auto-generated if omitted)
- `[options]` - Optional flags

## Options

- `--skip-validation` - Skip validation step
- `--skip-index` - Skip index update
- `--batch` - Write multiple documents (provide pattern)

## Examples

```bash
# Create API documentation
/docs:write api

# Create dataset documentation with specific path
/docs:write dataset docs/datasets/user-metrics/README.md

# Create ADR with validation skipped
/docs:write adr --skip-validation

# Batch write all API endpoints
/docs:write api docs/api/**/*.md --batch
```

## What This Does

**Single Document** (default):
1. Invoke docs-manager agent
2. Route to docs-manager-skill
3. Execute write → validate → index pipeline
4. Return success with file paths

**Batch Mode** (`--batch`):
1. Invoke docs-manager agent
2. Route to docs-director-skill
3. Expand pattern, execute in parallel
4. Update indices, return summary

## Context

You can provide documentation content conversationally. The command will:
- Detect doc_type from path if not specified
- Extract relevant information from conversation
- Build context bundle with template variables
- Generate document using type-specific template

## Related Commands

- `/docs:validate` - Validate existing documentation
- `/docs:list` - List documentation files
- `/docs:audit` - Audit all documentation

---

Use the @agent-fractary-docs:docs-manager agent to handle this write operation request.
