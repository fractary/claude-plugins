# FABER Project Integration Guide

**Audience**: Teams adopting FABER workflow for their existing projects

**Goal**: Map your current development workflow to FABER configuration

## Overview

FABER provides a universal issue-centric workflow:
- **Frame** → **Architect** → **Build** → **Evaluate** → **Release**
- Core artifacts: **Issue** + **Branch** + **Spec**

This guide helps you integrate FABER into your existing project by mapping your current practices to FABER's structure.

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

```bash
/fractary-faber:frame 123
/fractary-faber:architect 123
/fractary-faber:run 123 --autonomy dry-run
```

## See Also

- [CONFIGURATION.md](./CONFIGURATION.md) - Complete configuration reference
- [HOOKS.md](./HOOKS.md) - Phase-level hooks guide
- [PLUGIN-EXTENSION-GUIDE.md](./PLUGIN-EXTENSION-GUIDE.md) - Creating specialized FABER plugins
