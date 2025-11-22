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
✅ /fractary-faber:run 123              # Correct: Use the plugin command directly
✅ /fractary-faber:frame 123            # Correct: Run individual phases
✅ /fractary-faber:audit                # Correct: Validate configuration

❌ /my-project:faber 123                # Wrong: Don't create wrapper commands
❌ @agent my-project-faber-manager      # Wrong: Don't create wrapper agents
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

**Example structure:**
```
.github/ISSUE_TEMPLATE/
├── config.yml           # Optional: Configure template chooser
├── feature.yml          # Maps to "default" FABER workflow
├── hotfix.yml           # Maps to "hotfix" FABER workflow
└── documentation.yml    # Maps to "documentation" FABER workflow
```

**Example: Feature template** (`.github/ISSUE_TEMPLATE/feature.yml`):
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

**Example: Hotfix template** (`.github/ISSUE_TEMPLATE/hotfix.yml`):
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

**Example: config.yml** (`.github/ISSUE_TEMPLATE/config.yml`):
```yaml
blank_issues_enabled: false
contact_links:
  - name: 📚 Documentation
    url: https://github.com/your-org/your-repo/wiki
    about: Check our documentation for guides and references
  - name: 💬 Discussions
    url: https://github.com/your-org/your-repo/discussions
    about: Ask questions and discuss ideas
```

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
/fractary-faber:frame 123                    # Frame phase only
/fractary-faber:architect 123                # Architect phase only

# Test complete workflow with dry-run
/fractary-faber:run 123 --autonomy dry-run   # Simulate without making changes

# Test with assisted mode (stops before release)
/fractary-faber:run 123 --autonomy assist    # Execute but pause before release

# Production usage (pauses for approval before release)
/fractary-faber:run 123 --autonomy guarded   # Recommended for production
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
