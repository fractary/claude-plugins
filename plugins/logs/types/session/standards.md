# Session Log Standards

## Purpose

Session logs capture complete Claude Code conversation sessions for:
- Historical reference and context recovery
- Debugging and troubleshooting
- Learning and knowledge sharing
- Audit and compliance
- Performance analysis

## Required Sections

All session logs MUST include:

1. **Session Metadata** - Session ID, issue number, date, duration, tokens
2. **Conversation Log** - Complete conversation transcript
3. **Session Summary** - High-level summary of what was accomplished
4. **Key Decisions** - Important decisions made during session
5. **Action Items** - Follow-up tasks identified
6. **Files Modified** - List of files created/modified
7. **Commands Executed** - Tools and commands used
8. **Session End** - End time, final status, outcome

## Optional Sections

- **Context Switches** - Major context changes or topic shifts
- **Errors Encountered** - Errors and how they were resolved
- **Learning Points** - Key insights or lessons learned
- **References** - Links to related documentation or issues

## Capture Rules

### What to Capture

**ALWAYS capture**:
- Full conversation transcript (user messages + assistant responses)
- All tool invocations and results
- File operations (read, write, edit)
- Command executions (bash, git, etc.)
- Session metadata (start time, end time, duration, tokens)
- Associated issue/work item numbers
- Repository and branch context

**MAY capture**:
- Screenshots or visual content (if referenced)
- External links visited
- Context from previous sessions (if relevant)

### What to Redact

**ALWAYS redact** (before saving or archiving):
- API keys, tokens, passwords, secrets
- Personal Identifiable Information (PII): emails, names (unless workspace members), addresses
- Sensitive file paths that reveal internal structure
- Internal URLs or endpoints
- Database credentials or connection strings
- Private repository names (if not already public)

**Redaction format**: Replace with `[REDACTED:<type>]`
- Example: `password: [REDACTED:SECRET]`
- Example: `user@email.com` → `[REDACTED:EMAIL]`

### Real-Time vs Batch Capture

**Real-time capture** (preferred):
- Stream conversation to log file as it happens
- Append entries incrementally
- Lower memory usage, immediate availability

**Batch capture** (fallback):
- Capture full conversation at session end
- Single write operation
- Used when streaming not possible

## Naming Conventions

### File Names

Pattern: `session-{session_id}-{issue}-{slug}.md`

Examples:
- `session-abc123def-gh-125-refactor-logs-plugin.md`
- `session-xyz789abc-standalone-explore-codebase.md`
- `session-def456ghi-gh-084-add-csv-export.md`

### Session IDs

- **Format**: UUID v4 (8-4-4-4-12 hex digits)
- **Example**: `abc123de-f456-789a-bcde-f0123456789a`
- **Generation**: Use `uuidgen` or equivalent
- **Uniqueness**: Global uniqueness guaranteed

### Title Format

- **With Issue**: `Session #{issue}: {issue title}`
- **Without Issue**: `Session: {descriptive title}`
- Examples:
  - `Session #125: Refactor logs plugin with log types`
  - `Session: Explore authentication implementation`

## Content Guidelines

### Conversation Transcript

- **Format**: Preserve original markdown structure
- **User messages**: Prefix with `**User**:` or `> ` (quote)
- **Assistant messages**: Prefix with `**Assistant**:` or no prefix
- **Tool use**: Include tool calls and results
- **Timestamps**: Optional but recommended for long sessions

### Session Summary

- **Length**: 2-5 paragraphs
- **Focus**: What was accomplished, not how
- **Include**:
  - Primary goal of session
  - Key outcomes achieved
  - Major decisions made
  - Next steps identified

### Key Decisions

- **Format**: Bullet list, one decision per line
- **Structure**: Decision + rationale
- **Example**: "Chose SQLite over PostgreSQL for simpler deployment and lower overhead"

### Action Items

- **Format**: Checkbox list (`- [ ]`)
- **Specificity**: Actionable, not vague
- **Example**:
  - ✅ `- [ ] Create database migration for user_sessions table`
  - ❌ `- [ ] Fix database stuff`

## Redaction Examples

### API Keys and Secrets

```markdown
# Before
export ANTHROPIC_API_KEY="sk-ant-1234567890abcdef"

# After
export ANTHROPIC_API_KEY="[REDACTED:API_KEY]"
```

### Personal Information

```markdown
# Before
User: john.doe@company.com reported this issue

# After
User: [REDACTED:EMAIL] reported this issue
```

### File Paths

```markdown
# Before
/Users/john/projects/secret-client/src/api.ts

# After
/path/to/project/src/api.ts
```

### Database Credentials

```markdown
# Before
postgres://admin:password123@db.internal.com:5432/production

# After
postgres://[REDACTED:USER]:[REDACTED:PASSWORD]@[REDACTED:HOST]:5432/[REDACTED:DB]
```

## Status Values

- **active**: Session currently in progress
- **stopped**: Session ended normally
- **archived**: Session archived to cloud storage
- **error**: Session ended with error/crash

## Best Practices

1. **Start capture immediately**: Begin logging from first message
2. **Include context**: Repository, branch, issue number
3. **Summarize at end**: Don't rely on auto-generated summaries alone
4. **Review before archive**: Check for sensitive data
5. **Link to work items**: Always associate with issue when applicable
6. **Use descriptive titles**: Make sessions searchable
7. **Capture decisions**: Document why, not just what
8. **Preserve formatting**: Keep code blocks, tables, lists intact
9. **Tag appropriately**: Use labels for categorization
10. **Archive promptly**: Don't let local logs accumulate
