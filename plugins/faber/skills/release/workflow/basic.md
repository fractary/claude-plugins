# Release Phase: Basic Workflow

This workflow implements the basic Release phase - creating pull requests and completing workflows.

## Steps

### 1. Post Release Start Notification
```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "release" "🚀 **Release Phase Started**

**Work ID**: \`${WORK_ID}\`
**Type**: ${WORK_TYPE}

Creating pull request and preparing for release..." '[]'
```

### 2. Build PR Description

Create comprehensive PR description with workflow context:

```bash
PR_TITLE="$WORK_TYPE: $WORK_ITEM_TITLE"

PR_BODY=$(cat <<EOF
## Summary
$WORK_ITEM_DESCRIPTION

## Specification
See [specification]($SPEC_URL) for detailed technical design.

## Key Decisions
$(echo "$KEY_DECISIONS" | jq -r '.[] | "- " + .')

## Changes
- **Files Modified**: ${#FILES_CHANGED[@]}
- **Commits**: ${#COMMITS[@]}

## Testing
$TEST_RESULTS_SUMMARY

## Related
- Closes #$SOURCE_ID
- Work ID: \`$WORK_ID\`
- Specification: $SPEC_FILE

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)
```

### 3. Create Pull Request

Use repo-manager to create PR:

```markdown
Use the @agent-fractary-repo:repo-manager agent with the following request:
{
  "operation": "create-pr",
  "parameters": {
    "title": "{pr_title}",
    "body": "{pr_body}",
    "head": "{branch_name}",
    "base": "main",
    "work_id": "{work_id}"
  }
}
```

Store PR information:
```bash
PR_NUMBER=$(echo "$PR_RESULT" | jq -r '.pr_number')
PR_URL=$(echo "$PR_RESULT" | jq -r '.pr_url')
echo "✅ Pull request created: #$PR_NUMBER"
echo "   URL: $PR_URL"
```

### 4. Check Auto-Merge

If auto_merge configured and autonomy allows:

```bash
if [ "$AUTO_MERGE" = "true" ] && [ "$AUTONOMY" = "autonomous" ]; then
    echo "🔄 Auto-merging pull request..."

    # Use repo-manager to merge
    # (repo-manager handles merge strategies and safety checks)

    MERGE_STATUS="merged"
    echo "✅ Pull request auto-merged"
else
    echo "⏸️  Pull request created, awaiting manual review/merge"
    MERGE_STATUS="open"
fi
```

### 5. Close/Update Work Item

Use work-manager to close the work item:

```markdown
Use the @agent-fractary-work:work-manager agent with the following request:
{
  "operation": "close-issue",
  "parameters": {
    "issue_number": "{source_id}",
    "comment": "✅ **Completed via FABER Workflow**\n\nPull Request: {pr_url}\nWork ID: `{work_id}`\n\nAll phases completed successfully."
  }
}
```

```bash
CLOSED_WORK=true
echo "✅ Work item closed: #$SOURCE_ID"
```

### 6. Update Session

```bash
RELEASE_DATA=$(cat <<EOF
{
  "pr_url": "$PR_URL",
  "pr_number": $PR_NUMBER,
  "merge_status": "$MERGE_STATUS",
  "closed_work": $CLOSED_WORK
}
EOF
)

"$CORE_SKILL/session-update.sh" "$WORK_ID" "release" "completed" "$RELEASE_DATA"
```

### 7. Post Release Complete

```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "release" "✅ **Release Phase Complete**

**Pull Request**: [#$PR_NUMBER]($PR_URL)
**Merge Status**: $MERGE_STATUS
**Work Item**: Closed

🎉 FABER workflow completed successfully!" '["view-pr"]'
```

### 8. Return Results

```bash
cat <<EOF
{
  "status": "success",
  "phase": "release",
  "pr_url": "$PR_URL",
  "pr_number": $PR_NUMBER,
  "merge_status": "$MERGE_STATUS",
  "closed_work": $CLOSED_WORK
}
EOF
```

## Success Criteria
- ✅ Pull request created successfully
- ✅ PR links to work item
- ✅ PR includes spec reference
- ✅ Work item closed/updated
- ✅ Session updated with release results
- ✅ Release complete notification posted

## Autonomy Levels

### Dry-Run
- Skip Release phase entirely
- Report what would have been done

### Assist
- Stop before Release phase
- Wait for user to run Release manually

### Guarded
- Create PR but await approval before merge
- workflow-manager pauses for approval

### Autonomous
- Create PR
- Auto-merge if configured
- Close work item
- Complete workflow automatically

## Configuration

```toml
[workflow.release]
auto_merge = false  # Auto-merge PRs (autonomous mode only)
auto_close = true   # Auto-close work items
delete_branch = true  # Delete branch after merge

[systems.repo_config]
default_branch = "main"  # Target branch for PRs
```

This basic Release workflow creates pull requests and completes FABER workflows while respecting autonomy gates.
