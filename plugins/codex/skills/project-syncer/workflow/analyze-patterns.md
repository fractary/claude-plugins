# Workflow: Analyze Patterns

**Purpose**: Analyze and finalize sync patterns from configuration and frontmatter

## Steps

### 1. Load Base Patterns from Configuration

Start with patterns from input or configuration:
- If `patterns` parameter provided: use those
- Otherwise: use `config.default_sync_patterns` or `config.sync_patterns`

Default patterns typically include:
```
- docs/**
- CLAUDE.md
- README.md
- .claude/**
- standards/**
- guides/**
```

Output: "Base patterns loaded: <count> patterns"

### 2. Load Exclude Patterns

Start with exclude patterns from input or configuration:
- If `exclude` parameter provided: use those
- Otherwise: use `config.default_exclude_patterns` or `config.exclude_patterns`

Default excludes typically include:
```
- **/.git/**
- **/node_modules/**
- **/.env*
- **/*.log
- **/dist/**
- **/build/**
```

Output: "Exclude patterns loaded: <count> patterns"

### 3. Parse Frontmatter from Files (Optional Enhancement)

**Note**: This is an advanced feature. For MVP, skip this step.

In the future, parse frontmatter from markdown files to find:
- `codex_sync_include`: Additional patterns to sync
- `codex_sync_exclude`: Additional patterns to exclude

Use the `handler-sync-github:parse-frontmatter` operation for this.

### 4. Combine and Deduplicate Patterns

Merge all include patterns:
- Remove duplicates
- Sort for consistency
- Validate each pattern

Merge all exclude patterns:
- Remove duplicates
- Add codex repository to excludes (never sync the codex itself)
- Sort for consistency

Output:
```
Pattern Analysis Complete:
- Include: <count> patterns
- Exclude: <count> patterns
```

### 5. Validate Final Patterns

For each pattern:
- Check it's a valid glob expression
- Warn if pattern seems too broad (e.g., "**/*")
- Warn if pattern conflicts with excludes

If any validation fails:
- Output warning (don't fail - just warn)
- User can proceed or adjust

### 6. Output Final Pattern Sets

Return the finalized patterns:
```json
{
  "include_patterns": [
    "docs/**",
    "CLAUDE.md",
    ...
  ],
  "exclude_patterns": [
    "**/.git/**",
    "**/node_modules/**",
    ...
  ]
}
```

These will be passed to the handler for sync execution.

## Outputs

**Success**:
```json
{
  "success": true,
  "include_patterns": ["...", "..."],
  "exclude_patterns": ["...", "..."],
  "pattern_count": {
    "include": 6,
    "exclude": 8
  }
}
```

**Failure**:
```json
{
  "success": false,
  "error": "Pattern validation failed: <details>"
}
```
