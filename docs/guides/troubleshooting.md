# Troubleshooting Guide

Comprehensive troubleshooting for fractary-file, fractary-docs, fractary-spec, and fractary-logs plugins.

## Table of Contents

1. [General Issues](#general-issues)
2. [fractary-file Issues](#fractary-file-issues)
3. [fractary-docs Issues](#fractary-docs-issues)
4. [fractary-spec Issues](#fractary-spec-issues)
5. [fractary-logs Issues](#fractary-logs-issues)
6. [Integration Issues](#integration-issues)
7. [Performance Issues](#performance-issues)
8. [Getting Help](#getting-help)

## General Issues

### Plugin Not Found

**Symptoms**:
- Command `/fractary-file:init` not recognized
- Error: "Plugin not found" or "Command not available"

**Causes**:
- Plugin not installed
- Plugin not in correct directory
- Plugin manifest missing

**Solutions**:

1. **Verify plugin exists**:
```bash
ls plugins/file plugins/docs plugins/spec plugins/logs
```

Expected: All four directories should exist.

2. **Check plugin manifests**:
```bash
ls plugins/*/. claude-plugin/plugin.json
```

Expected: Each plugin should have `.claude-plugin/plugin.json`.

3. **Restart Claude Code**:
```bash
# Exit and restart Claude Code session
```

4. **Verify plugin structure**:
```bash
# Each plugin should have:
plugins/PLUGIN_NAME/
├── .claude-plugin/
│   └── plugin.json
├── agents/
├── commands/
├── skills/
└── README.md
```

---

### Configuration File Not Found

**Symptoms**:
- "No configuration file found"
- Plugin uses defaults instead of custom config

**Causes**:
- Configuration not initialized
- Configuration in wrong location
- Permissions issue

**Solutions**:

1. **Initialize plugin**:
```bash
/fractary-file:init
/fractary-docs:init
/fractary-spec:init
/fractary-logs:init
```

2. **Check configuration location**:
```bash
# Project config (highest priority)
ls .fractary/plugins/{file,docs,spec,logs}/config.json

# Global config (fallback)
ls ~/.config/fractary/{file,docs,spec,logs}/config.json
```

3. **Verify permissions**:
```bash
# Config files should be readable
chmod 0600 .fractary/plugins/*/config.json
```

4. **Copy from example**:
```bash
cp plugins/file/config/config.example.json .fractary/plugins/file/config.json
# Repeat for other plugins
```

---

### Permission Denied

**Symptoms**:
- "Permission denied" when accessing files
- Cannot create directories
- Cannot write configuration

**Causes**:
- Insufficient file permissions
- Directory doesn't exist
- Read-only filesystem

**Solutions**:

1. **Check directory permissions**:
```bash
ls -la /docs /specs /logs
ls -la .fractary/plugins/
```

2. **Fix permissions**:
```bash
# Make directories writable
chmod -R u+w /docs /specs /logs .fractary/

# Secure config files
chmod 0600 .fractary/plugins/*/config.json
```

3. **Create missing directories**:
```bash
mkdir -p /docs /specs /logs
mkdir -p .fractary/plugins/{file,docs,spec,logs}
```

4. **Check filesystem**:
```bash
# Ensure not on read-only filesystem
df -h .
mount | grep $(pwd)
```

---

### Environment Variables Not Set

**Symptoms**:
- "Environment variable not defined"
- Cloud operations fail with authentication errors
- Configuration validation errors

**Causes**:
- Environment variables not exported
- Wrong variable names
- Variables set in wrong shell session

**Solutions**:

1. **Check current environment**:
```bash
env | grep -E "(AWS|R2|GOOGLE|GDRIVE)"
```

2. **Set required variables**:
```bash
# For R2
export R2_ACCOUNT_ID="your-account-id"
export R2_ACCESS_KEY_ID="your-access-key"
export R2_SECRET_ACCESS_KEY="your-secret-key"

# For S3
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"

# For GCS
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"

# For Google Drive
export GDRIVE_CLIENT_ID="your-client-id"
export GDRIVE_CLIENT_SECRET="your-client-secret"
```

3. **Make permanent** (add to shell profile):
```bash
# Add to ~/.bashrc or ~/.zshrc
echo 'export AWS_ACCESS_KEY_ID="..."' >> ~/.bashrc
source ~/.bashrc
```

4. **Use .env file** (optional):
```bash
# Create .env file
cat > .env <<'EOF'
R2_ACCOUNT_ID=your-account-id
R2_ACCESS_KEY_ID=your-access-key
R2_SECRET_ACCESS_KEY=your-secret-key
EOF

# Load environment
set -a; source .env; set +a
```

---

## fractary-file Issues

### Upload Fails

**Symptoms**:
- "Upload failed"
- Connection timeout
- Authentication error

**Causes**:
- Cloud provider misconfigured
- Network issues
- Invalid credentials
- Bucket doesn't exist

**Solutions**:

1. **Verify configuration**:
```bash
cat .fractary/plugins/file/config.json
```

Check:
- `active_handler` set correctly
- Handler configuration complete
- Environment variables referenced correctly

2. **Test credentials**:
```bash
# For S3/R2
aws s3 ls s3://your-bucket

# For GCS
gsutil ls gs://your-bucket

# For Google Drive
rclone ls gdrive:
```

3. **Check bucket exists**:
```bash
# S3
aws s3 mb s3://your-bucket --region us-east-1

# GCS
gsutil mb -l us-central1 gs://your-bucket
```

4. **Test with local handler** (bypass cloud):
```json
{
  "active_handler": "local"
}
```

5. **Check network**:
```bash
# Test connectivity
ping storage.example.com
curl -I https://storage.example.com
```

6. **Enable debug logging**:
```bash
# Add to config
{
  "global_settings": {
    "debug": true
  }
}
```

---

### Handler Not Configured

**Symptoms**:
- "Handler 'r2' is not configured"
- Default to local handler

**Causes**:
- Handler missing from config
- Typo in handler name
- Missing required fields

**Solutions**:

1. **Check active_handler**:
```json
{
  "active_handler": "r2"  // Must match a key in "handlers"
}
```

2. **Verify handler exists in config**:
```json
{
  "handlers": {
    "r2": {  // Handler key must exist
      "account_id": "...",
      "access_key_id": "...",
      "secret_access_key": "...",
      "bucket_name": "..."
    }
  }
}
```

3. **Copy handler from example**:
```bash
# View example
cat plugins/file/config/config.example.json

# Copy relevant handler section to your config
```

4. **Validate required fields**:
- **R2**: account_id, access_key_id, secret_access_key, bucket_name
- **S3**: region, bucket_name (+ optional credentials)
- **GCS**: project_id, bucket_name (+ optional service_account_key)
- **GDrive**: client_id, client_secret, folder_id, rclone_remote_name
- **Local**: base_path

---

### rclone Not Found (Google Drive)

**Symptoms**:
- "rclone: command not found"
- Google Drive operations fail

**Causes**:
- rclone not installed
- rclone not in PATH

**Solutions**:

1. **Install rclone**:
```bash
# macOS
brew install rclone

# Linux
curl https://rclone.org/install.sh | sudo bash

# Windows
choco install rclone
```

2. **Verify installation**:
```bash
rclone version
```

3. **Configure rclone for Google Drive**:
```bash
rclone config
```

Follow interactive prompts for OAuth setup.

See `plugins/file/skills/handler-storage-gdrive/docs/oauth-setup-guide.md` for detailed OAuth configuration.

---

### Read Operation Fails

**Symptoms**:
- "Failed to read file"
- File not found
- Truncated output

**Causes**:
- File doesn't exist
- File too large (> 50MB limit)
- Network timeout

**Solutions**:

1. **Verify file exists**:
```
Use @agent-fractary-file:file-manager to list:
{
  "operation": "list",
  "parameters": {
    "prefix": "path/to/file"
  }
}
```

2. **Check file size**:
```
Use @agent-fractary-file:file-manager to list:
{
  "operation": "list",
  "parameters": {
    "prefix": "exact/file/path.txt"
  }
}
```

If size > 50MB, use `download` instead of `read`.

3. **Increase max_bytes**:
```
Use @agent-fractary-file:file-manager to read:
{
  "operation": "read",
  "parameters": {
    "remote_path": "file.txt",
    "max_bytes": 52428800  // 50MB
  }
}
```

4. **Use download for large files**:
```
Use @agent-fractary-file:file-manager to download:
{
  "operation": "download",
  "parameters": {
    "remote_path": "large-file.txt",
    "local_path": "./downloaded.txt"
  }
}
```

---

## fractary-docs Issues

### Template Not Found

**Symptoms**:
- "Template 'custom-type' not found"
- Generation fails

**Causes**:
- Invalid doc_type
- Custom template doesn't exist
- Template path misconfigured

**Solutions**:

1. **Use standard templates**:

Available types: adr, design, runbook, api-spec, test-report, deployment, changelog, architecture, troubleshooting, postmortem

```bash
/fractary-docs:generate adr "Title"
```

2. **Check custom template exists**:
```bash
ls plugins/docs/skills/doc-generator/templates/custom-type.md.template
```

3. **Verify template path in config**:
```json
{
  "templates": {
    "custom_template_dir": "path/to/templates",
    "use_project_templates": true
  }
}
```

4. **Copy example template**:
```bash
cp plugins/docs/skills/doc-generator/templates/basic.md.template \
   plugins/docs/skills/doc-generator/templates/your-type.md.template
```

---

### Validation Fails

**Symptoms**:
- Validation errors or warnings
- "Required section missing"
- "Broken link detected"

**Causes**:
- Document doesn't meet quality standards
- Missing required sections
- Broken internal links
- Front matter incomplete

**Solutions**:

1. **Review validation report**:
```bash
/fractary-docs:validate docs/problematic-doc.md
```

2. **Auto-fix simple issues**:
```bash
/fractary-docs:validate docs/ --fix
```

Fixes:
- Trailing whitespace
- Line endings
- Blank lines
- Simple markdown

3. **Add missing sections**:
```
Use @agent-fractary-docs:docs-manager to update:
{
  "operation": "update",
  "file_path": "docs/doc.md",
  "append_section": "Missing Section",
  "content": "## Missing Section\n\nContent here..."
}
```

4. **Fix broken links**:
```bash
/fractary-docs:link check --fix
```

5. **Update front matter**:
```
Use @agent-fractary-docs:docs-manager to update metadata:
{
  "operation": "update",
  "file_path": "docs/doc.md",
  "metadata": {
    "status": "approved",
    "updated": "2025-01-15"
  }
}
```

---

### Section Not Found (During Update)

**Symptoms**:
- "Section 'Performance' not found"
- Update operation fails

**Causes**:
- Section heading doesn't exist
- Typo in section name
- Case mismatch

**Solutions**:

1. **Check exact heading**:
```bash
grep "^##" docs/file.md
```

Note exact heading text and capitalization.

2. **Match case exactly**:
```
# Correct
"section": "Performance"

# Incorrect
"section": "performance"  // Wrong case
```

3. **Use append if section doesn't exist**:
```
Use @agent-fractary-docs:docs-manager to update:
{
  "operation": "update",
  "file_path": "docs/doc.md",
  "append_section": "Performance",
  "content": "## Performance\n\nNew section..."
}
```

---

### Broken Links

**Symptoms**:
- Validation reports broken links
- Links point to non-existent files
- Relative paths incorrect

**Causes**:
- File moved or deleted
- Incorrect relative path
- Typo in link

**Solutions**:

1. **Find all broken links**:
```bash
/fractary-docs:link check
```

2. **Auto-fix links**:
```bash
/fractary-docs:link check --fix
```

3. **Manual fix**:
```
Use @agent-fractary-docs:docs-manager to update:
{
  "operation": "update",
  "file_path": "docs/doc.md",
  "find": "/docs/old-path.md",
  "replace": "/docs/new-path.md"
}
```

4. **Update index**:
```bash
/fractary-docs:link index
```

---

## fractary-spec Issues

### Spec Generation Fails - Issue Not Found

**Symptoms**:
- "Issue #123 not found"
- GitHub authentication error

**Causes**:
- Invalid issue number
- GitHub token not configured
- fractary-work plugin not set up
- No access to repository

**Solutions**:

1. **Verify issue exists**:
```bash
gh issue view 123
```

2. **Check GitHub authentication**:
```bash
gh auth status
```

If not authenticated:
```bash
gh auth login
```

3. **Verify fractary-work plugin**:
```bash
cat .fractary/plugins/work/config.json
```

4. **Test GitHub access**:
```bash
gh repo view
```

5. **Check repository access**:
```bash
# Ensure you have read access to repo
gh api /repos/OWNER/REPO
```

---

### Archive Fails - Pre-checks Failed

**Symptoms**:
- "Cannot archive: issue not closed"
- "Cannot archive: PR not merged"

**Causes**:
- Issue still open
- PR still in review
- Pre-archive checks enabled

**Solutions**:

1. **Close issue first**:
```bash
gh issue close 123
```

2. **Merge PR first**:
```bash
gh pr merge 456
```

3. **Use --force flag** (not recommended):
```bash
/fractary-spec:archive 123 --force
```

**Warning**: --force bypasses safety checks. Use only if you're sure.

4. **Disable pre-checks** (in config):
```json
{
  "archive": {
    "pre_archive": {
      "require_issue_closed": false,
      "require_pr_merged": false
    }
  }
}
```

---

### Validation Incomplete

**Symptoms**:
- Validation reports incomplete
- Not all acceptance criteria met
- Tests missing

**Causes**:
- Implementation not complete
- Tests not added
- Docs not updated

**Solutions**:

1. **Review validation report**:
```bash
/fractary-spec:validate 123
```

2. **Address missing items**:
- Implement remaining requirements
- Check acceptance criteria boxes in spec
- Add tests
- Update documentation

3. **Re-run validation**:
```bash
/fractary-spec:validate 123
```

4. **Archive with warning** (if acceptable):
```bash
/fractary-spec:archive 123  # Will prompt for confirmation
```

---

### Can't Read Archived Spec

**Symptoms**:
- "Spec not found in archive"
- Read operation fails

**Causes**:
- Archive index out of sync
- Cloud access issue
- Spec never archived

**Solutions**:

1. **Check archive index**:
```bash
cat .fractary/plugins/spec/archive-index.json | jq '.archives[] | select(.issue_number == "123")'
```

2. **Sync index from cloud**:
```bash
/fractary-spec:init
```

Output should show: "Synced N archived specs from cloud"

3. **Verify file plugin working**:
```
Use @agent-fractary-file:file-manager to list:
{
  "operation": "list",
  "parameters": {
    "prefix": "archive/specs/"
  }
}
```

4. **Re-archive if needed**:
```bash
# If spec still in /specs
/fractary-spec:archive 123
```

---

## fractary-logs Issues

### No Active Session

**Symptoms**:
- "No active session"
- Cannot stop or log to session

**Causes**:
- Session not started
- Session already stopped

**Solutions**:

1. **Start session**:
```bash
/fractary-logs:capture 123
```

2. **Check active sessions**:
```bash
ls /logs/sessions/
```

Recent files indicate active sessions.

---

### Archive Fails - Upload Error

**Symptoms**:
- "Failed to upload log"
- Archive operation fails

**Causes**:
- fractary-file plugin misconfigured
- Cloud storage issue
- Network error

**Solutions**:

1. **Test file plugin**:
```
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "/logs/test.txt",
    "remote_path": "test/test.txt"
  }
}
```

2. **Check file plugin config**:
```bash
cat .fractary/plugins/file/config.json
```

3. **Verify cloud credentials**:
```bash
env | grep -E "(AWS|R2|GOOGLE)"
```

4. **Logs remain local** until resolved:
```bash
ls /logs/sessions/
```

---

### Search Not Finding Results

**Symptoms**:
- Search returns no results
- Expected matches not found

**Causes**:
- Incorrect search query
- Logs not captured
- Archive index out of sync

**Solutions**:

1. **Check logs exist**:
```bash
ls /logs/sessions/
```

2. **Try broader search**:
```bash
/fractary-logs:search "broad term"
```

3. **Search local only** (faster):
```bash
/fractary-logs:search "term" --local-only
```

4. **Rebuild archive index**:
```bash
/fractary-logs:init
```

5. **Check archive index**:
```bash
cat .fractary/plugins/logs/archive-index.json
```

---

### Session Not Capturing

**Symptoms**:
- Session log file not updating
- Messages not recorded

**Causes**:
- Session not properly started
- File permissions issue
- Disk full

**Solutions**:

1. **Verify session active**:
```bash
ls -lh /logs/sessions/session-*$(date +%Y-%m-%d)*.md
```

Recent modification time indicates active session.

2. **Check permissions**:
```bash
ls -la /logs/sessions/
```

Should be writable by current user.

3. **Check disk space**:
```bash
df -h /logs
```

4. **Restart capture**:
```bash
/fractary-logs:stop
/fractary-logs:capture 123
```

---

## Integration Issues

### Plugins Not Working Together

**Symptoms**:
- fractary-spec can't archive (needs fractary-file)
- fractary-logs can't archive (needs fractary-file)

**Causes**:
- Missing dependencies
- Plugins not configured
- Dependency version mismatch

**Solutions**:

1. **Check plugin dependencies**:
```bash
jq '.requires' plugins/*/. claude-plugin/plugin.json
```

2. **Verify all required plugins present**:
```bash
ls plugins/file plugins/work plugins/repo plugins/docs plugins/spec plugins/logs
```

3. **Initialize all plugins**:
```bash
/fractary-file:init
/fractary-work:init
/fractary-repo:init
/fractary-docs:init
/fractary-spec:init
/fractary-logs:init
```

4. **Test integration**:
```bash
# Test spec → file integration
/fractary-spec:archive test-issue-number

# Test logs → file integration
/fractary-logs:archive test-issue-number
```

---

### FABER Workflow Not Using New Plugins

**Symptoms**:
- FABER runs but doesn't generate specs
- Logs not captured
- No archival

**Causes**:
- FABER config not updated
- Plugins not enabled in workflow

**Solutions**:

1. **Check FABER config**:
```bash
cat .faber.config.toml
```

Should have:
```toml
[plugins]
file = "fractary-file"
docs = "fractary-docs"
spec = "fractary-spec"
logs = "fractary-logs"

[workflow.architect]
generate_spec = true

[workflow.release]
archive_specs = true
archive_logs = true
```

2. **Update FABER config**:
```bash
vim .faber.config.toml
```

Add missing plugin declarations.

3. **Test workflow**:
```bash
/faber:run test-issue --autonomy guarded
```

4. **Validate plugin integration**:
```bash
./tools/validate-migration.sh
```

---

## Performance Issues

### Slow Upload/Download

**Symptoms**:
- Cloud operations take long time
- Timeouts

**Causes**:
- Network bandwidth
- Large files
- Geographic distance to cloud region

**Solutions**:

1. **Compress before upload**:
```bash
gzip large-file.log
# Then upload compressed file
```

2. **Use closer region**:
```json
{
  "handlers": {
    "s3": {
      "region": "us-west-2"  // Closer to you
    }
  }
}
```

3. **Increase timeout**:
```json
{
  "global_settings": {
    "timeout_seconds": 600  // 10 minutes
  }
}
```

4. **Monitor network**:
```bash
# During upload/download
nethogs
```

---

### High Storage Costs

**Symptoms**:
- Unexpected cloud storage bills
- Storage usage growing quickly

**Causes**:
- Too many archived files
- Files not compressed
- No lifecycle policies

**Solutions**:

1. **Check storage usage**:
```
Use @agent-fractary-file:file-manager to list:
{
  "operation": "list",
  "parameters": {
    "prefix": "archive/"
  }
}
```

2. **Enable compression** (already default):
```json
{
  "archive": {
    "compression": "gzip"
  }
}
```

3. **Set retention policies** (cloud provider):
```bash
# S3 lifecycle policy
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-bucket \
  --lifecycle-configuration file://lifecycle.json
```

4. **Clean old archives** (if acceptable):
```bash
# Delete archives older than 1 year
# Use with caution!
```

---

## Getting Help

### Self-Help Resources

1. **Plugin READMEs**:
   - `plugins/file/README.md`
   - `plugins/docs/README.md`
   - `plugins/spec/README.md`
   - `plugins/logs/README.md`

2. **User Guides**:
   - `docs/guides/fractary-file-guide.md`
   - `docs/guides/fractary-docs-guide.md`
   - `docs/guides/fractary-spec-guide.md`
   - `docs/guides/fractary-logs-guide.md`

3. **Specifications**:
   - `docs/specs/SPEC-0029-*.md` (full specifications)

4. **Examples**:
   - `docs/examples/` (sample workflows)
   - `docs/tutorials/` (step-by-step guides)

5. **Validation Tool**:
   ```bash
   ./tools/validate-migration.sh
   ```

### Reporting Issues

If problem persists:

1. **Gather information**:
   - Error message (full text)
   - Command that failed
   - Configuration files
   - Plugin versions
   - Environment (OS, shell, Claude Code version)

2. **Create minimal reproduction**:
   - Simplest steps to reproduce
   - Sample files if needed

3. **Report on GitHub**:
   - Go to repository
   - Create new issue
   - Use appropriate template
   - Include all gathered information

4. **Community Support**:
   - Check existing issues for similar problems
   - Search discussions
   - Ask in community channels

### Debug Mode

Enable verbose logging:

```json
{
  "global_settings": {
    "debug": true,
    "log_level": "verbose"
  }
}
```

Then retry failed operation and check logs.

---

**Version**: 1.0 (2025-01-15)

For additional help, see [Getting Help](#getting-help) section or open a GitHub issue.
