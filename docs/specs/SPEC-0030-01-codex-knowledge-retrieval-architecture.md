# Codex Knowledge Retrieval Architecture

**Specification ID:** SPEC-0030-01
**Version:** 1.0.0
**Status:** Planning
**Created:** 2025-01-15
**Author:** System Architecture
**Related Specs:** SPEC-0012 (Codex Sync), SPEC-0029-04 (Docs Plugin)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Architecture Vision](#architecture-vision)
4. [Core Design Principles](#core-design-principles)
5. [System Architecture](#system-architecture)
6. [Implementation Phases](#implementation-phases)
7. [Success Criteria](#success-criteria)
8. [Migration Strategy](#migration-strategy)

---

## Executive Summary

### Purpose

Transform the Codex plugin from a **push-based synchronization system** to a **pull-based knowledge retrieval system** with intelligent caching, multi-source support, and MCP integration. This evolution addresses the core problem of making institutional knowledge accessible across time and projects without local file clutter.

### Key Innovation

**Cache-as-gateway pattern**: All knowledge access flows through an ephemeral local cache (`codex/`) that uses frontmatter-based permissions for access control. References in documentation (`@codex/project/path`) map directly to cache paths for perfect alignment and fast resolution.

### Strategic Value

1. **Universal Access**: One system for Fractary docs, Context7 technical docs, and external knowledge bases
2. **Always Fresh**: TTL-based caching ensures up-to-date information
3. **Offline Capable**: Pre-fetch critical docs for offline access
4. **Scalable**: O(n) instead of O(n²) as organization grows
5. **Future-Proof**: MCP-ready architecture supports vector stores and semantic search

---

## Problem Statement

### Current State (SPEC-0012)

**Push-Based Sync Model:**
```
Codex Repo → Sync to ALL projects → Local copies everywhere
```

**Problems:**
1. **Stale data**: Local copies become outdated
2. **Clutter**: Every project has copies of all other projects' docs
3. **Inconsistency**: References break when docs move between projects
4. **Scalability**: O(n²) sync relationships (100 projects = 9,900 syncs)
5. **Complexity**: Bidirectional sync with conflict resolution

### Desired State

**Pull-Based Retrieval Model:**
```
Project needs info → Request to Codex → Retrieve on-demand → Cache locally (ephemeral)
```

**Benefits:**
1. **Always fresh**: Cache with TTL, always up-to-date
2. **No clutter**: Only cache what's needed, gitignored
3. **Consistency**: Universal reference syntax
4. **Scalability**: O(n) - each project publishes once
5. **Simplicity**: No bidirectional sync complexity

---

## Architecture Vision

### The Knowledge Triangle

```
┌─────────────────────────────────────────────┐
│  AGGREGATION                                │
│  (Project → Codex)                          │
│                                             │
│  Projects publish docs to central storage  │
│  - /docs → codex/projects/{name}/docs      │
│  - Frontmatter controls permissions        │
│  - One-way, simple, reliable               │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  CENTRAL STORAGE                            │
│  (Single source of truth)                   │
│                                             │
│  - GitHub repo (codex.fractary.com)        │
│  - S3/R2 buckets (scalable storage)        │
│  - Vector store (semantic search)          │
│  - MCP servers (dynamic sources)           │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  RETRIEVAL                                  │
│  (Codex → Projects on-demand)               │
│                                             │
│  Projects fetch docs as needed              │
│  - @codex/project/path references          │
│  - Cache-first retrieval (fast)            │
│  - Permission-gated via frontmatter        │
│  - TTL-based freshness                     │
└─────────────────────────────────────────────┘
```

### Perfect Alignment Pattern

**The key insight**: Reference syntax maps directly to cache file paths

```
Reference in docs:  @codex/auth-service/docs/oauth.md
                      ↓ (strip @)
Cache file path:    codex/auth-service/docs/oauth.md
                      ↓ (MCP URI)
MCP resource:       codex://auth-service/docs/oauth.md
```

**Resolution is trivial**: `reference.replace(/^@/, '')`

**Benefits:**
- ✅ No translation layer
- ✅ Direct filesystem lookup
- ✅ Universal across all contexts
- ✅ Works with standard tools (grep, find, IDE)

---

## Core Design Principles

### 1. Cache-as-Gateway

**All access goes through local cache:**
```
Request → Check cache → Return if fresh → Fetch if miss → Cache → Return
```

**Cache enforces permissions:**
- Check frontmatter `codex_sync_include` before caching
- Only authorized docs make it to local cache
- Cache is the security boundary

### 2. Source Abstraction

**Multiple sources, single interface:**
```
Sources (What)          Handlers (How)           Access (When)
─────────────────────────────────────────────────────────────
fractary-codex    →     handler-github      →    On-demand fetch
context7          →     handler-mcp         →    Tool-based access
aws-docs          →     handler-http        →    URL fetch
vector-db         →     handler-vector      →    Semantic search
```

**Configuration determines routing:**
```json
{
  "sources": [
    {"name": "fractary-codex", "handler": "github"},
    {"name": "context7", "handler": "mcp-remote"}
  ]
}
```

### 3. Ephemeral Cache

**Cache is gitignored and regeneratable:**
```
codex/               # Gitignored (like node_modules)
├── auth-service/    # Cached from fractary-codex
├── shared-lib/      # Cached from fractary-codex
└── external/
    └── context7/    # Cached from Context7 MCP
```

**Characteristics:**
- Not committed to git
- Regeneratable from sources
- TTL-based expiration
- Pre-fetch on startup (optional)
- Manual refresh available

### 4. Frontmatter Permissions

**Documents declare who can access them:**
```yaml
---
codex_sync_include:
  - project-a        # Explicit project
  - shared/team-*    # Pattern matching
  - "*"              # Public (all projects)
codex_sync_exclude:
  - project-sensitive
---
```

**Enforcement at fetch time:**
1. Request for `@codex/auth-service/docs/oauth.md`
2. Fetch from source (GitHub/MCP/etc)
3. Parse frontmatter
4. Check if requesting project is in `codex_sync_include`
5. If yes: cache and serve
6. If no: error (unauthorized)

### 5. Hybrid Context7 Integration

**Use Context7 natively, cache optionally:**
```
Primary: Claude uses Context7 MCP tools directly
  ↓
Optional: Codex observes and caches responses
  ↓
Future: Reference cached docs via @codex/external/context7/...
```

**Benefits:**
- Full Context7 features (native)
- Performance boost (caching)
- Offline access (cached responses)
- Unified reference syntax (optional)

---

## System Architecture

### Component Diagram

```
┌──────────────────────────────────────────────────────────┐
│  USER LAYER                                              │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Documentation with @codex/ references              │  │
│  │ Commands: /codex:fetch, /codex:cache-refresh       │  │
│  │ Skills invoked by agents during workflows          │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│  CODEX PLUGIN LAYER                                      │
│  ┌────────────────────────────────────────────────────┐  │
│  │ codex-manager agent                                │  │
│  │  - Routes operations to skills                     │  │
│  │  - Handles configuration                           │  │
│  └────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐  │
│  │ document-fetcher skill                             │  │
│  │  - Reference resolution                            │  │
│  │  - Cache management                                │  │
│  │  - Permission checking                             │  │
│  │  - Handler selection                               │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│  CACHE LAYER                                             │
│  ┌────────────────────────────────────────────────────┐  │
│  │ codex/ (ephemeral, gitignored)                     │  │
│  │  ├── auth-service/                                 │  │
│  │  ├── shared-lib/                                   │  │
│  │  ├── external/context7/                            │  │
│  │  └── .cache-index.json (TTL metadata)             │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│  HANDLER LAYER                                           │
│  ┌───────────────┬──────────────┬──────────────────────┐ │
│  │handler-github │handler-mcp   │handler-http          │ │
│  │(Git repos)    │(MCP servers) │(Direct URLs)         │ │
│  └───────────────┴──────────────┴──────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│  SOURCE LAYER                                            │
│  ┌───────────────┬──────────────┬──────────────────────┐ │
│  │fractary-codex │Context7 MCP  │External URLs         │ │
│  │(GitHub)       │(33K+ libs)   │(AWS, docs, etc)      │ │
│  └───────────────┴──────────────┴──────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

### Data Flow

**Scenario 1: First Access (Cache Miss)**
```
1. User writes: @codex/auth-service/docs/oauth.md
2. Agent invokes: document-fetcher skill
3. Skill checks: codex/auth-service/docs/oauth.md
4. Cache miss → Load source config (handler=github)
5. Invoke handler-github
6. Fetch from: codex.fractary.com/projects/auth-service/docs/oauth.md
7. Parse frontmatter permissions
8. Check: Is requesting project authorized?
9. If yes: Cache at codex/auth-service/docs/oauth.md
10. Update: codex/.cache-index.json with TTL
11. Return: Content to agent
```

**Scenario 2: Subsequent Access (Cache Hit)**
```
1. User writes: @codex/auth-service/docs/oauth.md
2. Agent invokes: document-fetcher skill
3. Skill checks: codex/auth-service/docs/oauth.md
4. Cache hit → Check TTL in .cache-index.json
5. If fresh: Return cached content (FAST)
6. If stale: Refresh from source (same as cache miss)
```

**Scenario 3: Context7 Access**
```
1. Claude uses: get-library-docs tool (Context7 MCP)
2. Context7 returns: React hooks documentation
3. If cache_external_mcp enabled:
   a. Codex observes response
   b. Cache at: codex/external/context7/react/hooks.md
   c. Update index with TTL
4. Future references: @codex/external/context7/react/hooks (cached)
```

### Directory Structure

```
project/
├── docs/                    # Project docs (committed)
│   ├── architecture/
│   └── api/
├── specs/                   # Specifications (ephemeral → archived)
├── logs/                    # Operation logs (hybrid retention)
├── codex/                   # KNOWLEDGE CACHE (gitignored)
│   ├── auth-service/        # Fractary projects
│   │   └── docs/
│   │       └── oauth.md
│   ├── shared-lib/
│   │   └── README.md
│   ├── external/            # External sources
│   │   └── context7/
│   │       ├── react/
│   │       │   └── hooks.md
│   │       └── aws-sdk-js-v3/
│   │           └── s3.md
│   └── .cache-index.json    # TTL metadata
├── .fractary/               # Fractary infrastructure (committed)
│   ├── plugins/
│   │   ├── codex/config.json
│   │   ├── docs/config.json
│   │   └── work/config.json
│   └── registry/
│       └── artifacts.json
└── .gitignore
```

**.gitignore:**
```
codex/                       # All cached knowledge (ephemeral)
```

---

## Implementation Phases

### Phase 1: Local Cache & Reference System
**Goal:** Establish foundation with local cache and @codex/ references
**Details:** See [SPEC-0030-02](./SPEC-0030-02-phase1-local-cache.md)

**Key Deliverables:**
- `codex/` directory structure
- `document-fetcher` skill
- `@codex/` reference resolution
- Cache index with TTL
- GitHub handler (reuse existing sync)

**Duration:** 2-3 weeks

---

### Phase 2: Multi-Source & Permissions
**Goal:** Support multiple sources with frontmatter permissions
**Details:** See [SPEC-0030-03](./SPEC-0030-03-phase2-multi-source.md)

**Key Deliverables:**
- Source configuration system
- Handler abstraction
- Frontmatter permission enforcement
- External URL support (handler-http)
- Cache management commands

**Duration:** 2-3 weeks

---

### Phase 3: MCP Integration & Context7
**Goal:** Dual-mode access (local + MCP) with Context7 integration
**Details:** See [SPEC-0030-04](./SPEC-0030-04-phase3-mcp-integration.md)

**Key Deliverables:**
- MCP server for Codex
- Context7 hybrid caching
- MCP response observer
- Resource protocol support
- Subscription model for updates

**Duration:** 3-4 weeks

---

### Phase 4: Migration & Optimization
**Goal:** Migrate from push-sync (SPEC-0012) to pull-retrieval
**Details:** See [SPEC-0030-05](./SPEC-0030-05-phase4-migration.md)

**Key Deliverables:**
- Migration guide
- Backward compatibility
- Performance optimization
- Documentation updates
- Deprecation timeline

**Duration:** 2-3 weeks

---

## Success Criteria

### Functional Requirements

✅ **Reference Resolution**
- `@codex/project/path` maps directly to `codex/project/path`
- Works in all contexts (docs, specs, logs, code comments)
- Claude Code skill can fetch and return content
- Resolution time < 100ms for cache hits

✅ **Caching**
- Cache-first retrieval (check local before remote)
- TTL-based expiration (configurable per source)
- Pre-fetch capability (scan project for references)
- Manual refresh commands
- Automatic cache cleanup (expired entries)

✅ **Permissions**
- Frontmatter `codex_sync_include` enforced
- Unauthorized requests denied with clear error
- Pattern matching works (wildcards, negation)
- Default behavior (missing frontmatter = public)

✅ **Multi-Source**
- GitHub repos (fractary-codex)
- Context7 MCP (33K+ libraries)
- External URLs (AWS docs, etc)
- Consistent interface across all sources

✅ **Context7 Integration**
- Native MCP usage works
- Optional response caching
- Cache-first retrieval for cached items
- Offline access to cached docs

### Performance Requirements

✅ **Speed**
- Cache hit: < 100ms
- Cache miss + GitHub fetch: < 2s
- Cache miss + MCP fetch: < 3s
- Pre-fetch (100 docs): < 30s

✅ **Scalability**
- Handles 1000+ cached documents
- Cache size limit configurable (default: 500MB)
- Automatic LRU eviction if limit exceeded
- Parallel fetch support (up to 10 concurrent)

### Quality Requirements

✅ **Reliability**
- Graceful degradation (offline mode uses cache)
- Error messages are clear and actionable
- Failed fetches don't break workflows
- Retry logic for transient failures

✅ **Maintainability**
- Clear separation of concerns
- Handler abstraction for extensibility
- Well-documented configuration
- Comprehensive error handling

✅ **Usability**
- Simple reference syntax (`@codex/...`)
- Intuitive commands (`/codex:cache-refresh`)
- Automatic permission errors are self-explanatory
- Good documentation and examples

---

## Migration Strategy

### From SPEC-0012 (Push-Sync) to SPEC-0030 (Pull-Retrieval)

**Coexistence Period:**
- Both systems run in parallel (6 months)
- SPEC-0012 continues to sync (publish to codex)
- SPEC-0030 retrieves (fetch from codex)
- Projects opt-in to retrieval when ready

**Migration Path:**

**Stage 1: Publish-Only (Current + Phase 1)**
```
Projects continue: /codex:sync-project --to-codex  (publish)
Projects start using: @codex/... references (retrieval)
Bidirectional sync deprecated but still works
```

**Stage 2: Retrieval Adoption (Phase 2-3)**
```
Projects disable: --from-codex sync (no more pull-sync)
Projects rely on: @codex/... retrieval (cache-based)
Old synced files cleaned up manually
```

**Stage 3: Full Migration (Phase 4)**
```
Rename: /codex:sync-project → /codex:publish
Remove: --from-codex, --bidirectional options
Keep: Cache management commands
Update: All documentation
```

**Timeline:**
- Phase 1: 0-3 months (coexistence begins)
- Phase 2: 3-6 months (adoption period)
- Phase 3: 6-9 months (full migration)
- Phase 4: 9-12 months (cleanup complete)

---

## Related Specifications

- **SPEC-0012**: Codex Plugin Refactoring (current push-sync)
- **SPEC-0029-04**: Docs Plugin Architecture (creates docs)
- **SPEC-0029-08**: Spec Plugin Architecture (ephemeral specs)
- **SPEC-0029-12**: Logs Plugin Architecture (hybrid retention)
- **SPEC-0002**: FABER Architecture (workflow integration)

---

## References

### Technical Inspiration

- **Context7**: Documentation retrieval with 5-stage pipeline
- **Serena MCP**: Symbol-level semantic code understanding
- **MCP Protocol**: Resource, tools, and prompts primitives
- **URI RFC 3986**: Standard URI syntax
- **URI Templates RFC 6570**: Parameterized resource identifiers

### Fractary Standards

- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`
- `plugins/faber-cloud/` (handler pattern reference)
- `plugins/file/` (multi-provider abstraction)

---

**Status:** Ready for Phase 1 implementation
**Next Steps:** Review and approve SPEC-0030-02 (Phase 1 details)
**Document Version:** 1.0.0
**Last Updated:** 2025-01-15
