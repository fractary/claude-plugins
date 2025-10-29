---
name: repo:branch
description: Create, delete, and manage Git branches
---

# /repo:branch - Branch Management Command

Manage Git branches: create feature branches, delete old branches, and list branch status.

## Usage

```bash
# Create a new branch
/repo:branch create <work_id> <description> [--base <branch>]

# Delete a branch
/repo:branch delete <branch_name> [--location local|remote|both] [--force]

# List stale branches
/repo:branch list [--stale] [--merged]
```

## Examples

```bash
# Create feature branch from work item
/repo:branch create 123 "add user export feature"
/repo:branch create 456 "fix authentication bug" --base develop

# Delete merged feature branch
/repo:branch delete feat/old-feature
/repo:branch delete feat/123-export --location both

# List stale branches
/repo:branch list --stale --merged
```

## Command Implementation

This command parses user input and invokes the repo-manager agent with appropriate operations.

### Subcommand: create

**Purpose**: Generate semantic branch name and create branch

**Arguments**:
- `work_id` (required): Work item identifier
- `description` (required): Brief feature description
- `--base` (optional): Base branch name (default: from config)
- `--prefix` (optional): Branch prefix override (feat|fix|chore|docs|test|refactor|style|perf)

**Workflow**:
1. Parse arguments
2. Determine branch prefix from description or --prefix flag
3. Invoke agent: generate-branch-name operation
4. Invoke agent: create-branch operation
5. Display created branch name and commit SHA

**Example Flow**:
```
User: /repo:branch create 123 "add CSV export"

1. Generate name:
   {
     "operation": "generate-branch-name",
     "parameters": {
       "work_id": "123",
       "prefix": "feat",
       "description": "add CSV export"
     }
   }
   Result: "feat/123-add-csv-export"

2. Create branch:
   {
     "operation": "create-branch",
     "parameters": {
       "branch_name": "feat/123-add-csv-export",
       "base_branch": "main"
     }
   }

3. Display:
   ✅ Branch created: feat/123-add-csv-export
   Base branch: main
   Commit SHA: abc123...
```

### Subcommand: delete

**Purpose**: Delete branches locally and/or remotely

**Arguments**:
- `branch_name` (required): Branch to delete
- `--location` (optional): Where to delete: local|remote|both (default: local)
- `--force` (optional): Force delete even if unmerged

**Workflow**:
1. Parse arguments
2. Validate branch name
3. Invoke agent: delete-branch operation
4. Display deletion status

**Safety Checks**:
- Protected branches are rejected
- Unmerged branches require --force
- Confirmation prompt shown

**Example Flow**:
```
User: /repo:branch delete feat/old-feature --location both

1. Delete branch:
   {
     "operation": "delete-branch",
     "parameters": {
       "branch_name": "feat/old-feature",
       "location": "both",
       "force": false
     }
   }

2. Display:
   ✅ Branch deleted: feat/old-feature
   Deleted locally: true
   Deleted remotely: true
```

### Subcommand: list

**Purpose**: List stale or merged branches

**Arguments**:
- `--stale` (optional): Show branches with no recent activity
- `--merged` (optional): Show fully merged branches
- `--days` (optional): Inactivity threshold in days (default: 30)

**Workflow**:
1. Parse arguments
2. Invoke agent: list-stale-branches operation
3. Format and display results

**Example Flow**:
```
User: /repo:branch list --merged

1. List stale:
   {
     "operation": "list-stale-branches",
     "parameters": {
       "merged": true,
       "exclude_protected": true
     }
   }

2. Display:
   Stale Branches (3 found):

   Fully Merged:
   - feat/123-old-feature (merged 45 days ago)
   - fix/456-bug (merged 60 days ago)
   - chore/789-deps (merged 90 days ago)

   Use /repo:branch delete <name> to clean up
```

## Error Handling

**Invalid Arguments**:
```
Error: work_id is required
Usage: /repo:branch create <work_id> <description>
```

**Protected Branch**:
```
Error: Cannot delete protected branch: main
Protected branches: main, master, production
```

**Branch Not Found**:
```
Error: Branch not found: feat/nonexistent
Use /repo:branch list to see available branches
```

**Unmerged Commits**:
```
Warning: Branch has unmerged commits: feat/123-work
Use --force to delete anyway (this will lose changes)
```

## Integration

**Called By**: User via CLI

**Calls**: repo-manager agent with operations:
- generate-branch-name
- create-branch
- delete-branch
- list-stale-branches

**Returns**: Human-readable output formatted for terminal display

## Notes

- Branch names follow semantic conventions automatically
- Protected branches (main, master, production) cannot be deleted
- Default base branch comes from configuration
- Stale branch detection respects configuration thresholds
- All operations respect FABER workflow context if present
