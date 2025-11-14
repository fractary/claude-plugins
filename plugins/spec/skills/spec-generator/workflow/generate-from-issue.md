# Workflow: Generate Spec from Issue

This workflow describes the detailed steps for generating a specification from a GitHub issue.

## Step 1: Validate Inputs

Check that required inputs are provided:
- `issue_number` is present and valid (numeric)
- If `phase` provided, it's a positive integer
- If `template` provided, it's one of: basic, feature, infrastructure, api, bug

If validation fails, return error immediately.

## Step 2: Load Configuration

Load plugin configuration from `/plugins/spec/config/config.json`:
- Get `storage.local_path` (default: /specs)
- Get `naming.pattern` and `naming.multi_spec_pattern`
- Get `templates.default` (default: spec-basic)
- Get `integration` settings

## Step 3: Fetch Issue Data

Use the fractary-work plugin to fetch issue details:

```bash
gh issue view $ISSUE_NUMBER --json title,body,labels,assignees,url,state,number
```

Extract:
- **title**: Issue title
- **body**: Issue description/body
- **labels**: Array of labels (for classification)
- **assignees**: Array of assignees (for author field)
- **url**: Issue URL
- **state**: Issue state (open/closed)
- **number**: Issue number

If issue not found, return error.

## Step 4: Classify Work Type

If `template` parameter provided, use it.

Otherwise, auto-classify based on labels and title:

**Bug**:
- Labels contain: "bug", "defect", "hotfix"
- Title starts with: "Fix", "Bug:", "Hotfix:"

**Feature**:
- Labels contain: "feature", "enhancement", "story"
- Title starts with: "Add", "Feature:", "Implement"

**Infrastructure**:
- Labels contain: "infrastructure", "devops", "cloud", "deployment"
- Title contains: "infrastructure", "deploy", "AWS", "Docker", "Kubernetes"

**API**:
- Labels contain: "api", "endpoint", "rest", "graphql"
- Title contains: "API", "endpoint", "/api/"

**Default**: basic

## Step 5: Select Template

Map work type to template file:
- bug → `templates/spec-bug.md.template`
- feature → `templates/spec-feature.md.template`
- infrastructure → `templates/spec-infrastructure.md.template`
- api → `templates/spec-api.md.template`
- basic → `templates/spec-basic.md.template`

Read template file. If not found, fall back to spec-basic.md.template.

## Step 6: Generate Filename

Use naming pattern from config. For **issue-based specs**, use WORK prefix with 5-digit zero-padding:

**Single spec**:
```
WORK-{issue_number:05d}-{slug}.md
```

**Multi-spec** (if phase provided):
```
WORK-{issue_number:05d}-{phase:02d}-{slug}.md
```

Where:
- `{issue_number:05d}` = issue number, zero-padded to 5 digits (e.g., "00123")
- `{phase:02d}` = phase number, zero-padded to 2 digits (e.g., "01")
- `{slug}` = kebab-case slug from title or phase title
  - Take first 4-5 words
  - Convert to lowercase
  - Replace spaces with hyphens
  - Remove special characters
  - Example: "User Authentication System" → "user-authentication-system"

**Examples**:
- Issue 84, no phase: `WORK-00084-implement-feature.md`
- Issue 123, no phase: `WORK-00123-user-authentication.md`
- Issue 123, phase 1: `WORK-00123-01-user-auth.md`
- Issue 123, phase 2: `WORK-00123-02-oauth-integration.md`

**Implementation**:
```bash
# Format issue number with leading zeros (5 digits)
padded_issue=$(printf "%05d" "$issue_number")

# Build filename
if [ -n "$phase" ]; then
  # With phase (zero-pad phase to 2 digits)
  padded_phase=$(printf "%02d" "$phase")
  filename="WORK-${padded_issue}-${padded_phase}-${slug}.md"
else
  # Without phase
  filename="WORK-${padded_issue}-${slug}.md"
fi
```

## Step 7: Parse Issue Data

Extract structured data from issue body:

### Parse Acceptance Criteria
Look for sections like:
```markdown
## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

Extract checklist items into array.

### Parse Requirements
Look for sections like:
```markdown
## Requirements
- Requirement 1
- Requirement 2
```

or

```markdown
## Functional Requirements
- FR1: ...
```

Extract into functional and non-functional arrays.

### Parse Files to Modify
Look for sections like:
```markdown
## Files
- `path/to/file.ts`: Description
```

### Parse Dependencies
Look for sections like:
```markdown
## Dependencies
- Dependency 1
```

### Extract Summary
Use first paragraph of issue body as summary.

## Step 8: Prepare Template Variables

Create variable map for template:

```json
{
  "issue_number": "123",
  "issue_url": "https://github.com/org/repo/issues/123",
  "title": "Implement user authentication",
  "work_type": "feature",
  "date": "2025-01-15",
  "author": "username",
  "slug": "user-authentication",
  "summary": "First paragraph of issue body",
  "functional_requirements": ["FR1: ...", "FR2: ..."],
  "non_functional_requirements": ["NFR1: ...", "NFR2: ..."],
  "acceptance_criteria": ["Criterion 1", "Criterion 2"],
  "files": [{"path": "src/auth.ts", "description": "..."}],
  "dependencies": ["Package X", "Service Y"],
  "technical_approach": "Extracted from issue or TBD",
  "testing_strategy": "Extracted from issue or TBD",
  "risks": [{"risk": "Risk 1", "mitigation": "Mitigation 1"}],
  "notes": "Additional notes from issue"
}
```

## Step 9: Fill Template

Replace template variables:
- `{{variable}}` → simple replacement
- `{{#array}}...{{/array}}` → loop over array
- `{{#object}}...{{/object}}` → loop over object properties

For Mustache-style templates, use simple string replacement for now:
- Replace `{{issue_number}}` with value
- Replace `{{title}}` with value
- Handle arrays by repeating template section
- Handle conditionals by including/excluding sections

## Step 10: Add Frontmatter

Ensure frontmatter is at top:
```yaml
---
spec_id: spec-123-user-auth
issue_number: 123
issue_url: https://github.com/org/repo/issues/123
title: Implement user authentication
type: feature
status: draft
created: 2025-01-15
author: username
validated: false
---
```

## Step 11: Save Spec File

Write spec to `{local_path}/{filename}`:
- Use `storage.local_path` from config (e.g., `/specs`)
- Create directory if doesn't exist
- Write file with UTF-8 encoding
- Set appropriate permissions

Full path example: `/specs/spec-123-phase1-user-auth.md`

## Step 12: Link to GitHub Issue

If `integration.update_issue_on_create` is true in config:

Comment on GitHub issue:
```markdown
📋 Specification Created

Specification generated for this issue:
- [spec-123-phase1-user-auth.md](/specs/spec-123-phase1-user-auth.md)

This spec will guide implementation and be validated before archival.
```

Use fractary-work plugin or direct gh CLI:
```bash
gh issue comment $ISSUE_NUMBER --body "..."
```

If comment fails, log warning but continue (non-critical).

## Step 13: Return Confirmation

Output success message with:
- Spec file path
- Template used
- GitHub comment status

Return JSON structure as defined in SKILL.md.

## Error Recovery

At each step, if error occurs:
1. Log detailed error
2. Determine if recoverable
3. Return structured error response
4. Suggest corrective action

## Example Execution

```
Input:
  issue_number: 123
  phase: 1
  title: "User Authentication"

Steps:
  1. ✓ Inputs valid
  2. ✓ Config loaded
  3. ✓ Issue #123 fetched
  4. ✓ Classified as: feature
  5. ✓ Template selected: spec-feature.md.template
  6. ✓ Filename: WORK-00123-01-user-auth.md
  7. ✓ Issue data parsed
  8. ✓ Variables prepared
  9. ✓ Template filled
  10. ✓ Frontmatter added
  11. ✓ Saved to /specs/WORK-00123-01-user-auth.md
  12. ✓ GitHub comment added
  13. ✓ Success returned

Output:
  {
    "status": "success",
    "spec_path": "/specs/WORK-00123-01-user-auth.md",
    "issue_number": "123",
    "template": "feature",
    "github_comment_added": true
  }
```
