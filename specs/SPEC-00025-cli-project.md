# SPEC-00025: CLI Project

| Field | Value |
|-------|-------|
| **Status** | Draft |
| **Created** | 2025-12-11 |
| **Author** | Claude (with human direction) |
| **Related** | SPEC-00023-faber-sdk, SPEC-00024-codex-sdk, SPEC-00016-sdk-architecture |
| **Project** | `/mnt/c/GitHub/fractary/cli` (existing project) |

## 1. Executive Summary

This specification defines enhancements to the **existing `@fractary/cli` project** to support the two-SDK architecture (`@fractary/faber` + `@fractary/codex`). The CLI serves as the unified command-line interface that exposes SDK functionality to users and provides the bridge for Claude Code plugins.

### 1.1 Scope

This document covers:
- Hybrid command structure (top-level aliases + SDK namespaces)
- SDK integration layer (consuming faber and codex SDKs)
- Plugin bridge (how claude-plugins invoke CLI)
- Output formatting system
- Configuration management
- Error handling and exit codes
- Migration path from current CLI state

### 1.2 Design Goals

1. **Hybrid Command Structure** - Top-level shortcuts for common operations, explicit SDK paths for clarity
2. **SDK Consumer** - CLI consumes SDKs, it is not an SDK itself
3. **Plugin Bridge** - Seamless integration with Claude Code plugins
4. **Graceful Degradation** - Functions with partial SDK availability
5. **Consistent UX** - Uniform patterns across all commands
6. **Space-Separated Syntax** - Following SPEC-00014 argument standards

### 1.3 Non-Goals

- Creating another SDK (CLI is a consumer, not a producer)
- Replacing the plugin system (plugins remain thin CLI wrappers)
- Building a GUI or TUI (pure CLI focus)

## 2. Current State Analysis

### 2.1 Existing CLI Project

The CLI project exists at `/mnt/c/GitHub/fractary/cli` with:

```
@fractary/cli v0.2.0
├── Dependencies
│   ├── @fractary/faber ^0.1.0 (agent orchestration - roles/teams/workflows)
│   ├── @fractary/codex ^0.1.0 (doc metadata/validation/routing)
│   ├── @fractary/forge ^1.0.0 (asset management/scaffolding)
│   └── commander ^11.1.0 (argument parsing)
│
├── Current Commands
│   ├── fractary faber init|create|list|validate|build
│   ├── fractary codex init|validate|parse|config|route|list|check
│   └── fractary forge create|install|update|deploy|diff|validate|...
│
└── Structure
    └── src/tools/{faber,codex,forge}/commands/*.ts
```

### 2.2 Gap Analysis

| Current State | Target State |
|--------------|--------------|
| `@fractary/faber` = agent orchestration | `@fractary/faber` = development toolkit (work, repo, spec, logs, state, workflow) |
| `@fractary/codex` = doc metadata only | `@fractary/codex` = full knowledge infrastructure (refs, types, storage, cache, sync, MCP) |
| No work/repo/spec/logs commands | Full primitive command support |
| No plugin bridge | Structured plugin integration layer |

## 3. Hybrid Command Architecture

### 3.1 Command Structure Overview

```
fractary
├── faber                    # FABER SDK orchestration commands
│   ├── init                 # Initialize FABER project
│   ├── run                  # Run FABER workflow
│   ├── status               # Show workflow status
│   ├── plan                 # Create/view execution plan
│   ├── work                 # Work tracking (also top-level alias)
│   │   ├── issue            # Issue operations
│   │   ├── comment          # Comment operations
│   │   ├── label            # Label operations
│   │   └── milestone        # Milestone operations
│   ├── repo                 # Repository operations (also top-level alias)
│   │   ├── branch           # Branch operations
│   │   ├── commit           # Commit operations
│   │   ├── pr               # Pull request operations
│   │   ├── tag              # Tag operations
│   │   └── worktree         # Worktree operations
│   ├── spec                 # Specification management (also top-level alias)
│   │   ├── create           # Create specification
│   │   ├── refine           # Refine with Q&A
│   │   ├── validate         # Validate implementation
│   │   └── archive          # Archive to cloud
│   └── logs                 # Log management (also top-level alias)
│       ├── capture          # Start session capture
│       ├── write            # Write typed log
│       ├── search           # Search logs
│       └── archive          # Archive logs
│
├── codex                    # Codex SDK operations
│   ├── init                 # Initialize Codex configuration
│   ├── fetch                # Fetch document by reference
│   ├── sync                 # Sync project/org with Codex
│   │   ├── project          # Sync single project
│   │   └── org              # Sync entire organization
│   ├── cache                # Cache management
│   │   ├── list             # List cached items
│   │   ├── clear            # Clear cache
│   │   └── metrics          # Cache statistics
│   ├── validate             # Validate references
│   └── mcp                  # MCP server management
│       ├── start            # Start MCP server
│       └── status           # MCP server status
│
├── work                     # [ALIAS] → faber work
├── repo                     # [ALIAS] → faber repo
├── spec                     # [ALIAS] → faber spec
├── logs                     # [ALIAS] → faber logs
│
├── forge                    # Forge commands (existing)
│   └── ...
│
└── helm                     # Helm commands (future)
    └── ...
```

### 3.2 Alias Implementation

Top-level aliases provide shortcuts to SDK-namespaced commands:

```typescript
// src/cli.ts

import { Command } from 'commander';

const program = new Command();

// Full SDK command trees
program.addCommand(createFaberCommand());
program.addCommand(createCodexCommand());
program.addCommand(createForgeCommand());

// Top-level aliases (delegate to faber subcommands)
program.addCommand(
  createAliasCommand('work', 'faber work', 'Work item tracking (alias for faber work)')
);
program.addCommand(
  createAliasCommand('repo', 'faber repo', 'Repository operations (alias for faber repo)')
);
program.addCommand(
  createAliasCommand('spec', 'faber spec', 'Specification management (alias for faber spec)')
);
program.addCommand(
  createAliasCommand('logs', 'faber logs', 'Log management (alias for faber logs)')
);
```

```typescript
// src/utils/alias.ts

export function createAliasCommand(
  name: string,
  target: string,
  description: string
): Command {
  const cmd = new Command(name)
    .description(`${description}`)
    .allowUnknownOption()
    .allowExcessArguments()
    .action(async (options, command) => {
      // Rewrite argv to target command and re-parse
      const args = process.argv.slice(2);
      const aliasIndex = args.indexOf(name);
      args.splice(aliasIndex, 1, ...target.split(' '));

      // Re-invoke with modified args
      process.argv = [process.argv[0], process.argv[1], ...args];
      await program.parseAsync(process.argv);
    });

  return cmd;
}
```

### 3.3 Help Output

```bash
$ fractary --help

Fractary CLI - Unified command-line interface for all Fractary tools

Usage: fractary <command> [options]

SDK Commands:
  faber       FABER development toolkit (workflow, work, repo, spec, logs)
  codex       Codex knowledge infrastructure (fetch, sync, cache, mcp)
  forge       Asset management and project scaffolding
  helm        Runtime governance and monitoring [coming soon]

Shortcut Commands:
  work        Work item tracking (alias for: faber work)
  repo        Repository operations (alias for: faber repo)
  spec        Specification management (alias for: faber spec)
  logs        Log management (alias for: faber logs)

Options:
  -V, --version  Show version number
  -h, --help     Show help

Examples:
  $ fractary faber run --work-id 123     # Run FABER workflow
  $ fractary work issue fetch 123        # Fetch work item (shortcut)
  $ fractary repo commit "Add feature"   # Create commit (shortcut)
  $ fractary codex fetch "codex://org/project/doc.md"  # Fetch from Codex

Run 'fractary <command> --help' for more information on a command.
```

## 4. Command Specifications

### 4.1 FABER SDK Commands

#### 4.1.1 Workflow Commands

```bash
# Initialize FABER configuration
fractary faber init [--preset <name>] [--force]

# Run FABER workflow
fractary faber run --work-id <id> [--autonomy <level>] [--phase <phase>]
  --work-id       Work item ID to process (required)
  --autonomy      Autonomy level: dry-run|assist|guarded|autonomous (default: guarded)
  --phase         Start from specific phase: frame|architect|build|evaluate|release
  --resume        Resume from last checkpoint
  --skip-frame    Skip frame phase (reuse existing context)

# Check workflow status
fractary faber status [--work-id <id>] [--verbose]

# Create or view execution plan
fractary faber plan --work-id <id> [--output <path>]
```

#### 4.1.2 Work Commands

```bash
# Issue operations
fractary work issue fetch <number>
fractary work issue create --title <title> [--type <type>] [--body <body>]
fractary work issue update <number> [--title <title>] [--body <body>]
fractary work issue close <number> [--comment <text>]
fractary work issue search --query <query> [--state <state>] [--limit <n>]

# Comment operations
fractary work comment create <issue_number> --body <text>
fractary work comment list <issue_number> [--limit <n>]

# Label operations
fractary work label add <issue_number> --label <name>
fractary work label remove <issue_number> --label <name>
fractary work label list [--issue <number>]

# Milestone operations
fractary work milestone create --title <title> [--due <date>]
fractary work milestone list [--state <state>]
fractary work milestone assign <issue_number> --milestone <id>
```

#### 4.1.3 Repo Commands

```bash
# Branch operations
fractary repo branch create --description <desc> [--work-id <id>] [--base <branch>] [--worktree]
fractary repo branch delete <name> [--location <local|remote|both>] [--force]
fractary repo branch list [--stale] [--merged] [--pattern <glob>]

# Commit operations
fractary repo commit --message <msg> [--type <type>] [--scope <scope>] [--work-id <id>]
fractary repo commit-and-push --message <msg> [--type <type>] [--set-upstream]

# Pull request operations
fractary repo pr create --title <title> [--body <text>] [--base <branch>] [--draft]
fractary repo pr review <number> [--action <approve|request_changes|comment>]
fractary repo pr merge <number> [--strategy <merge|squash|rebase>] [--delete-branch]
fractary repo pr list [--state <open|closed|all>] [--author <user>]

# Tag operations
fractary repo tag create <name> [--message <text>] [--sign]
fractary repo tag push <name|all> [--remote <name>]
fractary repo tag list [--pattern <glob>] [--latest <n>]

# Worktree operations
fractary repo worktree create <branch> [--work-id <id>]
fractary repo worktree list
fractary repo worktree remove <branch> [--force]
fractary repo worktree cleanup [--merged] [--stale] [--dry-run]

# Push/Pull operations
fractary repo push [--remote <name>] [--set-upstream] [--force]
fractary repo pull [--rebase] [--strategy <merge|rebase|ff-only>]
```

#### 4.1.4 Spec Commands

```bash
# Create specification
fractary spec create --work-id <id> [--template <type>] [--force]

# Refine specification with Q&A
fractary spec refine --work-id <id> [--prompt <focus>] [--round <n>]

# Validate implementation against spec
fractary spec validate --work-id <id> [--phase <phase>]

# Archive specification to cloud storage
fractary spec archive --work-id <id> [--force]

# Read specification
fractary spec read --work-id <id> [--phase <n>]

# List specifications
fractary spec list [--status <draft|complete|archived>]

# Update specification
fractary spec update --work-id <id> --phase <id> [--status <status>] [--check-task <text>]
```

#### 4.1.5 Logs Commands

```bash
# Session capture
fractary logs capture <issue_number> [--model <model>]
fractary logs stop

# Write typed log
fractary logs write --type <type> --title <title> [--issue <number>]
  --type    Log type: session|build|deployment|debug|test|audit|operational

# Search logs
fractary logs search --query <text> [--type <type>] [--issue <number>]

# List logs
fractary logs list [--type <type>] [--status <active|archived>] [--issue <number>]

# Archive logs
fractary logs archive [--type <type>] [--issue <number>] [--dry-run]

# Cleanup old logs
fractary logs cleanup [--older-than <days>] [--type <type>] [--dry-run]

# Audit logs
fractary logs audit [--execute] [--verbose]
```

### 4.2 Codex SDK Commands

```bash
# Initialize Codex configuration
fractary codex init --org <name> [--codex-repo <url>]

# Fetch document by reference
fractary codex fetch <reference> [--no-cache] [--output <path>]
  Examples:
    fractary codex fetch "codex://fractary/plugins/docs/standards.md"
    fractary codex fetch "standards/api-design.md"

# Sync operations
fractary codex sync project [--direction <to-codex|from-codex|bidirectional>] [--dry-run]
fractary codex sync org [--parallel <n>] [--exclude <pattern>] [--dry-run]

# Cache management
fractary codex cache list [--expired] [--type <type>]
fractary codex cache clear [--pattern <glob>] [--expired-only]
fractary codex cache metrics

# Validate references
fractary codex validate [--path <dir>] [--fix]

# MCP server
fractary codex mcp start [--port <port>]
fractary codex mcp status
```

## 5. SDK Integration Layer

### 5.1 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         @fractary/cli                            │
├─────────────────────────────────────────────────────────────────┤
│  Commands Layer                                                  │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐      │
│  │  faber   │  codex   │  work*   │  repo*   │  spec*   │      │
│  └────┬─────┴────┬─────┴────┬─────┴────┬─────┴────┬─────┘      │
│       │          │          │          │          │             │
├───────┼──────────┼──────────┴──────────┴──────────┘             │
│  SDK Integration Layer                                           │
│  ┌────┴────┐ ┌───┴────┐                                         │
│  │  Faber  │ │ Codex  │  ← Runtime SDK detection                │
│  │ Client  │ │ Client │                                         │
│  └────┬────┘ └───┬────┘                                         │
└───────┼──────────┼──────────────────────────────────────────────┘
        │          │
        ▼          ▼
┌───────────┐ ┌───────────┐
│@fractary/ │ │@fractary/ │
│  faber    │ │  codex    │
│   SDK     │ │   SDK     │
└───────────┘ └───────────┘
```

### 5.2 SDK Client Factory

```typescript
// src/sdk/factory.ts

import type { FaberClient } from '@fractary/faber';
import type { CodexClient } from '@fractary/codex';

interface SDKClients {
  faber?: FaberClient;
  codex?: CodexClient;
}

let clients: SDKClients = {};

export async function getFaberClient(): Promise<FaberClient> {
  if (!clients.faber) {
    try {
      const { createClient } = await import('@fractary/faber');
      clients.faber = await createClient({
        configPath: findConfigPath('faber'),
      });
    } catch (error) {
      throw new SDKNotAvailableError('faber', error);
    }
  }
  return clients.faber;
}

export async function getCodexClient(): Promise<CodexClient> {
  if (!clients.codex) {
    try {
      const { createClient } = await import('@fractary/codex');
      clients.codex = await createClient({
        configPath: findConfigPath('codex'),
      });
    } catch (error) {
      throw new SDKNotAvailableError('codex', error);
    }
  }
  return clients.codex;
}

export function tryGetCodexClient(): Promise<CodexClient | null> {
  return getCodexClient().catch(() => null);
}
```

### 5.3 Command Implementation Pattern

```typescript
// src/tools/faber/commands/work/issue/fetch.ts

import { Command } from 'commander';
import { getFaberClient } from '../../../../sdk/factory';
import { formatOutput, handleError } from '../../../../utils';

export function createIssueFetchCommand(): Command {
  return new Command('fetch')
    .description('Fetch a work item by ID')
    .argument('<number>', 'Issue number')
    .option('--json', 'Output as JSON')
    .option('--verbose', 'Show additional details')
    .action(async (number: string, options) => {
      try {
        const faber = await getFaberClient();
        const workItem = await faber.work.getWorkItem(number);

        formatOutput(workItem, {
          format: options.json ? 'json' : 'table',
          verbose: options.verbose,
        });

        process.exit(0);
      } catch (error) {
        handleError(error);
        process.exit(1);
      }
    });
}
```

### 5.4 Cross-SDK Operations

Some operations benefit from both SDKs when available:

```typescript
// src/tools/faber/commands/spec/archive.ts

export async function archiveSpec(workId: string, options: ArchiveOptions) {
  const faber = await getFaberClient();
  const spec = await faber.spec.read(workId);

  // Try to use Codex for cloud archival if available
  const codex = await tryGetCodexClient();

  if (codex && !options.localOnly) {
    // Archive to Codex knowledge base
    const result = await codex.archive({
      content: spec.content,
      reference: `codex://${org}/${project}/specs/${spec.filename}`,
      type: 'spec',
      metadata: { workId, status: 'archived' },
    });

    return {
      ...result,
      cloudUrl: result.url,
      archivedToCodex: true,
    };
  }

  // Fallback to local archival via FABER SDK
  return faber.spec.archiveLocal(workId, options);
}
```

## 6. Plugin Bridge

### 6.1 Overview

Claude Code plugins invoke CLI commands. The plugin bridge ensures:
- Structured output for machine parsing
- Consistent error format
- Exit code semantics
- Streaming support for long operations

### 6.2 Plugin Invocation Pattern

```markdown
<!-- plugins/work/commands/issue-fetch.md -->

# issue-fetch

Fetch a work item by ID.

<WORKFLOW>
1. Parse arguments from user input
2. Execute: `fractary work issue fetch <number> --json`
3. Parse JSON response
4. Format for Claude display
</WORKFLOW>
```

### 6.3 Structured Output Mode

When invoked with `--json`, commands output structured responses:

```typescript
// Success response
{
  "status": "success",
  "data": {
    "id": "123",
    "title": "Implement feature X",
    "state": "open",
    // ... full work item data
  }
}

// Error response
{
  "status": "error",
  "error": {
    "code": "WORK_ITEM_NOT_FOUND",
    "message": "Work item #999 not found",
    "details": {
      "workId": "999",
      "provider": "github"
    }
  },
  "suggestions": [
    "Check that the issue number is correct",
    "Verify you have access to this repository"
  ]
}
```

### 6.4 Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Configuration error |
| 4 | Authentication error |
| 5 | Resource not found |
| 6 | Permission denied |
| 7 | Rate limit exceeded |
| 8 | Network error |
| 9 | SDK not available |

### 6.5 Plugin Agent Pattern

```markdown
<!-- plugins/work/agents/work-manager.md -->

<CONTEXT>
You are the work-manager agent. You route work tracking operations to CLI commands.
</CONTEXT>

<WORKFLOW>
1. Parse user request to determine operation
2. Map to CLI command:
   - fetch issue → `fractary work issue fetch <id> --json`
   - create issue → `fractary work issue create --title <t> --json`
   - add comment → `fractary work comment create <id> --body <text> --json`
3. Execute command via Bash tool
4. Parse JSON response
5. Handle errors using standardized format
6. Return formatted result to user
</WORKFLOW>

<COMMAND_MAPPING>
| Operation | CLI Command |
|-----------|-------------|
| fetch-work | `fractary work issue fetch <id> --json` |
| create-work | `fractary work issue create --title <t> --type <type> --json` |
| update-work | `fractary work issue update <id> --title <t> --json` |
| close-work | `fractary work issue close <id> --json` |
| add-comment | `fractary work comment create <id> --body <text> --json` |
| add-label | `fractary work label add <id> --label <name> --json` |
</COMMAND_MAPPING>
```

## 7. Output Formatting

### 7.1 Format Options

All commands support:
- `--json` - Machine-readable JSON
- `--yaml` - YAML output
- `--table` - Tabular display (default for lists)
- `--plain` - Plain text (default for single items)
- `--quiet` - Minimal output (IDs/paths only)

### 7.2 Formatter Implementation

```typescript
// src/utils/formatter.ts

export type OutputFormat = 'json' | 'yaml' | 'table' | 'plain' | 'quiet';

export interface FormatOptions {
  format?: OutputFormat;
  verbose?: boolean;
  color?: boolean;
}

export function formatOutput(data: unknown, options: FormatOptions = {}): void {
  const format = options.format ?? detectFormat();

  switch (format) {
    case 'json':
      console.log(JSON.stringify(data, null, 2));
      break;
    case 'yaml':
      console.log(yaml.dump(data));
      break;
    case 'table':
      console.log(formatTable(data, options));
      break;
    case 'plain':
      console.log(formatPlain(data, options));
      break;
    case 'quiet':
      console.log(formatQuiet(data));
      break;
  }
}

function detectFormat(): OutputFormat {
  // Use JSON if stdout is not a TTY (piped/scripted)
  if (!process.stdout.isTTY) {
    return 'json';
  }
  return 'plain';
}
```

### 7.3 Progress Indicators

Long-running operations show progress:

```typescript
// src/utils/progress.ts

export async function withProgress<T>(
  label: string,
  operation: () => Promise<T>
): Promise<T> {
  if (!process.stdout.isTTY) {
    // No progress in non-TTY mode
    return operation();
  }

  const spinner = ora(label).start();
  try {
    const result = await operation();
    spinner.succeed();
    return result;
  } catch (error) {
    spinner.fail();
    throw error;
  }
}
```

## 8. Configuration Management

### 8.1 Configuration Hierarchy

```
1. Default values (built into CLI)
2. Global config (~/.config/fractary/cli/config.json)
3. Project config (.fractary/cli/config.json)
4. Environment variables (FRACTARY_*)
5. CLI arguments (--option value)
```

Higher numbers override lower numbers.

### 8.2 Configuration Schema

```typescript
// src/config/schema.ts

export interface CLIConfig {
  // Output preferences
  output: {
    format: 'json' | 'yaml' | 'table' | 'plain';
    color: boolean;
    verbose: boolean;
  };

  // SDK settings
  sdk: {
    faber: {
      configPath?: string;
    };
    codex: {
      configPath?: string;
    };
  };

  // Plugin bridge settings
  plugins: {
    outputFormat: 'json';  // Always JSON for plugins
    includeMetadata: boolean;
  };
}
```

### 8.3 Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `FRACTARY_OUTPUT_FORMAT` | Default output format | `json` |
| `FRACTARY_NO_COLOR` | Disable color output | `1` |
| `FRACTARY_FABER_CONFIG` | FABER SDK config path | `/path/to/config.json` |
| `FRACTARY_CODEX_CONFIG` | Codex SDK config path | `/path/to/config.json` |
| `FRACTARY_VERBOSE` | Enable verbose output | `1` |

## 9. Error Handling

### 9.1 Error Hierarchy

```typescript
// src/errors/index.ts

export class CLIError extends Error {
  constructor(
    message: string,
    public code: string,
    public exitCode: number = 1,
    public details?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'CLIError';
  }
}

export class SDKNotAvailableError extends CLIError {
  constructor(sdk: 'faber' | 'codex', cause?: Error) {
    super(
      `${sdk} SDK is not available. Install with: npm install @fractary/${sdk}`,
      'SDK_NOT_AVAILABLE',
      9,
      { sdk, cause: cause?.message }
    );
  }
}

export class ConfigurationError extends CLIError {
  constructor(message: string, details?: Record<string, unknown>) {
    super(message, 'CONFIGURATION_ERROR', 3, details);
  }
}

export class AuthenticationError extends CLIError {
  constructor(provider: string, message?: string) {
    super(
      message ?? `Authentication failed for ${provider}`,
      'AUTHENTICATION_ERROR',
      4,
      { provider }
    );
  }
}
```

### 9.2 Error Handler

```typescript
// src/utils/error-handler.ts

export function handleError(error: unknown): void {
  if (error instanceof CLIError) {
    if (process.stdout.isTTY) {
      console.error(chalk.red(`Error: ${error.message}`));
      if (error.details) {
        console.error(chalk.gray(JSON.stringify(error.details, null, 2)));
      }
    } else {
      // JSON output for non-TTY
      console.error(JSON.stringify({
        status: 'error',
        error: {
          code: error.code,
          message: error.message,
          details: error.details,
        },
      }));
    }
    process.exit(error.exitCode);
  }

  // Unknown error
  console.error(chalk.red('Unexpected error:'), error);
  process.exit(1);
}
```

## 10. Directory Structure

### 10.1 Target Structure

```
cli/
├── src/
│   ├── cli.ts                    # Entry point
│   ├── sdk/                      # SDK integration layer
│   │   ├── factory.ts            # SDK client factory
│   │   ├── faber.ts              # FABER SDK wrapper
│   │   └── codex.ts              # Codex SDK wrapper
│   ├── tools/
│   │   ├── faber/
│   │   │   ├── index.ts          # faber command tree
│   │   │   └── commands/
│   │   │       ├── init.ts
│   │   │       ├── run.ts
│   │   │       ├── status.ts
│   │   │       ├── plan.ts
│   │   │       ├── work/
│   │   │       │   ├── index.ts
│   │   │       │   ├── issue/
│   │   │       │   │   ├── fetch.ts
│   │   │       │   │   ├── create.ts
│   │   │       │   │   └── ...
│   │   │       │   ├── comment/
│   │   │       │   ├── label/
│   │   │       │   └── milestone/
│   │   │       ├── repo/
│   │   │       │   ├── index.ts
│   │   │       │   ├── branch/
│   │   │       │   ├── commit/
│   │   │       │   ├── pr/
│   │   │       │   ├── tag/
│   │   │       │   └── worktree/
│   │   │       ├── spec/
│   │   │       │   ├── create.ts
│   │   │       │   ├── refine.ts
│   │   │       │   ├── validate.ts
│   │   │       │   └── archive.ts
│   │   │       └── logs/
│   │   │           ├── capture.ts
│   │   │           ├── write.ts
│   │   │           ├── search.ts
│   │   │           └── archive.ts
│   │   ├── codex/
│   │   │   ├── index.ts
│   │   │   └── commands/
│   │   │       ├── init.ts
│   │   │       ├── fetch.ts
│   │   │       ├── sync/
│   │   │       ├── cache/
│   │   │       ├── validate.ts
│   │   │       └── mcp/
│   │   ├── forge/
│   │   │   └── ... (existing)
│   │   └── aliases/
│   │       ├── work.ts           # work → faber work
│   │       ├── repo.ts           # repo → faber repo
│   │       ├── spec.ts           # spec → faber spec
│   │       └── logs.ts           # logs → faber logs
│   ├── utils/
│   │   ├── formatter.ts          # Output formatting
│   │   ├── progress.ts           # Progress indicators
│   │   ├── error-handler.ts      # Error handling
│   │   └── config.ts             # Configuration loading
│   ├── config/
│   │   └── schema.ts             # Config schema
│   └── errors/
│       └── index.ts              # Error classes
├── package.json
├── tsconfig.json
└── README.md
```

## 11. Migration Path

### 11.1 Phase 1: SDK Enhancement

Before CLI changes, the SDKs must be enhanced:

1. **@fractary/faber** - Add work, repo, spec, logs modules (per SPEC-00023)
2. **@fractary/codex** - Add storage, cache, sync, MCP modules (per SPEC-00024)

### 11.2 Phase 2: CLI Command Expansion

Add new commands to CLI:

1. Add `src/tools/faber/commands/work/` directory
2. Add `src/tools/faber/commands/repo/` directory
3. Add `src/tools/faber/commands/spec/` directory
4. Add `src/tools/faber/commands/logs/` directory
5. Expand `src/tools/codex/commands/` with new operations

### 11.3 Phase 3: Alias Implementation

Add top-level aliases:

1. Create `src/tools/aliases/` directory
2. Implement alias command factory
3. Register aliases in `cli.ts`

### 11.4 Phase 4: Plugin Bridge Enhancement

Update plugins to use CLI:

1. Update plugin agents to invoke CLI commands
2. Standardize JSON output parsing
3. Update error handling to use CLI exit codes

## 12. Testing Strategy

### 12.1 Test Levels

| Level | Location | Purpose |
|-------|----------|---------|
| Unit Tests | `src/**/*.test.ts` | Individual functions |
| Command Tests | `tests/commands/` | Command parsing and execution |
| Integration Tests | `tests/integration/` | SDK + CLI integration |
| E2E Tests | `tests/e2e/` | Full workflow tests |

### 12.2 Command Testing Pattern

```typescript
// tests/commands/work/issue/fetch.test.ts

describe('fractary work issue fetch', () => {
  it('should fetch issue and output JSON', async () => {
    const result = await execCLI(['work', 'issue', 'fetch', '123', '--json']);

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('"status": "success"');

    const data = JSON.parse(result.stdout);
    expect(data.data.id).toBe('123');
  });

  it('should return exit code 5 for not found', async () => {
    const result = await execCLI(['work', 'issue', 'fetch', '99999', '--json']);

    expect(result.exitCode).toBe(5);
    expect(result.stderr).toContain('WORK_ITEM_NOT_FOUND');
  });
});
```

## 13. References

- [SPEC-00023: FABER SDK](./SPEC-00023-faber-sdk.md) - FABER SDK specification
- [SPEC-00024: Codex SDK](./SPEC-00024-codex-sdk.md) - Codex SDK specification
- [SPEC-00016: SDK Architecture](./SPEC-00016-sdk-architecture.md) - Overall SDK architecture
- [SPEC-00014: CLI Argument Standards](./SPEC-00014-cli-argument-standards.md) - Argument syntax standards
- [Commander.js Documentation](https://github.com/tj/commander.js)
- [Existing CLI Project](https://github.com/fractary/cli)

## 14. Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-11 | 0.1.0 | Initial draft |
