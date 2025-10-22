---
description: Execute complete FABER workflow (Frame → Architect → Build → Evaluate → Release) for any domain
allowed-tools: Bash, SlashCommand
---

# FABER Core Workflow

Execute the complete universal FABER (Frame → Architect → Build → Evaluate → Release) workflow for **any domain** (engineering, design, writing, data, etc.).

## Usage

```bash
/fractary/faber/core/faber <source_type> <source_id> <work_domain> [model_set] [auto_merge]
```

## Parameters

- `source_type` (required): Work tracking system - "github", "jira", "linear", "manual"
- `source_id` (required): External work item ID (e.g., GitHub issue number, Jira ticket ID)
- `work_domain` (required): Domain for this work - "engineering", "design", "writing", "data"
- `model_set` (optional): Model set to use - "base" (default) or "heavy"
- `auto_merge` (optional): Auto-merge on release - "true" or "false" (default)

## What This Command Does

This command orchestrates a complete FABER workflow for any domain:

1. **Frame Phase**: Fetch and classify the work item, set up environment
2. **Architect Phase**: Generate implementation specification
3. **Build Phase**: Implement the solution from specification
4. **Evaluate Phase**: Test and review with automatic issue resolution (retry loop)
5. **Release Phase**: Deploy/publish and create pull request

## Workflow

### Step 1: Validate Input

```bash
# Check required parameters
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "❌ Error: source_type, source_id, and work_domain are required"
    echo "Usage: /fractary/faber/core/faber <source_type> <source_id> <work_domain> [model_set] [auto_merge]"
    exit 1
fi

source_type="$1"
source_id="$2"
work_domain="$3"
model_set="${4:-base}"
auto_merge="${5:-false}"

# Validate source_type
case ${source_type} in
    github|jira|linear|manual)
        ;;
    *)
        echo "❌ Error: Invalid source_type '${source_type}'"
        echo "Valid options: github, jira, linear, manual"
        exit 1
        ;;
esac

# Validate work_domain
case ${work_domain} in
    engineering|design|writing|data)
        ;;
    *)
        echo "❌ Error: Invalid work_domain '${work_domain}'"
        echo "Valid options: engineering, design, writing, data"
        exit 1
        ;;
esac

echo "🚀 Starting FABER workflow"
echo "Source: ${source_type}/${source_id}"
echo "Domain: ${work_domain}"
echo "Model set: ${model_set}"
echo "Auto-merge: ${auto_merge}"
```

### Step 2: Generate Work ID

```bash
# Generate unique work identifier
work_id=$(python3 -c "import uuid; print(uuid.uuid4().hex[:8])")

echo "🆔 Work ID: ${work_id}"
```

### Step 3: Initialize Work State

```bash
# Initialize state with FABER schema
claude -p "/fractary/faber/core/state_init ${work_id} ${source_id} ${work_domain} ${model_set}"

if [ $? -ne 0 ]; then
    echo "❌ Failed to initialize work state"
    exit 1
fi

echo "✅ Work state initialized"
```

### Step 4: Post Initial Status

Post workflow start notification to work tracking system.

```bash
# Notify work item that workflow has started
claude -p "/fractary/faber/core/work_comment ${source_id} ${work_id} ops \"🚀 FABER Workflow Started

**Work ID**: \\\`${work_id}\\\`
**Domain**: ${work_domain}
**Model Set**: ${model_set}
**Auto-Merge**: ${auto_merge}

Executing phases:
1. ⏳ Frame - Fetch and classify work item
2. ⏸️ Architect - Generate specification
3. ⏸️ Build - Implement solution
4. ⏸️ Evaluate - Test and review
5. ⏸️ Release - Deploy/publish

---
🤖 Powered by FABER Core\""

echo "✅ Posted workflow start notification"
```

### Step 5: Invoke Universal Director

Execute the complete FABER workflow via the universal director.

```bash
# Execute complete FABER workflow via director agent
echo "🎬 Invoking universal-director..."

claude --agent faber-director "${work_id}" "${source_type}" "${source_id}" "${work_domain}" "${auto_merge}"
director_exit=$?

if [ ${director_exit} -ne 0 ]; then
    echo ""
    echo "❌ FABER workflow failed (exit code: ${director_exit})"

    # Post failure notification
    claude -p "/fractary/faber/core/work_comment ${source_id} ${work_id} ops \"❌ FABER Workflow Failed

One or more phases failed. Please check the workflow state for details.

**Work ID**: \\\`${work_id}\\\`

To investigate:
\\\`\\\`\\\`bash
claude -p \\\"/fractary/faber/core/state_load ${work_id}\\\"
\\\`\\\`\\\`

---
🤖 Powered by FABER Core\""

    exit 1
fi

echo ""
echo "✅ FABER workflow completed successfully"
```

### Step 6: Output Results

Load final state and output workflow summary.

```bash
# Load final state
state_json=$(claude -p "/fractary/faber/core/state_load ${work_id}")

if [ $? -eq 0 ]; then
    # Extract key results
    work_type=$(echo ${state_json} | jq -r .work_type)
    spec_file=$(echo ${state_json} | jq -r .architect.file_path)
    pr_url=$(echo ${state_json} | jq -r '.release.pr_url // "N/A"')

    # Domain-specific fields (try multiple domains)
    branch_name=$(echo ${state_json} | jq -r '
        .engineering.branch_name //
        .design.branch_name //
        .writing.branch_name //
        .data.branch_name //
        "N/A"
    ')

    echo ""
    echo "📊 FABER Workflow Summary"
    echo "========================"
    echo "Work ID: ${work_id}"
    echo "Source: ${source_type}/${source_id}"
    echo "Domain: ${work_domain}"
    echo "Type: ${work_type}"
    echo "Branch: ${branch_name}"
    echo "Specification: ${spec_file}"
    echo "Pull Request: ${pr_url}"
    echo ""
    echo "✅ All 5 phases completed successfully!"
fi
```

### Step 7: Post Final Status

Post workflow completion notification.

```bash
# Post final notification
if [ $? -eq 0 ]; then
    claude -p "/fractary/faber/core/work_comment ${source_id} ${work_id} ops \"🎉 FABER Workflow Complete

**Work ID**: \\\`${work_id}\\\`
**Domain**: ${work_domain}
**Type**: ${work_type}

## Workflow Summary

1. ✅ **Frame**: Work classified and environment prepared
2. ✅ **Architect**: Specification generated
3. ✅ **Build**: Solution implemented
4. ✅ **Evaluate**: Tests and review passed
5. ✅ **Release**: Deployed/published

## Results

- **Specification**: \\\`${spec_file}\\\`
- **Branch**: \\\`${branch_name}\\\`
- **Pull Request**: ${pr_url}

$([ \"${auto_merge}\" = \"false\" ] && echo \"Next: Review and merge pull request to complete.\")

---
🤖 Powered by FABER Core\""
fi
```

## Exit Codes

- `0` - Success: All phases completed
- `1` - Failure: One or more phases failed

## Examples

### Engineering Workflow (GitHub)

```bash
# Feature for GitHub issue #123
/fractary/faber/core/faber github 123 engineering

# Bug fix with heavy models
/fractary/faber/core/faber github 456 engineering heavy

# Hotfix with auto-merge
/fractary/faber/core/faber github 789 engineering base true
```

### Design Workflow (Jira)

```bash
# Design task from Jira
/fractary/faber/core/faber jira PROJ-123 design

# Design with auto-merge
/fractary/faber/core/faber jira PROJ-456 design base true
```

### Writing Workflow (Linear)

```bash
# Content from Linear
/fractary/faber/core/faber linear CONT-123 writing

# Content with heavy models
/fractary/faber/core/faber linear CONT-456 writing heavy
```

### Data Workflow (GitHub)

```bash
# Data pipeline from GitHub
/fractary/faber/core/faber github 123 data

# Data analysis with auto-merge
/fractary/faber/core/faber github 456 data base true
```

## Output

```
🚀 Starting FABER workflow
Source: github/123
Domain: engineering
Model set: base
Auto-merge: false
🆔 Work ID: abc12345
✅ Work state initialized
✅ Posted workflow start notification
🎬 Invoking universal-director...

======================================
📋 Phase 1: Frame
======================================
✅ Frame phase complete

======================================
📐 Phase 2: Architect
======================================
✅ Architect phase complete

======================================
🔨 Phase 3: Build
======================================
✅ Build phase complete

======================================
🧪 Phase 4: Evaluate (with retry loop)
======================================
✅ Evaluate phase complete - GO decision

======================================
🚀 Phase 5: Release
======================================
✅ Release phase complete

======================================
🎉 FABER Workflow Complete
======================================

📊 FABER Workflow Summary
========================
Work ID: abc12345
Source: github/123
Domain: engineering
Type: /feature
Branch: feat-123-abc12345-add-export
Specification: docs/specs/issue-123-feature-abc12345-add-export.md
Pull Request: https://github.com/owner/repo/pull/45

✅ All 5 phases completed successfully!
```

## What Gets Created

After successful execution:

1. **Work State**: `.faber/state/{work_id}.json`
2. **Specification**: Domain-specific location (e.g., `docs/specs/`, `designs/`, `content/`)
3. **Implementation**: Domain-specific artifacts (code, designs, content, data pipelines)
4. **Tests/Reviews**: Test results and review evidence
5. **Documentation**: Domain-specific documentation
6. **Pull Request/Release**: Deployment artifact (PR, published design, published content, etc.)

## FABER Phases Executed

### 1. Frame Phase
- Fetch work item from tracking system
- Classify work type (bug, feature, chore, patch)
- Set up domain-specific environment
- Allocate resources as needed
- Post Frame start/complete notifications

### 2. Architect Phase
- Generate detailed implementation specification
- Create spec file in domain-appropriate location
- Commit and push specification
- Post Architect start/complete notifications

### 3. Build Phase
- Implement solution from specification
- Follow domain best practices
- Create tests/reviews as appropriate
- Commit implementation
- Push changes to remote
- Post Build start/complete notifications

### 4. Evaluate Phase (with retry loop)
- Run domain-specific tests
- Execute domain-specific review
- Make go/no-go decision
- If no-go and retries remain: loop back to Build
- If no-go and no retries: fail workflow
- Post Evaluate results

### 5. Release Phase
- Create pull request (or domain equivalent)
- Optional: Auto-merge to main
- Upload artifacts as needed
- Post Release start/complete notifications
- Optionally close work item

## Director Coordination

The universal-director orchestrates these managers:

- **frame-manager**: Frame phase operations
- **architect-manager**: Architect phase operations
- **build-manager**: Build phase operations
- **evaluate-manager**: Evaluate phase operations (with retry loop)
- **release-manager**: Release phase operations

These managers coordinate with:
- **work-manager**: Work tracking operations
- **repo-manager**: Version control operations
- **file-manager**: File storage operations
- **Domain bundles**: Domain-specific operations

## Domain Support

FABER Core supports multiple domains:

### Engineering (Implemented)
- Full FABER workflow
- Git worktrees for isolation
- Comprehensive testing
- Code review with auto-resolution
- Pull request creation

### Design (Future)
- Design workspace setup
- Design briefs and style guides
- Asset creation
- Design review
- Asset publication

### Writing (Future)
- Content workspace setup
- Content outlines
- Content writing and editing
- Content review
- Content publication

### Data (Future)
- Data workspace setup
- Pipeline design
- Pipeline implementation
- Data quality checks
- Pipeline deployment

## Error Handling

If any phase fails:
- Error logged with context
- Error notification posted to work tracking
- Work state preserved for debugging
- Environment/artifacts preserved for inspection
- Exit with non-zero code

## Recovery

To resume after failure:
```bash
# Load state to see where it failed
state_json=$(claude -p "/fractary/faber/core/state_load abc12345")

# Check phase statuses
echo ${state_json} | jq '{
  frame: .frame.status,
  architect: .architect.status,
  build: .build.status,
  evaluate: .evaluate.status,
  release: .release.status
}'

# Continue from specific phase (manual recovery)
# (Invoke specific phase managers as needed)
```

## Notes

- This command is the main entry point for FABER workflows
- It delegates all work to the universal-director agent
- The director coordinates managers, which use experts and domain bundles
- All work is tracked in state files
- Domain bundles provide domain-specific implementations

## Dependencies

- Python 3 (for UUID generation)
- Claude Code with agent support
- All FABER core components:
  - universal-director agent
  - 5 workflow managers (frame, architect, build, evaluate, release)
  - 3 system managers (work, repo, file)
  - 3 core experts (github-work, github-repo, r2)
  - Installed domain bundles (e.g., engineering)
- Work tracking system CLI (gh for GitHub, etc.)
- Version control (git)

## Configuration

Reads from `.faber.config.json`:

```json
{
  "systems": {
    "work_system": "github",
    "repo_system": "github",
    "file_system": "r2"
  },
  "bundles": {
    "installed": ["fractary/faber/engineering"],
    "available_directors": {
      "engineering": ["engineering-web-director", "universal-director"],
      "design": ["universal-director"]
    }
  },
  "workflow": {
    "max_evaluate_retries": 3,
    "auto_merge": false
  }
}
```

## See Also

- Engineering-specific workflow: `/fractary/faber/engineering/faber`
- Phase commands: `/fractary/faber/core/frame`, `/architect`, `/build`, `/evaluate`, `/release`
- System operations: `/fractary/faber/core/work_*`, `/repo_*`, `/file_*`
- State commands: `/fractary/faber/core/state_*`
