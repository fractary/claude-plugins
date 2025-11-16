# Workflow: Generate Spec from Context

This workflow describes the detailed steps for generating a specification from conversation context, optionally enriched with GitHub issue data.

## Overview

**Primary Source**: Conversation context (current session discussion)
**Optional Enrichment**: GitHub issue data (if `--work-id` provided)
**Template**: Auto-detected from merged context

This workflow is designed to preserve the full planning discussion context when creating specifications.

## Step 1: Auto-Detect Work ID (If Not Provided)

If `work_id` is not provided in the input, attempt to auto-detect from current branch:

1. Check if repo plugin is available (check for repo cache script)
2. Read repo plugin's git status cache:
   ```bash
   ~/.fractary/plugins/repo/scripts/read-status-cache.sh issue_id
   ```
3. If issue_id is non-empty and numeric, use it as `work_id`
4. If not found or invalid, proceed without work_id (standalone spec)

**Implementation**:
```bash
# Check if work_id provided in input
if [ -z "$WORK_ID" ]; then
    # Try to auto-detect from repo cache
    REPO_CACHE_SCRIPT="${HOME}/.fractary/plugins/repo/scripts/read-status-cache.sh"
    if [ -f "$REPO_CACHE_SCRIPT" ]; then
        DETECTED_ISSUE_ID=$("$REPO_CACHE_SCRIPT" issue_id 2>/dev/null | tr -d '[:space:]')
        if [[ "$DETECTED_ISSUE_ID" =~ ^[0-9]+$ ]]; then
            WORK_ID="$DETECTED_ISSUE_ID"
            echo "Auto-detected issue #${WORK_ID} from branch"
        fi
    fi
fi
```

**Note**: The repo plugin's status cache is maintained by hooks (UserPromptSubmit, Stop) and extracts issue IDs from branch names like `feat/123-description`.

## Step 2: Validate Inputs

Check that inputs are valid:
- If `work_id` provided or detected, it's valid (numeric)
- If `template` provided, it's one of: basic, feature, infrastructure, api, bug
- `context` (explicit) is optional string

Validation is minimal - work_id and template are both optional.

## Step 3: Load Configuration

Load plugin configuration from `.fractary/plugins/spec/config.json`:
- Get `storage.local_path` (default: /specs)
- Get `naming.pattern` and `naming.standalone_pattern`
- Get `templates.default` (default: spec-basic)
- Get `integration` settings

## Step 4: Extract Conversation Context

**This is the primary data source.**

Analyze the full conversation history:
- Extract discussions about requirements, goals, approach
- Identify key decisions made
- Note technical constraints mentioned
- Gather acceptance criteria discussed
- Collect any architecture decisions
- Extract mentioned files, dependencies, risks

The skill has access to the full conversation. Read through it comprehensively to understand:
- What is being built/fixed?
- Why is it needed?
- What approach was discussed?
- What requirements were mentioned?
- What constraints exist?
- What are the success criteria?

## Step 5: Fetch Issue Data (If `work_id` Provided or Detected)

If `work_id` is provided or was auto-detected, fetch full issue data including all comments:

Use the **repo plugin's issue-fetch** operation:

```bash
# This is pseudo-code - actual invocation would be through repo plugin
# The repo plugin handles fetching issue + all comments
```

**Note**: The repo plugin's `issue-fetch` operation provides:
- Issue title
- Issue body/description
- All issue comments (chronologically)
- Labels
- Assignees
- Issue URL
- State (open/closed)

Extract from issue data:
- **title**: Issue title
- **body**: Issue description
- **comments**: All comment bodies
- **labels**: Array of labels (for classification support)
- **assignees**: Array of assignees (for author field)
- **url**: Issue URL
- **state**: Issue state
- **number**: Issue number

If issue not found, return error.

## Step 6: Merge Contexts

Create merged context combining all sources:

**Priority order (highest to lowest)**:
1. Conversation context (primary source)
2. Explicit `--context` parameter (if provided)
3. Issue description (if work_id provided)
4. Issue comments (if work_id provided)

**Merging strategy**:
- Start with conversation context as base
- Layer in explicit context (if provided)
- Enrich with issue description and comments (if work_id provided)
- Reconcile any conflicts (conversation takes precedence)
- Note where different sources provide complementary information

**Example merged context**:
```
Primary (Conversation):
- Discussed implementing OAuth2 authentication
- Decided on JWT token approach
- Mentioned using Passport.js library
- Identified security requirements

From Issue #123:
- Title: "Implement user authentication"
- Description: Lists acceptance criteria
- Comment 1: Suggests using refresh tokens
- Comment 2: Notes compliance requirements

Merged:
- Goal: Implement OAuth2 authentication with JWT tokens
- Approach: Passport.js library
- Token Strategy: JWT with refresh tokens
- Requirements: Security + compliance
- Acceptance Criteria: From issue description
```

## Step 7: Auto-Detect Template

Infer template from merged context based on keywords and patterns.

**Classification logic**:

### Bug Template
Keywords in merged context:
- "fix", "bug", "defect", "regression", "broken"
- "error", "crash", "failure"
- Issue labels: "bug", "defect", "hotfix"
- Issue title starts with: "Fix", "Bug:", "Hotfix:"

### Feature Template
Keywords in merged context:
- "add", "implement", "new feature", "enhancement"
- "user story", "functionality", "capability"
- Issue labels: "feature", "enhancement", "story"
- Issue title starts with: "Add", "Feature:", "Implement"

### Infrastructure Template
Keywords in merged context:
- "deploy", "infrastructure", "AWS", "cloud"
- "Terraform", "Docker", "Kubernetes", "CI/CD"
- "monitoring", "scaling", "provisioning"
- Issue labels: "infrastructure", "devops", "cloud", "deployment"

### API Template
Keywords in merged context:
- "API", "endpoint", "REST", "GraphQL"
- "request", "response", "schema"
- "/api/", "REST API", "GraphQL API"
- Issue labels: "api", "endpoint", "rest", "graphql"

### Basic Template (Default)
If no clear match, use basic template.

**Template override**:
If `--template` parameter provided, use that instead of auto-detection.

## Step 8: Generate Filename

Determine naming pattern based on whether `work_id` is provided.

### With `work_id` (Issue-Linked)

Pattern: `WORK-{issue:05d}-{slug}.md`

Where:
- `{issue:05d}` = issue number, zero-padded to 5 digits
- `{slug}` = kebab-case slug from merged context

**Slug generation from merged context**:
1. Try to identify the main subject/feature from conversation
2. Take key descriptive words (3-5 words)
3. Convert to lowercase kebab-case
4. Example: "User authentication with OAuth" → "user-auth-oauth"

**Implementation**:
```bash
padded_issue=$(printf "%05d" "$work_id")
filename="WORK-${padded_issue}-${slug}.md"
```

**Examples**:
- Issue 123, slug "user-authentication": `WORK-00123-user-authentication.md`
- Issue 84, slug "api-redesign": `WORK-00084-api-redesign.md`

### Without `work_id` (Standalone)

Pattern: `SPEC-{timestamp}-{slug}.md`

Where:
- `{timestamp}` = Current timestamp in format `YYYYMMDDHHmmss`
- `{slug}` = kebab-case slug from merged context (same logic as above)

**Implementation**:
```bash
timestamp=$(date +%Y%m%d%H%M%S)
filename="SPEC-${timestamp}-${slug}.md"
```

**Examples**:
- Timestamp 20250115143000, slug "user-auth": `SPEC-20250115143000-user-auth.md`
- Timestamp 20250115150000, slug "api-design": `SPEC-20250115150000-api-design.md`

## Step 9: Parse Merged Context

Extract structured data from the merged context:

### Extract Summary
Synthesize a concise summary (2-3 sentences) that captures:
- What is being built/fixed
- Why it's needed
- High-level approach

### Extract Requirements

Look for functional and non-functional requirements across all sources:

**Functional Requirements**:
- "Must...", "Should...", "Shall..."
- "User can...", "System will..."
- Numbered requirements (FR1, FR2, etc.)

**Non-Functional Requirements**:
- Performance requirements
- Security requirements
- Compliance requirements
- Scalability requirements

### Extract Acceptance Criteria

Look for success criteria:
- Checklist items ("- [ ] ...")
- "Success when...", "Complete when..."
- Testable conditions
- Expected outcomes

### Extract Technical Details

**Files to Modify/Create**:
- Mentioned file paths
- Suggested new files
- Areas of codebase to change

**Dependencies**:
- Libraries mentioned
- Services required
- External APIs
- Infrastructure dependencies

**Technical Approach**:
- Architecture decisions
- Design patterns
- Technology choices
- Implementation strategy

### Extract Risks and Considerations

- Potential issues mentioned
- Trade-offs discussed
- Open questions
- Concerns raised

## Step 10: Prepare Template Variables

Create variable map for template:

```json
{
  "work_id": "123",  // if provided
  "issue_url": "https://github.com/org/repo/issues/123",  // if work_id provided
  "title": "Implement user authentication with OAuth",
  "work_type": "feature",
  "date": "2025-01-15",
  "author": "username or from issue assignee",
  "slug": "user-auth-oauth",
  "summary": "Synthesized summary from merged context",
  "functional_requirements": ["FR1: ...", "FR2: ..."],
  "non_functional_requirements": ["NFR1: ...", "NFR2: ..."],
  "acceptance_criteria": ["Criterion 1", "Criterion 2"],
  "files": [{"path": "src/auth.ts", "description": "..."}],
  "dependencies": ["passport", "jsonwebtoken"],
  "technical_approach": "Detailed from merged context",
  "testing_strategy": "Extracted or inferred",
  "risks": [{"risk": "Risk 1", "mitigation": "Mitigation 1"}],
  "notes": "Additional context and decisions",
  "source_context": "Conversation + Issue #123",  // or just "Conversation"
  "conversation_highlights": "Key decisions from discussion"
}
```

## Step 11: Select Template

Map work type to template file:
- bug → `templates/spec-bug.md.template`
- feature → `templates/spec-feature.md.template`
- infrastructure → `templates/spec-infrastructure.md.template`
- api → `templates/spec-api.md.template`
- basic → `templates/spec-basic.md.template`

Read template file. If not found, fall back to spec-basic.md.template.

## Step 12: Fill Template

Replace template variables:
- `{{variable}}` → simple replacement
- `{{#array}}...{{/array}}` → loop over array
- `{{#object}}...{{/object}}` → loop over object properties

For Mustache-style templates, use simple string replacement:
- Replace `{{work_id}}` with value (if present)
- Replace `{{title}}` with value
- Replace `{{summary}}` with synthesized summary
- Handle arrays by repeating template section
- Handle conditionals by including/excluding sections

## Step 13: Add Frontmatter

Ensure frontmatter is at top:

**With work_id**:
```yaml
---
spec_id: WORK-00123-user-auth
work_id: 123
issue_url: https://github.com/org/repo/issues/123
title: Implement user authentication with OAuth
type: feature
status: draft
created: 2025-01-15
author: username
validated: false
source: conversation+issue
---
```

**Without work_id**:
```yaml
---
spec_id: SPEC-20250115143000-user-auth
title: User authentication design
type: feature
status: draft
created: 2025-01-15
author: username
validated: false
source: conversation
---
```

## Step 14: Save Spec File

Write spec to `{local_path}/{filename}`:
- Use `storage.local_path` from config (e.g., `/specs`)
- Create directory if doesn't exist
- Write file with UTF-8 encoding
- Set appropriate permissions

**Full path examples**:
- With work_id: `/specs/WORK-00123-user-auth-oauth.md`
- Without work_id: `/specs/SPEC-20250115143000-user-auth.md`

## Step 15: Link to GitHub Issue (If `work_id` Provided or Detected)

If `work_id` is provided AND `integration.update_issue_on_create` is true in config:

Comment on GitHub issue:
```markdown
📋 Specification Created

Specification generated for this issue:
- [WORK-00123-user-auth-oauth.md](/specs/WORK-00123-user-auth-oauth.md)

Source: Conversation context + Issue data

This spec will guide implementation and be validated before archival.
```

Use repo plugin or direct gh CLI:
```bash
gh issue comment $WORK_ID --body "..."
```

If comment fails, log warning but continue (non-critical).

## Step 16: Return Confirmation

Output success message with:
- Spec file path
- Template used
- Source (conversation, conversation+issue, etc.)
- GitHub comment status (if applicable)

Return JSON structure as defined in SKILL.md.

## Error Recovery

At each step, if error occurs:
1. Log detailed error
2. Determine if recoverable
3. Return structured error response
4. Suggest corrective action

## Example Execution

### Example 1: Context Only

```
Input:
  (no work_id)
  (no template - will auto-detect)
  conversation: "We need to implement OAuth2 authentication..."

Steps:
  1. ✓ Inputs valid
  2. ✓ Config loaded
  3. ✓ Conversation context extracted
  4. ✗ No work_id, skip issue fetch
  5. ✓ Context merged (conversation only)
  6. ✓ Auto-detected: feature
  7. ✓ Template selected: spec-feature.md.template
  8. ✓ Filename: SPEC-20250115143000-oauth-auth.md
  9. ✓ Context parsed
  10. ✓ Variables prepared
  11. ✓ Template selected
  12. ✓ Template filled
  13. ✓ Frontmatter added
  14. ✓ Saved to /specs/SPEC-20250115143000-oauth-auth.md
  15. ✗ No work_id, skip GitHub comment
  16. ✓ Success returned

Output:
  {
    "status": "success",
    "spec_path": "/specs/SPEC-20250115143000-oauth-auth.md",
    "template": "feature",
    "source": "conversation",
    "github_comment_added": false
  }
```

### Example 2: Context + Auto-Detected Issue

```
Input:
  (no work_id - will auto-detect from branch)
  (no template - will auto-detect)
  conversation: "We should use JWT tokens for the auth system..."
  current branch: feat/123-jwt-auth

Steps:
  1. ✓ Auto-detected issue #123 from branch (via repo cache)
  2. ✓ Inputs validated
  3. ✓ Config loaded
  4. ✓ Conversation context extracted
  5. ✓ Issue #123 fetched (with comments) via repo plugin
  6. ✓ Contexts merged (conversation + issue)
  7. ✓ Auto-detected: feature (from merged context)
  8. ✓ Filename: WORK-00123-jwt-auth-system.md
  9. ✓ Merged context parsed
  10. ✓ Variables prepared
  11. ✓ Template selected: spec-feature.md.template
  12. ✓ Template filled
  13. ✓ Frontmatter added
  14. ✓ Saved to /specs/WORK-00123-jwt-auth-system.md
  15. ✓ GitHub comment added to issue #123
  16. ✓ Success returned

Output:
  {
    "status": "success",
    "spec_path": "/specs/WORK-00123-jwt-auth-system.md",
    "work_id": "123",
    "issue_url": "https://github.com/org/repo/issues/123",
    "template": "feature",
    "source": "conversation+issue",
    "github_comment_added": true
  }
```

## Key Differences from `generate-from-issue.md`

| Aspect | generate-from-issue | generate-from-context |
|--------|---------------------|----------------------|
| Primary Source | Issue data | Conversation context |
| Issue Fetch | Always (required) | Optional (if work_id) |
| Context Merging | Issue only | Conversation + Issue |
| Template Detection | From issue labels | From merged context |
| Naming (no issue) | N/A | SPEC-{timestamp}-* |
| Use Case | Issue-driven | Planning discussions |
