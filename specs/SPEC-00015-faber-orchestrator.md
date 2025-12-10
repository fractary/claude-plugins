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

## 14. References

- [SPEC-00002: FABER Architecture](./SPEC-00002-faber-architecture.md)
- [Anthropic API Documentation](https://docs.anthropic.com/en/api)
- [OpenAI API Documentation](https://platform.openai.com/docs/api-reference)
- [Commander.js Documentation](https://github.com/tj/commander.js)
- [fractary/cli Repository](https://github.com/fractary/cli)
