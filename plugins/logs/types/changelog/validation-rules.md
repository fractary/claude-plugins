# Changelog Log Validation Rules

This document defines validation rules for changelog logs. Rules are organized by validation type and severity.

---

## Frontmatter Validation

### ✅ MUST Rules (Critical)

1. **log_type field**
   - MUST be present
   - MUST equal "changelog"
   - **Error**: "Missing or invalid log_type field"
   - **Fix**: Add `log_type: changelog` to frontmatter

2. **changelog_id field**
   - MUST be present
   - MUST match pattern: `changelog-[a-z0-9-]+`
   - MUST be unique across all changelog logs
   - **Error**: "Missing or invalid changelog_id"
   - **Fix**: Add unique ID like `changelog-v1.2.0-20250117`

3. **version field**
   - MUST be present
   - MUST be valid semantic version (semver)
   - MUST match pattern: `MAJOR.MINOR.PATCH` with optional pre-release/build
   - **Error**: "Missing or invalid version number"
   - **Fix**: Use semver format like `1.2.3` or `2.0.0-beta.1`

4. **release_date field**
   - MUST be present
   - MUST be valid ISO 8601 timestamp
   - **Error**: "Missing or invalid release_date"
   - **Fix**: Use format `2025-01-17T10:00:00Z`

5. **status field**
   - MUST be present
   - MUST be one of: draft, planned, released, deprecated, archived
   - **Error**: "Missing or invalid status value"
   - **Fix**: Set status to valid enum value

6. **title field**
   - MUST be present
   - MUST be non-empty string
   - **Error**: "Missing or empty title"
   - **Fix**: Add descriptive title like "Version 1.2.0 Release"

### ⚠️ SHOULD Rules (Warnings)

1. **changes object**
   - SHOULD include at least one category (added/changed/fixed/etc.)
   - **Warning**: "No changes documented in this release"
   - **Fix**: Add changes to appropriate categories

2. **work_items array**
   - SHOULD link to related issues/PRs
   - **Warning**: "No work items referenced"
   - **Fix**: Add work_items array with issue/PR links

3. **breaking_changes array**
   - SHOULD be present if MAJOR version incremented
   - **Warning**: "Major version bump without breaking changes documentation"
   - **Fix**: Document breaking changes or use MINOR version

4. **compare_url**
   - SHOULD be present for easier version comparison
   - **Warning**: "Missing compare URL for version diff"
   - **Fix**: Add compare_url pointing to git diff

---

## Structure Validation

### ✅ MUST Rules

1. **Frontmatter delimiter**
   - MUST start with `---`
   - MUST end with `---`
   - **Error**: "Invalid or missing frontmatter delimiters"
   - **Fix**: Ensure frontmatter is enclosed in `---` markers

2. **Version header**
   - MUST include version number in heading
   - MUST include release date
   - **Error**: "Missing version header section"
   - **Fix**: Add `# Version {version} Release` header

3. **Changes section**
   - MUST have at least one change category
   - Categories MUST use correct headings (## Added, ## Fixed, etc.)
   - **Error**: "No change categories found"
   - **Fix**: Add at least one category: Added, Changed, Fixed, etc.

### ⚠️ SHOULD Rules

1. **Breaking changes section**
   - SHOULD appear before other change categories
   - SHOULD use `## ⚠️ Breaking Changes` heading
   - **Warning**: "Breaking changes section not at top"
   - **Fix**: Move breaking changes section to appear first

2. **Summary section**
   - SHOULD provide high-level overview
   - **Warning**: "Missing summary section"
   - **Fix**: Add summary describing the release

3. **Consistent formatting**
   - Changes SHOULD use bullet points (`-` or `*`)
   - Work items SHOULD use consistent link format
   - **Warning**: "Inconsistent formatting in changes"
   - **Fix**: Use bullet points for all changes

---

## Content Validation

### ✅ MUST Rules

1. **Semantic versioning**
   - Version MUST follow semver rules
   - Breaking changes MUST increment MAJOR version
   - New features MUST increment MINOR version (if no breaking changes)
   - Bug fixes MUST increment PATCH version (if no features)
   - **Error**: "Version number violates semantic versioning"
   - **Fix**: Adjust version based on change types

2. **Change categorization**
   - Changes MUST be in appropriate category
   - Breaking changes MUST be documented separately
   - Security fixes MUST be in Security section
   - **Error**: "Change in incorrect category"
   - **Fix**: Move change to appropriate category

3. **No sensitive data**
   - MUST NOT contain credentials, API keys, tokens
   - MUST NOT contain PII or customer data
   - **Error**: "Sensitive data detected in changelog"
   - **Fix**: Redact sensitive information

4. **Valid URLs**
   - compare_url and work item URLs MUST be valid URIs
   - **Error**: "Invalid URL format"
   - **Fix**: Ensure URLs are well-formed

### ⚠️ SHOULD Rules

1. **User-facing language**
   - Changes SHOULD be written for end users, not developers
   - SHOULD avoid internal jargon
   - **Warning**: "Technical jargon in user-facing changelog"
   - **Fix**: Simplify language for broader audience

2. **Migration notes**
   - Breaking changes SHOULD include migration guidance
   - **Warning**: "Breaking change without migration notes"
   - **Fix**: Add migration_notes explaining how to upgrade

3. **Descriptive changes**
   - Changes SHOULD be clear and specific
   - SHOULD NOT be too generic (e.g., "bug fixes")
   - **Warning**: "Vague change description"
   - **Fix**: Provide specific details about what changed

4. **Contributor attribution**
   - SHOULD include contributors array
   - **Warning**: "No contributors listed"
   - **Fix**: Add contributors who worked on this release

---

## Schema Validation

### JSON Schema Compliance

All changelog logs MUST validate against `schema.json`:

```bash
# Validation command
jsonschema -i changelog.md --extract-frontmatter schema.json
```

**Common schema errors**:

1. **Type mismatch**
   - **Error**: "Field 'version' must be string"
   - **Fix**: Ensure version is quoted string, not number

2. **Missing required field**
   - **Error**: "Required property 'changelog_id' missing"
   - **Fix**: Add all required fields to frontmatter

3. **Invalid enum value**
   - **Error**: "Status 'complete' not in enum [draft, planned, released, deprecated, archived]"
   - **Fix**: Use valid status value

4. **Pattern mismatch**
   - **Error**: "changelog_id doesn't match pattern ^changelog-[a-z0-9-]+$"
   - **Fix**: Use valid changelog_id format

5. **Additional properties**
   - **Error**: "changes object contains invalid category 'improvements'"
   - **Fix**: Use standard categories: added, changed, deprecated, removed, fixed, security

---

## Validation Error Severity

### Critical (MUST fix before archiving)
- Invalid schema
- Missing required fields
- Invalid semver
- Sensitive data present

### Warning (SHOULD fix but not blocking)
- Missing optional fields
- Formatting inconsistencies
- Vague descriptions
- Missing migration notes

### Info (Nice to have)
- Missing compare URL
- No contributors listed
- Generic release notes

---

## Automated Validation

The log-validator skill runs these checks automatically:

```bash
# Validate changelog log
/fractary-logs:validate changelog-v1.2.0-20250117.md

# Expected output:
✅ Schema validation: PASS
✅ Frontmatter structure: PASS
⚠️ Missing compare_url
⚠️ No contributors listed
✅ Semantic versioning: PASS
✅ No sensitive data detected
```

---

## Manual Review Checklist

Before releasing a changelog:

- [ ] Version number follows semver
- [ ] All changes categorized correctly
- [ ] Breaking changes documented with migration notes
- [ ] Security fixes highlighted
- [ ] Work items linked
- [ ] No sensitive data
- [ ] User-friendly language
- [ ] Compare URL included
- [ ] Contributors credited
- [ ] Status set to "released"
