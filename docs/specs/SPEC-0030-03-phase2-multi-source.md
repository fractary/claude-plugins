# Phase 2: Multi-Source Support & Permissions

**Specification ID:** SPEC-0030-03
**Phase:** 2 of 4
**Parent Spec:** [SPEC-0030-01](./SPEC-0030-01-codex-knowledge-retrieval-architecture.md)
**Previous Phase:** [SPEC-0030-02](./SPEC-0030-02-phase1-local-cache.md)
**Version:** 1.0.0
**Status:** Planning
**Duration:** 2-3 weeks

---

## Table of Contents

1. [Phase Overview](#phase-overview)
2. [Goals & Objectives](#goals--objectives)
3. [Technical Implementation](#technical-implementation)
4. [Implementation Tasks](#implementation-tasks)
5. [Testing & Validation](#testing--validation)

---

## Phase Overview

### Purpose

Extend the knowledge retrieval system to support multiple sources (not just fractary-codex) and implement frontmatter-based permission control. This phase enables organizations to integrate external documentation sources while maintaining access control.

### Scope

**In Scope:**
- Multi-source configuration
- Handler abstraction layer
- Frontmatter permission parsing and enforcement
- External URL handler (handler-http)
- Source-specific TTL configuration
- `/codex:cache-prefetch` command (scan project for references)

**Out of Scope:**
- MCP integration (Phase 3)
- Context7 integration (Phase 3)
- Vector store support (Phase 3)

### Dependencies

- **Phase 1**: Local cache and reference system must be complete
- **fractary-file plugin**: For potential cloud storage handlers

---

## Goals & Objectives

### Primary Goals

1. ✅ **Multi-Source Support**: Handle multiple documentation sources
2. ✅ **Permission Control**: Enforce frontmatter-based access rules
3. ✅ **Handler Abstraction**: Pluggable source adapters
4. ✅ **External URLs**: Fetch from any HTTP/HTTPS URL

### Success Metrics

- Support 3+ simultaneous sources
- Permission check time: < 50ms
- External URL fetch time: < 3s
- Zero false positives/negatives in permission enforcement

---

## Technical Implementation

### 1. Multi-Source Configuration

**Enhanced Configuration**:
```json
{
  "version": "1.0",
  "organization": "fractary",
  "cache": {
    "enabled": true,
    "location": "codex",
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
        "branch": "main",
        "base_path": "projects"
      },
      "cache": {
        "ttl_days": 7
      },
      "permissions": {
        "enabled": true,
        "default": "check_frontmatter"
      }
    },
    {
      "name": "aws-docs",
      "type": "external-url",
      "handler": "http",
      "url_pattern": "https://docs.aws.amazon.com/**",
      "cache": {
        "ttl_days": 60
      },
      "permissions": {
        "enabled": false
      }
    },
    {
      "name": "company-wiki",
      "type": "external-url",
      "handler": "http",
      "url_pattern": "https://wiki.company.com/**",
      "cache": {
        "ttl_days": 14
      },
      "permissions": {
        "enabled": false
      }
    }
  ]
}
```

### 2. Handler Abstraction

**Handler Interface** (conceptual, implemented in skills):

```markdown
## Handler Contract

All handlers must implement these operations:

### Operation: fetch
**Input**:
- source_config: Source configuration object
- reference: @codex/ or URL reference
- requesting_project: Current project name

**Output**:
- content: Document content
- metadata: {
    frontmatter: Parsed frontmatter (if exists)
    last_modified: Timestamp
    content_type: MIME type
  }

### Operation: validate-access (optional)
**Input**:
- frontmatter: Parsed frontmatter
- requesting_project: Current project name

**Output**:
- allowed: boolean
- reason: String (if denied)
```

**Handler Skills**:

```
skills/
├── handler-github/           # Phase 1 (existing)
│   └── SKILL.md
├── handler-http/             # Phase 2 (new)
│   ├── SKILL.md
│   └── scripts/
│       ├── fetch-url.sh
│       └── parse-metadata.sh
└── handler-s3/               # Future
    └── SKILL.md
```

### 3. Frontmatter Permission System

**Permission Frontmatter Format**:
```yaml
---
codex_sync_include:
  - project-a              # Explicit project
  - project-b
  - shared/team-backend    # Pattern (directory)
  - *-service              # Wildcard pattern
  - "*"                    # Public (all projects)
codex_sync_exclude:
  - project-sensitive      # Explicit exclusion
  - temp-*                 # Pattern exclusion
---
```

**Permission Rules**:
1. If `codex_sync_include` missing → **default: public** (allow all)
2. If `codex_sync_include: ["*"]` → **public** (allow all)
3. If project matches `codex_sync_include` → **check exclude list**
4. If project matches `codex_sync_exclude` → **deny**
5. If project in include and not in exclude → **allow**
6. Otherwise → **deny**

**Pattern Matching**:
- `*`: Matches any characters
- `project-*`: Matches "project-foo", "project-bar"
- `*-service`: Matches "auth-service", "user-service"
- `shared/team-*`: Matches "shared/team-backend", "shared/team-frontend"

### 4. Enhanced document-fetcher Skill

**New Workflow**: `workflow/fetch-with-permissions.md`

```markdown
<WORKFLOW>

## Step 1: Parse Reference and Determine Source

USE SCRIPT: ./scripts/resolve-reference.sh
Arguments: {reference}

Output: {cachePath, relativePath, project}

Load configuration: .fractary/plugins/codex/config.json

Determine source:
  - If reference starts with @codex/ → Look up in sources
  - If reference is URL → Match against url_pattern in sources
  - Default to first source if no match

## Step 2: Check Cache (unchanged from Phase 1)

[Same as Phase 1]

## Step 3: Fetch from Source

USE SKILL: handler-{source.handler}
Operation: fetch
Arguments: {
  source_config: source configuration
  reference: reference string
  requesting_project: current_project_name
}

Output: {content, metadata}

## Step 4: Check Permissions (NEW)

IF source.permissions.enabled == true:
  IF metadata.frontmatter exists:
    USE SCRIPT: ./scripts/check-permissions.sh
    Arguments: {
      frontmatter: metadata.frontmatter
      requesting_project: current_project_name
    }

    Output: {allowed: boolean, reason: string}

    IF allowed == false:
      RETURN ERROR: "Access denied: {reason}"
      DO NOT CACHE
      STOP

## Step 5: Store in Cache

USE SCRIPT: ./scripts/cache-store.sh
Arguments: {
  reference,
  cachePath,
  content,
  ttl_days: source.cache.ttl_days
}

## Step 6: Return Content

Return: {
  content,
  cached: true/false,
  source: source.name,
  permissions_checked: boolean
}

</WORKFLOW>
```

### 5. Permission Check Script

**Script**: `scripts/check-permissions.sh`

```bash
#!/usr/bin/env bash
# Check if requesting project has permission to access document

set -euo pipefail

frontmatter_json="$1"      # Frontmatter as JSON
requesting_project="$2"     # Current project name

# Extract permission arrays
include_json=$(echo "$frontmatter_json" | jq -r '.codex_sync_include // ["*"]')
exclude_json=$(echo "$frontmatter_json" | jq -r '.codex_sync_exclude // []')

# If include is ["*"], allow (public)
if echo "$include_json" | jq -e '. == ["*"]' > /dev/null; then
  echo '{"allowed": true, "reason": "public"}'
  exit 0
fi

# Check exclude list first
for pattern in $(echo "$exclude_json" | jq -r '.[]'); do
  if match_pattern "$requesting_project" "$pattern"; then
    echo "{\"allowed\": false, \"reason\": \"Excluded by pattern: $pattern\"}"
    exit 0
  fi
done

# Check include list
for pattern in $(echo "$include_json" | jq -r '.[]'); do
  if match_pattern "$requesting_project" "$pattern"; then
    echo '{"allowed": true, "reason": "matched_pattern"}'
    exit 0
  fi
done

# Not in include list
echo '{"allowed": false, "reason": "Not in codex_sync_include list"}'

# Pattern matching function
match_pattern() {
  local value="$1"
  local pattern="$2"

  # Convert glob pattern to regex
  regex=$(echo "$pattern" | sed 's/\*/.\*/g')

  if [[ "$value" =~ ^${regex}$ ]]; then
    return 0  # Match
  else
    return 1  # No match
  fi
}
```

### 6. handler-http Skill

**File**: `skills/handler-http/SKILL.md`

```markdown
---
name: handler-http
description: |
  HTTP/HTTPS URL handler for external documentation fetching
tools: Bash
---

<CONTEXT>
You are the HTTP handler for external URL documentation fetching.
Your responsibility is to fetch content from HTTP/HTTPS URLs with caching and metadata extraction.
</CONTEXT>

<CRITICAL_RULES>
**URL Validation:**
- ONLY allow http:// and https:// protocols
- NEVER execute arbitrary protocols (file://, ftp://, etc.)
- ALWAYS validate URL format
- TIMEOUT after 30 seconds

**Content Safety:**
- Set reasonable size limits (10MB default)
- Handle redirects (max 5 redirects)
- Validate content types
- Log all fetches

**Error Handling:**
- Clear error messages
- Retry with exponential backoff (3 attempts)
- Cache 404s temporarily (1 hour) to avoid repeated failures
</CRITICAL_RULES>

<INPUTS>
- source_config: Source configuration
- reference: URL or @codex/external/{source}/{path}
- requesting_project: Current project name
</INPUTS>

<WORKFLOW>

## Step 1: Resolve URL

IF reference starts with @codex/external/:
  Extract URL from cache path
  e.g., @codex/external/aws-docs/s3/api.html
    → Look up aws-docs source
    → Construct URL from url_pattern
ELSE:
  Use reference as direct URL

## Step 2: Fetch Content

USE SCRIPT: ./scripts/fetch-url.sh
Arguments: {
  url: resolved URL
  timeout: 30
  max_size: 10MB
  follow_redirects: true
}

Output: {
  content: HTML/Markdown/Text
  status_code: HTTP status
  content_type: MIME type
  final_url: After redirects
}

## Step 3: Extract Metadata

USE SCRIPT: ./scripts/parse-metadata.sh
Arguments: {content, content_type, url}

Output: {
  frontmatter: Parsed (if markdown with frontmatter)
  title: Extracted from HTML/markdown
  last_modified: From headers or meta tags
}

## Step 4: Return

Return: {
  content,
  metadata
}

</WORKFLOW>

<COMPLETION_CRITERIA>
- ✅ Content fetched successfully
- ✅ Metadata extracted
- ✅ All errors logged
</COMPLETION_CRITERIA>

<ERROR_HANDLING>
  <HTTP_ERROR>
  If HTTP status >= 400:
  - 404: Return clear "Not found" error
  - 403: Return "Access denied" error
  - 500: Retry with backoff
  - Other: Return descriptive error
  </HTTP_ERROR>

  <TIMEOUT>
  If fetch times out:
  - Return error with timeout duration
  - Suggest checking URL or network
  </TIMEOUT>

  <SIZE_LIMIT>
  If content too large:
  - Return error with size limit
  - Suggest downloading manually
  </SIZE_LIMIT>
</ERROR_HANDLING>
```

**Script**: `scripts/fetch-url.sh`

```bash
#!/usr/bin/env bash
# Fetch content from HTTP/HTTPS URL

set -euo pipefail

url="$1"
timeout="${2:-30}"
max_size="${3:-10485760}"  # 10MB default

# Validate protocol
if [[ ! "$url" =~ ^https?:// ]]; then
  echo "ERROR: Invalid protocol. Only http:// and https:// allowed" >&2
  exit 1
fi

# Fetch with curl
response=$(curl -L \
  --max-time "$timeout" \
  --max-filesize "$max_size" \
  --max-redirs 5 \
  --write-out "\n%{http_code}\n%{content_type}\n%{url_effective}" \
  --silent \
  --show-error \
  "$url")

# Parse response
content=$(echo "$response" | head -n -3)
status_code=$(echo "$response" | tail -n 3 | head -n 1)
content_type=$(echo "$response" | tail -n 2 | head -n 1)
final_url=$(echo "$response" | tail -n 1)

# Check status
if [[ "$status_code" -ge 400 ]]; then
  echo "ERROR: HTTP $status_code from $url" >&2
  exit 1
fi

# Output JSON
jq -n \
  --arg content "$content" \
  --argjson status "$status_code" \
  --arg type "$content_type" \
  --arg final "$final_url" \
  '{
    content: $content,
    status_code: $status,
    content_type: $type,
    final_url: $final
  }'
```

### 7. cache-prefetch Command

**File**: `commands/cache-prefetch.md`

```markdown
---
name: fractary-codex:cache-prefetch
description: Scan project for @codex/ references and pre-fetch them
argument-hint: [--path <dir>] [--dry-run]
---

<CONTEXT>
You are the cache-prefetch command router.
Your role is to scan the project for @codex/ references and pre-fetch all discovered documents.
</CONTEXT>

<CRITICAL_RULES>
**Scanning:**
- ONLY scan docs/, specs/, logs/, README.md by default
- RESPECT .gitignore patterns
- NEVER scan node_modules/, .git/, etc.

**Fetching:**
- Fetch in parallel (max 10 concurrent)
- Continue on individual failures
- Report summary at end
</CRITICAL_RULES>

<WORKFLOW>

## Step 1: Scan for References

USE SCRIPT: ./scripts/scan-references.sh
Arguments: {
  path: specified path or default (docs/, specs/, etc.)
  patterns: ["@codex/**"]
}

Output: List of unique @codex/ references

## Step 2: Show Plan

Display to user:
- Count of references found
- Estimated size (if known from index)
- Ask for confirmation (unless --dry-run)

## Step 3: Fetch All References

IF confirmed:
  FOR EACH reference (parallel, max 10):
    USE SKILL: fractary-codex:document-fetcher
    Operation: fetch
    Arguments: {reference, force_refresh: false}

    Track: success, failure, already_cached

## Step 4: Report Summary

Display:
- Total references: N
- Fetched: X (newly cached)
- Already cached: Y
- Failed: Z (with reasons)
- Total cache size: XMB

</WORKFLOW>

<EXAMPLES>
# Scan and pre-fetch all references
/codex:cache-prefetch

# Scan specific directory
/codex:cache-prefetch --path docs/

# Dry-run (show what would be fetched)
/codex:cache-prefetch --dry-run
</EXAMPLES>
```

**Script**: `scripts/scan-references.sh`

```bash
#!/usr/bin/env bash
# Scan project for @codex/ references

set -euo pipefail

scan_path="${1:-.}"
pattern="@codex/[a-zA-Z0-9/_-]+"

# Default paths to scan
if [[ "$scan_path" == "." ]]; then
  paths=("docs/" "specs/" "logs/" "README.md" "CLAUDE.md")
else
  paths=("$scan_path")
fi

# Scan for references
references=()
for path in "${paths[@]}"; do
  if [[ -e "$path" ]]; then
    while IFS= read -r ref; do
      references+=("$ref")
    done < <(grep -rhoE "$pattern" "$path" 2>/dev/null || true)
  fi
done

# Deduplicate and sort
unique_refs=$(printf '%s\n' "${references[@]}" | sort -u)

# Output JSON array
jq -R -s 'split("\n") | map(select(. != ""))' <<< "$unique_refs"
```

---

## Implementation Tasks

### Task 1: Multi-Source Configuration (2 days)

**Subtasks:**
1. Extend configuration schema
2. Add source validation
3. Implement source selection logic
4. Test with multiple sources

**Acceptance Criteria:**
- Configuration validates correctly
- Source selection works
- TTL per-source works

### Task 2: Handler Abstraction (2 days)

**Subtasks:**
1. Define handler interface contract
2. Refactor existing handler-github to match contract
3. Document handler requirements
4. Create handler template

**Acceptance Criteria:**
- Handler interface is clear
- Existing handler refactored
- Documentation complete

### Task 3: Permission System (3 days)

**Subtasks:**
1. Write `check-permissions.sh` script
2. Implement pattern matching
3. Add to document-fetcher workflow
4. Test all permission scenarios

**Acceptance Criteria:**
- All permission rules enforced correctly
- Pattern matching works (wildcards, etc.)
- Clear error messages for denied access

### Task 4: handler-http Implementation (3 days)

**Subtasks:**
1. Create SKILL.md
2. Write `fetch-url.sh` script
3. Write `parse-metadata.sh` script
4. Add error handling
5. Test with various URLs

**Acceptance Criteria:**
- Fetches HTTP/HTTPS URLs
- Handles redirects
- Extracts metadata
- Error handling works

### Task 5: cache-prefetch Command (2 days)

**Subtasks:**
1. Write `scan-references.sh` script
2. Create command router
3. Implement parallel fetching
4. Add progress reporting

**Acceptance Criteria:**
- Scans project correctly
- Finds all references
- Pre-fetches in parallel
- Reports summary

### Task 6: Integration Testing (2 days)

**Subtasks:**
1. Test multi-source scenarios
2. Test permission enforcement
3. Test external URL fetching
4. Test prefetch command

**Acceptance Criteria:**
- All sources work simultaneously
- Permissions enforced correctly
- External URLs fetch successfully
- Prefetch works end-to-end

### Task 7: Documentation (1 day)

**Subtasks:**
1. Document multi-source configuration
2. Document permission system
3. Document handler interface
4. Update usage guide

**Acceptance Criteria:**
- All features documented
- Examples provided
- Migration guide updated

---

## Testing & Validation

### Permission Test Matrix

| Frontmatter | Requesting Project | Expected |
|-------------|-------------------|----------|
| `include: ["*"]` | any-project | ✅ Allow |
| `include: ["project-a"]` | project-a | ✅ Allow |
| `include: ["project-a"]` | project-b | ❌ Deny |
| `include: ["*-service"]` | auth-service | ✅ Allow |
| `include: ["*-service"]` | web-app | ❌ Deny |
| `include: ["*"], exclude: ["temp-*"]` | temp-project | ❌ Deny |
| `include: ["*"], exclude: ["temp-*"]` | prod-project | ✅ Allow |
| (missing) | any-project | ✅ Allow (public default) |

### Multi-Source Test Scenarios

**Scenario 1: Fractary Codex (with permissions)**
```
Reference: @codex/auth-service/docs/api.md
Source: fractary-codex (GitHub)
Permissions: Enabled
Frontmatter: include: ["project-a"]
Requesting: project-a
Expected: ✅ Allow, cache, serve
```

**Scenario 2: External URL (no permissions)**
```
Reference: https://docs.aws.amazon.com/s3/api.html
Source: aws-docs (HTTP)
Permissions: Disabled
Expected: ✅ Fetch, cache, serve (no permission check)
```

**Scenario 3: Multiple Sources Simultaneously**
```
1. Fetch @codex/auth-service/docs/api.md (fractary-codex)
2. Fetch https://docs.aws.amazon.com/s3/api.html (aws-docs)
3. Verify both cached with different TTLs
4. Verify both accessible
```

### Prefetch Test

**Scenario: Project with 50 references**
```
Given: Project has 50 @codex/ references across docs/
When: User runs /codex:cache-prefetch
Then: All 50 references scanned
  And: Pre-fetch plan shown to user
  And: User confirms
  And: All 50 fetched (max 10 parallel)
  And: Summary shown (fetched, cached, failed)
  And: Total time < 60s
```

---

## Success Criteria

### Phase 2 Complete When:

✅ **Multi-Source Support**
- 3+ sources configured simultaneously
- Each source uses correct handler
- Source-specific TTLs work

✅ **Permission System**
- Frontmatter parsing works
- All permission rules enforced
- Pattern matching works correctly
- Denied access has clear errors

✅ **External URLs**
- HTTP/HTTPS URLs fetch successfully
- Metadata extracted
- Caching works with appropriate TTL

✅ **Prefetch**
- Scans project for references
- Pre-fetches all found references
- Reports accurate summary

✅ **Quality**
- No false positives/negatives in permissions
- External fetch time < 3s
- Documentation complete

---

## Next Steps

**After Phase 2 completion:**
1. Review and approve [SPEC-0030-04](./SPEC-0030-04-phase3-mcp-integration.md) (Phase 3)
2. Gather feedback on multi-source usage
3. Optimize permission checking performance
4. Begin Phase 3 implementation (MCP & Context7)

---

**Status:** Ready for implementation after Phase 1
**Document Version:** 1.0.0
**Last Updated:** 2025-01-15
