# Log Analysis Types

## Overview

The log-analyzer skill provides four types of analysis to extract insights from operational logs:

1. **Error Extraction** - Find and categorize all errors
2. **Pattern Detection** - Identify recurring issues
3. **Session Summary** - Summarize specific sessions
4. **Time Analysis** - Analyze time spent on work

## Error Extraction

### Purpose
Find all error messages in logs with context.

### Usage
```bash
# Analyze specific issue
/fractary-logs:analyze errors --issue 123

# Analyze all logs
/fractary-logs:analyze errors

# Analyze date range
/fractary-logs:analyze errors --since 2025-01-01
```

### Output
```
Error Analysis for Issue #123

Found 3 errors:

1. [2025-01-15 10:15] TypeError: Cannot read property 'user'
   File: src/auth/middleware.ts:42
   Context: JWT token validation
   Session: session-123-2025-01-15.md

   Code context:
   40: const token = req.headers.authorization
   41: const decoded = jwt.verify(token)
   42: const userId = decoded.user.id  // ERROR HERE
   43: const user = await findUser(userId)

2. [2025-01-15 11:30] CORS error: Origin not allowed
   ...
```

### Error Types Detected
- TypeError, ReferenceError, SyntaxError
- Exceptions (all languages)
- Failed operations
- Timeouts
- Fatal errors
- Build/compilation errors
- Test failures

### Use Cases
- **Debugging**: Find all errors for specific issue
- **Root cause analysis**: Understand error patterns
- **Quality review**: Check error frequency
- **Documentation**: Record known errors

## Pattern Detection

### Purpose
Find recurring issues across multiple logs.

### Usage
```bash
# Find patterns since date
/fractary-logs:analyze patterns --since 2025-01-01

# Find patterns in date range
/fractary-logs:analyze patterns --since 2024-12-01 --until 2025-01-31
```

### Output
```
Common Patterns (Last 30 days)

1. OAuth Configuration Issues (5 occurrences)
   Issues: #123, #124, #130
   Pattern: CORS errors during redirect
   Common solution: Update origin whitelist in config
   First seen: 2025-01-10
   Last seen: 2025-01-28

2. Database Connection Timeouts (3 occurrences)
   Issues: #125, #127, #133
   Pattern: High load on user table queries
   Common solution: Add connection pooling, index optimization

3. JWT Token Expiration (8 occurrences)
   ...
```

### Pattern Types
- Configuration errors (CORS, auth, database)
- Performance issues (timeouts, memory, CPU)
- Integration failures (API, third-party services)
- Infrastructure problems (network, deployment)
- Code issues (null references, type errors)

### Use Cases
- **Prevention**: Learn from past mistakes
- **Documentation**: Build knowledge base
- **Process improvement**: Identify systemic issues
- **Onboarding**: Show new developers common pitfalls

## Session Summary

### Purpose
Generate concise summary of a session.

### Usage
```bash
# Summarize specific issue session
/fractary-logs:analyze session 123

# Summarize by session ID
/fractary-logs:analyze session session-123-2025-01-15
```

### Output
```
Session Summary: Issue #123 - User Authentication

**Duration**: 2h 30m (150 minutes)
**Date**: 2025-01-15 09:00 - 11:30 UTC
**Messages**: 47
**Code Blocks**: 12
**Files Modified**: 8
**Status**: Completed

**Key Decisions**:
- OAuth2 over Basic Auth (security, easier third-party integration)
- JWT in HttpOnly cookies (prevent XSS)
- Redis for session storage (fast, scalable)
- 15-minute access tokens, 7-day refresh tokens

**Issues Encountered**:
- CORS configuration error (resolved in 15 minutes)
  Solution: Updated whitelist in CORS config

- Token refresh race condition (resolved in 30 minutes)
  Solution: Implemented mutex lock for refresh operations

**Files Created**:
- src/auth/oauth/provider.interface.ts
- src/auth/oauth/google-provider.ts
- src/auth/oauth/github-provider.ts
- src/auth/jwt/token-manager.ts

**Files Modified**:
- src/app.module.ts (added OAuth module)
- config/oauth.json (provider configuration)

**Tests Added**:
- OAuth flow tests (Google, GitHub)
- Token refresh tests
- Invalid token handling tests

**Outcome**: Successfully implemented, all tests passing
**Follow-up**: Add rate limiting, Microsoft OAuth provider
```

### Information Extracted
- Duration and timestamps
- Message and code block counts
- Key architectural decisions
- Problems encountered and solutions
- Files created/modified
- Testing coverage
- Overall outcome
- Next steps

### Use Cases
- **Handoff**: Share session context with team
- **Documentation**: Record implementation approach
- **Review**: Understand what was done
- **Learning**: Study successful implementations

## Time Analysis

### Purpose
Analyze time spent on work items and identify patterns.

### Usage
```bash
# Analyze time since date
/fractary-logs:analyze time --since 2025-01-01

# Analyze specific month
/fractary-logs:analyze time --since 2025-01-01 --until 2025-01-31

# Analyze all time
/fractary-logs:analyze time --since 2024-01-01
```

### Output
```
Time Analysis (January 2025)

**Overall Statistics**:
- Total sessions: 23
- Total development time: 52h 30m
- Average session duration: 2h 17m
- Median session duration: 1h 45m

**Time by Issue**:
- Issue #123 (User Auth): 4h 30m (3 sessions)
- Issue #125 (API Refactor): 3h 45m (2 sessions)
- Issue #130 (DB Migration): 3h 15m (2 sessions)
- Issue #127 (Bug Fixes): 2h 30m (5 sessions)
- Other issues: 38h 30m (11 sessions)

**By Issue Type**:
- Features: 35h (67%) - 15 sessions
  Average: 2h 20m per session

- Bugs: 12h (23%) - 6 sessions
  Average: 2h per session

- Refactoring: 5h 30m (10%) - 2 sessions
  Average: 2h 45m per session

**By Day of Week**:
- Monday: 12h (5 sessions)
- Tuesday: 8h 30m (4 sessions)
- Wednesday: 10h 30m (4 sessions)
- Thursday: 7h (3 sessions)
- Friday: 9h (4 sessions)
- Weekend: 5h 30m (3 sessions)

**Longest Sessions**:
1. Issue #123 (User Auth): 2h 30m - 2025-01-15
2. Issue #125 (API Refactor): 2h 15m - 2025-01-20
3. Issue #130 (DB Migration): 2h 00m - 2025-01-22

**Shortest Sessions**:
1. Issue #129 (Quick Fix): 15m - 2025-01-18
2. Issue #132 (Documentation): 20m - 2025-01-25
3. Issue #135 (Config Change): 25m - 2025-01-28

**Productivity Insights**:
- Most productive time: Wednesdays (2h 37m avg)
- Longest focus: Mid-week sessions
- Quick fixes: 20-30m average
- Complex features: 2-3h average
```

### Metrics Calculated
- Total time and session count
- Average and median durations
- Time by issue and type
- Day of week patterns
- Longest and shortest sessions
- Productivity trends

### Use Cases
- **Estimation**: Better time estimates for future work
- **Planning**: Understand capacity and velocity
- **Productivity**: Identify productive periods
- **Reporting**: Time tracking and reporting
- **Retrospectives**: Review team performance

## Advanced Analysis

### Combining Analysis Types

**Error patterns over time**:
```bash
# Find errors
/fractary-logs:analyze errors --since 2024-12-01

# Identify patterns
/fractary-logs:analyze patterns --since 2024-12-01

# Compare: Are same errors recurring?
```

**Session efficiency**:
```bash
# Get session summary
/fractary-logs:analyze session 123

# Check time spent
/fractary-logs:analyze time --issue 123

# Calculate: Time vs. complexity
```

### Custom Analysis

For custom analysis, use search + manual review:
```bash
# Find specific pattern
/fractary-logs:search "specific pattern" --since 2024-01-01

# Extract relevant sessions
/fractary-logs:read <issue>

# Analyze manually or pipe to custom scripts
```

## Best Practices

### Regular Analysis
Run analyses regularly:
- **Weekly**: Error extraction for current work
- **Monthly**: Pattern detection across all work
- **Quarterly**: Time analysis for planning

### Documentation
Document findings:
- Add patterns to knowledge base
- Update onboarding materials
- Create troubleshooting guides

### Action Items
Turn insights into action:
- Fix recurring errors
- Update configurations
- Improve processes
- Adjust estimates

### Share Learning
Share analysis results:
- Team retrospectives
- Documentation updates
- Architecture decision records
- Best practices guides
