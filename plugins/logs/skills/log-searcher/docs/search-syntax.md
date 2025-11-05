# Log Search Syntax Guide

## Basic Search

### Simple Text Search
```bash
/fractary-logs:search "OAuth implementation"
```

Searches both local and archived logs for the phrase "OAuth implementation".

### Case-Insensitive
All searches are case-insensitive by default.

```bash
/fractary-logs:search "oauth"  # Matches OAuth, oauth, OAUTH
```

## Search Filters

### By Issue Number
```bash
/fractary-logs:search "error" --issue 123
```

Search only logs associated with issue #123.

### By Log Type
```bash
/fractary-logs:search "failed" --type build
```

Types:
- `session` - Claude Code conversation logs
- `build` - Build and compilation logs
- `deployment` - Deployment and infrastructure logs
- `debug` - Debug and error trace logs

### By Date Range
```bash
/fractary-logs:search "timeout" --since 2025-01-01 --until 2025-01-31
```

Search logs created within the date range.

### Multiple Filters
```bash
/fractary-logs:search "authentication" --type session --since 2025-01-01 --issue 123
```

Combine filters for precise search.

## Search Scope

### Local Only
```bash
/fractary-logs:search "recent issue" --local-only
```

Search only local logs (fast, last 30 days).

### Cloud Only
```bash
/fractary-logs:search "old implementation" --cloud-only
```

Search only archived logs (slower, comprehensive).

### Hybrid (Default)
```bash
/fractary-logs:search "pattern"
```

Searches both local and cloud, aggregates results.

## Regular Expression Search

### Enable Regex Mode
```bash
/fractary-logs:search --regex "error:\s+\w+"
```

### Common Patterns

**Find error codes**:
```bash
/fractary-logs:search --regex "ERROR-\d{3,}"
```

**Find URLs**:
```bash
/fractary-logs:search --regex "https?://[^\s]+"
```

**Find email addresses**:
```bash
/fractary-logs:search --regex "[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}"
```

**Find API calls**:
```bash
/fractary-logs:search --regex "POST|GET|PUT|DELETE /api/[^\s]+"
```

## Result Limits

### Default Limit
By default, returns up to 100 results.

### Custom Limit
```bash
/fractary-logs:search "common term" --max-results 10
```

### Context Lines
Control how many lines of context shown around matches:
```bash
/fractary-logs:search "error" --context 5
```

Default: 3 lines before and after match.

## Result Format

### Result Structure
```
Found 3 matches (2 local, 1 archived):

1. [Local] session-123-2025-01-15.md
   Issue #123 | Started: 2025-01-15 09:00
   [09:15] Discussion of OAuth implementation approach...
   Context: Previous message about requirements
   Context: Next message about design decisions

2. [Local] session-124-2025-01-16.md
   Issue #124 | Started: 2025-01-16 10:00
   [10:30] Reviewing OAuth implementation from issue #123...

3. [Archived] session-089-2024-12-10.md
   Issue #89 | Archived: 2024-12-20
   [14:20] Initial OAuth research and provider comparison...
```

### Result Information
Each result shows:
- Source: Local or Archived
- Filename
- Issue number
- Timestamp (for sessions)
- Matching line with context
- Archive date (if archived)

## Search Tips

### Effective Queries

**Specific is better**:
- ✅ "OAuth2 implementation strategy"
- ❌ "auth"

**Use filters to narrow**:
- ✅ `--type session --since 2025-01-01`
- ❌ No filters, too many results

**Try variations**:
- "authentication" OR "auth" OR "OAuth"
- Use separate searches or regex: `(authentication|auth|OAuth)`

### Performance Optimization

**Fast searches**:
- Use `--local-only` for recent work
- Use specific `--issue` numbers
- Use `--type` to reduce scope

**Comprehensive searches**:
- Use `--cloud-only` for historical deep dive
- Remove filters for broad search
- Increase `--max-results` if needed

## Examples

### Find All Errors for Issue
```bash
/fractary-logs:search "error" --issue 123 --type session
```

### Recent Authentication Work
```bash
/fractary-logs:search "authentication" --since 2025-01-01 --type session
```

### Database Issues Across All Time
```bash
/fractary-logs:search "database.*timeout" --regex --type debug
```

### Specific Implementation Pattern
```bash
/fractary-logs:search "class.*extends.*React.Component" --regex --type session
```

### Deployment Failures
```bash
/fractary-logs:search "failed" --type deployment --since 2024-12-01
```

## Advanced Usage

### Combining with Read
After finding a match:
```bash
/fractary-logs:search "interesting pattern" --issue 123
# Found in session-123-2025-01-15.md

/fractary-logs:read 123
# View full log
```

### Combining with Analysis
Search then analyze:
```bash
/fractary-logs:search "error" --issue 123
# Found multiple errors

/fractary-logs:analyze errors --issue 123
# Get detailed error analysis
```

### Historical Pattern Research
```bash
# Find how we solved similar issues before
/fractary-logs:search "similar problem description" --cloud-only

# Read historical solution
/fractary-logs:read <old-issue>

# Apply learnings to current issue
```

## Troubleshooting

### No Results Found

**Check spelling**:
- Try variations of search terms
- Remove filters to broaden search

**Check date range**:
- Logs older than 30 days are archived
- Use `--cloud-only` or hybrid search

**Check archive status**:
- Verify archive index exists: `ls /logs/.archive-index.json`
- Run cleanup if needed: `/fractary-logs:cleanup`

### Too Many Results

**Add filters**:
- Specify `--type`
- Add `--issue` number
- Narrow `--since` and `--until` dates

**Reduce limit**:
- Use `--max-results 20`
- Refine query to be more specific

### Slow Searches

**Optimize query**:
- Use `--local-only` for recent work
- Specify `--type` to reduce scope
- Use `--issue` for targeted search

**Cloud searches are slower**:
- Archive searches require index traversal
- Consider caching frequently accessed logs locally
