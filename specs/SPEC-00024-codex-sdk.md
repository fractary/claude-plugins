# SPEC-00024: Codex SDK

| Field | Value |
|-------|-------|
| **ID** | SPEC-00024 |
| **Title** | Codex SDK - Knowledge Infrastructure for AI Agents |
| **Status** | Draft |
| **Created** | 2025-12-11 |
| **Author** | Fractary Engineering |
| **Related** | SPEC-00023 (FABER SDK), fractary-codex plugin |

## 1. Overview

### 1.1 Purpose

The Codex SDK (`@fractary/codex`) provides standalone knowledge infrastructure for AI agents. It serves as a "memory fabric" - managing universal references, storage abstraction, caching, synchronization, and an MCP server for unified knowledge access across projects and organizations.

The SDK is designed to work independently of FABER, enabling any application to leverage its knowledge management capabilities.

### 1.2 Core Principles

1. **Standalone Operation** - Works without FABER or any other Fractary SDK
2. **Universal References** - `codex://{org}/{project}/{path}` addresses any artifact
3. **Extensible Types** - Built-in types plus user-defined custom types
4. **Storage Abstraction** - Local, cloud, and vector store backends
5. **Cache-First Architecture** - Sub-100ms access with intelligent caching
6. **MCP Integration** - Exposes knowledge via Model Context Protocol

### 1.3 Key Use Cases

| Use Case | Description |
|----------|-------------|
| **Standalone Knowledge Base** | Organization-wide documentation and standards repository |
| **Cross-Project References** | Share specs, guides, and templates across repositories |
| **Custom Artifact Management** | Define and manage any artifact type (research, contracts, etc.) |
| **AI Context Provider** | MCP server for Claude/LLM access to organizational knowledge |
| **FABER Integration** | Optional enhancement for specs, logs, and state archival |

### 1.4 Relationship to FABER

```
┌─────────────────────────────────────────────────────────┐
│ @fractary/codex (Standalone)                            │
│                                                         │
│  Universal References │ Storage Abstraction │ MCP      │
│  Type Registry       │ Caching             │ Sync     │
└─────────────────────────────────────────────────────────┘
                              ↑
                              │ Optional Runtime Integration
                              │ (Codex detected at runtime)
                              │
┌─────────────────────────────────────────────────────────┐
│ @fractary/faber (Standalone)                            │
│                                                         │
│  Work │ Repo │ Spec │ Logs │ State │ Workflow          │
└─────────────────────────────────────────────────────────┘
```

- **No Compile-Time Dependency**: Neither SDK depends on the other
- **Runtime Detection**: FABER detects Codex at runtime via `require('@fractary/codex')`
- **Per-Artifact Configuration**: Each artifact type can opt-in to Codex management
- **Graceful Degradation**: Both SDKs work fully without the other

---

## 2. Architecture

### 2.1 Package Structure

```
@fractary/codex/
├── src/
│   ├── index.ts              # Main exports
│   ├── codex.ts              # Codex class (main entry point)
│   │
│   ├── references/           # Universal Reference System
│   │   ├── parser.ts         # Parse codex:// URIs
│   │   ├── resolver.ts       # Resolve references to paths
│   │   └── validator.ts      # Validate reference format
│   │
│   ├── types/                # Extensible Type Registry
│   │   ├── registry.ts       # Type registration and lookup
│   │   ├── built-in.ts       # Built-in types (docs, specs, logs, etc.)
│   │   └── custom.ts         # Custom type support
│   │
│   ├── storage/              # Storage Abstraction Layer
│   │   ├── manager.ts        # Storage manager
│   │   ├── local.ts          # Local filesystem storage
│   │   ├── s3.ts             # AWS S3 provider
│   │   ├── r2.ts             # Cloudflare R2 provider
│   │   ├── gcs.ts            # Google Cloud Storage provider
│   │   └── drive.ts          # Google Drive provider
│   │
│   ├── cache/                # Intelligent Caching
│   │   ├── manager.ts        # Cache manager
│   │   ├── index.ts          # Cache index operations
│   │   ├── ttl.ts            # TTL management
│   │   └── cleanup.ts        # Automatic cleanup
│   │
│   ├── sync/                 # Synchronization Engine
│   │   ├── manager.ts        # Sync orchestration
│   │   ├── project.ts        # Project-level sync
│   │   ├── organization.ts   # Organization-wide sync
│   │   └── handlers/         # Provider-specific handlers
│   │       ├── github.ts     # GitHub sync handler
│   │       ├── http.ts       # HTTP endpoint handler
│   │       └── local.ts      # Local filesystem handler
│   │
│   ├── mcp/                  # MCP Server
│   │   ├── server.ts         # MCP server implementation
│   │   ├── resources.ts      # Resource listing/reading
│   │   └── tools.ts          # MCP tools (fetch, status)
│   │
│   ├── permissions/          # Permission System
│   │   ├── checker.ts        # Permission checking
│   │   ├── frontmatter.ts    # Frontmatter-based permissions
│   │   └── patterns.ts       # Pattern matching (wildcards)
│   │
│   ├── migration/            # Migration Tools
│   │   ├── detector.ts       # Detect v2 configs
│   │   ├── converter.ts      # Convert v2 → v3
│   │   └── validator.ts      # Validate migrated config
│   │
│   ├── config/               # Configuration
│   │   ├── loader.ts         # Config file loading
│   │   ├── schema.ts         # JSON schema validation
│   │   └── defaults.ts       # Default values
│   │
│   └── cli/                  # CLI Commands
│       ├── index.ts          # CLI entry point
│       ├── init.ts           # Initialize configuration
│       ├── fetch.ts          # Fetch document
│       ├── sync.ts           # Sync operations
│       ├── cache.ts          # Cache management
│       ├── types.ts          # Type management
│       └── health.ts         # Health checks
│
├── bin/
│   └── codex-mcp.js          # MCP server binary
│
└── package.json
```

### 2.2 Component Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Codex SDK                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ References   │  │ Type         │  │ Storage              │  │
│  │              │  │ Registry     │  │ Abstraction          │  │
│  │ codex://     │  │              │  │                      │  │
│  │ parser       │  │ built-in +   │  │ local, S3, R2,      │  │
│  │ resolver     │  │ custom       │  │ GCS, Drive           │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Cache        │  │ Sync         │  │ MCP Server           │  │
│  │              │  │ Engine       │  │                      │  │
│  │ TTL-based    │  │              │  │ resources            │  │
│  │ index        │  │ project/org  │  │ tools                │  │
│  │ cleanup      │  │ bidirectional│  │ fetch-on-demand      │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Permissions  │  │ Migration    │  │ CLI                  │  │
│  │              │  │              │  │                      │  │
│  │ frontmatter  │  │ v2 → v3      │  │ init, fetch, sync   │  │
│  │ patterns     │  │ backup       │  │ cache, types, health │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Universal Reference System

### 3.1 URI Format

```
codex://{org}/{project}/{path}

Components:
  org     - Organization name (e.g., "fractary")
  project - Project/repository name (e.g., "auth-service")
  path    - File path within project (e.g., "docs/oauth.md")

Examples:
  codex://fractary/auth-service/docs/oauth.md
  codex://fractary/shared/standards/api-design.md
  codex://partner-org/contracts/2024/service-agreement.pdf
```

### 3.2 Reference Types

| Reference | Format | Description |
|-----------|--------|-------------|
| Full URI | `codex://org/project/path` | Complete reference with organization |
| Project-relative | `codex://project/path` | Uses configured default organization |
| Legacy | `@codex/project/path` | v2 format, auto-migrated to URI |

### 3.3 Reference Resolution

```typescript
interface ResolvedReference {
  uri: string;              // Full codex:// URI
  org: string;              // Organization
  project: string;          // Project name
  path: string;             // File path
  type: string;             // Artifact type (docs, specs, logs, custom)
  cachePath: string;        // Local cache path
  isLocal: boolean;         // Is this the current project?
}

// Resolution algorithm
class ReferenceResolver {
  resolve(uri: string): ResolvedReference {
    // 1. Parse URI components
    // 2. Determine artifact type from path patterns
    // 3. Check if current project (local resolution)
    // 4. Calculate cache path
    // 5. Return resolved reference
  }
}
```

### 3.4 Path Security

The SDK enforces strict path security:

```typescript
// Forbidden patterns
- Absolute paths (/etc/passwd)
- Directory traversal (../../../)
- Protocol injection (file://, http://)

// Validation
function validatePath(path: string): boolean {
  if (path.startsWith('/')) return false;
  if (path.includes('../')) return false;
  if (path.includes('..\\')) return false;
  return true;
}
```

---

## 4. Extensible Type Registry

### 4.1 Built-in Types

The SDK includes built-in types for common artifact categories:

```typescript
const BUILT_IN_TYPES = {
  docs: {
    name: 'docs',
    description: 'Documentation files',
    patterns: ['docs/**', 'README.md', 'CLAUDE.md'],
    defaultTtl: 604800,  // 7 days
    archiveAfterDays: 365,
    archiveStorage: 'cloud'
  },

  specs: {
    name: 'specs',
    description: 'Technical specifications',
    patterns: ['specs/**', 'SPEC-*.md'],
    defaultTtl: 1209600,  // 14 days (stable content)
    archiveAfterDays: null,  // Never archive
    archiveStorage: null
  },

  logs: {
    name: 'logs',
    description: 'Session and workflow logs',
    patterns: ['.fractary/**/logs/**'],
    defaultTtl: 86400,  // 1 day (ephemeral)
    archiveAfterDays: 30,
    archiveStorage: 'cloud'
  },

  standards: {
    name: 'standards',
    description: 'Organization standards and guides',
    patterns: ['standards/**', 'guides/**'],
    defaultTtl: 2592000,  // 30 days (very stable)
    archiveAfterDays: null,
    archiveStorage: null
  },

  templates: {
    name: 'templates',
    description: 'Reusable templates',
    patterns: ['templates/**', '.templates/**'],
    defaultTtl: 1209600,
    archiveAfterDays: 180,
    archiveStorage: 'cloud'
  },

  state: {
    name: 'state',
    description: 'Workflow state files',
    patterns: ['.fractary/**/state.json', '.fractary/**/state/**'],
    defaultTtl: 3600,  // 1 hour (frequently changing)
    archiveAfterDays: 7,
    archiveStorage: 'local'  // Archive locally, not cloud
  }
};
```

### 4.2 Custom Types

Users can define custom artifact types:

```typescript
// Configuration in .fractary/plugins/codex/config.json
{
  "types": {
    "custom": {
      "research": {
        "description": "Research notes and findings",
        "patterns": ["research/**", "notes/**"],
        "defaultTtl": 604800,
        "archiveAfterDays": 90,
        "archiveStorage": "cloud",
        "syncPatterns": ["research/**/*.md"],
        "excludePatterns": ["research/drafts/**"]
      },

      "contracts": {
        "description": "Legal contracts and agreements",
        "patterns": ["contracts/**", "legal/**"],
        "defaultTtl": 2592000,
        "archiveAfterDays": null,  // Never auto-archive
        "archiveStorage": null,
        "syncPatterns": ["contracts/**/*.pdf"],
        "permissions": {
          "include": ["legal-team-*", "leadership-*"],
          "exclude": ["*"]  // Default deny
        }
      },

      "meeting_notes": {
        "description": "Meeting notes and action items",
        "patterns": ["meetings/**"],
        "defaultTtl": 86400,
        "archiveAfterDays": 30,
        "archiveStorage": "drive",  // Archive to Google Drive
        "syncPatterns": ["meetings/**/*.md"]
      }
    }
  }
}
```

### 4.3 Type Registry API

```typescript
interface ArtifactType {
  name: string;
  description: string;
  patterns: string[];
  defaultTtl: number;
  archiveAfterDays: number | null;
  archiveStorage: 'local' | 'cloud' | 'drive' | null;
  syncPatterns?: string[];
  excludePatterns?: string[];
  permissions?: {
    include: string[];
    exclude: string[];
  };
}

class TypeRegistry {
  private builtIn: Map<string, ArtifactType>;
  private custom: Map<string, ArtifactType>;

  /**
   * Get type by name (checks custom first, then built-in)
   */
  get(name: string): ArtifactType | undefined;

  /**
   * Register a custom type
   */
  register(type: ArtifactType): void;

  /**
   * Detect type from file path
   */
  detectType(path: string): string;

  /**
   * List all available types
   */
  list(): ArtifactType[];

  /**
   * Validate type configuration
   */
  validate(type: Partial<ArtifactType>): ValidationResult;
}
```

### 4.4 Type Configuration in FABER

When FABER detects Codex, it can configure per-type Codex usage:

```json
// .fractary/plugins/faber/config.json
{
  "artifacts": {
    "specs": {
      "use_codex": false,
      "local_path": "/specs"
    },
    "logs": {
      "use_codex": true,
      "local_path": ".fractary/logs",
      "archive_to_codex_after_days": 30
    },
    "state": {
      "use_codex": false,
      "local_path": ".fractary/plugins/faber"
    }
  }
}
```

---

## 5. Storage Abstraction Layer

### 5.1 Storage Manager

```typescript
interface StorageProvider {
  name: string;
  type: 'local' | 's3' | 'r2' | 'gcs' | 'drive';

  read(path: string): Promise<Buffer>;
  write(path: string, content: Buffer): Promise<void>;
  delete(path: string): Promise<void>;
  exists(path: string): Promise<boolean>;
  list(prefix: string): Promise<string[]>;
  getMetadata(path: string): Promise<StorageMetadata>;
}

interface StorageMetadata {
  size: number;
  modifiedAt: Date;
  contentType: string;
  etag?: string;
}

class StorageManager {
  private providers: Map<string, StorageProvider>;
  private defaultProvider: string;

  /**
   * Register a storage provider
   */
  registerProvider(provider: StorageProvider): void;

  /**
   * Get provider by name
   */
  getProvider(name: string): StorageProvider;

  /**
   * Store artifact with type-based routing
   */
  async store(
    reference: string,
    content: Buffer,
    type: string
  ): Promise<StorageResult>;

  /**
   * Retrieve artifact
   */
  async retrieve(reference: string): Promise<RetrieveResult>;

  /**
   * Archive artifact based on type configuration
   */
  async archive(
    reference: string,
    destination: string
  ): Promise<ArchiveResult>;
}
```

### 5.2 Storage Providers

#### Local Storage

```typescript
class LocalStorage implements StorageProvider {
  name = 'local';
  type = 'local' as const;

  constructor(private basePath: string) {}

  async read(path: string): Promise<Buffer> {
    const fullPath = join(this.basePath, path);
    return fs.readFile(fullPath);
  }

  async write(path: string, content: Buffer): Promise<void> {
    const fullPath = join(this.basePath, path);
    await fs.mkdir(dirname(fullPath), { recursive: true });
    await fs.writeFile(fullPath, content);
  }

  // ... other methods
}
```

#### S3 Storage

```typescript
class S3Storage implements StorageProvider {
  name: string;
  type = 's3' as const;

  constructor(
    private bucket: string,
    private region: string,
    private prefix?: string
  ) {
    this.name = `s3-${bucket}`;
  }

  async read(path: string): Promise<Buffer> {
    const key = this.prefix ? `${this.prefix}/${path}` : path;
    const response = await this.client.getObject({
      Bucket: this.bucket,
      Key: key
    });
    return Buffer.from(await response.Body.transformToByteArray());
  }

  // ... other methods
}
```

#### R2 Storage

```typescript
class R2Storage implements StorageProvider {
  name: string;
  type = 'r2' as const;

  constructor(
    private accountId: string,
    private bucket: string,
    private prefix?: string
  ) {
    this.name = `r2-${bucket}`;
  }

  // Compatible with S3 API via Cloudflare's S3 compatibility
}
```

#### Google Cloud Storage

```typescript
class GCSStorage implements StorageProvider {
  name: string;
  type = 'gcs' as const;

  constructor(
    private bucket: string,
    private prefix?: string
  ) {
    this.name = `gcs-${bucket}`;
  }

  // Uses @google-cloud/storage SDK
}
```

#### Google Drive Storage

```typescript
class DriveStorage implements StorageProvider {
  name: string;
  type = 'drive' as const;

  constructor(
    private folderId: string
  ) {
    this.name = `drive-${folderId}`;
  }

  // Uses Google Drive API for file operations
}
```

### 5.3 Storage Configuration

```json
{
  "storage": {
    "providers": {
      "local": {
        "type": "local",
        "basePath": ".fractary/plugins/codex/cache"
      },
      "archive": {
        "type": "s3",
        "bucket": "fractary-codex-archive",
        "region": "us-east-1",
        "prefix": "archive"
      },
      "backup": {
        "type": "r2",
        "accountId": "${CF_ACCOUNT_ID}",
        "bucket": "codex-backup"
      },
      "shared": {
        "type": "drive",
        "folderId": "${GOOGLE_DRIVE_FOLDER_ID}"
      }
    },
    "routing": {
      "default": "local",
      "archive": "archive",
      "shared_docs": "shared"
    }
  }
}
```

---

## 6. Intelligent Caching

### 6.1 Cache Architecture

```
.fractary/plugins/codex/cache/
├── index.json           # Cache index with metadata
└── {org}/
    └── {project}/
        └── {path}       # Cached files mirror URI structure
```

### 6.2 Cache Index Structure

```typescript
interface CacheIndex {
  version: '3.0';
  entries: CacheEntry[];
  stats: {
    totalEntries: number;
    totalSizeBytes: number;
    lastCleanup: string | null;
    hitRate?: number;
  };
}

interface CacheEntry {
  uri: string;                    // codex://org/project/path
  path: string;                   // Relative cache path
  type: string;                   // Artifact type
  source: string;                 // Origin (github, http, local)
  cachedAt: string;               // ISO timestamp
  expiresAt: string;              // ISO timestamp (cachedAt + TTL)
  ttl: number;                    // TTL in seconds
  sizeBytes: number;              // File size
  hash: string;                   // Content hash (SHA256)
  lastAccessed: string;           // ISO timestamp
  syncedVia?: string;             // Sync source if applicable
}
```

### 6.3 Cache Manager API

```typescript
class CacheManager {
  private index: CacheIndex;
  private storage: StorageProvider;

  /**
   * Look up entry in cache
   */
  async lookup(uri: string): Promise<CacheLookupResult>;

  /**
   * Store content in cache
   */
  async store(
    uri: string,
    content: Buffer,
    options?: {
      ttl?: number;
      source?: string;
      type?: string;
    }
  ): Promise<CacheEntry>;

  /**
   * Retrieve content from cache
   */
  async retrieve(uri: string): Promise<CacheRetrieveResult | null>;

  /**
   * Clear cache entries
   */
  async clear(options: {
    scope: 'all' | 'expired' | 'project' | 'pattern' | 'type';
    filter?: {
      project?: string;
      pattern?: string;
      type?: string;
    };
    dryRun?: boolean;
  }): Promise<CacheClearResult>;

  /**
   * Get cache statistics
   */
  async getStats(): Promise<CacheStats>;

  /**
   * Run health check
   */
  async healthCheck(options?: {
    fix?: boolean;
  }): Promise<HealthCheckResult>;
}

interface CacheLookupResult {
  cached: boolean;
  fresh: boolean;
  reason: 'valid' | 'expired' | 'not_in_cache' | 'not_in_index';
  entry?: CacheEntry;
}
```

### 6.4 TTL Management

```typescript
class TTLManager {
  private typeRegistry: TypeRegistry;

  /**
   * Get TTL for a reference based on type
   */
  getTTL(uri: string, override?: number): number;

  /**
   * Check if entry is fresh
   */
  isFresh(entry: CacheEntry): boolean;

  /**
   * Calculate expiration time
   */
  calculateExpiry(cachedAt: Date, ttl: number): Date;
}

// TTL by type (configurable defaults)
const DEFAULT_TTL = {
  docs: 604800,       // 7 days
  specs: 1209600,     // 14 days
  logs: 86400,        // 1 day
  standards: 2592000, // 30 days
  templates: 1209600, // 14 days
  state: 3600,        // 1 hour
  default: 604800     // 7 days (fallback)
};
```

### 6.5 Automatic Cleanup

```typescript
class CacheCleanup {
  /**
   * Run automatic cleanup based on configuration
   */
  async runAutoCleanup(): Promise<CleanupResult>;

  /**
   * Clean up expired entries
   */
  async cleanExpired(): Promise<CleanupResult>;

  /**
   * Clean up to meet size limit
   */
  async cleanToSizeLimit(maxSizeMb: number): Promise<CleanupResult>;

  /**
   * Archive old entries before cleanup
   */
  async archiveBeforeCleanup(
    entries: CacheEntry[],
    archiveStorage: string
  ): Promise<ArchiveResult>;
}
```

---

## 7. Synchronization Engine

### 7.1 Sync Manager

```typescript
class SyncManager {
  private handlers: Map<string, SyncHandler>;

  /**
   * Sync a single project
   */
  async syncProject(options: {
    project: string;
    organization: string;
    codexRepo: string;
    direction: 'to-codex' | 'from-codex' | 'bidirectional';
    environment?: string;
    targetBranch?: string;
    patterns?: string[];
    dryRun?: boolean;
  }): Promise<SyncResult>;

  /**
   * Sync entire organization
   */
  async syncOrganization(options: {
    organization: string;
    codexRepo: string;
    direction: 'to-codex' | 'from-codex' | 'bidirectional';
    environment?: string;
    exclude?: string[];
    parallel?: number;
    dryRun?: boolean;
  }): Promise<OrgSyncResult>;

  /**
   * Get sync status
   */
  async getSyncStatus(project?: string): Promise<SyncStatus>;
}

interface SyncResult {
  success: boolean;
  project: string;
  direction: string;
  filesAdded: number;
  filesModified: number;
  filesDeleted: number;
  details: SyncFileDetail[];
  commits?: string[];
  errors?: string[];
}
```

### 7.2 Sync Handlers

#### GitHub Handler

```typescript
class GitHubSyncHandler implements SyncHandler {
  name = 'github';

  /**
   * Sync files from/to GitHub
   */
  async sync(options: SyncOptions): Promise<SyncResult>;

  /**
   * Discover repositories in organization
   */
  async discoverRepos(org: string): Promise<string[]>;

  /**
   * Clone codex repo with sparse checkout
   */
  async cloneCodex(
    repo: string,
    patterns: string[]
  ): Promise<CloneResult>;

  /**
   * Push changes to codex repo
   */
  async pushToCodex(
    changes: FileChange[],
    message: string
  ): Promise<PushResult>;
}
```

#### HTTP Handler

```typescript
class HTTPSyncHandler implements SyncHandler {
  name = 'http';

  /**
   * Fetch from HTTP endpoint
   */
  async fetch(url: string): Promise<FetchResult>;

  /**
   * Validate URL safety
   */
  validateUrl(url: string): boolean;
}
```

### 7.3 Environment-Aware Sync

```typescript
interface EnvironmentConfig {
  branch: string;
  description: string;
}

// Default environments
const DEFAULT_ENVIRONMENTS: Record<string, EnvironmentConfig> = {
  dev: { branch: 'test', description: 'Development environment' },
  test: { branch: 'test', description: 'Test/QA environment' },
  staging: { branch: 'main', description: 'Staging environment' },
  prod: { branch: 'main', description: 'Production environment' }
};

// Environment detection from git branch
function detectEnvironment(branch: string): string {
  if (branch.startsWith('feat/') || branch.startsWith('fix/')) {
    return 'test';
  }
  if (branch === 'main' || branch === 'master') {
    return 'prod';
  }
  return 'test';  // Safe default
}
```

---

## 8. MCP Server

### 8.1 MCP Server Implementation

```typescript
class CodexMCPServer {
  private server: MCPServer;
  private cache: CacheManager;
  private config: CodexConfig;

  constructor(options: MCPServerOptions) {
    this.server = new MCPServer({
      name: 'fractary-codex',
      version: '3.0.0',
      capabilities: {
        resources: {},
        tools: {}
      }
    });

    this.setupHandlers();
  }

  private setupHandlers(): void {
    // Resource handlers
    this.server.setRequestHandler(
      ListResourcesRequestSchema,
      this.listResources.bind(this)
    );

    this.server.setRequestHandler(
      ReadResourceRequestSchema,
      this.readResource.bind(this)
    );

    // Tool handlers
    this.server.setRequestHandler(
      ListToolsRequestSchema,
      this.listTools.bind(this)
    );

    this.server.setRequestHandler(
      CallToolRequestSchema,
      this.callTool.bind(this)
    );
  }

  async start(): Promise<void>;
  async stop(): Promise<void>;
}
```

### 8.2 MCP Resources

```typescript
/**
 * List all cached documents as MCP resources
 */
async listResources(): Promise<MCPResource[]> {
  const index = await this.cache.getIndex();

  return index.entries.map(entry => ({
    uri: entry.uri,
    name: entry.path,
    description: this.formatResourceDescription(entry),
    mimeType: this.detectMimeType(entry.path)
  }));
}

/**
 * Read a specific resource
 */
async readResource(uri: string): Promise<MCPResourceContent> {
  // 1. Try local resolution for current project
  const resolved = await this.resolver.resolve(uri);

  if (resolved.isLocal) {
    const content = await fs.readFile(resolved.path, 'utf-8');
    return { uri, content, metadata: { source: 'local' } };
  }

  // 2. Try cache
  const cached = await this.cache.retrieve(uri);
  if (cached && cached.fresh) {
    return { uri, content: cached.content, metadata: cached.metadata };
  }

  // 3. On-demand fetch
  if (!this.config.cache?.offlineMode) {
    const fetched = await this.fetchOnDemand(uri);
    if (fetched) {
      return { uri, content: fetched.content, metadata: fetched.metadata };
    }
  }

  // 4. Fallback to stale if configured
  if (this.config.cache?.fallbackToStale && cached) {
    return { uri, content: cached.content, metadata: { ...cached.metadata, stale: true } };
  }

  throw new Error(`Resource not found: ${uri}`);
}
```

### 8.3 MCP Tools

```typescript
const MCP_TOOLS = [
  {
    name: 'codex_fetch',
    description: 'Fetch a document from codex knowledge base',
    inputSchema: {
      type: 'object',
      properties: {
        uri: {
          type: 'string',
          description: 'Document URI (codex://org/project/path)'
        },
        force_refresh: {
          type: 'boolean',
          description: 'Force refresh from source',
          default: false
        }
      },
      required: ['uri']
    }
  },
  {
    name: 'codex_cache_status',
    description: 'Get cache statistics and status',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'codex_sync_status',
    description: 'Check sync status and information',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'codex_list_types',
    description: 'List available artifact types',
    inputSchema: {
      type: 'object',
      properties: {
        include_custom: {
          type: 'boolean',
          default: true
        }
      }
    }
  }
];
```

### 8.4 MCP Registration

The MCP server is registered in Claude settings:

```json
{
  "mcpServers": {
    "fractary-codex": {
      "command": "node",
      "args": [
        "/path/to/node_modules/@fractary/codex/bin/codex-mcp.js"
      ],
      "env": {
        "CODEX_CONFIG_PATH": "/path/to/project/.fractary/plugins/codex/config.json"
      }
    }
  }
}
```

---

## 9. Permission System

### 9.1 Frontmatter-Based Permissions

```yaml
---
codex_sync_include:
  - auth-service           # Exact project match
  - *-service              # Wildcard suffix
  - platform/*             # Directory prefix
  - "*"                    # Public (all projects)
codex_sync_exclude:
  - temp-*                 # Exclusions take precedence
  - project-sensitive
---
```

### 9.2 Permission Checker

```typescript
class PermissionChecker {
  /**
   * Check if requesting project can access document
   */
  async checkPermission(
    document: string,
    requestingProject: string
  ): Promise<PermissionResult>;

  /**
   * Parse permissions from frontmatter
   */
  parsePermissions(content: string): DocumentPermissions;

  /**
   * Match project against patterns
   */
  matchPattern(project: string, patterns: string[]): boolean;
}

interface DocumentPermissions {
  include: string[];
  exclude: string[];
}

interface PermissionResult {
  allowed: boolean;
  reason: 'allowed' | 'denied' | 'excluded' | 'not_in_list';
  matchedPattern?: string;
}
```

### 9.3 Pattern Matching

```typescript
/**
 * Pattern matching rules:
 * - "*" matches everything (public)
 * - "prefix-*" matches prefix
 * - "*-suffix" matches suffix
 * - "exact" matches exact name
 * - "path/*" matches path prefix
 */
function matchPattern(value: string, pattern: string): boolean {
  if (pattern === '*') return true;

  if (pattern.startsWith('*') && pattern.endsWith('*')) {
    return value.includes(pattern.slice(1, -1));
  }

  if (pattern.startsWith('*')) {
    return value.endsWith(pattern.slice(1));
  }

  if (pattern.endsWith('*')) {
    return value.startsWith(pattern.slice(0, -1));
  }

  return value === pattern;
}
```

---

## 10. Migration Tools

### 10.1 Version Detection

```typescript
class MigrationDetector {
  /**
   * Detect configuration version
   */
  detectVersion(config: any): '2.0' | '3.0' | 'unknown';

  /**
   * Check if migration is needed
   */
  needsMigration(config: any): boolean;

  /**
   * Find legacy configurations
   */
  findLegacyConfigs(): string[];
}
```

### 10.2 Migration Converter

```typescript
class MigrationConverter {
  /**
   * Convert v2.0 config to v3.0
   */
  async migrate(options: {
    source: string;
    destination: string;
    backup?: boolean;
    dryRun?: boolean;
  }): Promise<MigrationResult>;

  /**
   * Convert reference format
   */
  convertReference(ref: string): string {
    // @codex/project/path -> codex://org/project/path
  }

  /**
   * Convert configuration structure
   */
  convertConfig(v2Config: V2Config): V3Config;
}

interface MigrationResult {
  success: boolean;
  sourceVersion: string;
  targetVersion: string;
  backupPath?: string;
  changes: string[];
  warnings: string[];
}
```

### 10.3 Reference Migration

```typescript
class ReferenceMigrator {
  /**
   * Scan files for legacy references
   */
  async scanForLegacyRefs(
    path: string,
    patterns?: string[]
  ): Promise<LegacyRefScanResult>;

  /**
   * Convert legacy references in files
   */
  async convertReferences(options: {
    path: string;
    organization: string;
    dryRun?: boolean;
  }): Promise<ConversionResult>;
}
```

---

## 11. CLI Commands

### 11.1 Command Structure

```
codex <command> [options]

Commands:
  init              Initialize codex configuration
  fetch             Fetch a document by reference
  sync              Sync project or organization
  cache             Cache management operations
  types             Type registry operations
  health            Health checks and diagnostics
  migrate           Migration from v2 to v3
```

### 11.2 Command Implementations

#### init

```typescript
class InitCommand implements CLICommand {
  name = 'init';
  description = 'Initialize codex configuration';

  options = [
    { name: '--org', description: 'Organization name' },
    { name: '--codex', description: 'Codex repository' },
    { name: '--mcp', description: 'Register MCP server', type: 'boolean' }
  ];

  async execute(options: InitOptions): Promise<void> {
    // 1. Auto-detect organization from git remote
    // 2. Create configuration file
    // 3. Initialize cache directory
    // 4. Register MCP server if requested
    // 5. Validate setup
  }
}
```

#### fetch

```typescript
class FetchCommand implements CLICommand {
  name = 'fetch';
  description = 'Fetch a document from codex';

  options = [
    { name: '--force-refresh', description: 'Bypass cache' },
    { name: '--ttl', description: 'Override TTL (seconds)' },
    { name: '--output', description: 'Output format (content|json)' }
  ];

  async execute(uri: string, options: FetchOptions): Promise<void> {
    // 1. Parse and validate URI
    // 2. Check cache (unless force-refresh)
    // 3. Fetch from source if needed
    // 4. Store in cache
    // 5. Output content
  }
}
```

#### sync

```typescript
class SyncCommand implements CLICommand {
  name = 'sync';
  description = 'Sync with codex repository';

  subcommands = ['project', 'org'];

  options = [
    { name: '--to-codex', description: 'Sync to codex' },
    { name: '--from-codex', description: 'Sync from codex' },
    { name: '--bidirectional', description: 'Bidirectional sync' },
    { name: '--env', description: 'Target environment' },
    { name: '--dry-run', description: 'Preview changes' }
  ];
}
```

#### cache

```typescript
class CacheCommand implements CLICommand {
  name = 'cache';
  description = 'Cache management';

  subcommands = ['list', 'clear', 'stats'];

  // cache list
  async list(options: CacheListOptions): Promise<void>;

  // cache clear
  async clear(options: CacheClearOptions): Promise<void>;

  // cache stats
  async stats(): Promise<void>;
}
```

#### types

```typescript
class TypesCommand implements CLICommand {
  name = 'types';
  description = 'Manage artifact types';

  subcommands = ['list', 'add', 'remove', 'show'];

  // types list
  async list(): Promise<void>;

  // types add <name> --patterns <patterns> --ttl <seconds>
  async add(name: string, options: AddTypeOptions): Promise<void>;

  // types show <name>
  async show(name: string): Promise<void>;
}
```

#### health

```typescript
class HealthCommand implements CLICommand {
  name = 'health';
  description = 'Health checks and diagnostics';

  options = [
    { name: '--check', description: 'Specific check (cache|config|mcp)' },
    { name: '--fix', description: 'Auto-repair issues' },
    { name: '--verbose', description: 'Detailed output' }
  ];

  async execute(options: HealthOptions): Promise<void> {
    // Run health checks:
    // - Cache index validity
    // - Configuration validation
    // - MCP server status
    // - Storage accessibility
    // - Network connectivity
  }
}
```

---

## 12. Configuration

### 12.1 Configuration Schema

```typescript
interface CodexConfig {
  version: '3.0';
  organization: string;
  projectName?: string;
  codexRepo: string;

  cache: {
    defaultTtl: number;         // Default: 604800 (7 days)
    checkExpiration: boolean;   // Default: true
    fallbackToStale: boolean;   // Default: true
    offlineMode: boolean;       // Default: false
    maxSizeMb: number;          // Default: 0 (unlimited)
    autoCleanup: boolean;       // Default: true
    cleanupIntervalDays: number; // Default: 7
  };

  auth: {
    default: 'inherit' | 'env' | 'config';
    fallbackToPublic: boolean;
  };

  sources: Record<string, SourceConfig>;

  types: {
    custom: Record<string, ArtifactType>;
  };

  storage: {
    providers: Record<string, StorageProviderConfig>;
    routing: Record<string, string>;
  };

  environments: Record<string, EnvironmentConfig>;

  syncPatterns: string[];
  excludePatterns: string[];
  syncDirection: 'to-codex' | 'from-codex' | 'bidirectional';

  logging: {
    enabled: boolean;
    logFile: string;
    level: 'debug' | 'info' | 'warn' | 'error';
  };
}
```

### 12.2 Configuration File Locations

```
Project configuration:    .fractary/plugins/codex/config.json
Cache directory:          .fractary/plugins/codex/cache/
Cache index:              .fractary/plugins/codex/cache/index.json
Logs:                     .fractary/plugins/codex/logs/
```

### 12.3 Example Configuration

```json
{
  "version": "3.0",
  "organization": "fractary",
  "projectName": "my-project",
  "codexRepo": "codex.fractary.com",

  "cache": {
    "defaultTtl": 604800,
    "checkExpiration": true,
    "fallbackToStale": true,
    "offlineMode": false,
    "maxSizeMb": 500,
    "autoCleanup": true,
    "cleanupIntervalDays": 7
  },

  "auth": {
    "default": "inherit",
    "fallbackToPublic": true
  },

  "sources": {
    "fractary": {
      "type": "github-org",
      "ttl": 1209600
    },
    "partner-org": {
      "type": "github-org",
      "tokenEnv": "PARTNER_TOKEN"
    }
  },

  "types": {
    "custom": {
      "research": {
        "description": "Research notes",
        "patterns": ["research/**"],
        "defaultTtl": 604800,
        "archiveAfterDays": 90,
        "archiveStorage": "cloud"
      }
    }
  },

  "storage": {
    "providers": {
      "local": {
        "type": "local",
        "basePath": ".fractary/plugins/codex/cache"
      },
      "archive": {
        "type": "s3",
        "bucket": "codex-archive",
        "region": "us-east-1"
      }
    },
    "routing": {
      "default": "local",
      "archive": "archive"
    }
  },

  "environments": {
    "dev": { "branch": "test" },
    "test": { "branch": "test" },
    "staging": { "branch": "main" },
    "prod": { "branch": "main" }
  },

  "syncPatterns": ["docs/**", "standards/**", "CLAUDE.md"],
  "excludePatterns": ["**/.git/**", "**/node_modules/**"],
  "syncDirection": "bidirectional"
}
```

---

## 13. Error Handling

### 13.1 Error Types

```typescript
// Base error
class CodexError extends Error {
  code: string;
  context?: Record<string, any>;
}

// Reference errors
class InvalidReferenceError extends CodexError {
  code = 'INVALID_REFERENCE';
}

class ReferenceNotFoundError extends CodexError {
  code = 'REFERENCE_NOT_FOUND';
}

// Cache errors
class CacheError extends CodexError {
  code = 'CACHE_ERROR';
}

class CacheIndexCorruptError extends CodexError {
  code = 'CACHE_INDEX_CORRUPT';
}

// Storage errors
class StorageError extends CodexError {
  code = 'STORAGE_ERROR';
}

class StorageProviderNotFoundError extends CodexError {
  code = 'STORAGE_PROVIDER_NOT_FOUND';
}

// Sync errors
class SyncError extends CodexError {
  code = 'SYNC_ERROR';
}

class SyncAuthenticationError extends CodexError {
  code = 'SYNC_AUTH_ERROR';
}

// Permission errors
class PermissionDeniedError extends CodexError {
  code = 'PERMISSION_DENIED';
}

// Configuration errors
class ConfigurationError extends CodexError {
  code = 'CONFIG_ERROR';
}

class ConfigurationNotFoundError extends CodexError {
  code = 'CONFIG_NOT_FOUND';
}
```

### 13.2 Error Handling Patterns

```typescript
// Structured error responses
interface ErrorResponse {
  success: false;
  error: {
    code: string;
    message: string;
    context?: Record<string, any>;
  };
  suggestions?: string[];
}

// Example error handling
try {
  const content = await codex.fetch(uri);
} catch (error) {
  if (error instanceof ReferenceNotFoundError) {
    return {
      success: false,
      error: {
        code: error.code,
        message: error.message,
        context: { uri: error.context?.uri }
      },
      suggestions: [
        'Check if the reference URI is correct',
        'Verify the project exists in the organization',
        'Run /codex sync --from-codex to populate cache'
      ]
    };
  }
  throw error;
}
```

---

## 14. Performance Targets

### 14.1 Latency Targets

| Operation | Target | Description |
|-----------|--------|-------------|
| Cache hit | < 100ms | Read from local cache |
| Cache miss | < 2s | Fetch from GitHub via sparse checkout |
| Permission check | < 50ms | Frontmatter parsing and pattern matching |
| Cache index lookup | < 10ms | Index search operation |
| MCP resource list | < 200ms | List all cached resources |
| Type detection | < 5ms | Detect artifact type from path |

### 14.2 Storage Targets

| Metric | Target |
|--------|--------|
| Default cache size limit | Unlimited (configurable) |
| Maximum single file | 10MB |
| Cache index entries | 10,000+ |
| Concurrent operations | 10 parallel |

---

## 15. Testing Strategy

### 15.1 Test Categories

```
tests/
├── unit/
│   ├── references/       # URI parsing, resolution
│   ├── types/            # Type registry
│   ├── cache/            # Cache operations
│   ├── storage/          # Storage providers
│   └── permissions/      # Permission checking
├── integration/
│   ├── sync/             # Sync with GitHub
│   ├── mcp/              # MCP server
│   └── storage/          # Cloud storage
└── e2e/
    ├── cli/              # CLI commands
    └── workflow/         # Full workflows
```

### 15.2 Test Requirements

- Unit test coverage: > 80%
- Integration tests for all sync handlers
- E2E tests for CLI commands
- MCP server protocol compliance tests
- Performance benchmarks for cache operations

---

## 16. Dependencies

### 16.1 Runtime Dependencies

```json
{
  "dependencies": {
    "@modelcontextprotocol/sdk": "^0.5.0",
    "glob": "^10.0.0",
    "yaml": "^2.0.0",
    "zod": "^3.22.0"
  }
}
```

### 16.2 Optional Dependencies

```json
{
  "optionalDependencies": {
    "@aws-sdk/client-s3": "^3.0.0",
    "@google-cloud/storage": "^7.0.0",
    "googleapis": "^130.0.0"
  }
}
```

### 16.3 Peer Dependencies

```json
{
  "peerDependencies": {
    "typescript": "^5.0.0"
  }
}
```

---

## 17. Changelog

| Version | Date | Changes |
|---------|------|---------|
| 0.1.0 | 2025-12-11 | Initial draft specification |

---

## 18. Open Questions

1. **Vector Store Integration**: Should the SDK include built-in vector database support for semantic search, or leave this to a separate package?

2. **Real-Time Sync**: Should WebSocket-based real-time sync be included in v1.0, or deferred to a later version?

3. **Multi-Organization**: How should cross-organization references and permissions work for enterprise deployments?

4. **Encryption**: Should the SDK provide built-in encryption for sensitive artifacts in cloud storage?

---

## 19. References

- [fractary-codex Plugin](../plugins/codex/README.md)
- [MCP Integration Guide](../plugins/codex/docs/MCP-INTEGRATION.md)
- [Model Context Protocol](https://modelcontextprotocol.io)
- [SPEC-00023: FABER SDK](./SPEC-00023-faber-sdk.md)
