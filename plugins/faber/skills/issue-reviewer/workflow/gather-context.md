# Gather Context

This workflow step collects all necessary context for the issue review analysis.

## Overview

Before analyzing implementation completeness, we need to gather:
1. Issue details (title, description, all comments)
2. Specification content (if exists)
3. Code changes (diff against main/base branch)
4. Test files added or modified

## Steps

### 1. Fetch Issue Details

Use the work plugin to get complete issue information:

```bash
# Get issue details including all comments
scripts/gather-issue-context.sh "$WORK_ID"
```

**Expected Output:**
```json
{
  "issue": {
    "number": 233,
    "title": "Automatic process during evaluate phase...",
    "body": "I've surprisingly found many times...",
    "state": "open",
    "labels": ["enhancement"],
    "author": "jmcwilliam",
    "created_at": "2025-12-05T14:29:54Z"
  },
  "comments": [
    {
      "author": "claude-bot",
      "body": "Specification created...",
      "created_at": "2025-12-05T15:00:00Z"
    }
  ]
}
```

**If Issue Not Found:**
- Return failure immediately
- Cannot proceed without work item context

---

### 2. Fetch Specification

Look for related specifications:

```bash
# Find specs for this work ID
scripts/gather-spec-context.sh "$WORK_ID"
```

**Search Locations:**
1. `specs/WORK-{work_id:05d}-*.md` (standard naming)
2. `docs/specs/*{work_id}*.md` (alternate location)
3. Referenced in issue comments

**Expected Output:**
```json
{
  "found": true,
  "spec_path": "specs/WORK-00233-01-auto-issue-review.md",
  "spec_content": "# Specification: Automatic Issue Review...",
  "requirements": [
    {"id": "FR-1", "text": "Automatic invocation"},
    {"id": "FR-2", "text": "Input gathering"},
    ...
  ],
  "acceptance_criteria": [
    {"id": "AC-1", "text": "Skill file created"},
    ...
  ]
}
```

**If Spec Not Found:**
- Log warning: "No specification found, will analyze against issue description"
- Continue with issue description as primary source
- Set `spec_found: false` in context

---

### 3. Gather Code Changes

Get the diff between current branch and main:

```bash
# Get code changes since branching from main
scripts/gather-code-changes.sh
```

**Process:**
1. Determine base branch (main or master)
2. Get diff: `git diff {base}...HEAD`
3. Parse changed files
4. Identify file types (source, test, docs, config)
5. Summarize large files (>500 lines)

**Expected Output:**
```json
{
  "base_branch": "main",
  "branch_name": "feat/233-automatic-process-during-evaluate-phase-",
  "files_changed": [
    {
      "path": "plugins/faber/skills/issue-reviewer/SKILL.md",
      "status": "added",
      "additions": 150,
      "deletions": 0,
      "type": "skill"
    },
    {
      "path": "plugins/faber/agents/faber-manager.md",
      "status": "modified",
      "additions": 25,
      "deletions": 5,
      "type": "agent"
    }
  ],
  "summary": {
    "total_files": 12,
    "added": 10,
    "modified": 2,
    "deleted": 0,
    "total_additions": 850,
    "total_deletions": 10
  },
  "test_files": [
    "tests/issue-reviewer/gather-context.test.sh"
  ],
  "diff_content": "..." // Full diff or summarized
}
```

**For Large Diffs:**
- Files over 500 lines: Include first 100 and last 50 lines with summary
- Total diff over 5000 lines: Prioritize key file types (source > test > docs)
- Log warning if context may be incomplete

---

### 4. Identify PR Details (If Exists)

Check if a PR has been created:

```bash
# Check for existing PR
gh pr list --head "$(git branch --show-current)" --json number,title,body,url 2>/dev/null
```

**If PR Exists:**
```json
{
  "pr_exists": true,
  "pr_number": 234,
  "pr_title": "feat: Add issue-reviewer skill for FABER evaluate phase",
  "pr_body": "...",
  "pr_url": "https://github.com/fractary/claude-plugins/pull/234"
}
```

---

### 5. Aggregate Context

Combine all gathered context:

```json
{
  "work_id": "233",
  "gathered_at": "2025-12-05T15:30:00Z",
  "issue": { ... },
  "comments": [ ... ],
  "spec": {
    "found": true,
    "path": "specs/WORK-00233-01-auto-issue-review.md",
    "requirements": [ ... ],
    "acceptance_criteria": [ ... ]
  },
  "code_changes": {
    "files": [ ... ],
    "summary": { ... },
    "test_files": [ ... ]
  },
  "pr": {
    "exists": false
  },
  "context_quality": {
    "complete": true,
    "warnings": []
  }
}
```

## Error Handling

**Network Errors:**
```bash
# Retry with exponential backoff
for attempt in 1 2 3; do
  result=$(fetch_issue "$WORK_ID")
  if [ $? -eq 0 ]; then break; fi
  sleep $((attempt * 2))
done
```

**Missing Data:**
- Issue: FAIL (required)
- Spec: WARN + continue
- PR: INFO only
- Diff: WARN if incomplete

## Output

Return aggregated context to the skill for analysis steps.

```bash
# Save context for subsequent steps
echo "$CONTEXT_JSON" > /tmp/issue-reviewer-context.json
```
