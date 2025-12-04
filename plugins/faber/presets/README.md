# FABER Configuration Presets

This directory contains pre-configured FABER workflow presets for common use cases. Presets provide sensible defaults and help you get started quickly.

## Available Presets

### software-basic.toml
**Conservative automation with manual review**

- **Autonomy**: `assist` - Stops before Release phase
- **Auto-merge**: Disabled
- **File storage**: Local filesystem
- **Best for**:
  - Getting started with FABER
  - Production codebases
  - Teams new to automation
  - When you want full control

**Workflow**: Frame → Architect → Build → Evaluate → **[PAUSE]** → Manual Release

### software-guarded.toml (RECOMMENDED)
**Balanced automation with approval gate**

- **Autonomy**: `guarded` - Pauses at Release for approval
- **Auto-merge**: Disabled
- **File storage**: Cloudflare R2
- **Best for**:
  - Standard production workflows
  - Mature teams with FABER experience
  - Balance of automation and control
  - Most common use case

**Workflow**: Frame → Architect → Build → Evaluate → Release → **[PAUSE]** → Manual Approval

### software-autonomous.toml
**Full automation with no manual intervention**

- **Autonomy**: `autonomous` - No pauses
- **Auto-merge**: Enabled ⚠️
- **File storage**: Cloudflare R2
- **Best for**:
  - Non-critical changes (docs, tests)
  - Internal tools
  - Experimental projects
  - Maximum automation

**Workflow**: Frame → Architect → Build → Evaluate → Release → **[AUTO-MERGE]**

⚠️ **WARNING**: Use with extreme caution in production environments!

## How to Use a Preset

### Method 1: Copy Preset (Recommended)

1. **Choose a preset** based on your needs
2. **Copy to your project root**:
   ```bash
   cp plugins/fractary-faber/presets/software-guarded.toml .faber.config.toml
   ```
3. **Edit placeholders** (values marked with `<...>`):
   ```toml
   name = "my-app"
   org = "acme"
   repo = "my-app"
   ```
4. **Configure authentication** (if needed):
   ```bash
   # For GitHub
   gh auth login

   # For Cloudflare R2
   aws configure
   ```
5. **Start using FABER**:
   ```bash
   /fractary-faber:run --work-id 123
   ```

### Method 2: Use init command (Auto-detection)

1. **Run init command** to auto-detect settings:
   ```bash
   /fractary-faber:init
   ```
2. **Compare with preset** to see what's different:
   ```bash
   diff .faber.config.toml plugins/fractary-faber/presets/software-guarded.toml
   ```
3. **Merge as needed** - Take the best of both

## Customizing Presets

After copying a preset, you can customize:

### Change Autonomy Level
```toml
[defaults]
autonomy = "assist"     # Stop before Release
autonomy = "guarded"    # Pause at Release for approval (recommended)
autonomy = "autonomous" # Full automation
autonomy = "dry-run"    # Simulate only
```

### Change File Storage
```toml
[project]
file_system = "local"  # Local filesystem (no setup)
file_system = "r2"     # Cloudflare R2 (requires AWS CLI + credentials)
file_system = "s3"     # AWS S3 (future)
```

### Change Work Tracking
```toml
[project]
issue_system = "github"  # GitHub Issues (uses gh CLI)
issue_system = "jira"    # Jira (requires credentials)
issue_system = "linear"  # Linear (requires API key)
```

### Adjust Retry Behavior
```toml
[workflow]
max_evaluate_retries = 3  # Default
max_evaluate_retries = 5  # More resilient
max_evaluate_retries = 1  # Fail fast
```

### Add Safety Rules
```toml
[safety]
protected_paths = [
    ".git/",
    "node_modules/",
    ".env",
    "config/production.json",  # Add your own
]
```

## Preset Comparison

| Feature | Basic | Guarded | Autonomous |
|---------|-------|---------|------------|
| Autonomy | assist | guarded | autonomous |
| Auto-merge | ❌ | ❌ | ✅ |
| Pauses | Before Release | At Release | Never |
| File Storage | Local | R2 | R2 |
| Production Ready | ⚠️ | ✅ | ❌ |
| Setup Complexity | Low | Medium | Medium |
| Manual Steps | Many | Few | None |
| Risk Level | Low | Low-Medium | High |

## Migrating Between Presets

### From Basic → Guarded

1. Set up Cloudflare R2 (or keep local storage)
2. Change autonomy to `guarded`
3. Test with a non-critical issue

### From Guarded → Autonomous

⚠️ **Only do this if you're confident!**

1. Test thoroughly in guarded mode first
2. Change autonomy to `autonomous`
3. Set `auto_merge = true`
4. Add extra safety rules
5. Start with non-critical changes

### From Autonomous → Guarded

If you want more control:

1. Change autonomy to `guarded`
2. Set `auto_merge = false`
3. Add approval requirements

## Environment-Specific Presets

You can maintain multiple preset files:

```bash
.faber.config.toml           # Active config
.faber.config.production.toml   # Production settings (guarded)
.faber.config.development.toml  # Development settings (autonomous)
```

Switch between them:
```bash
cp .faber.config.production.toml .faber.config.toml
```

## Validation

After creating or modifying your config, validate it:

```bash
# Validate configuration
/fractary-faber:audit

# Test with dry-run
/fractary-faber:run --work-id 123 --autonomy dry-run
```

## Troubleshooting

### "Configuration file not found"
Run `/fractary-faber:init` or copy a preset

### "Authentication failed"
Configure platform authentication:
- GitHub: `gh auth login`
- R2: `aws configure`

### "Invalid configuration"
Check TOML syntax and required fields

### "Protected path modified"
Review `safety.protected_paths` in config

## Best Practices

1. **Start with `software-basic`** if new to FABER
2. **Move to `software-guarded`** once comfortable
3. **Use `software-autonomous`** only for non-critical work
4. **Customize for your needs** - presets are starting points
5. **Version control your config** - commit `.faber.config.toml`
6. **Test with dry-run first** - `/fractary-faber:run --work-id <id> --autonomy dry-run`

## Additional Resources

- [FABER Documentation](../docs/)
- [Configuration Reference](../config/faber.example.toml)
- [Plugin README](../README.md)

## Questions?

Ask the FABER assistant:
```bash
/faber How do I configure FABER?
/faber What autonomy level should I use?
/faber What's the difference between presets?
```
