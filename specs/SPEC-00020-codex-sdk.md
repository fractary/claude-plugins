# SPEC-00020: Codex SDK

| Field | Value |
|-------|-------|
| **Status** | Draft |
| **Created** | 2025-12-11 |
| **Author** | Claude (with human direction) |
| **Related** | SPEC-00016-sdk-architecture, plugins/codex/ |

## 1. Executive Summary

This specification details the **Codex SDK** implementation within `@fractary/core`. It maps the codex plugin's knowledge management, caching, and sync capabilities to SDK methods and CLI commands.

### 1.1 Scope

- Document retrieval with caching
- Multi-source document fetching (HTTP, GitHub)
- Cache management (clear, list, health, metrics)
- Bidirectional sync between projects and codex repository
- Organization-wide sync with parallel execution
- CLI command mappings
- Plugin migration path

### 1.2 Current Plugin Summary

| Metric | Value |
|--------|-------|
| Skills | 11 |
| Commands | 11 |
| Handlers | 2 (HTTP, GitHub Sync) |
| Operations | 8+ |

## 2. SDK Implementation

### 2.1 Module Structure

```
@fractary/core/
└── codex/
    ├── types.ts              # CodexProvider interface, data types
    ├── index.ts              # Public exports
    ├── provider.ts           # Main CodexProvider implementation
    ├── cache/
    │   ├── types.ts          # Cache types
    │   ├── store.ts          # Cache storage
    │   ├── index.ts          # Cache index management
    │   └── health.ts         # Cache health diagnostics
    ├── fetch/
    │   ├── types.ts          # Fetch handler types
    │   ├── http.ts           # HTTP document fetcher
    │   └── github.ts         # GitHub raw file fetcher
    └── sync/
        ├── types.ts          # Sync types
        ├── project.ts        # Single project sync
        ├── org.ts            # Organization-wide sync
        └── differ.ts         # Change detection
```

### 2.2 CodexProvider Interface

```typescript
// codex/types.ts

export interface CodexProvider {
  // === Document Retrieval ===

  /** Fetch document from codex knowledge base */
  fetchDocument(reference: string, options?: FetchOptions): Promise<Document>;

  /** Check if document exists */
  documentExists(reference: string): Promise<boolean>;

  // === Cache Management ===

  /** Clear cache entries */
  clearCache(options: ClearCacheOptions): Promise<ClearCacheResult>;

  /** List cached documents */
  listCache(options?: ListCacheOptions): Promise<CachedDocument[]>;

  /** Check cache health */
  checkCacheHealth(options?: HealthOptions): Promise<CacheHealth>;

  /** Get cache metrics */
  getCacheMetrics(): Promise<CacheMetrics>;

  // === Sync Operations ===

  /** Sync single project with codex repository */
  syncProject(project: string, options?: SyncOptions): Promise<SyncResult>;

  /** Sync all projects in organization */
  syncOrganization(options?: OrgSyncOptions): Promise<OrgSyncResult>;

  /** Discover repositories in organization */
  discoverRepos(organization: string): Promise<Repository[]>;

  // === Validation ===

  /** Validate codex references in files */
  validateReferences(path: string, options?: ValidateOptions): Promise<ValidationResult>;

  /** Validate plugin setup */
  validateSetup(): Promise<SetupValidation>;
}

// === Data Types ===

export interface Document {
  reference: string;
  content: string;
  source: 'cache' | 'http' | 'github';
  cached: boolean;
  timestamp: Date;
  version?: string;
  metadata?: Record<string, unknown>;
}

export interface FetchOptions {
  source?: 'http' | 'github' | 'auto';
  version?: string;
  bypassCache?: boolean;
  ttl?: number;  // Cache TTL in seconds
}

export interface ClearCacheOptions {
  scope: 'all' | 'expired' | 'project' | 'pattern';
  filter?: string;  // Project name or glob pattern
  dryRun?: boolean;
  confirmed?: boolean;
}

export interface ClearCacheResult {
  deletedCount: number;
  affectedEntries: string[];
  dryRun: boolean;
}

export interface CachedDocument {
  reference: string;
  source: string;
  size: number;
  cachedAt: Date;
  expiresAt?: Date;
  status: 'fresh' | 'stale' | 'expired';
  accessCount: number;
  lastAccessed: Date;
}

export interface ListCacheOptions {
  project?: string;
  pattern?: string;
  freshnessFilter?: 'fresh' | 'stale' | 'expired' | 'all';
}

export interface CacheHealth {
  status: 'healthy' | 'degraded' | 'unhealthy';
  issues: CacheIssue[];
  suggestions: string[];
  canAutoRepair: boolean;
}

export interface CacheIssue {
  type: 'orphan' | 'corrupt' | 'missing_index' | 'stale_index';
  path: string;
  severity: 'low' | 'medium' | 'high';
  description: string;
}

export interface CacheMetrics {
  totalEntries: number;
  totalSizeBytes: number;
  hitRate: number;
  missRate: number;
  avgFetchTime: number;
  oldestEntry: Date;
  newestEntry: Date;
  bySource: Record<string, { count: number; size: number }>;
  byProject: Record<string, { count: number; size: number }>;
}

export interface SyncOptions {
  direction: 'to-codex' | 'from-codex' | 'bidirectional';
  environment?: string;
  targetBranch?: string;
  patterns?: string[];
  exclude?: string[];
  dryRun?: boolean;
}

export interface SyncResult {
  project: string;
  direction: string;
  status: 'success' | 'partial' | 'failed';
  filesCreated: number;
  filesUpdated: number;
  filesDeleted: number;
  conflicts: SyncConflict[];
  errors: string[];
}

export interface SyncConflict {
  path: string;
  type: 'content' | 'deleted_locally' | 'deleted_remotely';
  resolution?: 'keep_local' | 'keep_remote' | 'manual';
}

export interface OrgSyncOptions extends SyncOptions {
  organization: string;
  codexRepo: string;
  parallelRepos?: number;
  exclude?: string[];  // Repository patterns to exclude
}

export interface OrgSyncResult {
  organization: string;
  totalProjects: number;
  successCount: number;
  failureCount: number;
  results: SyncResult[];
  duration: number;
}

export interface ValidationResult {
  valid: boolean;
  errors: ReferenceError[];
  warnings: ReferenceWarning[];
  fixable: number;
}

export interface ReferenceError {
  file: string;
  line: number;
  reference: string;
  error: string;
}

export interface ReferenceWarning {
  file: string;
  line: number;
  reference: string;
  warning: string;
}

export interface SetupValidation {
  valid: boolean;
  configExists: boolean;
  configValid: boolean;
  cacheAccessible: boolean;
  codexRepoAccessible: boolean;
  issues: string[];
}
```

## 3. Operation Mappings

### 3.1 Document Retrieval

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `document-fetcher` | `fetchDocument(reference, options?)` | `fractary codex fetch <reference>` |

#### 3.1.1 fetchDocument

**Current Plugin**: `document-fetcher` skill

**SDK Method**:
```typescript
async fetchDocument(reference: string, options?: FetchOptions): Promise<Document>
```

**CLI**:
```bash
fractary codex fetch <reference> [options]

Arguments:
  <reference>            Document reference (e.g., "standards/coding-style.md")

Options:
  --source <source>      Source: http, github, auto (default: auto)
  --version <version>    Specific version
  --bypass-cache         Skip cache, fetch fresh
  --json                 Output as JSON
```

**Implementation Notes**:
- Cache-first retrieval strategy
- Falls back to HTTP or GitHub based on reference format
- Updates cache index on fetch
- Tracks access count for metrics

**Cache Strategy**:
```typescript
async fetchDocument(reference: string, options: FetchOptions = {}): Promise<Document> {
  // 1. Check cache unless bypassed
  if (!options.bypassCache) {
    const cached = await this.cache.get(reference);
    if (cached && !this.isExpired(cached)) {
      await this.cache.recordHit(reference);
      return {
        ...cached.document,
        source: 'cache',
        cached: true,
      };
    }
  }

  // 2. Determine source
  const source = options.source || this.detectSource(reference);

  // 3. Fetch from source
  const document = source === 'github'
    ? await this.githubFetcher.fetch(reference, options)
    : await this.httpFetcher.fetch(reference, options);

  // 4. Update cache
  await this.cache.set(reference, document, options.ttl);

  return {
    ...document,
    source,
    cached: false,
  };
}
```

### 3.2 Cache Management

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `cache-clear` | `clearCache(options)` | `fractary codex cache clear` |
| `cache-list` | `listCache(options?)` | `fractary codex cache list` |
| `cache-health` | `checkCacheHealth(options?)` | `fractary codex cache health` |
| `cache-metrics` | `getCacheMetrics()` | `fractary codex cache metrics` |

#### 3.2.1 clearCache

**SDK Method**:
```typescript
async clearCache(options: ClearCacheOptions): Promise<ClearCacheResult>
```

**CLI**:
```bash
fractary codex cache clear [options]

Options:
  --scope <scope>        Scope: all, expired, project, pattern (default: expired)
  --filter <filter>      Project name or glob pattern (for project/pattern scope)
  --dry-run              Show what would be deleted
  --yes                  Skip confirmation
```

**Scopes**:
- `all` - Clear entire cache
- `expired` - Clear only expired entries
- `project` - Clear entries for specific project
- `pattern` - Clear entries matching glob pattern

#### 3.2.2 listCache

**SDK Method**:
```typescript
async listCache(options?: ListCacheOptions): Promise<CachedDocument[]>
```

**CLI**:
```bash
fractary codex cache list [options]

Options:
  --project <name>       Filter by project
  --pattern <pattern>    Filter by glob pattern
  --status <status>      Filter: fresh, stale, expired, all (default: all)
  --json                 Output as JSON
```

**Output**:
```
Cached Documents (23 total):
REFERENCE                           SIZE      STATUS    CACHED
standards/coding-style.md           12.5 KB   Fresh     2h ago
templates/skill-template.md         8.2 KB    Fresh     1d ago
guides/plugin-development.md        45.1 KB   Stale     7d ago
specs/SPEC-00002.md                 22.8 KB   Expired   30d ago

Total: 88.6 KB, 18 fresh, 3 stale, 2 expired
```

#### 3.2.3 checkCacheHealth

**SDK Method**:
```typescript
async checkCacheHealth(options?: HealthOptions): Promise<CacheHealth>
```

**CLI**:
```bash
fractary codex cache health [options]

Options:
  --repair               Auto-repair detected issues
  --verbose              Show detailed diagnostics
  --json                 Output as JSON
```

**Health Checks**:
- Orphaned cache files (no index entry)
- Corrupt cache entries
- Missing index entries
- Stale index data
- Permission issues

#### 3.2.4 getCacheMetrics

**SDK Method**:
```typescript
async getCacheMetrics(): Promise<CacheMetrics>
```

**CLI**:
```bash
fractary codex cache metrics [options]

Options:
  --json                 Output as JSON
```

**Output**:
```
Cache Metrics:
  Total Entries: 23
  Total Size: 88.6 KB
  Hit Rate: 87.3%
  Miss Rate: 12.7%
  Avg Fetch Time: 245ms

By Source:
  github: 18 entries (72.1 KB)
  http: 5 entries (16.5 KB)

By Project:
  claude-plugins: 15 entries
  fractary-core: 8 entries
```

### 3.3 Sync Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `project-syncer` | `syncProject(project, options?)` | `fractary codex sync project <name>` |
| `org-syncer` | `syncOrganization(options)` | `fractary codex sync org` |
| `repo-discoverer` | `discoverRepos(organization)` | (internal) |

#### 3.3.1 syncProject

**Current Plugin**: `project-syncer` skill

**SDK Method**:
```typescript
async syncProject(project: string, options?: SyncOptions): Promise<SyncResult>
```

**CLI**:
```bash
fractary codex sync project [project-name] [options]

Arguments:
  [project-name]         Project name (default: current project)

Options:
  --direction <dir>      Direction: to-codex, from-codex, bidirectional (default: bidirectional)
  --env <env>            Environment for branch mapping
  --dry-run              Show what would change
  --patterns <patterns>  Comma-separated file patterns to sync
  --exclude <patterns>   Comma-separated patterns to exclude
  --json                 Output as JSON
```

**Sync Process**:
1. Load project configuration
2. Determine target branch from environment mapping
3. Compare local and codex files
4. Apply changes based on direction
5. Handle conflicts
6. Update sync metadata

#### 3.3.2 syncOrganization

**Current Plugin**: `org-syncer` skill

**SDK Method**:
```typescript
async syncOrganization(options: OrgSyncOptions): Promise<OrgSyncResult>
```

**CLI**:
```bash
fractary codex sync org [options]

Options:
  --org <name>           Organization name
  --codex <repo>         Codex repository name
  --direction <dir>      Direction: to-codex, from-codex, bidirectional
  --env <env>            Environment for branch mapping
  --parallel <n>         Max parallel repos (default: 3)
  --exclude <patterns>   Comma-separated repo patterns to exclude
  --dry-run              Show what would change
  --json                 Output as JSON
```

**Two-Phase Architecture**:
1. Phase 1 (parallel): All projects → codex
2. Phase 2 (parallel): Codex → all projects

This prevents race conditions during bidirectional sync.

### 3.4 Validation

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `validate-refs` | `validateReferences(path, options?)` | `fractary codex validate refs` |
| `validate-setup` | `validateSetup()` | `fractary codex validate setup` |

#### 3.4.1 validateReferences

**SDK Method**:
```typescript
async validateReferences(path: string, options?: ValidateOptions): Promise<ValidationResult>
```

**CLI**:
```bash
fractary codex validate refs [options]

Options:
  --path <directory>     Directory to scan (default: current)
  --fix                  Auto-fix fixable issues
  --json                 Output as JSON
```

**Validates**:
- Codex reference syntax
- Reference targets exist
- Reference versions valid

#### 3.4.2 validateSetup

**SDK Method**:
```typescript
async validateSetup(): Promise<SetupValidation>
```

**CLI**:
```bash
fractary codex validate setup [options]

Options:
  --verbose              Show detailed validation
  --json                 Output as JSON
```

## 4. Cache Implementation

### 4.1 Cache Storage

```typescript
// codex/cache/store.ts

export class CacheStore {
  private cacheDir: string;
  private index: CacheIndex;

  constructor(config: CacheConfig) {
    this.cacheDir = config.cacheDir || '.fractary/plugins/codex/cache';
    this.index = new CacheIndex(path.join(this.cacheDir, 'index.json'));
  }

  async get(reference: string): Promise<CacheEntry | null> {
    const entry = await this.index.get(reference);
    if (!entry) return null;

    const filePath = this.getFilePath(reference);
    if (!await this.fileExists(filePath)) {
      await this.index.remove(reference);
      return null;
    }

    return {
      ...entry,
      content: await fs.readFile(filePath, 'utf-8'),
    };
  }

  async set(reference: string, document: Document, ttl?: number): Promise<void> {
    const filePath = this.getFilePath(reference);
    await fs.mkdir(path.dirname(filePath), { recursive: true });
    await fs.writeFile(filePath, document.content);

    await this.index.set(reference, {
      source: document.source,
      size: Buffer.byteLength(document.content),
      cachedAt: new Date(),
      expiresAt: ttl ? new Date(Date.now() + ttl * 1000) : undefined,
      version: document.version,
    });
  }

  async clear(options: ClearCacheOptions): Promise<ClearCacheResult> {
    const entries = await this.index.list();
    const toDelete: string[] = [];

    for (const entry of entries) {
      if (this.shouldDelete(entry, options)) {
        toDelete.push(entry.reference);
      }
    }

    if (!options.dryRun) {
      for (const ref of toDelete) {
        await this.remove(ref);
      }
    }

    return {
      deletedCount: toDelete.length,
      affectedEntries: toDelete,
      dryRun: options.dryRun || false,
    };
  }

  private shouldDelete(entry: CacheEntry, options: ClearCacheOptions): boolean {
    switch (options.scope) {
      case 'all':
        return true;
      case 'expired':
        return entry.expiresAt && entry.expiresAt < new Date();
      case 'project':
        return entry.reference.startsWith(options.filter || '');
      case 'pattern':
        return minimatch(entry.reference, options.filter || '*');
      default:
        return false;
    }
  }
}
```

### 4.2 Cache Index

```typescript
// codex/cache/index.ts

export interface CacheIndexEntry {
  reference: string;
  source: string;
  size: number;
  cachedAt: Date;
  expiresAt?: Date;
  version?: string;
  accessCount: number;
  lastAccessed: Date;
}

export class CacheIndex {
  private indexPath: string;
  private data: Map<string, CacheIndexEntry>;

  constructor(indexPath: string) {
    this.indexPath = indexPath;
    this.data = new Map();
  }

  async load(): Promise<void> {
    try {
      const content = await fs.readFile(this.indexPath, 'utf-8');
      const parsed = JSON.parse(content);
      this.data = new Map(Object.entries(parsed.entries));
    } catch {
      this.data = new Map();
    }
  }

  async save(): Promise<void> {
    const content = JSON.stringify({
      version: '1.0',
      entries: Object.fromEntries(this.data),
    }, null, 2);
    await fs.writeFile(this.indexPath, content);
  }

  async recordHit(reference: string): Promise<void> {
    const entry = this.data.get(reference);
    if (entry) {
      entry.accessCount++;
      entry.lastAccessed = new Date();
      await this.save();
    }
  }
}
```

## 5. Sync Implementation

### 5.1 Project Syncer

```typescript
// codex/sync/project.ts

export class ProjectSyncer {
  async sync(project: string, options: SyncOptions): Promise<SyncResult> {
    const config = await this.loadProjectConfig(project);
    const codexRepo = this.getCodexRepoPath(config);
    const targetBranch = this.resolveTargetBranch(options.environment, config);

    // Get file lists
    const localFiles = await this.getLocalFiles(project, options.patterns);
    const codexFiles = await this.getCodexFiles(codexRepo, project, targetBranch);

    // Compute changes
    const changes = this.computeChanges(localFiles, codexFiles, options.direction);

    // Apply changes (unless dry-run)
    const result: SyncResult = {
      project,
      direction: options.direction,
      status: 'success',
      filesCreated: 0,
      filesUpdated: 0,
      filesDeleted: 0,
      conflicts: [],
      errors: [],
    };

    if (!options.dryRun) {
      for (const change of changes) {
        try {
          await this.applyChange(change, options.direction);
          if (change.type === 'create') result.filesCreated++;
          if (change.type === 'update') result.filesUpdated++;
          if (change.type === 'delete') result.filesDeleted++;
        } catch (error: any) {
          result.errors.push(`${change.path}: ${error.message}`);
          result.status = 'partial';
        }
      }
    }

    return result;
  }
}
```

## 6. CLI Implementation

### 6.1 Command Structure

```
@fractary/cli/
└── src/tools/codex/
    ├── index.ts              # Codex command group
    └── commands/
        ├── fetch.ts
        ├── cache/
        │   ├── clear.ts
        │   ├── list.ts
        │   ├── health.ts
        │   └── metrics.ts
        ├── sync/
        │   ├── project.ts
        │   └── org.ts
        ├── validate/
        │   ├── refs.ts
        │   └── setup.ts
        └── init.ts
```

## 7. Configuration

### 7.1 Configuration Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "schema_version": { "type": "string", "const": "3.0" },
    "codex_repo": {
      "type": "object",
      "properties": {
        "organization": { "type": "string" },
        "repository": { "type": "string" },
        "default_branch": { "type": "string", "default": "main" }
      }
    },
    "cache": {
      "type": "object",
      "properties": {
        "enabled": { "type": "boolean", "default": true },
        "ttl_seconds": { "type": "number", "default": 86400 },
        "max_size_mb": { "type": "number", "default": 100 },
        "path": { "type": "string", "default": ".fractary/plugins/codex/cache" }
      }
    },
    "sync": {
      "type": "object",
      "properties": {
        "default_direction": { "type": "string", "enum": ["to-codex", "from-codex", "bidirectional"], "default": "bidirectional" },
        "patterns": { "type": "array", "items": { "type": "string" } },
        "exclude": { "type": "array", "items": { "type": "string" } },
        "parallel_repos": { "type": "number", "default": 3 }
      }
    },
    "environments": {
      "type": "object",
      "additionalProperties": { "type": "string" }
    }
  },
  "required": ["schema_version"]
}
```

### 7.2 Example Configuration

```json
{
  "schema_version": "3.0",
  "codex_repo": {
    "organization": "fractary",
    "repository": "codex",
    "default_branch": "main"
  },
  "cache": {
    "enabled": true,
    "ttl_seconds": 86400,
    "max_size_mb": 100
  },
  "sync": {
    "default_direction": "bidirectional",
    "patterns": ["**/*.md", "**/*.json"],
    "exclude": ["**/node_modules/**", "**/.git/**"],
    "parallel_repos": 3
  },
  "environments": {
    "dev": "develop",
    "test": "test",
    "prod": "main"
  }
}
```

## 8. References

- [SPEC-00016: SDK Architecture](./SPEC-00016-sdk-architecture.md) - Core interfaces
- [GitHub Raw Content API](https://docs.github.com/en/rest/repos/contents)
