# Phase 1: Local Cache & Reference System

**Specification ID:** SPEC-00030-02
**Phase:** 1 of 4
**Parent Spec:** [SPEC-00030-01](./SPEC-00030-01-codex-knowledge-retrieval-architecture.md)
**Version:** 1.0.0
**Status:** Planning
**Duration:** 2-3 weeks

---

## Table of Contents

1. [Phase Overview](#phase-overview)
2. [Goals & Objectives](#goals--objectives)
3. [Technical Implementation](#technical-implementation)
4. [File Structure](#file-structure)
5. [Implementation Tasks](#implementation-tasks)
6. [Testing & Validation](#testing--validation)

---

## Phase Overview

### Purpose

Establish the foundation for knowledge retrieval by implementing local caching, reference resolution, and the document-fetcher skill. This phase creates the core infrastructure that subsequent phases will build upon.

### Scope

**In Scope:**
- `codex/` directory structure and cache index
- `@codex/` reference syntax and resolution
- `document-fetcher` skill (basic fetch operation)
- Cache management (store, retrieve, expire)
- GitHub handler (reuse existing sync scripts)
- Commands: `/codex:fetch`, `/codex:cache-list`, `/codex:cache-clear`

**Out of Scope:**
- Multi-source support (Phase 2)
- Frontmatter permissions (Phase 2)
- MCP integration (Phase 3)
- Context7 integration (Phase 3)

### Dependencies

- **fractary-repo plugin**: Git operations
- **Existing codex sync scripts**: Reuse for GitHub fetching

---

## Goals & Objectives

### Primary Goals

1. ✅ **Perfect Alignment**: `@codex/project/path` → `codex/project/path`
2. ✅ **Cache-First Retrieval**: Check local before fetching remote
3. ✅ **TTL-Based Freshness**: Configurable expiration per source
4. ✅ **Simple Commands**: Easy to use, clear feedback

### Success Metrics

- Reference resolution time: < 50ms (cache hit)
- Fetch time from GitHub: < 2s (cache miss)
- Cache index operations: < 10ms
- Zero breaking changes to existing sync

---

## Technical Implementation

### 1. Cache Directory Structure

**Location**: `codex/` (visible, gitignored, like `node_modules/`)

```
codex/
├── auth-service/              # Project name (from fractary-codex)
│   ├── docs/
│   │   ├── oauth.md
│   │   └── api.md
│   ├── specs/
│   │   └── architecture.md
│   └── README.md
├── shared-lib/                # Another project
│   └── docs/
│       └── integration.md
└── .cache-index.json          # Metadata (TTL, sizes, timestamps)
```

**Cache Index Format** (`.cache-index.json`):
```json
{
  "version": "1.0",
  "entries": [
    {
      "reference": "@codex/auth-service/docs/oauth.md",
      "path": "auth-service/docs/oauth.md",
      "source": "fractary-codex",
      "cached_at": "2025-01-15T10:00:00Z",
      "expires_at": "2025-01-22T10:00:00Z",
      "ttl_days": 7,
      "size_bytes": 12543,
      "hash": "sha256:abc123...",
      "last_accessed": "2025-01-15T14:30:00Z"
    }
  ],
  "stats": {
    "total_entries": 42,
    "total_size_bytes": 523456,
    "last_cleanup": "2025-01-14T00:00:00Z"
  }
}
```

### 2. Reference Resolution

**Syntax**: `@codex/{project}/{path}`

**Resolution Algorithm**:
```javascript
function resolveReference(reference) {
  // 1. Validate format
  if (!reference.startsWith('@codex/')) {
    throw new Error('Invalid reference: must start with @codex/');
  }

  // 2. Extract path
  const relativePath = reference.replace(/^@codex\//, '');

  // 3. Construct cache path
  const cachePath = path.join('codex', relativePath);

  // 4. Construct MCP URI (future)
  const mcpUri = reference.replace(/^@/, '') + '://';

  return { cachePath, mcpUri, relativePath };
}
```

**Examples**:
```
@codex/auth-service/docs/oauth.md
  → cachePath: codex/auth-service/docs/oauth.md
  → mcpUri: codex://auth-service/docs/oauth.md

@codex/shared-lib/README.md
  → cachePath: codex/shared-lib/README.md
  → mcpUri: codex://shared-lib/README.md
```

### 3. document-fetcher Skill

**Location**: `plugins/codex/skills/document-fetcher/`

**Structure**:
```
skills/document-fetcher/
├── SKILL.md                   # Main skill definition
├── workflow/
│   ├── fetch-basic.md         # Basic fetch operation (Phase 1)
│   └── fetch-with-permissions.md  # Permission checking (Phase 2)
└── scripts/
    ├── resolve-reference.sh   # Parse @codex/ reference
    ├── cache-lookup.sh        # Check cache + TTL
    ├── cache-store.sh         # Store in cache + index
    └── github-fetch.sh        # Fetch from GitHub (reuse existing)
```

**SKILL.md Content**:
```markdown
---
name: document-fetcher
description: |
  Fetch documents from codex knowledge base with cache-first strategy
tools: Bash, Read
---

<CONTEXT>
You are the document-fetcher skill for the Fractary codex plugin.
Your responsibility is to resolve @codex/ references and retrieve content from cache or remote sources.
</CONTEXT>

<CRITICAL_RULES>
**Cache-First Strategy:**
- ALWAYS check cache before fetching remote
- ALWAYS verify TTL before serving cached content
- ALWAYS update last_accessed timestamp on cache hits

**Path Security:**
- NEVER allow directory traversal (../)
- ALWAYS validate reference format
- ALWAYS sanitize file paths

**Error Handling:**
- Clear error messages with actionable guidance
- Never fail silently
- Log all fetch operations
</CRITICAL_RULES>

<INPUTS>
- reference: @codex/ reference string
- force_refresh: boolean (default: false)
- ttl_override: number of days (optional)
</INPUTS>

<WORKFLOW>

## Step 1: Parse Reference

USE SCRIPT: ./scripts/resolve-reference.sh
Arguments: {reference}

Output: {cachePath, relativePath, project, path}

## Step 2: Check Cache

IF force_refresh == false:
  USE SCRIPT: ./scripts/cache-lookup.sh
  Arguments: {cachePath}

  IF cache hit AND fresh:
    Update last_accessed timestamp
    READ FILE: codex/{relativePath}
    RETURN: Content with metadata
    STOP (cache hit - fast path)

## Step 3: Fetch from Source

Load configuration: .fractary/plugins/codex/config.json
Determine source: "fractary-codex" (GitHub - Phase 1)

USE SCRIPT: ./scripts/github-fetch.sh
Arguments: {
  project: extracted from reference
  path: extracted from reference
  codex_repo: from config
}

Output: {content, metadata}

## Step 4: Store in Cache

USE SCRIPT: ./scripts/cache-store.sh
Arguments: {
  reference,
  cachePath,
  content,
  ttl_days: from config (default: 7)
}

Updates: codex/.cache-index.json

## Step 5: Return Content

Return: {
  content: file content
  cached: true/false
  source: "fractary-codex"
  fetched_at: timestamp
}

</WORKFLOW>

<COMPLETION_CRITERIA>
- ✅ Content returned to caller
- ✅ Cache index updated
- ✅ Fetch logged
</COMPLETION_CRITERIA>

<OUTPUTS>
Return structured response:
```json
{
  "success": true,
  "reference": "@codex/auth-service/docs/oauth.md",
  "content": "# OAuth Implementation\n...",
  "metadata": {
    "cached": true,
    "cached_at": "2025-01-15T10:00:00Z",
    "expires_at": "2025-01-22T10:00:00Z",
    "source": "fractary-codex"
  }
}
```
</OUTPUTS>

<ERROR_HANDLING>
  <INVALID_REFERENCE>
  If reference format invalid:
  - Return error with format explanation
  - Provide examples of valid references
  </INVALID_REFERENCE>

  <FETCH_FAILURE>
  If remote fetch fails:
  - Check if stale cache exists
  - Offer to serve stale cache
  - Suggest: /codex:cache-refresh to retry
  </FETCH_FAILURE>

  <CACHE_CORRUPTION>
  If cache index corrupted:
  - Rebuild index from filesystem
  - Log warning
  - Continue operation
  </CACHE_CORRUPTION>
</ERROR_HANDLING>
```

### 4. Scripts Implementation

**resolve-reference.sh**:
```bash
#!/usr/bin/env bash
# Resolve @codex/ reference to component parts

set -euo pipefail

reference="$1"

# Validate format
if [[ ! "$reference" =~ ^@codex/.+ ]]; then
  echo "ERROR: Invalid reference format: $reference" >&2
  echo "Expected: @codex/{project}/{path}" >&2
  exit 1
fi

# Extract components
relative_path="${reference#@codex/}"
project=$(echo "$relative_path" | cut -d'/' -f1)
path="${relative_path#$project/}"

# Output JSON
cat <<EOF
{
  "reference": "$reference",
  "relative_path": "$relative_path",
  "cache_path": "codex/$relative_path",
  "project": "$project",
  "path": "$path"
}
EOF
```

**cache-lookup.sh**:
```bash
#!/usr/bin/env bash
# Check cache for document and verify TTL

set -euo pipefail

cache_path="$1"
index_file="codex/.cache-index.json"

# Check if cache file exists
if [[ ! -f "$cache_path" ]]; then
  echo '{"cached": false, "reason": "not_in_cache"}'
  exit 0
fi

# Check if index exists
if [[ ! -f "$index_file" ]]; then
  echo '{"cached": false, "reason": "index_missing"}'
  exit 0
fi

# Look up entry in index
entry=$(jq --arg path "$cache_path" \
  '.entries[] | select(.path == $path)' \
  "$index_file")

if [[ -z "$entry" ]]; then
  echo '{"cached": false, "reason": "not_in_index"}'
  exit 0
fi

# Check TTL
expires_at=$(echo "$entry" | jq -r '.expires_at')
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ "$expires_at" < "$now" ]]; then
  echo '{"cached": true, "fresh": false, "reason": "expired"}'
  exit 0
fi

# Cache hit - fresh
echo '{"cached": true, "fresh": true}'
```

**cache-store.sh**:
```bash
#!/usr/bin/env bash
# Store document in cache and update index

set -euo pipefail

reference="$1"
cache_path="$2"
content="$3"
ttl_days="${4:-7}"

index_file="codex/.cache-index.json"

# Create directory structure
mkdir -p "$(dirname "$cache_path")"

# Write content
echo "$content" > "$cache_path"

# Calculate metadata
size_bytes=$(wc -c < "$cache_path")
hash=$(sha256sum "$cache_path" | cut -d' ' -f1)
cached_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
expires_at=$(date -u -d "+${ttl_days} days" +"%Y-%m-%dT%H:%M:%SZ")

# Create or update index
if [[ ! -f "$index_file" ]]; then
  echo '{"version": "1.0", "entries": [], "stats": {}}' > "$index_file"
fi

# Add entry to index
jq --arg ref "$reference" \
   --arg path "${cache_path#codex/}" \
   --arg cached "$cached_at" \
   --arg expires "$expires_at" \
   --argjson ttl "$ttl_days" \
   --argjson size "$size_bytes" \
   --arg hash "$hash" \
  '
  .entries |= map(select(.reference != $ref)) + [{
    reference: $ref,
    path: $path,
    source: "fractary-codex",
    cached_at: $cached,
    expires_at: $expires,
    ttl_days: $ttl,
    size_bytes: $size,
    hash: $hash,
    last_accessed: $cached
  }]
  ' "$index_file" > "${index_file}.tmp"

mv "${index_file}.tmp" "$index_file"

echo '{"success": true}'
```

**github-fetch.sh** (reuse existing sync logic):
```bash
#!/usr/bin/env bash
# Fetch document from GitHub codex repo

set -euo pipefail

project="$1"
path="$2"
codex_repo="$3"  # e.g., "codex.fractary.com"

# Load configuration
config_file=".fractary/plugins/codex/config.json"
if [[ ! -f "$config_file" ]]; then
  echo "ERROR: Codex configuration not found" >&2
  exit 1
fi

org=$(jq -r '.organization' "$config_file")

# Use sparse checkout for efficiency
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

cd "$temp_dir"
git clone --filter=blob:none --sparse \
  "https://github.com/$org/$codex_repo.git" repo

cd repo
git sparse-checkout set "projects/$project/$path"

# Read content
if [[ -f "projects/$project/$path" ]]; then
  cat "projects/$project/$path"
else
  echo "ERROR: Document not found in codex: projects/$project/$path" >&2
  exit 1
fi
```

### 5. Commands

**Command: /codex:fetch**

**File**: `commands/fetch.md`

```markdown
---
name: fractary-codex:fetch
description: Fetch a document from codex knowledge base
argument-hint: <@codex/reference> [--force]
---

<CONTEXT>
You are the fetch command router for the codex plugin.
Your role is to parse arguments and invoke the document-fetcher skill.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse reference argument (required)
- Parse force flag (optional)
- Invoke document-fetcher skill
- Display returned content to user

**YOU MUST NOT:**
- Fetch documents yourself
- Read files directly
- Execute git commands
</CRITICAL_RULES>

<WORKFLOW>
1. Parse arguments:
   - reference: First positional argument (required)
   - force: --force flag (optional)

2. Validate reference format:
   - Must start with @codex/
   - Must contain project and path

3. Invoke document-fetcher skill:
   ```
   USE SKILL: fractary-codex:document-fetcher
   Operation: fetch
   Arguments: {
     reference: parsed_reference,
     force_refresh: force_flag
   }
   ```

4. Display result to user:
   - Show content
   - Indicate if from cache or fresh fetch
   - Show expiration time
</WORKFLOW>

<EXAMPLES>
# Fetch document (cache-first)
/codex:fetch @codex/auth-service/docs/oauth.md

# Force refresh from source
/codex:fetch @codex/auth-service/docs/oauth.md --force
</EXAMPLES>
```

**Command: /codex:cache-list**

**File**: `commands/cache-list.md`

```markdown
---
name: fractary-codex:cache-list
description: List all cached documents
argument-hint: [--source <name>] [--expired]
---

<CONTEXT>
You are the cache-list command router.
Display cached documents with metadata.
</CONTEXT>

<WORKFLOW>
1. Read cache index: codex/.cache-index.json
2. Filter entries (if flags provided):
   - --source: Filter by source name
   - --expired: Show only expired entries
3. Format output:
   - Table view with columns: Reference, Cached At, Expires At, Size
   - Summary: Total count, Total size, Expired count
</WORKFLOW>

<EXAMPLES>
# List all cached documents
/codex:cache-list

# List expired cache entries
/codex:cache-list --expired

# List from specific source
/codex:cache-list --source fractary-codex
</EXAMPLES>
```

**Command: /codex:cache-clear**

**File**: `commands/cache-clear.md`

```markdown
---
name: fractary-codex:cache-clear
description: Clear cached documents
argument-hint: [--all | --expired | <@codex/reference>]
---

<CONTEXT>
You are the cache-clear command router.
Remove cached documents from local cache.
</CONTEXT>

<CRITICAL_RULES>
**Confirmation Required:**
- ALWAYS confirm with user before clearing
- Show what will be deleted (count, size)
- Require explicit yes/no response

**Safety:**
- NEVER delete cache index
- NEVER delete .fractary/ directory
- ONLY delete codex/ contents
</CRITICAL_RULES>

<WORKFLOW>
1. Determine scope:
   - --all: Clear entire cache
   - --expired: Clear only expired entries
   - <reference>: Clear specific document

2. Calculate impact:
   - Count of entries to delete
   - Total size to free

3. Confirm with user:
   - Show impact summary
   - Ask: "Proceed? (yes/no)"

4. If confirmed:
   - Delete files
   - Update cache index
   - Show summary of deleted items
</WORKFLOW>

<EXAMPLES>
# Clear all cache
/codex:cache-clear --all

# Clear expired entries
/codex:cache-clear --expired

# Clear specific document
/codex:cache-clear @codex/auth-service/docs/oauth.md
</EXAMPLES>
```

### 6. Configuration

**File**: `.fractary/plugins/codex/config.json`

```json
{
  "version": "1.0",
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",
  "cache": {
    "enabled": true,
    "location": "codex",
    "ttl_days": 7,
    "max_size_mb": 500,
    "auto_cleanup": true
  },
  "default_source": "fractary-codex",
  "sources": [
    {
      "name": "fractary-codex",
      "type": "codex",
      "handler": "github",
      "handler_config": {
        "repo": "codex.fractary.com",
        "branch": "main",
        "base_path": "projects"
      },
      "cache": {
        "ttl_days": 7
      }
    }
  ]
}
```

---

## File Structure

### New Files (Phase 1)

```
plugins/codex/
├── skills/
│   └── document-fetcher/
│       ├── SKILL.md                      # Main skill definition
│       ├── workflow/
│       │   └── fetch-basic.md            # Basic fetch workflow
│       └── scripts/
│           ├── resolve-reference.sh      # Parse @codex/ reference
│           ├── cache-lookup.sh           # Check cache + TTL
│           ├── cache-store.sh            # Store + update index
│           └── github-fetch.sh           # Fetch from GitHub
├── commands/
│   ├── fetch.md                          # /codex:fetch command
│   ├── cache-list.md                     # /codex:cache-list command
│   └── cache-clear.md                    # /codex:cache-clear command
├── config/
│   └── codex.example.json                # Example configuration
└── docs/
    └── phase1-usage-guide.md             # User documentation
```

### Modified Files

```
plugins/codex/
├── .claude-plugin/plugin.json            # Add new commands
├── agents/codex-manager.md               # Add fetch operation
└── README.md                             # Update with new features
```

### Generated at Runtime

```
project/
├── codex/                                # Cache directory (gitignored)
│   ├── auth-service/
│   ├── shared-lib/
│   └── .cache-index.json
└── .gitignore                            # Add: codex/
```

---

## Implementation Tasks

### Task 1: Cache Infrastructure (2 days)

**Subtasks:**
1. Create `codex/` directory structure
2. Implement cache index schema
3. Write `cache-lookup.sh` script
4. Write `cache-store.sh` script
5. Add `codex/` to `.gitignore`

**Acceptance Criteria:**
- Cache index correctly stores metadata
- TTL calculation works correctly
- Cache lookup is < 10ms

### Task 2: Reference Resolution (1 day)

**Subtasks:**
1. Write `resolve-reference.sh` script
2. Add format validation
3. Test with various reference formats
4. Document reference syntax

**Acceptance Criteria:**
- All valid references parse correctly
- Invalid references return clear errors
- Resolution is < 5ms

### Task 3: GitHub Fetcher (2 days)

**Subtasks:**
1. Extract logic from existing sync scripts
2. Implement sparse checkout
3. Add error handling
4. Test with various projects/paths

**Acceptance Criteria:**
- Fetches documents from codex repo
- Uses sparse checkout (efficient)
- Handles missing documents gracefully

### Task 4: document-fetcher Skill (3 days)

**Subtasks:**
1. Create SKILL.md with proper XML structure
2. Write `fetch-basic.md` workflow
3. Integrate all scripts
4. Add comprehensive error handling
5. Test cache-first logic

**Acceptance Criteria:**
- Cache hit path works (< 100ms)
- Cache miss path works (< 2s)
- TTL enforcement works
- Error messages are clear

### Task 5: Commands (2 days)

**Subtasks:**
1. Create `/codex:fetch` command
2. Create `/codex:cache-list` command
3. Create `/codex:cache-clear` command
4. Test argument parsing
5. Test skill invocation

**Acceptance Criteria:**
- All commands parse arguments correctly
- Commands invoke skills properly
- Output is user-friendly

### Task 6: Configuration (1 day)

**Subtasks:**
1. Create configuration schema
2. Create example config
3. Add config validation
4. Document configuration options

**Acceptance Criteria:**
- Config validates against schema
- Example config works out-of-box
- Documentation is complete

### Task 7: Integration & Testing (2 days)

**Subtasks:**
1. End-to-end testing (fetch → cache → retrieve)
2. Performance testing (cache hit/miss times)
3. Error scenario testing
4. Integration with existing sync

**Acceptance Criteria:**
- All success criteria met
- Performance targets achieved
- No breaking changes to existing sync

### Task 8: Documentation (1 day)

**Subtasks:**
1. Write Phase 1 usage guide
2. Update README.md
3. Document migration path
4. Create examples

**Acceptance Criteria:**
- Users can follow guide successfully
- All features documented
- Migration path clear

---

## Testing & Validation

### Unit Tests

**resolve-reference.sh**:
```bash
# Valid references
test "@codex/auth-service/docs/oauth.md" → success
test "@codex/shared-lib/README.md" → success

# Invalid references
test "codex/project/path" → error
test "@codex/" → error
test "@codex" → error
```

**cache-lookup.sh**:
```bash
# Cache scenarios
test "cache hit, fresh" → {cached: true, fresh: true}
test "cache hit, expired" → {cached: true, fresh: false}
test "cache miss" → {cached: false}
test "index missing" → {cached: false}
```

**cache-store.sh**:
```bash
# Storage scenarios
test "store new entry" → index updated
test "update existing entry" → old entry replaced
test "calculate correct TTL" → expires_at correct
test "handle large files" → size_bytes accurate
```

### Integration Tests

**Fetch Flow (Cache Miss)**:
```
1. Reference: @codex/test-project/docs/api.md
2. Cache lookup → miss
3. Fetch from GitHub → success
4. Store in cache → success
5. Verify: file in codex/test-project/docs/api.md
6. Verify: entry in .cache-index.json
```

**Fetch Flow (Cache Hit)**:
```
1. Reference: @codex/test-project/docs/api.md (already cached)
2. Cache lookup → hit, fresh
3. Read from cache → success
4. Verify: last_accessed updated
5. Verify: no GitHub fetch occurred
```

**Fetch Flow (Expired Cache)**:
```
1. Reference: @codex/test-project/docs/api.md (cached, expired)
2. Cache lookup → hit, stale
3. Fetch from GitHub → success
4. Update cache → success
5. Verify: new cached_at timestamp
6. Verify: new expires_at timestamp
```

### Performance Tests

**Cache Hit Performance**:
```bash
# Run 100 cache hits
for i in {1..100}; do
  time /codex:fetch @codex/test-project/docs/api.md
done

# Expected: avg < 100ms, max < 200ms
```

**Cache Miss Performance**:
```bash
# Run 10 cache misses (clear cache between each)
for i in {1..10}; do
  /codex:cache-clear @codex/test-project/docs/api.md --yes
  time /codex:fetch @codex/test-project/docs/api.md
done

# Expected: avg < 2s, max < 5s
```

### User Acceptance Tests

**Scenario 1: First-time fetch**
```
Given: User has never fetched this document
When: User runs /codex:fetch @codex/auth-service/docs/oauth.md
Then: Document is fetched from GitHub
  And: Document is cached locally
  And: Content is displayed to user
  And: Cache status is shown (fresh fetch)
```

**Scenario 2: Subsequent fetch (cached)**
```
Given: User has previously fetched this document (< 7 days ago)
When: User runs /codex:fetch @codex/auth-service/docs/oauth.md
Then: Document is retrieved from cache
  And: Content is displayed to user
  And: Cache status is shown (from cache, expires in X days)
```

**Scenario 3: Force refresh**
```
Given: User wants latest version regardless of cache
When: User runs /codex:fetch @codex/auth-service/docs/oauth.md --force
Then: Cache is bypassed
  And: Document is fetched from GitHub
  And: Cache is updated
  And: Content is displayed to user
```

---

## Success Criteria

### Phase 1 Complete When:

✅ **Core Functionality**
- `@codex/` references resolve to `codex/` paths
- Cache-first retrieval works
- TTL enforcement works
- GitHub fetching works

✅ **Commands Work**
- `/codex:fetch` fetches and displays documents
- `/codex:cache-list` shows cached documents
- `/codex:cache-clear` removes cached documents

✅ **Performance**
- Cache hit: < 100ms
- Cache miss: < 2s
- Cache index operations: < 10ms

✅ **Quality**
- Error messages are clear
- Documentation is complete
- No breaking changes to existing sync

✅ **Integration**
- Works with existing codex configuration
- Doesn't conflict with SPEC-00012 sync
- fractary-repo plugin integration works

---

## Next Steps

**After Phase 1 completion:**
1. Review and approve [SPEC-00030-03](./SPEC-00030-03-phase2-multi-source.md) (Phase 2)
2. Gather user feedback on Phase 1
3. Optimize performance based on real-world usage
4. Begin Phase 2 implementation (Multi-Source & Permissions)

---

**Status:** Ready for implementation
**Document Version:** 1.0.0
**Last Updated:** 2025-01-15
