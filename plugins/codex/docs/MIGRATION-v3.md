# Migration Guide: v2.0 to v3.0

This guide covers migrating from codex v2.0 (push-based sync) to v3.0 (pull-based retrieval with MCP integration).

## Overview

### What Changed

| Aspect | v2.0 | v3.0 |
|--------|------|------|
| **Architecture** | Push-based sync | Pull-based retrieval |
| **URI Format** | `@codex/project/path` | `codex://org/project/path` |
| **Cache Location** | `codex/` in project root | `.fractary/plugins/codex/cache/` |
| **Cache Index** | `.cache-index.json` | `cache/index.json` |
| **TTL Format** | Days (`ttl_days: 7`) | Seconds (`default_ttl: 604800`) |
| **Sources** | Array format | Object format (keyed by org) |
| **MCP** | Separate setup | Automatic with `/init` |
| **Offline** | Not supported | Built-in support |

### Key Benefits of v3.0

- **On-demand fetch**: Documents fetched when accessed, not pre-synced
- **MCP integration**: Automatic setup with init command
- **Offline mode**: Work without network using cached content
- **Multi-source**: GitHub orgs, HTTP endpoints, local files
- **Auth cascade**: Automatic authentication fallback
- **Current project detection**: Relative URI resolution

## Migration Steps

### Step 1: Backup Current Configuration

```bash
# Backup current config
cp .fractary/plugins/codex/config.json .fractary/plugins/codex/config.json.v2.backup
```

### Step 2: Run Migration Command

```bash
# Dry run first to preview changes
/fractary-codex:migrate --dry-run

# Apply migration
/fractary-codex:migrate
```

Or use the skill directly:
```bash
# Invoke config-migrator skill
```

### Step 3: Verify New Configuration

```bash
# Validate the setup
/fractary-codex:validate-setup

# Check cache health
/fractary-codex:cache-health
```

### Step 4: Update References

Run the reference validator to find and fix deprecated `@codex/` references:

```bash
# Find deprecated references
/fractary-codex:validate-refs

# Auto-fix references
/fractary-codex:validate-refs --fix
```

## Configuration Changes

### v2.0 Configuration

```json
{
  "version": "2.0",
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",
  "cache": {
    "ttl_days": 7,
    "max_size_mb": 500
  },
  "sources": [
    {
      "name": "fractary-codex",
      "type": "codex",
      "handler": "github",
      "handler_config": {
        "org": "fractary",
        "repo": "codex.fractary.com",
        "branch": "main"
      },
      "cache": {
        "ttl_days": 7
      }
    }
  ]
}
```

### v3.0 Configuration

```json
{
  "version": "3.0",
  "organization": "fractary",
  "project_name": "my-project",
  "codex_repo": "codex.fractary.com",
  "cache": {
    "default_ttl": 604800,
    "check_expiration": true,
    "fallback_to_stale": true,
    "offline_mode": false,
    "max_size_mb": 0,
    "auto_cleanup": true,
    "cleanup_interval_days": 7
  },
  "auth": {
    "default": "inherit",
    "fallback_to_public": true
  },
  "sources": {
    "fractary": {
      "type": "github-org",
      "ttl": 1209600,
      "branch": "main"
    }
  }
}
```

### Key Differences

1. **TTL in seconds**: `ttl_days: 7` → `default_ttl: 604800`
2. **Sources as object**: Array with `name` field → Object keyed by org name
3. **New fields**: `project_name`, `auth`, `offline_mode`, `fallback_to_stale`
4. **Simplified source config**: `handler_config` → direct properties
5. **Handler inference**: `type: "github-org"` infers GitHub handler

## URI Format Changes

### Old Format (v2.0)
```
@codex/project/path/to/file.md
```

### New Format (v3.0)
```
codex://org/project/path/to/file.md
```

### Migration Examples

```markdown
<!-- Old v2.0 -->
See @codex/auth-service/docs/oauth.md for details.
[API Guide](@codex/shared/standards/api-design.md)

<!-- New v3.0 -->
See codex://fractary/auth-service/docs/oauth.md for details.
[API Guide](codex://fractary/shared/standards/api-design.md)
```

The `validate-refs` command can auto-fix these:
```bash
/fractary-codex:validate-refs --fix
```

## Cache Location Changes

### Old Location (v2.0)
```
project-root/
├── codex/                    # Cache directory (gitignored)
│   ├── .cache-index.json    # Cache metadata
│   └── project/
│       └── path/
│           └── file.md
```

### New Location (v3.0)
```
project-root/
├── .fractary/
│   └── plugins/
│       └── codex/
│           ├── config.json  # Configuration
│           └── cache/       # Cache directory (gitignored)
│               ├── index.json
│               └── org/
│                   └── project/
│                       └── path/
│                           └── file.md
```

### Cache Migration

The migration command handles cache relocation:
1. Moves files from `codex/` to `.fractary/plugins/codex/cache/`
2. Updates cache index format
3. Adds organization prefix to paths
4. Updates `.gitignore` entries

## Command Changes

### Deprecated Commands (v2.0)

These commands are deprecated and will be removed:

```bash
# Deprecated - use fetch instead
/fractary-codex:sync-project my-project --from-codex

# Deprecated - individual fetches are faster
/fractary-codex:sync-org --from-codex
```

### New Commands (v3.0)

```bash
# Fetch documents on-demand
/fractary-codex:fetch codex://fractary/auth-service/docs/oauth.md

# Validate setup
/fractary-codex:validate-setup

# Validate references
/fractary-codex:validate-refs [--fix]

# Cache management
/fractary-codex:cache-list
/fractary-codex:cache-clear --expired
/fractary-codex:cache-health [--fix]
/fractary-codex:cache-metrics
```

## MCP Server Changes

### Old Setup (Manual)

Required manual configuration in `.claude/config.json`:
```json
{
  "mcpServers": {
    "fractary-codex": {
      "command": "node",
      "args": ["..."],
      "env": {
        "CODEX_CACHE_PATH": "${workspaceFolder}/codex",
        "CODEX_CONFIG_PATH": "..."
      }
    }
  }
}
```

### New Setup (Automatic)

```bash
# Init command handles everything
/fractary-codex:init --org fractary --codex codex.fractary.com

# Or install MCP separately
./scripts/install-mcp.sh
```

The MCP server is now registered in `.claude/settings.json` and uses the config path to find the cache.

## Handling Breaking Changes

### 1. Scripts Using Old Paths

Update any scripts that reference the old cache location:

```bash
# Old
cat codex/.cache-index.json
ls codex/project/

# New
cat .fractary/plugins/codex/cache/index.json
ls .fractary/plugins/codex/cache/org/project/
```

### 2. CI/CD Pipelines

Update pipeline configurations:

```yaml
# Old
cache:
  paths:
    - codex/

# New
cache:
  paths:
    - .fractary/plugins/codex/cache/
```

### 3. Git Configuration

The migration updates `.gitignore`:

```gitignore
# Old entry (can be removed)
codex/

# New entry (added by migration)
.fractary/plugins/codex/cache/
```

### 4. Environment Variables

New environment variables:
- `CODEX_CONFIG_PATH`: Path to config.json (for MCP server)
- `GITHUB_TOKEN`: Used in auth cascade (optional)
- Source-specific tokens via `token_env` config

## Rollback

If you need to rollback:

1. **Restore backup:**
   ```bash
   cp .fractary/plugins/codex/config.json.v2.backup .fractary/plugins/codex/config.json
   ```

2. **Restore cache location:**
   ```bash
   mv .fractary/plugins/codex/cache codex
   ```

3. **Update `.gitignore`** to use old entries

4. **Remove MCP registration:**
   ```bash
   ./scripts/uninstall-mcp.sh
   ```

## Troubleshooting

### Migration Fails

1. **Check config validity:**
   ```bash
   jq . .fractary/plugins/codex/config.json
   ```

2. **Manual migration:**
   - Create v3.0 config manually
   - Run `/fractary-codex:init`

### References Not Found

1. **Check URI format:**
   ```
   # Wrong
   @codex/project/path
   codex://project/path  # missing org

   # Correct
   codex://org/project/path
   ```

2. **Run reference validator:**
   ```bash
   /fractary-codex:validate-refs
   ```

### Cache Issues

1. **Clear and rebuild:**
   ```bash
   /fractary-codex:cache-clear --all
   ```

2. **Reinitialize:**
   ```bash
   /fractary-codex:init --force
   ```

## Timeline

The migration follows a staged rollout:

| Stage | Timeline | Status |
|-------|----------|--------|
| Stage 1 | Months 0-3 | **Current** - Both systems work |
| Stage 2 | Months 3-6 | v2.0 deprecated, warnings shown |
| Stage 3 | Months 6-9 | Sync commands show errors |
| Stage 4 | Months 9-12 | v2.0 removed, v3.0 only |

Migrate early to avoid disruption and benefit from v3.0 features.

## Related Documentation

- [README](../README.md) - Plugin overview
- [MCP Integration](./MCP-INTEGRATION.md) - MCP setup guide
- [SPEC-00033](../../../specs/SPEC-00033-codex-mcp-server-and-sync-unification.md) - Technical specification
