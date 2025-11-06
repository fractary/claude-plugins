# Complete FABER Workflow with New Plugins

End-to-end example demonstrating fractary-file, fractary-docs, fractary-spec, and fractary-logs in a FABER workflow.

## Scenario

Implement OAuth 2.0 authentication for a web application.

**Issue**: #123 - Add OAuth 2.0 Authentication
**Time**: ~3 hours
**Outcome**: Feature implemented, tested, documented, and archived

## Prerequisites

```bash
# 1. Initialize all plugins
/fractary-file:init --handler r2
/fractary-docs:init
/fractary-spec:init
/fractary-logs:init

# 2. Configure FABER
cat > .faber.config.toml <<'EOF'
[plugins]
file = "fractary-file"
docs = "fractary-docs"
spec = "fractary-spec"
logs = "fractary-logs"

[workflow.architect]
generate_spec = true

[workflow.evaluate]
validate_spec = true

[workflow.release]
archive_specs = true
archive_logs = true
EOF

# 3. Set cloud storage credentials
export R2_ACCOUNT_ID="your-account-id"
export R2_ACCESS_KEY_ID="your-access-key"
export R2_SECRET_ACCESS_KEY="your-secret-key"
```

## Workflow Execution

### Phase 1: Frame (5 minutes)

**Start FABER**:
```bash
/faber:run 123 --autonomy guarded
```

**What happens**:
1. **Fetch issue #123** from GitHub
2. **Session capture starts** automatically
   - Creates `/logs/sessions/session-123-2025-01-15-0900.md`
3. **Classify work** as "feature" (based on labels)
4. **Setup environment**

**Output**:
```
🎯 FABER Workflow Started
Issue: #123 - Add OAuth 2.0 Authentication
Type: Feature
Branch: feature/oauth-authentication

✓ Session logging started
✓ Environment ready

Next: Architect phase
```

---

### Phase 2: Architect (30 minutes)

**Auto-generates specification**:

FABER calls fractary-spec internally:
```
Use the @agent-fractary-spec:spec-manager agent to generate spec:
{
  "operation": "generate",
  "issue_number": "123",
  "template": "feature"
}
```

**Spec created**: `/specs/spec-123-oauth-authentication.md`

```markdown
---
spec_id: spec-123
issue_number: 123
status: active
created: 2025-01-15
template: feature
---

# Feature Spec: OAuth 2.0 Authentication

## User Story
As a **user**
I want **to log in with OAuth 2.0 providers (GitHub, Google)**
So that **I don't need to manage another password**

## Requirements
- [ ] OAuth 2.0 client configuration
- [ ] Authorization flow implementation
- [ ] Token storage (Redis)
- [ ] User profile mapping
- [ ] Session management
- [ ] Logout functionality

## User Flow
1. User clicks "Login with GitHub"
2. Redirect to GitHub authorization
3. User approves
4. Callback receives auth code
5. Exchange code for token
6. Store token, create session
7. User logged in ✓

## Technical Approach

### OAuth Providers
- GitHub
- Google
- (Extensible for more)

### Tech Stack
- passport.js for OAuth
- Redis for token storage
- Express sessions

### Architecture
```
User → Login Button → OAuth Provider → Callback → Token Exchange → Session
```

## Acceptance Criteria
- [ ] User can login with GitHub
- [ ] User can login with Google
- [ ] Tokens stored securely in Redis
- [ ] Session persists across requests
- [ ] User can logout
- [ ] Tests cover happy path and errors
- [ ] Documentation updated

## Testing
- Unit tests for OAuth flow
- Integration tests for providers
- E2E test for full flow
- Error scenarios covered

## Rollout
- Phase 1: Optional OAuth login
- Phase 2: Promote as primary login
- Phase 3: Deprecate password login (future)
```

**GitHub comment added**:
```markdown
📋 Specification Created

Specification generated for this issue:
- [spec-123-oauth-authentication.md](/specs/spec-123-oauth-authentication.md)

This spec will guide implementation and be validated before archival.
```

**Session log captures**:
```markdown
### [09:15] Claude
I've generated a comprehensive spec for OAuth 2.0 authentication.
The spec covers GitHub and Google providers, using passport.js...

🔑 **[09:20] Key Decision: Token Storage**
Decision: Use Redis for token storage
Rationale: Tokens should not persist in DB for security
```

---

### Phase 3: Build (2 hours)

**Implementation following spec**:

1. **Install dependencies**:
```bash
npm install passport passport-github2 passport-google-oauth20 redis
```

2. **Implement OAuth flow**:
   - `src/auth/oauth.ts` - OAuth configuration
   - `src/auth/strategies/github.ts` - GitHub strategy
   - `src/auth/strategies/google.ts` - Google strategy
   - `src/auth/middleware.ts` - Auth middleware
   - `src/routes/auth.ts` - Auth routes

3. **Configure Redis**:
   - `src/config/redis.ts` - Redis client

4. **Add tests**:
   - `tests/auth/oauth.test.ts` - Unit tests
   - `tests/integration/auth-flow.test.ts` - Integration tests

**Session log captures all work**:
```markdown
### [09:45] User
Let's start with the GitHub strategy.

### [09:46] Claude
I'll implement the GitHub OAuth strategy using passport-github2...

[Creates src/auth/strategies/github.ts]

### [10:30] User
Tests are failing with "token undefined"

### [10:31] Claude
The issue is in the callback - we're not checking if token exists...

[Fixes the bug]

🔑 **[10:35] Key Decision: Token Expiration**
Decision: 7-day token expiration with auto-renewal
Rationale: Balance between security and UX
Alternative: 30-day tokens rejected as too long
```

**Build logs captured**:
```bash
# During development
npm test > /logs/builds/123-test-$(date +%Y-%m-%d).log 2>&1
npm run build > /logs/builds/123-build-$(date +%Y-%m-%d).log 2>&1
```

---

### Phase 4: Evaluate (20 minutes)

**Validation runs automatically**:

```
Use the @agent-fractary-spec:spec-manager agent to validate:
{
  "operation": "validate",
  "issue_number": "123"
}
```

**Validation report**:
```
=== Spec Validation Report ===

Spec: spec-123-oauth-authentication.md
Issue: #123

✓ Requirements: Complete (6/6)
  ✓ OAuth client configuration
  ✓ Authorization flow
  ✓ Token storage
  ✓ User profile mapping
  ✓ Session management
  ✓ Logout functionality

✓ Acceptance Criteria: Complete (7/7)
  ✓ Login with GitHub
  ✓ Login with Google
  ✓ Tokens in Redis
  ✓ Session persistence
  ✓ Logout working
  ✓ Tests passing
  ✓ Docs updated

✓ Files Modified:
  ✓ src/auth/oauth.ts (created)
  ✓ src/auth/strategies/github.ts (created)
  ✓ src/auth/strategies/google.ts (created)
  ✓ src/auth/middleware.ts (modified)
  ✓ src/routes/auth.ts (created)
  ✓ src/config/redis.ts (created)

✓ Tests Added:
  ✓ tests/auth/oauth.test.ts (18 tests)
  ✓ tests/integration/auth-flow.test.ts (12 tests)

✓ Documentation Updated:
  ✓ docs/api/authentication.md (updated)
  ✓ docs/guides/setup.md (updated)

Overall: ✓ COMPLETE - Ready for release

=== End Report ===
```

**Tests run**:
```bash
npm test

OAuth Authentication
  ✓ should configure GitHub strategy
  ✓ should configure Google strategy
  ✓ should exchange code for token
  ✓ should store token in Redis
  ✓ should create user session
  ✓ should handle OAuth errors
  ...

30 tests passing
```

---

### Phase 5: Release (10 minutes)

**Create pull request**:
```bash
git add .
git commit -m "feat: Add OAuth 2.0 authentication (fixes #123)"
git push -u origin feature/oauth-authentication
```

**Merge PR** (via GitHub UI or CLI):
```bash
gh pr create --title "Add OAuth 2.0 Authentication" --body "Closes #123"
gh pr merge --squash
```

**Archive automatically triggers**:

**1. Archive Spec**:
```
Use the @agent-fractary-spec:spec-manager agent to archive:
{
  "operation": "archive",
  "issue_number": "123"
}
```

**What happens**:
- Spec uploaded to cloud: `archive/specs/2025/123.md`
- Archive index updated (local + cloud backup)
- Spec removed from `/specs`
- GitHub comment added with archive link

**2. Archive Logs**:
```
Use the @agent-fractary-logs:log-manager agent to archive:
{
  "operation": "archive",
  "issue_number": "123"
}
```

**What happens**:
- Session log compressed (gzip)
- Build logs compressed
- All logs uploaded to cloud: `archive/logs/2025/01/123/`
- Archive index updated
- Old logs removed from `/logs` (kept if < 30 days)
- GitHub comment added

**GitHub comments**:
```markdown
✅ Work Archived

This issue has been completed and archived!

**Specifications**:
- [OAuth Authentication Spec](https://storage.example.com/specs/2025/123.md) (18.4 KB)

**Session Logs**:
- [Session Log](https://storage.example.com/logs/2025/01/123/session.md.gz) (45.2 KB)
- [Build Logs](https://storage.example.com/logs/2025/01/123/build.log.gz) (12.1 KB)

**Archived**: 2025-01-15 14:30 UTC
**Validation**: Complete ✓
**Duration**: 2.5 hours
**Files Modified**: 12

These artifacts are permanently stored in cloud archive for future reference.
```

---

## After Workflow: Working State

### Local Workspace (Clean)

```
my-project/
├── /docs                      # Living documentation (in git)
│   ├── api/
│   │   └── authentication.md  # ✓ Updated
│   └── guides/
│       └── setup.md           # ✓ Updated
├── /specs                     # Only active specs
│   └── (empty - spec archived)
├── /logs                      # Only recent logs
│   └── (old logs archived)
└── src/                       # Implementation
    ├── auth/
    │   ├── oauth.ts           # ✓ Implemented
    │   ├── strategies/
    │   │   ├── github.ts
    │   │   └── google.ts
    │   └── middleware.ts
    └── ...
```

**Clean!** Old specs and logs archived to cloud, not cluttering workspace.

### Cloud Storage (Permanent Archive)

```
cloud-storage/
├── archive/
│   ├── specs/
│   │   └── 2025/
│   │       └── 123.md         # OAuth spec
│   └── logs/
│       └── 2025/
│           └── 01/
│               └── 123/
│                   ├── session-123.md.gz
│                   └── build-123.log.gz
```

**Searchable!** All historical data preserved and searchable.

## Later: Accessing Archived Content

### Read Archived Spec

**Scenario**: New similar work, want to reference OAuth implementation.

```bash
/fractary-spec:read 123
```

**Output**: Full spec streamed from cloud (no download needed).

### Search Logs

**Scenario**: Investigating similar OAuth issue.

```bash
/fractary-logs:search "OAuth token storage"
```

**Output**:
```
Found 3 matches:

[Cloud] archive/logs/2025/01/123/session-123.md.gz
  Line 45: Discussing OAuth token storage in Redis...
  Line 67: Decision: Use Redis for token storage

[Local] /logs/sessions/session-145.md
  Line 23: Referencing OAuth implementation from #123

Search complete: 3 results (1 local, 2 cloud)
```

### Link in Documentation

**docs/api/authentication.md**:
```markdown
# Authentication API

## OAuth 2.0 Implementation

Our OAuth implementation supports GitHub and Google providers.

For implementation details, see [archived spec](https://storage.example.com/specs/2025/123.md).

## Endpoints

POST /auth/oauth/github
...
```

## Cost Analysis

### Storage Costs (Example: Cloudflare R2)

**One issue** (#123):
- Spec: 18 KB
- Session log (compressed): 45 KB
- Build logs (compressed): 12 KB
- **Total**: 75 KB

**Monthly cost for 100 issues**:
- Storage: 100 × 75 KB = 7.5 MB
- Cost: 7.5 MB × $0.015/GB = $0.0001125/month
- **Effective cost**: ~$0 (under minimum billing)

**Yearly cost for 1,000 issues**:
- Storage: 1,000 × 75 KB = 75 MB
- Cost: 75 MB × $0.015/GB = $0.001125/month × 12 = $0.0135/year
- **Effective cost**: ~$0.01/year

**Conclusion**: Storage costs are negligible for most projects.

## Time Savings

**Before** (manual management):
- Manual spec creation: 30 min
- Manual logging: 10 min/hour
- Manual archival: 15 min
- Manual GitHub comments: 5 min
- **Total overhead**: ~1.5 hours per issue

**After** (automated):
- Spec auto-generated: 2 min
- Logging automatic: 0 min
- Archival automatic: 2 min
- GitHub comments automatic: 0 min
- **Total overhead**: ~5 minutes per issue

**Time saved**: ~1.5 hours per issue

For 100 issues/year: **150 hours saved**

## Key Takeaways

1. **Automatic**: Spec generation, validation, archival all automatic
2. **Clean workspace**: Only active specs/logs locally
3. **Searchable history**: Archived content accessible and searchable
4. **Negligible cost**: Cloud storage costs pennies per year
5. **Time savings**: ~1.5 hours per issue
6. **Better context**: Claude isn't confused by old specs
7. **Permanent record**: Never lose implementation details

## Next Steps

1. **Run your first workflow**:
   ```bash
   /faber:run <your-issue> --autonomy guarded
   ```

2. **Review what was created**:
   - Spec in `/specs`
   - Session log in `/logs/sessions`
   - Validation report

3. **Complete and archive**:
   - Implement following spec
   - Merge PR
   - Archive happens automatically

4. **Access later**:
   ```bash
   /fractary-spec:read <issue>
   /fractary-logs:search "topic"
   ```

## Troubleshooting

See [Troubleshooting Guide](../guides/troubleshooting.md) for common issues.

---

**Example Version**: 1.0 (2025-01-15)
