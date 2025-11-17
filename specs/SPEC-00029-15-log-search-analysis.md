# SPEC-00029-15: Log Search and Analysis

**Issue**: #29
**Phase**: 4 (fractary-logs Plugin)
**Dependencies**: SPEC-00029-12, SPEC-00029-13, SPEC-00029-14
**Status**: Draft
**Created**: 2025-01-15

## Overview

Implement log-searcher and log-analyzer skills to search across local and archived logs, extract patterns, identify errors, and generate insights from historical work.

## Search Capabilities

### 1. Local Search (Fast)
- Search /logs directory
- Grep-based, instant results
- Active/recent logs

### 2. Cloud Search (Comprehensive)
- Search archive index metadata
- Download and search matching archives
- Historical logs

### 3. Hybrid Search (Default)
- Search local first
- Extend to cloud if needed
- Rank by relevance

## Search Syntax

### Basic Text Search
```bash
/fractary-logs:search "OAuth implementation"

# Results:
Found 3 matches (2 local, 1 archived):

1. session-123-2025-01-15.md (local)
   [09:15] Discussion of OAuth implementation approach...

2. session-124-2025-01-16.md (local)
   [10:30] Reviewing OAuth implementation from issue #123...

3. session-089-2024-12-10.md (archived)
   [14:20] Initial OAuth research and provider comparison...
```

### Issue-Specific Search
```bash
/fractary-logs:search "error" --issue 123

# Search only logs for issue #123
```

### Date Range Search
```bash
/fractary-logs:search "deployment" --since 2025-01-01 --until 2025-01-31

# Search logs in January 2025
```

### Log Type Filter
```bash
/fractary-logs:search "failed" --type build

# Search only build logs
```

### Regular Expression Search
```bash
/fractary-logs:search --regex "error:\s+\w+" --type session

# Find error patterns in session logs
```

## Search Implementation

**scripts/search-local.sh**:
```bash
#!/bin/bash
set -euo pipefail

QUERY="$1"
LOG_DIR="/logs"
MAX_RESULTS="${2:-100}"

# Search with context
grep -r -i -n -C 3 "$QUERY" "$LOG_DIR" | head -n "$MAX_RESULTS"
```

**scripts/search-cloud.sh**:
```bash
#!/bin/bash
set -euo pipefail

QUERY="$1"
INDEX_FILE="/logs/.archive-index.json"

# Search index metadata first
MATCHING_ARCHIVES=$(jq -r \
    --arg query "$QUERY" \
    '.archives[] | select(.issue_title | test($query; "i")) | .issue_number' \
    "$INDEX_FILE")

if [[ -z "$MATCHING_ARCHIVES" ]]; then
    echo "No matches in archive metadata"
    exit 0
fi

# For each matching archive, download and search
for ISSUE in $MATCHING_ARCHIVES; do
    LOGS=$(jq -r \
        --arg issue "$ISSUE" \
        '.archives[] | select(.issue_number == $issue) | .logs[].cloud_url' \
        "$INDEX_FILE")

    for LOG_URL in $LOGS; do
        # Read from cloud without downloading
        CONTENT=$(fractary-file read "$LOG_URL")

        # Search content
        echo "$CONTENT" | grep -i -n -C 3 "$QUERY" || true
    done
done
```

## Analysis Capabilities

### 1. Error Extraction
Extract all errors from logs:
```bash
/fractary-logs:analyze errors --issue 123

# Output:
Error Analysis for Issue #123

Found 3 errors:

1. [2025-01-15 10:15] TypeError: Cannot read property 'user'
   File: src/auth/middleware.ts:42
   Context: JWT token validation

2. [2025-01-15 11:30] CORS error: Origin not allowed
   File: src/main.ts:15
   Context: OAuth redirect

3. [2025-01-15 14:00] Database connection timeout
   File: src/database/connection.ts:89
   Context: User lookup query
```

### 2. Pattern Detection
Find recurring patterns:
```bash
/fractary-logs:analyze patterns --since 2025-01-01

# Output:
Common Patterns (Last 30 days)

1. OAuth Configuration Issues (5 occurrences)
   - CORS errors during redirect
   - Solution: Update origin whitelist

2. Database Connection Timeouts (3 occurrences)
   - High load on user table
   - Solution: Add connection pooling

3. JWT Token Expiration (8 occurrences)
   - Users losing session mid-workflow
   - Solution: Implemented refresh token
```

### 3. Session Summary
Generate summary of session:
```bash
/fractary-logs:analyze session 123

# Output:
Session Summary: Issue #123

Duration: 2h 30m
Messages: 47
Code Blocks: 12
Files Modified: 8

Key Decisions:
- OAuth2 over Basic Auth
- JWT in HttpOnly cookies
- Redis for session storage

Issues Encountered:
- CORS configuration (15 min)
- Token refresh race condition (30 min)

Outcome: Successfully implemented, all tests passing
```

### 4. Time Analysis
Analyze time spent on issues:
```bash
/fractary-logs:analyze time --since 2025-01-01

# Output:
Time Analysis (Last 30 days)

Average session duration: 1h 45m
Total development time: 52h 30m

By issue type:
- Features: 35h (67%)
- Bugs: 12h (23%)
- Refactoring: 5h 30m (10%)

Longest sessions:
1. Issue #123 (User Auth): 2h 30m
2. Issue #125 (API Refactor): 2h 15m
3. Issue #130 (Database Migration): 2h 00m
```

## Analysis Scripts

**scripts/extract-errors.sh**:
```bash
#!/bin/bash
set -euo pipefail

ISSUE_NUMBER="$1"
LOG_DIR="/logs"

# Find all logs for issue
LOGS=$(find "$LOG_DIR" -name "*${ISSUE_NUMBER}*")

# Extract error patterns
for LOG in $LOGS; do
    # Look for common error patterns
    grep -i -E "(error|exception|failed|timeout):" "$LOG" || true
done | sort | uniq
```

**scripts/find-patterns.sh**:
```bash
#!/bin/bash
set -euo pipefail

SINCE_DATE="$1"
LOG_DIR="/logs"

# Find logs since date
LOGS=$(find "$LOG_DIR" -newermt "$SINCE_DATE")

# Extract and count common issues
declare -A PATTERNS

for LOG in $LOGS; do
    # Extract error types
    ERRORS=$(grep -i -oE "(CORS|timeout|connection|authentication) error" "$LOG" || true)

    # Count occurrences
    for ERROR in $ERRORS; do
        ((PATTERNS["$ERROR"]++))
    done
done

# Sort by frequency
for PATTERN in "${!PATTERNS[@]}"; do
    echo "${PATTERNS[$PATTERN]} $PATTERN"
done | sort -rn
```

## Commands

### /fractary-logs:search

```markdown
Search logs across local and cloud storage

Usage:
  /fractary-logs:search "<query>" [options]

Options:
  --issue <number>: Search only logs for specific issue
  --type <type>: Filter by log type (session|build|deployment|debug)
  --since <date>: Start date (YYYY-MM-DD)
  --until <date>: End date (YYYY-MM-DD)
  --regex: Treat query as regular expression
  --local-only: Search only local logs
  --cloud-only: Search only archived logs
  --max-results <n>: Limit results (default: 100)

Examples:
  /fractary-logs:search "OAuth error"
  /fractary-logs:search "timeout" --issue 123 --type build
  /fractary-logs:search --regex "error:\s+\w+" --since 2025-01-01
```

### /fractary-logs:analyze

```markdown
Analyze logs for patterns and insights

Usage:
  /fractary-logs:analyze <type> [options]

Types:
  errors: Extract all errors
  patterns: Find recurring patterns
  session: Summarize specific session
  time: Analyze time spent

Options:
  --issue <number>: Analyze specific issue
  --since <date>: Start date
  --until <date>: End date

Examples:
  /fractary-logs:analyze errors --issue 123
  /fractary-logs:analyze patterns --since 2025-01-01
  /fractary-logs:analyze session 123
  /fractary-logs:analyze time --since 2025-01-01
```

### /fractary-logs:read

```markdown
Read specific log (local or archived)

Usage:
  /fractary-logs:read <issue_number> [--type <type>]

Examples:
  /fractary-logs:read 123
  /fractary-logs:read 123 --type session
```

## Search Index Optimization

For faster cloud search, maintain searchable metadata:

```json
{
  "searchable_fields": {
    "issue_number": "123",
    "issue_title": "Implement user authentication",
    "keywords": ["oauth", "jwt", "authentication", "security"],
    "errors": ["CORS error", "timeout"],
    "decisions": ["OAuth2 over Basic Auth", "JWT tokens"],
    "files_modified": ["src/auth/oauth.ts", "src/auth/jwt.ts"],
    "duration_minutes": 150
  }
}
```

## Success Criteria

- [ ] Local search working (fast)
- [ ] Cloud search via index
- [ ] Hybrid search (local + cloud)
- [ ] Error extraction
- [ ] Pattern detection
- [ ] Session summarization
- [ ] Time analysis
- [ ] Search filters (issue, type, date)
- [ ] Regular expression support

## Timeline

**Estimated**: 3-4 days

## Next Steps

- **SPEC-00029-16**: FABER integration (all phases)
