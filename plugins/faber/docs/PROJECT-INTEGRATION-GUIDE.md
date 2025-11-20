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

# This creates .fractary/plugins/faber/config.json
```

### Step 4: Customize Phase Steps

Edit `.fractary/plugins/faber/config.json` to match your tools.

See complete example: `plugins/faber/config/faber.example.json`

### Step 5: Add Hooks for Existing Scripts

Reference your existing scripts via hooks instead of rewriting them.

### Step 6: Configure Autonomy Level

Choose appropriate autonomy based on your team's preferences:
- **dry-run**: Simulate only (for testing)
- **assist**: Stop before release (for learning)
- **guarded**: Pause for approval before release (recommended)
- **autonomous**: Full automation (use with caution)

### Step 7: Validate Configuration

```bash
/fractary-faber:audit
/fractary-faber:audit --verbose
```

### Step 8: Test Incrementally

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
