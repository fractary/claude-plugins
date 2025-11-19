# Fractary Status Plugin

Custom Claude Code status line showing git status, issue numbers, PR numbers, and last user prompt.

## Features

- **Project Name**: Repository name in square brackets (cyan)
- **Branch Name**: Current git branch in cyan
- **File Changes**: Count of uncommitted files (±N) - yellow if dirty, green if clean
- **Sync Status**: Commits ahead (↑N) in green, commits behind (↓N) in red (displayed after file changes)
- **Issue Number**: Extracted from branch name (#N) in magenta, clickable in web IDE
- **PR Number**: Current PR for branch (PR#N) in blue, clickable in web IDE
- **Last Prompt**: Your most recent command/question (truncated to 120 chars) in dim text

## Status Line Format

```
[project] branch ±files [↑ahead ↓behind] [#issue | issue-url] [PR#pr | pr-url]
last: prompt...
```

### Examples

**Terminal (OSC 8 hyperlinks):**
```
[claude-plugins] feat/99-new-feature ±4 ↑2 #99
last: update spec accordingly
```

**Web IDE (plain URLs):**
```
[claude-plugins] feat/99-new-feature ±4 ↑2 #99 https://github.com/owner/repo/issues/99
last: update spec accordingly
```

**Without clickable links:**
```
[my-project] main ±0
last: /fractary-spec:generate 99
```

## Installation

### Quick Install

```bash
/status:install
```

Then restart Claude Code to activate.

### What Gets Installed

The installation process:
1. Creates `.fractary/plugins/status/` directory for plugin configuration
2. Creates `.fractary/plugins/status/config.json` with plugin settings
3. Updates `.claude/settings.json` with statusLine configuration (using absolute path)
4. Updates `.gitignore` to exclude cache file

**Note**: Scripts remain in the plugin directory (`~/.claude/plugins/marketplaces/fractary/plugins/status/scripts/`).
The UserPromptSubmit hook is managed at the plugin level in `hooks/hooks.json` and automatically activates when the plugin is enabled.

### Manual Installation

If you prefer manual installation or need to troubleshoot:

1. Enable the plugin in `.claude/settings.json`:
   ```json
   {
     "enabledPlugins": {
       "fractary-status@fractary": true
     }
   }
   ```

2. Add statusLine configuration to `.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/plugins/marketplaces/fractary/plugins/status/scripts/status-line.sh"
     }
   }
   ```

3. Create plugin configuration:
   ```bash
   mkdir -p .fractary/plugins/status
   echo '{"version": "1.0.0", "cache_path": ".fractary/plugins/status"}' > .fractary/plugins/status/config.json
   ```

4. Restart Claude Code

**Important**: The UserPromptSubmit hook is automatically registered via the plugin's `hooks/hooks.json` and uses `${CLAUDE_PLUGIN_ROOT}`. You don't need to manually add it to your project's settings.json.

## Requirements

- **Git repository**: Must be run in a git repository
- **fractary-repo plugin**: Uses git status cache from repo plugin
- **jq**: For JSON processing (usually pre-installed)
- **gh CLI**: Optional, for PR number detection

## How It Works

### Two-Hook Architecture

1. **UserPromptSubmit Hook**: Captures your prompt each time you submit
   - Runs `capture-prompt.sh` on every prompt
   - Stores prompt in `.fractary/plugins/status/last-prompt.json`
   - Truncates to 120 characters for display
   - Non-blocking (<10ms execution time)

2. **StatusLine Hook**: Generates status line display
   - Runs `status-line.sh` when status line refreshes
   - Reads git status from fractary-repo cache
   - Extracts issue/PR numbers
   - Reads last prompt from cache
   - Formats and displays all elements
   - Fast execution (<100ms)

### Git Status Cache Integration

Status line leverages the git status cache from the `fractary-repo` plugin:
- No expensive git queries on every refresh
- Cache kept fresh by repo plugin hooks
- Shared across all sessions for same repository
- Fallback to live git queries if cache is stale

### Issue Number Detection

Issue numbers are extracted from:
1. Git status cache (if available)
2. Branch name pattern matching (e.g., `feat/123-description`)
3. Branch metadata (if stored by repo plugin)

### PR Number Detection

PR numbers are retrieved from:
1. Git status cache (preferred)
2. Local git branch metadata
3. GitHub API via gh CLI (fallback, cached to avoid rate limits)

### Clickable Links

The status line supports clickable issue and PR links in both terminal and web IDE environments:

**Terminal (OSC 8 hyperlinks):**
- Uses OSC 8 escape sequences for embedded clickable links
- The issue/PR label itself is clickable (e.g., "#123" or "PR#456")
- Supported by modern terminals: iTerm2, VSCode terminal, Hyper, etc.
- Click opens the issue/PR in your default browser

**Web IDE (plain URLs):**
- Displays label followed by plain URL (e.g., "#123 https://github.com/...")
- Web IDE automatically makes URLs clickable
- Click opens the issue/PR in your default browser
- Provides better compatibility with web-based interfaces

**GitHub Detection:**
- Automatically detects GitHub repository from git remote URL
- Supports both HTTPS and SSH remote formats
- Falls back to non-clickable labels for non-GitHub repositories

## Plugin Architecture

### Variable Expansion in Claude Code

Understanding where `${CLAUDE_PLUGIN_ROOT}` works is crucial for plugin development:

**✅ Supported in Plugin-Level Hooks** (`hooks/hooks.json`):
- Hooks registered in the plugin's `hooks/hooks.json` file support `${CLAUDE_PLUGIN_ROOT}`
- This variable expands at runtime to the plugin's installation directory
- Example: `${CLAUDE_PLUGIN_ROOT}/scripts/capture-prompt.sh` → `~/.claude/plugins/marketplaces/fractary/plugins/status/scripts/capture-prompt.sh`
- The UserPromptSubmit hook uses this pattern

**❌ NOT Supported in Project Settings** (`.claude/settings.json`):
- Project-level settings.json does not support `${CLAUDE_PLUGIN_ROOT}` variable expansion
- The `statusLine` property must use an absolute path
- Example: `~/.claude/plugins/marketplaces/fractary/plugins/status/scripts/status-line.sh`
- This is why the install script writes the absolute path

**Why the Difference?**

Claude Code's hook system has two distinct contexts:
1. **Plugin context**: Hooks defined in `hooks/hooks.json` execute with plugin-aware variable expansion
2. **Project context**: Settings in `.claude/settings.json` execute without plugin variable support

The `statusLine` property is configured at the project level (in `.claude/settings.json`), not at the plugin level, which is why it cannot use `${CLAUDE_PLUGIN_ROOT}`.

### File Locations

**Plugin-managed files** (never copied to project):
- Scripts: `~/.claude/plugins/marketplaces/fractary/plugins/status/scripts/`
- Hooks definition: `~/.claude/plugins/marketplaces/fractary/plugins/status/hooks/hooks.json`

**Project-specific files**:
- Configuration: `.fractary/plugins/status/config.json`
- Cache: `.fractary/plugins/status/last-prompt.json` (gitignored)
- Settings: `.claude/settings.json` (statusLine configuration)

## Configuration

### Plugin Configuration

Located at `.fractary/plugins/status/config.json`:

```json
{
  "version": "1.0.0",
  "installed": "2025-11-12T18:00:00Z",
  "scripts_path": ".claude/status/scripts",
  "cache_path": ".fractary/plugins/status"
}
```

### Runtime Cache

Prompt cache at `.fractary/plugins/status/last-prompt.json`:

```json
{
  "timestamp": "2025-11-12T18:34:24Z",
  "prompt": "update spec accordingly",
  "prompt_short": "update spec accordingly"
}
```

This file is automatically managed and should be added to `.gitignore`.

## Troubleshooting

### Status line not showing

1. Check hooks are configured:
   ```bash
   cat .claude/settings.json | jq '.statusLine, .hooks.UserPromptSubmit'
   ```

2. Verify scripts are executable:
   ```bash
   ls -la .claude/status/scripts/
   ```

3. Restart Claude Code

### No prompt displayed

1. Submit a prompt to trigger UserPromptSubmit hook
2. Check cache file exists:
   ```bash
   cat .fractary/plugins/status/last-prompt.json
   ```

3. Verify hook is running:
   ```bash
   # Should update after each prompt
   ls -lt .fractary/plugins/status/last-prompt.json
   ```

### Missing issue or PR numbers

1. Ensure branch name follows convention:
   - `feat/123-description`
   - `fix/456-bug-name`

2. Check git status cache:
   ```bash
   bash plugins/repo/scripts/read-status-cache.sh
   ```

3. For PR numbers, ensure `gh` CLI is installed and authenticated:
   ```bash
   gh auth status
   ```

### Performance issues

1. Check git status cache is working:
   ```bash
   # Should be recent
   ls -lt ~/.fractary/repo/status-*.cache
   ```

2. Verify cache is being refreshed by hooks:
   ```bash
   # Check repo plugin hooks are configured
   cat .claude/settings.json | jq '.hooks.UserPromptSubmit'
   ```

3. Check script execution time:
   ```bash
   time bash .claude/status/scripts/status-line.sh
   ```
   Should be <100ms

## Uninstallation

To remove the status line plugin:

1. Remove hooks from `.claude/settings.json`:
   ```json
   {
     "statusLine": null,
     "hooks": {
       "UserPromptSubmit": []
     }
   }
   ```

2. Remove scripts (optional):
   ```bash
   rm -rf .claude/status/
   rm -rf .fractary/plugins/status/
   ```

3. Restart Claude Code

## Development

### Project Structure

```
plugins/status/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata
├── commands/
│   └── install.md               # /status:install command
├── skills/
│   └── status-line-manager/
│       ├── SKILL.md            # Installation skill
│       └── scripts/
│           ├── install.sh       # Installation script
│           ├── status-line.sh   # Status line generator
│           └── capture-prompt.sh # Prompt capture
├── hooks/
│   ├── status-line.json         # StatusLine hook template
│   └── user-prompt-submit.json  # UserPromptSubmit hook template
└── README.md                    # This file
```

### Testing

Test the status line manually:

```bash
# Test status line display
bash .claude/status/scripts/status-line.sh

# Test prompt capture
echo "test prompt" | bash .claude/status/scripts/capture-prompt.sh
cat .fractary/plugins/status/last-prompt.json

# Test installation
/status:install
```

### Contributing

Follow the Fractary plugin standards:
- See `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`
- Use 3-layer architecture (commands → skills → scripts)
- Document with XML markup
- Keep scripts fast and deterministic

## Dependencies

- **fractary-repo**: Git status cache (required)
- **git**: Version control (required)
- **jq**: JSON processing (required)
- **gh**: GitHub CLI (optional, for PR numbers)
- **bash**: Shell scripting (required)

## License

MIT License - See repository LICENSE file

## Support

For issues or questions:
- GitHub Issues: https://github.com/fractary/claude-plugins/issues
- Documentation: See `docs/` directory
- Examples: See `plugins/status/hooks/` for configuration examples

## Changelog

### v1.1.0 (2025-11-16)
- Added clickable links for issue and PR numbers
- Support for both terminal (OSC 8) and web IDE (plain URL) environments
- Improved link formatting and display
- Standardized label format (#123 for issues, PR#123 for PRs)
- Added project name display
- Updated documentation with clickable link examples

### v1.0.0 (2025-11-12)
- Initial release
- StatusLine hook integration
- UserPromptSubmit hook integration
- Git status cache integration
- Issue/PR number detection
- Last prompt display (truncated to 120 chars)
- Installation command
- Full documentation
