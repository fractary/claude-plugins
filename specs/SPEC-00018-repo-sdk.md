# SPEC-00018: Repository Operations SDK

| Field | Value |
|-------|-------|
| **Status** | Draft |
| **Created** | 2025-12-11 |
| **Author** | Claude (with human direction) |
| **Related** | SPEC-00016-sdk-architecture, plugins/repo/ |

## 1. Executive Summary

This specification details the **Repository Operations SDK** implementation within `@fractary/core`. It maps all 11 skills and 24 commands from the current `fractary-repo` plugin to SDK methods and CLI commands.

### 1.1 Scope

- Implementation of `RepoProvider` interface (defined in SPEC-00016)
- Git CLI operations wrapper
- Platform handlers: GitHub, GitLab, Bitbucket
- All operations: branches, commits, push/pull, PRs, tags, worktrees
- CLI command mappings
- Plugin migration path

### 1.2 Current Plugin Summary

| Metric | Value |
|--------|-------|
| Skills | 11 |
| Commands | 24 |
| Handlers | 3 (GitHub, GitLab, Bitbucket) |
| Operations | 20+ |

## 2. SDK Implementation

### 2.1 Module Structure

```
@fractary/core/
└── repo/
    ├── types.ts              # RepoProvider interface, data types
    ├── index.ts              # Public exports
    ├── registry.ts           # Provider registry
    ├── git.ts                # Git CLI wrapper
    ├── branch-namer.ts       # Semantic branch naming
    ├── worktree.ts           # Worktree management
    ├── github.ts             # GitHub implementation
    ├── gitlab.ts             # GitLab implementation
    └── bitbucket.ts          # Bitbucket implementation
```

### 2.2 Architecture: Git + Platform APIs

The repo module combines two layers:

1. **Git CLI Layer** (`git.ts`) - Local operations
   - Branch operations
   - Commit operations
   - Push/Pull
   - Worktree management

2. **Platform API Layer** (`github.ts`, etc.) - Remote operations
   - Pull requests
   - Protected branch checks
   - CI status
   - Review management

```typescript
// Combined provider
export class GitHubRepoProvider implements RepoProvider {
  private git: GitClient;
  private api: Octokit;

  // Branch operations use Git CLI
  async createBranch(name: string, options?: CreateBranchOptions): Promise<Branch> {
    await this.git.checkout(['-b', name, options?.baseBranch || 'main']);
    // ...
  }

  // PR operations use GitHub API
  async createPullRequest(input: CreatePRInput): Promise<PullRequest> {
    const response = await this.api.pulls.create({ /* ... */ });
    // ...
  }
}
```

### 2.3 Provider Registry

```typescript
// repo/registry.ts

import { RepoProvider } from './types';
import { GitHubRepoProvider } from './github';
import { GitLabRepoProvider } from './gitlab';
import { BitbucketRepoProvider } from './bitbucket';

export type RepoProviderType = 'github' | 'gitlab' | 'bitbucket';

export interface RepoProviderConfig {
  provider: RepoProviderType;
  workingDirectory?: string;
  defaultBranch?: string;
  protectedBranches?: string[];
  // Provider-specific config
  github?: {
    token: string;
    owner: string;
    repo: string;
  };
  gitlab?: {
    token: string;
    projectId: string;
    baseUrl?: string;
  };
  bitbucket?: {
    username: string;
    appPassword: string;
    workspace: string;
    repoSlug: string;
  };
}

export function createRepoProvider(config: RepoProviderConfig): RepoProvider {
  switch (config.provider) {
    case 'github':
      if (!config.github) throw new ConfigurationError('GitHub config required');
      return new GitHubRepoProvider(config);
    case 'gitlab':
      if (!config.gitlab) throw new ConfigurationError('GitLab config required');
      return new GitLabRepoProvider(config);
    case 'bitbucket':
      if (!config.bitbucket) throw new ConfigurationError('Bitbucket config required');
      return new BitbucketRepoProvider(config);
    default:
      throw new ConfigurationError(`Unknown provider: ${config.provider}`);
  }
}
```

## 3. Operation Mappings

### 3.1 Branch Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `branch-manager` (create) | `createBranch(name, options?)` | `fractary repo branch create` |
| `branch-manager` (delete) | `deleteBranch(name, options?)` | `fractary repo branch delete <name>` |
| `branch-manager` (list) | `listBranches(filters?)` | `fractary repo branch list` |
| `branch-namer` | `generateBranchName(description, options?)` | (internal) |
| `branch-puller` | `pull(options?)` | `fractary repo pull` |
| `branch-pusher` | `push(options?)` | `fractary repo push` |

#### 3.1.1 createBranch

**Current Plugin**: `branch-manager` skill (create operation)

**SDK Method**:
```typescript
async createBranch(name: string, options?: CreateBranchOptions): Promise<Branch>
```

**CLI**:
```bash
fractary repo branch create [options]

Options:
  --name <name>          Direct branch name (e.g., "feature/my-branch")
  --description <desc>   Description to generate branch name from
  --base <branch>        Base branch (default: main)
  --prefix <prefix>      Branch prefix: feat, fix, hotfix, chore, docs, test (default: feat)
  --work-id <id>         Work item ID to link
  --worktree             Create git worktree for parallel development
  --checkout             Checkout after creation (default: true)
  --json                 Output as JSON
```

**Implementation Notes**:
- Two modes: direct name vs description-based generation
- Validates branch doesn't exist
- Validates base branch exists
- Protected branch safety checks
- Optional worktree creation
- Updates status cache after creation

**Branch Naming Convention**:
```
{prefix}/{work-id}-{slug}     # With work ID: feat/123-add-csv-export
{prefix}/{slug}               # Without work ID: feat/add-csv-export
```

**Platform Implementation (Git + GitHub)**:
```typescript
// github.ts
async createBranch(name: string, options: CreateBranchOptions = {}): Promise<Branch> {
  const baseBranch = options.baseBranch || this.config.defaultBranch || 'main';

  // Validate base branch exists
  await this.git.revParse(['--verify', baseBranch]);

  // Check if branch already exists
  const exists = await this.branchExists(name);
  if (exists && !options.force) {
    throw new ValidationError('Branch already exists', ['name'], name);
  }

  // Create branch
  await this.git.checkout(['-b', name, baseBranch]);

  // Create worktree if requested
  if (options.worktree) {
    await this.createWorktree(name, { baseBranch, workId: options.workId });
  }

  // Get branch info
  const sha = await this.git.revParse(['HEAD']);

  return {
    name,
    sha,
    isDefault: false,
    isProtected: await this.isProtectedBranch(name),
    lastCommitDate: new Date(),
  };
}
```

#### 3.1.2 deleteBranch

**Current Plugin**: `branch-manager` skill (delete operation)

**SDK Method**:
```typescript
async deleteBranch(name: string, options?: DeleteBranchOptions): Promise<void>
```

**CLI**:
```bash
fractary repo branch delete <name> [options]

Options:
  --location <where>     Where to delete: local, remote, both (default: local)
  --force                Force delete unmerged branch
  --worktree-cleanup     Remove associated worktree if exists
```

**Implementation Notes**:
- Protected branch safety check
- Validates branch is merged (unless --force)
- Cleans up associated worktree if requested
- Can delete local only, remote only, or both

#### 3.1.3 listBranches

**Current Plugin**: `branch-manager` skill (list operation)

**SDK Method**:
```typescript
async listBranches(filters?: BranchFilters): Promise<PaginatedResult<Branch>>
```

**CLI**:
```bash
fractary repo branch list [options]

Options:
  --merged               Show only merged branches
  --stale                Show only stale branches (inactive > N days)
  --days <n>             Days threshold for stale (default: 30)
  --pattern <pattern>    Filter by name pattern (glob)
  --json                 Output as JSON
```

#### 3.1.4 generateBranchName

**Current Plugin**: `branch-namer` skill

**SDK Method**:
```typescript
generateBranchName(description: string, options?: BranchNameOptions): string
```

**Implementation**:
```typescript
// branch-namer.ts

export function generateBranchName(
  description: string,
  options: BranchNameOptions = {}
): string {
  const prefix = options.prefix || 'feat';
  const workId = options.workId;

  // Slugify description
  const slug = description
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')      // Remove special chars
    .replace(/\s+/g, '-')               // Spaces to hyphens
    .replace(/-+/g, '-')                // Collapse multiple hyphens
    .replace(/^-|-$/g, '')              // Trim hyphens
    .substring(0, 50);                  // Max length

  if (workId) {
    return `${prefix}/${workId}-${slug}`;
  }
  return `${prefix}/${slug}`;
}
```

#### 3.1.5 pull

**Current Plugin**: `branch-puller` skill

**SDK Method**:
```typescript
async pull(options?: PullOptions): Promise<void>
```

**CLI**:
```bash
fractary repo pull [branch] [options]

Arguments:
  [branch]               Branch to pull (default: current)

Options:
  --remote <name>        Remote name (default: origin)
  --rebase               Use rebase instead of merge
  --strategy <strategy>  Strategy: merge, rebase, ff-only (default: merge)
  --allow-switch         Allow switching branches if needed
```

**Implementation Notes**:
- Intelligent conflict resolution
- Stash uncommitted changes if needed
- Support for rebase workflow

#### 3.1.6 push

**Current Plugin**: `branch-pusher` skill

**SDK Method**:
```typescript
async push(options?: PushOptions): Promise<void>
```

**CLI**:
```bash
fractary repo push [branch] [options]

Arguments:
  [branch]               Branch to push (default: current)

Options:
  --remote <name>        Remote name (default: origin)
  --set-upstream         Set upstream tracking (-u)
  --force                Force push (DANGEROUS)
  --force-with-lease     Safer force push
```

**Implementation Notes**:
- Protected branch safety check
- Force-with-lease preferred over force
- Warns before force push to main/master

### 3.2 Commit Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `commit-creator` | `commit(input)` | `fractary repo commit` |

#### 3.2.1 commit

**Current Plugin**: `commit-creator` skill

**SDK Method**:
```typescript
async commit(input: CreateCommitInput): Promise<Commit>
```

**CLI**:
```bash
fractary repo commit [options]

Options:
  --message <msg>        Commit message (required, or use first positional arg)
  --type <type>          Type: feat, fix, chore, docs, test, refactor, style, perf
  --scope <scope>        Scope in parentheses
  --work-id <id>         Work item ID for metadata
  --author-context <ctx> FABER context: frame, architect, build, evaluate, release
  --breaking             Mark as breaking change
  --description <text>   Extended description
  --allow-empty          Allow empty commit
  --json                 Output as JSON
```

**Commit Message Format** (Conventional Commits + FABER):
```
type(scope): summary

Extended description

Work-Item: #123
Author-Context: build

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Implementation**:
```typescript
// commit-creator logic
async commit(input: CreateCommitInput): Promise<Commit> {
  // Build conventional commit message
  let message = input.type ? `${input.type}` : '';
  if (input.scope) message += `(${input.scope})`;
  if (input.breaking) message += '!';
  message += `: ${input.message}`;

  if (input.description) {
    message += `\n\n${input.description}`;
  }

  // Add FABER metadata
  const metadata: string[] = [];
  if (input.workId) {
    metadata.push(`Work-Item: #${input.workId}`);
  }
  if (input.authorContext) {
    metadata.push(`Author-Context: ${input.authorContext}`);
  }
  if (metadata.length > 0) {
    message += `\n\n${metadata.join('\n')}`;
  }

  // Execute git commit
  const args = ['-m', message];
  if (input.allowEmpty) args.push('--allow-empty');

  await this.git.commit(args);

  const sha = await this.git.revParse(['HEAD']);
  return {
    sha,
    message: input.message,
    author: await this.git.config(['user.name']),
    authorEmail: await this.git.config(['user.email']),
    date: new Date(),
    parents: [], // Could fetch if needed
  };
}
```

### 3.3 Pull Request Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `pr-manager` (create) | `createPullRequest(input)` | `fractary repo pr create` |
| `pr-manager` (get) | `getPullRequest(number)` | `fractary repo pr get <number>` |
| `pr-manager` (list) | `listPullRequests(filters?)` | `fractary repo pr list` |
| `pr-manager` (comment) | `commentOnPullRequest(number, comment)` | `fractary repo pr comment <number>` |
| `pr-manager` (review) | `reviewPullRequest(number, review)` | `fractary repo pr review <number>` |
| `pr-manager` (merge) | `mergePullRequest(number, options?)` | `fractary repo pr merge <number>` |
| `pr-manager` (analyze) | `analyzePullRequest(number)` | `fractary repo pr review <number>` (default action) |

#### 3.3.1 createPullRequest

**Current Plugin**: `pr-manager` skill (create operation)

**SDK Method**:
```typescript
async createPullRequest(input: CreatePRInput): Promise<PullRequest>
```

**CLI**:
```bash
fractary repo pr create [options]

Options:
  --title <title>        PR title (required)
  --body <body>          PR description
  --prompt <prompt>      Instructions for generating body
  --head <branch>        Head branch (default: current)
  --base <branch>        Base branch (default: main)
  --work-id <id>         Work item ID (adds "Closes #ID")
  --draft                Create as draft PR
  --labels <labels>      Comma-separated labels
  --reviewers <users>    Comma-separated reviewers
  --json                 Output as JSON
```

**Implementation Notes**:
- Extracts work ID from branch name if not provided (e.g., `feat/123-name` → #123)
- Adds "Closes #{work_id}" to body
- Protected branch safety for base branch
- Returns PR URL for easy access

**PR Body Format**:
```markdown
## Summary
<generated or user-provided summary>

## Test Plan
<testing checklist>

Closes #123

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

#### 3.3.2 mergePullRequest

**Current Plugin**: `pr-manager` skill (merge operation)

**SDK Method**:
```typescript
async mergePullRequest(number: number, options?: MergeOptions): Promise<void>
```

**CLI**:
```bash
fractary repo pr merge <number> [options]

Options:
  --strategy <strategy>  Merge strategy: merge, squash, rebase (default: squash)
  --delete-branch        Delete branch after merge
  --worktree-cleanup     Remove associated worktree if exists
  --commit-message <msg> Custom merge commit message
```

**Implementation Notes**:
- Protected branch safety: requires `FABER_RELEASE_APPROVED=true` for protected branches
- Waits for CI checks if configured
- Cleans up worktree after merge if requested
- Warns before merge to protected branches

#### 3.3.3 reviewPullRequest

**Current Plugin**: `pr-manager` skill (review operation)

**SDK Method**:
```typescript
async reviewPullRequest(number: number, review: PRReview): Promise<void>
```

**CLI**:
```bash
fractary repo pr review <number> [options]

Options:
  --action <action>      Action: analyze, approve, request_changes, comment (default: analyze)
  --comment <text>       Review comment
  --wait-for-ci          Wait for CI to complete before review
  --ci-timeout <seconds> CI wait timeout (default: 300)
```

**Actions**:
- `analyze` - Generate PR analysis (default)
- `approve` - Approve the PR
- `request_changes` - Request changes with comment
- `comment` - Add review comment without approval/rejection

### 3.4 Tag Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `tag-manager` (create) | `createTag(input)` | `fractary repo tag create` |
| `tag-manager` (push) | `pushTag(tagName, options?)` | `fractary repo tag push <name>` |
| `tag-manager` (list) | `listTags(filters?)` | `fractary repo tag list` |

#### 3.4.1 createTag

**Current Plugin**: `tag-manager` skill (create operation)

**SDK Method**:
```typescript
async createTag(input: CreateTagInput): Promise<Tag>
```

**CLI**:
```bash
fractary repo tag create <name> [options]

Arguments:
  <name>                 Tag name (semantic versioning recommended: v1.2.3)

Options:
  --message <msg>        Tag message (creates annotated tag)
  --commit <sha>         Commit SHA to tag (default: HEAD)
  --sign                 GPG sign the tag
  --force                Replace existing tag
  --json                 Output as JSON
```

**Implementation Notes**:
- Validates semantic versioning format
- Supports lightweight and annotated tags
- GPG signing when configured

#### 3.4.2 pushTag

**SDK Method**:
```typescript
async pushTag(tagName: string, options?: PushTagOptions): Promise<void>
```

**CLI**:
```bash
fractary repo tag push <name> [options]

Arguments:
  <name>                 Tag name, or "all" to push all tags

Options:
  --remote <name>        Remote name (default: origin)
```

### 3.5 Worktree Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `worktree-manager` (create) | `createWorktree(branch, options?)` | (via branch create --worktree) |
| `worktree-manager` (list) | `listWorktrees()` | `fractary repo worktree list` |
| `worktree-manager` (remove) | `removeWorktree(branch, options?)` | `fractary repo worktree remove <branch>` |
| `worktree-manager` (cleanup) | `cleanupWorktrees(options?)` | `fractary repo worktree cleanup` |

#### 3.5.1 createWorktree

**Current Plugin**: `worktree-manager` skill (create operation)

**SDK Method**:
```typescript
async createWorktree(branch: string, options?: WorktreeOptions): Promise<Worktree>
```

**Implementation**:
```typescript
// worktree.ts

async createWorktree(branch: string, options: WorktreeOptions = {}): Promise<Worktree> {
  const repoName = await this.getRepoName();
  const worktreePath = `../${repoName}-wt-${this.slugify(branch)}`;

  // Create worktree
  await this.git.worktree(['add', worktreePath, branch]);

  // Store metadata
  const worktree: Worktree = {
    path: worktreePath,
    branch,
    workId: options.workId,
    createdAt: new Date(),
    isLocked: false,
    hasChanges: false,
  };

  await this.saveWorktreeMetadata(worktree);

  return worktree;
}
```

**Worktree Naming Convention**:
```
{repo-name}-wt-{branch-slug}
Example: claude-plugins-wt-feat-123-add-csv-export
Location: Sibling to main repository
```

#### 3.5.2 listWorktrees

**SDK Method**:
```typescript
async listWorktrees(): Promise<Worktree[]>
```

**CLI**:
```bash
fractary repo worktree list [options]

Options:
  --json                 Output as JSON
```

**Output**:
```
Active Worktrees:
1. feat/123-add-csv-export
   Path: ../claude-plugins-wt-feat-123-add-csv-export
   Work Item: #123
   Created: 2025-11-12
   Status: Active

2. fix/456-auth-bug
   Path: ../claude-plugins-wt-fix-456-auth-bug
   Work Item: #456
   Created: 2025-11-10
   Status: Has uncommitted changes
```

#### 3.5.3 removeWorktree

**SDK Method**:
```typescript
async removeWorktree(branch: string, options?: RemoveWorktreeOptions): Promise<void>
```

**CLI**:
```bash
fractary repo worktree remove <branch> [options]

Options:
  --force                Force removal with uncommitted changes
```

**Implementation Notes**:
- Warns if uncommitted changes exist
- Requires --force to override
- Prevents removal from within worktree directory
- Cleans up metadata registry

#### 3.5.4 cleanupWorktrees

**SDK Method**:
```typescript
async cleanupWorktrees(options?: CleanupWorktreeOptions): Promise<WorktreeCleanupResult>
```

**CLI**:
```bash
fractary repo worktree cleanup [options]

Options:
  --merged               Clean up merged worktrees
  --stale                Clean up stale worktrees (inactive > N days)
  --days <n>             Days threshold for stale (default: 30)
  --dry-run              Show what would be removed
```

### 3.6 Cleanup Operations

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `cleanup-manager` | (combines branch + worktree cleanup) | `fractary repo cleanup` |

#### 3.6.1 cleanup (Combined)

**CLI**:
```bash
fractary repo cleanup [options]

Options:
  --delete               Actually delete (default: dry-run)
  --merged               Clean merged branches
  --inactive             Clean inactive branches
  --days <n>             Days for inactive threshold (default: 30)
  --location <where>     Where: local, remote, both
  --exclude <pattern>    Exclude pattern (can be repeated)
```

### 3.7 Status and Utility

| Plugin Skill | SDK Method | CLI Command |
|--------------|------------|-------------|
| `repo-common` | `getStatus()` | `fractary repo status` |
| `repo-common` | `isProtectedBranch(branch)` | (internal) |
| `repo-common` | `getCurrentBranch()` | (internal, also in status) |

#### 3.7.1 getStatus

**SDK Method**:
```typescript
async getStatus(): Promise<RepoStatus>
```

**CLI**:
```bash
fractary repo status [options]

Options:
  --json                 Output as JSON
```

**Output**:
```
Branch: feat/123-add-csv-export
Status: 2 ahead, 1 behind origin/main

Staged:
  M src/feature.ts

Modified:
  M README.md

Untracked:
  ? temp.log
```

## 4. Platform Implementations

### 4.1 Git CLI Wrapper

**File**: `@fractary/core/repo/git.ts`

**Dependencies**:
- `simple-git` - Git CLI wrapper

```typescript
// git.ts

import simpleGit, { SimpleGit } from 'simple-git';

export class GitClient {
  private git: SimpleGit;

  constructor(workingDirectory?: string) {
    this.git = simpleGit(workingDirectory || process.cwd());
  }

  async checkout(args: string[]): Promise<void> {
    await this.git.checkout(args);
  }

  async commit(args: string[]): Promise<void> {
    await this.git.commit(args);
  }

  async push(args: string[]): Promise<void> {
    await this.git.push(args);
  }

  async pull(args: string[]): Promise<void> {
    await this.git.pull(args);
  }

  async revParse(args: string[]): Promise<string> {
    return (await this.git.revparse(args)).trim();
  }

  async config(args: string[]): Promise<string> {
    return (await this.git.raw(['config', ...args])).trim();
  }

  async worktree(args: string[]): Promise<void> {
    await this.git.raw(['worktree', ...args]);
  }

  async status(): Promise<StatusResult> {
    return this.git.status();
  }

  async diff(args: string[]): Promise<string> {
    return this.git.diff(args);
  }

  async log(args: string[]): Promise<LogResult> {
    return this.git.log(args);
  }

  async tag(args: string[]): Promise<void> {
    await this.git.tag(args);
  }

  async branch(args: string[]): Promise<BranchSummary> {
    return this.git.branch(args);
  }
}
```

### 4.2 GitHub Implementation

**File**: `@fractary/core/repo/github.ts`

**Dependencies**:
- `@octokit/rest` - GitHub API client
- `simple-git` - Git CLI (via GitClient)

```typescript
// github.ts

import { Octokit } from '@octokit/rest';
import { GitClient } from './git';
import { RepoProvider, PullRequest, CreatePRInput } from './types';

export class GitHubRepoProvider implements RepoProvider {
  readonly name = 'github';
  private git: GitClient;
  private api: Octokit;
  private config: GitHubRepoConfig;

  constructor(config: GitHubRepoConfig) {
    this.config = config;
    this.git = new GitClient(config.workingDirectory);
    this.api = new Octokit({ auth: config.token });
  }

  // PR operations use API
  async createPullRequest(input: CreatePRInput): Promise<PullRequest> {
    const headBranch = input.headBranch || await this.getCurrentBranch();
    const baseBranch = input.baseBranch || this.config.defaultBranch || 'main';

    // Extract work ID from branch if not provided
    const workId = input.workId || this.extractWorkIdFromBranch(headBranch);

    // Build body with work item reference
    let body = input.body || '';
    if (workId) {
      body += `\n\nCloses #${workId}`;
    }
    body += '\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)';

    const response = await this.api.pulls.create({
      owner: this.config.owner,
      repo: this.config.repo,
      title: input.title,
      body,
      head: headBranch,
      base: baseBranch,
      draft: input.draft,
    });

    // Add labels if specified
    if (input.labels?.length) {
      await this.api.issues.addLabels({
        owner: this.config.owner,
        repo: this.config.repo,
        issue_number: response.data.number,
        labels: input.labels,
      });
    }

    // Request reviewers if specified
    if (input.reviewers?.length) {
      await this.api.pulls.requestReviewers({
        owner: this.config.owner,
        repo: this.config.repo,
        pull_number: response.data.number,
        reviewers: input.reviewers,
      });
    }

    return this.mapPullRequest(response.data);
  }

  private extractWorkIdFromBranch(branch: string): string | undefined {
    // Pattern: prefix/123-description or prefix/123
    const match = branch.match(/^[^/]+\/(\d+)(?:-|$)/);
    return match?.[1];
  }

  // Branch operations use Git CLI
  async getCurrentBranch(): Promise<string> {
    return this.git.revParse(['--abbrev-ref', 'HEAD']);
  }

  async createBranch(name: string, options?: CreateBranchOptions): Promise<Branch> {
    // Implementation as shown in 3.1.1
  }

  // Protected branch check uses API
  async isProtectedBranch(branch: string): Promise<boolean> {
    try {
      await this.api.repos.getBranchProtection({
        owner: this.config.owner,
        repo: this.config.repo,
        branch,
      });
      return true;
    } catch (error: any) {
      if (error.status === 404) return false;
      throw error;
    }
  }
}
```

### 4.3 GitLab Implementation

**File**: `@fractary/core/repo/gitlab.ts`

**Dependencies**:
- `@gitbeaker/rest` - GitLab API client

### 4.4 Bitbucket Implementation

**File**: `@fractary/core/repo/bitbucket.ts`

**Dependencies**:
- `bitbucket` - Bitbucket API client

## 5. CLI Implementation

### 5.1 Command Structure

```
@fractary/cli/
└── src/tools/repo/
    ├── index.ts              # Repo command group
    └── commands/
        ├── branch/
        │   ├── create.ts
        │   ├── delete.ts
        │   └── list.ts
        ├── commit.ts
        ├── push.ts
        ├── pull.ts
        ├── pr/
        │   ├── create.ts
        │   ├── get.ts
        │   ├── list.ts
        │   ├── comment.ts
        │   ├── review.ts
        │   └── merge.ts
        ├── tag/
        │   ├── create.ts
        │   ├── push.ts
        │   └── list.ts
        ├── worktree/
        │   ├── list.ts
        │   ├── remove.ts
        │   └── cleanup.ts
        ├── cleanup.ts
        ├── status.ts
        └── init.ts
```

### 5.2 Combined Commands

For convenience, the CLI also supports combined operations:

```bash
# Commit and push in one command
fractary repo commit-and-push --message "Add feature" --type feat

# Equivalent to:
# fractary repo commit --message "Add feature" --type feat
# fractary repo push --set-upstream
```

## 6. Plugin Migration

### 6.1 Current Plugin Structure

```
plugins/repo/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   └── repo-manager.md
├── commands/
│   ├── branch-create.md
│   ├── commit.md
│   └── ... (24 commands)
├── skills/
│   ├── branch-manager/
│   ├── commit-creator/
│   ├── pr-manager/
│   ├── handler-source-control-github/
│   └── ... (11 skills)
├── scripts/
│   └── status-cache.sh
└── hooks/
    └── hooks.json
```

### 6.2 Post-Migration Structure

```
plugins/repo/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   └── repo-manager.md           # Thin router to CLI
├── commands/
│   └── ... (invoke CLI)
└── hooks/
    └── hooks.json                # Still needed for Claude Code hooks
```

### 6.3 What Gets Removed

- All skill implementations (move to SDK)
- All shell scripts (replaced by TypeScript)
- Handler skills (consolidated into SDK provider classes)

### 6.4 What Stays

- Commands (Claude UX)
- Agent (thin router)
- Hooks (Claude Code integration)

## 7. Configuration

### 7.1 Configuration Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "schema_version": { "type": "string", "const": "1.0" },
    "provider": { "type": "string", "enum": ["github", "gitlab", "bitbucket"] },
    "default_branch": { "type": "string", "default": "main" },
    "protected_branches": {
      "type": "array",
      "items": { "type": "string" },
      "default": ["main", "master", "production"]
    },
    "branch_prefix": { "type": "string", "default": "feat" },
    "github": {
      "type": "object",
      "properties": {
        "token_env": { "type": "string", "default": "GITHUB_TOKEN" },
        "owner": { "type": "string" },
        "repo": { "type": "string" }
      }
    },
    "worktrees": {
      "type": "object",
      "properties": {
        "enabled": { "type": "boolean", "default": true },
        "base_path": { "type": "string", "default": ".." },
        "naming_pattern": { "type": "string", "default": "{repo}-wt-{branch-slug}" }
      }
    },
    "commit": {
      "type": "object",
      "properties": {
        "sign": { "type": "boolean", "default": false },
        "add_co_author": { "type": "boolean", "default": true }
      }
    }
  },
  "required": ["schema_version", "provider"]
}
```

### 7.2 Example Configuration

```json
{
  "schema_version": "1.0",
  "provider": "github",
  "default_branch": "main",
  "protected_branches": ["main", "production"],
  "branch_prefix": "feat",
  "github": {
    "token_env": "GITHUB_TOKEN",
    "owner": "fractary",
    "repo": "claude-plugins"
  },
  "worktrees": {
    "enabled": true,
    "base_path": "..",
    "naming_pattern": "{repo}-wt-{branch-slug}"
  },
  "commit": {
    "sign": false,
    "add_co_author": true
  }
}
```

## 8. Safety Features

### 8.1 Protected Branch Safety

```typescript
// Safety checks before operations on protected branches

async assertNotProtected(branch: string, operation: string): Promise<void> {
  if (await this.isProtectedBranch(branch)) {
    // Check for explicit approval
    if (process.env.FABER_RELEASE_APPROVED !== 'true') {
      throw new ValidationError(
        `Operation '${operation}' on protected branch '${branch}' requires FABER_RELEASE_APPROVED=true`,
        ['branch'],
        branch
      );
    }
  }
}
```

### 8.2 Force Push Warning

```typescript
async push(options: PushOptions): Promise<void> {
  if (options.force && !options.forceWithLease) {
    const branch = options.branch || await this.getCurrentBranch();
    if (['main', 'master', 'production'].includes(branch)) {
      throw new ValidationError(
        `Force push to ${branch} is extremely dangerous. Use --force-with-lease instead.`,
        ['branch'],
        branch
      );
    }
  }
}
```

### 8.3 Uncommitted Changes Warning

Operations that could lose data warn about uncommitted changes:

```typescript
async removeWorktree(branch: string, options?: RemoveWorktreeOptions): Promise<void> {
  const worktree = await this.getWorktreeByBranch(branch);
  if (worktree.hasChanges && !options?.force) {
    throw new ValidationError(
      `Worktree has uncommitted changes. Use --force to remove anyway.`,
      ['branch'],
      branch
    );
  }
}
```

## 9. References

- [SPEC-00016: SDK Architecture](./SPEC-00016-sdk-architecture.md) - Core interfaces
- [GitHub REST API](https://docs.github.com/en/rest)
- [GitLab REST API](https://docs.gitlab.com/ee/api/)
- [Bitbucket REST API](https://developer.atlassian.com/cloud/bitbucket/rest/)
- [simple-git Documentation](https://github.com/steveukx/git-js)
- [Conventional Commits](https://www.conventionalcommits.org/)
