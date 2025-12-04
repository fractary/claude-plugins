# FABER Project Integration Guide

**Audience**: Teams adopting FABER workflow for their existing projects

**Goal**: Map your current development workflow to FABER configuration

## Overview

FABER provides a universal issue-centric workflow:
- **Frame** → **Architect** → **Build** → **Evaluate** → **Release**
- Core artifacts: **Issue** + **Branch** + **Spec**

This guide helps you integrate FABER into your existing project by mapping your current practices to FABER's structure.

## ⚠️ Important: Direct Command Usage

**DO NOT create wrapper agents or commands for FABER**. The FABER plugin already provides:
- ✅ Complete workflow orchestration via `faber-manager` agent
- ✅ Ready-to-use commands (`/fractary-faber:init`, `/fractary-faber:run`, etc.)
- ✅ Full integration with work, repo, spec, and logs plugins

**Use FABER commands directly:**
```bash
✅ /fractary-faber:run --work-id 123                   # Correct: Use the plugin command directly
✅ /fractary-faber:run --work-id 123 --phase frame     # Correct: Run individual phases
✅ /fractary-faber:audit                               # Correct: Validate configuration

❌ /my-project:faber 123                               # Wrong: Don't create wrapper commands
❌ @agent my-project-faber-manager                     # Wrong: Don't create wrapper agents
```

The `faber-manager` agent is already the universal workflow orchestrator. Additional wrappers add unnecessary complexity without benefits.

## Integration Steps

### Step 1: Understand Your Current Workflow

Document your current development process. Most teams follow some variation of:

**Example: Typical Software Workflow**
```
1. Create GitHub issue
2. Create feature branch
3. Write design document (optional)
4. Implement solution
5. Run tests locally
6. Push and create PR
7. CI runs (tests, lint, security)
8. Code review
9. Merge to main
10. Deploy
```

### Step 2: Map to FABER Phases

Map your workflow steps to FABER's 5 phases:

| Your Step | FABER Phase | What Happens |
|-----------|-------------|--------------|
| Create issue | **Frame** | Fetch issue details |
| Create branch | **Frame** | Setup development environment |
| Design document | **Architect** | Generate specification |
| Implement | **Build** | Code implementation |
| Commit | **Build** | Commit with semantic message |
| Run tests | **Evaluate** | Execute test suite |
| Code review | **Evaluate** | Review implementation |
| Create PR | **Release** | Generate pull request |
| Merge | **Release** | Merge to main branch |
| Deploy | **Release** | Deploy to production |

### Step 3: Initialize FABER

```bash
# Generate base configuration
/fractary-faber:init

# This creates:
# - .fractary/plugins/faber/config.json (main config with workflow references)
# - .fractary/plugins/faber/workflows/default.json (standard workflow)
# - .fractary/plugins/faber/workflows/hotfix.json (expedited workflow)
```

**Directory structure created:**
```
.fractary/plugins/faber/
├── config.json              # Main configuration (references workflows)
└── workflows/               # Workflow definition files
    ├── default.json         # Standard FABER workflow
    └── hotfix.json          # Expedited hotfix workflow
```

### Step 4: Customize Workflows

Edit workflow files in `.fractary/plugins/faber/workflows/` to match your tools.

**Main config** (`.fractary/plugins/faber/config.json`) references workflows:
```json
{
  "workflows": [
    {
      "id": "default",
      "file": "./workflows/default.json",
      "description": "Standard FABER workflow"
    },
    {
      "id": "hotfix",
      "file": "./workflows/hotfix.json",
      "description": "Expedited workflow for critical patches"
    }
  ],
  "integrations": { ... },
  "logging": { ... }
}
```

**Workflow files** contain phase definitions. Edit `.fractary/plugins/faber/workflows/default.json`:
```json
{
  "$schema": "../workflow.schema.json",
  "id": "default",
  "description": "Standard FABER workflow",
  "phases": {
    "frame": { ... },
    "architect": { ... },
    "build": { ... },
    "evaluate": { ... },
    "release": { ... }
  },
  "hooks": { ... },
  "autonomy": { ... }
}
```

#### ⚠️ Important: Adding Custom Workflows

To add custom workflows:

1. **Copy a template**:
   ```bash
   cp .fractary/plugins/faber/workflows/default.json .fractary/plugins/faber/workflows/documentation.json
   ```

2. **Edit the new workflow file** to customize phases and steps

3. **Add reference to config.json**:
   ```json
   {
     "workflows": [
       {
         "id": "default",
         "file": "./workflows/default.json",
         "description": "Standard FABER workflow"
         // KEEP THIS - it's your baseline workflow
       },
       {
         "id": "documentation",
         "file": "./workflows/documentation.json",
         "description": "Documentation-only workflow"
         // ADD custom workflows alongside default
       }
     ]
   }
   ```

**Always keep the default workflow** as your fallback for general development.

See complete example: `plugins/faber/config/faber.example.json`
See workflow templates: `plugins/faber/config/workflows/`

### Step 5: Create GitHub Issue Templates (Recommended)

Create GitHub issue templates that mirror your FABER workflows to provide workflow selection at issue creation time.

**Why this helps:**
- Users select the appropriate workflow when creating issues
- Templates can pre-populate labels, metadata, and checklists aligned with specific workflows
- Ensures issues have the right structure for the workflow they'll follow
- Makes custom workflows discoverable to team members

#### Template Ordering Strategy

GitHub displays templates in **alphabetical order** by filename. Use numeric prefixes to control the order based on workflow frequency and type.

**Recommended numbering system:**
```
00-09: Flexible/General   (Most common - blank/general issues)
10-19: Create/New         (Creating new features, components, etc.)
20-29: Update/Modify      (Updating existing functionality)
30-39: Audit/Inspect      (Review, analysis, investigation)
40-49: Urgent/Critical    (Hotfixes, security patches)
50-59: Maintenance        (Documentation, chores, dependencies)
```

**Example structure:**
```
.github/ISSUE_TEMPLATE/
├── config.yml              # Configure template chooser + blank_issues_enabled
├── 00-blank.yml            # Flexible template (appears FIRST)
├── 10-feature.yml          # New feature (Create category)
├── 11-bug.yml              # Bug fix (Create category)
├── 20-enhancement.yml      # Enhancement to existing feature (Update category)
├── 30-audit.yml            # Code review, investigation (Audit category)
├── 40-hotfix.yml           # Critical fixes (Urgent category)
└── 50-documentation.yml    # Documentation updates (Maintenance category)
```

This ordering ensures:
- Most flexible option appears first (00-blank.yml)
- Common operations (create new work) appear near the top
- Specialized operations (audits, hotfixes) appear further down
- Logical grouping by workflow type

#### Template Examples

**00-blank.yml** - Minimal, flexible template (appears FIRST):
```yaml
name: General Issue
description: Flexible template for any type of work
title: ""
labels: []
body:
  - type: markdown
    attributes:
      value: |
        Use this template for any issue that doesn't fit other categories.
        This is the most flexible option - customize as needed.

  - type: textarea
    id: description
    attributes:
      label: Description
      description: Describe what needs to be done
      placeholder: What is this issue about?
    validations:
      required: true

  - type: textarea
    id: context
    attributes:
      label: Additional Context
      description: Any additional information
      placeholder: Links, screenshots, related issues, etc.
```

**10-feature.yml** - New feature template (Create category):
```yaml
name: Feature Request
description: Standard feature development workflow
title: "[Feature]: "
labels: ["type:feature", "workflow:default"]
body:
  - type: markdown
    attributes:
      value: |
        This issue will follow the **default FABER workflow**:
        Frame → Architect → Build → Evaluate → Release

  - type: textarea
    id: description
    attributes:
      label: Description
      description: What feature should be implemented?
      placeholder: Describe the feature...
    validations:
      required: true

  - type: textarea
    id: acceptance-criteria
    attributes:
      label: Acceptance Criteria
      description: How will we know this feature is complete?
      placeholder: |
        - [ ] Criterion 1
        - [ ] Criterion 2
    validations:
      required: true

  - type: textarea
    id: context
    attributes:
      label: Additional Context
      description: Any additional information that would help with implementation
      placeholder: Technical details, related issues, screenshots, etc.
```

**11-bug.yml** - Bug fix template (Create category):
```yaml
name: Bug Report
description: Report a bug or defect
title: "[Bug]: "
labels: ["type:bug", "workflow:default"]
body:
  - type: markdown
    attributes:
      value: |
        Report a bug to be fixed via FABER workflow.

  - type: textarea
    id: description
    attributes:
      label: What's wrong?
      description: Describe the bug
      placeholder: What happened? What should have happened?
    validations:
      required: true

  - type: textarea
    id: reproduction
    attributes:
      label: Steps to Reproduce
      placeholder: |
        1. Go to...
        2. Click on...
        3. See error...
    validations:
      required: true

  - type: textarea
    id: impact
    attributes:
      label: Impact
      description: Who is affected and how?
```

**30-audit.yml** - Audit/investigation template (Audit category):
```yaml
name: Audit / Investigation
description: Code review, investigation, or analysis task
title: "[Audit]: "
labels: ["type:audit", "workflow:default"]
body:
  - type: markdown
    attributes:
      value: |
        Use this for code reviews, investigations, or analysis tasks.

  - type: textarea
    id: scope
    attributes:
      label: Scope
      description: What should be reviewed or investigated?
      placeholder: Which files, components, or systems?
    validations:
      required: true

  - type: textarea
    id: objectives
    attributes:
      label: Objectives
      description: What are you looking for?
      placeholder: Security issues, performance problems, technical debt, etc.
```

**40-hotfix.yml** - Hotfix template (Urgent category):
```yaml
name: Hotfix
description: Expedited workflow for critical patches
title: "[HOTFIX]: "
labels: ["type:hotfix", "priority:critical", "workflow:hotfix"]
body:
  - type: markdown
    attributes:
      value: |
        This issue will follow the **hotfix FABER workflow** (expedited).

        ⚠️ Use only for critical production issues requiring immediate attention.

  - type: dropdown
    id: severity
    attributes:
      label: Severity
      description: What is the impact?
      options:
        - Critical - Production down
        - High - Major functionality impaired
        - Medium - Limited functionality affected
    validations:
      required: true

  - type: textarea
    id: problem
    attributes:
      label: Problem Description
      description: What is broken?
    validations:
      required: true

  - type: textarea
    id: impact
    attributes:
      label: User Impact
      description: Who is affected and how?
    validations:
      required: true
```

**50-documentation.yml** - Documentation template (Maintenance category):
```yaml
name: Documentation
description: Documentation updates or improvements
title: "[Docs]: "
labels: ["type:docs", "workflow:default"]
body:
  - type: markdown
    attributes:
      value: |
        Use this template for documentation updates, improvements, or additions.

  - type: textarea
    id: description
    attributes:
      label: What needs to be documented?
      description: Describe the documentation need
      placeholder: What should be added, updated, or clarified?
    validations:
      required: true

  - type: textarea
    id: scope
    attributes:
      label: Scope
      description: Which documentation areas are affected?
      placeholder: README, API docs, user guides, etc.
```

#### config.yml - Template Chooser Configuration

**`.github/ISSUE_TEMPLATE/config.yml`:**

**⚠️ CRITICAL: Always enable blank issues for FABER workflows**

```yaml
blank_issues_enabled: true  # REQUIRED: Must be true for FABER flexibility
contact_links:
  - name: 📚 Documentation
    url: https://github.com/your-org/your-repo/wiki
    about: Check our documentation for guides and references
  - name: 💬 Discussions
    url: https://github.com/your-org/your-repo/discussions
    about: Ask questions and discuss ideas
```

**Why `blank_issues_enabled: true` is required:**
- FABER workflows can be initiated from issues created outside templates (API, integrations, manual creation)
- Allows team members to create quick issues without template overhead when appropriate
- Prevents blocking FABER execution when issue doesn't match a specific template
- Templates provide guidance but shouldn't be mandatory constraints

**Workflow mapping:**
- `workflow:default` label → FABER uses default workflow
- `workflow:hotfix` label → FABER uses hotfix workflow
- `workflow:documentation` label → FABER uses documentation workflow

When running FABER, it can detect the workflow label:
```bash
# Automatically detects workflow from issue labels
/fractary-faber:run 123

# Or explicitly specify workflow
/fractary-faber:run 123 --workflow hotfix
```

### Step 6: Add Hooks for Existing Scripts

Reference your existing scripts via hooks instead of rewriting them.

### Step 7: Configure Autonomy Level

Choose appropriate autonomy based on your team's preferences:
- **dry-run**: Simulate only (for testing)
- **assist**: Stop before release (for learning)
- **guarded**: Pause for approval before release (recommended)
- **autonomous**: Full automation (use with caution)

### Step 8: Validate Configuration

```bash
/fractary-faber:audit
/fractary-faber:audit --verbose
```

### Step 9: Test Incrementally

Start with individual phases, then progress to full workflow execution:

```bash
# Test individual phases (recommended for first-time setup)
/fractary-faber:run --work-id 123 --phase frame              # Frame phase only
/fractary-faber:run --work-id 123 --phase frame,architect    # Frame + Architect phases

# Test complete workflow with dry-run
/fractary-faber:run --work-id 123 --autonomy dry-run         # Simulate without making changes

# Test with assisted mode (stops before release)
/fractary-faber:run --work-id 123 --autonomy assist          # Execute but pause before release

# Production usage (pauses for approval before release)
/fractary-faber:run --work-id 123 --autonomy guarded         # Recommended for production
```

## Direct Integration Pattern

When integrating FABER into your project, use the plugin commands directly in your workflow:

```bash
# In your development process:
1. Create issue in your work tracker (GitHub/Jira/Linear)
2. Run: /fractary-faber:run <issue-number>
3. FABER executes all phases automatically
4. Review and approve release when prompted
```

**What FABER handles automatically:**
- ✅ Branch creation with semantic naming
- ✅ Specification generation from issue context
- ✅ Implementation guidance and context management
- ✅ Test execution and validation
- ✅ Pull request creation with generated summary
- ✅ Work tracking integration (comments, status updates)

**What you configure:**
- Your preferred autonomy level (dry-run, assist, guarded, autonomous)
- Phase-specific steps via hooks (test commands, build scripts, deploy procedures)
- Tool integrations (work tracker, repo platform, file storage)

## Common Integration Mistakes

**❌ Don't Do This:**
- Creating project-specific wrapper commands around FABER commands
- Creating project-specific agents that invoke `faber-manager`
- Copying FABER logic into custom agents/skills
- Modifying FABER plugin files directly

**✅ Do This Instead:**
- Use `/fractary-faber:*` commands directly
- Customize behavior via `.fractary/plugins/faber/config.json`
- Add project-specific logic via phase hooks
- Extend via plugin system (see PLUGIN-EXTENSION-GUIDE.md)

## See Also

- [CONFIGURATION.md](./CONFIGURATION.md) - Complete configuration reference
- [HOOKS.md](./HOOKS.md) - Phase-level hooks guide
- [PLUGIN-EXTENSION-GUIDE.md](./PLUGIN-EXTENSION-GUIDE.md) - Creating specialized FABER plugins
- [STATE-TRACKING.md](./STATE-TRACKING.md) - Understanding workflow state management
