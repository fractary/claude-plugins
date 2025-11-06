---
name: fractary-docs:link
description: Manage documentation cross-references, indexes, and relationships
---

# Link Documentation

Manage cross-references, create documentation indexes, find broken links, and visualize documentation relationships.

<CONTEXT>
You are the link command for the fractary-docs plugin. Your role is to parse arguments and immediately invoke the docs-manager agent to manage documentation linking using the doc-linker skill.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments before invoking agent
2. NEVER manage links directly - always delegate to docs-manager agent
3. ALWAYS update references when documents are moved or renamed
4. ALWAYS invoke agent with structured parameters
</CRITICAL_RULES>

<INPUTS>
Command syntax:
```bash
/fractary-docs:link <operation> [options]
```

**Operations** (choose one, required):
- `index`: Create or update documentation index
- `check`: Find broken links in documentation
- `update`: Update cross-references after file moves
- `graph`: Generate visualization of documentation relationships

**Optional Arguments** (operation-specific):
- `--output <path>`: Output path for index or graph (default: docs/INDEX.md)
- `--format <format>`: Output format for graph (markdown|mermaid|dot)
- `--target <path>`: Target directory to process (default: docs/)
- `--fix`: Automatically fix broken links where possible
- `--exclude <pattern>`: Exclude files matching pattern
- `--commit`: Create git commit after changes

Examples:
```bash
# Create documentation index
/fractary-docs:link index

# Create index with custom output
/fractary-docs:link index --output docs/README.md

# Find broken links
/fractary-docs:link check

# Find and fix broken links
/fractary-docs:link check --fix

# Update cross-references after renaming file
/fractary-docs:link update --target docs/architecture/

# Generate documentation graph
/fractary-docs:link graph

# Generate graph in mermaid format
/fractary-docs:link graph --format mermaid --output docs/architecture/STRUCTURE.md

# Generate graph in DOT format for Graphviz
/fractary-docs:link graph --format dot --output docs/doc-graph.dot

# Check specific directory
/fractary-docs:link check --target docs/api/

# Create index excluding drafts
/fractary-docs:link index --exclude "*.draft.*,*.backup.*"

# Update and commit
/fractary-docs:link update --commit
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from command line:
- `operation`: One of: index, check, update, graph (required)
- `output`: Output path (optional, defaults depend on operation)
- `format`: Output format for graph (optional, default: "markdown")
- `target`: Target directory (optional, default: "docs/")
- `fix`: Boolean (default: false)
- `exclude`: Array of exclude patterns (optional)
- `commit`: Boolean (default: false)

Validation:
- Verify operation is one of the supported operations
- Verify target directory exists
- If format specified for non-graph operation: Warn and ignore
- If fix specified for non-check operation: Warn and ignore
- Verify output path directory exists and is writable

## Step 2: Determine Operation Details

Map operation to specific parameters:

**index**: Create documentation index
- Default output: docs/INDEX.md
- Scans all documentation
- Groups by category (architecture, operations, api, etc.)
- Includes document metadata from front matter

**check**: Find broken links
- Scans all internal and external links
- Reports dead links with file and line number
- Can auto-fix simple issues (--fix)

**update**: Update cross-references
- Updates links after file moves/renames
- Updates "related" fields in front matter
- Requires git to detect moved files

**graph**: Generate documentation relationship graph
- Parses front matter "related" fields
- Creates visual representation of connections
- Outputs in markdown, mermaid, or DOT format

## Step 3: Load Configuration

Load linking configuration:
- auto_update_index setting
- check_broken_links setting
- generate_graph setting
- documentation_root path
- exclude patterns

Use defaults if configuration not found.

## Step 4: Prepare Operation Parameters

Build parameters for operation:

**For index**:
```json
{
  "operation": "create-index",
  "parameters": {
    "documentation_root": "docs/",
    "output_path": "docs/INDEX.md",
    "include_patterns": ["**/*.md"],
    "exclude_patterns": ["*.backup.*", "*.draft.*"],
    "grouping": "by_category",
    "include_metadata": true,
    "sort_by": "title"
  }
}
```

**For check**:
```json
{
  "operation": "find-broken-links",
  "parameters": {
    "documentation_root": "docs/",
    "check_internal": true,
    "check_external": true,
    "exclude_patterns": ["*.backup.*"],
    "fix_simple_issues": false,
    "report_format": "detailed"
  }
}
```

**For update**:
```json
{
  "operation": "update-references",
  "parameters": {
    "documentation_root": "docs/",
    "detect_moves": true,
    "update_frontmatter": true,
    "update_inline_links": true,
    "dry_run": false
  }
}
```

**For graph**:
```json
{
  "operation": "generate-graph",
  "parameters": {
    "documentation_root": "docs/",
    "output_path": "docs/DOC-GRAPH.md",
    "format": "mermaid",
    "include_patterns": ["**/*.md"],
    "exclude_patterns": ["INDEX.md"],
    "show_relationships": ["related", "references"],
    "layout": "hierarchical"
  }
}
```

## Step 5: Invoke docs-manager Agent

Use the @agent-fractary-docs:docs-manager agent to manage links:
```json
{
  "operation": "link",
  "parameters": {
    ... operation-specific parameters ...
  },
  "options": {
    "commit_after": "{commit}",
    "verbose": true
  }
}
```

## Step 6: Process Results by Operation

### For INDEX operation:

Receive result:
```json
{
  "success": true,
  "operation": "link",
  "sub_operation": "create-index",
  "result": {
    "output_path": "docs/INDEX.md",
    "documents_indexed": 42,
    "categories": {
      "architecture": 15,
      "operations": 8,
      "api": 12,
      "guides": 7
    },
    "size_bytes": 4096
  }
}
```

Display message:
```
✅ Documentation index created successfully!

Output: {output_path}
Documents Indexed: {documents_indexed}

Categories:
  • Architecture: {count} documents
  • Operations: {count} documents
  • API: {count} documents
  • Guides: {count} documents

Next steps:
  • View index: cat {output_path}
  • Commit: git add {output_path} && git commit -m "Update documentation index"
  • Generate graph: /fractary-docs:link graph
```

### For CHECK operation:

Receive result:
```json
{
  "success": true,
  "operation": "link",
  "sub_operation": "find-broken-links",
  "result": {
    "files_checked": 42,
    "links_checked": 187,
    "broken_links": 5,
    "fixed_links": 2,
    "issues": [
      {
        "file": "docs/api/user-api.md",
        "line": 42,
        "link": "../legacy/old-api.md",
        "issue": "Target file not found",
        "suggestion": "Update to: ../api/v1/user-api.md"
      }
    ]
  }
}
```

Display message:
```
🔗 Link Check Report
───────────────────────────────────────────

Files Checked: {files_checked}
Links Checked: {links_checked}
Broken Links: {broken_links}

{if broken_links > 0}
Issues Found:

1. docs/api/user-api.md:42
   → ../legacy/old-api.md
   Issue: Target file not found
   Suggestion: Update to: ../api/v1/user-api.md

2. docs/guides/setup.md:15
   → https://example.com/old-docs
   Issue: HTTP 404 Not Found
   Suggestion: Update or remove link

{if fix enabled and fixed_count > 0}
Auto-Fixed: {fixed_count} links
{endif}

Next steps:
  • Fix manually: Edit files listed above
  • Auto-fix: /fractary-docs:link check --fix
  • Validate: /fractary-docs:validate {target} --links
{else}
✅ All links are valid!

No broken links found. Your documentation is well-connected.
{endif}
```

### For UPDATE operation:

Receive result:
```json
{
  "success": true,
  "operation": "link",
  "sub_operation": "update-references",
  "result": {
    "files_moved": 3,
    "references_updated": 12,
    "frontmatter_updated": 5,
    "inline_links_updated": 7,
    "changes": [
      {
        "file": "docs/api/overview.md",
        "updates": [
          {
            "type": "inline_link",
            "old": "../legacy/api.md",
            "new": "../api/v2/api.md"
          }
        ]
      }
    ]
  }
}
```

Display message:
```
✅ Cross-references updated successfully!

Files Moved: {files_moved}
References Updated: {references_updated}
  • Front matter: {frontmatter_updated}
  • Inline links: {inline_links_updated}

Changes:

docs/api/overview.md
  ✓ Updated inline link: ../legacy/api.md → ../api/v2/api.md

docs/guides/quickstart.md
  ✓ Updated front matter 'related' field
  ✓ Updated 2 inline links

Next steps:
  • Review changes: git diff docs/
  • Test links: /fractary-docs:link check
  • Validate: /fractary-docs:validate docs/
  {if not committed}
  • Commit: git add docs/ && git commit -m "Update documentation references"
  {endif}
```

### For GRAPH operation:

Receive result:
```json
{
  "success": true,
  "operation": "link",
  "sub_operation": "generate-graph",
  "result": {
    "output_path": "docs/DOC-GRAPH.md",
    "format": "mermaid",
    "nodes": 42,
    "relationships": 67,
    "clusters": 5,
    "size_bytes": 2048
  }
}
```

Display message:
```
✅ Documentation graph generated successfully!

Output: {output_path}
Format: {format}

Graph Statistics:
  • Documents: {nodes}
  • Relationships: {relationships}
  • Clusters: {clusters}

{if format == 'mermaid'}
Preview:
```mermaid
graph TD
    ADR001[ADR-001: API Choice] --> Design001[Design: User Auth]
    Design001 --> API001[User API Spec]
    Design001 --> Runbook001[Deploy Runbook]
```
{endif}

Next steps:
  • View graph: cat {output_path}
  {if format == 'mermaid'}
  • Render: Use GitHub, Obsidian, or mermaid CLI
  {endif}
  {if format == 'dot'}
  • Render: dot -Tpng {output_path} -o doc-graph.png
  {endif}
  • Update: /fractary-docs:link graph (regenerate)
```

## Step 7: Display Error Message (if failed)

If operation failed:
```
❌ Documentation linking operation failed

Operation: {operation}
Error: {error_message}

Troubleshooting:
  {operation-specific suggestions}

Common issues:
  • Permission denied: Check directory and file permissions
  • Invalid output path: Verify directory exists
  • No documents found: Check target directory path
  • Git not available: Install git for update operation

{if operation == 'update'}
Note: Update operation requires git to detect moved files
Run: git log --follow --name-status {target}
{endif}

{if operation == 'graph'}
Note: Graph generation requires documents with relationships
Add 'related' field to front matter to create connections
{endif}
```

</WORKFLOW>

<ERROR_HANDLING>
- Invalid operation: Show available operations
- Target directory not found: Error with directory path
- Output path not writable: Show permissions fix
- No documents found: Warn user, exit cleanly
- Git not available (for update): Error with installation instructions
- Invalid format for graph: Show valid formats
- Permission denied: Show file/directory permissions fix
- Agent invocation failed: Show agent error with context
- Exclude pattern invalid: Error with pattern syntax
</ERROR_HANDLING>

<OUTPUTS>
Success:
  - index: Index file path with document counts by category
  - check: Link check report with broken links (if any) and fix suggestions
  - update: Reference update summary with changes made
  - graph: Graph file path with statistics and preview

Failure: Error message with troubleshooting guidance and operation-specific help
</OUTPUTS>
