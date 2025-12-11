# SPEC-00015: FABER Orchestrator

| Field | Value |
|-------|-------|
| **Status** | Draft |
| **Created** | 2025-12-10 |
| **Author** | Claude (with human direction) |
| **Related** | SPEC-00002-faber-architecture, fractary/cli |

## 1. Executive Summary

This specification defines the **FABER Orchestrator**, a deterministic workflow execution engine that uses LLMs as workers rather than orchestrators. The orchestrator will be integrated into the `fractary` CLI (`fractary/cli` repository) and will replace the current Claude Code plugin-based execution approach.

### 1.1 Problem Statement

The current FABER implementation attempts to use Claude Code (an LLM) to orchestrate workflow execution. This approach has fundamental limitations:

1. **Permission boundaries** - Non-interactive Claude sessions cannot approve operations
2. **State reliability** - LLMs can hallucinate progress, skip steps, or lose track of state
3. **Control flow unpredictability** - LLMs introduce variability where determinism is required
4. **Model lock-in** - Tied to Anthropic's Claude with no ability to use other models
5. **Cost inefficiency** - Using expensive models for orchestration tasks that don't require intelligence

### 1.2 Solution

A proper orchestration layer where:
- **Code owns the workflow loop** (deterministic, not LLM-controlled)
- **LLMs are invoked as tools** for steps that require intelligence
- **Direct API access** eliminates permission issues and gives full control
- **Model routing** enables using the right model for each task
- **Ensemble support** allows "meeting of minds" decisions from multiple models

## 2. Architecture

### 2.1 High-Level Design

```
┌─────────────────────────────────────────────────────────────────┐
│                      Fractary CLI                               │
│                 fractary faber <command>                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Workflow Engine                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │  Frame   │→ │ Architect│→ │  Build   │→ │ Evaluate │→ ...   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │
│                         │                                       │
│                         ▼                                       │
│  ┌─────────────────────────────────────────────────────┐       │
│  │              Step Executor                           │       │
│  │  • Deterministic code controls flow                  │       │
│  │  • LLM calls are function invocations               │       │
│  │  • State persisted after each step                  │       │
│  │  • Resume from any step on failure                  │       │
│  └─────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Model Router                                 │
│  ┌─────────────────────────────────────────────────────┐       │
│  │  Route by step type:                                 │       │
│  │  • classify_work    → Haiku (fast, cheap)           │       │
│  │  • generate_spec    → Opus (deep reasoning)         │       │
│  │  • implement        → Sonnet (code, balanced)       │       │
│  │  • review           → Ensemble [Opus + GPT-4]       │       │
│  └─────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Provider Adapters                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ Anthropic│  │  OpenAI  │  │  Google  │  │  Local   │        │
│  │   API    │  │   API    │  │  Gemini  │  │ (Ollama) │        │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Tool Execution Layer                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │   Git    │  │  GitHub  │  │   File   │  │  Shell   │        │
│  │  Client  │  │   API    │  │   I/O    │  │   Exec   │        │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Responsibilities

| Component | Responsibility |
|-----------|----------------|
| **CLI Layer** | Parse commands, load config, invoke workflow engine |
| **Workflow Engine** | Execute phases/steps in order, manage state, emit events |
| **Step Executor** | Execute individual steps, handle LLM tool loops |
| **Model Router** | Select model(s) for each step based on configuration |
| **Provider Adapters** | Unified interface to different LLM APIs |
| **Tool Executor** | Execute tools (git, file, github) directly without LLM permission dance |

### 2.3 Data Flow

```
1. User runs: fractary faber run --work-id 123

2. CLI loads:
   - Project config (.fractary/faber/config.toml)
   - Workflow definition (.fractary/faber/workflows/default.json)
   - Provider credentials (from env vars)

3. Workflow Engine:
   a. Creates execution plan
   b. Initializes state store
   c. For each phase:
      - Emit phase_start event
      - For each step:
        - Emit step_start event
        - Save state (in_progress)
        - Route to appropriate model(s)
        - Execute LLM with tools
        - Process tool calls directly
        - Save state (completed/failed)
        - Emit step_complete/step_failed event
      - Emit phase_complete event

4. On completion or failure:
   - Save final state
   - Emit workflow_complete/workflow_failed event
   - Return result to CLI
```

## 3. CLI Commands

### 3.1 Command Structure

```bash
fractary faber <command> [options]
```

### 3.2 Commands

#### 3.2.1 `fractary faber run`

Execute a FABER workflow for a work item.

```bash
fractary faber run [options]

Options:
  --work-id <id>          Work item ID (GitHub issue, Jira ticket, etc.)
  --workflow <id>         Workflow to use (default: "default")
  --autonomy <level>      Autonomy level: autonomous, guarded, assisted (default: guarded)
  --phase <phases>        Comma-separated phases to run (default: all)
  --dry-run               Show what would be executed without running
  --verbose               Enable verbose output
  --json                  Output results as JSON

Examples:
  fractary faber run --work-id 123
  fractary faber run --work-id 123 --autonomy assisted --phase frame,architect
  fractary faber run --work-id 123 --dry-run
```

#### 3.2.2 `fractary faber plan`

Create an execution plan without executing.

```bash
fractary faber plan [options]

Options:
  --work-id <id>          Work item ID
  --workflow <id>         Workflow to use
  --output <path>         Save plan to file (default: stdout)
  --json                  Output as JSON

Examples:
  fractary faber plan --work-id 123
  fractary faber plan --work-id 123 --output plan.json
```

#### 3.2.3 `fractary faber execute`

Execute a previously created plan.

```bash
fractary faber execute <plan-id> [options]

Options:
  --from-step <n>         Resume from step N (0-based index)
  --step <step-id>        Execute only specific step
  --dry-run               Show what would be executed
  --verbose               Enable verbose output

Examples:
  fractary faber execute plan-abc123
  fractary faber execute plan-abc123 --from-step 5
```

#### 3.2.4 `fractary faber status`

Check status of running or completed workflows.

```bash
fractary faber status [run-id] [options]

Options:
  --all                   Show all runs (not just current)
  --json                  Output as JSON
  --watch                 Watch for updates (live)

Examples:
  fractary faber status
  fractary faber status run-abc123
  fractary faber status --all --json
```

#### 3.2.5 `fractary faber logs`

View execution logs for a workflow run.

```bash
fractary faber logs <run-id> [options]

Options:
  --step <step-id>        Show logs for specific step
  --phase <phase>         Show logs for specific phase
  --follow                Follow logs in real-time
  --tail <n>              Show last N lines (default: 100)
  --json                  Output as JSON

Examples:
  fractary faber logs run-abc123
  fractary faber logs run-abc123 --step implement
  fractary faber logs run-abc123 --follow
```

#### 3.2.6 `fractary faber cancel`

Cancel a running workflow.

```bash
fractary faber cancel <run-id> [options]

Options:
  --force                 Force cancel without cleanup
  --reason <text>         Cancellation reason

Examples:
  fractary faber cancel run-abc123
  fractary faber cancel run-abc123 --reason "Requirements changed"
```

#### 3.2.7 `fractary faber config`

Manage orchestrator configuration.

```bash
fractary faber config <action> [key] [value]

Actions:
  show                    Show current configuration
  get <key>               Get specific config value
  set <key> <value>       Set config value
  validate                Validate configuration

Examples:
  fractary faber config show
  fractary faber config get model_routing.implement
  fractary faber config set model_routing.default.model claude-sonnet-4
  fractary faber config validate
```

## 4. Configuration

### 4.1 Configuration File Location

```
.fractary/faber/config.toml          # Main configuration
.fractary/faber/workflows/           # Workflow definitions
.fractary/faber/state/               # Execution state (gitignored)
.fractary/faber/logs/                # Execution logs
```

### 4.2 Configuration Schema

```toml
# .fractary/faber/config.toml

[orchestrator]
version = "1.0"
default_workflow = "default"
default_autonomy = "guarded"

# Work item integration
[work]
provider = "github"  # github, jira, linear
# Provider-specific settings loaded from environment

# Source control integration
[repo]
provider = "github"  # github, gitlab, bitbucket
default_branch = "main"
branch_prefix = "feat"

# Model routing configuration
[model_routing]

# Default model for steps without specific routing
[model_routing.default]
provider = "anthropic"
model = "claude-sonnet-4-20250514"

# Step-specific routing (by step ID or step type)
[model_routing.steps.classify_work]
provider = "anthropic"
model = "claude-3-5-haiku-20241022"

[model_routing.steps.generate_spec]
provider = "anthropic"
model = "claude-opus-4-20250514"

[model_routing.steps.implement]
provider = "anthropic"
model = "claude-sonnet-4-20250514"

# Ensemble configuration for review step
[model_routing.steps.review]
strategy = "ensemble"
aggregation = "merge"  # vote, merge, best

[[model_routing.steps.review.models]]
provider = "anthropic"
model = "claude-opus-4-20250514"

[[model_routing.steps.review.models]]
provider = "openai"
model = "gpt-4o"

# Provider credentials (from environment variables)
[providers.anthropic]
api_key_env = "ANTHROPIC_API_KEY"
base_url = "https://api.anthropic.com"  # Optional override

[providers.openai]
api_key_env = "OPENAI_API_KEY"

[providers.google]
api_key_env = "GOOGLE_API_KEY"

[providers.ollama]
base_url = "http://localhost:11434"

# Tool configuration
[tools.git]
enabled = true

[tools.github]
token_env = "GITHUB_TOKEN"

[tools.filesystem]
enabled = true
sandbox = "."  # Restrict to current directory

[tools.shell]
enabled = true
allowed_commands = ["npm", "node", "python", "pytest", "jest"]

# Autonomy level settings
[autonomy.guarded]
pause_before = ["release"]  # Phases requiring approval
require_approval_for = ["merge_pr", "deploy"]

[autonomy.assisted]
pause_before = ["architect", "build", "release"]

[autonomy.autonomous]
pause_before = []
```

### 4.3 Workflow Definition

```json
// .fractary/faber/workflows/default.json
{
  "id": "default",
  "name": "Standard FABER Workflow",
  "version": "1.0",
  "extends": null,

  "phases": {
    "frame": {
      "enabled": true,
      "steps": [
        {
          "id": "fetch_work",
          "name": "Fetch Work Item",
          "type": "work_fetch",
          "config": {}
        },
        {
          "id": "classify_work",
          "name": "Classify Work Type",
          "type": "llm_task",
          "prompt_template": "classify_work",
          "config": {}
        },
        {
          "id": "create_branch",
          "name": "Create Branch",
          "type": "repo_branch",
          "config": {
            "prefix": "feat"
          }
        }
      ]
    },

    "architect": {
      "enabled": true,
      "steps": [
        {
          "id": "generate_spec",
          "name": "Generate Specification",
          "type": "llm_task",
          "prompt_template": "generate_spec",
          "tools": ["file_read", "file_search", "web_search"],
          "config": {
            "output_path": ".fractary/faber/specs/{work_id}.md"
          }
        },
        {
          "id": "refine_spec",
          "name": "Refine Specification",
          "type": "llm_task",
          "prompt_template": "refine_spec",
          "tools": ["file_read", "file_write", "ask_user"],
          "config": {}
        }
      ]
    },

    "build": {
      "enabled": true,
      "steps": [
        {
          "id": "implement",
          "name": "Implement Solution",
          "type": "llm_agentic",
          "prompt_template": "implement",
          "tools": ["file_read", "file_write", "file_search", "shell_exec", "web_search"],
          "config": {
            "max_iterations": 50,
            "checkpoint_interval": 10
          }
        },
        {
          "id": "commit_changes",
          "name": "Commit Changes",
          "type": "repo_commit",
          "config": {
            "message_template": "feat({scope}): {summary}\n\nCloses #{work_id}"
          }
        }
      ]
    },

    "evaluate": {
      "enabled": true,
      "max_retries": 3,
      "steps": [
        {
          "id": "run_tests",
          "name": "Run Tests",
          "type": "shell_exec",
          "config": {
            "command": "npm test",
            "allow_failure": false
          }
        },
        {
          "id": "review",
          "name": "Code Review",
          "type": "llm_task",
          "prompt_template": "code_review",
          "tools": ["file_read", "git_diff"],
          "config": {}
        },
        {
          "id": "create_pr",
          "name": "Create Pull Request",
          "type": "repo_pr",
          "config": {
            "draft": false,
            "auto_merge": false
          }
        }
      ]
    },

    "release": {
      "enabled": true,
      "steps": [
        {
          "id": "wait_ci",
          "name": "Wait for CI",
          "type": "repo_ci_wait",
          "config": {
            "timeout_minutes": 30
          }
        },
        {
          "id": "merge_pr",
          "name": "Merge Pull Request",
          "type": "repo_pr_merge",
          "config": {
            "strategy": "squash",
            "delete_branch": true
          }
        }
      ]
    }
  }
}
```

## 5. Core Interfaces

### 5.1 Workflow Engine

```typescript
interface WorkflowEngine {
  // Execute a complete workflow
  execute(plan: ExecutionPlan, options: ExecutionOptions): Promise<ExecutionResult>;

  // Execute a single step
  executeStep(step: Step, context: ExecutionContext): Promise<StepResult>;

  // Pause/resume support
  pause(runId: string): Promise<void>;
  resume(runId: string, fromStep?: string): Promise<ExecutionResult>;
  cancel(runId: string, reason?: string): Promise<void>;

  // Status and logs
  getStatus(runId: string): Promise<RunStatus>;
  getLogs(runId: string, options?: LogOptions): AsyncIterable<LogEntry>;

  // Event subscription
  on(event: WorkflowEvent, handler: EventHandler): void;
}

interface ExecutionPlan {
  id: string;
  workId: string;
  workflow: WorkflowDefinition;
  context: WorkflowContext;
  createdAt: Date;
}

interface ExecutionOptions {
  autonomy: 'autonomous' | 'guarded' | 'assisted';
  dryRun?: boolean;
  fromStep?: string;
  phases?: string[];
  verbose?: boolean;
}

interface ExecutionResult {
  runId: string;
  status: 'completed' | 'failed' | 'cancelled' | 'paused';
  phases: PhaseResult[];
  duration: number;
  error?: Error;
  artifacts: Record<string, any>;
}
```

### 5.2 Model Router

```typescript
interface ModelRouter {
  // Get model configuration for a step
  getModelConfig(step: Step, context: ExecutionContext): ModelConfig | EnsembleConfig;

  // Execute with routing
  execute(step: Step, context: ExecutionContext): Promise<LLMResponse>;
}

interface ModelConfig {
  provider: string;
  model: string;
  temperature?: number;
  maxTokens?: number;
}

interface EnsembleConfig {
  strategy: 'ensemble';
  models: ModelConfig[];
  aggregation: 'vote' | 'merge' | 'best';
  synthesisModel?: ModelConfig;  // Model to merge responses
}
```

### 5.3 Provider Adapter

```typescript
interface LLMProvider {
  // Core completion with tool support
  complete(request: CompletionRequest): Promise<CompletionResponse>;

  // Streaming support
  stream(request: CompletionRequest): AsyncIterable<StreamChunk>;

  // Provider info
  readonly name: string;
  readonly supportedModels: string[];
}

interface CompletionRequest {
  model: string;
  messages: Message[];
  tools?: ToolDefinition[];
  temperature?: number;
  maxTokens?: number;
  stopSequences?: string[];
}

interface CompletionResponse {
  id: string;
  content: ContentBlock[];
  stopReason: 'end_turn' | 'tool_use' | 'max_tokens' | 'stop_sequence';
  usage: {
    inputTokens: number;
    outputTokens: number;
  };
}
```

### 5.4 Tool Executor

```typescript
interface ToolExecutor {
  // Execute a tool call
  execute(toolCall: ToolCall, context: ExecutionContext): Promise<ToolResult>;

  // List available tools
  getAvailableTools(): ToolDefinition[];

  // Check if tool is allowed
  isAllowed(toolName: string, context: ExecutionContext): boolean;
}

interface ToolCall {
  id: string;
  name: string;
  input: Record<string, any>;
}

interface ToolResult {
  toolUseId: string;
  content: string | object;
  isError: boolean;
}

// Built-in tool definitions
type BuiltInTool =
  | 'file_read'
  | 'file_write'
  | 'file_search'
  | 'git_status'
  | 'git_diff'
  | 'git_commit'
  | 'git_branch'
  | 'github_issue'
  | 'github_pr'
  | 'shell_exec'
  | 'web_search'
  | 'ask_user';
```

## 6. State Management

### 6.1 State File Structure

```
.fractary/faber/state/
├── runs/
│   └── {run-id}/
│       ├── state.json           # Current execution state
│       ├── plan.json            # Original execution plan
│       ├── events/              # Event log (append-only)
│       │   ├── 001-workflow_start.json
│       │   ├── 002-phase_start.json
│       │   └── ...
│       └── artifacts/           # Step outputs
│           ├── spec.md
│           └── ...
└── current                      # Symlink to active run (if any)
```

### 6.2 State Schema

```typescript
interface ExecutionState {
  runId: string;
  planId: string;
  workId: string;
  status: 'pending' | 'running' | 'paused' | 'completed' | 'failed' | 'cancelled';

  // Current position
  currentPhase: string | null;
  currentStep: string | null;
  currentStepIndex: number;

  // Phase tracking
  phases: Record<string, PhaseState>;

  // Timing
  startedAt: string;
  updatedAt: string;
  completedAt: string | null;

  // Context accumulated during execution
  context: {
    workItem: WorkItem;
    branch: string;
    spec: string | null;
    pr: PullRequest | null;
    [key: string]: any;
  };

  // Error tracking
  errors: ExecutionError[];
  retryCount: number;
}

interface PhaseState {
  status: 'pending' | 'running' | 'completed' | 'failed' | 'skipped';
  steps: Record<string, StepState>;
  startedAt: string | null;
  completedAt: string | null;
}

interface StepState {
  status: 'pending' | 'running' | 'completed' | 'failed' | 'skipped';
  result: any | null;
  error: string | null;
  startedAt: string | null;
  completedAt: string | null;
  attempts: number;
}
```

### 6.3 Event Log

Events are append-only JSON files for audit trail:

```typescript
interface WorkflowEvent {
  eventId: number;
  type: EventType;
  timestamp: string;
  runId: string;
  phase?: string;
  step?: string;
  data: Record<string, any>;
}

type EventType =
  | 'workflow_start'
  | 'workflow_complete'
  | 'workflow_failed'
  | 'workflow_cancelled'
  | 'workflow_paused'
  | 'workflow_resumed'
  | 'phase_start'
  | 'phase_complete'
  | 'phase_failed'
  | 'step_start'
  | 'step_complete'
  | 'step_failed'
  | 'step_retry'
  | 'tool_call'
  | 'tool_result'
  | 'user_input'
  | 'checkpoint';
```

## 7. Ensemble Execution

### 7.1 Ensemble Strategies

#### Vote Strategy
Multiple models answer independently, majority wins.

```typescript
async function executeVote(
  step: Step,
  models: ModelConfig[],
  context: ExecutionContext
): Promise<LLMResponse> {
  const responses = await Promise.all(
    models.map(m => this.providers[m.provider].complete({
      model: m.model,
      messages: step.messages,
      tools: step.tools
    }))
  );

  // Extract decisions and vote
  const decisions = responses.map(r => extractDecision(r));
  return majorityVote(decisions);
}
```

#### Merge Strategy
Multiple models contribute, a synthesis model combines.

```typescript
async function executeMerge(
  step: Step,
  config: EnsembleConfig,
  context: ExecutionContext
): Promise<LLMResponse> {
  // Get responses from all models in parallel
  const responses = await Promise.all(
    config.models.map(m => this.providers[m.provider].complete({
      model: m.model,
      messages: step.messages,
      tools: step.tools
    }))
  );

  // Synthesize using designated model
  const synthesisPrompt = buildSynthesisPrompt(step, responses);
  const synthesisModel = config.synthesisModel || config.models[0];

  return this.providers[synthesisModel.provider].complete({
    model: synthesisModel.model,
    messages: [{ role: 'user', content: synthesisPrompt }]
  });
}
```

#### Best Strategy
Multiple models answer, quality evaluator selects best.

```typescript
async function executeBest(
  step: Step,
  config: EnsembleConfig,
  context: ExecutionContext
): Promise<LLMResponse> {
  const responses = await Promise.all(
    config.models.map(m => this.providers[m.provider].complete({
      model: m.model,
      messages: step.messages,
      tools: step.tools
    }))
  );

  // Evaluate each response
  const evaluator = config.synthesisModel || config.models[0];
  const evaluationPrompt = buildEvaluationPrompt(step, responses);

  const evaluation = await this.providers[evaluator.provider].complete({
    model: evaluator.model,
    messages: [{ role: 'user', content: evaluationPrompt }]
  });

  const bestIndex = extractBestIndex(evaluation);
  return responses[bestIndex];
}
```

## 8. Implementation Plan

### 8.1 Phase 1: Core Infrastructure (Week 1-2)

1. **Project Setup**
   - Add `src/tools/faber/orchestrator/` directory to fractary/cli
   - Set up TypeScript interfaces and types
   - Add dependencies (anthropic SDK, openai SDK)

2. **Provider Adapters**
   - Implement `AnthropicProvider`
   - Implement `OpenAIProvider`
   - Create unified `LLMProvider` interface

3. **Tool Executor**
   - Implement core tools: file_read, file_write, file_search
   - Implement git tools: git_status, git_diff, git_commit, git_branch
   - Implement github tools: github_issue, github_pr

4. **Configuration**
   - Implement config loader for `.fractary/faber/config.toml`
   - Implement workflow loader for JSON definitions
   - Add validation with helpful error messages

### 8.2 Phase 2: Workflow Engine (Week 3-4)

1. **State Management**
   - Implement state persistence
   - Implement event logging
   - Implement checkpoint/resume

2. **Workflow Engine Core**
   - Implement phase iteration
   - Implement step execution
   - Implement error handling and retry

3. **Model Router**
   - Implement step-based routing
   - Implement configuration-based selection

4. **CLI Commands**
   - Implement `fractary faber run`
   - Implement `fractary faber status`
   - Implement `fractary faber logs`

### 8.3 Phase 3: Advanced Features (Week 5-6)

1. **Ensemble Support**
   - Implement vote strategy
   - Implement merge strategy
   - Implement best strategy

2. **Additional Providers**
   - Implement Google Gemini provider
   - Implement Ollama provider (local)

3. **CLI Completion**
   - Implement `fractary faber plan`
   - Implement `fractary faber execute`
   - Implement `fractary faber cancel`
   - Implement `fractary faber config`

4. **Testing & Documentation**
   - Unit tests for core components
   - Integration tests for workflows
   - User documentation

### 8.4 Phase 4: Migration & Polish (Week 7-8)

1. **Migration from Claude Code Plugins**
   - Port workflow definitions
   - Port prompt templates
   - Validate parity with existing functionality

2. **Performance Optimization**
   - Implement response caching
   - Optimize token usage
   - Add cost tracking

3. **Production Hardening**
   - Error recovery improvements
   - Logging improvements
   - Monitoring hooks

## 9. Migration Path

### 9.1 What Carries Forward

| From Plugins | To Orchestrator |
|--------------|-----------------|
| Workflow definitions (JSON) | Workflow definitions (JSON) - same format |
| State tracking patterns | State management - enhanced |
| Event emission patterns | Event logging - deterministic |
| Prompt templates | Prompt templates - reusable |
| Tool schemas | Tool definitions - direct execution |

### 9.2 What Changes

| Plugins Approach | Orchestrator Approach |
|------------------|----------------------|
| Claude CLI subprocess | Direct API calls |
| LLM controls loop | Code controls loop |
| Permission prompts | Direct tool execution |
| Single model (Claude) | Multi-model routing |
| Claude Max pricing | Pay-per-token, optimized |

### 9.3 Backward Compatibility

The orchestrator will support the existing workflow JSON format from the plugins. Users can migrate by:

1. Installing the CLI: `npm install -g @fractary/cli`
2. Moving config: `.fractary/plugins/faber/` → `.fractary/faber/`
3. Adding model routing to config
4. Running: `fractary faber run --work-id 123`

## 10. Cost Considerations

### 10.1 Model Cost Comparison

| Model | Input (per 1M) | Output (per 1M) | Use Case |
|-------|----------------|-----------------|----------|
| Claude Haiku | $0.25 | $1.25 | Classification, simple tasks |
| Claude Sonnet | $3.00 | $15.00 | Implementation, balanced |
| Claude Opus | $15.00 | $75.00 | Architecture, complex reasoning |
| GPT-4o | $2.50 | $10.00 | Alternative perspective |
| GPT-4o-mini | $0.15 | $0.60 | Cheap alternative |

### 10.2 Optimization Strategies

1. **Model routing** - Use cheaper models for simple tasks
2. **Caching** - Cache repeated queries (e.g., file contents)
3. **Prompt optimization** - Minimize context size
4. **Early termination** - Stop when task is complete
5. **Batch operations** - Combine related tool calls

### 10.3 Cost Tracking

The orchestrator will track costs per run:

```typescript
interface CostTracking {
  runId: string;
  totalCost: number;
  byModel: Record<string, {
    inputTokens: number;
    outputTokens: number;
    cost: number;
  }>;
  byStep: Record<string, number>;
}
```

## 11. Security Considerations

### 11.1 Credential Management

- API keys stored in environment variables only
- Never logged or persisted to disk
- Provider adapters validate key presence at startup

### 11.2 Tool Sandboxing

- File operations restricted to project directory
- Shell commands allowlisted in configuration
- Git operations limited to current repository

### 11.3 Output Validation

- LLM outputs validated before tool execution
- Dangerous operations require explicit confirmation
- Audit trail of all operations

## 12. Success Metrics

### 12.1 Reliability

- **Step completion rate**: >99% of steps execute without infrastructure failure
- **Resume success rate**: >95% of interrupted runs resume successfully
- **State consistency**: 100% of state transitions are atomic

### 12.2 Performance

- **Overhead**: <5% time overhead vs direct API calls
- **Latency**: <500ms step transition time
- **Memory**: <200MB baseline memory usage

### 12.3 Cost Efficiency

- **Token optimization**: 20%+ reduction vs single-model approach
- **Model routing accuracy**: Appropriate model selected 95%+ of time

## 13. Open Questions

1. **Web UI**: Should there be a web interface for monitoring? (Defer to Phase 2)
2. **Distributed execution**: Support for parallel step execution? (Defer)
3. **Plugin system**: Allow custom tools and providers? (Consider for v2)
4. **Caching layer**: Shared cache across runs? (Evaluate need)

## 14. SDK Architecture

The Fractary ecosystem is organized into multiple SDK packages with clear separation of concerns. Each SDK is published to npm (TypeScript) and PyPI (Python) from a single monorepo per tool.

### 14.1 Repository Structure: Monorepo per Tool

Each tool has a single GitHub repository containing both TypeScript and Python implementations:

| GitHub Repository | npm Package | PyPI Package | Description |
|-------------------|-------------|--------------|-------------|
| `fractary/core` | `@fractary/core` | `fractary-core` | Foundation: types, utilities, LLM providers, integrations |
| `fractary/faber` | `@fractary/faber` | `fractary-faber` | Workflow orchestration engine |
| `fractary/codex` | `@fractary/codex` | `fractary-codex` | Knowledge and memory management |
| `fractary/helm` | `@fractary/helm` | `fractary-helm` | Monitoring and governance |
| `fractary/forge` | `@fractary/forge` | `fractary-forge` | Authoring and templating tools |
| `fractary/cli` | `@fractary/cli` | `fractary-cli` | Unified command-line interface |

### 14.2 Monorepo Directory Structure

Each repository follows a consistent structure with language implementations in subfolders:

```
fractary/core/
├── packages/
│   ├── ts/                    # TypeScript implementation
│   │   ├── src/
│   │   ├── package.json       # @fractary/core
│   │   ├── tsconfig.json
│   │   └── vitest.config.ts
│   │
│   └── py/                    # Python implementation (future)
│       ├── src/
│       │   └── fractary_core/
│       ├── pyproject.toml     # fractary-core
│       └── pytest.ini
│
├── specs/                     # Shared interface specifications
│   ├── providers.schema.json  # LLMProvider interface schema
│   ├── work.schema.json       # WorkItem, Issue schemas
│   ├── repo.schema.json       # Repository, PR schemas
│   └── file.schema.json       # FileStorage schemas
│
├── tests/
│   ├── conformance/           # Cross-language test cases
│   │   ├── providers/         # Provider conformance tests
│   │   ├── work/              # Work tracking conformance
│   │   └── repo/              # Repo operations conformance
│   └── fixtures/              # Shared test data
│
├── .github/
│   └── workflows/
│       ├── ts.yml             # TypeScript CI
│       ├── py.yml             # Python CI
│       └── conformance.yml    # Cross-language tests
│
├── CLAUDE.md
├── README.md
└── CHANGELOG.md
```

### 14.3 Design Benefits: Monorepo Approach

**Why monorepo per tool (not per language)?**

1. **Single PR for both languages** - Add a feature to TS and Py together
2. **Atomic versioning** - Release 1.2.0 for both implementations simultaneously
3. **Interface sync via specs/** - JSON schemas ensure both languages implement same contracts
4. **Conformance testing** - Same test cases validate both implementations
5. **Single issue tracker** - "Add Ollama provider" touches both in one issue
6. **Simpler naming** - `fractary/core` not `fractary/core-ts` + `fractary/core-py`

**Comparison to industry:**
- **Prisma**: TypeScript + Rust in same repo
- **Supabase**: Multiple SDK languages co-located
- Stripe/OpenAI use separate repos, but they have separate teams per language

### 14.4 Dependency Graph

```
@fractary/core          ← Foundation (types, utils, providers, integrations)
       ↑
@fractary/faber         ← Depends on core
@fractary/codex         ← Depends on core
@fractary/helm          ← Depends on core (observes faber)
@fractary/forge         ← Depends on core
       ↑
@fractary/cli           ← Depends on all SDKs
```

### 14.5 Design Decision: Unified Core

The `@fractary/core` package includes both foundational utilities AND integrations (LLM providers, work tracking, repo operations, file storage). This design:

- **Simplifies dependency management** - One package to install for all basics
- **Reduces version coordination** - Core moves as a unit
- **Easier onboarding** - "Just install core"
- **Can be split later** - If install size becomes an issue, extract `@fractary/integrations`

---

## 15. Package: @fractary/core

> **Repository**: `fractary/core`
> **npm**: `@fractary/core`
> **PyPI**: `fractary-core` (future)
> **Purpose**: Foundation package containing types, utilities, LLM providers, and platform integrations

### 15.1 Overview

The core package is the foundation of the Fractary ecosystem. It provides:
- Common types and utilities used across all packages
- Error classes and configuration loading
- LLM provider adapters (Anthropic, OpenAI, Google, Ollama)
- Platform integrations (GitHub, Jira, Linear, Git, S3, R2)
- Tool definitions and executor framework

### 15.2 Directory Structure

```
fractary/core/
├── ts/                            # TypeScript implementation
│   ├── src/
│   │   ├── types/
│   │   │   ├── common.ts          # Common types (Result, Maybe, etc.)
│   │   │   ├── config.ts          # Configuration types
│   │   │   ├── events.ts          # Event system types
│   │   │   ├── errors.ts          # Error types
│   │   │   └── index.ts           # Type exports
│   │   │
│   │   ├── config/
│   │   │   ├── loader.ts          # Config file loading (TOML, JSON)
│   │   │   ├── validator.ts       # Schema validation
│   │   │   ├── resolver.ts        # Environment variable resolution
│   │   │   └── index.ts
│   │   │
│   │   ├── errors/
│   │   │   ├── base.ts            # FractaryError base class
│   │   │   ├── config.ts          # ConfigurationError
│   │   │   ├── validation.ts      # ValidationError
│   │   │   ├── provider.ts        # ProviderError
│   │   │   └── index.ts
│   │   │
│   │   ├── utils/
│   │   │   ├── async.ts           # Async utilities (retry, timeout)
│   │   │   ├── fs.ts              # File system utilities
│   │   │   ├── json.ts            # JSON utilities
│   │   │   ├── logger.ts          # Logging interface
│   │   │   └── index.ts
│   │   │
│   │   ├── providers/
│   │   │   ├── types.ts           # LLMProvider interface
│   │   │   ├── anthropic.ts       # Anthropic Claude adapter
│   │   │   ├── openai.ts          # OpenAI GPT adapter
│   │   │   ├── google.ts          # Google Gemini adapter
│   │   │   ├── ollama.ts          # Ollama local adapter
│   │   │   ├── registry.ts        # Provider registry
│   │   │   └── index.ts
│   │   │
│   │   ├── work/
│   │   │   ├── types.ts           # WorkItem, Issue interfaces
│   │   │   ├── github.ts          # GitHub Issues adapter
│   │   │   ├── jira.ts            # Jira Cloud adapter
│   │   │   ├── linear.ts          # Linear adapter
│   │   │   ├── registry.ts        # Work provider registry
│   │   │   └── index.ts
│   │   │
│   │   ├── repo/
│   │   │   ├── types.ts           # Repository, Branch, PR interfaces
│   │   │   ├── git.ts             # Git CLI operations
│   │   │   ├── github.ts          # GitHub API adapter
│   │   │   ├── gitlab.ts          # GitLab API adapter
│   │   │   ├── bitbucket.ts       # Bitbucket API adapter
│   │   │   ├── registry.ts        # Repo provider registry
│   │   │   └── index.ts
│   │   │
│   │   ├── file/
│   │   │   ├── types.ts           # FileStorage interface
│   │   │   ├── local.ts           # Local filesystem
│   │   │   ├── s3.ts              # AWS S3
│   │   │   ├── r2.ts              # Cloudflare R2
│   │   │   └── index.ts
│   │   │
│   │   ├── tools/
│   │   │   ├── types.ts           # Tool, ToolCall, ToolResult interfaces
│   │   │   ├── file-tools.ts      # file_read, file_write, file_search
│   │   │   ├── git-tools.ts       # git_status, git_diff, git_commit
│   │   │   ├── github-tools.ts    # github_issue, github_pr
│   │   │   ├── shell-tools.ts     # shell_exec (sandboxed)
│   │   │   ├── executor.ts        # ToolExecutor implementation
│   │   │   └── index.ts
│   │   │
│   │   └── index.ts               # Public API
│   │
│   ├── package.json               # @fractary/core
│   ├── tsconfig.json
│   └── vitest.config.ts
│
├── py/                            # Python implementation (future)
│   ├── src/
│   │   └── fractary_core/
│   │       ├── __init__.py
│   │       ├── types/
│   │       ├── config/
│   │       ├── errors/
│   │       ├── providers/
│   │       ├── work/
│   │       ├── repo/
│   │       ├── file/
│   │       └── tools/
│   ├── pyproject.toml             # fractary-core
│   └── pytest.ini
│
├── specs/                         # Shared interface specifications
│   ├── providers.schema.json
│   ├── work.schema.json
│   ├── repo.schema.json
│   └── file.schema.json
│
├── tests/
│   ├── conformance/               # Cross-language test cases
│   └── fixtures/                  # Shared test data
│
├── CLAUDE.md
└── README.md
```

### 15.3 Core Types

```typescript
// types/common.ts

/** Result type for operations that can fail */
export type Result<T, E = Error> =
  | { success: true; value: T }
  | { success: false; error: E };

/** Optional value wrapper */
export type Maybe<T> = T | null | undefined;

/** Async result */
export type AsyncResult<T, E = Error> = Promise<Result<T, E>>;

/** Event emitter interface */
export interface EventEmitter<Events extends Record<string, any>> {
  on<K extends keyof Events>(event: K, handler: (data: Events[K]) => void): void;
  off<K extends keyof Events>(event: K, handler: (data: Events[K]) => void): void;
  emit<K extends keyof Events>(event: K, data: Events[K]): void;
}

/** Logger interface */
export interface Logger {
  debug(message: string, meta?: Record<string, any>): void;
  info(message: string, meta?: Record<string, any>): void;
  warn(message: string, meta?: Record<string, any>): void;
  error(message: string, meta?: Record<string, any>): void;
}
```

```typescript
// types/config.ts

/** Base configuration interface */
export interface FractaryConfig {
  version: string;
  [key: string]: unknown;
}

/** Environment variable reference */
export interface EnvRef {
  env: string;
  default?: string;
}

/** Configuration source */
export type ConfigSource = 'file' | 'env' | 'default' | 'override';
```

### 15.4 Error Classes

```typescript
// errors/base.ts

export class FractaryError extends Error {
  readonly code: string;
  readonly context?: Record<string, any>;

  constructor(message: string, code: string, context?: Record<string, any>) {
    super(message);
    this.name = 'FractaryError';
    this.code = code;
    this.context = context;
  }
}

// errors/config.ts
export class ConfigurationError extends FractaryError {
  constructor(message: string, context?: Record<string, any>) {
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

  constructor(message: string, provider: string, context?: Record<string, any>) {
    super(message, 'PROVIDER_ERROR', { ...context, provider });
    this.name = 'ProviderError';
    this.provider = provider;
  }
}
```

### 15.5 LLM Provider Interface

```typescript
// providers/types.ts

export interface LLMProvider {
  readonly name: string;
  readonly supportedModels: string[];

  /** Send a completion request */
  complete(request: CompletionRequest): Promise<CompletionResponse>;

  /** Stream a completion request */
  stream(request: CompletionRequest): AsyncIterable<StreamChunk>;

  /** Count tokens for a message (estimate) */
  countTokens(messages: Message[]): Promise<number>;
}

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
  toolInput?: Record<string, any>;
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
```

### 15.6 Anthropic Provider Implementation

```typescript
// providers/anthropic.ts

import Anthropic from '@anthropic-ai/sdk';
import { LLMProvider, CompletionRequest, CompletionResponse } from './types';

export class AnthropicProvider implements LLMProvider {
  readonly name = 'anthropic';
  readonly supportedModels = [
    'claude-opus-4-20250514',
    'claude-sonnet-4-20250514',
    'claude-3-5-haiku-20241022',
  ];

  private client: Anthropic;

  constructor(apiKey: string, options?: { baseUrl?: string }) {
    this.client = new Anthropic({
      apiKey,
      baseURL: options?.baseUrl,
    });
  }

  async complete(request: CompletionRequest): Promise<CompletionResponse> {
    const response = await this.client.messages.create({
      model: request.model,
      max_tokens: request.maxTokens ?? 4096,
      temperature: request.temperature,
      system: request.systemPrompt,
      messages: this.convertMessages(request.messages),
      tools: request.tools?.map(this.convertTool),
      stop_sequences: request.stopSequences,
    });

    return this.convertResponse(response);
  }

  async *stream(request: CompletionRequest): AsyncIterable<StreamChunk> {
    const stream = await this.client.messages.stream({
      model: request.model,
      max_tokens: request.maxTokens ?? 4096,
      temperature: request.temperature,
      system: request.systemPrompt,
      messages: this.convertMessages(request.messages),
      tools: request.tools?.map(this.convertTool),
    });

    for await (const event of stream) {
      yield this.convertStreamEvent(event);
    }
  }

  // ... conversion methods
}
```

### 15.7 Work Tracking Interface

```typescript
// work/types.ts

export interface WorkProvider {
  readonly name: string;

  /** Fetch a work item by ID */
  getWorkItem(id: string): Promise<WorkItem>;

  /** Search work items */
  searchWorkItems(query: WorkItemQuery): Promise<WorkItem[]>;

  /** Create a work item */
  createWorkItem(item: CreateWorkItemInput): Promise<WorkItem>;

  /** Update a work item */
  updateWorkItem(id: string, updates: UpdateWorkItemInput): Promise<WorkItem>;

  /** Add a comment */
  addComment(workItemId: string, comment: string): Promise<Comment>;
}

export interface WorkItem {
  id: string;
  key: string;          // e.g., "PROJ-123" or "#123"
  title: string;
  description: string;
  status: string;
  type: 'feature' | 'bug' | 'chore' | 'task' | 'story' | 'epic';
  labels: string[];
  assignee?: string;
  reporter?: string;
  createdAt: Date;
  updatedAt: Date;
  url: string;
}
```

### 15.8 Repository Operations Interface

```typescript
// repo/types.ts

export interface RepoProvider {
  readonly name: string;

  /** Get current branch */
  getCurrentBranch(): Promise<string>;

  /** Create a branch */
  createBranch(name: string, baseBranch?: string): Promise<Branch>;

  /** Create a commit */
  commit(message: string, options?: CommitOptions): Promise<Commit>;

  /** Push to remote */
  push(branch: string, options?: PushOptions): Promise<void>;

  /** Create a pull request */
  createPullRequest(input: CreatePRInput): Promise<PullRequest>;

  /** Get pull request */
  getPullRequest(number: number): Promise<PullRequest>;

  /** Merge pull request */
  mergePullRequest(number: number, options?: MergeOptions): Promise<void>;
}

export interface PullRequest {
  number: number;
  title: string;
  body: string;
  state: 'open' | 'closed' | 'merged';
  headBranch: string;
  baseBranch: string;
  url: string;
  createdAt: Date;
  mergedAt?: Date;
}

export interface Commit {
  sha: string;
  message: string;
  author: string;
  date: Date;
}
```

### 15.9 Tool Executor

```typescript
// tools/executor.ts

import { ToolCall, ToolResult, ToolDefinition } from './types';
import { fileTools } from './file-tools';
import { gitTools } from './git-tools';
import { githubTools } from './github-tools';
import { shellTools } from './shell-tools';

export interface ToolExecutorConfig {
  workingDirectory: string;
  allowedShellCommands?: string[];
  githubToken?: string;
  sandbox?: boolean;
}

export class ToolExecutor {
  private tools: Map<string, ToolHandler>;
  private config: ToolExecutorConfig;

  constructor(config: ToolExecutorConfig) {
    this.config = config;
    this.tools = new Map();

    // Register built-in tools
    this.registerTools(fileTools(config));
    this.registerTools(gitTools(config));
    if (config.githubToken) {
      this.registerTools(githubTools(config.githubToken));
    }
    this.registerTools(shellTools(config));
  }

  async execute(toolCall: ToolCall): Promise<ToolResult> {
    const handler = this.tools.get(toolCall.name);
    if (!handler) {
      return {
        toolUseId: toolCall.id,
        content: `Unknown tool: ${toolCall.name}`,
        isError: true,
      };
    }

    try {
      const result = await handler.execute(toolCall.input);
      return {
        toolUseId: toolCall.id,
        content: result,
        isError: false,
      };
    } catch (error) {
      return {
        toolUseId: toolCall.id,
        content: error instanceof Error ? error.message : String(error),
        isError: true,
      };
    }
  }

  getAvailableTools(): ToolDefinition[] {
    return Array.from(this.tools.values()).map(h => h.definition);
  }
}
```

### 15.10 Dependencies

```json
{
  "name": "@fractary/core",
  "version": "1.0.0",
  "description": "Foundation package for Fractary ecosystem",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "exports": {
    ".": "./dist/index.js",
    "./providers": "./dist/providers/index.js",
    "./work": "./dist/work/index.js",
    "./repo": "./dist/repo/index.js",
    "./file": "./dist/file/index.js",
    "./tools": "./dist/tools/index.js"
  },
  "dependencies": {
    "toml": "^3.0.0",
    "ajv": "^8.12.0",
    "@anthropic-ai/sdk": "^0.30.0",
    "openai": "^4.70.0",
    "@google/generative-ai": "^0.21.0",
    "simple-git": "^3.22.0",
    "octokit": "^4.0.0",
    "glob": "^10.3.0"
  },
  "devDependencies": {
    "typescript": "^5.3.0",
    "vitest": "^1.0.0"
  }
}
```

---

## 16. Package: @fractary/faber

> **Repository**: `fractary/faber`
> **npm**: `@fractary/faber`
> **PyPI**: `fractary-faber` (future)
> **Purpose**: Deterministic workflow orchestration engine for AI-assisted development

### 16.1 Overview

The faber package is the core workflow orchestration engine. It provides deterministic workflow execution, model routing, ensemble support, and state management. This is the main package that implements the FABER workflow (Frame → Architect → Build → Evaluate → Release).

### 16.2 Directory Structure

```
fractary/faber/
├── ts/                               # TypeScript implementation
│   ├── src/
│   │   ├── engine/
│   │   │   ├── types.ts              # WorkflowEngine interface
│   │   │   ├── engine.ts             # WorkflowEngine implementation
│   │   │   ├── executor.ts           # Step executor (LLM + tool loop)
│   │   │   ├── planner.ts            # Execution plan creation
│   │   │   └── index.ts
│   │   │
│   │   ├── router/
│   │   │   ├── types.ts              # ModelRouter interface
│   │   │   ├── router.ts             # Step-to-model routing
│   │   │   ├── ensemble.ts           # Ensemble execution strategies
│   │   │   └── index.ts
│   │   │
│   │   ├── state/
│   │   │   ├── types.ts              # State interfaces
│   │   │   ├── store.ts              # State persistence
│   │   │   ├── events.ts             # Event logging
│   │   │   └── index.ts
│   │   │
│   │   ├── workflow/
│   │   │   ├── types.ts              # Workflow, Phase, Step interfaces
│   │   │   ├── loader.ts             # Workflow definition loader
│   │   │   ├── validator.ts          # Workflow validation
│   │   │   └── index.ts
│   │   │
│   │   ├── prompts/
│   │   │   ├── types.ts              # Prompt template interface
│   │   │   ├── loader.ts             # Template loading
│   │   │   ├── renderer.ts           # Variable substitution
│   │   │   ├── templates/            # Built-in templates
│   │   │   │   ├── classify_work.md
│   │   │   │   ├── generate_spec.md
│   │   │   │   ├── implement.md
│   │   │   │   └── code_review.md
│   │   │   └── index.ts
│   │   │
│   │   ├── config/
│   │   │   ├── types.ts              # FaberConfig interface
│   │   │   ├── loader.ts             # Config loading
│   │   │   ├── schema.ts             # Config schema
│   │   │   └── index.ts
│   │   │
│   │   └── index.ts                  # Public API
│   │
│   ├── package.json                  # @fractary/faber
│   ├── tsconfig.json
│   └── vitest.config.ts
│
├── py/                               # Python implementation (future)
│   ├── src/fractary_faber/
│   ├── pyproject.toml                # fractary-faber
│   └── pytest.ini
│
├── specs/                            # Shared interface specifications
├── tests/conformance/
├── CLAUDE.md
└── README.md
```

### 16.3 Workflow Engine Interface

```typescript
// engine/types.ts

import { EventEmitter } from '@fractary/core';

export interface WorkflowEngine {
  /** Execute a complete workflow */
  execute(plan: ExecutionPlan, options?: ExecutionOptions): Promise<ExecutionResult>;

  /** Execute a single step */
  executeStep(step: Step, context: ExecutionContext): Promise<StepResult>;

  /** Pause a running workflow */
  pause(runId: string): Promise<void>;

  /** Resume a paused workflow */
  resume(runId: string, options?: ResumeOptions): Promise<ExecutionResult>;

  /** Cancel a running workflow */
  cancel(runId: string, reason?: string): Promise<void>;

  /** Get workflow status */
  getStatus(runId: string): Promise<RunStatus>;

  /** Get execution logs */
  getLogs(runId: string, options?: LogOptions): AsyncIterable<LogEntry>;

  /** Subscribe to events */
  on: EventEmitter<WorkflowEvents>['on'];
}

export interface ExecutionPlan {
  id: string;
  workId: string;
  workflow: WorkflowDefinition;
  context: WorkflowContext;
  createdAt: Date;
}

export interface ExecutionOptions {
  autonomy?: 'autonomous' | 'guarded' | 'assisted';
  dryRun?: boolean;
  fromStep?: string;
  phases?: string[];
  verbose?: boolean;
  onApprovalRequired?: (step: Step) => Promise<boolean>;
}

export interface ExecutionResult {
  runId: string;
  planId: string;
  workId: string;
  status: 'completed' | 'failed' | 'cancelled' | 'paused';
  phases: PhaseResult[];
  duration: number;
  cost: CostSummary;
  error?: Error;
  artifacts: Record<string, any>;
}

export interface WorkflowEvents {
  workflow_start: { runId: string; planId: string };
  workflow_complete: { runId: string; result: ExecutionResult };
  workflow_failed: { runId: string; error: Error };
  workflow_paused: { runId: string; step: string };
  phase_start: { runId: string; phase: string };
  phase_complete: { runId: string; phase: string };
  step_start: { runId: string; phase: string; step: string };
  step_complete: { runId: string; phase: string; step: string; result: StepResult };
  step_failed: { runId: string; phase: string; step: string; error: Error };
  tool_call: { runId: string; step: string; tool: string; input: any };
  tool_result: { runId: string; step: string; tool: string; result: any };
}
```

### 16.4 Workflow Engine Implementation

```typescript
// engine/engine.ts

import { LLMProvider, ToolExecutor, Logger } from '@fractary/core';
import { WorkflowEngine, ExecutionPlan, ExecutionOptions, ExecutionResult } from './types';
import { ModelRouter } from '../router';
import { StateStore } from '../state';
import { StepExecutor } from './executor';

export class FaberEngine implements WorkflowEngine {
  private router: ModelRouter;
  private stateStore: StateStore;
  private stepExecutor: StepExecutor;
  private toolExecutor: ToolExecutor;
  private logger: Logger;
  private eventHandlers: Map<string, Set<Function>>;

  constructor(config: FaberEngineConfig) {
    this.router = new ModelRouter(config.modelRouting, config.providers);
    this.stateStore = new StateStore(config.stateDir);
    this.toolExecutor = new ToolExecutor(config.tools);
    this.stepExecutor = new StepExecutor(this.router, this.toolExecutor);
    this.logger = config.logger;
    this.eventHandlers = new Map();
  }

  async execute(plan: ExecutionPlan, options: ExecutionOptions = {}): Promise<ExecutionResult> {
    const runId = this.generateRunId();
    const state = await this.stateStore.initialize(runId, plan);

    this.emit('workflow_start', { runId, planId: plan.id });

    try {
      for (const phase of this.getPhases(plan, options)) {
        await this.executePhase(runId, phase, state, options);
      }

      const result = this.buildResult(runId, state, 'completed');
      this.emit('workflow_complete', { runId, result });
      return result;

    } catch (error) {
      await this.stateStore.markFailed(runId, error as Error);
      this.emit('workflow_failed', { runId, error: error as Error });
      throw error;
    }
  }

  private async executePhase(
    runId: string,
    phase: Phase,
    state: ExecutionState,
    options: ExecutionOptions
  ): Promise<void> {
    this.emit('phase_start', { runId, phase: phase.id });
    await this.stateStore.startPhase(runId, phase.id);

    for (const step of phase.steps) {
      // Check if approval required (guarded/assisted mode)
      if (this.requiresApproval(step, options)) {
        const approved = await options.onApprovalRequired?.(step);
        if (!approved) {
          await this.pause(runId);
          return;
        }
      }

      await this.executeStepWithRetry(runId, phase, step, state, options);
    }

    await this.stateStore.completePhase(runId, phase.id);
    this.emit('phase_complete', { runId, phase: phase.id });
  }

  private async executeStepWithRetry(
    runId: string,
    phase: Phase,
    step: Step,
    state: ExecutionState,
    options: ExecutionOptions
  ): Promise<void> {
    const maxRetries = phase.maxRetries ?? 0;
    let lastError: Error | null = null;

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        this.emit('step_start', { runId, phase: phase.id, step: step.id });
        await this.stateStore.startStep(runId, step.id);

        const context = this.buildContext(state, step);
        const result = await this.stepExecutor.execute(step, context, {
          onToolCall: (tool, input) => {
            this.emit('tool_call', { runId, step: step.id, tool, input });
          },
          onToolResult: (tool, result) => {
            this.emit('tool_result', { runId, step: step.id, tool, result });
          },
        });

        await this.stateStore.completeStep(runId, step.id, result);
        this.emit('step_complete', { runId, phase: phase.id, step: step.id, result });
        return;

      } catch (error) {
        lastError = error as Error;
        this.logger.warn(`Step ${step.id} failed (attempt ${attempt + 1}/${maxRetries + 1})`, {
          error: lastError.message,
        });

        if (attempt < maxRetries) {
          await this.stateStore.recordRetry(runId, step.id, lastError);
        }
      }
    }

    await this.stateStore.failStep(runId, step.id, lastError!);
    this.emit('step_failed', { runId, phase: phase.id, step: step.id, error: lastError! });
    throw lastError;
  }

  // ... other methods
}
```

### 16.5 Model Router

```typescript
// router/router.ts

import { LLMProvider, CompletionRequest, CompletionResponse } from '@fractary/core';
import { ModelConfig, EnsembleConfig, ModelRoutingConfig } from './types';
import { EnsembleExecutor } from './ensemble';

export class ModelRouter {
  private providers: Map<string, LLMProvider>;
  private config: ModelRoutingConfig;
  private ensemble: EnsembleExecutor;

  constructor(config: ModelRoutingConfig, providers: Map<string, LLMProvider>) {
    this.config = config;
    this.providers = providers;
    this.ensemble = new EnsembleExecutor(providers);
  }

  getModelConfig(step: Step): ModelConfig | EnsembleConfig {
    // Check step-specific routing first
    const stepRouting = this.config.steps?.[step.id];
    if (stepRouting) return stepRouting;

    // Check step type routing
    const typeRouting = this.config.steps?.[step.type];
    if (typeRouting) return typeRouting;

    // Fall back to default
    return this.config.default;
  }

  async execute(step: Step, request: CompletionRequest): Promise<CompletionResponse> {
    const routing = this.getModelConfig(step);

    if ('strategy' in routing && routing.strategy === 'ensemble') {
      return this.ensemble.execute(request, routing);
    }

    const provider = this.providers.get(routing.provider);
    if (!provider) {
      throw new Error(`Unknown provider: ${routing.provider}`);
    }

    return provider.complete({
      ...request,
      model: routing.model,
      temperature: routing.temperature ?? request.temperature,
      maxTokens: routing.maxTokens ?? request.maxTokens,
    });
  }
}
```

### 16.6 Dependencies

```json
{
  "name": "@fractary/faber",
  "version": "1.0.0",
  "dependencies": {
    "@fractary/core": "^1.0.0"
  }
}
```

---

## 17. Package: @fractary/codex

> **Repository**: `fractary/codex`
> **npm**: `@fractary/codex`
> **PyPI**: `fractary-codex` (future)
> **Purpose**: Knowledge and memory management for AI-assisted development

### 17.1 Overview

The codex package provides knowledge management, documentation sync, and memory capabilities. It enables sharing knowledge across projects and maintaining context for AI assistants.

### 17.2 Directory Structure

```
fractary/codex/
├── ts/                               # TypeScript implementation
│   ├── src/
│   │   ├── metadata/
│   │   │   ├── types.ts              # Frontmatter types
│   │   │   ├── parser.ts             # YAML frontmatter parsing
│   │   │   ├── validator.ts          # Schema validation
│   │   │   └── index.ts
│   │   │
│   │   ├── sync/
│   │   │   ├── types.ts              # Sync configuration types
│   │   │   ├── router.ts             # File → repo routing
│   │   │   ├── differ.ts             # Change detection
│   │   │   ├── syncer.ts             # Sync execution
│   │   │   └── index.ts
│   │   │
│   │   ├── memory/
│   │   │   ├── types.ts              # Memory store types
│   │   │   ├── store.ts              # Memory persistence
│   │   │   ├── retriever.ts          # Semantic retrieval
│   │   │   └── index.ts
│   │   │
│   │   ├── config/
│   │   │   ├── types.ts              # CodexConfig interface
│   │   │   ├── loader.ts             # Config loading
│   │   │   └── index.ts
│   │   │
│   │   └── index.ts
│   │
│   ├── package.json                  # @fractary/codex
│   ├── tsconfig.json
│   └── vitest.config.ts
│
├── py/                               # Python implementation (future)
│   ├── src/fractary_codex/
│   ├── pyproject.toml                # fractary-codex
│   └── pytest.ini
│
├── specs/
├── tests/conformance/
├── CLAUDE.md
└── README.md
```

### 17.3 Core Interfaces

```typescript
// metadata/types.ts

export interface DocumentMetadata {
  title: string;
  description?: string;
  system?: string;
  visibility?: 'public' | 'internal' | 'private';
  tags?: string[];
  sync?: SyncConfig;
  [key: string]: unknown;
}

export interface SyncConfig {
  to?: string[];
  exclude?: string[];
  strategy?: 'mirror' | 'merge' | 'manual';
}

// sync/types.ts

export interface SyncResult {
  source: string;
  destinations: SyncDestination[];
  status: 'synced' | 'skipped' | 'error';
  changes: FileChange[];
}

export interface FileChange {
  path: string;
  type: 'added' | 'modified' | 'deleted';
  diff?: string;
}
```

### 17.4 Dependencies

```json
{
  "name": "@fractary/codex",
  "version": "1.0.0",
  "dependencies": {
    "@fractary/core": "^1.0.0",
    "gray-matter": "^4.0.3"
  }
}
```

---

## 18. Package: @fractary/helm

> **Repository**: `fractary/helm`
> **npm**: `@fractary/helm`
> **PyPI**: `fractary-helm` (future)
> **Purpose**: Monitoring, metrics, and governance for AI workflows

### 18.1 Overview

The helm package provides monitoring, cost tracking, performance metrics, and governance policies for AI workflow execution. It observes faber executions and provides insights.

### 18.2 Directory Structure

```
fractary/helm/
├── ts/                               # TypeScript implementation
│   ├── src/
│   │   ├── monitor/
│   │   │   ├── types.ts              # Monitor interfaces
│   │   │   ├── observer.ts           # Workflow observer
│   │   │   ├── collector.ts          # Metrics collection
│   │   │   └── index.ts
│   │   │
│   │   ├── metrics/
│   │   │   ├── types.ts              # Metric types
│   │   │   ├── cost.ts               # Cost tracking
│   │   │   ├── performance.ts        # Latency, throughput
│   │   │   ├── quality.ts            # Success rates, retries
│   │   │   └── index.ts
│   │   │
│   │   ├── governance/
│   │   │   ├── types.ts              # Policy types
│   │   │   ├── policies.ts           # Built-in policies
│   │   │   ├── enforcer.ts           # Policy enforcement
│   │   │   └── index.ts
│   │   │
│   │   ├── reports/
│   │   │   ├── types.ts              # Report types
│   │   │   ├── generator.ts          # Report generation
│   │   │   └── index.ts
│   │   │
│   │   └── index.ts
│   │
│   ├── package.json                  # @fractary/helm
│   ├── tsconfig.json
│   └── vitest.config.ts
│
├── py/                               # Python implementation (future)
│   ├── src/fractary_helm/
│   ├── pyproject.toml                # fractary-helm
│   └── pytest.ini
│
├── specs/
├── tests/conformance/
├── CLAUDE.md
└── README.md
```

### 18.3 Core Interfaces

```typescript
// monitor/types.ts

export interface WorkflowMonitor {
  /** Attach to a workflow engine */
  attach(engine: WorkflowEngine): void;

  /** Get metrics for a run */
  getMetrics(runId: string): Promise<RunMetrics>;

  /** Get aggregated metrics */
  getAggregateMetrics(options: MetricsQuery): Promise<AggregateMetrics>;

  /** Generate report */
  generateReport(options: ReportOptions): Promise<Report>;
}

// metrics/types.ts

export interface RunMetrics {
  runId: string;
  duration: number;
  cost: CostBreakdown;
  tokenUsage: TokenBreakdown;
  stepMetrics: StepMetrics[];
  modelUsage: ModelUsage[];
}

export interface CostBreakdown {
  total: number;
  byModel: Record<string, number>;
  byStep: Record<string, number>;
  byPhase: Record<string, number>;
}

// governance/types.ts

export interface GovernancePolicy {
  id: string;
  name: string;
  description: string;
  check(context: PolicyContext): PolicyResult;
}

export interface PolicyResult {
  passed: boolean;
  violations: Violation[];
  warnings: Warning[];
}
```

### 18.4 Dependencies

```json
{
  "name": "@fractary/helm",
  "version": "1.0.0",
  "dependencies": {
    "@fractary/core": "^1.0.0"
  }
}
```

---

## 19. Package: @fractary/forge

> **Repository**: `fractary/forge`
> **npm**: `@fractary/forge`
> **PyPI**: `fractary-forge` (future)
> **Purpose**: Authoring and templating tools for AI agents and workflows

### 19.1 Overview

The forge package provides tools for authoring AI agent definitions, workflow templates, and transforming them for different platforms (Claude Code, LangChain, etc.).

### 19.2 Directory Structure

```
fractary/forge/
├── ts/                               # TypeScript implementation
│   ├── src/
│   │   ├── concepts/
│   │   │   ├── types.ts              # Role, Tool, Eval, Team, Workflow
│   │   │   ├── loaders/              # Concept loaders
│   │   │   │   ├── role.ts
│   │   │   │   ├── tool.ts
│   │   │   │   ├── eval.ts
│   │   │   │   ├── team.ts
│   │   │   │   └── workflow.ts
│   │   │   └── index.ts
│   │   │
│   │   ├── bindings/
│   │   │   ├── types.ts              # Binding interface
│   │   │   ├── claude-code.ts        # Claude Code transformer
│   │   │   ├── langgraph.ts          # LangGraph transformer
│   │   │   └── index.ts
│   │   │
│   │   ├── overlays/
│   │   │   ├── types.ts              # Overlay types
│   │   │   ├── resolver.ts           # Overlay resolution
│   │   │   ├── merger.ts             # Deep merge logic
│   │   │   └── index.ts
│   │   │
│   │   ├── templates/
│   │   │   ├── types.ts              # Template types
│   │   │   ├── engine.ts             # Template rendering
│   │   │   └── index.ts
│   │   │
│   │   └── index.ts
│   │
│   ├── package.json                  # @fractary/forge
│   ├── tsconfig.json
│   └── vitest.config.ts
│
├── py/                               # Python implementation (future)
│   ├── src/fractary_forge/
│   ├── pyproject.toml                # fractary-forge
│   └── pytest.ini
│
├── specs/
├── tests/conformance/
├── CLAUDE.md
└── README.md
```

### 19.3 Dependencies

```json
{
  "name": "@fractary/forge",
  "version": "1.0.0",
  "dependencies": {
    "@fractary/core": "^1.0.0",
    "js-yaml": "^4.1.0",
    "handlebars": "^4.7.0"
  }
}
```

---

## 20. Package: @fractary/cli

> **Repository**: `fractary/cli`
> **npm**: `@fractary/cli`
> **PyPI**: `fractary-cli` (future)
> **Purpose**: Unified command-line interface for all Fractary tools

### 20.1 Overview

The CLI package provides the user-facing command-line interface. It's a thin layer over the SDK packages, handling argument parsing, output formatting, and user interaction.

### 20.2 Directory Structure

```
fractary/cli/
├── ts/                               # TypeScript implementation
│   ├── src/
│   │   ├── cli.ts                    # Main entry point
│   │   │
│   │   ├── tools/
│   │   │   ├── faber/
│   │   │   │   ├── index.ts          # Faber command group
│   │   │   │   └── commands/
│   │   │   │       ├── run.ts
│   │   │   │       ├── plan.ts
│   │   │   │       ├── execute.ts
│   │   │   │       ├── status.ts
│   │   │   │       ├── logs.ts
│   │   │   │       ├── cancel.ts
│   │   │   │       └── config.ts
│   │   │   │
│   │   │   ├── codex/
│   │   │   │   ├── index.ts
│   │   │   │   └── commands/
│   │   │   │       ├── init.ts
│   │   │   │       ├── validate.ts
│   │   │   │       ├── sync.ts
│   │   │   │       └── config.ts
│   │   │   │
│   │   │   ├── helm/
│   │   │   │   ├── index.ts
│   │   │   │   └── commands/
│   │   │   │       ├── status.ts
│   │   │   │       ├── metrics.ts
│   │   │   │       └── report.ts
│   │   │   │
│   │   │   └── forge/
│   │   │       ├── index.ts
│   │   │       └── commands/
│   │   │           ├── init.ts
│   │   │           ├── create.ts
│   │   │           ├── build.ts
│   │   │           └── validate.ts
│   │   │
│   │   ├── utils/
│   │   │   ├── output.ts             # Chalk formatting
│   │   │   ├── prompts.ts            # User prompts
│   │   │   ├── progress.ts           # Progress indicators
│   │   │   └── config.ts             # CLI config loading
│   │   │
│   │   └── index.ts
│   │
│   ├── bin/
│   │   └── fractary                  # CLI entry script
│   │
│   ├── package.json                  # @fractary/cli
│   ├── tsconfig.json
│   └── vitest.config.ts
│
├── py/                               # Python implementation (future)
│   ├── src/fractary_cli/
│   │   └── __main__.py
│   ├── pyproject.toml                # fractary-cli
│   └── pytest.ini
│
├── CLAUDE.md
└── README.md
```

### 20.3 CLI Entry Point

```typescript
// src/cli.ts

import { Command } from 'commander';
import { createFaberCommand } from './tools/faber';
import { createCodexCommand } from './tools/codex';
import { createHelmCommand } from './tools/helm';
import { createForgeCommand } from './tools/forge';

const program = new Command();

program
  .name('fractary')
  .description('Unified CLI for Fractary tools')
  .version('1.0.0');

program.addCommand(createFaberCommand());
program.addCommand(createCodexCommand());
program.addCommand(createHelmCommand());
program.addCommand(createForgeCommand());

program.parse();
```

### 20.4 Example Command Implementation

```typescript
// src/tools/faber/commands/run.ts

import { Command } from 'commander';
import chalk from 'chalk';
import { FaberEngine, loadConfig, createPlan } from '@fractary/faber';
import { createProviders } from '@fractary/core';

export function runCommand(): Command {
  return new Command('run')
    .description('Execute a FABER workflow for a work item')
    .requiredOption('--work-id <id>', 'Work item ID')
    .option('--workflow <id>', 'Workflow to use', 'default')
    .option('--autonomy <level>', 'Autonomy level', 'guarded')
    .option('--phase <phases>', 'Phases to run (comma-separated)')
    .option('--dry-run', 'Show what would be executed')
    .option('--verbose', 'Enable verbose output')
    .option('--json', 'Output as JSON')
    .action(async (options) => {
      try {
        const config = await loadConfig('.fractary/faber/config.toml');
        const providers = createProviders(config.providers);
        const engine = new FaberEngine({ ...config, providers });

        // Set up event handlers for progress display
        if (!options.json) {
          engine.on('phase_start', ({ phase }) => {
            console.log(chalk.cyan(`\n▶ Phase: ${phase}`));
          });
          engine.on('step_start', ({ step }) => {
            console.log(chalk.gray(`  → ${step}`));
          });
          engine.on('step_complete', ({ step }) => {
            console.log(chalk.green(`  ✓ ${step}`));
          });
          engine.on('step_failed', ({ step, error }) => {
            console.log(chalk.red(`  ✗ ${step}: ${error.message}`));
          });
        }

        const plan = await createPlan({
          workId: options.workId,
          workflow: options.workflow,
        });

        const result = await engine.execute(plan, {
          autonomy: options.autonomy,
          dryRun: options.dryRun,
          phases: options.phase?.split(','),
          verbose: options.verbose,
          onApprovalRequired: async (step) => {
            // Interactive approval prompt
            return promptForApproval(step);
          },
        });

        if (options.json) {
          console.log(JSON.stringify(result, null, 2));
        } else {
          console.log(chalk.green(`\n✓ Workflow ${result.status}`));
          console.log(chalk.gray(`  Duration: ${result.duration}ms`));
          console.log(chalk.gray(`  Cost: $${result.cost.total.toFixed(4)}`));
        }

      } catch (error: any) {
        if (options.json) {
          console.log(JSON.stringify({ error: error.message }, null, 2));
        } else {
          console.error(chalk.red('Error:'), error.message);
        }
        process.exit(1);
      }
    });
}
```

### 20.5 Dependencies

```json
{
  "name": "@fractary/cli",
  "version": "1.0.0",
  "bin": {
    "fractary": "./bin/fractary"
  },
  "dependencies": {
    "@fractary/core": "^1.0.0",
    "@fractary/faber": "^1.0.0",
    "@fractary/codex": "^1.0.0",
    "@fractary/helm": "^1.0.0",
    "@fractary/forge": "^1.0.0",
    "commander": "^11.1.0",
    "chalk": "^5.3.0",
    "ora": "^8.0.0",
    "inquirer": "^9.2.0"
  }
}
```

---

## 21. Implementation Roadmap (Updated)

### Phase 1: Core Foundation (Week 1-2)
1. Create `fractary/core-ts` repository
   - Types, utilities, error classes
   - Config loading and validation
   - LLM provider adapters (Anthropic, OpenAI)
   - Work tracking integrations (GitHub, Jira)
   - Repo operations (Git, GitHub API)
   - Tool executor framework

### Phase 2: Faber SDK (Week 3-4)
1. Create `fractary/faber-ts` repository
   - Workflow engine
   - Model router
   - State management
   - Prompt templates

### Phase 3: CLI Integration (Week 5-6)
1. Update `fractary/cli` repository
   - Wire faber commands to SDK
   - Add progress display
   - Add interactive prompts

### Phase 4: Advanced Features (Week 7-8)
1. Ensemble support in faber
2. Additional providers (Google, Ollama)
3. Helm monitoring integration
4. Documentation and testing

### Phase 5: Additional SDKs (Week 9+)
1. Update `fractary/codex-ts` to new patterns
2. Create `fractary/helm-ts`
3. Update `fractary/forge-ts`
4. Python SDKs (future)

---

## 22. References

- [SPEC-00002: FABER Architecture](./SPEC-00002-faber-architecture.md)
- [Anthropic API Documentation](https://docs.anthropic.com/en/api)
- [OpenAI API Documentation](https://platform.openai.com/docs/api-reference)
- [Commander.js Documentation](https://github.com/tj/commander.js)
- [fractary/cli Repository](https://github.com/fractary/cli)
