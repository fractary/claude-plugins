# SPEC-00023: FABER SDK

## Status: Draft
## Version: 1.0.0
## Last Updated: 2025-12-11

---

## 1. Executive Summary

This specification defines the FABER SDK (`@fractary/faber`) - a standalone development toolkit that provides work tracking, source control operations, specification management, logging, state management, and workflow orchestration. The SDK works independently without requiring any other Fractary packages, using local file storage by default.

### 1.1 Design Philosophy

**Standalone First**: FABER works completely on its own. All artifacts (specs, logs, state) are stored locally with direct file paths. No external dependencies required.

**Codex Enhancement Optional**: When `@fractary/codex` is installed and configured, FABER can delegate storage operations to Codex on a per-artifact-type basis. This is runtime integration, not compile-time dependency.

**Domain Logic Ownership**: FABER owns the *logic* of what to create, validate, and track. Codex (when enabled) takes over *where* things are stored, *when* they're archived, and *how* they're referenced.

### 1.2 Scope

**In Scope:**
- Work tracking (issues, labels, milestones, comments) across GitHub, Jira, Linear
- Repository operations (branches, commits, PRs, tags, worktrees) across GitHub, GitLab, Bitbucket
- Specification logic (creation, templates, validation, refinement)
- Log logic (session capture, log types, redaction, retention rules)
- State management (workflow state, run manifests)
- Workflow orchestration (FABER phases: Frame, Architect, Build, Evaluate, Release)
- LLM routing and model selection
- CLI commands for all operations

**Out of Scope:**
- Storage abstraction (Codex handles this when enabled)
- Universal references (Codex handles `codex://` URIs)
- Cross-project sync (Codex handles this)
- MCP server (Codex provides this)

### 1.3 References

- SPEC-00015: FABER Orchestrator Architecture (original vision)
- SPEC-00024: Codex SDK (companion spec)
- Plugin sources: `plugins/faber/`, `plugins/work/`, `plugins/repo/`

---

## 2. Architecture Overview

### 2.1 Package Structure

```
@fractary/faber/
├── package.json
├── src/
│   ├── index.ts                 # Public API exports
│   ├── types.ts                 # All TypeScript interfaces
│   ├── errors.ts                # FABER-specific error types
│   ├── config.ts                # Configuration loading
│   │
│   ├── work/                    # Work Tracking Module
│   │   ├── index.ts
│   │   ├── manager.ts           # WorkManager class
│   │   ├── types.ts
│   │   └── providers/
│   │       ├── github.ts
│   │       ├── jira.ts
│   │       └── linear.ts
│   │
│   ├── repo/                    # Repository Operations Module
│   │   ├── index.ts
│   │   ├── manager.ts           # RepoManager class
│   │   ├── types.ts
│   │   ├── git.ts               # Git CLI wrapper
│   │   └── providers/
│   │       ├── github.ts
│   │       ├── gitlab.ts
│   │       └── bitbucket.ts
│   │
│   ├── spec/                    # Specification Module
│   │   ├── index.ts
│   │   ├── manager.ts           # SpecManager class
│   │   ├── types.ts
│   │   ├── generator.ts         # Spec generation logic
│   │   ├── validator.ts         # Spec validation
│   │   ├── refiner.ts           # Spec refinement Q&A
│   │   └── templates/
│   │       ├── basic.ts
│   │       ├── feature.ts
│   │       ├── bug.ts
│   │       ├── infrastructure.ts
│   │       └── api.ts
│   │
│   ├── logs/                    # Logging Module
│   │   ├── index.ts
│   │   ├── manager.ts           # LogManager class
│   │   ├── types.ts
│   │   ├── capturer.ts          # Session capture
│   │   ├── writer.ts            # Log writing
│   │   └── log-types/
│   │       ├── session.ts
│   │       ├── build.ts
│   │       ├── deployment.ts
│   │       ├── test.ts
│   │       ├── debug.ts
│   │       ├── audit.ts
│   │       ├── operational.ts
│   │       └── workflow.ts
│   │
│   ├── state/                   # State Management Module
│   │   ├── index.ts
│   │   ├── manager.ts           # StateManager class
│   │   ├── types.ts
│   │   └── persistence.ts       # Local state persistence
│   │
│   ├── workflow/                # Workflow Orchestration
│   │   ├── index.ts
│   │   ├── orchestrator.ts      # FaberWorkflow class
│   │   ├── types.ts
│   │   ├── phases/
│   │   │   ├── frame.ts
│   │   │   ├── architect.ts
│   │   │   ├── build.ts
│   │   │   ├── evaluate.ts
│   │   │   └── release.ts
│   │   └── llm/
│   │       ├── router.ts        # Model selection
│   │       └── providers/
│   │           ├── anthropic.ts
│   │           └── openai.ts
│   │
│   ├── storage/                 # Local Storage (default)
│   │   ├── index.ts
│   │   ├── local.ts             # Direct file operations
│   │   └── codex-adapter.ts     # Optional Codex integration
│   │
│   └── cli/                     # CLI Commands
│       ├── index.ts
│       ├── work.ts
│       ├── repo.ts
│       ├── spec.ts
│       ├── logs.ts
│       └── workflow.ts
│
└── tests/
```

### 2.2 Module Dependencies (Internal)

```
┌─────────────────────────────────────────────────────────────────┐
│                        workflow/                                │
│                    (Orchestration Layer)                        │
└───────────────────────────┬─────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│     work/     │   │     repo/     │   │     state/    │
│ (Issue Track) │   │ (Source Ctrl) │   │  (Workflow)   │
└───────────────┘   └───────────────┘   └───────────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                         spec/ + logs/                           │
│                      (Artifact Logic)                           │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                         storage/                                │
│            (Local by default, Codex adapter optional)           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Work Tracking Module

### 3.1 WorkManager API

```typescript
// @fractary/faber/src/work/manager.ts

import {
  WorkConfig,
  Issue,
  IssueCreateOptions,
  IssueUpdateOptions,
  Comment,
  Label,
  Milestone,
  WorkType,
} from './types';

export class WorkManager {
  constructor(config?: WorkConfig);

  // ═══════════════════════════════════════════════════════════════
  // ISSUES
  // ═══════════════════════════════════════════════════════════════

  async createIssue(options: IssueCreateOptions): Promise<Issue>;
  async fetchIssue(issueId: string | number): Promise<Issue>;
  async updateIssue(issueId: string | number, options: IssueUpdateOptions): Promise<Issue>;
  async closeIssue(issueId: string | number): Promise<Issue>;
  async reopenIssue(issueId: string | number): Promise<Issue>;
  async searchIssues(query: string, filters?: IssueFilters): Promise<Issue[]>;
  async assignIssue(issueId: string | number, assignee: string): Promise<Issue>;
  async unassignIssue(issueId: string | number): Promise<Issue>;

  // ═══════════════════════════════════════════════════════════════
  // COMMENTS
  // ═══════════════════════════════════════════════════════════════

  async createComment(issueId: string | number, body: string): Promise<Comment>;
  async listComments(issueId: string | number, options?: ListOptions): Promise<Comment[]>;
  async updateComment(commentId: string, body: string): Promise<Comment>;
  async deleteComment(commentId: string): Promise<void>;

  // ═══════════════════════════════════════════════════════════════
  // LABELS
  // ═══════════════════════════════════════════════════════════════

  async addLabels(issueId: string | number, labels: string[]): Promise<Label[]>;
  async removeLabels(issueId: string | number, labels: string[]): Promise<void>;
  async setLabels(issueId: string | number, labels: string[]): Promise<Label[]>;
  async listLabels(issueId?: string | number): Promise<Label[]>;

  // ═══════════════════════════════════════════════════════════════
  // MILESTONES
  // ═══════════════════════════════════════════════════════════════

  async createMilestone(options: MilestoneCreateOptions): Promise<Milestone>;
  async setMilestone(issueId: string | number, milestone: string): Promise<Issue>;
  async removeMilestone(issueId: string | number): Promise<Issue>;
  async listMilestones(state?: 'open' | 'closed' | 'all'): Promise<Milestone[]>;

  // ═══════════════════════════════════════════════════════════════
  // CLASSIFICATION
  // ═══════════════════════════════════════════════════════════════

  async classifyWorkType(issue: Issue): Promise<WorkType>;
}
```

### 3.2 Platform Providers

```typescript
// Provider interface implemented by each platform
interface WorkProvider {
  readonly platform: 'github' | 'jira' | 'linear';

  createIssue(options: IssueCreateOptions): Promise<Issue>;
  fetchIssue(issueId: string | number): Promise<Issue>;
  updateIssue(issueId: string | number, options: IssueUpdateOptions): Promise<Issue>;
  // ... all operations
}

// Platform-specific implementations
class GitHubWorkProvider implements WorkProvider { ... }
class JiraWorkProvider implements WorkProvider { ... }
class LinearWorkProvider implements WorkProvider { ... }
```

### 3.3 Types

```typescript
// @fractary/faber/src/work/types.ts

export interface WorkConfig {
  platform: 'github' | 'jira' | 'linear';
  owner?: string;      // GitHub org/user
  repo?: string;       // GitHub repo
  project?: string;    // Jira/Linear project
  token?: string;      // Auth token (or from env)
}

export interface Issue {
  id: string;
  number: number;
  title: string;
  body: string;
  state: 'open' | 'closed';
  labels: Label[];
  assignees: string[];
  milestone?: Milestone;
  created_at: string;
  updated_at: string;
  closed_at?: string;
  url: string;
}

export interface IssueCreateOptions {
  title: string;
  body?: string;
  labels?: string[];
  assignees?: string[];
  milestone?: string;
}

export interface IssueUpdateOptions {
  title?: string;
  body?: string;
  state?: 'open' | 'closed';
}

export type WorkType = 'feature' | 'bug' | 'chore' | 'patch' | 'infrastructure' | 'api';

export interface Label {
  name: string;
  color?: string;
  description?: string;
}

export interface Milestone {
  id: string;
  title: string;
  description?: string;
  due_on?: string;
  state: 'open' | 'closed';
}

export interface Comment {
  id: string;
  body: string;
  author: string;
  created_at: string;
  updated_at: string;
}
```

---

## 4. Repository Operations Module

### 4.1 RepoManager API

```typescript
// @fractary/faber/src/repo/manager.ts

import {
  RepoConfig,
  Branch,
  Commit,
  PullRequest,
  Tag,
  Worktree,
  CommitOptions,
  PRCreateOptions,
} from './types';

export class RepoManager {
  constructor(config?: RepoConfig);

  // ═══════════════════════════════════════════════════════════════
  // BRANCHES
  // ═══════════════════════════════════════════════════════════════

  async createBranch(name: string, options?: BranchCreateOptions): Promise<Branch>;
  async deleteBranch(name: string, options?: BranchDeleteOptions): Promise<void>;
  async listBranches(options?: BranchListOptions): Promise<Branch[]>;
  async getCurrentBranch(): Promise<string>;
  async switchBranch(name: string): Promise<void>;
  async generateBranchName(workId: string, description: string): Promise<string>;

  // ═══════════════════════════════════════════════════════════════
  // COMMITS
  // ═══════════════════════════════════════════════════════════════

  async createCommit(options: CommitOptions): Promise<Commit>;
  async getCommit(sha: string): Promise<Commit>;
  async listCommits(options?: CommitListOptions): Promise<Commit[]>;
  async getDiff(base?: string, head?: string): Promise<string>;
  async getStatus(): Promise<GitStatus>;
  async stageFiles(patterns: string[]): Promise<void>;
  async unstageFiles(patterns: string[]): Promise<void>;

  // ═══════════════════════════════════════════════════════════════
  // PULL REQUESTS
  // ═══════════════════════════════════════════════════════════════

  async createPR(options: PRCreateOptions): Promise<PullRequest>;
  async getPR(number: number): Promise<PullRequest>;
  async updatePR(number: number, options: PRUpdateOptions): Promise<PullRequest>;
  async mergePR(number: number, options?: PRMergeOptions): Promise<PullRequest>;
  async listPRs(options?: PRListOptions): Promise<PullRequest[]>;
  async addPRComment(number: number, body: string): Promise<Comment>;
  async requestReview(number: number, reviewers: string[]): Promise<void>;
  async approvePR(number: number, comment?: string): Promise<void>;

  // ═══════════════════════════════════════════════════════════════
  // TAGS
  // ═══════════════════════════════════════════════════════════════

  async createTag(name: string, options?: TagCreateOptions): Promise<Tag>;
  async listTags(options?: TagListOptions): Promise<Tag[]>;
  async pushTag(name: string): Promise<void>;
  async deleteTag(name: string, options?: TagDeleteOptions): Promise<void>;

  // ═══════════════════════════════════════════════════════════════
  // WORKTREES
  // ═══════════════════════════════════════════════════════════════

  async createWorktree(branch: string, options?: WorktreeOptions): Promise<Worktree>;
  async listWorktrees(): Promise<Worktree[]>;
  async removeWorktree(branch: string, force?: boolean): Promise<void>;
  async cleanupWorktrees(options?: WorktreeCleanupOptions): Promise<void>;

  // ═══════════════════════════════════════════════════════════════
  // PUSH/PULL
  // ═══════════════════════════════════════════════════════════════

  async push(options?: PushOptions): Promise<void>;
  async pull(options?: PullOptions): Promise<void>;
  async fetch(remote?: string): Promise<void>;
}
```

### 4.2 Commit Message Format

```typescript
// Conventional Commits + FABER metadata

interface CommitOptions {
  message: string;                    // Summary line
  type?: CommitType;                  // feat, fix, chore, etc.
  scope?: string;                     // Component affected
  body?: string;                      // Extended description
  breaking?: boolean;                 // BREAKING CHANGE footer
  workId?: string;                    // Work item reference
  coAuthors?: string[];               // Co-authors
}

type CommitType = 'feat' | 'fix' | 'chore' | 'docs' | 'style' | 'refactor' | 'perf' | 'test';

// Generated format:
// feat(auth): Add OAuth2 support
//
// Implement OAuth2 authentication flow with PKCE.
//
// Work-Item: #123
// BREAKING CHANGE: Removes legacy auth endpoints
//
// Co-Authored-By: Claude <noreply@anthropic.com>
```

### 4.3 Types

```typescript
// @fractary/faber/src/repo/types.ts

export interface RepoConfig {
  platform: 'github' | 'gitlab' | 'bitbucket';
  owner: string;
  repo: string;
  defaultBranch?: string;
  token?: string;
}

export interface Branch {
  name: string;
  sha: string;
  isDefault: boolean;
  isProtected: boolean;
  upstream?: string;
  lastCommit?: Commit;
}

export interface Commit {
  sha: string;
  message: string;
  author: string;
  date: string;
  parents: string[];
}

export interface PullRequest {
  number: number;
  title: string;
  body: string;
  state: 'open' | 'closed' | 'merged';
  head: string;
  base: string;
  author: string;
  reviewers: string[];
  labels: string[];
  mergeable?: boolean;
  url: string;
  created_at: string;
  merged_at?: string;
}

export interface Tag {
  name: string;
  sha: string;
  message?: string;
  tagger?: string;
  date: string;
}

export interface Worktree {
  path: string;
  branch: string;
  sha: string;
  isMain: boolean;
}

export interface GitStatus {
  branch: string;
  ahead: number;
  behind: number;
  staged: string[];
  modified: string[];
  untracked: string[];
  conflicts: string[];
}
```

---

## 5. Specification Module

### 5.1 SpecManager API

```typescript
// @fractary/faber/src/spec/manager.ts

import {
  Specification,
  SpecCreateOptions,
  SpecValidateResult,
  SpecRefineResult,
  SpecTemplate,
} from './types';

export class SpecManager {
  constructor(config?: SpecConfig);

  // ═══════════════════════════════════════════════════════════════
  // CREATION
  // ═══════════════════════════════════════════════════════════════

  /**
   * Generate a specification from context
   *
   * Standalone: Writes to /specs/WORK-00123.md
   * With Codex: Delegates storage to Codex
   */
  async create(options: SpecCreateOptions): Promise<Specification>;

  /**
   * Check if spec exists for work item
   */
  async exists(workId: string): Promise<boolean>;

  /**
   * Find specs for work item
   */
  async findByWorkId(workId: string): Promise<Specification[]>;

  // ═══════════════════════════════════════════════════════════════
  // READING
  // ═══════════════════════════════════════════════════════════════

  /**
   * Read a specification
   *
   * Standalone: Reads from /specs/
   * With Codex: Resolves codex://specs/ reference
   */
  async read(identifier: string): Promise<Specification | null>;

  /**
   * List all specifications
   */
  async list(options?: SpecListOptions): Promise<Specification[]>;

  // ═══════════════════════════════════════════════════════════════
  // VALIDATION
  // ═══════════════════════════════════════════════════════════════

  /**
   * Validate implementation against specification
   */
  async validate(specPath: string, options?: ValidateOptions): Promise<SpecValidateResult>;

  // ═══════════════════════════════════════════════════════════════
  // REFINEMENT
  // ═══════════════════════════════════════════════════════════════

  /**
   * Refine spec through Q&A workflow
   */
  async refine(workId: string, options?: RefineOptions): Promise<SpecRefineResult>;

  /**
   * Generate refinement questions without applying
   */
  async generateQuestions(workId: string): Promise<RefinementQuestion[]>;

  // ═══════════════════════════════════════════════════════════════
  // PROGRESS TRACKING
  // ═══════════════════════════════════════════════════════════════

  /**
   * Update phase status in spec
   */
  async updatePhaseStatus(specPath: string, phaseId: string, status: PhaseStatus): Promise<void>;

  /**
   * Check off a task in spec
   */
  async checkTask(specPath: string, phaseId: string, taskText: string): Promise<void>;

  /**
   * Add implementation notes
   */
  async addNotes(specPath: string, phaseId: string, notes: string[]): Promise<void>;

  // ═══════════════════════════════════════════════════════════════
  // TEMPLATES
  // ═══════════════════════════════════════════════════════════════

  /**
   * Get available templates
   */
  getTemplates(): SpecTemplate[];

  /**
   * Auto-detect template from context
   */
  detectTemplate(context: TemplateDetectionContext): SpecTemplate;
}
```

### 5.2 Storage Behavior

```typescript
// @fractary/faber/src/spec/manager.ts

class SpecManager {
  private storage: SpecStorage;

  constructor(config?: SpecConfig) {
    // Check if Codex is available and enabled for specs
    if (this.codexEnabledForSpecs()) {
      this.storage = new CodexSpecStorage();
    } else {
      this.storage = new LocalSpecStorage(config?.localPath ?? '/specs');
    }
  }

  private codexEnabledForSpecs(): boolean {
    // Runtime check - no compile-time dependency
    try {
      const codexConfig = this.loadCodexConfig();
      return codexConfig?.types?.specs?.enabled === true;
    } catch {
      return false;
    }
  }

  async create(options: SpecCreateOptions): Promise<Specification> {
    // Generate spec content (this is FABER's domain)
    const spec = await this.generator.generate(options);

    // Store via storage adapter (local or Codex)
    const path = await this.storage.write(spec);

    // Link to work item (if work module available)
    if (options.workId && this.workManager) {
      await this.workManager.createComment(
        options.workId,
        `📋 Specification created: ${path}`
      );
    }

    return { ...spec, path };
  }
}
```

### 5.3 Types

```typescript
// @fractary/faber/src/spec/types.ts

export interface SpecConfig {
  localPath?: string;           // Default: /specs
  templates?: {
    default: SpecTemplateType;
    customDir?: string;
  };
}

export interface Specification {
  id: string;                   // WORK-00123-feature or SPEC-20250115-name
  path: string;                 // Local path or codex:// reference
  title: string;
  workId?: string;
  workType: WorkType;
  template: SpecTemplateType;
  content: string;
  metadata: SpecMetadata;
  phases?: SpecPhase[];
}

export interface SpecMetadata {
  created_at: string;
  updated_at: string;
  validation_status?: 'not_validated' | 'partial' | 'complete' | 'failed';
  source: 'conversation' | 'issue' | 'conversation+issue';
}

export interface SpecPhase {
  id: string;
  title: string;
  status: 'not_started' | 'in_progress' | 'complete';
  objective?: string;
  tasks: SpecTask[];
  notes?: string[];
}

export interface SpecTask {
  text: string;
  completed: boolean;
}

export type SpecTemplateType = 'basic' | 'feature' | 'bug' | 'infrastructure' | 'api';

export interface SpecCreateOptions {
  workId?: string;
  template?: SpecTemplateType;
  context?: string;
  conversationContext?: string;
  force?: boolean;
}

export interface SpecValidateResult {
  status: 'pass' | 'partial' | 'fail';
  score: number;
  checks: {
    requirements: { completed: number; total: number; status: 'pass' | 'warn' | 'fail' };
    acceptanceCriteria: { met: number; total: number; status: 'pass' | 'warn' | 'fail' };
    filesModified: { status: 'pass' | 'fail' };
    testsAdded: { added: number; expected: number; status: 'pass' | 'warn' | 'fail' };
    docsUpdated: { status: 'pass' | 'fail' };
  };
  suggestions?: string[];
}
```

---

## 6. Logging Module

### 6.1 LogManager API

```typescript
// @fractary/faber/src/logs/manager.ts

import {
  LogConfig,
  LogEntry,
  LogType,
  SessionState,
  LogWriteOptions,
  CaptureResult,
  SearchOptions,
  SearchResults,
} from './types';

export class LogManager {
  constructor(config?: LogConfig);

  // ═══════════════════════════════════════════════════════════════
  // LOG WRITING
  // ═══════════════════════════════════════════════════════════════

  /**
   * Write a log entry
   *
   * Standalone: Writes to .fractary/logs/{type}/
   * With Codex: Delegates to Codex storage
   */
  async write(options: LogWriteOptions): Promise<LogEntry>;

  /**
   * Get available log types
   */
  getLogTypes(): LogTypeDefinition[];

  // ═══════════════════════════════════════════════════════════════
  // SESSION CAPTURE
  // ═══════════════════════════════════════════════════════════════

  /**
   * Start session capture
   */
  async startCapture(options: CaptureStartOptions): Promise<CaptureResult>;

  /**
   * Append to active session
   */
  async append(options: AppendOptions): Promise<void>;

  /**
   * Stop session capture
   */
  async stopCapture(options?: CaptureStopOptions): Promise<CaptureResult>;

  /**
   * Get active session
   */
  getActiveSession(): SessionState | null;

  // ═══════════════════════════════════════════════════════════════
  // READING
  // ═══════════════════════════════════════════════════════════════

  /**
   * Read a log entry
   */
  async read(identifier: string): Promise<LogEntry | null>;

  /**
   * List logs
   */
  async list(options?: LogListOptions): Promise<LogEntry[]>;

  /**
   * Search logs (local only - Codex provides cross-archive search)
   */
  async search(options: SearchOptions): Promise<SearchResults>;

  // ═══════════════════════════════════════════════════════════════
  // ANALYSIS
  // ═══════════════════════════════════════════════════════════════

  /**
   * Analyze log for patterns/errors
   */
  async analyze(logPath: string, type: 'errors' | 'patterns' | 'summary'): Promise<AnalysisResult>;

  // ═══════════════════════════════════════════════════════════════
  // RETENTION (Local)
  // ═══════════════════════════════════════════════════════════════

  /**
   * Get retention status for logs
   * Note: When Codex enabled, Codex handles retention/archival
   */
  async getRetentionStatus(): Promise<RetentionStatusResult[]>;

  /**
   * Cleanup expired logs (local only)
   */
  async cleanup(options?: CleanupOptions): Promise<CleanupResult>;
}
```

### 6.2 Log Types

```typescript
// @fractary/faber/src/logs/types.ts

export type LogType =
  | 'session'      // Claude Code conversation sessions
  | 'build'        // Build process logs
  | 'deployment'   // Deployment/release logs
  | 'test'         // Test execution logs
  | 'debug'        // Debug session logs
  | 'audit'        // Audit trail logs
  | 'operational'  // Monitoring/metrics
  | 'workflow';    // FABER workflow logs

export interface LogTypeDefinition {
  type: LogType;
  description: string;
  localPath: string;
  schema: JSONSchema;
  template: string;
  defaultRetention: {
    localDays: number;
    archiveAfterDays?: number;
  };
}

export interface LogEntry {
  id: string;
  type: LogType;
  path: string;
  title: string;
  content: string;
  metadata: LogMetadata;
  size_bytes: number;
}

export interface LogMetadata {
  date: string;
  status: LogStatus;
  issue_number?: number;
  repository?: string;
  branch?: string;
}

export type LogStatus =
  | 'active'
  | 'completed'
  | 'stopped'
  | 'success'
  | 'failure'
  | 'error';

export interface SessionState {
  session_id: string;
  log_path: string;
  issue_number: number;
  start_time: string;
  status: 'active' | 'stopped';
}

export interface RedactionPatterns {
  api_keys: boolean;
  jwt_tokens: boolean;
  passwords: boolean;
  credit_cards: boolean;
  custom_patterns?: RegExp[];
}
```

### 6.3 Storage Behavior

```typescript
class LogManager {
  private storage: LogStorage;

  constructor(config?: LogConfig) {
    if (this.codexEnabledForLogs()) {
      this.storage = new CodexLogStorage();
    } else {
      this.storage = new LocalLogStorage(config?.localPath ?? '.fractary/logs');
    }
  }

  async write(options: LogWriteOptions): Promise<LogEntry> {
    // Validate against log type schema (FABER's domain)
    const logType = this.getLogType(options.type);
    this.validator.validate(options.data, logType.schema);

    // Apply redaction (FABER's domain)
    const redactedContent = this.redactor.redact(options.content);

    // Render template (FABER's domain)
    const rendered = this.renderer.render(logType.template, {
      ...options.data,
      content: redactedContent,
    });

    // Store via adapter (local or Codex)
    return this.storage.write(options.type, rendered);
  }
}
```

---

## 7. State Management Module

### 7.1 StateManager API

```typescript
// @fractary/faber/src/state/manager.ts

import {
  WorkflowState,
  RunManifest,
  PhaseState,
} from './types';

export class StateManager {
  constructor(config?: StateConfig);

  // ═══════════════════════════════════════════════════════════════
  // WORKFLOW STATE
  // ═══════════════════════════════════════════════════════════════

  /**
   * Get current workflow state
   */
  async getState(workflowId: string): Promise<WorkflowState | null>;

  /**
   * Save workflow state
   */
  async saveState(state: WorkflowState): Promise<void>;

  /**
   * Update phase state
   */
  async updatePhase(workflowId: string, phase: string, state: Partial<PhaseState>): Promise<void>;

  /**
   * Clear workflow state
   */
  async clearState(workflowId: string): Promise<void>;

  // ═══════════════════════════════════════════════════════════════
  // RUN MANIFESTS
  // ═══════════════════════════════════════════════════════════════

  /**
   * Create run manifest
   */
  async createManifest(workflowId: string): Promise<RunManifest>;

  /**
   * Get run manifest
   */
  async getManifest(manifestId: string): Promise<RunManifest | null>;

  /**
   * Update run manifest
   */
  async updateManifest(manifestId: string, updates: Partial<RunManifest>): Promise<void>;

  /**
   * List run manifests
   */
  async listManifests(workflowId?: string): Promise<RunManifest[]>;
}
```

### 7.2 Types

```typescript
// @fractary/faber/src/state/types.ts

export interface StateConfig {
  localPath?: string;  // Default: .fractary/plugins/faber
}

export interface WorkflowState {
  workflow_id: string;
  work_id: string;
  current_phase: FaberPhase;
  phase_states: Record<FaberPhase, PhaseState>;
  started_at: string;
  updated_at: string;
  status: 'running' | 'paused' | 'completed' | 'failed';
}

export type FaberPhase = 'frame' | 'architect' | 'build' | 'evaluate' | 'release';

export interface PhaseState {
  status: 'pending' | 'in_progress' | 'completed' | 'failed' | 'skipped';
  started_at?: string;
  completed_at?: string;
  attempts: number;
  error?: string;
  outputs?: Record<string, unknown>;
}

export interface RunManifest {
  manifest_id: string;
  workflow_id: string;
  work_id: string;
  created_at: string;
  completed_at?: string;
  status: 'running' | 'completed' | 'failed';
  phases: PhaseManifest[];
  artifacts: ArtifactManifest[];
}

export interface PhaseManifest {
  phase: FaberPhase;
  status: string;
  duration_ms: number;
  steps: StepManifest[];
}

export interface StepManifest {
  name: string;
  skill?: string;
  status: 'success' | 'failure' | 'skipped';
  duration_ms: number;
  outputs?: Record<string, unknown>;
}

export interface ArtifactManifest {
  type: 'spec' | 'log' | 'commit' | 'pr' | 'branch';
  path: string;
  created_at: string;
}
```

---

## 8. Workflow Orchestration

### 8.1 FaberWorkflow API

```typescript
// @fractary/faber/src/workflow/orchestrator.ts

import {
  WorkflowConfig,
  WorkflowResult,
  PhaseResult,
  AutonomyLevel,
} from './types';

export class FaberWorkflow {
  constructor(options: WorkflowOptions);

  // ═══════════════════════════════════════════════════════════════
  // EXECUTION
  // ═══════════════════════════════════════════════════════════════

  /**
   * Run complete workflow
   */
  async run(): Promise<WorkflowResult>;

  /**
   * Run single phase
   */
  async runPhase(phase: FaberPhase): Promise<PhaseResult>;

  /**
   * Resume from saved state
   */
  async resume(): Promise<WorkflowResult>;

  /**
   * Pause workflow
   */
  async pause(): Promise<void>;

  /**
   * Abort workflow
   */
  async abort(): Promise<void>;

  // ═══════════════════════════════════════════════════════════════
  // STATUS
  // ═══════════════════════════════════════════════════════════════

  /**
   * Get current status
   */
  getStatus(): WorkflowStatus;

  /**
   * Get current phase
   */
  getCurrentPhase(): FaberPhase | null;

  /**
   * Check if workflow is running
   */
  isRunning(): boolean;

  // ═══════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════════

  /**
   * Set autonomy level
   */
  setAutonomy(level: AutonomyLevel): void;

  /**
   * Get workflow configuration
   */
  getConfig(): WorkflowConfig;
}

export interface WorkflowOptions {
  workId: string | number;
  autonomy?: AutonomyLevel;
  config?: Partial<WorkflowConfig>;
}

export type AutonomyLevel =
  | 'dry-run'      // No actual changes
  | 'assisted'     // Stops before release
  | 'guarded'      // Pauses at release for approval
  | 'autonomous';  // Full automation
```

### 8.2 Phase Implementations

```typescript
// @fractary/faber/src/workflow/phases/frame.ts

export class FramePhase {
  async execute(context: PhaseContext): Promise<PhaseResult> {
    // 1. Fetch work item
    const issue = await this.workManager.fetchIssue(context.workId);

    // 2. Classify work type
    const workType = await this.workManager.classifyWorkType(issue);

    // 3. Setup environment (branch creation is in Build phase)

    return {
      status: 'completed',
      outputs: {
        issue,
        workType,
      },
    };
  }
}

// @fractary/faber/src/workflow/phases/architect.ts

export class ArchitectPhase {
  async execute(context: PhaseContext): Promise<PhaseResult> {
    // 1. Generate specification
    const spec = await this.specManager.create({
      workId: context.workId,
      conversationContext: context.conversationContext,
    });

    // 2. Optionally refine
    if (context.config.refineSpec) {
      await this.specManager.refine(context.workId);
    }

    return {
      status: 'completed',
      outputs: { spec },
    };
  }
}

// @fractary/faber/src/workflow/phases/build.ts

export class BuildPhase {
  async execute(context: PhaseContext): Promise<PhaseResult> {
    // 1. Create branch (automatic primitive)
    const branch = await this.repoManager.createBranch(
      await this.repoManager.generateBranchName(context.workId, context.issue.title)
    );

    // 2. Implementation happens here (LLM-driven)

    // 3. Create commits
    const commits = await this.createCommits(context);

    // 4. Log workflow progress
    await this.logManager.write({
      type: 'workflow',
      data: {
        phase: 'build',
        workId: context.workId,
        commits: commits.map(c => c.sha),
      },
    });

    return {
      status: 'completed',
      outputs: { branch, commits },
    };
  }
}

// @fractary/faber/src/workflow/phases/evaluate.ts

export class EvaluatePhase {
  async execute(context: PhaseContext): Promise<PhaseResult> {
    // 1. Run tests
    const testResult = await this.runTests(context);

    // 2. Validate against spec
    const validationResult = await this.specManager.validate(context.specPath);

    // 3. Handle retry logic
    if (testResult.failed || validationResult.status === 'fail') {
      if (context.attempts < context.config.maxRetries) {
        return { status: 'retry', reason: 'Tests or validation failed' };
      }
      return { status: 'failed', error: 'Max retries exceeded' };
    }

    return {
      status: 'completed',
      outputs: { testResult, validationResult },
    };
  }
}

// @fractary/faber/src/workflow/phases/release.ts

export class ReleasePhase {
  async execute(context: PhaseContext): Promise<PhaseResult> {
    // 1. Create PR (automatic primitive)
    const pr = await this.repoManager.createPR({
      title: `${context.workType}(${context.scope}): ${context.issue.title}`,
      body: this.generatePRBody(context),
      head: context.branch,
      base: context.config.baseBranch,
    });

    // 2. Request reviews if configured
    if (context.config.requestReviews) {
      await this.repoManager.requestReview(pr.number, context.config.reviewers);
    }

    // 3. Update work item
    await this.workManager.createComment(
      context.workId,
      `🚀 Pull request created: ${pr.url}`
    );

    return {
      status: 'completed',
      outputs: { pr },
    };
  }
}
```

---

## 9. Configuration

### 9.1 FABER Configuration Schema

```typescript
// .fractary/plugins/faber/config.json

export interface FaberConfig {
  schema_version: string;

  // Work tracking configuration
  work: {
    platform: 'github' | 'jira' | 'linear';
    owner?: string;
    repo?: string;
    project?: string;
  };

  // Repository configuration
  repo: {
    platform: 'github' | 'gitlab' | 'bitbucket';
    owner: string;
    repo: string;
    defaultBranch: string;
    branchPrefix: {
      feature: string;
      bugfix: string;
      hotfix: string;
      chore: string;
    };
  };

  // Artifact storage configuration
  artifacts: {
    specs: {
      use_codex: boolean;      // When true, Codex handles storage
      local_path: string;       // Used when use_codex is false
    };
    logs: {
      use_codex: boolean;
      local_path: string;
    };
    state: {
      use_codex: boolean;
      local_path: string;
    };
  };

  // Workflow configuration
  workflow: {
    autonomy: AutonomyLevel;
    phases: {
      frame: { enabled: boolean };
      architect: { enabled: boolean; refineSpec: boolean };
      build: { enabled: boolean };
      evaluate: { enabled: boolean; maxRetries: number };
      release: { enabled: boolean; requestReviews: boolean; reviewers: string[] };
    };
    hooks: {
      pre_frame?: string;
      post_frame?: string;
      pre_architect?: string;
      post_architect?: string;
      // ... etc for each phase
    };
  };

  // LLM configuration
  llm: {
    defaultModel: string;
    modelOverrides: {
      [phase: string]: string;
    };
  };
}
```

### 9.2 Example Configuration

```json
{
  "schema_version": "1.0",

  "work": {
    "platform": "github",
    "owner": "fractary",
    "repo": "claude-plugins"
  },

  "repo": {
    "platform": "github",
    "owner": "fractary",
    "repo": "claude-plugins",
    "defaultBranch": "main",
    "branchPrefix": {
      "feature": "feat",
      "bugfix": "fix",
      "hotfix": "hotfix",
      "chore": "chore"
    }
  },

  "artifacts": {
    "specs": {
      "use_codex": false,
      "local_path": "/specs"
    },
    "logs": {
      "use_codex": true,
      "local_path": ".fractary/logs"
    },
    "state": {
      "use_codex": false,
      "local_path": ".fractary/plugins/faber"
    }
  },

  "workflow": {
    "autonomy": "guarded",
    "phases": {
      "frame": { "enabled": true },
      "architect": { "enabled": true, "refineSpec": true },
      "build": { "enabled": true },
      "evaluate": { "enabled": true, "maxRetries": 3 },
      "release": { "enabled": true, "requestReviews": true, "reviewers": ["team-lead"] }
    }
  },

  "llm": {
    "defaultModel": "claude-sonnet-4-5-20250514",
    "modelOverrides": {
      "architect": "claude-opus-4-5-20250514"
    }
  }
}
```

---

## 10. CLI Implementation

### 10.1 Command Structure

```
fractary <module> <command> [options]

Modules:
  work        Work tracking operations
  repo        Repository operations
  spec        Specification management
  logs        Log management
  workflow    FABER workflow operations

Examples:
  fractary work issue create "Fix auth bug" --labels bug
  fractary repo commit "Add feature" --type feat --work-id 123
  fractary spec create --work-id 123
  fractary logs capture --issue 123
  fractary workflow run 123 --autonomy guarded
```

### 10.2 Command Implementations

```typescript
// @fractary/faber/src/cli/index.ts

import { Command } from 'commander';
import { registerWorkCommands } from './work';
import { registerRepoCommands } from './repo';
import { registerSpecCommands } from './spec';
import { registerLogsCommands } from './logs';
import { registerWorkflowCommands } from './workflow';

export function createCLI(): Command {
  const program = new Command();

  program
    .name('fractary')
    .description('FABER development toolkit')
    .version('1.0.0');

  registerWorkCommands(program);
  registerRepoCommands(program);
  registerSpecCommands(program);
  registerLogsCommands(program);
  registerWorkflowCommands(program);

  return program;
}
```

---

## 11. Error Handling

### 11.1 Error Types

```typescript
// @fractary/faber/src/errors.ts

export class FaberError extends Error {
  constructor(
    message: string,
    public code: string,
    public details?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'FaberError';
  }
}

// Work errors
export class WorkError extends FaberError {
  constructor(message: string, code: string, details?: Record<string, unknown>) {
    super(message, code, details);
    this.name = 'WorkError';
  }
}

export class IssueNotFoundError extends WorkError {
  constructor(issueId: string | number) {
    super(`Issue not found: ${issueId}`, 'ISSUE_NOT_FOUND', { issueId });
  }
}

// Repo errors
export class RepoError extends FaberError {
  constructor(message: string, code: string, details?: Record<string, unknown>) {
    super(message, code, details);
    this.name = 'RepoError';
  }
}

export class BranchExistsError extends RepoError {
  constructor(branchName: string) {
    super(`Branch already exists: ${branchName}`, 'BRANCH_EXISTS', { branchName });
  }
}

export class ProtectedBranchError extends RepoError {
  constructor(branchName: string, operation: string) {
    super(
      `Cannot ${operation} protected branch: ${branchName}`,
      'PROTECTED_BRANCH',
      { branchName, operation }
    );
  }
}

// Spec errors
export class SpecError extends FaberError {
  constructor(message: string, code: string, details?: Record<string, unknown>) {
    super(message, code, details);
    this.name = 'SpecError';
  }
}

export class SpecNotFoundError extends SpecError {
  constructor(identifier: string) {
    super(`Specification not found: ${identifier}`, 'SPEC_NOT_FOUND', { identifier });
  }
}

export class SpecValidationError extends SpecError {
  constructor(specPath: string, errors: string[]) {
    super(`Specification validation failed: ${specPath}`, 'SPEC_VALIDATION_FAILED', { specPath, errors });
  }
}

// Log errors
export class LogError extends FaberError {
  constructor(message: string, code: string, details?: Record<string, unknown>) {
    super(message, code, details);
    this.name = 'LogError';
  }
}

export class NoActiveSessionError extends LogError {
  constructor() {
    super('No active capture session', 'NO_ACTIVE_SESSION', {});
  }
}

// Workflow errors
export class WorkflowError extends FaberError {
  constructor(message: string, code: string, details?: Record<string, unknown>) {
    super(message, code, details);
    this.name = 'WorkflowError';
  }
}

export class PhaseFailedError extends WorkflowError {
  constructor(phase: string, reason: string) {
    super(`Phase ${phase} failed: ${reason}`, 'PHASE_FAILED', { phase, reason });
  }
}
```

---

## 12. Codex Integration (Optional)

### 12.1 Runtime Detection

```typescript
// @fractary/faber/src/storage/codex-adapter.ts

export class CodexAdapter {
  private codex: any | null = null;

  constructor() {
    this.codex = this.tryLoadCodex();
  }

  private tryLoadCodex(): any | null {
    try {
      // Runtime import - no compile-time dependency
      const { Codex } = require('@fractary/codex');
      return new Codex();
    } catch {
      return null;
    }
  }

  isAvailable(): boolean {
    return this.codex !== null;
  }

  isEnabledFor(artifactType: string): boolean {
    if (!this.codex) return false;

    try {
      const config = this.codex.getConfig();
      return config.types?.[artifactType]?.enabled === true;
    } catch {
      return false;
    }
  }

  async store(type: string, id: string, content: string): Promise<string> {
    if (!this.codex) {
      throw new FaberError('Codex not available', 'CODEX_NOT_AVAILABLE');
    }
    return this.codex.store(type, id, content);
  }

  async retrieve(type: string, id: string): Promise<string | null> {
    if (!this.codex) {
      throw new FaberError('Codex not available', 'CODEX_NOT_AVAILABLE');
    }
    return this.codex.get(type, id);
  }

  getReference(type: string, id: string): string {
    return `codex://${type}/${id}`;
  }
}
```

### 12.2 Storage Factory

```typescript
// @fractary/faber/src/storage/index.ts

export function createStorage(artifactType: string, config: FaberConfig): Storage {
  const codex = new CodexAdapter();

  const artifactConfig = config.artifacts[artifactType];

  if (artifactConfig?.use_codex && codex.isAvailable() && codex.isEnabledFor(artifactType)) {
    return new CodexStorage(codex, artifactType);
  }

  return new LocalStorage(artifactConfig?.local_path ?? getDefaultPath(artifactType));
}

interface Storage {
  write(id: string, content: string): Promise<string>;  // Returns path/reference
  read(id: string): Promise<string | null>;
  exists(id: string): Promise<boolean>;
  list(): Promise<string[]>;
  delete(id: string): Promise<void>;
}

class LocalStorage implements Storage {
  constructor(private basePath: string) {}

  async write(id: string, content: string): Promise<string> {
    const path = `${this.basePath}/${id}.md`;
    await fs.writeFile(path, content);
    return path;  // Direct file path
  }

  // ... other methods
}

class CodexStorage implements Storage {
  constructor(private codex: CodexAdapter, private type: string) {}

  async write(id: string, content: string): Promise<string> {
    await this.codex.store(this.type, id, content);
    return this.codex.getReference(this.type, id);  // codex://type/id
  }

  // ... other methods
}
```

---

## 13. Migration from Plugins

### 13.1 Plugin to SDK Mapping

| Plugin | SDK Module | Notes |
|--------|------------|-------|
| `plugins/work/` | `@fractary/faber/work` | All skills → WorkManager methods |
| `plugins/repo/` | `@fractary/faber/repo` | All skills → RepoManager methods |
| `plugins/spec/` | `@fractary/faber/spec` | Spec logic only, storage via adapter |
| `plugins/logs/` | `@fractary/faber/logs` | Log logic only, storage via adapter |
| `plugins/faber/` | `@fractary/faber/workflow` | Orchestration, state management |

### 13.2 Backward Compatibility

During transition:
- Plugin commands call CLI equivalents
- Configuration schemas remain compatible
- File formats unchanged
- Gradual migration path

---

## 14. Testing Strategy

### 14.1 Unit Tests

```typescript
describe('WorkManager', () => {
  describe('createIssue', () => {
    it('creates issue with GitHub provider');
    it('creates issue with Jira provider');
    it('creates issue with Linear provider');
    it('throws on invalid platform');
  });
});

describe('RepoManager', () => {
  describe('createBranch', () => {
    it('creates branch from default');
    it('creates branch from specified base');
    it('throws on protected branch');
    it('generates semantic branch name');
  });
});

describe('SpecManager', () => {
  describe('create', () => {
    it('creates spec with local storage');
    it('creates spec with Codex when enabled');
    it('links spec to work item');
    it('selects correct template');
  });
});

describe('FaberWorkflow', () => {
  describe('run', () => {
    it('executes all phases in order');
    it('respects autonomy level');
    it('handles phase failures');
    it('saves and resumes state');
  });
});
```

### 14.2 Integration Tests

```typescript
describe('FABER E2E', () => {
  it('complete workflow: issue → spec → branch → commits → PR');
  it('workflow with Codex integration');
  it('workflow resume after pause');
  it('evaluate phase retry loop');
});
```

---

## 15. References

- SPEC-00015: FABER Orchestrator Architecture
- SPEC-00024: Codex SDK (companion spec)
- Plugin sources: `plugins/faber/`, `plugins/work/`, `plugins/repo/`, `plugins/spec/`, `plugins/logs/`
