# Fetch Workflow with Multi-Source and Permissions (Phase 2)

This workflow extends the basic fetch with source routing and permission checking.

## Step 1: Parse Reference and Route to Source

USE SCRIPT: ./scripts/resolve-reference.sh
Arguments: {reference}

OUTPUT: {cache_path, relative_path, project, path}

IF parsing fails:
  - Return error with format explanation
  - STOP

USE SCRIPT: ./scripts/route-source.sh
Arguments: {reference, config_file}

OUTPUT: {source, handler, reference_type, project}

IF routing fails:
  - Return error (no source configured)
  - Suggest configuration steps
  - STOP

Extract from routing result:
- source_name: source.name
- handler_type: handler
- ttl_days: source.cache.ttl_days
- permissions_enabled: source.permissions.enabled
- permissions_default: source.permissions.default

## Step 2: Check Cache (unchanged from Phase 1)

USE SCRIPT: ./scripts/cache-lookup.sh
Arguments: {cache_path}

OUTPUT: {cached, fresh, reason, cached_at, expires_at, source, size_bytes}

IF cached AND fresh:
  - Update last_accessed timestamp in cache index
  - Read content from cache_path
  - RETURN: Content with metadata
  - STOP (cache hit - fast path ✅)

## Step 3: Fetch from Source via Handler

Route to appropriate handler based on handler_type:

IF handler_type == "github":
  USE SCRIPT: ./scripts/github-fetch.sh
  Arguments: {
    project: project from reference
    path: path from reference
    codex_repo: source.handler_config.repo
    org: source.handler_config.org
    branch: source.handler_config.branch || "main"
    base_path: source.handler_config.base_path || "projects"
  }

  OUTPUT: Content to stdout

  # Parse frontmatter if needed
  IF permissions_enabled:
    USE SCRIPT: ./scripts/parse-frontmatter.sh
    Arguments: {content via stdin}
    OUTPUT: frontmatter JSON

ELSE IF handler_type == "http":
  USE SKILL: handler-http
  Operation: fetch
  Arguments: {
    source_config: source
    reference: reference
    requesting_project: current_project_name
  }

  OUTPUT: {content, metadata}

  Extract:
  - content: from response
  - frontmatter: from metadata.frontmatter

ELSE:
  ERROR: "Unknown handler type: {handler_type}"
  STOP

IF fetch fails:
  - Return error from handler
  - Log failure
  - STOP

## Step 4: Check Permissions (NEW in Phase 2)

IF permissions_enabled == true:
  IF frontmatter exists AND has codex_sync fields:
    # Determine requesting project
    requesting_project = get_current_project_name() || "unknown"

    USE SCRIPT: ./scripts/check-permissions.sh
    Arguments: {
      frontmatter: frontmatter as JSON
      requesting_project: requesting_project
    }

    OUTPUT: {allowed, reason, matched_pattern}

    IF allowed == false:
      ERROR: "Access denied: {reason}"
      LOG: Permission denial for audit
      DO NOT CACHE (important!)
      STOP

  ELSE IF permissions_default == "deny":
    ERROR: "Access denied: No frontmatter permissions and default is deny"
    STOP

  ELSE IF permissions_default == "check_frontmatter":
    # No frontmatter found - treat as public
    # Continue with caching

  # permissions_default == "allow" - continue

## Step 5: Store in Cache

USE SCRIPT: ./scripts/cache-store.sh
Arguments: {
  reference: reference
  cache_path: cache_path from Step 1
  content: content from Step 3 (via stdin)
  ttl_days: ttl_days from source config
}

OUTPUT: {success, cache_path, size_bytes, cached_at, expires_at}

IF storage fails:
  - Log warning
  - Continue anyway (content was fetched successfully)

## Step 6: Return Content

Return structured response:
```json
{
  "success": true,
  "content": "<document content>",
  "metadata": {
    "cached": true,
    "source": "<source_name>",
    "handler": "<handler_type>",
    "size_bytes": <number>,
    "cached_at": "<ISO 8601>",
    "expires_at": "<ISO 8601>",
    "permissions_checked": <boolean>,
    "frontmatter": {...}
  }
}
```

## Completion

Operation complete when:
- ✅ Content retrieved and returned
- ✅ Permissions verified (if enabled)
- ✅ Content cached (if allowed)
- ✅ Metadata complete
- ✅ All errors logged

## Error Handling Notes

**Permission Denials:**
- Must NOT cache denied content
- Must log denial for audit
- Should suggest checking frontmatter permissions

**Missing Sources:**
- Clear error about configuration
- Suggest running /fractary-codex:init
- List available sources if any

**Handler Failures:**
- Pass through handler's error message
- Include source name for context
- Suggest checking handler configuration

## Performance Targets

- Cache hit (Step 2): < 100ms ✅
- Permission check (Step 4): < 50ms
- Total (cache miss): < 3s (was < 2s in Phase 1, now includes permission check)
