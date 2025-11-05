# ⚠️ ALPHA/PREVIEW STATUS

**Version**: 1.0.0-alpha
**Status**: Preview - Core functionality complete, cloud integration pending
**Updated**: 2025-01-15

## What Works ✅

### Fully Functional
- ✅ **Session Capture**: Record Claude Code conversations in markdown
- ✅ **Sensitive Data Redaction**: API keys, tokens, passwords, credit cards
- ✅ **Local Storage**: 30-day retention in `/logs` directory
- ✅ **Search**: Fast local search with filters
- ✅ **Analysis**: Error extraction, pattern detection, session summaries, time tracking
- ✅ **Archive Index**: Metadata tracking for all logs
- ✅ **Security**: Secure temp directories, input validation, concurrency control

### Commands Available
- `/fractary-logs:init` - Initialize configuration
- `/fractary-logs:capture <issue>` - Start session capture
- `/fractary-logs:stop` - Stop capture
- `/fractary-logs:log <issue> "message"` - Log specific message
- `/fractary-logs:search "query"` - Search logs
- `/fractary-logs:analyze <type>` - Analyze logs
- `/fractary-logs:read <issue>` - Read logs

## What's Not Yet Implemented ⚠️

### Cloud Upload Integration (In Progress)
**Status**: Architecture designed, awaiting implementation
**Limitation**: Files are NOT uploaded to cloud storage
**Workaround**: Use local-only mode

**What This Means**:
- Archive operations prepare files but don't upload them
- Logs remain in local storage only
- Archive index is created but contains simulated URLs
- Time-based cleanup (30 days) will delete old logs

**Configuration**:
Set `retention.strategy` to `"local"` to acknowledge local-only mode:
```json
{
  "retention": {
    "strategy": "local",
    "local_days": 30,
    "cloud_days": "n/a"
  }
}
```

**Implementation Plan**:
The architecture is designed for agent-to-agent integration:
1. log-manager agent prepares files for upload
2. log-manager invokes file-manager agent (fractary-file plugin)
3. file-manager performs actual upload
4. log-manager receives URLs and updates index

**To Complete**:
- [ ] Implement agent-to-agent invocation in log-manager
- [ ] Add upload orchestration logic
- [ ] Add error recovery for failed uploads
- [ ] Test with actual cloud providers (R2, S3, GCS)
- [ ] Update status to Beta

**Commands Affected**:
- `/fractary-logs:archive <issue>` - Prepares but doesn't upload
- `/fractary-logs:cleanup` - Prepares but doesn't upload

**ETA**: Next release (v1.0.0-beta)

## Recommended Usage (Alpha)

### ✅ Safe to Use
- **Session capture** for documentation
- **Local log storage** for recent work
- **Search and analysis** of local logs
- **Development and testing**

### ⚠️ Use with Caution
- **Archival operations** (files won't upload)
- **Long-term retention** (relies on local storage only)
- **Production systems** (wait for cloud integration)

### ❌ Do Not Use For
- **Critical log retention** (no cloud backup)
- **Compliance requirements** (no long-term archival)
- **Multi-environment deployments** (local storage only)

## Migration Path

When cloud integration is complete (v1.0.0-beta):
1. Existing local logs will be detected
2. Bulk upload operation will be available
3. Archive index will be updated with real URLs
4. Hybrid retention will activate

**Your data is safe**: All local logs are preserved and can be bulk-uploaded later.

## Reporting Issues

Found a bug or limitation?
- Report at: https://github.com/fractary/claude-plugins/issues
- Tag with: `logs-plugin`, `alpha`
- Include: Version number, configuration, logs

## Version History

- **1.0.0-alpha** (2025-01-15): Initial release, local-only mode
- **1.0.0-beta** (planned): Cloud integration complete
- **1.0.0** (planned): Production ready, full hybrid retention
