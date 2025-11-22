# Build Phase: Cloud Infrastructure Workflow

This workflow implements the Build phase for cloud infrastructure work items - generating and implementing Infrastructure as Code from specifications.

## Overview

This workflow is used when FABER is processing infrastructure-related work items. It bridges the software development workflow (Frame → Architect → Build) with cloud infrastructure implementation using the faber-cloud plugin.

## When This Workflow Is Used

This workflow should be selected when:
- Work item involves cloud infrastructure changes
- Tags include: `infrastructure`, `cloud`, `aws`, `terraform`
- Work type indicates infrastructure work
- Configuration specifies cloud domain

## Steps

### 1. Post Build Start Notification

```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "build" "🔨 **Build Phase Started (Cloud Infrastructure)**

**Work ID**: \`${WORK_ID}\`
**Type**: ${WORK_TYPE}
$([ "$RETRY_COUNT" -gt 0 ] && echo "**Retry**: Attempt $((RETRY_COUNT + 1))")

Implementing infrastructure from specification..." '[]'
```

### 2. Load Specification

```bash
# Read spec file from architect phase
SPEC_FILE=$(echo "$ARCHITECT_CONTEXT" | jq -r '.spec_file')

if [ ! -f "$SPEC_FILE" ]; then
    echo "❌ Specification file not found: $SPEC_FILE"
    exit 1
fi

SPEC_CONTENT=$(cat "$SPEC_FILE")
echo "✅ Loaded specification: $SPEC_FILE"
```

### 3. Check for Retry Context

If this is a retry from the Evaluate phase:

```bash
if [ "$RETRY_COUNT" -gt 0 ]; then
    echo "🔄 Retry Context: $RETRY_CONTEXT"
    echo "Previous build failed evaluation - addressing issues..."

    # Extract debugger findings or test failures
    # This context helps the engineer know what to fix
fi
```

### 4. Invoke Infrastructure Engineer

Use the faber-cloud plugin's engineer skill to generate/update Terraform code:

```bash
# Prepare context for engineer
ENGINEER_INSTRUCTIONS="$SPEC_FILE"

# If retry, add debugger context
if [ "$RETRY_COUNT" -gt 0 ]; then
    ENGINEER_INSTRUCTIONS="$SPEC_FILE - Fix issues: $RETRY_CONTEXT"
fi

echo "🔧 Invoking infrastructure engineer..."
echo "Instructions: $ENGINEER_INSTRUCTIONS"
```

Invoke the engineer skill via SlashCommand:

```markdown
Use the /fractary-faber-cloud:engineer command with the following context:

"$ENGINEER_INSTRUCTIONS"

This will:
1. Read the FABER specification
2. Extract infrastructure requirements
3. Generate Terraform code (or update existing code if retry)
4. Validate the generated code
5. Return results
```

**Important:** The engineer skill will:
- Parse the spec file path intelligently
- Generate appropriate Terraform resources
- Always validate the code
- Handle both fresh generation and updates

### 5. Verify Engineer Results

```bash
# Check that engineer completed successfully
if [ $? -ne 0 ]; then
    echo "❌ Infrastructure engineer failed"
    # Update state with failure
    "$CORE_SKILL/state-update-phase.sh" "build" "failed" "{\"error\": \"Engineer failed\"}"
    exit 1
fi

# Verify Terraform files exist
TF_DIR="./infrastructure/terraform"
if [ ! -f "$TF_DIR/main.tf" ]; then
    echo "❌ Terraform main.tf not generated"
    exit 1
fi

echo "✅ Infrastructure code generated and validated"
```

### 6. Commit Infrastructure Code

Use repo-manager to commit the generated Terraform:

```markdown
Use the @agent-fractary-repo:repo-manager agent with the following request:
{
  "operation": "create-commit",
  "parameters": {
    "message": "infra: {work_item_title}",
    "type": "infra",
    "work_id": "{work_id}",
    "files": ["infrastructure/terraform/*.tf"]
  }
}
```

Store commit information:

```bash
COMMIT_SHA=$(echo "$COMMIT_RESULT" | jq -r '.commit_sha')
COMMIT_URL=$(echo "$COMMIT_RESULT" | jq -r '.commit_url')

echo "✅ Infrastructure committed: $COMMIT_SHA"
```

### 7. Update Session

```bash
BUILD_DATA=$(cat <<EOF
{
  "commits": ["$COMMIT_SHA"],
  "terraform_files": [
    "main.tf",
    "variables.tf",
    "outputs.tf"
  ],
  "validation_status": "passed",
  "retry_count": $RETRY_COUNT
}
EOF
)

"$CORE_SKILL/state-update-phase.sh" "build" "completed" "$BUILD_DATA"
```

### 8. Post Build Complete

```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "build" "✅ **Build Phase Complete (Cloud Infrastructure)**

**Commit**: [\`${COMMIT_SHA:0:7}\`]($COMMIT_URL)
**Terraform Files**: main.tf, variables.tf, outputs.tf
**Validation**: ✅ Passed

Infrastructure code generated and committed. Ready for evaluation..." '[]'
```

### 9. Return Results

```bash
cat <<EOF
{
  "status": "success",
  "phase": "build",
  "domain": "cloud",
  "commits": ["$COMMIT_SHA"],
  "terraform_files": [
    "main.tf",
    "variables.tf",
    "outputs.tf"
  ],
  "validation_passed": true,
  "retry_count": $RETRY_COUNT
}
EOF
```

## Success Criteria

- ✅ Specification loaded from architect phase
- ✅ Infrastructure requirements extracted
- ✅ Terraform code generated via faber-cloud engineer
- ✅ Code validated (terraform fmt + validate)
- ✅ Changes committed to version control
- ✅ Session updated with build results
- ✅ Build complete notification posted

## Integration with Evaluate Phase

After Build completes, the Evaluate phase will:
1. Run infrastructure tests (via `/fractary-faber-cloud:test`)
2. Check security, cost, compliance
3. If tests fail → retry Build with error context
4. If tests pass → proceed to Release

## Retry Handling

When invoked as a retry (retry_count > 0):

1. **Load Retry Context**
   - Review evaluation failures
   - Extract specific issues (IAM errors, validation failures, etc.)

2. **Pass Context to Engineer**
   - Include retry context in engineer instructions
   - Engineer will update existing Terraform to fix issues
   - Example: "Fix IAM permissions - Lambda needs s3:PutObject"

3. **Re-validate**
   - Engineer always validates
   - Ensures fixes are correct

4. **Commit Fix**
   - Commit message indicates this is a fix
   - Links to original work item

## Configuration

This workflow respects FABER configuration:

```toml
[workflow.skills]
build = "cloud"  # Selects this workflow

[build]
commit_on_success = true  # Commit after generation
```

**Note:** Validation is always performed for cloud infrastructure - there is no config option to disable it. This ensures all generated Terraform code is validated before committing.

## Error Handling

### Engineer Failure

If the engineer skill fails:
```bash
# Error is already reported by engineer
# Update state and exit
"$CORE_SKILL/state-update-phase.sh" "build" "failed" \
  "{\"error\": \"Infrastructure engineer failed\", \"retry_count\": $RETRY_COUNT}"
exit 1
```

### Validation Failure

If Terraform validation fails:
```bash
# Engineer will have already reported validation errors
# State update and exit
"$CORE_SKILL/state-update-phase.sh" "build" "failed" \
  "{\"error\": \"Terraform validation failed\", \"retry_count\": $RETRY_COUNT}"
exit 1
```

### Commit Failure

If commit fails:
```bash
# Code generated but not committed
# Report error, user can investigate
echo "❌ Commit failed - Terraform code generated but not committed"
"$CORE_SKILL/state-update-phase.sh" "build" "failed" \
  "{\"error\": \"Git commit failed\", \"retry_count\": $RETRY_COUNT}"
exit 1
```

## Example: Full Flow

**Work Item #456: "Add S3 bucket for user uploads"**

1. **Frame Phase**: Fetches issue, classifies as infrastructure
2. **Architect Phase**: Creates `.faber/specs/456-add-s3-bucket.md`
3. **Build Phase (cloud.md)**:
   - Reads spec: `.faber/specs/456-add-s3-bucket.md`
   - Invokes: `/fractary-faber-cloud:engineer ".faber/specs/456-add-s3-bucket.md"`
   - Engineer generates:
     - `infrastructure/terraform/main.tf` (S3 bucket, encryption, versioning)
     - `infrastructure/terraform/variables.tf`
     - `infrastructure/terraform/outputs.tf`
   - Validates: ✅ terraform fmt + validate pass
   - Commits: "infra: Add S3 bucket for user uploads"
4. **Evaluate Phase**: Tests infrastructure (security scan, cost check)
5. **Release Phase**: Creates PR, applies to test environment

## Notes

- This workflow delegates actual Terraform generation to faber-cloud plugin
- Keeps FABER focused on orchestration, not implementation details
- Engineer skill handles all Terraform-specific logic
- Always validates - no exceptions
- Supports retry loop via retry_context

This cloud Build workflow bridges FABER's software development workflow with infrastructure implementation while maintaining clean separation of concerns.
