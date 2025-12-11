# SPEC-00016: SDK Architecture & Core Interfaces

| Field | Value |
|-------|-------|
| **Status** | Draft |
| **Created** | 2025-12-11 |
| **Author** | Claude (with human direction) |
| **Related** | SPEC-00015-faber-orchestrator, SPEC-00023-faber-sdk, SPEC-00024-codex-sdk |

## 1. Executive Summary

This specification defines the **Fractary SDK Architecture**, establishing the foundational interfaces, layer boundaries, and contracts for the SDK ecosystem. It describes the **two-SDK architecture** where `@fractary/faber` and `@fractary/codex` are independent packages with no compile-time dependencies, unified by a common CLI layer.

### 1.1 Scope

This document covers:
- Three-layer architecture (SDK → CLI → Plugins)
- Two independent SDKs: `@fractary/faber` (development toolkit) and `@fractary/codex` (knowledge infrastructure)
- Future SDKs: `@fractary/helm` (governance) and `@fractary/forge` (authoring)
- FABER SDK interfaces (`WorkProvider`, `RepoProvider`, `FileStorage`, `SpecProvider`, `LogProvider`, `LLMProvider`)
- Codex SDK interface summary (full details in SPEC-00024)
- Configuration schema and loading patterns
- CLI command structure and routing (`@fractary/cli`)
- Error hierarchy and handling patterns
- What remains in `claude-plugins` after migration
- Migration path from plugins to SDK/CLI

### 1.2 Design Goals

1. **Independent SDKs** - No compile-time dependencies between `@fractary/faber` and `@fractary/codex`
2. **Runtime Integration** - Optional cross-SDK features via runtime detection
3. **Provider Agnostic** - Single interface, multiple implementations (GitHub/Jira/Linear, GitHub/GitLab/Bitbucket, S3/R2/GCS)
4. **CLI-First** - All functionality accessible via unified `fractary` CLI
5. **SDK-Composable** - TypeScript and Python SDKs for programmatic access
6. **Plugin-Compatible** - Claude Code plugins become thin CLI wrappers
7. **Configuration-Driven** - Behavior determined by config files, not code

## 2. Three-Layer Architecture

### 2.1 Layer Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Layer 3: Claude Code Plugins                     │
│  /fractary-work:issue-fetch  /fractary-repo:commit  /fractary-faber:run  │
│                                                                     │
│  Purpose: Claude-specific UX, natural language routing              │
│  Implementation: Thin wrappers that invoke CLI or SDK               │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ invokes
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Layer 2: Fractary CLI                            │
│  fractary work issue fetch    fractary repo commit                  │
│  fractary faber run           fractary logs capture                 │
│                                                                     │
│  Purpose: User-facing commands, argument parsing, output formatting │
│  Implementation: Delegates to SDK, handles I/O                      │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ uses
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Layer 1: SDK Packages                            │
│  @fractary/faber: WorkProvider, RepoProvider, FileStorage,          │
│                   SpecProvider, LogProvider, WorkflowEngine         │
│  @fractary/codex: CodexClient, StorageProvider, TypeRegistry,       │
│                   CacheManager, SyncEngine, MCPServer               │
│                                                                     │
│  Purpose: Programmable API, provider implementations, business logic│
│  Implementation: TypeScript + Python packages (independent SDKs)    │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Layer Responsibilities

| Layer | Responsibility | Does NOT Do |
|-------|---------------|-------------|
| **SDK** | Business logic, provider adapters, state management | User I/O, argument parsing, formatting |
| **CLI** | Argument parsing, output formatting, user prompts | Business logic, API calls |
| **Plugins** | Claude UX, natural language routing, context preservation | Direct API calls, business logic |

### 2.3 Data Flow Example

```
User types: /fractary-repo:commit "Add feature"

1. Plugin Layer (commands/commit.md):
   - Parses natural language arguments
   - Routes to CLI: `fractary repo commit "Add feature"`

2. CLI Layer (cli/src/tools/repo/commands/commit.ts):
   - Parses --type, --work-id, --scope flags
   - Loads configuration
   - Calls SDK: repoProvider.commit({ message, type, workId })

3. SDK Layer (@fractary/core/repo/github.ts):
   - Executes git operations
   - Formats commit message
   - Returns result: { sha, message, branch }

4. Response flows back up:
   - SDK → CLI (formats output)
   - CLI → Plugin (displays to user)
   - Plugin → Claude (natural language confirmation)
```

## 3. SDK Package Structure

### 3.1 Package Overview

The Fractary ecosystem uses **independent SDKs** with no compile-time dependencies between them. This enables:
- Standalone usage of either SDK
- Runtime detection for optional cross-SDK features
- Simpler dependency management and versioning

| Package | npm | Purpose | Dependencies |
|---------|-----|---------|--------------|
| `@fractary/faber` | `@fractary/faber` | Development toolkit: work tracking, repo operations, specs, logs, state, workflow | External only |
| `@fractary/codex` | `@fractary/codex` | Knowledge infrastructure: references, types, storage, caching, sync, MCP | External only |
| `@fractary/cli` | `@fractary/cli` | Command-line interface exposing all SDK functionality | `@fractary/faber`, `@fractary/codex` |
| `@fractary/helm` | `@fractary/helm` | Runtime monitoring, evaluation, governance | Future SDK |
| `@fractary/forge` | `@fractary/forge` | Authoring tools for primitives and bundles | Future SDK |

**Key Design Principle**: `@fractary/faber` and `@fractary/codex` have **no compile-time dependencies** on each other. When FABER needs Codex features (e.g., spec archival), it uses runtime detection:

```typescript
// Runtime detection pattern
const codex = await tryRequire('@fractary/codex');
if (codex) {
  await codex.archive(spec);
} else {
  // Graceful fallback to local-only operation
}
```

### 3.2 @fractary/faber Internal Structure

The FABER SDK is a standalone development toolkit containing all primitives needed for AI-assisted development workflows.

```
@fractary/faber/
├── types/              # Common types (Result, Maybe, Logger)
├── errors/             # Error class hierarchy
├── config/             # Configuration loading and validation
├── providers/          # LLM providers (Anthropic, OpenAI, Google, Ollama)
├── work/               # Work tracking (GitHub, Jira, Linear)
├── repo/               # Repository operations (Git, GitHub, GitLab, Bitbucket)
├── file/               # File storage (Local, S3, R2, GCS, Google Drive)
├── spec/               # Specification management
├── logs/               # Log management
├── state/              # Workflow state persistence
├── workflow/           # FABER workflow engine (Frame, Architect, Build, Evaluate, Release)
└── tools/              # Tool executor framework
```

### 3.3 @fractary/codex Internal Structure

The Codex SDK is a standalone knowledge infrastructure for cross-project memory and document management.

```
@fractary/codex/
├── types/              # Common types and interfaces
├── errors/             # Codex-specific error hierarchy
├── config/             # Configuration loading
├── references/         # Universal reference system (codex://{org}/{project}/{path})
├── registry/           # Extensible type registry (built-in + custom types)
├── storage/            # Storage abstraction layer (Local, S3, R2, GCS, Google Drive)
├── cache/              # Intelligent caching with TTL (<100ms cache hit)
├── sync/               # Bidirectional synchronization engine
├── mcp/                # MCP server for knowledge access
├── permissions/        # Frontmatter-based access control
└── migration/          # v2→v3 migration utilities
```

See [SPEC-00024: Codex SDK](./SPEC-00024-codex-sdk.md) for comprehensive details.

### 3.4 @fractary/cli Internal Structure

The CLI is the unified command-line interface that consumes both SDKs and exposes all functionality to users.

```
@fractary/cli/
├── commands/
│   ├── work/           # fractary work issue|comment|label|milestone
│   ├── repo/           # fractary repo branch|commit|pr|tag|worktree
│   ├── file/           # fractary file upload|download|list
│   ├── spec/           # fractary spec create|refine|validate|archive
│   ├── logs/           # fractary logs capture|write|search|archive
│   ├── faber/          # fractary faber init|run|status|plan
│   └── codex/          # fractary codex fetch|sync|cache|validate
├── formatters/         # Output formatting (json, table, plain)
├── config/             # CLI configuration management
└── utils/              # Shared CLI utilities
```

## 4. SDK Interfaces

This section defines the interfaces for both SDKs. Each SDK has independent interfaces with no cross-dependencies.

### 4.0 Interface Ownership Summary

| Interface | SDK | Purpose |
|-----------|-----|---------|
| `WorkProvider` | `@fractary/faber` | Work item tracking (GitHub Issues, Jira, Linear) |
| `RepoProvider` | `@fractary/faber` | Repository operations (Git, GitHub, GitLab, Bitbucket) |
| `FileStorage` | `@fractary/faber` | File storage operations (Local, S3, R2, GCS, Drive) |
| `SpecProvider` | `@fractary/faber` | Specification management |
| `LogProvider` | `@fractary/faber` | Log management and retention |
| `LLMProvider` | `@fractary/faber` | LLM provider abstraction |
| `WorkflowEngine` | `@fractary/faber` | FABER workflow orchestration |
| `CodexClient` | `@fractary/codex` | Main client for knowledge operations |
| `StorageProvider` | `@fractary/codex` | Storage abstraction for Codex |
| `TypeRegistry` | `@fractary/codex` | Extensible artifact type system |
| `CacheManager` | `@fractary/codex` | Intelligent caching with TTL |
| `SyncEngine` | `@fractary/codex` | Bidirectional synchronization |
| `MCPServer` | `@fractary/codex` | MCP server for knowledge access |

**Note**: The `@fractary/codex` interfaces are fully specified in [SPEC-00024: Codex SDK](./SPEC-00024-codex-sdk.md). This document focuses on `@fractary/faber` interfaces.

---

## 4.1 FABER SDK Interfaces

### 4.1.1 Common Types

```typescript
// types/common.ts

/** Result type for operations that can fail */
export type Result<T, E = Error> =
  | { success: true; value: T }
  | { success: false; error: E };

/** Async result */
export type AsyncResult<T, E = Error> = Promise<Result<T, E>>;

/** Optional value wrapper */
export type Maybe<T> = T | null | undefined;

/** Pagination for list operations */
export interface Pagination {
  limit?: number;
  offset?: number;
  cursor?: string;
}

/** Paginated response */
export interface PaginatedResult<T> {
  items: T[];
  total: number;
  hasMore: boolean;
  nextCursor?: string;
}

/** Logger interface */
export interface Logger {
  debug(message: string, meta?: Record<string, unknown>): void;
  info(message: string, meta?: Record<string, unknown>): void;
  warn(message: string, meta?: Record<string, unknown>): void;
  error(message: string, meta?: Record<string, unknown>): void;
}

/** Event emitter interface */
export interface EventEmitter<Events extends Record<string, unknown>> {
  on<K extends keyof Events>(event: K, handler: (data: Events[K]) => void): void;
  off<K extends keyof Events>(event: K, handler: (data: Events[K]) => void): void;
  emit<K extends keyof Events>(event: K, data: Events[K]): void;
}
```

### 4.1.2 Error Hierarchy

```typescript
// errors/base.ts

/** Base error for all Fractary errors */
export class FractaryError extends Error {
  readonly code: string;
  readonly context?: Record<string, unknown>;

  constructor(message: string, code: string, context?: Record<string, unknown>) {
    super(message);
    this.name = 'FractaryError';
    this.code = code;
    this.context = context;
  }
}

// errors/config.ts
export class ConfigurationError extends FractaryError {
  constructor(message: string, context?: Record<string, unknown>) {
    super(message, 'CONFIG_ERROR', context);
    this.name = 'ConfigurationError';
  }
}

// errors/validation.ts
export class ValidationError extends FractaryError {
  readonly path: string[];
  readonly value: unknown;

  constructor(message: string, path: string[], value: unknown) {
    super(message, 'VALIDATION_ERROR', { path, value });
    this.name = 'ValidationError';
    this.path = path;
    this.value = value;
  }
}

// errors/provider.ts
export class ProviderError extends FractaryError {
  readonly provider: string;
  readonly operation: string;

  constructor(
    message: string,
    provider: string,
    operation: string,
    context?: Record<string, unknown>
  ) {
    super(message, 'PROVIDER_ERROR', { ...context, provider, operation });
    this.name = 'ProviderError';
    this.provider = provider;
    this.operation = operation;
  }
}

// errors/not-found.ts
export class NotFoundError extends FractaryError {
  readonly resourceType: string;
  readonly resourceId: string;

  constructor(resourceType: string, resourceId: string) {
    super(`${resourceType} not found: ${resourceId}`, 'NOT_FOUND', { resourceType, resourceId });
    this.name = 'NotFoundError';
    this.resourceType = resourceType;
    this.resourceId = resourceId;
  }
}

// errors/authentication.ts
export class AuthenticationError extends FractaryError {
  readonly provider: string;

  constructor(provider: string, message?: string) {
    super(message || `Authentication failed for ${provider}`, 'AUTH_ERROR', { provider });
    this.name = 'AuthenticationError';
    this.provider = provider;
  }
}

// errors/rate-limit.ts
export class RateLimitError extends FractaryError {
  readonly provider: string;
  readonly retryAfter?: number;

  constructor(provider: string, retryAfter?: number) {
    super(`Rate limit exceeded for ${provider}`, 'RATE_LIMIT', { provider, retryAfter });
    this.name = 'RateLimitError';
    this.provider = provider;
    this.retryAfter = retryAfter;
  }
}
```

### 4.1.3 WorkProvider Interface

```typescript
// work/types.ts

export interface WorkProvider {
  readonly name: string;  // 'github' | 'jira' | 'linear'

  // === Issue Operations ===

  /** Fetch a work item by ID */
  getWorkItem(id: string): Promise<WorkItem>;

  /** Create a new work item */
  createWorkItem(input: CreateWorkItemInput): Promise<WorkItem>;

  /** Update an existing work item */
  updateWorkItem(id: string, updates: UpdateWorkItemInput): Promise<WorkItem>;

  /** Search work items */
  searchWorkItems(query: WorkItemQuery): Promise<PaginatedResult<WorkItem>>;

  /** List work items with filters */
  listWorkItems(filters: WorkItemFilters): Promise<PaginatedResult<WorkItem>>;

  // === State Management ===

  /** Close a work item */
  closeWorkItem(id: string, comment?: string): Promise<WorkItem>;

  /** Reopen a work item */
  reopenWorkItem(id: string, comment?: string): Promise<WorkItem>;

  /** Transition work item to state */
  transitionWorkItem(id: string, state: string): Promise<WorkItem>;

  // === Assignment ===

  /** Assign work item to user */
  assignWorkItem(id: string, assignee: string): Promise<WorkItem>;

  /** Unassign work item */
  unassignWorkItem(id: string, assignee?: string): Promise<WorkItem>;

  // === Comments ===

  /** Add comment to work item */
  addComment(workItemId: string, comment: string, metadata?: CommentMetadata): Promise<Comment>;

  /** List comments on work item */
  listComments(workItemId: string, options?: ListCommentsOptions): Promise<PaginatedResult<Comment>>;

  // === Labels ===

  /** Add label to work item */
  addLabel(workItemId: string, label: string): Promise<void>;

  /** Remove label from work item */
  removeLabel(workItemId: string, label: string): Promise<void>;

  /** Set all labels on work item (replaces existing) */
  setLabels(workItemId: string, labels: string[]): Promise<void>;

  /** List available labels */
  listLabels(): Promise<Label[]>;

  // === Milestones ===

  /** Create milestone */
  createMilestone(input: CreateMilestoneInput): Promise<Milestone>;

  /** Update milestone */
  updateMilestone(id: string, updates: UpdateMilestoneInput): Promise<Milestone>;

  /** Assign work item to milestone */
  assignMilestone(workItemId: string, milestoneId: string): Promise<WorkItem>;

  /** Remove work item from milestone */
  removeMilestone(workItemId: string): Promise<WorkItem>;

  /** List milestones */
  listMilestones(filters?: MilestoneFilters): Promise<PaginatedResult<Milestone>>;

  // === Classification ===

  /** Classify work item type */
  classifyWorkItem(workItem: WorkItem): WorkType;
}

// === Data Types ===

export interface WorkItem {
  id: string;
  key: string;              // e.g., "PROJ-123" or "#123"
  title: string;
  description: string;
  status: string;
  state: 'open' | 'in_progress' | 'in_review' | 'done' | 'closed';
  type: WorkType;
  labels: string[];
  assignee?: string;
  assignees?: string[];
  reporter?: string;
  milestone?: string;
  createdAt: Date;
  updatedAt: Date;
  closedAt?: Date;
  url: string;
  metadata?: Record<string, unknown>;
}

export type WorkType = 'feature' | 'bug' | 'chore' | 'patch' | 'task' | 'story' | 'epic';

export interface CreateWorkItemInput {
  title: string;
  description?: string;
  type?: WorkType;
  labels?: string[];
  assignees?: string[];
  milestone?: string;
}

export interface UpdateWorkItemInput {
  title?: string;
  description?: string;
  labels?: string[];
  assignees?: string[];
  milestone?: string;
}

export interface WorkItemQuery {
  query: string;
  limit?: number;
}

export interface WorkItemFilters {
  state?: 'open' | 'closed' | 'all';
  labels?: string[];
  assignee?: string;
  milestone?: string;
  limit?: number;
  since?: Date;
}

export interface Comment {
  id: string;
  body: string;
  author: string;
  createdAt: Date;
  updatedAt: Date;
  url: string;
}

export interface CommentMetadata {
  workId?: string;
  authorContext?: 'frame' | 'architect' | 'build' | 'evaluate' | 'release' | 'ops';
}

export interface Label {
  name: string;
  color?: string;
  description?: string;
}

export interface Milestone {
  id: string;
  title: string;
  description?: string;
  dueDate?: Date;
  state: 'open' | 'closed';
  url: string;
}
```

### 4.1.4 RepoProvider Interface

```typescript
// repo/types.ts

export interface RepoProvider {
  readonly name: string;  // 'github' | 'gitlab' | 'bitbucket'

  // === Branch Operations ===

  /** Get current branch */
  getCurrentBranch(): Promise<string>;

  /** Create a branch */
  createBranch(name: string, options?: CreateBranchOptions): Promise<Branch>;

  /** Delete a branch */
  deleteBranch(name: string, options?: DeleteBranchOptions): Promise<void>;

  /** List branches */
  listBranches(filters?: BranchFilters): Promise<PaginatedResult<Branch>>;

  /** Checkout branch */
  checkoutBranch(name: string): Promise<void>;

  /** Generate semantic branch name */
  generateBranchName(description: string, options?: BranchNameOptions): string;

  // === Commit Operations ===

  /** Create a commit */
  commit(input: CreateCommitInput): Promise<Commit>;

  /** Get commit details */
  getCommit(sha: string): Promise<Commit>;

  /** List commits */
  listCommits(options?: ListCommitsOptions): Promise<PaginatedResult<Commit>>;

  /** Get diff */
  getDiff(options?: DiffOptions): Promise<string>;

  // === Push/Pull Operations ===

  /** Push to remote */
  push(options?: PushOptions): Promise<void>;

  /** Pull from remote */
  pull(options?: PullOptions): Promise<void>;

  // === Pull Request Operations ===

  /** Create pull request */
  createPullRequest(input: CreatePRInput): Promise<PullRequest>;

  /** Get pull request */
  getPullRequest(number: number): Promise<PullRequest>;

  /** List pull requests */
  listPullRequests(filters?: PRFilters): Promise<PaginatedResult<PullRequest>>;

  /** Add comment to pull request */
  commentOnPullRequest(number: number, comment: string): Promise<Comment>;

  /** Review pull request */
  reviewPullRequest(number: number, review: PRReview): Promise<void>;

  /** Merge pull request */
  mergePullRequest(number: number, options?: MergeOptions): Promise<void>;

  /** Analyze pull request */
  analyzePullRequest(number: number): Promise<PRAnalysis>;

  // === Tag Operations ===

  /** Create tag */
  createTag(input: CreateTagInput): Promise<Tag>;

  /** Push tag */
  pushTag(tagName: string, options?: PushTagOptions): Promise<void>;

  /** List tags */
  listTags(filters?: TagFilters): Promise<PaginatedResult<Tag>>;

  // === Worktree Operations ===

  /** Create worktree */
  createWorktree(branch: string, options?: WorktreeOptions): Promise<Worktree>;

  /** List worktrees */
  listWorktrees(): Promise<Worktree[]>;

  /** Remove worktree */
  removeWorktree(branch: string, options?: RemoveWorktreeOptions): Promise<void>;

  /** Cleanup stale worktrees */
  cleanupWorktrees(options?: CleanupWorktreeOptions): Promise<WorktreeCleanupResult>;

  // === Status ===

  /** Get repository status */
  getStatus(): Promise<RepoStatus>;

  /** Check if branch is protected */
  isProtectedBranch(branch: string): Promise<boolean>;
}

// === Data Types ===

export interface Branch {
  name: string;
  sha: string;
  isDefault: boolean;
  isProtected: boolean;
  upstream?: string;
  lastCommitDate?: Date;
}

export interface CreateBranchOptions {
  baseBranch?: string;
  checkout?: boolean;
  worktree?: boolean;
  workId?: string;
  prefix?: string;
}

export interface DeleteBranchOptions {
  location?: 'local' | 'remote' | 'both';
  force?: boolean;
  cleanupWorktree?: boolean;
}

export interface BranchFilters {
  merged?: boolean;
  stale?: boolean;
  staleDays?: number;
  pattern?: string;
}

export interface BranchNameOptions {
  prefix?: string;
  workId?: string;
}

export interface Commit {
  sha: string;
  message: string;
  author: string;
  authorEmail: string;
  date: Date;
  parents: string[];
}

export interface CreateCommitInput {
  message: string;
  type?: 'feat' | 'fix' | 'chore' | 'docs' | 'test' | 'refactor' | 'style' | 'perf';
  scope?: string;
  workId?: string;
  authorContext?: string;
  breaking?: boolean;
  description?: string;
  allowEmpty?: boolean;
}

export interface ListCommitsOptions {
  branch?: string;
  since?: Date;
  until?: Date;
  author?: string;
  limit?: number;
}

export interface DiffOptions {
  staged?: boolean;
  base?: string;
  head?: string;
}

export interface PushOptions {
  branch?: string;
  remote?: string;
  setUpstream?: boolean;
  force?: boolean;
  forceWithLease?: boolean;
}

export interface PullOptions {
  branch?: string;
  remote?: string;
  rebase?: boolean;
  strategy?: 'merge' | 'rebase' | 'ff-only';
}

export interface PullRequest {
  number: number;
  title: string;
  body: string;
  state: 'open' | 'closed' | 'merged';
  draft: boolean;
  headBranch: string;
  baseBranch: string;
  author: string;
  url: string;
  createdAt: Date;
  updatedAt: Date;
  mergedAt?: Date;
  mergedBy?: string;
  reviewers?: string[];
  labels?: string[];
  checks?: CICheck[];
}

export interface CreatePRInput {
  title: string;
  body?: string;
  headBranch?: string;
  baseBranch?: string;
  workId?: string;
  draft?: boolean;
  labels?: string[];
  reviewers?: string[];
}

export interface PRFilters {
  state?: 'open' | 'closed' | 'merged' | 'all';
  author?: string;
  baseBranch?: string;
  limit?: number;
}

export interface PRReview {
  action: 'approve' | 'request_changes' | 'comment';
  comment?: string;
}

export interface PRAnalysis {
  summary: string;
  filesChanged: number;
  additions: number;
  deletions: number;
  risks: string[];
  suggestions: string[];
  checksStatus: 'passing' | 'failing' | 'pending';
}

export interface MergeOptions {
  strategy?: 'merge' | 'squash' | 'rebase';
  deleteBranch?: boolean;
  cleanupWorktree?: boolean;
  commitMessage?: string;
}

export interface CICheck {
  name: string;
  status: 'success' | 'failure' | 'pending' | 'skipped';
  url?: string;
}

export interface Tag {
  name: string;
  sha: string;
  message?: string;
  tagger?: string;
  date: Date;
}

export interface CreateTagInput {
  name: string;
  message?: string;
  sha?: string;
  sign?: boolean;
  force?: boolean;
}

export interface PushTagOptions {
  remote?: string;
}

export interface TagFilters {
  pattern?: string;
  latest?: number;
}

export interface Worktree {
  path: string;
  branch: string;
  workId?: string;
  createdAt: Date;
  isLocked: boolean;
  hasChanges: boolean;
}

export interface WorktreeOptions {
  baseBranch?: string;
  workId?: string;
}

export interface RemoveWorktreeOptions {
  force?: boolean;
}

export interface CleanupWorktreeOptions {
  merged?: boolean;
  stale?: boolean;
  staleDays?: number;
  dryRun?: boolean;
}

export interface WorktreeCleanupResult {
  removed: string[];
  skipped: string[];
  errors: Array<{ path: string; error: string }>;
}

export interface RepoStatus {
  branch: string;
  ahead: number;
  behind: number;
  staged: string[];
  modified: string[];
  untracked: string[];
  hasChanges: boolean;
}
```

### 4.1.5 FileStorage Interface

```typescript
// file/types.ts

export interface FileStorage {
  readonly name: string;  // 'local' | 's3' | 'r2' | 'gcs' | 'gdrive'

  /** Upload file */
  upload(localPath: string, remotePath: string, options?: UploadOptions): Promise<UploadResult>;

  /** Download file */
  download(remotePath: string, localPath: string, options?: DownloadOptions): Promise<void>;

  /** Read file content without downloading */
  read(remotePath: string, options?: ReadOptions): Promise<string>;

  /** Delete file */
  delete(remotePath: string): Promise<void>;

  /** List files */
  list(remotePath: string, options?: ListOptions): Promise<FileInfo[]>;

  /** Get presigned URL */
  getUrl(remotePath: string, options?: GetUrlOptions): Promise<string>;

  /** Check if file exists */
  exists(remotePath: string): Promise<boolean>;

  /** Get file info */
  getInfo(remotePath: string): Promise<FileInfo>;
}

// === Data Types ===

export interface UploadOptions {
  public?: boolean;
  contentType?: string;
  metadata?: Record<string, string>;
}

export interface UploadResult {
  remotePath: string;
  url: string;
  size: number;
  contentType: string;
}

export interface DownloadOptions {
  maxBytes?: number;
}

export interface ReadOptions {
  maxBytes?: number;
  encoding?: 'utf-8' | 'base64';
}

export interface ListOptions {
  maxResults?: number;
  prefix?: string;
  recursive?: boolean;
}

export interface GetUrlOptions {
  expiresIn?: number;  // seconds
  download?: boolean;
}

export interface FileInfo {
  name: string;
  path: string;
  size: number;
  contentType: string;
  lastModified: Date;
  isDirectory: boolean;
}
```

### 4.1.6 SpecProvider Interface

```typescript
// spec/types.ts

export interface SpecProvider {
  /** Generate specification from context */
  generate(input: GenerateSpecInput): Promise<Spec>;

  /** Refine specification with user feedback */
  refine(specPath: string, options?: RefineOptions): Promise<RefineResult>;

  /** Validate implementation against specification */
  validate(specPath: string, options?: ValidateOptions): Promise<ValidationResult>;

  /** Archive specification to cloud storage */
  archive(issueNumber: string, options?: ArchiveOptions): Promise<ArchiveResult>;

  /** Read archived specification */
  read(issueNumber: string, options?: ReadSpecOptions): Promise<Spec>;

  /** List specifications */
  list(filters?: SpecFilters): Promise<Spec[]>;

  /** Update specification phase/tasks */
  update(specPath: string, updates: SpecUpdates): Promise<Spec>;

  /** Link specification to work item */
  link(specPath: string, workItemId: string): Promise<void>;
}

// === Data Types ===

export interface Spec {
  id: string;
  path: string;
  title: string;
  workId?: string;
  type: SpecType;
  status: SpecStatus;
  phases: SpecPhase[];
  createdAt: Date;
  updatedAt: Date;
  archivedAt?: Date;
  cloudUrl?: string;
}

export type SpecType = 'basic' | 'feature' | 'bug' | 'infrastructure' | 'api';

export type SpecStatus = 'draft' | 'in_progress' | 'complete' | 'archived';

export interface SpecPhase {
  id: string;
  name: string;
  status: 'not_started' | 'in_progress' | 'complete';
  tasks: SpecTask[];
  notes?: string[];
}

export interface SpecTask {
  description: string;
  completed: boolean;
}

export interface GenerateSpecInput {
  workId?: string;
  template?: SpecType;
  context?: string;
  force?: boolean;
}

export interface RefineOptions {
  prompt?: string;
  round?: number;
}

export interface RefineResult {
  questionsAsked: number;
  questionsAnswered: number;
  improvementsApplied: number;
  bestEffortDecisions: number;
  additionalRoundsRecommended: boolean;
}

export interface ValidateOptions {
  phase?: string;
}

export interface ValidationResult {
  status: 'complete' | 'partial' | 'incomplete';
  requirementsComplete: number;
  requirementsTotal: number;
  acceptanceCriteriaMet: number;
  acceptanceCriteriaTotal: number;
  filesModified: boolean;
  testsAdded: boolean;
  docsUpdated: boolean;
}

export interface ArchiveOptions {
  force?: boolean;
  skipWarnings?: boolean;
}

export interface ArchiveResult {
  archivedAt: Date;
  specs: Array<{
    localPath: string;
    cloudUrl: string;
    size: number;
  }>;
  indexUpdated: boolean;
  githubCommented: boolean;
  localCleaned: boolean;
}

export interface ReadSpecOptions {
  phase?: number;
}

export interface SpecFilters {
  workId?: string;
  status?: SpecStatus;
  type?: SpecType;
  archived?: boolean;
}

export interface SpecUpdates {
  phaseId: string;
  status?: 'not_started' | 'in_progress' | 'complete';
  checkTasks?: string[];
  checkAllTasks?: boolean;
  notes?: string[];
}
```

### 4.1.7 LogProvider Interface

```typescript
// logs/types.ts

export interface LogProvider {
  // === Session Capture ===

  /** Start session capture */
  startCapture(issueNumber: string, options?: CaptureOptions): Promise<Session>;

  /** Stop session capture */
  stopCapture(): Promise<Session>;

  /** Log explicit message */
  log(message: string, options?: LogMessageOptions): Promise<void>;

  /** Append to current session */
  append(content: string): Promise<void>;

  // === Log Writing ===

  /** Write typed log */
  write(type: LogType, title: string, data?: Record<string, unknown>): Promise<Log>;

  /** Classify content to log type */
  classify(content: string): Promise<ClassificationResult>;

  /** Validate log against schema */
  validate(logPath: string): Promise<ValidationResult>;

  // === Log Retrieval ===

  /** List logs */
  list(filters?: LogFilters): Promise<PaginatedResult<Log>>;

  /** Search logs */
  search(query: string, options?: SearchOptions): Promise<SearchResult>;

  /** Read log content */
  read(logPath: string): Promise<Log>;

  // === Analysis ===

  /** Analyze logs */
  analyze(type: AnalysisType, options?: AnalysisOptions): Promise<AnalysisResult>;

  /** Generate summary (AI-powered, optional) */
  summarize(logPath: string): Promise<Summary>;

  // === Archival ===

  /** Archive logs by retention policy */
  archive(options?: ArchiveLogOptions): Promise<ArchiveLogResult>;

  /** Cleanup old logs */
  cleanup(options?: CleanupOptions): Promise<CleanupResult>;

  // === Audit ===

  /** Audit logs in project */
  audit(options?: AuditOptions): Promise<AuditResult>;
}

// === Data Types ===

export type LogType =
  | 'session'      // Claude Code conversations
  | 'build'        // Build process logs
  | 'deployment'   // Infrastructure deployment
  | 'debug'        // Debug and diagnostic
  | 'test'         // Test execution
  | 'audit'        // Security/compliance
  | 'operational'  // System operational
  | '_untyped';    // Unclassified

export interface Log {
  id: string;
  path: string;
  type: LogType;
  title: string;
  status: 'active' | 'completed' | 'archived';
  issueNumber?: string;
  createdAt: Date;
  updatedAt: Date;
  archivedAt?: Date;
  cloudUrl?: string;
  size: number;
  metadata?: Record<string, unknown>;
}

export interface Session extends Log {
  type: 'session';
  sessionId: string;
  repository: string;
  branch: string;
  model: string;
  turns?: number;
  duration?: number;
  tokenCount?: number;
}

export interface CaptureOptions {
  redactSensitive?: boolean;
  model?: string;
}

export interface LogMessageOptions {
  issueNumber?: string;
  role?: 'user' | 'assistant' | 'system';
}

export interface ClassificationResult {
  recommendedType: LogType;
  confidence: number;
  reasons: string[];
}

export interface LogFilters {
  type?: LogType;
  status?: 'active' | 'completed' | 'archived';
  issueNumber?: string;
  since?: Date;
  until?: Date;
}

export interface SearchOptions {
  issueNumber?: string;
  type?: LogType;
  since?: Date;
  until?: Date;
  regex?: boolean;
  localOnly?: boolean;
  cloudOnly?: boolean;
}

export interface SearchResult {
  matches: Array<{
    log: Log;
    snippets: string[];
    lineNumbers: number[];
  }>;
  totalMatches: number;
  searchedLocal: boolean;
  searchedCloud: boolean;
}

export type AnalysisType = 'errors' | 'patterns' | 'session' | 'time';

export interface AnalysisOptions {
  issueNumber?: string;
  since?: Date;
  until?: Date;
  verbose?: boolean;
}

export interface AnalysisResult {
  type: AnalysisType;
  findings: Array<{
    category: string;
    count: number;
    details: string[];
  }>;
  summary: string;
}

export interface Summary {
  logId: string;
  accomplishments: string[];
  technicalDecisions: string[];
  filesModified: string[];
  issuesDiscussed: string[];
  learnings: string[];
}

export interface ArchiveLogOptions {
  type?: LogType;
  issueNumber?: string;
  trigger?: 'issue_closed' | 'pr_merged' | 'retention_expired' | 'manual';
  dryRun?: boolean;
}

export interface ArchiveLogResult {
  archived: Array<{
    localPath: string;
    cloudUrl: string;
    originalSize: number;
    compressedSize?: number;
  }>;
  skipped: Array<{ path: string; reason: string }>;
  indexUpdated: boolean;
}

export interface CleanupOptions {
  olderThanDays?: number;
  type?: LogType;
  dryRun?: boolean;
}

export interface CleanupResult {
  removed: string[];
  skipped: string[];
  spaceFreed: number;
}

export interface AuditOptions {
  execute?: boolean;
  verbose?: boolean;
}

export interface AuditResult {
  reportPath: string;
  specPath?: string;  // Remediation spec
  gaps: Array<{
    category: string;
    priority: 'high' | 'medium' | 'low';
    description: string;
    recommendation: string;
  }>;
  stats: {
    totalLogs: number;
    unmanagedLogs: number;
    logsInVcs: number;
    archivedCount: number;
    localStorageMb: number;
    cloudStorageMb: number;
  };
}

// === Retention Configuration ===

export interface RetentionPolicy {
  localDays: number | 'forever';
  cloudDays: number | 'forever';
  priority: 'low' | 'medium' | 'high' | 'critical';
  autoArchive: boolean;
  cleanupAfterArchive: boolean;
  exceptions?: RetentionExceptions;
  archiveTriggers?: ArchiveTriggers;
  compression?: CompressionConfig;
}

export interface RetentionExceptions {
  keepIfLinkedToOpenIssue?: boolean;
  keepIfReferencedInDocs?: boolean;
  keepRecentN?: number;
  neverDeleteProduction?: boolean;
  neverDeleteSecurityIncidents?: boolean;
  neverDeleteComplianceAudits?: boolean;
}

export interface ArchiveTriggers {
  ageDays?: number;
  sizeMb?: number;
  status?: string[];
}

export interface CompressionConfig {
  enabled: boolean;
  format: 'gzip' | 'zstd';
  thresholdMb: number;
}
```

### 4.1.8 LLMProvider Interface

```typescript
// providers/types.ts

export interface LLMProvider {
  readonly name: string;  // 'anthropic' | 'openai' | 'google' | 'ollama'
  readonly supportedModels: string[];

  /** Send completion request */
  complete(request: CompletionRequest): Promise<CompletionResponse>;

  /** Stream completion request */
  stream(request: CompletionRequest): AsyncIterable<StreamChunk>;

  /** Count tokens (estimate) */
  countTokens(messages: Message[]): Promise<number>;
}

// === Data Types ===

export interface CompletionRequest {
  model: string;
  messages: Message[];
  tools?: ToolDefinition[];
  temperature?: number;
  maxTokens?: number;
  stopSequences?: string[];
  systemPrompt?: string;
}

export interface CompletionResponse {
  id: string;
  model: string;
  content: ContentBlock[];
  stopReason: 'end_turn' | 'tool_use' | 'max_tokens' | 'stop_sequence';
  usage: TokenUsage;
}

export interface TokenUsage {
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens?: number;
  cacheWriteTokens?: number;
}

export interface Message {
  role: 'user' | 'assistant' | 'system';
  content: string | ContentBlock[];
}

export interface ContentBlock {
  type: 'text' | 'tool_use' | 'tool_result';
  text?: string;
  toolUseId?: string;
  toolName?: string;
  toolInput?: Record<string, unknown>;
  toolResult?: string | object;
  isError?: boolean;
}

export interface ToolDefinition {
  name: string;
  description: string;
  inputSchema: JSONSchema;
}

export interface StreamChunk {
  type: 'text_delta' | 'tool_use_start' | 'tool_use_delta' | 'message_stop';
  text?: string;
  toolUseId?: string;
  toolName?: string;
  toolInput?: string;  // Partial JSON
}

export type JSONSchema = Record<string, unknown>;
```

### 4.2 Codex SDK Interfaces

The Codex SDK interfaces are fully specified in [SPEC-00024: Codex SDK](./SPEC-00024-codex-sdk.md). Key interfaces include:

| Interface | Purpose |
|-----------|---------|
| `CodexClient` | Main client for all Codex operations |
| `StorageProvider` | Abstraction for storage backends (Local, S3, R2, GCS, Drive) |
| `TypeRegistry` | Extensible artifact type system with built-in + custom types |
| `CacheManager` | Intelligent caching with TTL and <100ms hit time |
| `SyncEngine` | Bidirectional synchronization between projects and Codex |
| `MCPServer` | MCP server exposing knowledge access tools |
| `PermissionManager` | Frontmatter-based access control system |

For complete interface definitions, see SPEC-00024 sections 5-11.

## 5. Configuration System

### 5.1 Configuration Hierarchy

```
1. Default values (built into SDK)
2. Global config (~/.config/fractary/{tool}/config.json)
3. Project config (.fractary/plugins/{tool}/config.json)
4. Environment variables (FRACTARY_*)
5. CLI arguments (--option value)
```

Higher numbers override lower numbers.

### 5.2 Configuration Loading

```typescript
// config/loader.ts

export interface ConfigLoader {
  /** Load configuration with full hierarchy */
  load<T>(schema: ConfigSchema<T>): Promise<T>;

  /** Get specific config value */
  get<T>(key: string, defaultValue?: T): T;

  /** Set config value (project level) */
  set(key: string, value: unknown): Promise<void>;

  /** Validate configuration */
  validate<T>(config: T, schema: ConfigSchema<T>): ValidationResult;
}

export interface ConfigSchema<T> {
  name: string;
  version: string;
  schema: JSONSchema;
  defaults: Partial<T>;
  envMapping?: Record<string, string>;  // config key → env var
}
```

### 5.3 Standard Configuration Paths

| Tool | Project Config | Global Config |
|------|---------------|---------------|
| work | `.fractary/plugins/work/config.json` | `~/.config/fractary/work/config.json` |
| repo | `.fractary/plugins/repo/config.json` | `~/.config/fractary/repo/config.json` |
| file | `.fractary/plugins/file/config.json` | `~/.config/fractary/file/config.json` |
| spec | `.fractary/plugins/spec/config.json` | `~/.config/fractary/spec/config.json` |
| logs | `.fractary/plugins/logs/config.json` | `~/.config/fractary/logs/config.json` |
| faber | `.fractary/plugins/faber/config.json` | `~/.config/fractary/faber/config.json` |
| codex | `.fractary/plugins/codex/config.json` | `~/.config/fractary/codex/config.json` |

**IMPORTANT**: Use flat structure (no subdirectory).
- Correct: `.fractary/plugins/work/config.json`
- Wrong: `.fractary/plugins/work/config/config.json`

## 6. CLI Command Structure

### 6.1 Command Pattern

```
fractary <tool> <resource> <action> [arguments] [options]
```

Examples:
```bash
fractary work issue fetch 123
fractary work issue create --title "Bug fix" --type bug
fractary repo branch create --description "Add feature" --work-id 123
fractary repo commit --message "Add feature" --type feat
fractary faber run --work-id 123 --autonomy guarded
fractary logs capture 123
fractary spec create --work-id 123
```

### 6.2 Command Mapping

| Plugin Command | CLI Command |
|---------------|-------------|
| `/fractary-work:issue-fetch 123` | `fractary work issue fetch 123` |
| `/fractary-work:issue-create` | `fractary work issue create` |
| `/fractary-work:comment-create 123 "msg"` | `fractary work comment create 123 "msg"` |
| `/fractary-repo:commit "msg"` | `fractary repo commit --message "msg"` |
| `/fractary-repo:branch-create "desc"` | `fractary repo branch create --description "desc"` |
| `/fractary-repo:pr-create "title"` | `fractary repo pr create --title "title"` |
| `/fractary-faber:run 123` | `fractary faber run --work-id 123` |
| `/fractary-spec:create` | `fractary spec create` |
| `/fractary-logs:capture 123` | `fractary logs capture 123` |

### 6.3 Common Options

All commands support:
- `--help` - Show help
- `--version` - Show version
- `--verbose` / `-v` - Verbose output
- `--quiet` / `-q` - Suppress output
- `--json` - Output as JSON
- `--config <path>` - Custom config path
- `--dry-run` - Show what would happen

## 7. Plugin Migration

### 7.1 What Moves to SDK

| Current Location | SDK Location | Notes |
|-----------------|--------------|-------|
| `plugins/work/skills/handler-*` | `@fractary/faber/work/` | Work tracking providers |
| `plugins/repo/skills/handler-*` | `@fractary/faber/repo/` | Repository providers |
| `plugins/file/skills/handler-*` | `@fractary/faber/file/` | File storage providers |
| `plugins/spec/skills/*` | `@fractary/faber/spec/` | Spec operations |
| `plugins/logs/skills/*` | `@fractary/faber/logs/` | Log operations |
| `plugins/faber/skills/*` | `@fractary/faber/workflow/` | Workflow engine |
| `plugins/codex/skills/*` | `@fractary/codex/` | Knowledge infrastructure (separate SDK) |
| All shell scripts | SDK implementations | TypeScript/Python |

**Note**: Codex operations move to the independent `@fractary/codex` SDK, not into `@fractary/faber`. See [SPEC-00024](./SPEC-00024-codex-sdk.md) for details.

### 7.2 What Stays in Plugins

| Component | Purpose |
|-----------|---------|
| Commands (`commands/*.md`) | Claude UX, natural language parsing |
| Agents (`agents/*.md`) | Claude workflow orchestration |
| Hooks (`hooks/`) | Claude Code event handling |
| Templates | Prompt templates for Claude |

### 7.3 Plugin Architecture Post-Migration

```
plugins/work/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   └── work-manager.md           # Routes to CLI commands
├── commands/
│   └── issue-fetch.md            # Invokes: fractary work issue fetch
└── hooks/
    └── hooks.json                # Claude Code hooks
```

**Agent becomes a thin router:**
```markdown
# work-manager.md

<WORKFLOW>
1. Parse user request
2. Map to CLI command
3. Execute: `fractary work <resource> <action> [args]`
4. Format response for Claude
</WORKFLOW>
```

### 7.4 Migration Timeline

1. **Phase 1**: Build `@fractary/faber` SDK with all development primitives (work, repo, file, spec, logs, workflow)
2. **Phase 2**: Build `@fractary/codex` SDK with knowledge infrastructure (references, types, storage, cache, sync, MCP)
3. **Phase 3**: Build `@fractary/cli` consuming both SDKs
4. **Phase 4**: Update plugins to invoke CLI instead of internal skills
5. **Phase 5**: Remove migrated skill implementations from plugins
6. **Future**: Build `@fractary/helm` (runtime governance) and `@fractary/forge` (authoring tools)

## 8. Testing Strategy

### 8.1 Test Levels

| Level | Location | Purpose |
|-------|----------|---------|
| Unit Tests | `packages/*/src/**/*.test.ts` | Individual functions |
| Integration Tests | `packages/*/tests/integration/` | Provider + API |
| Conformance Tests | `tests/conformance/` | Cross-language parity |
| E2E Tests | `tests/e2e/` | Full CLI workflows |

### 8.2 Conformance Testing

Ensures TypeScript and Python implementations behave identically:

```
tests/conformance/
├── work/
│   ├── get-work-item.json       # Input/output pairs
│   ├── create-work-item.json
│   └── ...
├── repo/
│   ├── create-branch.json
│   └── ...
└── runner.ts                     # Runs tests against both implementations
```

## 9. Versioning Strategy

### 9.1 Semantic Versioning

All packages follow semver:
- **Major**: Breaking interface changes
- **Minor**: New features, backward compatible
- **Patch**: Bug fixes

### 9.2 Version Coordination

- `@fractary/core` version drives ecosystem
- Other packages depend on core version range: `"@fractary/core": "^1.0.0"`
- CLI bundles specific versions of all packages

## 10. Security Considerations

### 10.1 Credential Management

- API keys from environment variables only
- Never logged or persisted
- Validated at provider initialization

### 10.2 Input Validation

- All user inputs validated before use
- Path traversal prevention
- Shell command allowlisting

### 10.3 Output Sanitization

- Sensitive data redacted in logs
- Error messages don't expose internals

## 11. References

### SDK Specifications
- [SPEC-00023: FABER SDK](./SPEC-00023-faber-sdk.md) - Consolidated FABER SDK specification
- [SPEC-00024: Codex SDK](./SPEC-00024-codex-sdk.md) - Consolidated Codex SDK specification
- [SPEC-00015: FABER Orchestrator](./SPEC-00015-faber-orchestrator.md) - Workflow engine details (being updated for two-SDK architecture)

### External Documentation
- [Anthropic API Documentation](https://docs.anthropic.com/en/api)
- [OpenAI API Documentation](https://platform.openai.com/docs/api-reference)
- [Commander.js Documentation](https://github.com/tj/commander.js)
