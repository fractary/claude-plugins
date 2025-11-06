# Claude Code Configuration

This directory contains project-level Claude Code configuration for the fractary plugin marketplace.

## Configuration Files

### settings.json

The `settings.json` file configures:

1. **Local Marketplace Registration** (`extraKnownMarketplaces`):
   - Registers the fractary marketplace from the local `.claude-plugin/marketplace.json` file
   - This makes all fractary plugins available in the Claude Code web environment

2. **Enabled Plugins** (`enabledPlugins`):
   - `fractary-work@fractary` - Work item management (GitHub Issues, Jira, Linear)
   - `fractary-repo@fractary` - Source control operations (GitHub, GitLab, Bitbucket)
   - `fractary-file@fractary` - File storage operations (R2, S3, local)
   - `fractary-faber@fractary` - FABER workflow orchestration
   - `fractary-faber-cloud@fractary` - Cloud infrastructure workflows
   - `fractary-codex@fractary` - Memory and knowledge management

## How It Works

### Claude Code Web Environment

When using Claude Code on the web, each session creates a fresh environment by:
1. Cloning the repository
2. Reading `.claude/settings.json`
3. Registering any marketplaces defined in `extraKnownMarketplaces`
4. Enabling plugins listed in `enabledPlugins`

### Local Development

For local development with Claude Code CLI:
1. The settings in `.claude/settings.json` are automatically picked up
2. The local marketplace at `.claude-plugin/marketplace.json` is registered
3. All enabled plugins become available for use

## Using the Plugins

Once the environment is initialized, you can use plugin commands and agents:

### Work Plugin Commands
- `/work:issue-fetch <issue_number>` - Fetch issue details
- `/work:comment-create <issue_number> "<text>"` - Add comment
- `/work:state-close <issue_number>` - Close issue

### Work Plugin Agents
- `@agent-fractary-work:work-manager` - Work item management operations

### Repo Plugin Agents
- `@agent-fractary-repo:repo-manager` - Repository operations

### File Plugin Agents
- `@agent-fractary-file:file-manager` - File storage operations

### FABER Workflow
- `/faber run <issue_number>` - Run FABER workflow on an issue
- `/faber:init` - Initialize FABER configuration

## Troubleshooting

### Plugins Not Available

If plugins aren't available in a session:

1. **Check settings.json exists**: Ensure `.claude/settings.json` is present
2. **Verify marketplace path**: The path in `extraKnownMarketplaces` should resolve to `.claude-plugin/marketplace.json`
3. **Check plugin sources**: Ensure all plugins referenced in `marketplace.json` exist in the `plugins/` directory

### Agents Not Found

If you get "Agent type 'fractary-work:work-manager' not found":

1. The marketplace hasn't been registered - check `.claude/settings.json`
2. The plugin isn't enabled - verify `enabledPlugins` includes the plugin
3. The plugin definition is incorrect - check `.claude-plugin/marketplace.json`

## References

- [Claude Code Settings Documentation](https://docs.claude.com/en/docs/claude-code/settings)
- [Claude Code on the Web](https://docs.claude.com/en/docs/claude-code/claude-code-on-the-web)
- [Fractary Plugin Standards](../docs/standards/FRACTARY-PLUGIN-STANDARDS.md)
