# Workflow: Update Existing Documentation

This workflow guides updating existing documentation while preserving structure and formatting.

## Overview

The doc-updater skill provides four operations for modifying documentation:
- **update-section**: Replace content of specific section
- **append-section**: Add new section to document
- **update-metadata**: Modify front matter fields
- **replace-content**: Pattern-based replacement

## Common Workflow Steps

### Step 1: Verify File Exists

Check that the target document exists:
```bash
if [[ ! -f "$FILE_PATH" ]]; then
  echo "Error: File not found"
  exit 1
fi
```

### Step 2: Create Backup

Always create backup before modifications:
```bash
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_PATH="${FILE_PATH}.backup-${TIMESTAMP}"
cp "$FILE_PATH" "$BACKUP_PATH"
```

### Step 3: Parse Document

Understand document structure before updating:
```bash
PARSE_RESULT=$(./scripts/parse-document.sh --file "$FILE_PATH")
```

Returns sections, code blocks, tables, and front matter.

### Step 4: Execute Update

Choose appropriate update operation based on need.

### Step 5: Validate Result

Run validation after update:
```bash
./scripts/validate-output.sh --file "$FILE_PATH"
```

### Step 6: Review Changes

Use git diff to review:
```bash
git diff "$FILE_PATH"
```

If issues found, restore from backup:
```bash
cp "$BACKUP_PATH" "$FILE_PATH"
```

## Operation-Specific Workflows

### A. Update Section Workflow

**Use Case**: Modify content of existing section

**Example: Update ADR Status**

```bash
./scripts/update-section.sh \
  --file docs/architecture/adrs/ADR-001-database-choice.md \
  --heading "Status" \
  --content "Accepted

This decision was approved on 2025-01-15 after team review and prototype validation." \
  --preserve-subsections false
```

**Result**:
- "Status" section content replaced
- Section heading remains "Status"
- No subsections (preserve-subsections: false)
- Rest of document unchanged

**Parameters**:
```json
{
  "file_path": "docs/architecture/adrs/ADR-001-database-choice.md",
  "section_heading": "Status",
  "new_content": "Accepted\n\nThis decision was approved...",
  "preserve_subsections": false
}
```

**Steps**:
1. Parse document to find "Status" section
2. Extract section boundaries
3. Replace section content
4. Keep heading at same level
5. Remove subsections if preserve_subsections: false
6. Write updated document

**Example: Update Design Architecture Section**

```bash
./scripts/update-section.sh \
  --file docs/architecture/designs/user-auth.md \
  --heading "Architecture" \
  --content "The authentication system consists of three main components:

### Authentication Service
Handles login, logout, and token validation.

### User Store
PostgreSQL database storing user credentials.

### Session Cache
Redis cache for active sessions." \
  --preserve-subsections true
```

**Result**:
- "Architecture" section updated with new content
- Subsections preserved (Auth Service, User Store, Session Cache)
- Other sections unchanged

### B. Append Section Workflow

**Use Case**: Add new section without modifying existing content

**Example: Add Performance Section to Design Doc**

```bash
./scripts/append-section.sh \
  --file docs/architecture/designs/user-auth.md \
  --heading "Performance Considerations" \
  --content "Target response time: < 200ms for authentication requests.

Load testing shows system handles 1000 req/s with 95th percentile latency of 180ms." \
  --after "Implementation" \
  --level 2
```

**Result**:
- New "## Performance Considerations" section added
- Placed after "Implementation" section
- Existing content unchanged

**Parameters**:
```json
{
  "file_path": "docs/architecture/designs/user-auth.md",
  "section_heading": "Performance Considerations",
  "content": "Target response time...",
  "after_heading": "Implementation",
  "heading_level": 2
}
```

**Steps**:
1. Parse document to find insertion point
2. If after_heading specified, find that section's end line
3. Otherwise, insert at end of document
4. Add blank line separator
5. Add new section with proper heading level
6. Write updated document

**Example: Add Troubleshooting Entry to Runbook**

```bash
./scripts/append-section.sh \
  --file docs/operations/runbooks/database-failover.md \
  --heading "Replication Lag Issues" \
  --content "**Symptoms**: Stale data in secondary database.

**Diagnosis**: Check replication lag:
\`\`\`bash
SELECT NOW() - pg_last_xact_replay_timestamp() AS lag;
\`\`\`

**Solution**: If lag > 1 minute, investigate network or primary database load." \
  --after "Troubleshooting" \
  --level 3
```

**Result**:
- New troubleshooting subsection added
- Nested under "Troubleshooting" section (level 3)
- Code blocks preserved

### C. Update Metadata Workflow

**Use Case**: Modify front matter without touching document body

**Example: Update Document Status**

```bash
./scripts/update-metadata.sh \
  --file docs/architecture/adrs/ADR-002-api-versioning.md \
  --field "status" \
  --value "accepted" \
  --auto-timestamp true
```

**Result**:
- Front matter "status" field changed to "accepted"
- "updated" field automatically set to current date
- Document body completely unchanged

**Parameters**:
```json
{
  "file_path": "docs/architecture/adrs/ADR-002-api-versioning.md",
  "field": "status",
  "value": "accepted",
  "auto_update_timestamp": true
}
```

**Steps**:
1. Extract front matter from document
2. Parse YAML
3. Update specified field
4. If auto_timestamp, update "updated" field with current date
5. Regenerate YAML front matter
6. Replace front matter in document
7. Preserve document body exactly
8. Write updated document

**Example: Add Tags**

```bash
./scripts/update-metadata.sh \
  --file docs/api/user-api-spec.md \
  --field "tags" \
  --value '["api", "rest", "authentication", "v2"]' \
  --auto-timestamp true
```

**Result**:
- "tags" field updated with array
- "updated" timestamp refreshed

**Example: Update Related Documents**

```bash
./scripts/update-metadata.sh \
  --file docs/architecture/designs/auth-system.md \
  --field "related" \
  --value '["../adrs/ADR-003-jwt-tokens.md", "../../api/auth-api-spec.md"]' \
  --auto-timestamp true
```

**Result**:
- "related" field updated with paths to related docs
- Enables doc-linker to build relationship graph

### D. Replace Content Workflow

**Use Case**: Pattern-based replacement across document

**Example: Update Version Number**

```bash
./scripts/replace-content.sh \
  --file docs/api/v1-api-spec.md \
  --pattern "version: 1.0" \
  --replacement "version: 1.1" \
  --regex false \
  --global true
```

**Result**:
- All occurrences of "version: 1.0" replaced with "version: 1.1"
- Code blocks protected (no replacement inside \`\`\`)
- Markdown structure preserved

**Parameters**:
```json
{
  "file_path": "docs/api/v1-api-spec.md",
  "pattern": "version: 1.0",
  "replacement": "version: 1.1",
  "regex": false,
  "global": true
}
```

**Steps**:
1. Read document content
2. Track code blocks (don't replace inside them)
3. For each line not in code block:
   - If global: replace all pattern occurrences
   - If not global: replace first occurrence only
4. Write updated document

**Example: Update URLs with Regex**

```bash
./scripts/replace-content.sh \
  --file docs/guides/setup-guide.md \
  --pattern "https://old-domain\\.com/([^\\s]+)" \
  --replacement "https://new-domain.com/\\1" \
  --regex true \
  --global true
```

**Result**:
- All URLs matching pattern updated
- Path component preserved via capture group (\\1)
- Regex matching enabled

**Example: Fix Repeated Typo**

```bash
./scripts/replace-content.sh \
  --file docs/architecture/system-overview.md \
  --pattern "databse" \
  --replacement "database" \
  --regex false \
  --global true
```

**Result**:
- All instances of typo "databse" replaced with "database"

## Error Handling

### File Not Found

**Error**:
```json
{
  "success": false,
  "error": "File not found: docs/missing.md",
  "error_code": "FILE_NOT_FOUND"
}
```

**Solution**: Verify file path is correct

### Section Not Found

**Error**:
```json
{
  "success": false,
  "error": "Section not found: Performance",
  "error_code": "SECTION_NOT_FOUND",
  "available_sections": ["Overview", "Architecture", "Implementation"]
}
```

**Solution**: Check section heading (case-sensitive), or use one of available sections

### Pattern Not Found

**Error**:
```json
{
  "success": false,
  "error": "Pattern not found: version: 2.0",
  "error_code": "PATTERN_NOT_FOUND",
  "replacements": 0
}
```

**Solution**: Verify pattern exists in document, check for typos

### No Front Matter

**Error**:
```json
{
  "success": false,
  "error": "No front matter found in document",
  "error_code": "NO_FRONTMATTER"
}
```

**Solution**: Add front matter using doc-generator or manually

## Best Practices

### 1. Always Create Backups
```bash
# Backup created automatically
BACKUP_PATH="${FILE_PATH}.backup-$(date +%Y%m%d%H%M%S)"
```

Restore if needed:
```bash
cp "$BACKUP_PATH" "$FILE_PATH"
```

### 2. Review Changes with Git Diff
```bash
git diff "$FILE_PATH"
```

Shows exactly what changed.

### 3. Update One Section at a Time

Better:
```bash
# Update status
/fractary-docs:update doc.md --section "Status" --content "Accepted"

# Then update another section
/fractary-docs:update doc.md --section "Implementation" --content "..."
```

Instead of:
```bash
# Trying to update multiple sections at once (not supported)
```

### 4. Use Meaningful Commit Messages

After updating:
```bash
git add docs/architecture/adrs/ADR-001.md
git commit -m "docs: Update ADR-001 status to accepted"
```

### 5. Validate After Updates

```bash
/fractary-docs:validate "$FILE_PATH"
```

Catches issues early.

### 6. Keep Timestamps Current

Always use auto-timestamp when updating:
```bash
--auto-timestamp true
```

### 7. Preserve Subsections When Appropriate

If section has useful subsections, preserve them:
```bash
--preserve-subsections true
```

### 8. Test Patterns Before Global Replace

Test pattern match first:
```bash
grep "pattern" "$FILE_PATH"
```

Then do replacement.

### 9. Use Literal for Simple Replacements

For simple text replacement, literal is safer:
```bash
--regex false
```

Use regex only when needed for complex patterns.

### 10. Document Why Changes Were Made

In commit message or ADR, explain why document was updated.

## Integration with FABER

FABER workflows can use doc-updater to:

**Evaluate Phase**: Update test reports with results
```bash
/fractary-docs:update docs/testing/test-report.md \
  --section "Results" \
  --content "Test run completed: 245/250 passed (98%)"
```

**Release Phase**: Update deployment docs with deployment record
```bash
/fractary-docs:update docs/deployments/production.md \
  --append-section "2025-01-15 Deployment" \
  --content "Version 2.1.0 deployed successfully"
```

**Any Phase**: Update ADR status when decisions finalized
```bash
/fractary-docs:update docs/architecture/adrs/ADR-005.md \
  --metadata status \
  --content "accepted"
```

## Recovery Procedures

### Restore from Backup

```bash
# List available backups
ls -lt docs/architecture/adrs/ADR-001.md.backup-*

# Restore specific backup
cp docs/architecture/adrs/ADR-001.md.backup-20250115120000 \
   docs/architecture/adrs/ADR-001.md
```

### Restore from Git

```bash
# View history
git log --oneline docs/architecture/adrs/ADR-001.md

# Restore specific version
git checkout <commit> docs/architecture/adrs/ADR-001.md
```

## Examples Repository

See `examples/` directory for complete update examples:
- Updating ADR lifecycle
- Adding sections to design docs
- Pattern replacement for version bumps
- Metadata updates for status tracking
