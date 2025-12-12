# SPEC-00021: Spec Management SDK

## Status: Draft
## Version: 1.0.0
## Last Updated: 2025-12-11

---

## 1. Executive Summary

This specification defines the Spec Management SDK (`@fractary/spec`) which provides programmatic specification management for work-driven development. The SDK handles the complete specification lifecycle: creation from context, refinement through feedback, validation against implementation, progress tracking, and lifecycle-based archival.

### 1.1 Scope

**In Scope:**
- Specification generation from conversation/issue context
- Template selection and customization
- Specification validation against implementations
- Refinement workflow with Q&A
- Progress tracking (phases, tasks)
- Bidirectional linking (specs ↔ work items)
- Two-tier storage (local active + cloud archive)
- Archive index management

**Out of Scope:**
- LLM-based content generation (uses LLMProvider from core)
- Work item operations (uses WorkProvider)
- File storage operations (uses FileStorage)
- Git operations (uses RepoProvider)

### 1.2 References

- SPEC-00015: FABER Orchestrator Architecture (parent spec)
- SPEC-00016: SDK Architecture & Core Interfaces
- SPEC-00017: Work Tracking SDK (integration point)
- SPEC-00019: File Storage SDK (archive storage)
- Plugin source: `plugins/spec/`

---

## 2. SDK Implementation

### 2.1 Package Structure

```
packages/
├── ts/
│   └── spec/
│       ├── package.json
│       ├── src/
│       │   ├── index.ts              # Public API exports
│       │   ├── types.ts              # TypeScript interfaces
│       │   ├── spec-manager.ts       # Main orchestration class
│       │   ├── generator.ts          # Spec generation logic
│       │   ├── validator.ts          # Implementation validation
│       │   ├── refiner.ts            # Refinement workflow
│       │   ├── archiver.ts           # Archive operations
│       │   ├── linker.ts             # Work item linking
│       │   ├── updater.ts            # Progress tracking
│       │   ├── templates/            # Built-in templates
│       │   │   ├── basic.ts
│       │   │   ├── feature.ts
│       │   │   ├── bug.ts
│       │   │   ├── infrastructure.ts
│       │   │   └── api.ts
│       │   └── storage/
│       │       ├── local.ts          # Local spec storage
│       │       └── archive-index.ts  # Archive index management
│       └── tests/
└── py/
    └── spec/
        ├── pyproject.toml
        └── src/fractary_spec/
            ├── __init__.py
            ├── types.py
            ├── spec_manager.py
            ├── generator.py
            ├── validator.py
            ├── refiner.py
            ├── archiver.py
            ├── linker.py
            ├── updater.py
            ├── templates/
            └── storage/
```

### 2.2 Core Types

```typescript
// packages/ts/spec/src/types.ts

import { WorkProvider, FileStorage, LLMProvider } from '@fractary/core';

/**
 * Specification metadata stored in frontmatter
 */
export interface SpecMetadata {
  id: string;                    // WORK-00123-feature or SPEC-20250115143000-feature
  title: string;
  work_id?: string;              // Linked work item ID
  work_type: WorkType;
  template: TemplateType;
  created_at: string;            // ISO timestamp
  updated_at: string;
  validation_status?: ValidationStatus;
  validation_date?: string;
  archived_at?: string;
  archive_url?: string;
  source: SpecSource;
}

export type WorkType = 'feature' | 'bug' | 'infrastructure' | 'api' | 'chore' | 'patch';
export type TemplateType = 'basic' | 'feature' | 'bug' | 'infrastructure' | 'api';
export type SpecSource = 'conversation' | 'issue' | 'conversation+issue';
export type ValidationStatus = 'not_validated' | 'partial' | 'complete' | 'failed';

/**
 * Specification file representation
 */
export interface Specification {
  metadata: SpecMetadata;
  content: string;               // Markdown body
  path: string;                  // Local file path
  phases?: SpecPhase[];          // Parsed phases
}

/**
 * Phase within a specification
 */
export interface SpecPhase {
  id: string;                    // phase-1, Phase 1, etc.
  title: string;
  status: PhaseStatus;
  objective?: string;
  tasks: SpecTask[];
  notes?: string[];
  estimated_scope?: string;
}

export type PhaseStatus = 'not_started' | 'in_progress' | 'complete';

export interface SpecTask {
  text: string;
  completed: boolean;
}

/**
 * Validation result from checking implementation
 */
export interface ValidationResult {
  status: ValidationStatus;
  score: number;                 // 0.0 - 1.0
  checks: {
    requirements: ValidationCheck;
    acceptance_criteria: ValidationCheck;
    files_modified: ValidationCheck;
    tests_added: ValidationCheck;
    docs_updated: ValidationCheck;
  };
  summary: string;
}

export interface ValidationCheck {
  status: 'pass' | 'warn' | 'fail';
  completed?: number;
  total?: number;
  details?: string[];
}

/**
 * Refinement question generated during review
 */
export interface RefinementQuestion {
  id: string;
  topic: string;
  question: string;
  rationale: string;             // Why this matters
  suggestions?: string[];        // Possible answers
  answered: boolean;
  answer?: string;
  best_effort_decision?: string;
}

/**
 * Archive entry in the index
 */
export interface ArchiveEntry {
  spec_id: string;
  work_id?: string;
  title: string;
  archived_at: string;
  cloud_url: string;
  size_bytes: number;
  work_type: WorkType;
}

/**
 * Configuration for spec management
 */
export interface SpecConfig {
  schema_version: string;
  storage: {
    local_path: string;          // Default: /specs
    cloud_archive_path: string;  // Pattern: archive/specs/{year}/{spec_id}.md
    archive_index: {
      local_cache: string;
      cloud_backup: string;
    };
  };
  naming: {
    issue_specs: {
      prefix: string;            // WORK
      digits: number;            // 5 (zero-padded)
      phase_format: 'numeric' | 'slug';
      phase_separator: string;
    };
    standalone_specs: {
      prefix: string;            // SPEC
      digits: number;
      auto_increment: boolean;
    };
  };
  archive: {
    strategy: 'lifecycle' | 'manual';
    auto_archive_on: {
      issue_close: boolean;
      pr_merge: boolean;
      faber_release: boolean;
    };
    pre_archive: {
      check_docs_updated: 'warn' | 'require' | 'skip';
      prompt_user: boolean;
      require_validation: boolean;
    };
    post_archive: {
      update_archive_index: boolean;
      comment_on_issue: boolean;
      comment_on_pr: boolean;
      remove_from_local: boolean;
    };
  };
  templates: {
    default: TemplateType;
    custom_template_dir?: string;
  };
}

/**
 * Options for spec generation
 */
export interface GenerateOptions {
  work_id?: string;              // Link to work item
  template?: TemplateType;       // Override auto-detection
  context?: string;              // Additional context
  force?: boolean;               // Create even if exists
  conversation_context?: string; // Full conversation for context-aware generation
}

/**
 * Options for spec validation
 */
export interface ValidateOptions {
  spec_path: string;
  work_id?: string;
  check_git_changes?: boolean;
}

/**
 * Options for spec refinement
 */
export interface RefineOptions {
  work_id: string;
  prompt?: string;               // Focus area for refinement
  round?: number;                // Refinement round (default: 1)
  max_questions?: number;
}

/**
 * Options for archival
 */
export interface ArchiveOptions {
  work_id: string;
  force?: boolean;               // Skip pre-archive checks
  skip_warnings?: boolean;       // Don't prompt for warnings
}

/**
 * Options for spec updates
 */
export interface UpdateOptions {
  spec_path: string;
  phase_id: string;
}

export interface UpdatePhaseStatusOptions extends UpdateOptions {
  status: PhaseStatus;
}

export interface CheckTaskOptions extends UpdateOptions {
  task_text: string;
}

export interface AddNotesOptions extends UpdateOptions {
  notes: string[];
}

export interface BatchUpdateOptions extends UpdateOptions {
  updates: {
    status?: PhaseStatus;
    check_all_tasks?: boolean;
    tasks_to_check?: string[];
    notes?: string[];
  };
}

/**
 * Dependencies injected into SpecManager
 */
export interface SpecDependencies {
  workProvider?: WorkProvider;   // For issue linking
  fileStorage?: FileStorage;     // For cloud archive
  llmProvider?: LLMProvider;     // For refinement Q&A
  config?: SpecConfig;
}

/**
 * Result types for operations
 */
export interface GenerateResult {
  status: 'success' | 'skipped' | 'warning' | 'failure';
  spec_path?: string;
  work_id?: string;
  template?: TemplateType;
  source?: SpecSource;
  existing_specs?: string[];
  message: string;
  warnings?: string[];
  errors?: string[];
}

export interface ValidateResult {
  status: 'success' | 'warning' | 'failure';
  validation: ValidationResult;
  spec_updated: boolean;
  message: string;
  warnings?: string[];
  errors?: string[];
  suggested_fixes?: string[];
}

export interface RefineResult {
  status: 'success' | 'skipped' | 'warning' | 'failure';
  spec_path?: string;
  questions_asked: number;
  questions_answered: number;
  improvements_applied: number;
  best_effort_decisions: number;
  additional_round_recommended: boolean;
  message: string;
}

export interface ArchiveResult {
  status: 'success' | 'failure';
  specs_archived: Array<{
    filename: string;
    cloud_url: string;
    size_bytes: number;
  }>;
  archive_index_updated: boolean;
  github_comments: {
    issue: boolean;
    pr: boolean;
  };
  local_cleanup: boolean;
  message: string;
  errors?: string[];
}

export interface UpdateResult {
  status: 'success' | 'failure';
  operation: string;
  changes: {
    status_updated?: boolean;
    tasks_checked?: number;
    notes_added?: number;
  };
  message: string;
  errors?: string[];
}

export interface ReadResult {
  status: 'success' | 'failure';
  spec?: Specification;
  source: 'local' | 'archive';
  message: string;
  errors?: string[];
}
```

### 2.3 Main API Class

```typescript
// packages/ts/spec/src/spec-manager.ts

import {
  SpecConfig,
  SpecDependencies,
  GenerateOptions,
  GenerateResult,
  ValidateOptions,
  ValidateResult,
  RefineOptions,
  RefineResult,
  ArchiveOptions,
  ArchiveResult,
  UpdatePhaseStatusOptions,
  CheckTaskOptions,
  AddNotesOptions,
  BatchUpdateOptions,
  UpdateResult,
  ReadResult,
  Specification,
  ArchiveEntry,
} from './types';

export class SpecManager {
  private config: SpecConfig;
  private generator: SpecGenerator;
  private validator: SpecValidator;
  private refiner: SpecRefiner;
  private archiver: SpecArchiver;
  private linker: SpecLinker;
  private updater: SpecUpdater;
  private archiveIndex: ArchiveIndex;

  constructor(deps: SpecDependencies = {}) {
    this.config = deps.config ?? loadDefaultConfig();
    this.generator = new SpecGenerator(deps);
    this.validator = new SpecValidator(deps);
    this.refiner = new SpecRefiner(deps);
    this.archiver = new SpecArchiver(deps);
    this.linker = new SpecLinker(deps);
    this.updater = new SpecUpdater();
    this.archiveIndex = new ArchiveIndex(this.config);
  }

  // ═══════════════════════════════════════════════════════════════
  // GENERATION
  // ═══════════════════════════════════════════════════════════════

  /**
   * Generate a new specification from context
   *
   * @example
   * // Generate spec linked to work item
   * const result = await specManager.generate({
   *   work_id: '123',
   *   conversation_context: conversationText
   * });
   *
   * @example
   * // Generate standalone spec with template override
   * const result = await specManager.generate({
   *   template: 'infrastructure',
   *   context: 'Setting up CI/CD pipeline'
   * });
   */
  async generate(options: GenerateOptions): Promise<GenerateResult>;

  /**
   * Auto-detect work ID from current git branch
   * Returns issue number if branch matches patterns like feat/123-name
   */
  async detectWorkIdFromBranch(): Promise<string | null>;

  /**
   * Check if spec(s) already exist for a work item
   */
  async findSpecsForWorkId(workId: string): Promise<string[]>;

  // ═══════════════════════════════════════════════════════════════
  // VALIDATION
  // ═══════════════════════════════════════════════════════════════

  /**
   * Validate implementation against specification
   *
   * Checks:
   * - Requirements coverage
   * - Acceptance criteria completion
   * - Expected files modified
   * - Tests added
   * - Documentation updated
   *
   * @example
   * const result = await specManager.validate({
   *   spec_path: '/specs/WORK-00123-feature.md',
   *   check_git_changes: true
   * });
   */
  async validate(options: ValidateOptions): Promise<ValidateResult>;

  // ═══════════════════════════════════════════════════════════════
  // REFINEMENT
  // ═══════════════════════════════════════════════════════════════

  /**
   * Refine specification through Q&A workflow
   *
   * 1. Analyzes spec for gaps and ambiguities
   * 2. Generates meaningful questions
   * 3. Posts questions to work item
   * 4. Presents questions for user answers
   * 5. Applies improvements based on answers
   * 6. Makes best-effort decisions for unanswered questions
   *
   * @example
   * const result = await specManager.refine({
   *   work_id: '123',
   *   prompt: 'Focus on security implications'
   * });
   */
  async refine(options: RefineOptions): Promise<RefineResult>;

  /**
   * Generate refinement questions without applying changes
   * Useful for preview before full refinement
   */
  async generateRefinementQuestions(
    workId: string,
    prompt?: string
  ): Promise<RefinementQuestion[]>;

  // ═══════════════════════════════════════════════════════════════
  // ARCHIVAL
  // ═══════════════════════════════════════════════════════════════

  /**
   * Archive completed specifications to cloud storage
   *
   * Process:
   * 1. Find all specs for work item
   * 2. Check pre-archive conditions (unless force)
   * 3. Upload to cloud storage
   * 4. Update archive index
   * 5. Comment on work item and PR
   * 6. Remove local files
   *
   * @example
   * const result = await specManager.archive({
   *   work_id: '123',
   *   force: false
   * });
   */
  async archive(options: ArchiveOptions): Promise<ArchiveResult>;

  /**
   * Read a specification (from local or archive)
   * Automatically retrieves from cloud if not local
   */
  async read(workIdOrPath: string): Promise<ReadResult>;

  /**
   * List all archived specs with optional filtering
   */
  async listArchived(filter?: {
    work_type?: WorkType;
    year?: number;
    search?: string;
  }): Promise<ArchiveEntry[]>;

  // ═══════════════════════════════════════════════════════════════
  // PROGRESS TRACKING
  // ═══════════════════════════════════════════════════════════════

  /**
   * Update phase status in specification
   */
  async updatePhaseStatus(options: UpdatePhaseStatusOptions): Promise<UpdateResult>;

  /**
   * Check off a completed task
   */
  async checkTask(options: CheckTaskOptions): Promise<UpdateResult>;

  /**
   * Check off all tasks in a phase
   */
  async checkAllTasks(options: UpdateOptions): Promise<UpdateResult>;

  /**
   * Add implementation notes to a phase
   */
  async addNotes(options: AddNotesOptions): Promise<UpdateResult>;

  /**
   * Batch update a phase (status + tasks + notes)
   */
  async batchUpdate(options: BatchUpdateOptions): Promise<UpdateResult>;

  // ═══════════════════════════════════════════════════════════════
  // LINKING
  // ═══════════════════════════════════════════════════════════════

  /**
   * Link specification to work item via comment
   */
  async linkToWorkItem(specPath: string, workId: string): Promise<void>;

  /**
   * Post archive completion comment to work item and PR
   */
  async postArchiveComment(
    workId: string,
    archiveUrls: string[],
    prNumber?: string
  ): Promise<void>;

  // ═══════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════════

  /**
   * Initialize spec plugin configuration
   */
  static async initialize(force?: boolean): Promise<{
    status: 'success' | 'exists' | 'failure';
    config_path: string;
    message: string;
  }>;

  /**
   * Load configuration from file or return defaults
   */
  static loadConfig(configPath?: string): SpecConfig;

  /**
   * Get current configuration
   */
  getConfig(): SpecConfig;
}
```

---

## 3. Operation Mappings

### 3.1 Skill to SDK Method Mapping

| Plugin Skill | SDK Method | CLI Command |
|-------------|-----------|-------------|
| spec-generator | `specManager.generate()` | `fractary spec create` |
| spec-validator | `specManager.validate()` | `fractary spec validate` |
| spec-archiver | `specManager.archive()` | `fractary spec archive` |
| spec-refiner | `specManager.refine()` | `fractary spec refine` |
| spec-linker | `specManager.linkToWorkItem()` | (internal) |
| spec-updater | `specManager.updatePhaseStatus()` | `fractary spec update` |
| spec-updater | `specManager.checkTask()` | `fractary spec check-task` |
| spec-updater | `specManager.batchUpdate()` | `fractary spec batch-update` |
| spec-initializer | `SpecManager.initialize()` | `fractary spec init` |
| (read) | `specManager.read()` | `fractary spec read` |

### 3.2 Detailed Operation Specifications

#### 3.2.1 Generate Specification

**Plugin Skill:** `spec-generator`
**SDK Method:** `specManager.generate(options)`
**CLI Command:** `fractary spec create`

```bash
# CLI Usage
fractary spec create [--work-id <id>] [--template <type>] [--context <text>] [--force]

# Examples
fractary spec create --work-id 123
fractary spec create --template infrastructure --context "CI/CD setup"
fractary spec create --work-id 123 --force  # Create even if exists
```

**SDK Usage:**
```typescript
const result = await specManager.generate({
  work_id: '123',
  template: 'feature',
  conversation_context: fullConversation,
  force: false
});

// Result
{
  status: 'success',
  spec_path: '/specs/WORK-00123-user-auth.md',
  work_id: '123',
  template: 'feature',
  source: 'conversation+issue',
  message: 'Specification generated: WORK-00123-user-auth.md'
}
```

**Naming Conventions:**
- Issue-linked: `WORK-{issue:05d}-{slug}.md` (e.g., `WORK-00123-feature.md`)
- Standalone: `SPEC-{timestamp}-{slug}.md` (e.g., `SPEC-20250115143000-feature.md`)
- Multi-spec: `WORK-{issue:05d}-{phase:02d}-{slug}.md` (e.g., `WORK-00123-01-auth.md`)

#### 3.2.2 Validate Specification

**Plugin Skill:** `spec-validator`
**SDK Method:** `specManager.validate(options)`
**CLI Command:** `fractary spec validate`

```bash
# CLI Usage
fractary spec validate <spec-path> [--work-id <id>] [--check-git]

# Examples
fractary spec validate /specs/WORK-00123-feature.md
fractary spec validate /specs/WORK-00123-feature.md --check-git
```

**SDK Usage:**
```typescript
const result = await specManager.validate({
  spec_path: '/specs/WORK-00123-feature.md',
  check_git_changes: true
});

// Result
{
  status: 'warning',
  validation: {
    status: 'partial',
    score: 0.8,
    checks: {
      requirements: { status: 'pass', completed: 8, total: 8 },
      acceptance_criteria: { status: 'pass', met: 5, total: 5 },
      files_modified: { status: 'pass' },
      tests_added: { status: 'warn', added: 2, expected: 3 },
      docs_updated: { status: 'fail' }
    },
    summary: '80% complete - tests and docs need attention'
  },
  spec_updated: true,
  warnings: ['Tests incomplete: 2/3', 'Documentation not updated'],
  suggested_fixes: ['Add missing test case', 'Update README']
}
```

**Validation Checks:**
| Check | Description | Status Logic |
|-------|-------------|--------------|
| Requirements | All spec requirements implemented | pass: 100%, warn: 80%+, fail: <80% |
| Acceptance Criteria | Checkbox items completed | pass: 100%, warn: 80%+, fail: <80% |
| Files Modified | Expected files changed (from spec) | pass/fail based on git diff |
| Tests Added | Test files created/modified | pass: expected count, warn: partial |
| Docs Updated | Documentation files updated | pass/fail based on file changes |

#### 3.2.3 Refine Specification

**Plugin Skill:** `spec-refiner`
**SDK Method:** `specManager.refine(options)`
**CLI Command:** `fractary spec refine`

```bash
# CLI Usage
fractary spec refine <work-id> [--prompt <focus>] [--round <n>]

# Examples
fractary spec refine 123
fractary spec refine 123 --prompt "Focus on security"
fractary spec refine 123 --round 2
```

**SDK Usage:**
```typescript
const result = await specManager.refine({
  work_id: '123',
  prompt: 'Focus on API design',
  round: 1
});

// Result
{
  status: 'success',
  spec_path: '/specs/WORK-00123-feature.md',
  questions_asked: 5,
  questions_answered: 3,
  improvements_applied: 7,
  best_effort_decisions: 2,
  additional_round_recommended: false,
  message: 'Specification refined: WORK-00123-feature.md'
}
```

**Refinement Workflow:**
1. Load existing spec for work_id
2. Analyze for gaps, ambiguities, assumptions
3. Generate meaningful questions (not generic)
4. Post questions to work item as comment
5. Present questions via interactive prompt
6. Collect user answers (partial OK)
7. Apply improvements for answered questions
8. Make best-effort decisions for unanswered
9. Update spec with changelog entry
10. Post completion summary to work item

#### 3.2.4 Archive Specification

**Plugin Skill:** `spec-archiver`
**SDK Method:** `specManager.archive(options)`
**CLI Command:** `fractary spec archive`

```bash
# CLI Usage
fractary spec archive <work-id> [--force] [--skip-warnings]

# Examples
fractary spec archive 123
fractary spec archive 123 --force
```

**SDK Usage:**
```typescript
const result = await specManager.archive({
  work_id: '123',
  force: false,
  skip_warnings: false
});

// Result
{
  status: 'success',
  specs_archived: [
    {
      filename: 'WORK-00123-01-auth.md',
      cloud_url: 'https://storage.example.com/specs/2025/123-01.md',
      size_bytes: 15420
    },
    {
      filename: 'WORK-00123-02-oauth.md',
      cloud_url: 'https://storage.example.com/specs/2025/123-02.md',
      size_bytes: 18920
    }
  ],
  archive_index_updated: true,
  github_comments: { issue: true, pr: true },
  local_cleanup: true,
  message: 'Archived 2 specs for issue #123'
}
```

**Archive Process:**
1. Find all specs matching `WORK-{workId:05d}-*.md`
2. Pre-archive checks (unless force):
   - Documentation updated (warn/require/skip per config)
   - Validation passed (if require_validation)
   - User prompt (if prompt_user)
3. Upload each spec to cloud via FileStorage
4. Update archive index (local + cloud backup)
5. Comment on work item with archive URLs
6. Comment on PR (if exists)
7. Remove local spec files
8. Return archive confirmation

#### 3.2.5 Read Specification

**Plugin Skill:** (implicit in commands)
**SDK Method:** `specManager.read(workIdOrPath)`
**CLI Command:** `fractary spec read`

```bash
# CLI Usage
fractary spec read <work-id-or-path>

# Examples
fractary spec read 123              # Find by work ID (local or archive)
fractary spec read /specs/WORK-00123-feature.md
```

**SDK Usage:**
```typescript
const result = await specManager.read('123');

// Result
{
  status: 'success',
  spec: {
    metadata: {
      id: 'WORK-00123-feature',
      title: 'User Authentication',
      work_id: '123',
      work_type: 'feature',
      // ... full metadata
    },
    content: '# User Authentication\n...',
    path: '/specs/WORK-00123-feature.md',
    phases: [/* parsed phases */]
  },
  source: 'local',  // or 'archive'
  message: 'Spec loaded from local storage'
}
```

**Read Logic:**
1. Check local `/specs/` directory first
2. If not found, check archive index
3. If in archive, download from cloud storage
4. Parse frontmatter and content
5. Parse phases if present
6. Return structured specification

#### 3.2.6 Update Progress

**Plugin Skill:** `spec-updater`
**SDK Methods:** `updatePhaseStatus()`, `checkTask()`, `checkAllTasks()`, `addNotes()`, `batchUpdate()`
**CLI Commands:** `fractary spec update`, `fractary spec check-task`, `fractary spec batch-update`

```bash
# CLI Usage
fractary spec update <spec-path> --phase <id> --status <status>
fractary spec check-task <spec-path> --phase <id> --task <text>
fractary spec batch-update <spec-path> --phase <id> --complete

# Examples
fractary spec update /specs/WORK-00123.md --phase phase-1 --status complete
fractary spec check-task /specs/WORK-00123.md --phase phase-1 --task "Create SKILL.md"
fractary spec batch-update /specs/WORK-00123.md --phase phase-1 --complete --notes "Done"
```

**SDK Usage:**
```typescript
// Update phase status
await specManager.updatePhaseStatus({
  spec_path: '/specs/WORK-00123-feature.md',
  phase_id: 'phase-1',
  status: 'complete'
});

// Check single task
await specManager.checkTask({
  spec_path: '/specs/WORK-00123-feature.md',
  phase_id: 'phase-1',
  task_text: 'Create SKILL.md'
});

// Batch update (status + all tasks + notes)
await specManager.batchUpdate({
  spec_path: '/specs/WORK-00123-feature.md',
  phase_id: 'phase-1',
  updates: {
    status: 'complete',
    check_all_tasks: true,
    notes: ['Completed in single session']
  }
});
```

**Status Indicators:**
| Status | Display |
|--------|---------|
| not_started | ⬜ Not Started |
| in_progress | 🔄 In Progress |
| complete | ✅ Complete |

---

## 4. Template System

### 4.1 Built-in Templates

| Template | Use Case | Key Sections |
|----------|----------|--------------|
| `basic` | Simple specs, quick documentation | Overview, Requirements, Notes |
| `feature` | New functionality | Overview, Requirements, Acceptance Criteria, Phases, Testing |
| `bug` | Bug fixes | Problem Statement, Root Cause, Solution, Verification |
| `infrastructure` | DevOps, CI/CD, systems | Overview, Components, Configuration, Rollout Plan |
| `api` | API endpoints | Endpoints, Request/Response, Authentication, Examples |

### 4.2 Template Detection

```typescript
function detectTemplate(context: {
  workType?: WorkType;
  title?: string;
  labels?: string[];
  content?: string;
}): TemplateType {
  // Priority order:
  // 1. Explicit work type mapping
  // 2. Label-based detection
  // 3. Content keyword analysis
  // 4. Default to 'basic'
}
```

**Work Type to Template Mapping:**
| Work Type | Template |
|-----------|----------|
| feature | feature |
| bug | bug |
| infrastructure | infrastructure |
| api | api |
| chore | basic |
| patch | basic |

### 4.3 Custom Templates

Custom templates can be placed in the configured directory:

```typescript
// Config
{
  "templates": {
    "default": "basic",
    "custom_template_dir": ".fractary/templates/spec"
  }
}

// Custom template: .fractary/templates/spec/security-review.md
// Referenced as: --template security-review
```

---

## 5. Storage Architecture

### 5.1 Two-Tier Storage Model

```
┌─────────────────────────────────────────────────────────────┐
│                     Local Storage                            │
│  /specs/                                                     │
│  ├── WORK-00123-feature.md        (active)                  │
│  ├── WORK-00124-01-auth.md        (active, multi-spec)     │
│  ├── WORK-00124-02-oauth.md       (active, multi-spec)     │
│  └── SPEC-20250115143000-idea.md  (standalone)             │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ archive()
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     Cloud Archive                            │
│  archive/specs/                                              │
│  ├── .archive-index.json          (master index)            │
│  ├── 2025/                                                   │
│  │   ├── WORK-00123-feature.md                              │
│  │   └── WORK-00124-auth.md                                 │
│  └── 2024/                                                   │
│      └── WORK-00050-legacy.md                               │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Archive Index Structure

```typescript
interface ArchiveIndex {
  version: string;
  updated_at: string;
  entries: ArchiveEntry[];
}

// Example
{
  "version": "1.0",
  "updated_at": "2025-01-15T14:30:00Z",
  "entries": [
    {
      "spec_id": "WORK-00123-feature",
      "work_id": "123",
      "title": "User Authentication",
      "archived_at": "2025-01-15T14:30:00Z",
      "cloud_url": "https://storage.example.com/specs/2025/WORK-00123-feature.md",
      "size_bytes": 15420,
      "work_type": "feature"
    }
  ]
}
```

### 5.3 Local Cache

```
.fractary/plugins/spec/
├── config.json           # Plugin configuration
├── archive-index.json    # Local cache of archive index
└── templates/            # Custom templates (optional)
```

---

## 6. CLI Implementation

### 6.1 Command Structure

```
fractary spec <command> [options]

Commands:
  init                Initialize spec plugin configuration
  create              Generate a new specification
  read <id>           Read specification (local or archive)
  validate <path>     Validate implementation against spec
  refine <work-id>    Refine specification through Q&A
  archive <work-id>   Archive completed specifications
  update <path>       Update phase status
  check-task <path>   Check off a task
  batch-update <path> Batch update a phase
  list                List local specifications
  list-archived       List archived specifications
```

### 6.2 Command Implementations

```typescript
// packages/ts/cli/src/commands/spec.ts

import { SpecManager } from '@fractary/spec';
import { Command } from 'commander';

export function registerSpecCommands(program: Command): void {
  const spec = program.command('spec').description('Specification management');

  spec
    .command('init')
    .description('Initialize spec plugin configuration')
    .option('--force', 'Overwrite existing configuration')
    .action(async (options) => {
      const result = await SpecManager.initialize(options.force);
      console.log(result.message);
    });

  spec
    .command('create')
    .description('Generate a new specification')
    .option('--work-id <id>', 'Link to work item')
    .option('--template <type>', 'Template type')
    .option('--context <text>', 'Additional context')
    .option('--force', 'Create even if exists')
    .action(async (options) => {
      const specManager = new SpecManager();
      const result = await specManager.generate(options);
      formatOutput(result);
    });

  spec
    .command('read <id>')
    .description('Read specification')
    .action(async (id) => {
      const specManager = new SpecManager();
      const result = await specManager.read(id);
      if (result.status === 'success' && result.spec) {
        console.log(result.spec.content);
      } else {
        console.error(result.message);
      }
    });

  spec
    .command('validate <path>')
    .description('Validate implementation against spec')
    .option('--work-id <id>', 'Work item ID')
    .option('--check-git', 'Check git changes')
    .action(async (path, options) => {
      const specManager = new SpecManager();
      const result = await specManager.validate({
        spec_path: path,
        work_id: options.workId,
        check_git_changes: options.checkGit
      });
      formatValidationOutput(result);
    });

  spec
    .command('refine <work-id>')
    .description('Refine specification through Q&A')
    .option('--prompt <text>', 'Focus area for refinement')
    .option('--round <n>', 'Refinement round', '1')
    .action(async (workId, options) => {
      const specManager = new SpecManager();
      const result = await specManager.refine({
        work_id: workId,
        prompt: options.prompt,
        round: parseInt(options.round)
      });
      formatOutput(result);
    });

  spec
    .command('archive <work-id>')
    .description('Archive completed specifications')
    .option('--force', 'Skip pre-archive checks')
    .option('--skip-warnings', 'Don\'t prompt for warnings')
    .action(async (workId, options) => {
      const specManager = new SpecManager();
      const result = await specManager.archive({
        work_id: workId,
        force: options.force,
        skip_warnings: options.skipWarnings
      });
      formatArchiveOutput(result);
    });

  // ... additional commands
}
```

---

## 7. Configuration Schema

### 7.1 Full Configuration

```json
{
  "schema_version": "1.0",
  "storage": {
    "local_path": "/specs",
    "cloud_archive_path": "archive/specs/{year}/{spec_id}.md",
    "archive_index": {
      "local_cache": ".fractary/plugins/spec/archive-index.json",
      "cloud_backup": "archive/specs/.archive-index.json"
    }
  },
  "naming": {
    "issue_specs": {
      "prefix": "WORK",
      "digits": 5,
      "phase_format": "numeric",
      "phase_separator": "-"
    },
    "standalone_specs": {
      "prefix": "SPEC",
      "digits": 4,
      "auto_increment": true,
      "start_from": null
    }
  },
  "archive": {
    "strategy": "lifecycle",
    "auto_archive_on": {
      "issue_close": true,
      "pr_merge": true,
      "faber_release": true
    },
    "pre_archive": {
      "check_docs_updated": "warn",
      "prompt_user": true,
      "require_validation": false
    },
    "post_archive": {
      "update_archive_index": true,
      "comment_on_issue": true,
      "comment_on_pr": true,
      "remove_from_local": true
    }
  },
  "integration": {
    "work_plugin": "fractary-work",
    "file_plugin": "fractary-file",
    "link_to_issue": true,
    "update_issue_on_create": true,
    "update_issue_on_archive": true,
    "github_link_format": "dual"
  },
  "templates": {
    "default": "basic",
    "custom_template_dir": null
  }
}
```

### 7.2 Configuration Location

```
.fractary/plugins/spec/config.json
```

### 7.3 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FRACTARY_SPEC_LOCAL_PATH` | Local specs directory | `/specs` |
| `FRACTARY_SPEC_ARCHIVE_PATH` | Cloud archive path pattern | `archive/specs/{year}/{spec_id}.md` |
| `FRACTARY_SPEC_DEFAULT_TEMPLATE` | Default template type | `basic` |

---

## 8. Plugin Migration

### 8.1 Migration Summary

| Plugin Component | SDK Replacement | Notes |
|-----------------|-----------------|-------|
| `spec-generator/` skill | `SpecManager.generate()` | Template logic moves to SDK |
| `spec-validator/` skill | `SpecManager.validate()` | Validation checks in SDK |
| `spec-archiver/` skill | `SpecManager.archive()` | Uses FileStorage for uploads |
| `spec-refiner/` skill | `SpecManager.refine()` | Uses LLMProvider for analysis |
| `spec-linker/` skill | `SpecManager.linkToWorkItem()` | Uses WorkProvider |
| `spec-updater/` skill | `SpecManager.updatePhaseStatus()` etc. | Direct file manipulation |
| `spec-initializer/` skill | `SpecManager.initialize()` | Config generation |
| `spec-manager` agent | Thin orchestration layer | Routes to CLI/SDK |
| `commands/*.md` | CLI commands | Replaced by `fractary spec` |
| `config/*.json` | SDK config | Same schema, loaded by SDK |
| `scripts/*.sh` | SDK implementation | Shell scripts replaced by TS/Py |

### 8.2 Deprecation Timeline

1. **Phase 1**: SDK implementation complete
2. **Phase 2**: CLI wrapper complete
3. **Phase 3**: Plugin updated to call CLI
4. **Phase 4**: Direct SDK calls for FABER integration
5. **Phase 5**: Plugin skills become thin wrappers

### 8.3 Backward Compatibility

- Plugin commands continue to work during transition
- Configuration schema remains compatible
- Archive index format unchanged
- Spec file format unchanged

---

## 9. Integration Points

### 9.1 FABER Integration

The Spec SDK integrates with FABER phases:

| FABER Phase | Spec Operation | Trigger |
|-------------|----------------|---------|
| Architect | `generate()` | Create spec from issue context |
| Architect | `refine()` | Improve spec through Q&A |
| Build | `updatePhaseStatus()` | Track implementation progress |
| Build | `checkTask()` | Mark tasks complete |
| Evaluate | `validate()` | Check implementation against spec |
| Release | `archive()` | Archive on PR merge |

### 9.2 Work Plugin Integration

```typescript
// Fetch issue context for spec generation
const issue = await workProvider.fetchIssue(workId);
const spec = await specManager.generate({
  work_id: workId,
  conversation_context: context
});

// Comment on issue with spec link
await workProvider.createComment(workId, {
  body: `📋 Specification created: [${spec.spec_path}](${localPath})`
});
```

### 9.3 File Plugin Integration

```typescript
// Archive to cloud storage
const archiveUrl = await fileStorage.upload({
  source: specPath,
  destination: `archive/specs/${year}/${specId}.md`,
  contentType: 'text/markdown'
});
```

### 9.4 Repo Plugin Integration

```typescript
// Auto-detect work ID from branch
const branch = await repoProvider.getCurrentBranch();
const workId = extractWorkId(branch); // feat/123-name → 123
```

---

## 10. Error Handling

### 10.1 Error Types

```typescript
import { FractaryError } from '@fractary/core';

export class SpecError extends FractaryError {
  constructor(message: string, code: string, details?: Record<string, unknown>) {
    super(message, code, details);
    this.name = 'SpecError';
  }
}

export class SpecNotFoundError extends SpecError {
  constructor(identifier: string) {
    super(
      `Specification not found: ${identifier}`,
      'SPEC_NOT_FOUND',
      { identifier }
    );
  }
}

export class SpecExistsError extends SpecError {
  constructor(workId: string, existingPaths: string[]) {
    super(
      `Specification already exists for work item #${workId}`,
      'SPEC_EXISTS',
      { workId, existingPaths }
    );
  }
}

export class ValidationError extends SpecError {
  constructor(specPath: string, failures: string[]) {
    super(
      `Specification validation failed: ${specPath}`,
      'VALIDATION_FAILED',
      { specPath, failures }
    );
  }
}

export class ArchiveError extends SpecError {
  constructor(workId: string, reason: string) {
    super(
      `Failed to archive specifications for #${workId}: ${reason}`,
      'ARCHIVE_FAILED',
      { workId, reason }
    );
  }
}

export class TemplateNotFoundError extends SpecError {
  constructor(templateName: string) {
    super(
      `Template not found: ${templateName}`,
      'TEMPLATE_NOT_FOUND',
      { templateName }
    );
  }
}
```

### 10.2 Error Recovery

| Error | Recovery Action |
|-------|----------------|
| Spec exists | Return existing spec info, suggest --force |
| Spec not found | Check archive, suggest create |
| Template not found | Fall back to basic template |
| Upload failed | Retry with exponential backoff, keep local |
| Index update failed | Keep local, warn user |
| GitHub comment failed | Log warning, continue (non-critical) |

---

## 11. Testing Strategy

### 11.1 Unit Tests

```typescript
describe('SpecManager', () => {
  describe('generate', () => {
    it('creates spec linked to work item');
    it('creates standalone spec without work_id');
    it('auto-detects work_id from branch');
    it('skips if spec exists and force=false');
    it('creates new spec if force=true');
    it('selects correct template based on work type');
    it('falls back to basic template');
  });

  describe('validate', () => {
    it('passes when all criteria met');
    it('warns when partially complete');
    it('fails when critical requirements missing');
    it('updates spec frontmatter with status');
  });

  describe('archive', () => {
    it('uploads all specs for work item');
    it('updates archive index');
    it('removes local files after upload');
    it('keeps local files if upload fails');
    it('comments on issue and PR');
  });
});
```

### 11.2 Integration Tests

```typescript
describe('Spec SDK Integration', () => {
  it('full lifecycle: create → validate → archive');
  it('refinement workflow with Q&A');
  it('read from archive after local cleanup');
  it('multi-spec handling for single work item');
});
```

---

## 12. References

- SPEC-00015: FABER Orchestrator Architecture
- SPEC-00016: SDK Architecture & Core Interfaces
- SPEC-00017: Work Tracking SDK
- SPEC-00019: File Storage SDK
- Plugin source: `plugins/spec/`
- Plugin config example: `plugins/spec/config/config.example.json`
