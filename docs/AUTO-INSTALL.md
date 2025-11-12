# Automatic Fractary Marketplace Installation

**Issue**: [#84](https://github.com/fractary/claude-plugins/issues/84)
**Specification**: [spec-84-auto-install-fractary-plugins-on-startup.md](../specs/spec-84-auto-install-fractary-plugins-on-startup.md)

## Overview

This repository implements automatic installation of the Fractary plugin marketplace when Claude Code sessions start. This ensures that all Fractary plugins are immediately available in fresh environments (GitHub workers, virtual sessions, etc.) without requiring manual installation.

## How It Works

### SessionStart Hook

The solution uses Claude Code's `SessionStart` hook to execute a startup script before each session begins. The hook is configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "./scripts/claude/install-fractary-marketplace.sh"
          }
        ]
      }
    ]
  }
}
```

### Installation Script

The script `scripts/claude/install-fractary-marketplace.sh` performs the following:

1. **Check if marketplace is already installed** - Avoids redundant installations
2. **Install marketplace if needed** - Runs `/plugin marketplace add fractary/claude-plugins`
3. **Set environment variables** - Exports `FRACTARY_MARKETPLACE_STATUS` for visibility
4. **Return context to Claude** - Provides installation status in Claude Code session

### Smart Detection

The script checks if the marketplace is already installed to:
- **Reduce startup time** - Skip installation if not needed
- **Avoid duplicate installations** - Prevent errors from re-installing
- **Provide fast feedback** - Session starts immediately if marketplace exists

## Installation Time

- **First session** (marketplace not installed): ~5-15 seconds
- **Subsequent sessions** (marketplace already installed): <1 second (detection only)

## What Gets Installed

When the marketplace is installed, these plugins become available:

- `fractary-faber@fractary` - Core FABER workflow orchestration
- `fractary-faber-cloud@fractary` - Cloud infrastructure workflows
- `fractary-work@fractary` - Work item management (GitHub, Jira, Linear)
- `fractary-repo@fractary` - Source control operations (GitHub, GitLab, Bitbucket)
- `fractary-file@fractary` - File storage operations (R2, S3, local)
- `fractary-codex@fractary` - Memory and knowledge management
- `fractary-docs@fractary` - Documentation management
- `fractary-logs@fractary` - Log management and analysis
- `fractary-spec@fractary` - Specification generation

Individual plugins still need to be enabled in `.claude/settings.json` (see `enabledPlugins` section).

## Troubleshooting

### Script Fails to Run

**Symptom**: SessionStart hook doesn't execute the script

**Possible causes**:
- Script is not executable - Run: `chmod +x scripts/claude/install-fractary-marketplace.sh`
- Path is incorrect - Ensure path is relative to repository root
- Claude Code doesn't support SessionStart - Update to latest version

### Installation Fails

**Symptom**: Script runs but marketplace installation fails

**Possible causes**:
- No network access - Check internet connectivity
- GitHub rate limiting - Wait and retry
- Invalid repository - Verify `fractary/claude-plugins` exists and is accessible

**Manual installation**:
```bash
/plugin marketplace add fractary/claude-plugins
```

### Script Runs Every Session

**Symptom**: Installation happens on every session start, even when already installed

**Possible causes**:
- Detection logic is failing - Check `claude plugin marketplace list` output
- Marketplace name mismatch - Verify marketplace is named "fractary"

**Debug**:
```bash
# Check if marketplace is installed
/plugin marketplace list

# Check installation logs
cat /tmp/marketplace-install.log
```

## Environment Variables

The script sets the following environment variable (via `CLAUDE_ENV_FILE`):

- `FRACTARY_MARKETPLACE_STATUS`:
  - `installed` - Marketplace was already present
  - `newly_installed` - Marketplace was just installed this session
  - `failed` - Installation failed

Access in subsequent bash commands:
```bash
echo $FRACTARY_MARKETPLACE_STATUS
```

## Testing the Solution

### Test in Fresh Environment

To test the auto-installation behavior:

1. **Remove the marketplace** (if installed):
   ```bash
   /plugin marketplace remove fractary
   ```

2. **Start a new session**:
   ```bash
   claude code --resume
   ```

3. **Verify installation**:
   - Check session start messages for installation confirmation
   - Run `/plugin marketplace list` to confirm `fractary` is present
   - Run `/help` to see fractary plugin commands

### Test in Existing Environment

To verify the skip-installation logic:

1. **Ensure marketplace is installed**:
   ```bash
   /plugin marketplace add fractary/claude-plugins
   ```

2. **Start a new session**:
   ```bash
   claude code --resume
   ```

3. **Verify skip message**:
   - Check session start messages for "already installed" confirmation
   - Session should start quickly (<1 second for hook)

## Replicating for Other Marketplaces

To implement automatic installation for other plugin marketplaces:

1. **Copy the script**:
   ```bash
   cp scripts/claude/install-fractary-marketplace.sh scripts/claude/install-your-marketplace.sh
   ```

2. **Update configuration variables**:
   ```bash
   MARKETPLACE_REPO="your-org/your-plugins"
   MARKETPLACE_NAME="your-org"
   ```

3. **Add hook to `.claude/settings.json`**:
   ```json
   {
     "hooks": {
       "SessionStart": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "./scripts/claude/install-fractary-marketplace.sh"
             },
             {
               "type": "command",
               "command": "./scripts/claude/install-your-marketplace.sh"
             }
           ]
         }
       ]
     }
   }
   ```

4. **Commit to repository**:
   ```bash
   git add .claude/settings.json scripts/claude/install-your-marketplace.sh
   git commit -m "feat: auto-install your-org marketplace on startup"
   ```

## Benefits

1. **Zero manual intervention** - Developers don't need to install marketplace manually
2. **Works across environments** - GitHub workers, virtual sessions, local development
3. **Fast subsequent sessions** - Detection is quick, installation only happens once
4. **Team consistency** - Everyone gets the same plugins automatically
5. **Version control friendly** - Configuration is committed to repository
6. **Fail-safe** - Session continues even if installation fails

## Related Documentation

- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks.md)
- [Claude Code Plugins Guide](https://code.claude.com/docs/en/plugins.md)
- [Fractary Plugin Standards](./standards/FRACTARY-PLUGIN-STANDARDS.md)
- [Issue #84: Auto Install Fractary Plugins on Startup](https://github.com/fractary/claude-plugins/issues/84)
- [Specification: spec-84-auto-install-fractary-plugins-on-startup.md](../specs/spec-84-auto-install-fractary-plugins-on-startup.md)

## Architecture Decisions

### Why SessionStart Hook?

The `SessionStart` hook is ideal because:
- Runs before Claude Code session begins
- Has access to `CLAUDE_ENV_FILE` for environment persistence
- Can return context to Claude Code for session awareness
- Supports conditional logic (check before install)
- Fails gracefully if installation impossible

### Why Shell Script?

Shell script was chosen over other approaches because:
- Simple and transparent (easy to debug)
- No external dependencies
- Fast execution
- Direct access to Claude Code CLI commands
- Works in all environments (Linux, macOS, WSL)

### Alternative Approaches Considered

1. **GitHub Actions** - Only works for GitHub worker environments, not local sessions
2. **Dockerfile/devcontainer** - Requires Docker, not universal
3. **Meta-plugin** - Complex, circular dependency issues
4. **Manual installation docs** - Requires user intervention (not automatic)

The SessionStart hook approach was selected as the most universal and reliable solution.
