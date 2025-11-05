# Update Strategies

Guide for choosing the right update strategy and operation for different documentation update scenarios.

## When to Update vs. Regenerate

### Update Existing Document When:

✅ **Minor Content Changes**
- Fix typos or grammatical errors
- Update specific section with new information
- Add new sections to existing document
- Update status or metadata
- Refresh outdated information in one section

✅ **Incremental Evolution**
- Document is mostly correct, needs targeted updates
- Changes are localized to specific sections
- Want to preserve existing content and structure
- Multiple people contributed, don't want to regenerate

✅ **Status Tracking**
- Update ADR status from proposed → accepted
- Mark design doc as approved after review
- Update "updated" timestamp after changes

### Regenerate Document When:

❌ **Major Restructuring**
- Need to reorganize entire document
- Changing document type or purpose
- Complete rewrite needed
- Template structure has changed significantly

❌ **Starting Fresh**
- Original document has quality issues throughout
- Want to apply new template standard
- Consolidating multiple documents

❌ **Automated Generation**
- Document is fully generated from data (e.g., API spec from OpenAPI)
- No manual edits to preserve
- Part of automated build process

## Choosing the Right Operation

### Use update-section When:

**Scenario**: Need to replace content of specific section

**Examples**:
- Update "Status" section in ADR to mark as accepted
- Refresh "Architecture" section in design doc with new diagram
- Update "Steps" in runbook after process changes
- Revise "Troubleshooting" section with new solutions

**Characteristics**:
- Target section clearly identified by heading
- Want to replace all content in that section
- May want to preserve or remove subsections
- Rest of document stays unchanged

**Decision Tree**:
```
Do you know the exact section heading? → YES
Do you want to replace its entire content? → YES
Do you want rest of document unchanged? → YES
→ Use update-section
```

### Use append-section When:

**Scenario**: Need to add new section without modifying existing content

**Examples**:
- Add "Performance Considerations" to design doc
- Add new troubleshooting entry to runbook
- Add new API endpoint to specification
- Add "Lessons Learned" to postmortem

**Characteristics**:
- Adding new content, not replacing existing
- New section has clear heading
- Can specify where to insert (after specific section or at end)
- Existing sections completely unchanged

**Decision Tree**:
```
Are you adding completely new content? → YES
Does it need its own section? → YES
Should existing content remain untouched? → YES
→ Use append-section
```

### Use update-metadata When:

**Scenario**: Need to modify front matter only

**Examples**:
- Update document status in lifecycle
- Add or update tags for categorization
- Update "related" documents list
- Change author or update timestamp
- Mark document as reviewed

**Characteristics**:
- Only changing YAML front matter
- Document body must remain exactly the same
- Often used for status tracking or metadata maintenance
- Frequently automated

**Decision Tree**:
```
Are you only changing front matter? → YES
Should document body stay exactly the same? → YES
Is this a metadata/status update? → YES
→ Use update-metadata
```

### Use replace-content When:

**Scenario**: Need pattern-based replacement across document

**Examples**:
- Update version number throughout document
- Replace outdated terminology or naming
- Update URLs or file paths
- Fix repeated typos across document
- Update API endpoints after rename

**Characteristics**:
- Same change needed in multiple places
- Can use literal text or regex pattern
- Can replace all occurrences or just first
- Preserves markdown structure

**Decision Tree**:
```
Is the same change needed in multiple places? → YES
Can you describe it as a pattern? → YES
Want to replace all or first occurrence? → SPECIFY
→ Use replace-content
```

## Complex Update Scenarios

### Scenario 1: Update Multiple Sections

**Problem**: Need to update several sections in same document

**Solution**: Multiple update-section calls
```bash
# Update Status
/fractary-docs:update doc.md --section "Status" --content "Accepted"

# Update Implementation
/fractary-docs:update doc.md --section "Implementation" --content "..."

# Update Testing
/fractary-docs:update doc.md --section "Testing" --content "..."
```

**Strategy**:
- Update one section at a time
- Validate after each update
- Use git commits to track each change
- Easier to rollback if needed

### Scenario 2: Add Section and Update Metadata

**Problem**: Need to add new section and update status

**Solution**: Combine append-section and update-metadata
```bash
# Add new section
/fractary-docs:update doc.md \
  --append-section "Performance Results" \
  --content "Benchmarks show..."

# Update status
/fractary-docs:update doc.md \
  --metadata status \
  --content "review"
```

**Strategy**:
- Do content changes first (append-section)
- Then metadata changes (update-metadata)
- Single commit for related changes

### Scenario 3: Update Section and Fix Typos

**Problem**: Need to update a section and fix typos elsewhere

**Solution**: Combine update-section and replace-content
```bash
# Update main section
/fractary-docs:update doc.md \
  --section "Architecture" \
  --content "New architecture..."

# Fix typo throughout
/fractary-docs:update doc.md \
  --replace "databse" \
  --content "database"
```

**Strategy**:
- Major updates first (update-section)
- Then minor fixes (replace-content)
- Verify with git diff before committing

### Scenario 4: Restructure Section with Subsections

**Problem**: Need to update section but keep its subsections

**Solution**: Use preserve-subsections
```bash
/fractary-docs:update doc.md \
  --section "Implementation" \
  --content "New implementation approach: ..." \
  --preserve-subsections true
```

**Strategy**:
- Set preserve-subsections: true
- Only main section content replaced
- Subsections (### Phase 1, ### Phase 2) kept intact
- Useful when subsection content still valid

### Scenario 5: Update Version Throughout Document

**Problem**: Version number appears in multiple places

**Solution**: Use replace-content with global flag
```bash
/fractary-docs:update doc.md \
  --replace "version 2.0" \
  --content "version 2.1" \
  --global
```

**Strategy**:
- Test pattern match first: `grep "version 2.0" doc.md`
- Use global flag to replace all occurrences
- Verify no unwanted replacements (check code blocks)
- Review with git diff

## Preservation Strategies

### What Gets Preserved

**Always Preserved**:
- Document structure outside target area
- Code block formatting and language tags
- List indentation and numbering
- Table structure and alignment
- Link syntax and URLs
- Inline formatting (bold, italic, code)
- Blank lines for readability

**Conditionally Preserved**:
- Subsections (based on preserve-subsections flag)
- Content inside code blocks (never replaced by replace-content)
- Front matter fields (only specified field updated by update-metadata)

### Preservation Rules by Operation

**update-section**:
```
Preserves:
  - Section heading (unchanged)
  - All other sections in document
  - Front matter
  - Code blocks and lists in other sections

Does Not Preserve:
  - Section content (replaced)
  - Subsections (unless preserve-subsections: true)
```

**append-section**:
```
Preserves:
  - Entire existing document
  - All sections and content
  - Front matter
  - Structure and formatting

Adds:
  - New section at insertion point
  - Proper heading level
  - Blank line separators
```

**update-metadata**:
```
Preserves:
  - Entire document body (100% unchanged)
  - All front matter fields except target
  - All sections and content
  - All formatting

Changes:
  - Specified front matter field only
  - "updated" timestamp (if auto-timestamp enabled)
```

**replace-content**:
```
Preserves:
  - Document structure
  - Markdown syntax
  - Content inside code blocks (protected)
  - Front matter
  - Tables, lists, links

Changes:
  - Pattern matches in content
  - Only outside code blocks
```

## Performance Considerations

### Document Size

**Small Documents** (< 100 lines):
- All operations perform well
- No special considerations

**Medium Documents** (100-1000 lines):
- Parse time minimal (< 1 second)
- All operations still fast
- Consider backing up before updates

**Large Documents** (> 1000 lines):
- Parse time may be noticeable (1-3 seconds)
- Consider splitting into smaller documents
- Test updates on copy first
- Use replace-content sparingly on very large docs

### Operation Complexity

**Fast Operations**:
- update-metadata (only touches front matter)
- replace-content with literal pattern
- append-section at end of document

**Medium Operations**:
- update-section (requires parsing and section identification)
- append-section after specific section (requires section finding)

**Slower Operations**:
- replace-content with complex regex on large documents
- update-section with subsection preservation (requires nested parsing)

### Optimization Tips

1. **Batch Related Updates**: Update multiple fields in single metadata update rather than separate calls

2. **Use Specific Patterns**: More specific patterns = faster matching
```bash
# Faster (specific)
--replace "version: 2.0"

# Slower (broader)
--replace "version.*"
```

3. **Limit Section Scope**: Update smallest possible section
```bash
# Update subsection rather than parent section
--section "Implementation Details"  # Better
--section "Implementation"  # Unnecessarily broad
```

4. **Validate Selectively**: Validate only what changed
```bash
# After update-section, validate structure
--validate structure

# After update-metadata, validate frontmatter
--validate frontmatter
```

## Safety Strategies

### 1. Always Backup

Automatic backups created:
```bash
{file}.backup-{timestamp}
```

Manual backup before risky operations:
```bash
cp doc.md doc.md.manual-backup
```

### 2. Test on Copy First

For complex updates:
```bash
# Copy document
cp important-doc.md test-doc.md

# Test update on copy
/fractary-docs:update test-doc.md --section "Risky Section" --content "..."

# Review with git diff
git diff test-doc.md

# If good, apply to original
/fractary-docs:update important-doc.md --section "Risky Section" --content "..."
```

### 3. Use Git Commits

Commit before major updates:
```bash
git add docs/
git commit -m "docs: before major update"

# Now safe to update
/fractary-docs:update ...

# Review changes
git diff

# If bad, revert
git checkout docs/
```

### 4. Validate After Updates

Always validate:
```bash
/fractary-docs:update doc.md ...
/fractary-docs:validate doc.md
```

### 5. Review Diffs

Before committing:
```bash
git diff doc.md
```

Look for:
- Unwanted changes
- Broken markdown
- Lost content
- Formatting issues

## Troubleshooting

### Update Didn't Work

**Symptoms**: No changes or wrong changes made

**Diagnosis**:
1. Check if section heading matches exactly (case-sensitive)
2. Verify file path is correct
3. Check if backup was created (indicates script ran)
4. Review error message for clues

**Solutions**:
- List available sections: Check parse result
- Fix heading case or wording
- Verify file path
- Check file permissions

### Content Corrupted

**Symptoms**: Markdown broken after update

**Diagnosis**:
1. View git diff to see what changed
2. Check if code blocks were affected
3. Look for missing closing markers (```, ---, etc.)

**Solutions**:
- Restore from backup: `cp backup original`
- Restore from git: `git checkout file`
- Re-run update with corrected parameters

### Subsections Lost

**Symptoms**: Subsections disappeared after update-section

**Cause**: preserve-subsections: false (default may vary)

**Solution**:
- Restore from backup
- Re-run with --preserve-subsections true
- Or regenerate subsections in new content

### Pattern Replaced Too Much

**Symptoms**: replace-content changed unwanted occurrences

**Diagnosis**:
1. Pattern too broad
2. Global flag used when shouldn't be
3. Matched inside code blocks (shouldn't happen, but check)

**Solutions**:
- Restore from backup
- Make pattern more specific
- Use regex with anchors
- Review matches before replacing: `grep "pattern" file`

## Best Practices Summary

1. **Always create backups** before updates
2. **Update one section at a time** for clarity
3. **Validate after each update** to catch issues early
4. **Use git commits** to track changes
5. **Review diffs** before committing
6. **Test complex patterns** before global replacement
7. **Preserve subsections** when appropriate
8. **Update timestamps** automatically
9. **Document why** in commit messages
10. **Keep backups** until confident in changes

## Quick Reference

```bash
# Update section content
/fractary-docs:update file.md --section "Heading" --content "New content"

# Add new section
/fractary-docs:update file.md --append-section "New Section" --content "Content"

# Update metadata
/fractary-docs:update file.md --metadata field --content "value"

# Replace pattern
/fractary-docs:update file.md --replace "old" --content "new" --global

# Validate result
/fractary-docs:validate file.md
```

## See Also

- **Workflow Guide**: `workflow/update-documentation.md`
- **SKILL.md**: Complete skill specification
- **Scripts**: `scripts/*.sh` - Implementation details
