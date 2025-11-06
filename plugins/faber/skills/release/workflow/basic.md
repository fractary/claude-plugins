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
# Sanitize user-controlled inputs for PR title and body (prevent injection)
SAFE_TITLE=$(echo "$WORK_ITEM_TITLE" | tr -d '\n\r' | cut -c1-100 | sed 's/[`$"\\]/\\&/g')
SAFE_DESCRIPTION=$(echo "$WORK_ITEM_DESCRIPTION" | sed 's/[`$"\\]/\\&/g')

PR_TITLE="${WORK_TYPE}: ${SAFE_TITLE}"

PR_BODY=$(cat <<EOF
## Summary
${SAFE_DESCRIPTION}

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

**Security Note**: User-controlled inputs (work item titles, descriptions) are sanitized before use in PR titles/bodies to prevent injection attacks.

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

### 5. Update Documentation (Optional)

**If configured**, update current state documentation:

```bash
UPDATE_DOCUMENTATION=$(echo "$CONFIG_JSON" | jq -r '.workflow.release.update_documentation // "prompt"')

if [ "$UPDATE_DOCUMENTATION" = "prompt" ]; then
    echo "📚 Documentation update recommended."
    echo "Should documentation be updated now? (y/n/skip)"
    # Prompt user for confirmation
elif [ "$UPDATE_DOCUMENTATION" = "auto" ]; then
    echo "📚 Updating documentation..."

    Use the @agent-fractary-docs:docs-manager agent with the following request:
    {
      "operation": "update",
      "parameters": {
        "docs_type": "current_state",
        "issue_number": "{source_id}",
        "changes": "{summary_of_changes}"
      }
    }

    echo "✅ Documentation updated"
fi
```

**Note**: This updates current state docs (e.g., README, API docs), NOT specs.

### 6. Generate Deployment Doc (Optional)

**If configured**, generate deployment documentation:

```bash
GENERATE_DEPLOYMENT_DOC=$(echo "$CONFIG_JSON" | jq -r '.workflow.release.generate_deployment_doc // false')

if [ "$GENERATE_DEPLOYMENT_DOC" = "true" ]; then
    echo "📦 Generating deployment documentation..."

    Use the @agent-fractary-docs:docs-manager agent with the following request:
    {
      "operation": "generate-deployment",
      "parameters": {
        "issue_number": "{source_id}",
        "pr_number": "{pr_number}",
        "changes": "{deployment_changes}"
      }
    }

    echo "✅ Deployment doc generated"
fi
```

This is typically used for infrastructure changes.

### 7. Archive Workflow Artifacts

**If configured**, archive specs and logs:

```bash
ARCHIVE_SPECS=$(echo "$CONFIG_JSON" | jq -r '.workflow.release.archive_specs // true')
ARCHIVE_LOGS=$(echo "$CONFIG_JSON" | jq -r '.workflow.release.archive_logs // true')
CHECK_DOCS=$(echo "$CONFIG_JSON" | jq -r '.workflow.release.check_docs_updated // "warn"')
```

#### Archive Specifications

If `archive_specs` is enabled:

```markdown
Use the @agent-fractary-spec:spec-manager agent with the following request:
{
  "operation": "archive",
  "parameters": {
    "issue_number": "{source_id}",
    "check_docs": {CHECK_DOCS}
  }
}
```

The spec-manager will:
- Check if docs were updated (if check_docs != "skip")
- Upload specs to cloud storage
- Update archive index
- Comment on issue/PR with spec URLs
- Remove from local

```bash
echo "✅ Specifications archived"
```

#### Archive Logs

If `archive_logs` is enabled:

```markdown
Use the @agent-fractary-logs:log-manager agent with the following request:
{
  "operation": "archive",
  "parameters": {
    "issue_number": "{source_id}"
  }
}
```

The log-manager will:
- Collect all logs (session, build, test, debug)
- Compress large logs
- Upload to cloud storage
- Update archive index
- Comment on issue/PR with log URLs
- Remove from local

```bash
echo "✅ Logs archived"
```

**Alternative: Unified Archive**

Or use the unified archive-workflow skill:

```markdown
Use the @skill-fractary-faber:archive-workflow skill:
{
  "operation": "archive",
  "issue_number": "{source_id}",
  "skip_checks": true
}
```

This handles both specs and logs in one operation.

### 8. Delete Branch

**If configured**, delete the feature branch:

```bash
DELETE_BRANCH=$(echo "$CONFIG_JSON" | jq -r '.workflow.release.delete_branch // true')

if [ "$DELETE_BRANCH" = "true" ] && [ "$MERGE_STATUS" = "merged" ]; then
    echo "🗑️  Deleting feature branch..."

    Use the @agent-fractary-repo:repo-manager agent with the following request:
    {
      "operation": "delete-branch",
      "parameters": {
        "branch": "{branch_name}"
      }
    }

    echo "✅ Feature branch deleted"
fi
```

### 9. Close/Update Work Item

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

### 10. Update Session

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

### 11. Post Release Complete

```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "release" "✅ **Release Phase Complete**

**Pull Request**: [#$PR_NUMBER]($PR_URL)
**Merge Status**: $MERGE_STATUS
**Work Item**: Closed

🎉 FABER workflow completed successfully!" '["view-pr"]'
```

### 12. Return Results

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
