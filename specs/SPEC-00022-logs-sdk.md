# SPEC-00022: Logs Management SDK

## Status: Draft
## Version: 1.0.0
## Last Updated: 2025-12-11

---

## 1. Executive Summary

This specification defines the Logs Management SDK (`@fractary/logs`) which provides comprehensive log management for development workflows. The SDK handles the complete log lifecycle: type-aware log creation, session capture with redaction, hybrid search (local + cloud), path-based retention policies, and archival with compression.

### 1.1 Scope

**In Scope:**
- Type-aware log creation with templates and validation
- Session capture (start/append/stop) with redaction
- Hybrid search across local and cloud storage
- Path-based retention policies with exceptions
- Archival with compression and index management
- Log analysis (patterns, errors, time-series)
- Storage auditing and cleanup

**Out of Scope:**
- LLM-based summarization (uses LLMProvider from core)
- Cloud storage operations (uses FileStorage)
- Work item operations (uses WorkProvider)

### 1.2 References

- SPEC-00015: FABER Orchestrator Architecture (parent spec)
- SPEC-00016: SDK Architecture & Core Interfaces
- SPEC-00019: File Storage SDK (archive storage)
- SPEC-00017: Work Tracking SDK (issue linking)
- Plugin source: `plugins/logs/`

---

## 2. SDK Implementation

### 2.1 Package Structure

```
packages/
├── ts/
│   └── logs/
│       ├── package.json
│       ├── src/
│       │   ├── index.ts              # Public API exports
│       │   ├── types.ts              # TypeScript interfaces
│       │   ├── log-manager.ts        # Main orchestration class
│       │   ├── writer.ts             # Log creation with templates
│       │   ├── capturer.ts           # Session capture
│       │   ├── searcher.ts           # Hybrid search
│       │   ├── archiver.ts           # Archive operations
│       │   ├── analyzer.ts           # Log analysis
│       │   ├── auditor.ts            # Storage auditing
│       │   ├── validator.ts          # Log validation
│       │   ├── types/                # Log type definitions
│       │   │   ├── session.ts
│       │   │   ├── build.ts
│       │   │   ├── deployment.ts
│       │   │   ├── test.ts
│       │   │   ├── debug.ts
│       │   │   ├── audit.ts
│       │   │   ├── operational.ts
│       │   │   ├── workflow.ts
│       │   │   └── changelog.ts
│       │   ├── retention/
│       │   │   ├── policy-matcher.ts # Path pattern matching
│       │   │   └── exceptions.ts     # Retention exceptions
│       │   └── storage/
│       │       ├── local.ts          # Local storage operations
│       │       └── archive-index.ts  # Archive index management
│       └── tests/
└── py/
    └── logs/
        ├── pyproject.toml
        └── src/fractary_logs/
            ├── __init__.py
            ├── types.py
            ├── log_manager.py
            ├── writer.py
            ├── capturer.py
            ├── searcher.py
            ├── archiver.py
            ├── analyzer.py
            ├── auditor.py
            ├── validator.py
            ├── log_types/
            ├── retention/
            └── storage/
```

### 2.2 Core Types

```typescript
// packages/ts/logs/src/types.ts

import { FileStorage, WorkProvider, LLMProvider } from '@fractary/core';

/**
 * Log types supported by the system
 */
export type LogType =
  | 'session'      // Claude Code conversation sessions
  | 'build'        // Build process logs
  | 'deployment'   // Deployment/release logs
  | 'test'         // Test execution logs
  | 'debug'        // Debug session logs
  | 'audit'        // Audit trail/compliance logs
  | 'operational'  // Monitoring/metrics/alerts
  | 'workflow'     // FABER workflow execution logs
  | 'changelog'    // Release changelogs
  | '_untyped';    // Uncategorized logs

/**
 * Log status values
 */
export type LogStatus =
  | 'active'
  | 'completed'
  | 'stopped'
  | 'success'
  | 'failure'
  | 'cancelled'
  | 'error'
  | 'rolled_back'
  | 'published';

/**
 * Log priority levels
 */
export type LogPriority = 'low' | 'medium' | 'high' | 'critical';

/**
 * Base log metadata stored in frontmatter
 */
export interface LogMetadata {
  log_id: string;                // UUID or type-specific format
  log_type: LogType;
  title: string;
  date: string;                  // ISO timestamp
  status: LogStatus;
  issue_number?: number;
  repository?: string;
  branch?: string;
}

/**
 * Session-specific log metadata
 */
export interface SessionLogMetadata extends LogMetadata {
  log_type: 'session';
  session_id: string;
  model: string;
  start_date: string;
  end_date?: string;
  duration_seconds?: number;
  conversation_turns?: number;
  token_count?: number;
}

/**
 * Build-specific log metadata
 */
export interface BuildLogMetadata extends LogMetadata {
  log_type: 'build';
  build_id: string;
  build_system: string;          // npm, cargo, make, etc.
  trigger: 'manual' | 'ci' | 'hook';
  duration_seconds?: number;
  exit_code?: number;
}

/**
 * Deployment-specific log metadata
 */
export interface DeploymentLogMetadata extends LogMetadata {
  log_type: 'deployment';
  deployment_id: string;
  environment: 'development' | 'staging' | 'production';
  version?: string;
  rollback_available?: boolean;
  health_check_passed?: boolean;
}

/**
 * Audit-specific log metadata
 */
export interface AuditLogMetadata extends LogMetadata {
  log_type: 'audit';
  audit_type: 'security' | 'compliance' | 'access' | 'change';
  actor?: string;
  action?: string;
  resource?: string;
}

/**
 * Workflow-specific log metadata
 */
export interface WorkflowLogMetadata extends LogMetadata {
  log_type: 'workflow';
  workflow_id: string;
  phase: 'frame' | 'architect' | 'build' | 'evaluate' | 'release';
  phase_status: 'pending' | 'in_progress' | 'completed' | 'failed';
}

/**
 * Log entry representation
 */
export interface LogEntry {
  metadata: LogMetadata;
  content: string;               // Markdown body
  path: string;                  // Local file path
  size_bytes: number;
}

/**
 * Retention policy configuration
 */
export interface RetentionPolicy {
  pattern: string;               // Glob pattern (e.g., "sessions/*")
  log_type?: LogType;
  local_days: number;
  cloud_days: number | 'forever';
  priority: LogPriority;
  auto_archive: boolean;
  cleanup_after_archive: boolean;
  retention_exceptions?: RetentionExceptions;
  archive_triggers?: ArchiveTriggers;
  validation?: ValidationConfig;
  compression?: CompressionConfig;
  metadata?: {
    description: string;
    typical_size_mb: number;
    typical_duration_minutes?: number;
    value: string;
  };
}

export interface RetentionExceptions {
  keep_if_linked_to_open_issue?: boolean;
  keep_if_referenced_in_docs?: boolean;
  keep_recent_n?: number;
  never_delete_production?: boolean;
  never_delete_security_incidents?: boolean;
  never_delete_compliance_audits?: boolean;
}

export interface ArchiveTriggers {
  age_days: number;
  size_mb?: number;
  status?: LogStatus[];
}

export interface ValidationConfig {
  require_summary?: boolean;
  require_redaction_check?: boolean;
  warn_if_no_decisions?: boolean;
  warn_if_no_errors_on_failure?: boolean;
  require_health_checks_for_production?: boolean;
  require_rollback_plan_for_production?: boolean;
}

export interface CompressionConfig {
  enabled: boolean;
  format: 'gzip' | 'zstd';
  threshold_mb: number;
}

/**
 * Retention status for a log
 */
export type RetentionStatus = 'active' | 'expiring_soon' | 'expired' | 'protected';

export interface RetentionStatusResult {
  log_path: string;
  status: RetentionStatus;
  policy: RetentionPolicy;
  expires_at?: string;
  protected_reason?: string;
}

/**
 * Session capture state
 */
export interface SessionState {
  session_id: string;
  log_path: string;
  issue_number: number;
  start_time: string;
  status: 'active' | 'stopped';
}

/**
 * Redaction patterns for sensitive data
 */
export interface RedactionPatterns {
  api_keys: boolean;
  jwt_tokens: boolean;
  passwords: boolean;
  credit_cards: boolean;
  email_addresses: boolean;
  custom_patterns?: string[];
}

/**
 * Search options
 */
export interface SearchOptions {
  query: string;
  filters?: {
    issue_number?: number;
    log_type?: LogType | LogType[];
    since_date?: string;
    until_date?: string;
    status?: LogStatus | LogStatus[];
  };
  options?: {
    regex?: boolean;
    local_only?: boolean;
    cloud_only?: boolean;
    max_results?: number;
    context_lines?: number;
  };
}

/**
 * Search result
 */
export interface SearchResult {
  log_path: string;
  log_type: LogType;
  source: 'local' | 'archived';
  issue_number?: number;
  date: string;
  matches: SearchMatch[];
}

export interface SearchMatch {
  line_number: number;
  content: string;
  context_before: string[];
  context_after: string[];
}

/**
 * Archive entry in the index
 */
export interface ArchiveEntry {
  log_id: string;
  log_type: LogType;
  issue_number?: number;
  archived_at: string;
  local_path: string;
  cloud_url: string;
  original_size_bytes: number;
  compressed_size_bytes?: number;
  retention_policy: {
    local_days: number;
    cloud_policy: number | 'forever';
  };
  delete_local_after?: string;
}

/**
 * Type-aware archive index
 */
export interface ArchiveIndex {
  version: string;
  type_aware: boolean;
  updated_at: string;
  archives: ArchiveEntry[];
  by_type: {
    [type in LogType]?: {
      count: number;
      total_size_mb: number;
    };
  };
}

/**
 * Analysis result
 */
export interface AnalysisResult {
  log_path: string;
  analysis_type: 'errors' | 'patterns' | 'time' | 'summary';
  findings: AnalysisFinding[];
  summary: string;
}

export interface AnalysisFinding {
  type: string;
  count: number;
  locations: string[];
  severity?: 'info' | 'warning' | 'error';
  recommendation?: string;
}

/**
 * Audit result for storage analysis
 */
export interface AuditResult {
  total_logs: number;
  total_size_mb: number;
  by_type: {
    [type in LogType]?: {
      count: number;
      size_mb: number;
      oldest: string;
      newest: string;
    };
  };
  issues: AuditIssue[];
  recommendations: string[];
}

export interface AuditIssue {
  type: 'orphaned' | 'missing_metadata' | 'invalid_format' | 'oversized';
  path: string;
  details: string;
}

/**
 * Full configuration schema
 */
export interface LogsConfig {
  schema_version: string;
  storage: {
    local_path: string;
    cloud_archive_path: string;
    cloud_logs_path: string;
    cloud_summaries_path: string;
    archive_index_file: string;
    provider: 'local' | 's3' | 'r2' | 'gcs';
    bucket?: string;
    limits: {
      max_session_size_mb: number;
      max_log_size_mb: number;
      warn_session_size_mb: number;
      total_storage_warn_gb: number;
    };
  };
  retention: {
    default: Omit<RetentionPolicy, 'pattern'>;
    paths: RetentionPolicy[];
  };
  auto_backup: {
    enabled: boolean;
    trigger_on_init: boolean;
    trigger_on_session_start: boolean;
    backup_older_than_days: number;
    generate_summaries: boolean;
  };
  summarization: {
    enabled: boolean;
    auto_generate_on_archive: boolean;
    model: string;
    store_with_logs: boolean;
    separate_paths: boolean;
    format: 'markdown' | 'json';
  };
  archive: {
    auto_archive_on: {
      work_complete: boolean;
      issue_close: boolean;
      manual_trigger: boolean;
    };
    compression: CompressionConfig;
    post_archive: {
      update_archive_index: boolean;
      comment_on_issue: boolean;
      remove_from_local: boolean;
      keep_index: boolean;
    };
  };
  session_logging: {
    enabled: boolean;
    auto_capture: boolean;
    format: 'markdown' | 'json';
    include_timestamps: boolean;
    redact_sensitive: boolean;
    auto_name_by_issue: boolean;
    model_name: string;
    redaction_patterns: RedactionPatterns;
  };
  search: {
    index_local: boolean;
    search_cloud: boolean;
    max_results: number;
    default_context_lines: number;
  };
  integration: {
    github: {
      enabled: boolean;
      comment_on_capture: boolean;
      comment_on_archive: boolean;
    };
    faber: {
      auto_capture: boolean;
      auto_archive_on_complete: boolean;
    };
  };
  docs_integration: {
    enabled: boolean;
    copy_summary_to_docs: boolean;
    docs_path: string;
    update_index: boolean;
    index_file: string;
    summary_filename_pattern: string;
    index_format: 'table' | 'list';
    max_index_entries: number;
  };
}

/**
 * Dependencies injected into LogManager
 */
export interface LogsDependencies {
  fileStorage?: FileStorage;
  workProvider?: WorkProvider;
  llmProvider?: LLMProvider;
  config?: LogsConfig;
}

/**
 * Result types for operations
 */
export interface WriteResult {
  status: 'success' | 'failure';
  log_id: string;
  log_type: LogType;
  log_path: string;
  size_bytes: number;
  validation: 'passed' | 'failed';
  message: string;
  errors?: string[];
}

export interface CaptureResult {
  status: 'success' | 'failure';
  session_id: string;
  log_path: string;
  operation: 'start' | 'append' | 'stop';
  message: string;
  metrics?: {
    duration_seconds: number;
    conversation_turns: number;
    token_count: number;
  };
}

export interface ArchiveResult {
  status: 'success' | 'partial' | 'failure';
  logs_archived: Array<{
    log_id: string;
    log_type: LogType;
    cloud_url: string;
    original_size_bytes: number;
    compressed_size_bytes?: number;
  }>;
  logs_protected: Array<{
    log_id: string;
    reason: string;
  }>;
  space_freed_mb: number;
  space_uploaded_mb: number;
  message: string;
  errors?: string[];
}

export interface CleanupResult {
  status: 'success' | 'failure';
  files_deleted: number;
  space_freed_mb: number;
  by_type: {
    [type in LogType]?: {
      deleted: number;
      size_mb: number;
    };
  };
  message: string;
}

export interface SearchResults {
  status: 'success' | 'failure';
  total_matches: number;
  results: SearchResult[];
  sources: {
    local: number;
    archived: number;
  };
  message: string;
}
```

### 2.3 Main API Class

```typescript
// packages/ts/logs/src/log-manager.ts

import {
  LogsConfig,
  LogsDependencies,
  LogType,
  LogMetadata,
  LogEntry,
  WriteResult,
  CaptureResult,
  SearchOptions,
  SearchResults,
  ArchiveResult,
  CleanupResult,
  AnalysisResult,
  AuditResult,
  RetentionStatusResult,
} from './types';

export class LogManager {
  private config: LogsConfig;
  private writer: LogWriter;
  private capturer: SessionCapturer;
  private searcher: LogSearcher;
  private archiver: LogArchiver;
  private analyzer: LogAnalyzer;
  private auditor: LogAuditor;
  private validator: LogValidator;
  private archiveIndex: ArchiveIndex;

  constructor(deps: LogsDependencies = {}) {
    this.config = deps.config ?? loadDefaultConfig();
    this.writer = new LogWriter(deps);
    this.capturer = new SessionCapturer(deps);
    this.searcher = new LogSearcher(deps);
    this.archiver = new LogArchiver(deps);
    this.analyzer = new LogAnalyzer();
    this.auditor = new LogAuditor(deps);
    this.validator = new LogValidator();
    this.archiveIndex = new ArchiveIndex(this.config);
  }

  // ═══════════════════════════════════════════════════════════════
  // LOG CREATION
  // ═══════════════════════════════════════════════════════════════

  /**
   * Write a log entry using type-specific template
   *
   * @example
   * const result = await logManager.write({
   *   log_type: 'build',
   *   title: 'Production Build',
   *   data: {
   *     build_id: 'build-123',
   *     build_system: 'npm',
   *     trigger: 'ci',
   *     status: 'success'
   *   }
   * });
   */
  async write(options: {
    log_type: LogType;
    title: string;
    data: Record<string, unknown>;
    output_path?: string;
    validate_only?: boolean;
    dry_run?: boolean;
  }): Promise<WriteResult>;

  /**
   * List available log types with their schemas
   */
  getLogTypes(): Array<{
    type: LogType;
    description: string;
    schema_path: string;
    template_path: string;
  }>;

  // ═══════════════════════════════════════════════════════════════
  // SESSION CAPTURE
  // ═══════════════════════════════════════════════════════════════

  /**
   * Start capturing a new session
   *
   * @example
   * const result = await logManager.startCapture({
   *   issue_number: 123,
   *   context: { branch: 'feat/auth' }
   * });
   */
  async startCapture(options: {
    issue_number: number;
    context?: {
      repository?: string;
      branch?: string;
      model?: string;
    };
    redact_sensitive?: boolean;
  }): Promise<CaptureResult>;

  /**
   * Append message to active session
   */
  async appendToSession(options: {
    role: 'user' | 'claude' | 'system';
    message: string;
    session_id?: string;
  }): Promise<CaptureResult>;

  /**
   * Stop active session capture
   */
  async stopCapture(options?: {
    session_id?: string;
    generate_summary?: boolean;
  }): Promise<CaptureResult>;

  /**
   * Get active session state
   */
  getActiveSession(): SessionState | null;

  // ═══════════════════════════════════════════════════════════════
  // SEARCH
  // ═══════════════════════════════════════════════════════════════

  /**
   * Search logs with hybrid local + cloud search
   *
   * @example
   * const results = await logManager.search({
   *   query: 'OAuth implementation',
   *   filters: {
   *     log_type: 'session',
   *     since_date: '2025-01-01'
   *   },
   *   options: {
   *     max_results: 50,
   *     context_lines: 5
   *   }
   * });
   */
  async search(options: SearchOptions): Promise<SearchResults>;

  /**
   * Search local logs only (fast)
   */
  async searchLocal(query: string, filters?: SearchOptions['filters']): Promise<SearchResults>;

  /**
   * Search archived logs only (comprehensive)
   */
  async searchArchived(query: string, filters?: SearchOptions['filters']): Promise<SearchResults>;

  // ═══════════════════════════════════════════════════════════════
  // READING
  // ═══════════════════════════════════════════════════════════════

  /**
   * Read a log entry by path or issue number
   */
  async read(identifier: string | number): Promise<LogEntry | null>;

  /**
   * List logs with optional filtering
   */
  async list(options?: {
    log_type?: LogType | LogType[];
    issue_number?: number;
    status?: LogStatus | LogStatus[];
    since?: string;
    until?: string;
    limit?: number;
  }): Promise<LogEntry[]>;

  // ═══════════════════════════════════════════════════════════════
  // ARCHIVAL
  // ═══════════════════════════════════════════════════════════════

  /**
   * Archive logs based on retention policy
   *
   * @example
   * // Archive all expired logs
   * const result = await logManager.archive({
   *   trigger: 'retention_expired'
   * });
   *
   * // Archive logs for specific issue
   * const result = await logManager.archive({
   *   issue_number: 123,
   *   trigger: 'issue_closed'
   * });
   */
  async archive(options: {
    issue_number?: number;
    log_type?: LogType | LogType[];
    trigger: 'issue_closed' | 'pr_merged' | 'retention_expired' | 'manual';
    force?: boolean;
    dry_run?: boolean;
  }): Promise<ArchiveResult>;

  /**
   * Clean up local storage based on retention policies
   */
  async cleanup(options?: {
    log_type?: LogType | LogType[];
    dry_run?: boolean;
  }): Promise<CleanupResult>;

  /**
   * Get retention status for logs
   */
  async getRetentionStatus(options?: {
    log_type?: LogType;
  }): Promise<RetentionStatusResult[]>;

  /**
   * Verify archive integrity
   */
  async verifyArchive(): Promise<{
    status: 'healthy' | 'issues_found';
    total_archived: number;
    verified: number;
    missing: number;
    issues: Array<{ log_id: string; issue: string }>;
  }>;

  // ═══════════════════════════════════════════════════════════════
  // ANALYSIS
  // ═══════════════════════════════════════════════════════════════

  /**
   * Analyze logs for patterns and errors
   *
   * @example
   * const result = await logManager.analyze({
   *   log_path: '/logs/session/session-123.md',
   *   analysis_type: 'errors'
   * });
   */
  async analyze(options: {
    log_path: string;
    analysis_type: 'errors' | 'patterns' | 'time' | 'summary';
  }): Promise<AnalysisResult>;

  /**
   * Extract errors from build/test logs
   */
  async extractErrors(logPath: string): Promise<AnalysisFinding[]>;

  /**
   * Find recurring patterns across logs
   */
  async findPatterns(options: {
    log_type: LogType;
    since?: string;
  }): Promise<AnalysisFinding[]>;

  // ═══════════════════════════════════════════════════════════════
  // AUDITING
  // ═══════════════════════════════════════════════════════════════

  /**
   * Audit log storage for issues and recommendations
   */
  async audit(): Promise<AuditResult>;

  /**
   * Discover all logs in the project
   */
  async discoverLogs(): Promise<{
    total: number;
    by_type: { [type in LogType]?: number };
    paths: string[];
  }>;

  // ═══════════════════════════════════════════════════════════════
  // VALIDATION
  // ═══════════════════════════════════════════════════════════════

  /**
   * Validate a log against its type schema
   */
  async validate(logPath: string): Promise<{
    valid: boolean;
    errors: string[];
    warnings: string[];
  }>;

  /**
   * Classify an untyped log into a type
   */
  async classify(logPath: string): Promise<{
    suggested_type: LogType;
    confidence: number;
    reasons: string[];
  }>;

  // ═══════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════════

  /**
   * Initialize logs plugin configuration
   */
  static async initialize(force?: boolean): Promise<{
    status: 'success' | 'exists' | 'failure';
    config_path: string;
    message: string;
  }>;

  /**
   * Load configuration from file
   */
  static loadConfig(configPath?: string): LogsConfig;

  /**
   * Get current configuration
   */
  getConfig(): LogsConfig;

  /**
   * Get retention policy for a log path
   */
  getRetentionPolicy(logPath: string): RetentionPolicy;
}
```

---

## 3. Operation Mappings

### 3.1 Skill to SDK Method Mapping

| Plugin Skill | SDK Method | CLI Command |
|-------------|-----------|-------------|
| log-writer | `logManager.write()` | `fractary logs write` |
| log-capturer | `logManager.startCapture()` | `fractary logs capture` |
| log-capturer | `logManager.stopCapture()` | `fractary logs stop` |
| log-capturer | `logManager.appendToSession()` | (internal) |
| log-searcher | `logManager.search()` | `fractary logs search` |
| log-lister | `logManager.list()` | `fractary logs list` |
| log-archiver | `logManager.archive()` | `fractary logs archive` |
| log-archiver | `logManager.cleanup()` | `fractary logs cleanup` |
| log-analyzer | `logManager.analyze()` | `fractary logs analyze` |
| log-auditor | `logManager.audit()` | `fractary logs audit` |
| log-validator | `logManager.validate()` | (internal) |
| log-classifier | `logManager.classify()` | (internal) |
| log-summarizer | (uses LLMProvider) | `fractary logs summarize` |
| (read) | `logManager.read()` | `fractary logs read` |

### 3.2 Detailed Operation Specifications

#### 3.2.1 Write Log

**Plugin Skill:** `log-writer`
**SDK Method:** `logManager.write(options)`
**CLI Command:** `fractary logs write`

```bash
# CLI Usage
fractary logs write --type <type> --title <title> [--data <json>] [--validate-only] [--dry-run]

# Examples
fractary logs write --type build --title "Production Build" --data '{"build_system":"npm","status":"success"}'
fractary logs write --type session --title "Auth implementation" --data '{"issue_number":123}'
```

**SDK Usage:**
```typescript
const result = await logManager.write({
  log_type: 'build',
  title: 'Production Build',
  data: {
    build_id: 'build-20250115-001',
    build_system: 'npm',
    trigger: 'ci',
    status: 'success',
    duration_seconds: 120
  }
});

// Result
{
  status: 'success',
  log_id: 'build-20250115-001',
  log_type: 'build',
  log_path: '.fractary/logs/builds/build-20250115-001.md',
  size_bytes: 1250,
  validation: 'passed',
  message: 'Log created: build-20250115-001.md'
}
```

**Type-Specific Schema Validation:**
| Log Type | Required Fields | Optional Fields |
|----------|----------------|-----------------|
| session | session_id, issue_number, status | model, branch, conversation_content |
| build | build_id, build_system, trigger, status | duration_seconds, exit_code |
| deployment | deployment_id, environment, status | version, health_check_passed |
| test | test_id, framework, status | duration_seconds, passed, failed |
| audit | audit_type, actor, action | resource, details |
| workflow | workflow_id, phase, phase_status | work_id, duration_seconds |

#### 3.2.2 Session Capture

**Plugin Skill:** `log-capturer`
**SDK Methods:** `startCapture()`, `appendToSession()`, `stopCapture()`
**CLI Commands:** `fractary logs capture`, `fractary logs stop`

```bash
# CLI Usage
fractary logs capture --issue <number> [--branch <name>] [--no-redact]
fractary logs stop [--session <id>] [--summarize]

# Examples
fractary logs capture --issue 123 --branch feat/auth
fractary logs stop --summarize
```

**SDK Usage:**
```typescript
// Start capture
const startResult = await logManager.startCapture({
  issue_number: 123,
  context: {
    repository: 'fractary/claude-plugins',
    branch: 'feat/123-auth',
    model: 'claude-sonnet-4.5'
  },
  redact_sensitive: true
});

// Append messages (called internally during session)
await logManager.appendToSession({
  role: 'user',
  message: 'Create an authentication module'
});

// Stop capture
const stopResult = await logManager.stopCapture({
  generate_summary: true
});

// Stop Result
{
  status: 'success',
  session_id: '550e8400-e29b-41d4-a716-446655440000',
  log_path: '.fractary/logs/sessions/session-550e8400.md',
  operation: 'stop',
  message: 'Session finalized',
  metrics: {
    duration_seconds: 9000,
    conversation_turns: 45,
    token_count: 12500
  }
}
```

**Redaction Patterns:**
| Pattern | Example | Replacement |
|---------|---------|-------------|
| API Keys | `sk-proj-abc123...` | `[REDACTED:API_KEY]` |
| JWT Tokens | `eyJhbGciOiJ...` | `[REDACTED:JWT]` |
| Passwords | `password: secret123` | `password: [REDACTED:PASSWORD]` |
| Credit Cards | `4111-1111-1111-1111` | `[REDACTED:CREDIT_CARD]` |
| GitHub Tokens | `ghp_xxxxxxxxxxxx` | `[REDACTED:GH_TOKEN]` |

#### 3.2.3 Search Logs

**Plugin Skill:** `log-searcher`
**SDK Method:** `logManager.search(options)`
**CLI Command:** `fractary logs search`

```bash
# CLI Usage
fractary logs search <query> [--type <type>] [--issue <number>] [--since <date>] [--local-only] [--cloud-only] [--max <n>]

# Examples
fractary logs search "OAuth implementation"
fractary logs search "error" --type build --since 2025-01-01
fractary logs search "deployment" --cloud-only --max 50
```

**SDK Usage:**
```typescript
const results = await logManager.search({
  query: 'OAuth implementation',
  filters: {
    log_type: ['session', 'debug'],
    since_date: '2025-01-01',
    issue_number: 123
  },
  options: {
    max_results: 50,
    context_lines: 3
  }
});

// Result
{
  status: 'success',
  total_matches: 5,
  results: [
    {
      log_path: '.fractary/logs/sessions/session-123.md',
      log_type: 'session',
      source: 'local',
      issue_number: 123,
      date: '2025-01-15T09:00:00Z',
      matches: [
        {
          line_number: 45,
          content: 'Discussion of OAuth implementation approach...',
          context_before: ['...'],
          context_after: ['...']
        }
      ]
    }
  ],
  sources: { local: 3, archived: 2 },
  message: 'Found 5 matches (3 local, 2 archived)'
}
```

**Search Priority:**
1. Local logs searched first (fast)
2. If results < max_results, extend to cloud archive
3. Results ranked by: exact match > partial match, recent > old, session > other types

#### 3.2.4 Archive Logs

**Plugin Skill:** `log-archiver`
**SDK Method:** `logManager.archive(options)`
**CLI Command:** `fractary logs archive`

```bash
# CLI Usage
fractary logs archive [--issue <number>] [--type <type>] [--trigger <trigger>] [--force] [--dry-run]

# Examples
fractary logs archive --trigger retention_expired
fractary logs archive --issue 123 --trigger issue_closed
fractary logs archive --type test --dry-run
```

**SDK Usage:**
```typescript
const result = await logManager.archive({
  trigger: 'retention_expired',
  log_type: ['session', 'test', 'build']
});

// Result
{
  status: 'success',
  logs_archived: [
    {
      log_id: 'session-001',
      log_type: 'session',
      cloud_url: 'r2://logs/2025/01/session/session-001.md.gz',
      original_size_bytes: 125000,
      compressed_size_bytes: 42000
    }
    // ... more logs
  ],
  logs_protected: [
    {
      log_id: 'session-002',
      reason: 'keep_if_linked_to_open_issue'
    }
  ],
  space_freed_mb: 2.9,
  space_uploaded_mb: 20.3,
  message: 'Archived 45 logs across 3 types'
}
```

**Archive Process:**
1. Discover logs matching criteria (via log-lister)
2. Load retention policies from config (path-based matching)
3. Calculate retention status (active/expiring/expired/protected)
4. Apply retention exceptions
5. Compress logs > threshold_mb
6. Upload to cloud via FileStorage
7. Update type-aware archive index
8. Clean local storage (per retention policy)
9. Comment on issue (if configured)

#### 3.2.5 Cleanup Logs

**Plugin Skill:** `log-archiver`
**SDK Method:** `logManager.cleanup(options)`
**CLI Command:** `fractary logs cleanup`

```bash
# CLI Usage
fractary logs cleanup [--type <type>] [--dry-run]

# Examples
fractary logs cleanup
fractary logs cleanup --type test --dry-run
```

**SDK Usage:**
```typescript
const result = await logManager.cleanup({
  log_type: 'test',
  dry_run: false
});

// Result
{
  status: 'success',
  files_deleted: 30,
  space_freed_mb: 8.7,
  by_type: {
    test: { deleted: 30, size_mb: 8.7 }
  },
  message: 'Cleaned up 30 test logs, freed 8.7 MB'
}
```

#### 3.2.6 Analyze Logs

**Plugin Skill:** `log-analyzer`
**SDK Method:** `logManager.analyze(options)`
**CLI Command:** `fractary logs analyze`

```bash
# CLI Usage
fractary logs analyze <log-path> --type <analysis-type>

# Examples
fractary logs analyze .fractary/logs/builds/build-001.md --type errors
fractary logs analyze .fractary/logs/sessions/session-001.md --type summary
```

**SDK Usage:**
```typescript
const result = await logManager.analyze({
  log_path: '.fractary/logs/builds/build-001.md',
  analysis_type: 'errors'
});

// Result
{
  log_path: '.fractary/logs/builds/build-001.md',
  analysis_type: 'errors',
  findings: [
    {
      type: 'TypeScriptError',
      count: 3,
      locations: ['src/index.ts:45', 'src/utils.ts:12', 'src/api.ts:88'],
      severity: 'error',
      recommendation: 'Fix type mismatches in these files'
    }
  ],
  summary: 'Found 3 TypeScript errors across 3 files'
}
```

**Analysis Types:**
| Type | Description | Output |
|------|-------------|--------|
| errors | Extract error messages and stack traces | Error locations, counts, patterns |
| patterns | Find recurring patterns | Common sequences, repeated issues |
| time | Time-series analysis | Duration trends, peak activity |
| summary | Generate executive summary | Key events, decisions, outcomes |

#### 3.2.7 Audit Storage

**Plugin Skill:** `log-auditor`
**SDK Method:** `logManager.audit()`
**CLI Command:** `fractary logs audit`

```bash
# CLI Usage
fractary logs audit

# Output
Storage Audit Report
───────────────────────────────────────
Total: 150 logs | 45.3 MB

By Type:
  session:    45 logs | 15.2 MB | oldest: 2024-12-01 | newest: 2025-01-15
  build:      60 logs | 18.5 MB | oldest: 2024-11-15 | newest: 2025-01-15
  test:       40 logs | 10.1 MB | oldest: 2025-01-01 | newest: 2025-01-15
  deployment:  5 logs |  1.5 MB | oldest: 2024-10-01 | newest: 2025-01-10

Issues Found:
  - Orphaned log: .fractary/logs/unknown/old-log.md
  - Missing metadata: .fractary/logs/sessions/session-orphan.md

Recommendations:
  - Archive 30 expired test logs (3.2 MB)
  - Classify 2 untyped logs
  - Run cleanup to free 5.4 MB
```

---

## 4. Log Type System

### 4.1 Built-in Log Types

| Type | Purpose | Retention | Priority |
|------|---------|-----------|----------|
| session | Claude Code conversations | 7d local / forever cloud | high |
| build | Build process output | 3d local / 30d cloud | medium |
| deployment | Release/deploy logs | 30d local / forever cloud | critical |
| test | Test execution | 3d local / 7d cloud | low |
| debug | Debug sessions | 7d local / 30d cloud | medium |
| audit | Compliance/security | 90d local / forever cloud | critical |
| operational | Monitoring/metrics | 14d local / 90d cloud | medium |
| workflow | FABER workflow execution | 7d local / forever cloud | high |
| changelog | Release changelogs | 7d local / forever cloud | high |

### 4.2 Type Context Structure

Each log type has a context directory:

```
types/{log_type}/
├── schema.json           # JSON Schema for validation
├── template.md           # Mustache template for rendering
├── standards.md          # Type-specific conventions
└── validation-rules.md   # Additional validation rules
```

### 4.3 Type Registration

```typescript
// Register custom log type
logManager.registerType({
  type: 'custom',
  schema: customSchema,
  template: customTemplate,
  retention: {
    local_days: 14,
    cloud_days: 90,
    priority: 'medium'
  }
});
```

---

## 5. Retention System

### 5.1 Path-Based Matching

```typescript
function matchRetentionPolicy(logPath: string, config: LogsConfig): RetentionPolicy {
  const relativePath = getRelativePath(logPath);

  // Test against each pattern in order
  for (const policy of config.retention.paths) {
    if (matchesGlob(relativePath, policy.pattern)) {
      return policy;
    }
  }

  // Fall back to default
  return { pattern: '*', ...config.retention.default };
}
```

### 5.2 Retention Exceptions

| Exception | Description | Applies To |
|-----------|-------------|------------|
| `keep_if_linked_to_open_issue` | Don't delete if issue still open | session, build, debug |
| `keep_if_referenced_in_docs` | Don't delete if referenced in documentation | session, deployment, changelog |
| `keep_recent_n` | Always keep N most recent logs | all types |
| `never_delete_production` | Never auto-delete production logs | deployment |
| `never_delete_security_incidents` | Never auto-delete security audit logs | audit |
| `never_delete_compliance_audits` | Never auto-delete compliance logs | audit |

### 5.3 Retention Status Calculation

```typescript
function calculateRetentionStatus(log: LogEntry, policy: RetentionPolicy): RetentionStatus {
  const age = daysSince(log.metadata.date);

  // Check exceptions first
  if (isProtected(log, policy.retention_exceptions)) {
    return 'protected';
  }

  // Check age against policy
  if (age > policy.local_days) {
    return 'expired';
  } else if (age > policy.local_days - 3) {
    return 'expiring_soon';
  }

  return 'active';
}
```

---

## 6. CLI Implementation

### 6.1 Command Structure

```
fractary logs <command> [options]

Commands:
  init              Initialize logs plugin configuration
  write             Write a log entry
  capture           Start session capture
  stop              Stop session capture
  read <id>         Read a log entry
  list              List logs
  search <query>    Search logs
  analyze <path>    Analyze log content
  archive           Archive logs to cloud
  cleanup           Clean up local storage
  audit             Audit log storage
  verify            Verify archive integrity
```

### 6.2 Command Implementations

```typescript
// packages/ts/cli/src/commands/logs.ts

import { LogManager } from '@fractary/logs';
import { Command } from 'commander';

export function registerLogsCommands(program: Command): void {
  const logs = program.command('logs').description('Log management');

  logs
    .command('init')
    .description('Initialize logs plugin configuration')
    .option('--force', 'Overwrite existing configuration')
    .action(async (options) => {
      const result = await LogManager.initialize(options.force);
      console.log(result.message);
    });

  logs
    .command('write')
    .description('Write a log entry')
    .requiredOption('--type <type>', 'Log type')
    .requiredOption('--title <title>', 'Log title')
    .option('--data <json>', 'Log data as JSON')
    .option('--validate-only', 'Only validate, don\'t write')
    .option('--dry-run', 'Show what would be written')
    .action(async (options) => {
      const logManager = new LogManager();
      const data = options.data ? JSON.parse(options.data) : {};
      const result = await logManager.write({
        log_type: options.type,
        title: options.title,
        data,
        validate_only: options.validateOnly,
        dry_run: options.dryRun
      });
      formatOutput(result);
    });

  logs
    .command('capture')
    .description('Start session capture')
    .requiredOption('--issue <number>', 'Issue number', parseInt)
    .option('--branch <name>', 'Branch name')
    .option('--no-redact', 'Disable sensitive data redaction')
    .action(async (options) => {
      const logManager = new LogManager();
      const result = await logManager.startCapture({
        issue_number: options.issue,
        context: { branch: options.branch },
        redact_sensitive: options.redact !== false
      });
      formatOutput(result);
    });

  logs
    .command('stop')
    .description('Stop session capture')
    .option('--session <id>', 'Specific session ID')
    .option('--summarize', 'Generate summary')
    .action(async (options) => {
      const logManager = new LogManager();
      const result = await logManager.stopCapture({
        session_id: options.session,
        generate_summary: options.summarize
      });
      formatOutput(result);
    });

  logs
    .command('search <query>')
    .description('Search logs')
    .option('--type <type>', 'Filter by log type')
    .option('--issue <number>', 'Filter by issue', parseInt)
    .option('--since <date>', 'Start date')
    .option('--until <date>', 'End date')
    .option('--local-only', 'Search local only')
    .option('--cloud-only', 'Search cloud only')
    .option('--max <n>', 'Max results', parseInt, 100)
    .action(async (query, options) => {
      const logManager = new LogManager();
      const results = await logManager.search({
        query,
        filters: {
          log_type: options.type,
          issue_number: options.issue,
          since_date: options.since,
          until_date: options.until
        },
        options: {
          local_only: options.localOnly,
          cloud_only: options.cloudOnly,
          max_results: options.max
        }
      });
      formatSearchResults(results);
    });

  logs
    .command('archive')
    .description('Archive logs to cloud')
    .option('--issue <number>', 'Archive for specific issue', parseInt)
    .option('--type <type>', 'Archive specific type')
    .option('--trigger <trigger>', 'Archive trigger', 'manual')
    .option('--force', 'Skip safety checks')
    .option('--dry-run', 'Preview without archiving')
    .action(async (options) => {
      const logManager = new LogManager();
      const result = await logManager.archive({
        issue_number: options.issue,
        log_type: options.type,
        trigger: options.trigger,
        force: options.force,
        dry_run: options.dryRun
      });
      formatArchiveOutput(result);
    });

  // ... additional commands
}
```

---

## 7. Configuration Schema

### 7.1 Configuration Location

```
.fractary/plugins/logs/config.json
```

### 7.2 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FRACTARY_LOGS_LOCAL_PATH` | Local logs directory | `/logs` |
| `FRACTARY_LOGS_PROVIDER` | Cloud storage provider | `s3` |
| `FRACTARY_LOGS_BUCKET` | Cloud storage bucket | `fractary-logs` |
| `FRACTARY_LOGS_MAX_SESSION_SIZE_MB` | Max session log size | `50` |
| `FRACTARY_LOGS_REDACT_SENSITIVE` | Enable redaction | `true` |

---

## 8. Plugin Migration

### 8.1 Migration Summary

| Plugin Component | SDK Replacement | Notes |
|-----------------|-----------------|-------|
| `log-writer/` skill | `LogManager.write()` | Template rendering in SDK |
| `log-capturer/` skill | `LogManager.startCapture()` etc. | Session state in SDK |
| `log-searcher/` skill | `LogManager.search()` | Hybrid search in SDK |
| `log-archiver/` skill | `LogManager.archive()` | Uses FileStorage |
| `log-analyzer/` skill | `LogManager.analyze()` | Analysis logic in SDK |
| `log-auditor/` skill | `LogManager.audit()` | Storage analysis in SDK |
| `log-lister/` skill | `LogManager.list()` | Listing/filtering in SDK |
| `log-validator/` skill | `LogManager.validate()` | Schema validation in SDK |
| `log-classifier/` skill | `LogManager.classify()` | Type detection in SDK |
| `log-summarizer/` skill | Uses LLMProvider | LLM integration point |
| `log-manager` agent | Thin orchestration layer | Routes to CLI/SDK |
| `commands/*.md` | CLI commands | Replaced by `fractary logs` |
| `config/*.json` | SDK config | Same schema, loaded by SDK |
| `types/*/` | SDK type definitions | Schema/template in SDK |
| `scripts/*.sh` | SDK implementation | Shell scripts replaced |

### 8.2 Type Context Migration

Plugin type context files move to SDK:

```
plugins/logs/types/{type}/         →  packages/ts/logs/src/types/{type}/
├── schema.json                    →  ├── schema.ts
├── template.md                    →  ├── template.ts
├── standards.md                   →  ├── standards.ts
└── validation-rules.md            →  └── validation.ts
```

### 8.3 Backward Compatibility

- Plugin commands continue to work during transition
- Configuration schema remains compatible (v2.0)
- Archive index format unchanged
- Log file format unchanged (frontmatter + markdown)

---

## 9. Integration Points

### 9.1 FABER Integration

| FABER Phase | Log Operation | Trigger |
|-------------|---------------|---------|
| Any | `startCapture()` | FABER workflow start |
| Any | `appendToSession()` | During workflow execution |
| Any | `stopCapture()` | FABER workflow complete |
| Any | `write()` (workflow type) | Phase transitions |
| Release | `archive()` | Workflow completion |

### 9.2 Work Plugin Integration

```typescript
// Check if issue is open (for retention exception)
const issue = await workProvider.fetchIssue(log.metadata.issue_number);
if (issue.state === 'open') {
  return 'protected'; // keep_if_linked_to_open_issue
}

// Comment on archive
await workProvider.createComment(issueNumber, {
  body: `📦 Session logs archived: [${archiveUrl}](${archiveUrl})`
});
```

### 9.3 File Plugin Integration

```typescript
// Upload to cloud storage
const cloudUrl = await fileStorage.upload({
  source: compressedLogPath,
  destination: `archive/logs/${year}/${month}/${logType}/${filename}.gz`,
  contentType: 'application/gzip'
});

// Read from archive
const content = await fileStorage.read(archiveEntry.cloud_url);
```

---

## 10. Error Handling

### 10.1 Error Types

```typescript
import { FractaryError } from '@fractary/core';

export class LogsError extends FractaryError {
  constructor(message: string, code: string, details?: Record<string, unknown>) {
    super(message, code, details);
    this.name = 'LogsError';
  }
}

export class LogTypeNotFoundError extends LogsError {
  constructor(logType: string) {
    super(
      `Unknown log type: ${logType}`,
      'LOG_TYPE_NOT_FOUND',
      { logType, available: getAvailableTypes() }
    );
  }
}

export class ValidationError extends LogsError {
  constructor(logPath: string, errors: string[]) {
    super(
      `Log validation failed: ${logPath}`,
      'VALIDATION_FAILED',
      { logPath, errors }
    );
  }
}

export class NoActiveSessionError extends LogsError {
  constructor() {
    super(
      'No active capture session',
      'NO_ACTIVE_SESSION',
      {}
    );
  }
}

export class ArchiveError extends LogsError {
  constructor(logType: string, reason: string) {
    super(
      `Failed to archive ${logType} logs: ${reason}`,
      'ARCHIVE_FAILED',
      { logType, reason }
    );
  }
}

export class RetentionConflictError extends LogsError {
  constructor(logPath: string, conflicts: string[]) {
    super(
      `Retention policy conflict for ${logPath}`,
      'RETENTION_CONFLICT',
      { logPath, conflicts }
    );
  }
}
```

### 10.2 Error Recovery

| Error | Recovery Action |
|-------|----------------|
| Type not found | List available types, suggest classification |
| Validation failed | Show specific errors, suggest fixes |
| No active session | List recent sessions, suggest starting new |
| Archive upload failed | Keep local, suggest retry |
| Index update failed | Warn user, keep logs locally |
| Cloud search failed | Return local results only |

---

## 11. Testing Strategy

### 11.1 Unit Tests

```typescript
describe('LogManager', () => {
  describe('write', () => {
    it('creates log with type-specific template');
    it('validates against type schema');
    it('applies redaction patterns');
    it('rejects invalid log type');
  });

  describe('capture', () => {
    it('starts new session with issue number');
    it('appends messages with timestamps');
    it('applies redaction to sensitive data');
    it('calculates metrics on stop');
    it('prevents multiple active sessions');
  });

  describe('search', () => {
    it('searches local logs first');
    it('extends to cloud if needed');
    it('respects max_results limit');
    it('ranks results by relevance');
  });

  describe('archive', () => {
    it('respects retention exceptions');
    it('compresses logs over threshold');
    it('updates archive index');
    it('cleans local after successful upload');
    it('keeps local if upload fails');
  });

  describe('retention', () => {
    it('matches path patterns correctly');
    it('applies default for unmatched paths');
    it('calculates expiration correctly');
    it('handles multiple exceptions');
  });
});
```

### 11.2 Integration Tests

```typescript
describe('Logs SDK Integration', () => {
  it('full lifecycle: capture → archive → search');
  it('type-aware archival with correct paths');
  it('retention exception handling');
  it('hybrid search across local and cloud');
});
```

---

## 12. References

- SPEC-00015: FABER Orchestrator Architecture
- SPEC-00016: SDK Architecture & Core Interfaces
- SPEC-00017: Work Tracking SDK
- SPEC-00019: File Storage SDK
- Plugin source: `plugins/logs/`
- Plugin config example: `plugins/logs/config/config.example.json`
