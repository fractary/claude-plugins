---
name: fractary-repo:commit
description: Create semantic commits with conventional commit format and FABER metadata
---

# /repo:commit - Commit Creation Command

Create semantic, well-formatted Git commits following conventional commit standards with FABER metadata.

## Usage

```bash
# Auto-generate commit from changes (no arguments required)
/repo:commit

# Create a commit with explicit message and type
/repo:commit <message> --type <type> [options]
```

## Automatic Mode (No Arguments)

When invoked without arguments, the command will:
1. Analyze both staged and unstaged git changes
2. Review recent commit history for style consistency
3. Automatically generate an appropriate commit message
4. Automatically determine the correct commit type
5. Create the commit

**Example:**
```bash
# Automatically analyze changes and create commit
/repo:commit
```

## Manual Mode (Explicit Arguments)

When you want full control over the commit message and type.

### Required Flags

- `--type`: Commit type (feat|fix|chore|docs|test|refactor|style|perf)

### Optional Flags

- `--work-id <id>`: Work item identifier (required for FABER workflows)
- `--context <context>`: Author context (architect|implementor|tester|reviewer)
- `--scope <scope>`: Conventional commit scope
- `--breaking`: Mark as breaking change
- `--description <text>`: Extended description for commit body

### Examples

```bash
# Feature commit
/repo:commit "Add CSV export functionality" --type feat --work-id 123

# Bug fix with scope
/repo:commit "Fix timeout bug" --type fix --scope auth --work-id 456

# Documentation update
/repo:commit "Update API docs" --type docs

# FABER commit with full metadata
/repo:commit "Implement user export" --type feat --work-id 123 --context implementor

# Breaking change
/repo:commit "Change API signature" --type feat --breaking --work-id 789
```

## Command Implementation

This command creates properly formatted commits with metadata.

### Workflow

**1. Check for Arguments**:
- If no arguments provided → Enter **Automatic Mode**
- If arguments provided → Enter **Manual Mode**

### Automatic Mode Workflow

**1. Analyze Git State**:
- Run `git status` to see staged and unstaged changes
- Run `git diff` for staged changes
- Run `git diff` for unstaged changes
- Run `git log` to review recent commit style

**2. Generate Commit Details**:
- Analyze the nature of changes (new feature, bug fix, refactor, docs, etc.)
- Determine appropriate commit type automatically
- Draft concise commit message (< 72 chars) following conventional commits
- Identify scope if applicable
- Ensure message follows repository commit style

**3. Stage Changes if Needed**:
- If relevant unstaged files exist, add them to staging area
- Skip files that should not be committed (e.g., .env, credentials)

**4. Create Commit**:
- Invoke repo-manager agent with generated parameters
- Include Claude Code attribution and co-author

**5. Display Result**:
```
✅ Commit created successfully

Commit SHA: abc123def456...
Type: docs
Message: docs(faber-cloud): Reorganize documentation structure

Changes:
- Moved phase completion docs to docs/specs/status/
- Created centralized architecture document
- 7 files added, 7 files deleted

To push: /repo:push
```

### Manual Mode Workflow

**1. Parse Arguments**:
- Extract message (first positional argument)
- Parse --type flag (required)
- Parse optional flags (--work-id, --context, --scope, --breaking, --description)

**2. Validate Inputs**:
- Check message is non-empty
- Verify type is valid (feat|fix|chore|docs|test|refactor|style|perf)
- Validate message length (< 72 chars for summary)
- Check work-id if provided

**3. Invoke Agent**:
```json
{
  "operation": "create-commit",
  "parameters": {
    "message": "Add CSV export functionality",
    "type": "feat",
    "work_id": "123",
    "author_context": "implementor",
    "scope": "export",
    "breaking": false
  }
}
```

**4. Display Result**:
```
✅ Commit created successfully

Commit SHA: abc123def456...
Type: feat
Message: feat(export): Add CSV export functionality
Work Item: #123

To push: /repo:push
```

## Commit Message Format

The command generates commits following Conventional Commits + FABER metadata:

```
<type>[optional scope]: <description>

[optional body]

Work-Item: #<work_id>
Author-Context: <context>

[optional footer]
```

### Example Generated Commit

```
feat(export): Add CSV export functionality

Implements user data export to CSV format with configurable columns
and filtering options.

Work-Item: #123
Author-Context: implementor
Phase: build

Closes #123
```

## Commit Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation only
- **style**: Code style changes (formatting, etc.)
- **refactor**: Code refactoring
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

## Error Handling

**No Changes to Commit**:
```
Error: No changes to commit
Stage your changes first: git add <files>
```

**Invalid Type (Manual Mode)**:
```
Error: Invalid commit type: invalid
Valid types: feat, fix, chore, docs, test, refactor, style, perf
```

**Message Too Long (Manual Mode)**:
```
Error: Commit message exceeds 72 characters
Keep the summary concise, use --description for details
```

**Missing Type Flag (Manual Mode with Message)**:
```
Error: --type flag is required when providing a commit message
Usage: /repo:commit <message> --type <type>

Or use automatic mode: /repo:commit (no arguments)
```

**Invalid Author Context**:
```
Error: Invalid author context: invalid
Valid contexts: architect, implementor, tester, reviewer
```

## FABER Integration

When used within FABER workflows, the command automatically:
- Includes author context from workflow phase
- Links to work item being processed
- Adds phase metadata
- Formats commit for traceability

**FABER Phases and Contexts**:
- Frame → architect (creating specifications)
- Architect → architect (designing solution)
- Build → implementor (implementing features)
- Evaluate → tester (adding tests, fixing bugs)
- Release → reviewer (reviewing and merging)

## Advanced Usage

**Multi-line Commit**:
```bash
/repo:commit "Add user authentication" \
  --type feat \
  --work-id 123 \
  --description "Implements JWT-based authentication with refresh tokens. Includes middleware for route protection and role-based access control."
```

**Breaking Change**:
```bash
/repo:commit "Remove deprecated API endpoints" \
  --type feat \
  --breaking \
  --work-id 456 \
  --description "BREAKING CHANGE: Removed /api/v1/legacy endpoints. Migrate to /api/v2/"
```

**Scoped Fix**:
```bash
/repo:commit "Prevent SQL injection" \
  --type fix \
  --scope database \
  --work-id 789
```

## Integration

**Called By**: User via CLI

**Calls**: repo-manager agent with operation:
- create-commit

**Returns**: Human-readable output with commit SHA and details

## Best Practices

1. **Use automatic mode for quick commits**: Just run `/repo:commit` without arguments
2. **Use manual mode for precise control**: When you need specific FABER metadata or work items
3. **Keep summaries concise**: < 72 characters
4. **Use imperative mood**: "Add feature" not "Added feature"
5. **Include work item**: Always use --work-id for traceability in FABER workflows
6. **Choose correct type**: Helps with changelog generation
7. **Use scopes**: Helps identify which part of codebase changed
8. **Mark breaking changes**: Critical for semantic versioning

## Notes

- **Automatic mode** analyzes changes and generates commit message/type automatically
- **Manual mode** requires explicit --type flag when providing a message
- Commits are created on current branch
- Work item references enable automatic issue closing
- FABER metadata aids in workflow traceability
- Conventional format enables automated changelog generation
- GPG signing respects configuration settings
- Automatic mode follows the same commit style as Claude Code's built-in git commit behavior
