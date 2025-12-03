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

- `--prompt "<instructions>"` - Instructions for generating documentation from conversation context. Claude will use the current conversation plus these instructions to craft the documentation content.
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

# Generate documentation from conversation context
/docs:write api --prompt "Document the authentication endpoints we discussed, including the OAuth2 flow"

# Generate ADR capturing decision discussion
/docs:write adr --prompt "Create an ADR for the database migration strategy we decided on"

# Generate guide from implementation discussion
/docs:write guide --prompt "Write a guide covering the deployment process we walked through"
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

**Using `--prompt`**: When you provide a `--prompt` argument, Claude will use your instructions to guide what aspects of the conversation to capture in the documentation. This is especially useful after design discussions, implementation walkthroughs, or decision-making sessions where you want to document the outcomes.

## Related Commands

- `/docs:validate` - Validate existing documentation
- `/docs:list` - List documentation files
- `/docs:audit` - Audit all documentation

---

Use the @agent-fractary-docs:docs-manager agent to handle this write operation request.
