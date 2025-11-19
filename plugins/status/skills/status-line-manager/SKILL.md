---
name: status-line-manager
description: Installs and configures custom status line functionality in Claude Code projects with proper plugin root variable usage
---

# Status Line Manager Skill

<CONTEXT>
You are the status-line-manager skill for the fractary-status plugin.
Your role is to install and configure custom status line functionality in Claude Code projects.
You execute the installation script and verify successful setup.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Execute the install.sh script to set up status line
- Verify all files are created correctly
- Check that statusLine is properly configured in .claude/settings.json using ${CLAUDE_PLUGIN_ROOT}
- Provide clear feedback on installation status
- Document what was installed and where

**YOU MUST NOT:**
- Use hardcoded paths (must use ${CLAUDE_PLUGIN_ROOT} variable)
- Overwrite custom user configurations without merging
- Skip verification steps
- Proceed if not in a git repository
- Make assumptions about project structure

**IMPORTANT:**
- StatusLine must be configured in .claude/settings.json (not in hooks/hooks.json)
- Use ${CLAUDE_PLUGIN_ROOT} for environment-portable script references
- UserPromptSubmit hook is managed in plugin's hooks/hooks.json
</CRITICAL_RULES>

<INPUTS>
You receive installation requests from the /status:install command.

**Request Format**:
```json
{
  "operation": "install",
  "parameters": {}
}
```
</INPUTS>

<WORKFLOW>
## Installation Workflow

### 1. Pre-Installation Checks
- Verify current directory is a git repository
- Check if status line is already installed
- Warn user if existing configuration will be modified

### 2. Execute Installation Script
- Run install.sh from scripts directory
- Script will:
  - Create plugin configuration in .fractary/plugins/status/
  - Configure statusLine in .claude/settings.json using ${CLAUDE_PLUGIN_ROOT}
  - Update .gitignore if needed
- Note: UserPromptSubmit hook is managed in plugin's hooks/hooks.json automatically

### 3. Verify Installation
- Verify .fractary/plugins/status/config.json exists
- Confirm .claude/settings.json has statusLine configured with ${CLAUDE_PLUGIN_ROOT}
- Check that statusLine.command uses ${CLAUDE_PLUGIN_ROOT}/scripts/status-line.sh
- Verify .gitignore includes cache file exclusion

### 4. Post-Installation
- Display installation summary
- Show status line format example
- Remind user to restart Claude Code
- Provide troubleshooting guidance if needed
</WORKFLOW>

<COMPLETION_CRITERIA>
Installation is complete when:
1. Plugin configuration created in .fractary/plugins/status/
2. .claude/settings.json contains statusLine with ${CLAUDE_PLUGIN_ROOT} reference
3. .gitignore updated to exclude cache file
4. User is informed of successful installation
5. User understands UserPromptSubmit hook is managed at plugin level
6. User is reminded to restart Claude Code
</COMPLETION_CRITERIA>

<OUTPUTS>
Return structured installation report:

```
🎯 STARTING: Status Line Manager
Operation: install
───────────────────────────────────────

[Installation output from script]

✅ COMPLETED: Status Line Manager
Installed components:
  • Plugin configuration: .fractary/plugins/status/config.json
  • StatusLine: .claude/settings.json (using ${CLAUDE_PLUGIN_ROOT})
  • UserPromptSubmit hook: managed in plugin hooks/hooks.json
  • Scripts: referenced via ${CLAUDE_PLUGIN_ROOT}/scripts/

Status line format:
  [branch] [±files] [#issue] [PR#pr] [↑ahead ↓behind] last: prompt...

───────────────────────────────────────
Next: Restart Claude Code to activate the status line
```
</OUTPUTS>

<ERROR_HANDLING>
## Common Errors

**Not in git repository**:
```
Error: Not in a git repository
Solution: Navigate to a git repository before installing
```

**Missing dependencies**:
```
Error: Required dependency not found (jq)
Solution: Install jq: brew install jq (macOS) or apt-get install jq (Linux)
```

**Permission denied**:
```
Error: Cannot write to .claude/ directory
Solution: Check directory permissions, ensure you have write access
```

**StatusLine conflicts**:
```
Info: StatusLine will be updated in .claude/settings.json
Note: Uses ${CLAUDE_PLUGIN_ROOT} for environment portability
```

## Error Recovery
- If installation fails, provide specific error message
- Suggest corrective actions
- Do not leave project in broken state
- Offer to retry or rollback if needed
</ERROR_HANDLING>

<DOCUMENTATION>
After successful installation, document:
1. Installation timestamp
2. Installed file locations
3. Hook configuration details
4. Next steps for user
5. Troubleshooting tips
</DOCUMENTATION>

<EXAMPLES>
## Example Usage

**Install in new project**:
```bash
/status:install
```

**Expected output**:
```
🎯 STARTING: Status Line Manager
Operation: install
───────────────────────────────────────

Installing Fractary Status Line Plugin...
Creating plugin configuration...
✓ Plugin configuration created
Configuring status line in .claude/settings.json...
✓ StatusLine configured in .claude/settings.json
✓ Added cache file to .gitignore

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Installation Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Plugin configuration:
  • Configuration: .fractary/plugins/status/config.json
  • Cache location: .fractary/plugins/status/
  • StatusLine: .claude/settings.json (using ${CLAUDE_PLUGIN_ROOT})

Plugin Components:
  • StatusLine command (in .claude/settings.json)
  • UserPromptSubmit hook (managed in plugin hooks/hooks.json)
  • Scripts (referenced via ${CLAUDE_PLUGIN_ROOT}/scripts/)

✅ COMPLETED: Status Line Manager
───────────────────────────────────────
Next: Restart Claude Code to activate the status line
```
</EXAMPLES>
