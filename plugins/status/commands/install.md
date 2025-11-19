# Status Install Command

<CONTEXT>
You are the /status:install command for the fractary-status plugin.
Your role is to parse user input and invoke the status-line-manager skill to install the custom status line in the current project.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Invoke the status-line-manager skill
- Pass installation request to the skill
- Return the skill's response to the user

**YOU MUST NOT:**
- Perform installation yourself (the skill handles that)
- Execute scripts directly (delegate to skill)
- Skip verification steps

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   - No arguments required for this command

2. **Build structured request**
   - Create installation request

3. **Invoke skill**
   - Use the Skill tool with skill="fractary-status:status-line-manager"
   - Pass the structured request

4. **Return response**
   - The skill will handle installation and return results
   - Display results to user
</WORKFLOW>

<USAGE>
## Command Syntax

```bash
/status:install
```

No arguments required. Installs status line in current project.
</USAGE>

<SKILL_INVOCATION>
## Invoking the Skill

Invoke the status-line-manager skill with:

```
🎯 Installing Fractary Status Line Plugin

I'm using the fractary-status:status-line-manager skill to install the custom status line in your project.

Request:
{
  "operation": "install",
  "parameters": {}
}
```

The skill will:
1. Verify project is a git repository
2. Create plugin configuration directory (.fractary/plugins/status/)
3. Configure plugin settings
4. Verify installation
5. Return installation summary

Note: Hooks are managed at the plugin level and automatically activated when the plugin is installed.
StatusLine uses absolute path in project settings.json. Plugin hooks use ${CLAUDE_PLUGIN_ROOT}.
</SKILL_INVOCATION>

<ERROR_HANDLING>
Common errors:
- **Not in git repo**: Status line requires a git repository
- **Missing dependencies**: jq is required for JSON processing
- **Permission errors**: Need write access to .claude/ directory
</ERROR_HANDLING>

<NOTES>
## What Gets Installed

The installation process:
1. Creates `.fractary/plugins/status/` directory for plugin configuration
2. Creates `.fractary/plugins/status/config.json` with plugin settings
3. Updates `.gitignore` to exclude cache file

**Plugin-Level Components (Managed Automatically):**
- Hooks are registered in the plugin's marketplace entry and use `${CLAUDE_PLUGIN_ROOT}/scripts/`
- Scripts remain in plugin root directory (`~/.claude/plugins/marketplaces/fractary/plugins/status/scripts/`)
- UserPromptSubmit hook captures prompts automatically
- StatusLine is configured in project's `.claude/settings.json` with absolute path

**Note:** `${CLAUDE_PLUGIN_ROOT}` only works in plugin-level hooks, not in project settings.json!

## Status Line Features

Once installed and Claude Code is restarted, your status line will show:
- Current branch name
- Modified files count (±N)
- Issue number (#N) from branch name
- PR number (PR#N) if available
- Commits ahead (↑N) and behind (↓N)
- Last user prompt (truncated to 40 chars)

Format: `[branch] [±files] [#issue] [PR#pr] [↑ahead ↓behind] last: prompt...`
</NOTES>
