# Migration Guide: v1.x to v2.0

Guide for migrating from the monolithic v1.x architecture to the modular v2.0 architecture.

## Overview

Version 2.0 represents a major architectural refactoring while maintaining backward compatibility with existing workflows.

### What Changed

**Architecture**:
- ❌ Monolithic single skill
- ✅ 7 specialized skills with handler pattern
- ✅ 3-layer architecture (Commands → Agent → Skills → Handlers)
- ✅ 55-60% context reduction

**New Features**:
- ✅ 6 user-facing slash commands
- ✅ Handler pattern for multi-platform support
- ✅ Comprehensive configuration system
- ✅ 7 new operations (tag management, PR reviews, branch cleanup)

### What Stayed the Same

- ✅ Agent interface (no breaking changes)
- ✅ FABER integration (fully compatible)
- ✅ Programmatic API (same request/response format)
- ✅ GitHub support (all existing operations work)

## Breaking Changes

**There are NO breaking changes** in v2.0. All existing usage patterns continue to work.

However, the **internal structure has changed significantly**:
- Old monolithic `skills/repo-manager` → New modular skills
- Configuration format updated (but old format still works with defaults)

## Migration Steps

### Step 1: Backup Current Configuration

```bash
# Backup existing FABER config if using with FABER
cp .faber.config.toml .faber.config.toml.backup

# Backup any custom scripts (if you modified them)
cp -r plugins/repo/skills/repo-manager/scripts plugins/repo/skills/repo-manager/scripts.backup
```

### Step 2: Update Plugin

```bash
# Pull latest changes
cd plugins/repo
git pull origin main

# Or reinstall plugin
claude plugin update fractary/repo
```

### Step 3: Update Configuration

#### Option A: Use New Configuration Format (Recommended)

Create new configuration file:

```bash
# Copy example configuration
cp plugins/repo/config/repo.example.json ~/.fractary/repo/config.json

# Edit configuration
nano ~/.fractary/repo/config.json
```

Example configuration:
```json
{
  "handlers": {
    "source_control": {
      "active": "github",
      "github": {
        "token": "$GITHUB_TOKEN",
        "api_url": "https://api.github.com"
      }
    }
  },
  "defaults": {
    "default_branch": "main",
    "protected_branches": ["main", "master", "production"],
    "branch_naming": {
      "pattern": "{prefix}/{issue_id}-{slug}",
      "allowed_prefixes": ["feat", "fix", "chore", "docs", "test", "refactor"]
    },
    "commit_format": "faber",
    "merge_strategy": "no-ff"
  }
}
```

#### Option B: Keep Existing Configuration (Backward Compatible)

If you're using FABER with `.faber.config.toml`, no changes needed. The plugin will use built-in defaults and work exactly as before.

### Step 4: Verify Installation

Test basic operations:

```bash
# Navigate to a test repository
cd /path/to/test/repo

# Test new command interface
/repo:branch create 1 "test migration"

# Test programmatic interface (should work as before)
# If using with FABER, run a test workflow
```

### Step 5: Explore New Features (Optional)

Try the new slash commands:

```bash
# Branch management
/repo:branch list --stale --merged

# Semantic commits
/repo:commit "Add feature" --type feat --work-id 123

# Push with upstream
/repo:push --set-upstream

# PR management
/repo:pr create "feat: New feature" --work-id 123

# Tag management
/repo:tag create v1.0.0 --message "Release"

# Branch cleanup
/repo:cleanup --merged
```

## Configuration Migration

### Old Format (FABER v1.x)

```yaml
# .faber.config.toml
handlers:
  repository:
    active: "github"
    github:
      owner: "myorg"
      repo: "my-project"
      main_branch: "main"
```

### New Format (Repo Plugin v2.0)

```json
{
  "handlers": {
    "source_control": {
      "active": "github",
      "github": {
        "token": "$GITHUB_TOKEN",
        "api_url": "https://api.github.com"
      }
    }
  },
  "defaults": {
    "default_branch": "main"
  }
}
```

**Note**: Both formats work. The plugin will:
1. Check for `~/.fractary/repo/config.json` (new format)
2. Fall back to `.faber.config.toml` (old format)
3. Use built-in defaults if neither exists

## Feature Comparison

### v1.x (Monolithic)

**What you had**:
- ✅ Branch creation
- ✅ Semantic commits
- ✅ Push operations
- ✅ PR creation
- ✅ PR merging
- ✅ FABER integration
- ❌ No user commands
- ❌ No tag management
- ❌ No PR reviews
- ❌ No branch cleanup
- ❌ Single platform (GitHub)

**Architecture**:
- 1 agent (370 lines with bash examples)
- 1 skill (320 lines, monolithic)
- ~690 lines loaded per operation

### v2.0 (Modular)

**What you have now**:
- ✅ All v1.x operations (backward compatible)
- ✅ **6 slash commands** for direct use
- ✅ **Tag management** (create, push tags)
- ✅ **PR reviews** (comment, review, approve)
- ✅ **Branch cleanup** (list/delete stale branches)
- ✅ **Handler pattern** (ready for GitLab, Bitbucket)
- ✅ **Configuration system** with comprehensive options
- ✅ **55-60% context reduction**

**Architecture**:
- 1 agent (200 lines, routing only)
- 7 specialized skills (200-400 lines each)
- 3 handlers (platform-specific)
- ~350-750 lines loaded per operation (average: ~550)

## Common Migration Scenarios

### Scenario 1: Using with FABER

**Before (v1.x)**:
```toml
# .faber.config.toml
handlers:
  repository:
    active: "github"
```

**After (v2.0)**:
No changes needed! FABER integration works exactly the same way.

**Optional**: Create `~/.fractary/repo/config.json` for additional plugin-specific settings.

### Scenario 2: Custom Scripts

**Before (v1.x)**:
You modified scripts in `plugins/repo/skills/repo-manager/scripts/github/`

**After (v2.0)**:
Scripts moved to `plugins/repo/skills/handler-source-control-github/scripts/`

**Migration**:
1. Copy your custom scripts to new location
2. Update script paths in your workflows
3. Test thoroughly

### Scenario 3: Direct Agent Invocation

**Before (v1.x)**:
```bash
claude --agent repo-manager "create-branch feature/new-feature"
```

**After (v2.0)**:
Same syntax works! Agent interface unchanged.

**Alternative (v2.0)**:
Use new commands:
```bash
/repo:branch create 123 "new feature"
```

### Scenario 4: Programmatic Usage

**Before (v1.x)**:
```json
{
  "operation": "create-branch",
  "parameters": {
    "branch_name": "feat/123-export",
    "base_branch": "main"
  }
}
```

**After (v2.0)**:
Exact same format! No changes needed.

## Troubleshooting Migration Issues

### Issue: "Operation not found"

**Cause**: Old skill still being loaded

**Solution**:
```bash
# Clear Claude cache
claude cache clear

# Or restart Claude Code
```

### Issue: "Configuration not found"

**Cause**: Plugin looking for new config format

**Solution**:
```bash
# Create default config
cp plugins/repo/config/repo.example.json ~/.fractary/repo/config.json

# Or let it use built-in defaults (no action needed)
```

### Issue: "Handler not found"

**Cause**: Handler not configured

**Solution**:
```json
{
  "handlers": {
    "source_control": {
      "active": "github"
    }
  }
}
```

### Issue: Custom scripts not working

**Cause**: Scripts moved to new location

**Solution**:
1. Find your custom scripts in backup
2. Copy to new location: `plugins/repo/skills/handler-source-control-github/scripts/`
3. Verify script permissions: `chmod +x script.sh`

### Issue: FABER workflow broken

**Cause**: Unlikely, but check configuration

**Solution**:
```bash
# Verify FABER config
cat .faber.config.toml

# Test specific operation
claude --agent repo-manager "create-branch test/migration-test main"

# Check FABER logs
```

## Rollback Procedure

If you encounter issues and need to rollback:

### Step 1: Restore Backup

```bash
# Restore configuration
cp .faber.config.toml.backup .faber.config.toml

# Restore custom scripts (if any)
cp -r plugins/repo/skills/repo-manager/scripts.backup/* \
      plugins/repo/skills/repo-manager/scripts/
```

### Step 2: Revert Plugin

```bash
# Check out previous version
cd plugins/repo
git checkout v1.0.0

# Or reinstall old version
claude plugin install fractary/repo@1.0.0
```

### Step 3: Clear Cache

```bash
claude cache clear
```

### Step 4: Test

```bash
# Verify rollback worked
/repo:branch create 1 "rollback test"
```

## Benefits of Migrating

### Context Efficiency

**v1.x**: ~690 lines per operation
**v2.0**: ~550 lines per operation (average)
**Savings**: ~20% reduction (up to 60% for simple operations)

### New Capabilities

- **User Commands**: Direct interaction via slash commands
- **Tag Management**: Version tagging support
- **PR Reviews**: Full review lifecycle
- **Branch Cleanup**: Automated stale branch management
- **Multi-Platform Ready**: Handler pattern for GitLab, Bitbucket

### Better Organization

- **7 Focused Skills**: Each skill does one thing well
- **Clear Separation**: Commands → Agent → Skills → Handlers
- **Easier Testing**: Test each skill independently
- **Simpler Maintenance**: Update one skill without affecting others

### Extensibility

- **Add Platforms**: Create new handlers without touching agent
- **Add Operations**: Update skills without changing architecture
- **Customize Workflows**: Override specific skills as needed

## FAQ

### Q: Will my FABER workflows break?

**A**: No. The agent interface is unchanged. FABER workflows work exactly as before.

### Q: Do I need to update my configuration?

**A**: Not required. The plugin works with existing configuration and built-in defaults. But updating to the new format gives you access to more options.

### Q: Can I use both old and new command interfaces?

**A**: Yes. The programmatic interface (agent invocation) and new slash commands both work simultaneously.

### Q: What happens to custom scripts I wrote?

**A**: Copy them to the new handler location: `plugins/repo/skills/handler-source-control-github/scripts/`

### Q: Can I still use only GitHub?

**A**: Yes. GitLab and Bitbucket are optional handlers. GitHub continues to work exactly as before.

### Q: How do I test the migration worked?

**A**: Run these commands:
```bash
/repo:branch create 1 "migration test"
/repo:commit "Test commit" --type test --work-id 1
/repo:push
git checkout main
/repo:branch delete test/1-migration-test
```

### Q: What if I encounter issues?

**A**:
1. Check [Troubleshooting](#troubleshooting-migration-issues) section above
2. Rollback if needed (see [Rollback Procedure](#rollback-procedure))
3. File an issue: https://github.com/fractary/claude-plugins/issues

## Post-Migration Checklist

After migrating, verify:

- [ ] Basic operations work (branch, commit, push)
- [ ] FABER integration works (if applicable)
- [ ] Custom scripts work (if applicable)
- [ ] Configuration loads correctly
- [ ] New commands accessible (/repo:branch, /repo:commit, etc.)
- [ ] Protected branch safety works
- [ ] Authentication works (GITHUB_TOKEN set)

## Getting Help

- **Documentation**: https://github.com/fractary/claude-plugins/tree/main/plugins/repo
- **Issues**: https://github.com/fractary/claude-plugins/issues
- **Discussions**: https://github.com/fractary/claude-plugins/discussions
- **Specification**: [Repo Plugin Refactoring Spec](spec/repo-plugin-refactoring-spec.md)

## Feedback

We'd love to hear about your migration experience!

- What went well?
- What was confusing?
- What could be improved?

Please share feedback in [GitHub Discussions](https://github.com/fractary/claude-plugins/discussions).

---

**Migration successful?** 🎉 Explore the new features and enjoy the improved context efficiency!
