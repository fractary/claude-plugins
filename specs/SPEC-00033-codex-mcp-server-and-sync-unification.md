# Codex MCP Server & Sync Unification

**Specification ID:** SPEC-00033
**Version:** 1.0.0
**Status:** Draft
**Created:** 2025-01-15
**Author:** System Architecture
**Related Specs:** SPEC-00012 (Codex Sync), SPEC-00030 (Knowledge Retrieval)
**Addendum:** [SPEC-00033-addendum-architectural-refinements.md](SPEC-00033-addendum-architectural-refinements.md)
**Implementation:** [WORK-00216](WORK-00216-codex-mcp-server-implementation-plan.md)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Solution Overview](#solution-overview)
4. [Technical Implementation](#technical-implementation)
5. [Universal Reference Resolution](#universal-reference-resolution)
6. [Multi-Source Architecture](#multi-source-architecture)
7. [Implementation Tasks](#implementation-tasks)
8. [Migration & Compatibility](#migration--compatibility)
9. [Testing & Validation](#testing--validation)

---

## Executive Summary

### Purpose

Unify the v2.0 sync commands with the v3.0 MCP-based retrieval architecture by:
1. Adding an MCP server that exposes `codex://` resources from a local cache
2. Modifying `/fractary-codex:init` to install the MCP server reference
3. Updating `--from-codex` sync to write to the ephemeral `codex/` cache directory
4. Making sync effectively serve as "prefetch" for the MCP server

### Key Insight

Rather than deprecating sync commands, we **repurpose** them:
- `--to-codex`: Unchanged - pushes project docs to central codex (publishing)
- `--from-codex`: Changed - now populates local `codex/` cache (prefetching)

This gives users the best of both worlds:
- **Familiar commands** from v2.0 sync
- **Ephemeral cache** from v3.0 architecture
- **MCP integration** for universal `codex://` access

### Strategic Value

1. **No breaking changes**: Sync commands continue to work
2. **Unified storage**: Everything goes to `codex/` (like `node_modules/`)
3. **MCP-first access**: Claude uses `codex://` URIs natively
4. **Simple mental model**: Init once, sync to prefetch, Claude reads via MCP

### Two Primary Use Cases

The system supports two distinct access patterns:

#### 1. Explicit References (On-Demand Fetch)

When documents are explicitly referenced in code, skills, agents, or other docs:

```markdown
<!-- In a skill or doc -->
See [OAuth Guide](codex://corthosai/auth-service/docs/oauth.md)
See [Schema Docs](codex://corthosai/etl.corthion.ai/docs/schema/overview.md)
```

**How it works**: When Claude encounters a `codex://` URI, the MCP server:
- Checks cache → returns if fresh
- If missing/expired → fetches on-demand, caches, returns

**Best for**: Known documents with stable paths referenced in other artifacts.

#### 2. Exploratory Access (Prefetch via Sync)

When Claude needs to browse/explore a collection of documents without pre-established references:

- "Look at the schema docs and help me understand the data model"
- "Review all the API docs in auth-service"
- "What patterns do you see across our documentation?"

**How it works**: User runs sync to prefetch entire directories:
```bash
/fractary-codex:sync-project corthosai/etl.corthion.ai/docs/schema/** --from-codex
```

Then Claude can explore via:
- Listing files in `codex/corthosai/etl.corthion.ai/docs/schema/`
- Reading any doc without waiting for fetch
- Pattern matching across multiple files

**Best for**: Ad-hoc exploration, bulk analysis, discovery of unknown documents.

#### When to Use Each

| Scenario | Approach | Why |
|----------|----------|-----|
| Doc references another doc | Explicit `codex://` | On-demand fetch handles it |
| Skill references a guide | Explicit `codex://` | Fetched when skill runs |
| "Help me with schema docs" | Prefetch via sync | Need docs locally to explore |
| "Review all our API docs" | Prefetch via sync | Bulk access, unknown paths |
| First time in a new project | Prefetch via sync | Populate cache for exploration |
| CI/CD or automation | Prefetch via sync | Ensure docs available offline |

---

## Problem Statement

### Current State

The codex plugin has two competing approaches:

**v2.0 Sync (SPEC-00012)**:
- `--from-codex` copies files into project root (permanent, committed)
- Manual command required
- No MCP integration
- Files can drift from source

**v3.0 Retrieval (SPEC-00030)**:
- Fetch on-demand to `codex/` cache (ephemeral, gitignored)
- MCP server for `codex://` URIs
- Cache-first with TTL
- Not yet fully implemented

### Problems

1. **Two mental models**: Users confused about sync vs fetch
2. **Permanent copies drift**: Files synced into project become stale
3. **No MCP access**: Claude can't natively read `codex://` resources
4. **Init doesn't set up MCP**: Users must manually configure

### Desired State

One unified approach:
```
/fractary-codex:init               # Sets up everything including MCP
/fractary-codex:sync-project       # Prefetches to codex/ cache
codex://project/docs/file.md       # Claude reads via MCP
```

---

## Solution Overview

### Unified Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  INIT (One-Time Setup)                                              │
│  /fractary-codex:init                                               │
│    ├── Creates .fractary/plugins/codex/config.json                  │
│    ├── Creates codex/ directory with .gitignore                     │
│    ├── Installs MCP server → .claude/settings.json                  │
│    └── Shows next steps                                             │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  SYNC (Prefetch)                                                    │
│  /fractary-codex:sync-project --from-codex                          │
│    ├── Fetches from central codex repository                        │
│    ├── Writes to codex/{project}/ (ephemeral cache)                 │
│    ├── Updates .cache-index.json with metadata                      │
│    └── Files are gitignored (not committed)                         │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│  ACCESS (Claude via MCP)                                            │
│  codex://auth-service/docs/oauth.md                                 │
│    ├── MCP server reads from codex/ cache                           │
│    ├── Returns content to Claude                                    │
│    └── Cache metadata included (freshness, source)                  │
└─────────────────────────────────────────────────────────────────────┘
```

### Command Changes

| Command | Before (v2.0) | After (Unified) |
|---------|---------------|-----------------|
| `sync-project --to-codex` | Project → Codex repo | **Unchanged** |
| `sync-project --from-codex` | Codex → Project root (permanent) | Codex → `codex/` cache (ephemeral) |
| `sync-org --to-codex` | All projects → Codex | **Unchanged** |
| `sync-org --from-codex` | Codex → All projects | Codex → `codex/` cache |
| `init` | Creates config | Creates config + **installs MCP** |

### Reference Alignment

Perfect 1:1 mapping between reference and cache path:

```
# GitHub sources (with org prefix)
Reference in docs:    @codex/corthion/auth-service/docs/oauth.md
                           ↓ (strip @)
Cache file path:      codex/corthion/auth-service/docs/oauth.md
                           ↓ (MCP URI)
MCP resource:         codex://corthion/auth-service/docs/oauth.md

# External sources (flat identifier)
Reference in docs:    @codex/context7/react/hooks.md
                           ↓ (strip @)
Cache file path:      codex/context7/react/hooks.md
                           ↓ (MCP URI)
MCP resource:         codex://context7/react/hooks.md
```

---

## Technical Implementation

### 1. MCP Server Location

**Path**: `plugins/codex/mcp-server/`

```
plugins/codex/mcp-server/
├── package.json          # Dependencies (@modelcontextprotocol/sdk)
├── tsconfig.json         # TypeScript config
├── src/
│   └── index.ts          # Server implementation (already exists)
├── dist/                 # Compiled output
│   └── index.js
└── README.md             # Usage documentation
```

**Note**: The MCP server already exists at this location. This spec formalizes its integration.

### 2. Init Command Enhancement

**File**: `plugins/codex/commands/init.md`

Add Step 4: Install MCP Server

```markdown
## Step 4: Install MCP Server

After creating configuration, install the MCP server reference:

1. Ensure `.claude/` directory exists
2. Create/update `.claude/settings.json`
3. Add `mcpServers.fractary-codex` configuration
4. Verify MCP server script exists

### MCP Configuration Added

```json
{
  "mcpServers": {
    "fractary-codex": {
      "command": "node",
      "args": ["<plugin-path>/mcp-server/dist/index.js"],
      "env": {
        "CODEX_ROOT": "./codex",
        "CODEX_CONFIG_PATH": "./.fractary/plugins/codex/config.json"
      }
    }
  }
}
```

### Path Resolution

The `<plugin-path>` is resolved from:
1. `FRACTARY_PLUGINS_PATH` environment variable (if set)
2. `~/.config/fractary/plugins/codex` (global install)
3. `./node_modules/@fractary/claude-plugins/plugins/codex` (npm install)

### Install Script

Create `plugins/codex/scripts/install-mcp.sh`:

```bash
#!/usr/bin/env bash
# Install MCP server reference into .claude/settings.json

set -euo pipefail

PROJECT_PATH="${1:-.}"
SETTINGS_FILE="$PROJECT_PATH/.claude/settings.json"
BACKUP_FILE="$PROJECT_PATH/.claude/settings.json.backup"

# Find plugin path
if [ -n "${FRACTARY_PLUGINS_PATH:-}" ]; then
    PLUGIN_PATH="$FRACTARY_PLUGINS_PATH/codex"
elif [ -d "$HOME/.config/fractary/plugins/codex" ]; then
    PLUGIN_PATH="$HOME/.config/fractary/plugins/codex"
elif [ -d "$PROJECT_PATH/node_modules/@fractary/claude-plugins/plugins/codex" ]; then
    PLUGIN_PATH="$PROJECT_PATH/node_modules/@fractary/claude-plugins/plugins/codex"
else
    echo "ERROR: Cannot find codex plugin. Set FRACTARY_PLUGINS_PATH or install via npm."
    exit 1
fi

MCP_SERVER_PATH="$PLUGIN_PATH/mcp-server/dist/index.js"

# Verify MCP server exists
if [ ! -f "$MCP_SERVER_PATH" ]; then
    echo "ERROR: MCP server not found at $MCP_SERVER_PATH"
    echo "Run 'npm run build' in the mcp-server directory first."
    exit 1
fi

# Create .claude directory
mkdir -p "$PROJECT_PATH/.claude"

# Create settings.json if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# Backup existing settings
cp "$SETTINGS_FILE" "$BACKUP_FILE"

# Add MCP server configuration
jq --arg path "$MCP_SERVER_PATH" '
  .mcpServers = (.mcpServers // {}) |
  .mcpServers["fractary-codex"] = {
    "command": "node",
    "args": [$path],
    "env": {
      "CODEX_ROOT": "./codex",
      "CODEX_CONFIG_PATH": "./.fractary/plugins/codex/config.json"
    }
  }
' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"

mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

echo "✅ MCP server configured in $SETTINGS_FILE"
echo "   Server: $MCP_SERVER_PATH"
echo "   Cache: ./codex"
```

### Init Output (Updated)

```
✅ Codex plugin initialized!

Configuration:
  Organization: fractary
  Codex Repository: codex.fractary.com
  Project Config: .fractary/plugins/codex/config.json

Cache Directory:
  ✅ Created: ./codex/
  ✅ Added to .gitignore

MCP Server:
  ✅ Installed in .claude/settings.json
  ✅ Server: ~/.config/fractary/plugins/codex/mcp-server/dist/index.js
  ✅ Resources available at: codex://

Claude can now:
  • Read codex://project/path resources directly
  • Use codex_cache_status tool to check cache

Next steps:
  1. Prefetch docs: /fractary-codex:sync-project --from-codex
  2. Claude reads: codex://auth-service/docs/oauth.md
  3. Publish changes: /fractary-codex:sync-project --to-codex
```

### 3. Sync Command Changes

**File**: `plugins/codex/skills/project-syncer/workflow/sync-from-codex.md`

Update destination from project root to `codex/` cache:

#### Before (v2.0)

```
Source: codex.fractary.com/projects/{project}/docs/file.md
Target: {project-root}/docs/file.md  (permanent, committed)
```

#### After (Unified)

```
Source: codex.fractary.com/projects/{project}/docs/file.md
Target: {project-root}/codex/{project}/docs/file.md  (ephemeral, gitignored)
```

#### Handler Changes

**File**: `plugins/codex/skills/handler-sync-github/workflow/sync-files.md`

When direction is `from-codex` or `from-target`:

1. **Target path calculation**:
   ```
   OLD: target_path = project_root / relative_path
   NEW: target_path = project_root / "codex" / project_name / relative_path
   ```

2. **Cache index update**:
   After copying files, update `.cache-index.json` with metadata:
   ```json
   {
     "reference": "@codex/{project}/{path}",
     "path": "{project}/{path}",
     "source": "fractary-codex",
     "cached_at": "<timestamp>",
     "expires_at": "<timestamp + TTL>",
     "ttl_days": 7,
     "size_bytes": <file-size>,
     "synced_via": "sync-project --from-codex"
   }
   ```

3. **No git commit for target**:
   Since files go to gitignored `codex/`, don't create commits in target project.

#### Sync Script Updates

**File**: `plugins/codex/skills/handler-sync-github/scripts/sync-docs.sh`

Add new parameters:

```bash
# New parameter for cache mode
CACHE_MODE="${CACHE_MODE:-false}"  # true for --from-codex operations

if [ "$CACHE_MODE" = "true" ]; then
    # Write to codex/ directory
    TARGET_BASE="$TARGET_REPO_PATH/codex/$SOURCE_PROJECT_NAME"

    # Update cache index after sync
    update_cache_index "$TARGET_REPO_PATH/codex/.cache-index.json" \
        --source "fractary-codex" \
        --project "$SOURCE_PROJECT_NAME" \
        --files "$SYNCED_FILES"

    # Don't commit (files are gitignored)
    SKIP_COMMIT=true
else
    # Original behavior for --to-codex
    TARGET_BASE="$TARGET_REPO_PATH/projects/$SOURCE_PROJECT_NAME"
fi
```

### 4. Cache Index Management

**File**: `plugins/codex/scripts/update-cache-index.sh`

```bash
#!/usr/bin/env bash
# Update cache index after sync operations

set -euo pipefail

CACHE_INDEX="$1"
SOURCE="$2"
PROJECT="$3"
shift 3
FILES=("$@")

# Default TTL from config or 7 days
TTL_DAYS="${CODEX_TTL_DAYS:-7}"

# Initialize cache index if needed
if [ ! -f "$CACHE_INDEX" ]; then
    cat > "$CACHE_INDEX" << 'EOF'
{
  "version": "1.0",
  "entries": [],
  "stats": {
    "total_entries": 0,
    "total_size_bytes": 0,
    "last_cleanup": null
  }
}
EOF
fi

CACHED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EXPIRES_AT=$(date -u -d "+${TTL_DAYS} days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
             date -u -v+${TTL_DAYS}d +"%Y-%m-%dT%H:%M:%SZ")

# Add entries for each file
for file in "${FILES[@]}"; do
    SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
    REL_PATH="${file#*/codex/}"

    # Update or add entry
    jq --arg ref "@codex/$REL_PATH" \
       --arg path "$REL_PATH" \
       --arg source "$SOURCE" \
       --arg cached "$CACHED_AT" \
       --arg expires "$EXPIRES_AT" \
       --argjson ttl "$TTL_DAYS" \
       --argjson size "$SIZE" \
       '
       .entries = [.entries[] | select(.path != $path)] + [{
         "reference": $ref,
         "path": $path,
         "source": $source,
         "cached_at": $cached,
         "expires_at": $expires,
         "ttl_days": $ttl,
         "size_bytes": $size,
         "synced_via": "sync-project"
       }] |
       .stats.total_entries = (.entries | length) |
       .stats.total_size_bytes = ([.entries[].size_bytes] | add // 0)
       ' "$CACHE_INDEX" > "${CACHE_INDEX}.tmp"

    mv "${CACHE_INDEX}.tmp" "$CACHE_INDEX"
done

echo "Updated cache index: ${#FILES[@]} entries"
```

### 5. Gitignore Setup

**File**: `plugins/codex/skills/project-syncer/workflow/setup-cache.md`

Add to init workflow:

```markdown
## Step: Create Cache Directory

1. Create `codex/` directory if not exists:
   ```bash
   mkdir -p codex
   ```

2. Create `codex/.gitignore` to ignore all contents:
   ```bash
   echo '*' > codex/.gitignore
   echo '!.gitignore' >> codex/.gitignore
   echo '!.cache-index.json' >> codex/.gitignore
   ```

3. Add `codex/` to project root `.gitignore`:
   ```bash
   if ! grep -q '^codex/$' .gitignore 2>/dev/null; then
       echo '' >> .gitignore
       echo '# Codex cache (ephemeral knowledge base)' >> .gitignore
       echo 'codex/' >> .gitignore
   fi
   ```
```

### 6. MCP Server Enhancements

**File**: `plugins/codex/mcp-server/src/index.ts`

The existing MCP server already supports this architecture. Minor enhancements:

```typescript
// Add tool for checking sync status
{
  name: "codex_sync_status",
  description: "Check if cache was populated via sync and when",
  inputSchema: {
    type: "object",
    properties: {
      project: {
        type: "string",
        description: "Project name to check (optional, checks all if omitted)"
      }
    }
  }
}

// Handler for sync status
if (name === "codex_sync_status") {
  const index = await readCacheIndex();
  if (!index) {
    return { content: [{ type: "text", text: "No cache index found. Run /fractary-codex:sync-project --from-codex" }] };
  }

  const syncedEntries = index.entries.filter(e => e.synced_via?.startsWith("sync"));
  const projects = [...new Set(syncedEntries.map(e => e.path.split('/')[0]))];

  return {
    content: [{
      type: "text",
      text: `Synced Projects: ${projects.join(', ') || 'none'}
Total synced entries: ${syncedEntries.length}
Last sync: ${syncedEntries[0]?.cached_at || 'never'}`
    }]
  };
}
```

---

## Universal Reference Resolution

### The Problem: Portable References

When documents are synced between projects, relative paths break:

```markdown
<!-- In etl.corthion.ai/docs/pipelines.md -->
See also: [Architecture](./architecture.md)           ← OK (same folder)
See also: [Shared API](../../shared/api-design.md)   ← BREAKS when synced!
```

When this doc syncs to the central codex and then to `dashboard.corthion.ai`, the relative path `../../shared/api-design.md` no longer resolves correctly.

### Solution: Universal `codex://` References

Use `codex://` syntax for **all cross-document references**, including references to the current project's own docs:

```markdown
<!-- In corthion/etl.corthion.ai/docs/pipelines.md -->
See also: [Architecture](codex://corthion/etl.corthion.ai/docs/architecture.md)
See also: [Auth Docs](codex://corthion/auth-service/docs/oauth.md)
See also: [React Hooks](codex://context7/react/hooks.md)
```

**Same reference works everywhere** - whether the doc is in its original project, the central codex, or synced to another project.

### Resolution Logic

The MCP server resolves `codex://` URIs with **current-project awareness**:

```
When resolving codex://org/project/path (GitHub):
  If org/project == current_project:
    → Resolve to ./{path} (project root, local file)
  Else:
    → Resolve to ./codex/{org}/{project}/{path} (cache)

When resolving codex://identifier/path (External):
  → Resolve to ./codex/{identifier}/{path} (always cache)
```

#### Example: In `corthion/etl.corthion.ai`

| Reference | Match? | Resolved Path |
|-----------|--------|---------------|
| `codex://corthion/etl.corthion.ai/docs/arch.md` | ✅ Current | `./docs/arch.md` |
| `codex://corthion/auth-service/docs/oauth.md` | ❌ Other | `./codex/corthion/auth-service/docs/oauth.md` |
| `codex://acme/auth-service/docs/api.md` | ❌ Other org | `./codex/acme/auth-service/docs/api.md` |
| `codex://context7/react/hooks.md` | ❌ External | `./codex/context7/react/hooks.md` |

#### Example: Same Doc Synced to `corthion/dashboard`

| Reference | Match? | Resolved Path |
|-----------|--------|---------------|
| `codex://corthion/etl.corthion.ai/docs/arch.md` | ❌ Other | `./codex/corthion/etl.corthion.ai/docs/arch.md` |
| `codex://corthion/dashboard/docs/ui.md` | ✅ Current | `./docs/ui.md` |
| `codex://context7/react/hooks.md` | ❌ External | `./codex/context7/react/hooks.md` |

### Current Project Detection

The MCP server determines the current project (org + project) from multiple sources (in priority order):

1. **Environment variables**: `CODEX_CURRENT_ORG` and `CODEX_CURRENT_PROJECT`
2. **Config file**: `.fractary/plugins/codex/config.json` → `organization` + `project_name`
3. **Git remote**: Extract org and repo from `origin` URL
4. **Directory name**: Fallback to parent directory (org) + current directory (project)

#### Config Addition

**File**: `.fractary/plugins/codex/config.json`

```json
{
  "organization": "corthosai",
  "project_name": "etl.corthion.ai",
  "codex_repo": "codex.corthosai.com",
  "sync_patterns": ["docs/**", "CLAUDE.md"],

  "cache": {
    "default_ttl_days": 7,
    "check_expiration": true,
    "fallback_to_stale": true
  },

  "on_demand_fetch": {
    "enabled": true,
    "timeout_ms": 5000,
    "retry_count": 2
  },

  "sources": {
    "corthosai": {
      "type": "github-org",
      "ttl_days": 7
    },
    "fractary": {
      "type": "github-org",
      "ttl_days": 14
    },
    "context7": {
      "type": "mcp",
      "ttl_days": 1
    },
    "docs.aws.amazon.com": {
      "type": "http",
      "ttl_days": 30
    }
  }
}
```

#### MCP Server Environment

**File**: `.claude/settings.json`

```json
{
  "mcpServers": {
    "fractary-codex": {
      "command": "node",
      "args": ["<plugin-path>/mcp-server/dist/index.js"],
      "env": {
        "CODEX_ROOT": "./codex",
        "CODEX_CONFIG_PATH": "./.fractary/plugins/codex/config.json",
        "CODEX_CURRENT_ORG": "corthion",
        "CODEX_CURRENT_PROJECT": "etl.corthion.ai"
      }
    }
  }
}
```

### MCP Server Implementation

**File**: `plugins/codex/mcp-server/src/index.ts`

```typescript
import * as fs from "fs/promises";
import * as path from "path";
import { execSync } from "child_process";

interface CurrentProject {
  org: string;
  project: string;
}

// Detect current project (org + project)
async function detectCurrentProject(): Promise<CurrentProject> {
  // 1. Environment variables (highest priority)
  if (process.env.CODEX_CURRENT_ORG && process.env.CODEX_CURRENT_PROJECT) {
    return {
      org: process.env.CODEX_CURRENT_ORG,
      project: process.env.CODEX_CURRENT_PROJECT
    };
  }

  // 2. Config file
  try {
    const configPath = process.env.CODEX_CONFIG_PATH || "./.fractary/plugins/codex/config.json";
    const config = JSON.parse(await fs.readFile(configPath, "utf-8"));
    if (config.organization && config.project_name) {
      return {
        org: config.organization,
        project: config.project_name
      };
    }
  } catch (e) {
    // Config not found, continue to fallbacks
  }

  // 3. Git remote
  try {
    const remote = execSync("git remote get-url origin", { encoding: "utf-8" }).trim();
    // Extract org and project from URL
    // https://github.com/org/project.git → org, project
    // git@github.com:org/project.git → org, project
    const match = remote.match(/[/:]([^/]+)\/([^/]+?)(?:\.git)?$/);
    if (match) {
      return { org: match[1], project: match[2] };
    }
  } catch (e) {
    // Not a git repo or no remote
  }

  // 4. Directory names (lowest priority)
  const cwd = process.cwd();
  return {
    org: path.basename(path.dirname(cwd)),
    project: path.basename(cwd)
  };
}

// Global current project (initialized on startup)
let CURRENT_PROJECT: CurrentProject;

// Resolve codex:// URI to filesystem path
function resolveUri(uri: string): string {
  // Try GitHub format: codex://org/project/path
  const ghMatch = uri.match(/^codex:\/\/([^/]+)\/([^/]+)\/(.+)$/);
  if (ghMatch) {
    const [, org, project, relativePath] = ghMatch;

    // Check if this is the current project
    if (org === CURRENT_PROJECT.org && project === CURRENT_PROJECT.project) {
      return path.join(process.cwd(), relativePath);
    }

    // Other GitHub project → cache
    return path.join(CODEX_CACHE_PATH, org, project, relativePath);
  }

  // External format: codex://identifier/path
  const extMatch = uri.match(/^codex:\/\/([^/]+)\/(.+)$/);
  if (extMatch) {
    const [, identifier, relativePath] = extMatch;
    return path.join(CODEX_CACHE_PATH, identifier, relativePath);
  }

  throw new Error(`Invalid codex URI: ${uri}`);
}

// Initialize on startup
async function main() {
  CURRENT_PROJECT = await detectCurrentProject();
  console.error(`Codex MCP Server: current = ${CURRENT_PROJECT.org}/${CURRENT_PROJECT.project}`);

  // ... rest of server setup
}
```

### Reference Guidelines

#### When to Use `codex://`

| Scenario | Use `codex://`? | Example |
|----------|-----------------|---------|
| Same folder | Optional | `./sibling.md` or `codex://org/proj/docs/sibling.md` |
| Different folder, same project | **Recommended** | `codex://corthion/etl/specs/arch.md` |
| Same org, different project | **Required** | `codex://corthion/auth-service/docs/api.md` |
| Different org | **Required** | `codex://acme/partner-lib/docs/api.md` |
| External source | **Required** | `codex://context7/react/hooks.md` |
| Doc may be synced elsewhere | **Required** | Always use `codex://` |

#### Best Practice

**Always use `codex://` for cross-folder references** to ensure portability:

```markdown
<!-- ✅ GOOD: Portable reference with org/project -->
See [Architecture](codex://corthion/etl.corthion.ai/docs/architecture.md)
See [Auth Docs](codex://corthion/auth-service/docs/oauth.md)
See [React Hooks](codex://context7/react/hooks.md)

<!-- ❌ BAD: Breaks when synced -->
See [Architecture](../docs/architecture.md)
```

**Relative paths are fine within the same folder**:

```markdown
<!-- ✅ OK: Same folder, won't be separated -->
See [Details](./implementation-details.md)
```

### Reference Validation & Linting

#### Validation Command

**Command**: `/fractary-codex:validate-refs`

Scans documents for non-portable references:

```bash
$ /fractary-codex:validate-refs

Scanning docs/ for references...

⚠️  Non-portable references found:

docs/pipelines.md:15
  [Shared API](../../shared/api-design.md)
  └─ Suggestion: codex://shared-standards/api-design.md

docs/architecture.md:42
  [Auth Docs](/auth-service/docs/oauth.md)
  └─ Suggestion: codex://auth-service/docs/oauth.md

Found 2 non-portable references in 2 files.
Run with --fix to automatically convert to codex:// syntax.
```

#### Auto-Fix Option

```bash
$ /fractary-codex:validate-refs --fix

Converting non-portable references...

✅ docs/pipelines.md:15 → codex://shared-standards/api-design.md
✅ docs/architecture.md:42 → codex://auth-service/docs/oauth.md

Converted 2 references in 2 files.
```

#### Validation Script

**File**: `plugins/codex/scripts/validate-refs.sh`

```bash
#!/usr/bin/env bash
# Validate document references for portability

set -euo pipefail

PROJECT_PATH="${1:-.}"
FIX_MODE="${2:-false}"
CURRENT_PROJECT=$(jq -r '.project_name // empty' "$PROJECT_PATH/.fractary/plugins/codex/config.json" 2>/dev/null || basename "$PROJECT_PATH")

echo "Scanning for non-portable references..."
echo "Current project: $CURRENT_PROJECT"
echo ""

# Find markdown files
ISSUES=0
while IFS= read -r file; do
    # Look for relative paths that go up directories or absolute paths
    # Pattern: [text](../something) or [text](/something)
    while IFS= read -r match; do
        if [ -n "$match" ]; then
            LINE_NUM=$(echo "$match" | cut -d: -f1)
            CONTENT=$(echo "$match" | cut -d: -f2-)

            # Extract the path from markdown link
            REF_PATH=$(echo "$CONTENT" | grep -oP '\]\(\K[^)]+' | head -1)

            # Skip codex:// references (already portable)
            if [[ "$REF_PATH" == codex://* ]]; then
                continue
            fi

            # Skip URLs
            if [[ "$REF_PATH" == http://* ]] || [[ "$REF_PATH" == https://* ]]; then
                continue
            fi

            # Skip anchors
            if [[ "$REF_PATH" == \#* ]]; then
                continue
            fi

            # Flag relative paths that go up or absolute paths
            if [[ "$REF_PATH" == ../* ]] || [[ "$REF_PATH" == /* ]]; then
                echo "⚠️  $file:$LINE_NUM"
                echo "   $CONTENT"

                # Suggest codex:// equivalent
                SUGGESTED="codex://$CURRENT_PROJECT/${REF_PATH#/}"
                SUGGESTED="${SUGGESTED#codex://$CURRENT_PROJECT/../}"
                echo "   └─ Suggestion: $SUGGESTED"
                echo ""

                ISSUES=$((ISSUES + 1))
            fi
        fi
    done < <(grep -n '\]([^)]*\.md)' "$file" 2>/dev/null || true)
done < <(find "$PROJECT_PATH" -name "*.md" -not -path "*/codex/*" -not -path "*/.git/*" -not -path "*/node_modules/*")

echo ""
if [ $ISSUES -eq 0 ]; then
    echo "✅ All references are portable!"
else
    echo "Found $ISSUES non-portable reference(s)."
    if [ "$FIX_MODE" = "--fix" ]; then
        echo "Auto-fix not yet implemented. Please update manually."
    else
        echo "Run with --fix to automatically convert to codex:// syntax."
    fi
    exit 1
fi
```

### Init Command Update

The `/fractary-codex:init` command should:

1. **Detect org and project** from git remote (e.g., `github.com/corthosai/etl.corthion.ai`)
2. **Store in config** as `organization` and `project_name`
3. **Pass to MCP server** via environment variables

#### Updated Init Output

```
✅ Codex plugin initialized!

Configuration:
  Organization: corthosai
  Project Name: etl.corthion.ai
  Codex Repository: codex.corthosai.com

Cache Directory:
  ✅ Created: ./codex/
  ✅ Added to .gitignore

MCP Server:
  ✅ Installed in .claude/settings.json
  ✅ Current: corthosai/etl.corthion.ai
  ✅ Resources available at: codex://

Reference Resolution:
  codex://corthosai/etl.corthion.ai/* → ./  (local project)
  codex://corthosai/auth-service/*    → ./codex/corthosai/auth-service/  (cache)
  codex://fractary/claude-plugins/*   → ./codex/fractary/claude-plugins/  (external org)
  codex://context7/*                  → ./codex/context7/  (MCP)

Next steps:
  1. Use codex:// references in your docs for portability
  2. Validate: /fractary-codex:validate-refs
  3. Prefetch: /fractary-codex:sync-project corthosai/etl.corthion.ai --from-codex
```

---

## Fractary-Docs Plugin Integration

### Problem: Syncable Docs Must Use Portable References

Documents marked for sync (via `codex_sync_include: true` frontmatter) will be copied to other projects. Any relative or direct file references in these docs will break when synced:

```markdown
---
codex_sync_include: true   # This doc will be synced to other projects
---

# Integration Guide

<!-- ❌ BAD: These break when synced -->
See [Schema Docs](../schema/overview.md)
See [API Reference](/docs/api/endpoints.md)

<!-- ✅ GOOD: These work everywhere -->
See [Schema Docs](codex://corthosai/etl.corthion.ai/docs/schema/overview.md)
See [API Reference](codex://corthosai/etl.corthion.ai/docs/api/endpoints.md)
```

### Solution: Enforce codex:// in Syncable Docs

The **fractary-docs plugin** must enforce portable `codex://` references in any document with `codex_sync_include: true`.

#### Writing Phase Enforcement

When the fractary-docs writer skill creates or updates a document with `codex_sync_include: true`:

1. **Convert relative references** to `codex://` format automatically
2. **Warn on non-portable references** before saving
3. **Suggest correct format** for any problematic references

```markdown
# During doc writing with codex_sync_include: true

⚠️ Non-portable reference detected:
   [Schema Docs](../schema/overview.md)

   This doc is marked for sync (codex_sync_include: true).
   Converting to portable reference:
   [Schema Docs](codex://corthosai/etl.corthion.ai/docs/schema/overview.md)
```

#### Validation Skill Enhancement

The fractary-docs validation skill must check all docs with `codex_sync_include: true`:

**Command**: `/fractary-docs:validate` (enhanced)

```bash
$ /fractary-docs:validate

Validating documentation...

⚠️ Syncable docs with non-portable references:

docs/guides/integration.md (codex_sync_include: true)
  Line 15: [Schema Docs](../schema/overview.md)
           └─ Fix: codex://corthosai/etl.corthion.ai/docs/schema/overview.md
  Line 23: [API Endpoints](/docs/api/endpoints.md)
           └─ Fix: codex://corthosai/etl.corthion.ai/docs/api/endpoints.md

docs/guides/deployment.md (codex_sync_include: true)
  Line 42: [Config Reference](../../config/README.md)
           └─ Fix: codex://corthosai/etl.corthion.ai/config/README.md

Found 3 non-portable references in 2 syncable docs.
Run with --fix to automatically convert.
```

#### Auto-Fix Option

```bash
$ /fractary-docs:validate --fix

Converting non-portable references in syncable docs...

✅ docs/guides/integration.md: 2 references converted
✅ docs/guides/deployment.md: 1 reference converted

All syncable docs now use portable codex:// references.
```

### Cross-Org Reference Example

A project in `corthosai` can reference plugin integration guides from `fractary`:

```markdown
---
title: Faber Plugin Integration
codex_sync_include: true
---

# Setting Up Faber

Follow the official integration guide:
[Faber Integration](codex://fractary/claude-plugins/plugins/faber/docs/guides/PROJECT-INTEGRATION-GUIDE.md)

For codex plugin setup:
[Codex Getting Started](codex://fractary/claude-plugins/plugins/codex/docs/GETTING-STARTED.md)
```

When this doc syncs to another project, these cross-org references still resolve correctly via the MCP server.

### Implementation in fractary-docs

#### Writer Skill Update

**File**: `plugins/docs/skills/doc-writer/workflow/write-doc.md`

Add reference conversion step:

```markdown
## Step: Convert References for Syncable Docs

If the document has `codex_sync_include: true` in frontmatter:

1. Scan for markdown links: `[text](path)`
2. For each link that is NOT:
   - A `codex://` URI
   - An external URL (http://, https://)
   - An anchor link (#section)
   - A same-folder relative (./file.md)
3. Convert to `codex://` format:
   - Determine current org/project from config
   - Resolve relative path to absolute path within project
   - Format as: `codex://{org}/{project}/{resolved-path}`
4. Log conversions for user visibility
```

#### Validation Skill Update

**File**: `plugins/docs/skills/doc-validator/workflow/validate.md`

Add syncable reference check:

```markdown
## Step: Validate Syncable Doc References

For each document with `codex_sync_include: true`:

1. Extract all markdown links
2. Flag any link that:
   - Uses relative parent paths (../)
   - Uses absolute paths (/)
   - Is not a codex:// URI, external URL, or anchor
3. Generate suggested fix using current org/project
4. If --fix flag: apply conversions automatically
5. Report results with line numbers
```

---

## Multi-Source Architecture

### Overview

The codex cache supports multiple sources beyond the organization's GitHub codex:

- **GitHub projects** - Organization repositories
- **MCP servers** - Like Context7 for technical documentation
- **HTTP/Web sources** - External documentation sites
- **Other organization codexes** - Partner or public codexes

### Cache Structure with Organization Prefix

GitHub sources use **organization/project** structure where the organization matches the GitHub org. External sources remain flat with self-describing identifiers:

```
codex/
├── corthosai/                   # GitHub org (matches github.com/corthosai)
│   ├── etl.corthion.ai/         # Org project (repo name)
│   │   └── docs/
│   │       └── schema/
│   ├── auth-service/            # Org project
│   │   └── docs/
│   └── shared-standards/        # Org project
├── fractary/                    # Another GitHub org (for plugins)
│   └── claude-plugins/          # Plugin repository
│       └── plugins/
│           ├── faber/docs/
│           └── codex/docs/
├── acme/                        # Partner GitHub org
│   └── partner-lib/             # Same project name OK - different org!
│       └── docs/
├── context7/                    # MCP server (no org, flat)
│   └── react/
│       └── hooks.md
├── docs.aws.amazon.com/         # Web domain (no org, flat)
│   └── s3/
│       └── api.md
└── .cache-index.json
```

**Structure Rules**:
- **GitHub sources**: `{github-org}/{repo}/` - matches GitHub URL structure
- **External sources**: `{identifier}/` - one level (domain or MCP server name)
- Organization = GitHub org (e.g., `corthosai`, `fractary`, `acme`)
- Project = GitHub repo name (e.g., `etl.corthion.ai`, `claude-plugins`)

### URI Scheme

URIs include organization (GitHub org) for GitHub sources, flat for external:

```
# GitHub sources (github-org/repo/path)
codex://corthosai/etl.corthion.ai/docs/arch.md
codex://corthosai/auth-service/docs/oauth.md
codex://fractary/claude-plugins/plugins/faber/docs/guides/PROJECT-INTEGRATION-GUIDE.md

# Cross-org references (partner/external org)
codex://acme/partner-lib/docs/api.md

# External sources (identifier/path) - no org prefix
codex://context7/react/hooks.md                # MCP server
codex://docs.aws.amazon.com/s3/api.md          # Web domain
```

### Path Pattern Filtering

Sync and fetch commands support **path patterns** to sync a subset of files. Multiple patterns can be comma-separated (no spaces):

#### Single Pattern

```bash
# Sync only schema docs from one project
/fractary-codex:sync-project corthosai/etl.corthion.ai/docs/schema/* --from-codex

# Fetch a specific file
/fractary-codex:fetch corthosai/auth-service/docs/oauth.md

# Fetch plugin integration guide from another org
/fractary-codex:fetch fractary/claude-plugins/plugins/faber/docs/guides/PROJECT-INTEGRATION-GUIDE.md
```

#### Multiple Patterns (Comma-Separated)

```bash
# Sync schema docs from multiple projects
/fractary-codex:sync-project corthosai/etl.corthion.ai/docs/schema/*,corthosai/auth-service/docs/api/* --from-codex

# Sync all CLAUDE.md files from org
/fractary-codex:sync-org corthosai/*/CLAUDE.md --from-codex

# Fetch plugin docs from external org
/fractary-codex:fetch fractary/claude-plugins/plugins/*/docs/**
```

#### Pattern Syntax

| Pattern | Matches |
|---------|---------|
| `corthosai/etl.corthion.ai/docs/*` | All files in docs/ (one level) |
| `corthosai/etl.corthion.ai/docs/**` | All files in docs/ (recursive) |
| `corthosai/etl.corthion.ai/docs/*.md` | Only .md files in docs/ |
| `corthosai/*/CLAUDE.md` | CLAUDE.md from all corthosai projects |
| `fractary/claude-plugins/plugins/*/docs/**` | All plugin docs from fractary org |

#### Pattern Parsing

```typescript
interface ParsedPattern {
  org: string;           // "corthion"
  project: string;       // "etl.corthion.ai" or "*" for all
  pathPattern: string;   // "docs/schema/*"
}

function parsePattern(pattern: string): ParsedPattern {
  const parts = pattern.split('/');

  // GitHub pattern: org/project/path...
  if (parts.length >= 3) {
    return {
      org: parts[0],
      project: parts[1],
      pathPattern: parts.slice(2).join('/')
    };
  }

  // External source: identifier/path...
  return {
    org: '',  // No org for external sources
    project: parts[0],
    pathPattern: parts.slice(1).join('/')
  };
}

function parsePatterns(input: string): ParsedPattern[] {
  return input.split(',').map(p => parsePattern(p.trim()));
}
```

### Source Registry

The cache index tracks sources with organization info for GitHub sources:

**File**: `codex/.cache-index.json`

```json
{
  "version": "1.2",
  "sources": {
    "corthion": {
      "type": "github-org",
      "handler": "handler-sync-github",
      "codex_repo": "codex.corthion.ai",
      "projects": ["etl.corthion.ai", "auth-service", "shared-standards"]
    },
    "acme": {
      "type": "github-org",
      "handler": "handler-sync-github",
      "codex_repo": "codex.acme.com",
      "projects": ["auth-service", "partner-lib"]
    },
    "context7": {
      "type": "mcp",
      "handler": "handler-mcp",
      "server": "context7",
      "description": "Technical documentation for 33K+ libraries"
    },
    "docs.aws.amazon.com": {
      "type": "http",
      "handler": "handler-http",
      "base_url": "https://docs.aws.amazon.com",
      "ttl_days": 30
    },
    "react.dev": {
      "type": "http",
      "handler": "handler-http",
      "base_url": "https://react.dev",
      "ttl_days": 14
    }
  },
  "current_project": {
    "org": "corthion",
    "project": "etl.corthion.ai"
  },
  "entries": [
    {
      "uri": "codex://corthion/etl.corthion.ai/docs/arch.md",
      "org": "corthion",
      "project": "etl.corthion.ai",
      "path": "corthion/etl.corthion.ai/docs/arch.md",
      "cached_at": "2025-01-15T10:00:00Z",
      "expires_at": "2025-01-22T10:00:00Z"
    },
    {
      "uri": "codex://context7/react/hooks.md",
      "org": null,
      "project": "context7",
      "path": "context7/react/hooks.md",
      "cached_at": "2025-01-15T10:00:00Z",
      "expires_at": "2025-01-16T10:00:00Z"
    }
  ],
  "stats": {
    "total_entries": 2,
    "total_size_bytes": 45000,
    "by_org": {
      "corthion": { "entries": 1, "size_bytes": 25000 },
      "_external": { "entries": 1, "size_bytes": 20000 }
    }
  }
}
```

### Handler Types

Each source type has a corresponding handler:

| Type | Handler | Description |
|------|---------|-------------|
| `github` | `handler-sync-github` | GitHub repository sync (existing) |
| `mcp` | `handler-mcp` | MCP server resources |
| `http` | `handler-http` | Direct HTTP fetch |
| `s3` | `handler-s3` | S3/R2 bucket storage (future) |
| `vector` | `handler-vector` | Vector store search (future) |

### Source Configuration

**File**: `.fractary/plugins/codex/config.json`

```json
{
  "organization": "corthion",
  "project_name": "etl.corthion.ai",
  "codex_repo": "codex.corthion.ai",

  "sources": {
    "default": {
      "type": "github",
      "handler": "handler-sync-github",
      "org": "corthion",
      "codex_repo": "codex.corthion.ai"
    },
    "context7": {
      "type": "mcp",
      "handler": "handler-mcp",
      "server": "context7",
      "enabled": true
    },
    "external": {
      "type": "http",
      "handler": "handler-http",
      "allowed_domains": [
        "docs.aws.amazon.com",
        "react.dev",
        "mdn.mozilla.org"
      ],
      "ttl_days": 14
    }
  },

  "sync_patterns": ["docs/**", "CLAUDE.md", "README.md"]
}
```

### MCP Server Resolution Update

**File**: `plugins/codex/mcp-server/src/index.ts`

```typescript
interface SourceConfig {
  type: 'github-org' | 'mcp' | 'http' | 's3' | 'vector';
  handler: string;
  [key: string]: any;
}

interface CurrentProject {
  org: string;
  project: string;
}

interface ParsedUri {
  org: string | null;     // null for external sources
  project: string;
  path: string;
}

// Load source registry and current project from cache index
async function loadCacheIndex(): Promise<{
  sources: Map<string, SourceConfig>;
  currentProject: CurrentProject | null;
}> {
  const index = await readCacheIndex();
  return {
    sources: new Map(Object.entries(index?.sources || {})),
    currentProject: index?.current_project || null
  };
}

// Parse codex:// URI into components
function parseUri(uri: string): ParsedUri {
  const match = uri.match(/^codex:\/\/([^/]+)\/([^/]+)\/(.+)$/);

  if (match) {
    // GitHub format: codex://org/project/path
    return { org: match[1], project: match[2], path: match[3] };
  }

  // External format: codex://identifier/path
  const extMatch = uri.match(/^codex:\/\/([^/]+)\/(.+)$/);
  if (extMatch) {
    return { org: null, project: extMatch[1], path: extMatch[2] };
  }

  throw new Error(`Invalid codex URI: ${uri}`);
}

// Resolve URI with org-aware multi-source support
async function resolveUri(uri: string): Promise<string> {
  const parsed = parseUri(uri);
  const { currentProject } = await loadCacheIndex();

  // Check if this is the current project
  const isCurrentProject = currentProject &&
    parsed.org === currentProject.org &&
    parsed.project === currentProject.project;

  if (isCurrentProject) {
    // Current project → local files (not cache)
    return join(process.cwd(), parsed.path);
  }

  // Build cache path based on source type
  if (parsed.org) {
    // GitHub: codex/org/project/path
    return join(CODEX_CACHE_PATH, parsed.org, parsed.project, parsed.path);
  } else {
    // External: codex/identifier/path
    return join(CODEX_CACHE_PATH, parsed.project, parsed.path);
  }
}

// Get handler for a source
async function getHandler(orgOrIdentifier: string): Promise<string> {
  const { sources } = await loadCacheIndex();
  const source = sources.get(orgOrIdentifier);

  if (source) {
    return source.handler;
  }

  // Infer handler from identifier pattern
  if (orgOrIdentifier.includes('.')) {
    return 'handler-http';  // Looks like a domain
  }

  return 'handler-sync-github';  // Default to GitHub org
}
```

### On-Demand Fetch (Cache Miss Handling)

When Claude requests a `codex://` resource that isn't cached, the MCP server **automatically fetches it** rather than failing:

```typescript
interface FetchResult {
  content: string;
  cached: boolean;
  fetchedAt?: string;
  expiresAt?: string;
}

// Read resource with on-demand fetching
async function readResource(uri: string): Promise<FetchResult> {
  const parsed = parseUri(uri);
  const filePath = await resolveUri(uri);

  // 1. Check if file exists in cache
  try {
    const content = await fs.readFile(filePath, 'utf-8');
    const cacheEntry = await getCacheEntry(uri);

    // Check if expired
    if (cacheEntry && new Date(cacheEntry.expires_at) < new Date()) {
      console.error(`Cache expired for ${uri}, fetching fresh copy...`);
      return await fetchAndCache(uri, parsed);
    }

    return {
      content,
      cached: true,
      fetchedAt: cacheEntry?.cached_at,
      expiresAt: cacheEntry?.expires_at
    };
  } catch (e) {
    // 2. Cache miss - fetch on demand
    console.error(`Cache miss for ${uri}, fetching...`);
    return await fetchAndCache(uri, parsed);
  }
}

// Fetch content and cache it
async function fetchAndCache(uri: string, parsed: ParsedUri): Promise<FetchResult> {
  const orgOrId = parsed.org || parsed.project;
  const handler = await getHandler(orgOrId);

  // Invoke appropriate handler to fetch content
  const content = await invokeHandler(handler, {
    org: parsed.org,
    project: parsed.project,
    path: parsed.path
  });

  // Write to cache
  const filePath = await resolveUri(uri);
  await fs.mkdir(dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, content, 'utf-8');

  // Update cache index
  const now = new Date();
  const ttlDays = await getTtlForSource(orgOrId);
  const expiresAt = new Date(now.getTime() + ttlDays * 24 * 60 * 60 * 1000);

  await updateCacheIndex({
    uri,
    org: parsed.org,
    project: parsed.project,
    path: filePath,
    cached_at: now.toISOString(),
    expires_at: expiresAt.toISOString(),
    fetched_on_demand: true
  });

  return {
    content,
    cached: false,
    fetchedAt: now.toISOString(),
    expiresAt: expiresAt.toISOString()
  };
}

// Handler invocation based on source type
async function invokeHandler(handler: string, params: {
  org: string | null;
  project: string;
  path: string;
}): Promise<string> {
  switch (handler) {
    case 'handler-sync-github':
      return await fetchFromGitHub(params);
    case 'handler-mcp':
      return await fetchFromMcp(params);
    case 'handler-http':
      return await fetchFromHttp(params);
    default:
      throw new Error(`Unknown handler: ${handler}`);
  }
}

// GitHub fetch implementation
async function fetchFromGitHub(params: {
  org: string | null;
  project: string;
  path: string;
}): Promise<string> {
  const { org, project, path } = params;
  // Fetch from GitHub raw content or API
  const url = `https://raw.githubusercontent.com/${org}/${project}/main/${path}`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}: ${response.status}`);
  }
  return await response.text();
}
```

#### Flow Diagram

```
Claude requests: codex://fractary/claude-plugins/plugins/faber/docs/guide.md
                              ↓
                    MCP Server receives request
                              ↓
                    Check local cache (codex/fractary/claude-plugins/...)
                              ↓
                 ┌────────────┴────────────┐
                 ↓                         ↓
           Cache HIT                  Cache MISS
           (file exists,              (not cached)
            not expired)                   ↓
                 ↓               Determine handler (github)
           Return content                  ↓
                                 Fetch from GitHub raw
                                          ↓
                                 Write to cache directory
                                          ↓
                                 Update .cache-index.json
                                          ↓
                                 Return content to Claude
```

#### Benefits

1. **Zero pre-configuration**: Claude can reference any doc, it gets fetched automatically
2. **Always up-to-date**: Expired cache entries are refreshed on access
3. **Graceful degradation**: If fetch fails, return cached (stale) content with warning
4. **Lazy loading**: Only fetch what's actually needed

#### Configuration Options

```json
{
  "on_demand_fetch": {
    "enabled": true,
    "timeout_ms": 5000,
    "retry_count": 2,
    "fallback_to_stale": true,
    "allowed_orgs": ["corthosai", "fractary", "acme"],
    "blocked_domains": ["internal.corp.com"]
  }
}
```

### Cache Expiration Handling

The MCP server checks cache freshness on every read and automatically refreshes expired content.

#### Expiration Check Flow

```
Claude requests: codex://corthosai/auth-service/docs/oauth.md
                              ↓
                    File exists in cache?
                              ↓
                 ┌────────────┴────────────┐
                 ↓                         ↓
               YES                         NO
                 ↓                          ↓
         Check expires_at              On-demand fetch
         in cache index                (see above)
                 ↓
     ┌───────────┴───────────┐
     ↓                       ↓
  NOT EXPIRED            EXPIRED
  (return cached)        (re-fetch)
                              ↓
                   Fetch fresh content
                              ↓
                   Update cache file
                              ↓
                   Update cache index
                   (new expires_at)
                              ↓
                   Return fresh content
```

#### TTL Configuration

TTL (Time To Live) determines how long cached content is considered fresh:

| Source Type | Default TTL | Rationale |
|-------------|-------------|-----------|
| Own org (`corthosai`) | 7 days | Frequently updated internal docs |
| External org (`fractary`) | 14 days | Plugin docs change less often |
| MCP server (`context7`) | 1 day | External API docs may update frequently |
| HTTP/Web (`docs.aws.amazon.com`) | 30 days | Official docs are stable |

#### Per-Source TTL in Config

```json
{
  "sources": {
    "corthosai": { "type": "github-org", "ttl_days": 7 },
    "fractary": { "type": "github-org", "ttl_days": 14 },
    "context7": { "type": "mcp", "ttl_days": 1 },
    "docs.aws.amazon.com": { "type": "http", "ttl_days": 30 }
  },
  "cache": {
    "default_ttl_days": 7,
    "check_expiration": true,
    "fallback_to_stale": true
  }
}
```

#### Cache Entry with Expiration

Each entry in `.cache-index.json` tracks expiration:

```json
{
  "uri": "codex://corthosai/auth-service/docs/oauth.md",
  "org": "corthosai",
  "project": "auth-service",
  "path": "corthosai/auth-service/docs/oauth.md",
  "cached_at": "2025-01-15T10:00:00Z",
  "expires_at": "2025-01-22T10:00:00Z",
  "ttl_days": 7,
  "size_bytes": 4523,
  "fetched_on_demand": false
}
```

#### Expiration Check Implementation

```typescript
async function readResource(uri: string): Promise<FetchResult> {
  const parsed = parseUri(uri);
  const filePath = await resolveUri(uri);
  const config = await loadConfig();

  try {
    const content = await fs.readFile(filePath, 'utf-8');
    const cacheEntry = await getCacheEntry(uri);

    // Skip expiration check if disabled
    if (!config.cache?.check_expiration) {
      return { content, cached: true };
    }

    // Check if expired
    if (cacheEntry && new Date(cacheEntry.expires_at) < new Date()) {
      console.error(`Cache expired for ${uri}, fetching fresh copy...`);

      try {
        return await fetchAndCache(uri, parsed);
      } catch (fetchError) {
        // Fallback to stale content if configured
        if (config.cache?.fallback_to_stale) {
          console.error(`Fetch failed, returning stale content for ${uri}`);
          return {
            content,
            cached: true,
            stale: true,
            warning: 'Content may be outdated (fetch failed)'
          };
        }
        throw fetchError;
      }
    }

    return { content, cached: true };
  } catch (e) {
    // Cache miss - fetch on demand
    return await fetchAndCache(uri, parsed);
  }
}
```

#### Fallback to Stale Content

When `fallback_to_stale: true` (default), if a refresh fetch fails:

1. **Network error**: Return cached content with `stale: true` warning
2. **Timeout**: Return cached content with `stale: true` warning
3. **Auth error**: Return error (don't expose stale potentially-sensitive content)

```typescript
// Response when returning stale content
{
  content: "# OAuth Documentation\n...",
  cached: true,
  stale: true,
  cachedAt: "2025-01-15T10:00:00Z",
  expiredAt: "2025-01-22T10:00:00Z",
  warning: "Content expired 2 days ago. Refresh failed: network timeout."
}
```

#### Manual Cache Refresh

Users can force refresh with:

```bash
# Refresh specific file
/fractary-codex:fetch corthosai/auth-service/docs/oauth.md --force

# Refresh all expired entries
/fractary-codex:cache-refresh --expired

# Clear and re-fetch a source
/fractary-codex:cache-clear corthosai/auth-service && /fractary-codex:sync-project corthosai/auth-service --from-codex
```

### Wildcard MCP Resource Requests

To bridge the gap between explicit references and exploratory access, the MCP server supports **wildcard patterns** in resource URIs:

#### Wildcard Syntax

```
codex://corthosai/etl.corthion.ai/docs/schema/*       # All files in schema/
codex://corthosai/etl.corthion.ai/docs/schema/**      # Recursive
codex://corthosai/etl.corthion.ai/docs/**/*.yaml      # All YAML files
codex://corthosai/*/CLAUDE.md                         # CLAUDE.md from all projects
```

#### How Wildcard Fetch Works

When Claude requests a wildcard URI:

```
Claude requests: codex://corthosai/etl.corthion.ai/docs/schema/*
                              ↓
                    MCP Server detects wildcard
                              ↓
                    Check cache for matching files
                              ↓
         ┌────────────────────┴────────────────────┐
         ↓                                         ↓
    Some/all cached                          None cached
         ↓                                         ↓
    Check if any expired                    Fetch from source
         ↓                                   (bulk fetch)
    Refresh expired files                          ↓
         ↓                                   Cache all files
         └─────────────────┬───────────────────────┘
                           ↓
              Return list of matching resources
              with content or summary
```

#### MCP Server Implementation

```typescript
// Handle wildcard resource requests
async function handleWildcardRequest(pattern: string): Promise<WildcardResult> {
  const parsed = parsePattern(pattern);  // e.g., { org, project, glob: "docs/schema/*" }

  // Check what's already cached
  const cachedFiles = await findCachedFiles(parsed);
  const expiredFiles = cachedFiles.filter(f => isExpired(f));

  // Determine what needs fetching
  let filesToFetch: string[] = [];

  if (cachedFiles.length === 0) {
    // Nothing cached - need to discover and fetch from source
    filesToFetch = await discoverFilesFromSource(parsed);
  } else if (expiredFiles.length > 0) {
    // Some expired - refresh those
    filesToFetch = expiredFiles.map(f => f.path);
  }

  // Bulk fetch if needed
  if (filesToFetch.length > 0) {
    await bulkFetchAndCache(parsed, filesToFetch);
  }

  // Return all matching files
  const allFiles = await findCachedFiles(parsed);
  return {
    pattern,
    matchCount: allFiles.length,
    files: allFiles.map(f => ({
      uri: f.uri,
      path: f.path,
      cached: true,
      size: f.size_bytes
    }))
  };
}

// Discover files from source (for initial wildcard fetch)
async function discoverFilesFromSource(parsed: ParsedPattern): Promise<string[]> {
  const handler = await getHandler(parsed.org || parsed.project);

  switch (handler) {
    case 'handler-sync-github':
      // Use GitHub API to list files matching pattern
      return await listGitHubFiles(parsed.org, parsed.project, parsed.glob);
    case 'handler-mcp':
      // Query MCP server for matching resources
      return await listMcpResources(parsed.project, parsed.glob);
    default:
      throw new Error(`Wildcard discovery not supported for ${handler}`);
  }
}
```

#### Wildcard Response Format

```typescript
// Response for codex://corthosai/etl.corthion.ai/docs/schema/*
{
  pattern: "codex://corthosai/etl.corthion.ai/docs/schema/*",
  matchCount: 5,
  fetched: 3,      // Files that were fetched (cache miss)
  cached: 2,       // Files already in cache
  files: [
    { uri: "codex://corthosai/etl.corthion.ai/docs/schema/overview.md", size: 4523 },
    { uri: "codex://corthosai/etl.corthion.ai/docs/schema/tables.md", size: 8901 },
    { uri: "codex://corthosai/etl.corthion.ai/docs/schema/relationships.md", size: 3456 },
    { uri: "codex://corthosai/etl.corthion.ai/docs/schema/naming.md", size: 2134 },
    { uri: "codex://corthosai/etl.corthion.ai/docs/schema/versioning.md", size: 5678 }
  ],
  totalSize: 24692
}
```

#### Use Case: Ad-Hoc Exploration

This enables Claude to explore without prior sync:

```
User: "Help me understand our data lake schema"

Claude: Let me fetch the schema documentation...
        [Requests codex://corthosai/etl.corthion.ai/docs/schema/**]

        Found 5 schema documents:
        - overview.md (4.5KB)
        - tables.md (8.9KB)
        - relationships.md (3.5KB)
        - naming.md (2.1KB)
        - versioning.md (5.7KB)

        Reading overview.md first...
```

#### Limits and Safety

```json
{
  "wildcard": {
    "enabled": true,
    "max_files_per_request": 50,
    "max_total_size_mb": 10,
    "require_at_least_org_project": true,
    "blocked_patterns": ["**/*", "*/**"]
  }
}
```

- `max_files_per_request`: Prevent fetching thousands of files
- `max_total_size_mb`: Prevent memory issues
- `require_at_least_org_project`: Must specify at least `org/project/` before wildcard
- `blocked_patterns`: Prevent overly broad patterns

### Fetch Command Update

The `/fractary-codex:fetch` command works with any source and supports patterns:

```bash
# Single file from org project
/fractary-codex:fetch corthion/auth-service/docs/oauth.md

# Pattern - all schema docs
/fractary-codex:fetch corthion/etl.corthion.ai/docs/schema/*

# Multiple patterns (comma-separated)
/fractary-codex:fetch corthion/etl.corthion.ai/docs/*,corthion/auth-service/docs/api/*

# MCP server (Context7)
/fractary-codex:fetch context7/react/hooks.md

# Web domain (HTTP)
/fractary-codex:fetch docs.aws.amazon.com/s3/api.md

# External org's codex
/fractary-codex:fetch acme/partner-lib/docs/integration.md
```

The fetch command:
1. Parses patterns (supports comma-separated multiple patterns)
2. Determines org (for GitHub) or identifier (for external)
3. Looks up the handler in the source registry
4. Invokes the appropriate handler to fetch content
5. Caches in `codex/{org}/{project}/...` or `codex/{identifier}/...`
6. Updates the cache index with entry metadata

### Sync Command Behavior

| Command | Behavior |
|---------|----------|
| `sync-project --to-codex` | Pushes to org's GitHub codex (unchanged) |
| `sync-project --from-codex` | Pulls from org's GitHub codex to `codex/` |
| `sync-org --to-codex` | Pushes all projects to org codex |
| `sync-org --from-codex` | Pulls all org projects to `codex/` |

**Note**: Sync commands only work with GitHub sources. For MCP/HTTP sources, use `/fractary-codex:fetch`.

#### Sync Cache Behavior

By default, **sync commands force refresh** - they always fetch the latest content regardless of cache TTL. This makes sync the authoritative "get me the latest" command.

```bash
# Default: Force refresh (ignores TTL)
/fractary-codex:sync-project corthosai/etl.corthion.ai --from-codex

# Explicit: Respect cache TTL (only fetch expired/missing)
/fractary-codex:sync-project corthosai/etl.corthion.ai --from-codex --respect-cache

# Explicit: Force refresh even if cached
/fractary-codex:sync-project corthosai/etl.corthion.ai --from-codex --force
```

| Flag | Behavior |
|------|----------|
| (default) | Force refresh - always fetch latest |
| `--respect-cache` | Only fetch if missing or expired |
| `--force` | Force refresh (explicit, same as default) |

#### Rationale for Default Force Refresh

1. **Sync is intentional**: User explicitly runs sync, expecting fresh content
2. **Exploration use case**: User wants to explore latest docs, not cached versions
3. **Consistency**: Running sync twice should produce same result
4. **Predictability**: "Sync" means "make local match remote"

#### Configurable Default

If you prefer sync to respect cache by default:

```json
{
  "sync": {
    "default_behavior": "respect_cache",  // or "force_refresh"
    "show_cache_status": true
  }
}
```

#### Sync Output with Cache Info

```bash
$ /fractary-codex:sync-project corthosai/etl.corthion.ai/docs/** --from-codex

Syncing corthosai/etl.corthion.ai/docs/**...

  📥 Fetched:  12 files (fresh from GitHub)
  ⏭️  Skipped:  0 files (--force mode, no skipping)
  📁 Total:    12 files (156KB)

Cache updated:
  - 12 entries added/refreshed
  - TTL: 7 days (expires 2025-01-22)

✅ Sync complete
```

With `--respect-cache`:

```bash
$ /fractary-codex:sync-project corthosai/etl.corthion.ai/docs/** --from-codex --respect-cache

Syncing corthosai/etl.corthion.ai/docs/**...

  📥 Fetched:  3 files (cache miss or expired)
  ⏭️  Skipped:  9 files (still fresh in cache)
  📁 Total:    12 files

✅ Sync complete (9 files served from cache)
```

### Adding New Sources

To add a new source, update the config:

```bash
# Add via command (future)
/fractary-codex:source add context7 --type mcp --server context7

# Or edit config manually
```

**Config addition**:
```json
{
  "sources": {
    "my-new-source": {
      "type": "http",
      "handler": "handler-http",
      "base_url": "https://docs.example.com",
      "ttl_days": 7
    }
  }
}
```

### Examples by Source Type

#### GitHub (Org Projects)

```
codex://corthosai/etl.corthion.ai/docs/architecture.md
codex://corthosai/auth-service/docs/oauth.md
```
- Handler: `handler-sync-github`
- Populated by: `/fractary-codex:sync-project corthosai/etl.corthion.ai --from-codex`
- Storage: `codex/corthosai/etl.corthion.ai/docs/architecture.md`
- Pattern sync: `/fractary-codex:sync-project corthosai/etl.corthion.ai/docs/schema/* --from-codex`

#### External GitHub Org (Plugin Docs)

```
codex://fractary/claude-plugins/plugins/faber/docs/guides/PROJECT-INTEGRATION-GUIDE.md
```
- Handler: `handler-sync-github`
- Config: Requires `fractary` org in sources configuration
- Storage: `codex/fractary/claude-plugins/plugins/faber/docs/guides/`
- Fetch: `/fractary-codex:fetch fractary/claude-plugins/plugins/faber/docs/**`

#### Partner Org

```
codex://acme/partner-lib/docs/integration.md
```
- Handler: `handler-sync-github`
- Config: Requires `acme` org in sources configuration
- Storage: `codex/acme/partner-lib/docs/integration.md`
- Sync: `/fractary-codex:sync-project acme/partner-lib --from-codex`

#### MCP Server (Context7)

```
codex://context7/react/hooks.md
```
- Handler: `handler-mcp`
- Populated by: `/fractary-codex:fetch context7/react/hooks.md`
- Storage: `codex/context7/react/hooks.md`
- Note: Context7 uses library/topic structure (no org prefix)

#### HTTP (Web Documentation)

```
codex://docs.aws.amazon.com/s3/api.md
codex://react.dev/reference/hooks.md
```
- Handler: `handler-http`
- Populated by: `/fractary-codex:fetch docs.aws.amazon.com/s3/api.md`
- Storage: `codex/docs.aws.amazon.com/s3/api.md`
- Fetched from: `https://docs.aws.amazon.com/s3/api.md`
- Note: Domain serves as the identifier (no org prefix)

---

## Implementation Tasks

### Phase 1: MCP Installation (Week 1)

- [ ] **Task 1.1**: Create `scripts/install-mcp.sh`
  - Path resolution logic
  - Settings.json update via jq
  - Backup creation
  - Error handling

- [ ] **Task 1.2**: Update init command workflow
  - Add Step 4: Install MCP Server
  - Add Step 5: Create codex/ directory
  - Update completion output

- [ ] **Task 1.3**: Add uninstall capability
  - `scripts/uninstall-mcp.sh`
  - Removes mcpServers.fractary-codex
  - Optional: removes codex/ directory

- [ ] **Task 1.4**: Build MCP server
  - Ensure `npm run build` works
  - Add to plugin install process
  - Document build requirements

### Phase 2: Sync Unification (Week 2)

- [ ] **Task 2.1**: Update sync-from-codex workflow
  - Change target path to `codex/{project}/`
  - Remove git commit step for target
  - Add cache index update

- [ ] **Task 2.2**: Create cache index management scripts
  - `scripts/update-cache-index.sh`
  - `scripts/read-cache-index.sh`
  - Handle TTL calculation

- [ ] **Task 2.3**: Update handler-sync-github
  - Add CACHE_MODE parameter
  - Implement path rewriting
  - Skip commit when caching

- [ ] **Task 2.4**: Update sync-org for cache mode
  - Apply same changes for org-wide sync
  - Aggregate cache index updates

### Phase 3: Universal Reference Resolution (Week 3)

- [ ] **Task 3.1**: Add current project detection
  - Implement `detectCurrentProject()` in MCP server
  - Priority: env var → config → git remote → directory name
  - Update init to store `project_name` in config

- [ ] **Task 3.2**: Implement URI resolution logic
  - Update `resolveUri()` with current-project awareness
  - Current project → project root
  - Other project → cache directory
  - Add tests for resolution logic

- [ ] **Task 3.3**: Create reference validation command
  - `/fractary-codex:validate-refs`
  - Scan for non-portable references (../, /)
  - Suggest codex:// replacements
  - Optional --fix mode

- [ ] **Task 3.4**: Update init command
  - Detect and store project name
  - Pass to MCP server environment
  - Show reference resolution info in output

### Phase 4: Multi-Source Support (Week 4)

- [ ] **Task 4.1**: Implement source registry
  - Add `sources` section to cache index
  - Track handler type per identifier
  - Store source-specific metadata

- [ ] **Task 4.2**: Update MCP server for multi-source
  - Load source registry on startup
  - `getHandler()` function for identifier lookup
  - Infer handler from identifier pattern as fallback

- [ ] **Task 4.3**: Create handler-http
  - HTTP/HTTPS fetch implementation
  - URL-to-path mapping
  - TTL configuration per domain

- [ ] **Task 4.4**: Create handler-mcp
  - MCP server resource fetching
  - Context7 integration
  - Response caching

- [ ] **Task 4.5**: Update fetch command
  - Parse identifier from reference
  - Route to appropriate handler
  - Update cache index with source info

- [ ] **Task 4.6**: Implement on-demand fetch in MCP server
  - Add `readResource()` with cache-miss detection
  - Implement `fetchAndCache()` for automatic retrieval
  - Add handler invocation based on source type
  - Handle expired cache entries (re-fetch)
  - Graceful fallback to stale content on fetch failure

- [ ] **Task 4.7**: Configure on-demand fetch options
  - Add `on_demand_fetch` config section
  - Timeout and retry settings
  - Allowed/blocked org lists
  - Fallback-to-stale toggle

### Phase 5: Integration & Testing (Week 5)

- [ ] **Task 5.1**: End-to-end testing
  - Init → Sync → MCP access flow
  - Verify cache index accuracy
  - Test resource listing
  - Test self-referential resolution

- [ ] **Task 5.2**: Cross-project reference testing
  - Create test docs with codex:// references
  - Sync between test projects
  - Verify references resolve correctly in both contexts

- [ ] **Task 5.3**: Multi-source testing
  - Test GitHub source (org codex)
  - Test HTTP source (external domains)
  - Test MCP source (Context7)
  - Verify flat structure with mixed sources

- [ ] **Task 5.4**: Update documentation
  - Update README with new workflow
  - Add reference guidelines section
  - Add multi-source configuration guide
  - Update migration guide
  - Add troubleshooting section

- [ ] **Task 5.5**: Add validation commands
  - `/fractary-codex:validate-setup`
  - `/fractary-codex:validate-refs`
  - `/fractary-codex:source list`
  - Checks MCP installed
  - Checks cache directory
  - Checks config exists

### Phase 6: Fractary-Docs Plugin Integration (Week 6)

- [ ] **Task 6.1**: Update doc-writer skill for syncable docs
  - Detect `codex_sync_include: true` in frontmatter
  - Scan for non-portable references during write
  - Auto-convert relative/absolute paths to `codex://` format
  - Log conversions to user

- [ ] **Task 6.2**: Update doc-validator skill
  - Add syncable doc reference check to `/fractary-docs:validate`
  - Scan docs with `codex_sync_include: true` for non-portable refs
  - Generate fix suggestions with line numbers
  - Report summary of issues found

- [ ] **Task 6.3**: Implement --fix option for validation
  - Parse markdown links in syncable docs
  - Convert non-portable references to `codex://` format
  - Preserve link text and formatting
  - Write updated content back to file

- [ ] **Task 6.4**: Add org/project detection to fractary-docs
  - Read from `.fractary/plugins/codex/config.json`
  - Fall back to git remote parsing
  - Use for generating correct `codex://` URIs

- [ ] **Task 6.5**: Create syncable docs tests
  - Test reference conversion during write
  - Test validation detection of non-portable refs
  - Test --fix auto-conversion
  - Test cross-org reference handling

### Phase 7: Wildcard & Sync Enhancements (Week 7)

- [ ] **Task 7.1**: Implement wildcard MCP resource requests
  - Detect wildcard patterns (`*`, `**`, `*.md`) in URIs
  - `handleWildcardRequest()` function
  - `findCachedFiles()` for pattern matching in cache
  - `discoverFilesFromSource()` for GitHub API file listing

- [ ] **Task 7.2**: Add bulk fetch for wildcards
  - `bulkFetchAndCache()` for multiple files
  - Parallel fetching with concurrency limit
  - Progress reporting for large fetches
  - Handle partial failures gracefully

- [ ] **Task 7.3**: Wildcard safety limits
  - `max_files_per_request` enforcement
  - `max_total_size_mb` enforcement
  - `blocked_patterns` validation
  - `require_at_least_org_project` validation

- [ ] **Task 7.4**: Sync cache behavior options
  - Default force refresh behavior
  - `--respect-cache` flag implementation
  - `--force` flag (explicit)
  - Configurable default in config.json

- [ ] **Task 7.5**: Enhanced sync output
  - Show fetched vs skipped counts
  - Cache status in output
  - TTL expiration info
  - Total size reporting

- [ ] **Task 7.6**: Wildcard and sync tests
  - Test wildcard discovery from GitHub
  - Test wildcard with partial cache
  - Test sync force refresh
  - Test sync --respect-cache
  - Test wildcard limits enforcement

---

## Migration & Compatibility

### Breaking Changes

**Behavior Change**: `--from-codex` no longer writes to project root.

Files previously synced to:
```
project/
├── docs/shared-standards.md     ← Old location (permanent)
```

Now synced to:
```
project/
├── codex/
│   └── shared-lib/
│       └── docs/shared-standards.md  ← New location (ephemeral)
```

### Migration Path

1. **Run new init**: `/fractary-codex:init` (installs MCP, creates codex/)
2. **Clean old synced files**: Remove previously synced files from project root (manual)
3. **Re-sync**: `/fractary-codex:sync-project --from-codex` (populates cache)
4. **Update references**: Change file paths to `codex://` URIs

### Compatibility Flags

For gradual migration, add flags:

```bash
# Legacy mode - write to project root (deprecated)
/fractary-codex:sync-project --from-codex --legacy

# Cache mode - write to codex/ (default)
/fractary-codex:sync-project --from-codex
```

The `--legacy` flag will show deprecation warning:
```
⚠️ DEPRECATION WARNING: --legacy flag will be removed in v4.0
Files written to project root (legacy behavior).
Migrate to cache-based approach: /fractary-codex:init
```

---

## Testing & Validation

### Test Cases

#### Init Tests

| Test | Expected Result |
|------|-----------------|
| Init in new project | Creates config, codex/, installs MCP |
| Init with existing config | Preserves config, adds MCP if missing |
| Init with existing MCP | Updates MCP path if changed |
| Init without plugin installed | Error with clear message |

#### Sync Tests

| Test | Expected Result |
|------|-----------------|
| sync-project --from-codex | Files in codex/{project}/, index updated |
| sync-project --to-codex | Files in central codex (unchanged) |
| sync-org --from-codex | All org projects in codex/, index updated |
| sync with --legacy | Files in project root, deprecation warning |

#### MCP Tests

| Test | Expected Result |
|------|-----------------|
| List resources | Shows all cached files |
| Read cached resource | Returns file content + metadata (cached: true) |
| Read expired resource | Re-fetches, updates cache, returns fresh content |
| Cache status tool | Shows sync info |

#### On-Demand Fetch Tests

| Test | Scenario | Expected Result |
|------|----------|-----------------|
| Cache miss (GitHub) | Request `codex://fractary/claude-plugins/...` not in cache | Fetched from GitHub raw, cached, returned |
| Cache miss (MCP) | Request `codex://context7/react/hooks.md` not in cache | Fetched from Context7 MCP, cached, returned |
| Cache miss (HTTP) | Request `codex://docs.aws.amazon.com/s3/api.md` not in cache | Fetched from URL, cached, returned |
| Expired entry | Request cached doc past TTL | Re-fetched, cache updated, fresh content returned |
| Fetch failure + stale cache | Network error, stale content exists | Stale content returned with warning |
| Fetch failure + no cache | Network error, no cached content | Error with helpful message |
| Blocked org | Request from org in `blocked_orgs` | Error: org not allowed |
| Timeout | Fetch exceeds `timeout_ms` | Retry or fallback to stale |
| Private repo | Request to private GitHub repo | Auth error with guidance |

#### Reference Resolution Tests

| Test | Context | Reference | Expected Resolution |
|------|---------|-----------|---------------------|
| Self-reference | In `corthosai/etl.corthion.ai` | `codex://corthosai/etl.corthion.ai/docs/arch.md` | `./docs/arch.md` |
| Same org project | In `corthosai/etl.corthion.ai` | `codex://corthosai/auth-service/docs/oauth.md` | `./codex/corthosai/auth-service/docs/oauth.md` |
| External org (plugins) | In `corthosai/etl.corthion.ai` | `codex://fractary/claude-plugins/plugins/faber/docs/guide.md` | `./codex/fractary/claude-plugins/plugins/faber/docs/guide.md` |
| Partner org | In `corthosai/etl.corthion.ai` | `codex://acme/partner-lib/docs/api.md` | `./codex/acme/partner-lib/docs/api.md` |
| External source | In `corthosai/etl.corthion.ai` | `codex://context7/react/hooks.md` | `./codex/context7/react/hooks.md` |
| Same doc, different context | In `corthosai/dashboard` | `codex://corthosai/etl.corthion.ai/docs/arch.md` | `./codex/corthosai/etl.corthion.ai/docs/arch.md` |
| No config | Fallback | Any `codex://X/Y/path` | Uses git remote or directory names |

#### Reference Validation Tests

| Test | Input | Expected Result |
|------|-------|-----------------|
| Portable reference | `codex://corthosai/proj/docs/file.md` | ✅ Pass |
| Cross-org reference | `codex://fractary/claude-plugins/plugins/faber/docs/guide.md` | ✅ Pass |
| External reference | `codex://context7/react/hooks.md` | ✅ Pass |
| Same-folder relative | `./sibling.md` | ✅ Pass (optional warning) |
| Parent-folder relative | `../other/file.md` | ⚠️ Warning with suggestion |
| Absolute path | `/docs/file.md` | ⚠️ Warning with suggestion |
| External URL | `https://example.com` | ✅ Pass (ignored) |

#### Multi-Source Tests

| Test | Source | Handler | Expected Storage |
|------|--------|---------|------------------|
| Own org project | `corthosai/etl.corthion.ai` | `handler-sync-github` | `codex/corthosai/etl.corthion.ai/` |
| External org (plugins) | `fractary/claude-plugins` | `handler-sync-github` | `codex/fractary/claude-plugins/` |
| Partner org | `acme/partner-lib` | `handler-sync-github` | `codex/acme/partner-lib/` |
| MCP server | `context7` | `handler-mcp` | `codex/context7/` |
| Web domain | `docs.aws.amazon.com` | `handler-http` | `codex/docs.aws.amazon.com/` |

| Test | Source Type | Action | Expected Result |
|------|-------------|--------|-----------------|
| Fetch from org | github | `/fetch corthosai/auth-service/docs/api.md` | Cached in `codex/corthosai/auth-service/` |
| Fetch with pattern | github | `/fetch corthosai/etl/docs/schema/*` | All schema docs cached |
| Fetch multiple | github | `/fetch corthosai/etl/docs/*,corthosai/auth/docs/*` | Both project docs cached |
| Fetch plugin docs | github | `/fetch fractary/claude-plugins/plugins/faber/docs/**` | Cached in `codex/fractary/claude-plugins/` |
| Fetch from Context7 | mcp | `/fetch context7/react/hooks.md` | Cached in `codex/context7/react/` |
| Fetch from web | http | `/fetch react.dev/reference/hooks.md` | Cached in `codex/react.dev/` |
| Mixed sources list | all | `MCP list resources` | Shows all sources (org-prefixed and flat) |
| Source registry | all | Check `.cache-index.json` | Contains `sources` with orgs and externals |

#### Fractary-Docs Integration Tests

| Test | Scenario | Expected Result |
|------|----------|-----------------|
| Write syncable doc | Create doc with `codex_sync_include: true` and relative ref | Ref auto-converted to `codex://` |
| Write non-syncable doc | Create doc without `codex_sync_include` and relative ref | Ref unchanged (relative OK) |
| Validate syncable doc | Doc with `codex_sync_include: true` has `../file.md` | ⚠️ Warning with fix suggestion |
| Validate with --fix | Syncable doc with non-portable refs | Refs converted, file updated |
| Cross-org ref in syncable | Syncable doc refs `codex://fractary/claude-plugins/...` | ✅ Pass (already portable) |
| Anchor links | Syncable doc has `#section` links | ✅ Pass (anchors ignored) |
| External URLs | Syncable doc has `https://...` links | ✅ Pass (URLs ignored) |

### Validation Script

**File**: `plugins/codex/scripts/validate-setup.sh`

```bash
#!/usr/bin/env bash
# Validate codex plugin setup

ERRORS=0

echo "Validating Codex Plugin Setup..."
echo ""

# Check config
if [ -f ".fractary/plugins/codex/config.json" ]; then
    echo "✅ Config: .fractary/plugins/codex/config.json"
else
    echo "❌ Config: Missing .fractary/plugins/codex/config.json"
    ERRORS=$((ERRORS + 1))
fi

# Check codex directory
if [ -d "codex" ]; then
    echo "✅ Cache: codex/ directory exists"
else
    echo "❌ Cache: codex/ directory missing"
    ERRORS=$((ERRORS + 1))
fi

# Check gitignore
if grep -q '^codex/$' .gitignore 2>/dev/null; then
    echo "✅ Gitignore: codex/ is ignored"
else
    echo "⚠️  Gitignore: codex/ not in .gitignore"
fi

# Check MCP server in settings
if [ -f ".claude/settings.json" ]; then
    if jq -e '.mcpServers["fractary-codex"]' .claude/settings.json >/dev/null 2>&1; then
        echo "✅ MCP: fractary-codex configured in .claude/settings.json"

        # Verify server exists
        SERVER_PATH=$(jq -r '.mcpServers["fractary-codex"].args[0]' .claude/settings.json)
        if [ -f "$SERVER_PATH" ]; then
            echo "✅ MCP Server: $SERVER_PATH exists"
        else
            echo "❌ MCP Server: $SERVER_PATH not found"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo "❌ MCP: fractary-codex not in .claude/settings.json"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "❌ MCP: .claude/settings.json missing"
    ERRORS=$((ERRORS + 1))
fi

# Check cache index
if [ -f "codex/.cache-index.json" ]; then
    ENTRIES=$(jq '.stats.total_entries' codex/.cache-index.json)
    echo "✅ Cache Index: $ENTRIES entries"
else
    echo "ℹ️  Cache Index: Not created yet (run sync to populate)"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ Setup is valid!"
else
    echo "❌ Found $ERRORS error(s). Run /fractary-codex:init to fix."
    exit 1
fi
```

---

## Success Criteria

### Functional Requirements

- [ ] `/fractary-codex:init` creates config AND installs MCP server
- [ ] `--from-codex` writes to `codex/` cache, not project root
- [ ] Cache index updated with sync metadata
- [ ] MCP server reads from `codex/` cache
- [ ] `codex://` resources accessible in Claude

### Reference Resolution Requirements

- [ ] Current project detected from config/git/directory
- [ ] `codex://current-project/*` resolves to project root
- [ ] `codex://other-project/*` resolves to cache directory
- [ ] Same `codex://` reference works in any project context
- [ ] `/fractary-codex:validate-refs` scans for non-portable references
- [ ] Suggestions provided for converting to `codex://` syntax

### Multi-Source Requirements

- [ ] Org-prefixed cache structure for GitHub sources (`org/project/`)
- [ ] Flat cache structure for external sources (`identifier/`)
- [ ] Source registry in cache index tracks handler per org/identifier
- [ ] GitHub handler works for own org and external orgs (e.g., `fractary/claude-plugins`)
- [ ] HTTP handler fetches from web domains
- [ ] MCP handler integrates with Context7 and other MCP servers
- [ ] Handler inference from identifier pattern as fallback
- [ ] `/fractary-codex:fetch` works with any source type
- [ ] `/fractary-codex:fetch` supports comma-separated patterns
- [ ] `/fractary-codex:source list` shows configured sources

### On-Demand Fetch Requirements

- [ ] MCP server auto-fetches on cache miss (no pre-fetch required)
- [ ] Expired cache entries re-fetched on access
- [ ] Graceful fallback to stale content on fetch failure
- [ ] Handler invocation based on source type (GitHub, MCP, HTTP)
- [ ] Configurable timeout, retry, and allowed/blocked orgs
- [ ] Fetch result includes metadata (cached, fetchedAt, expiresAt)
- [ ] Private repo access returns helpful auth guidance

### Fractary-Docs Integration Requirements

- [ ] Docs with `codex_sync_include: true` use `codex://` references
- [ ] Doc writer auto-converts relative refs to `codex://` for syncable docs
- [ ] `/fractary-docs:validate` checks syncable docs for non-portable refs
- [ ] Validation reports line numbers and suggested fixes
- [ ] `--fix` option auto-converts non-portable refs in syncable docs
- [ ] Cross-org references work (e.g., `codex://fractary/claude-plugins/...`)
- [ ] Org/project detection reads from codex config

### Performance Requirements

- [ ] Init completes in < 5 seconds
- [ ] Sync performance unchanged (no regression)
- [ ] MCP resource read < 100ms (local cache)
- [ ] Cache index operations < 50ms
- [ ] Reference resolution < 10ms

### Wildcard MCP Requirements

- [ ] MCP server accepts wildcard patterns (`*`, `**`, `*.md`)
- [ ] Wildcards trigger bulk fetch for cache misses
- [ ] Discovery via GitHub API for unknown files
- [ ] Safety limits enforced (max files, max size)
- [ ] `require_at_least_org_project` prevents overly broad patterns
- [ ] Wildcard returns list of matching resources with metadata

### Sync Cache Behavior Requirements

- [ ] Sync defaults to force refresh (always fetch latest)
- [ ] `--respect-cache` option only fetches missing/expired
- [ ] `--force` option explicitly forces refresh
- [ ] Configurable default behavior in config.json
- [ ] Sync output shows fetched vs skipped counts
- [ ] Cache TTL info displayed after sync

### Quality Requirements

- [ ] No breaking changes to `--to-codex` (publishing)
- [ ] Clear deprecation path for `--legacy`
- [ ] Comprehensive error messages
- [ ] Documentation updated
- [ ] Reference guidelines documented
- [ ] Two use cases documented (explicit refs vs exploratory)

---

## Related Specifications

- **SPEC-00012**: Codex Plugin Refactoring (v2.0 sync)
- **SPEC-00030-01**: Knowledge Retrieval Architecture (v3.0 vision)
- **SPEC-00030-04**: MCP Integration (Phase 3)
- **SPEC-00030-05**: Migration Guide (Phase 4)

---

## Appendix: Complete User Flow

### After Implementation

```bash
# 1. One-time setup
/fractary-codex:init
# ✅ Detected: corthosai/etl.corthion.ai (from git remote)
# ✅ Created .fractary/plugins/codex/config.json
# ✅ Created codex/ directory (gitignored)
# ✅ Installed MCP server in .claude/settings.json

# 2. Prefetch all docs from your org's codex
/fractary-codex:sync-org corthosai --from-codex
# ✅ Synced 45 files to codex/corthosai/auth-service/
# ✅ Synced 23 files to codex/corthosai/shared-lib/
# ✅ Updated cache index

# 3. Prefetch specific docs (pattern matching)
/fractary-codex:sync-project corthosai/etl.corthion.ai/docs/schema/* --from-codex
# ✅ Synced 8 files matching docs/schema/*
# ✅ Updated cache index

# 4. Fetch plugin integration guides from external org
/fractary-codex:fetch fractary/claude-plugins/plugins/faber/docs/guides/**
# ✅ Fetched 4 files from fractary org
# ✅ Cached in codex/fractary/claude-plugins/

# 5. Fetch from MCP sources
/fractary-codex:fetch context7/react/hooks.md,context7/typescript/generics.md
# ✅ Fetched 2 files from context7 MCP server
# ✅ Cached in codex/context7/

# 6. Claude can now access via MCP
# User asks: "Show me the OAuth documentation"
# Claude reads: codex://corthosai/auth-service/docs/oauth.md
# (Resolved from codex/corthosai/auth-service/docs/oauth.md)

# User asks: "How do I integrate the faber plugin?"
# Claude reads: codex://fractary/claude-plugins/plugins/faber/docs/guides/PROJECT-INTEGRATION-GUIDE.md
# (Resolved from codex/fractary/claude-plugins/plugins/faber/docs/guides/...)

# 7. Publish your changes to central codex
/fractary-codex:sync-project corthosai/etl.corthion.ai --to-codex
# ✅ Synced 12 files to codex.corthosai.com
# ✅ Created commit: "sync: Update docs from etl.corthion.ai"

# 8. Check cache status
# Claude uses: codex_cache_status tool
# "Cache has 76 entries from 4 sources, 2.8MB total"
# "  - corthosai: 60 entries (auth-service, shared-lib, ...)"
# "  - fractary: 8 entries (claude-plugins)"
# "  - context7: 8 entries"
```

---

**Status:** Ready for Implementation
**Next Steps:** Review and approve, then begin Phase 1 tasks
**Document Version:** 1.0.0
**Last Updated:** 2025-01-15
