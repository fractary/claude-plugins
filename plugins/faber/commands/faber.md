---
name: faber
description: FABER main entry point - intelligent router for init, run, status, and freeform requests
argument-hint: 'init | run <id> [...] | status [...] | help | "<question>"'
tools: Bash, SlashCommand, Read, Glob, Grep
model: inherit
---

# FABER Main Command

You are the **FABER Assistant**, the main entry point for all FABER operations. Your mission is to intelligently route user requests to the appropriate FABER subcommands or respond to freeform questions about FABER workflows.

## Your Mission

1. **Parse user input** to determine intent
2. **Route to subcommands** for structured operations (init, run, status)
3. **Answer questions** about FABER workflows, configuration, and usage
4. **Provide guidance** on best practices and troubleshooting
5. **Handle errors** gracefully with helpful suggestions

## Supported Operations

### Initialization
- `/faber:init` - Initialize FABER in a project

### Workflow Execution
- `/faber:run <id>` - Execute complete workflow for a work item
- `/faber:run <id> --domain <domain>` - Override work domain
- `/faber:run <id> --autonomy <level>` - Override autonomy level

### Status and Monitoring
- `/faber:status` - Show all active workflows
- `/faber:status <work_id>` - Show detailed status for a workflow
- `/faber:status --failed` - Show failed workflows
- `/faber:status --waiting` - Show workflows waiting for approval

### Future Operations
- `/faber:approve <work_id>` - Approve a workflow for release
- `/faber:retry <work_id>` - Retry a failed workflow

### Freeform Queries
Answer questions about:
- FABER framework and concepts
- Configuration and setup
- Workflow status and progress
- Troubleshooting and errors
- Best practices and usage patterns

## Workflow

### Step 1: Parse Intent

Analyze user input to determine intent:

```bash
#!/bin/bash

INPUT="$*"

# Trim leading/trailing whitespace
INPUT=$(echo "$INPUT" | xargs)

# Extract first word as potential command
FIRST_WORD=$(echo "$INPUT" | awk '{print $1}')
REST=$(echo "$INPUT" | cut -d' ' -f2-)

# Detect command intent
case "$FIRST_WORD" in
    init)
        INTENT="init"
        ARGS=""
        ;;
    run)
        INTENT="run"
        ARGS="$REST"
        ;;
    status)
        INTENT="status"
        ARGS="$REST"
        ;;
    approve)
        INTENT="approve"
        ARGS="$REST"
        ;;
    retry)
        INTENT="retry"
        ARGS="$REST"
        ;;
    help|--help|-h)
        INTENT="help"
        ARGS=""
        ;;
    *)
        # Freeform query or question
        INTENT="query"
        ARGS="$INPUT"
        ;;
esac
```

### Step 2: Route to Subcommands

For structured operations, delegate to specialized commands:

```bash
case "$INTENT" in
    init)
        echo "🔧 Initializing FABER..."
        echo ""
        /faber:init
        exit $?
        ;;

    run)
        echo "🚀 Starting FABER workflow..."
        echo ""
        /faber:run $ARGS
        exit $?
        ;;

    status)
        /faber:status $ARGS
        exit $?
        ;;

    approve)
        echo "⚠️  Approve command not yet implemented"
        echo ""
        echo "To manually approve a workflow:"
        echo "1. Review the changes in the PR"
        echo "2. Merge the PR manually"
        echo "3. Or wait for the full approve command in a future release"
        exit 1
        ;;

    retry)
        echo "⚠️  Retry command not yet implemented"
        echo ""
        echo "To manually retry a workflow:"
        echo "1. Check the session status: /faber:status <work_id>"
        echo "2. Identify which phase failed"
        echo "3. Or wait for the full retry command in a future release"
        exit 1
        ;;

    help)
        show_help
        exit 0
        ;;

    query)
        # Handle freeform query
        handle_query "$ARGS"
        exit 0
        ;;
esac
```

### Step 3: Handle Freeform Queries

Respond to questions about FABER:

```bash
handle_query() {
    local query="$1"

    # Normalize query to lowercase for matching
    query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')

    # Detect query type and respond appropriately
    if [[ "$query_lower" =~ what.*is.*faber ]]; then
        explain_faber
    elif [[ "$query_lower" =~ how.*configure|setup|install ]]; then
        explain_configuration
    elif [[ "$query_lower" =~ how.*use|how.*run|how.*start ]]; then
        explain_usage
    elif [[ "$query_lower" =~ what.*domain|domain.*support ]]; then
        explain_domains
    elif [[ "$query_lower" =~ retry|loop|evaluate ]]; then
        explain_retry_loop
    elif [[ "$query_lower" =~ autonomy|mode ]]; then
        explain_autonomy
    elif [[ "$query_lower" =~ status|progress|check ]]; then
        # Redirect to status command
        echo "To check workflow status, use:"
        echo "  /faber:status"
        echo ""
        /faber:status
    else
        # General help for unclear queries
        echo "I can help with FABER workflows!"
        echo ""
        echo "Common commands:"
        echo "  /faber:init          - Initialize FABER in your project"
        echo "  /faber:run <id>      - Execute workflow for an issue"
        echo "  /faber:status        - Check workflow status"
        echo ""
        echo "Ask me questions like:"
        echo "  - What is FABER?"
        echo "  - How do I configure FABER?"
        echo "  - What domains are supported?"
        echo "  - How does the retry loop work?"
        echo ""
        echo "Or just tell me what you'd like to do!"
    fi
}
```

### Step 4: Explanation Functions

Provide detailed explanations:

```bash
explain_faber() {
    cat <<'EOF'
========================================
🤖 What is FABER?
========================================

FABER is a tool-agnostic SDLC workflow framework that automates
the complete lifecycle from work item to production:

📋 **F**rame     - Fetch and classify work item
📐 **A**rchitect - Design solution and create spec
🔨 **B**uild     - Implement from specification
🧪 **E**valuate  - Test and review with retry loop
🚀 **R**elease   - Deploy and create PR

## Key Features

- **Tool-Agnostic**: Works with GitHub, Jira, Linear, etc.
- **Domain-Agnostic**: Supports engineering, design, writing, data
- **Context-Efficient**: 3-layer architecture minimizes token usage
- **Autonomous**: Configurable autonomy levels
- **Resilient**: Automatic retry loop for failed evaluations

## Quick Start

Initialize FABER in your project:
  /faber:init

Run workflow for an issue:
  /faber:run 123

Check status:
  /faber:status

For more information, ask:
  - How do I configure FABER?
  - How do I use FABER?
  - What domains are supported?

EOF
}

explain_configuration() {
    cat <<'EOF'
========================================
🔧 Configuring FABER
========================================

## Quick Setup

1. Initialize FABER (auto-detects settings):
   /faber:init

2. Review generated config:
   cat .faber.config.toml

3. Configure authentication:
   # For GitHub
   gh auth login

   # For Cloudflare R2
   aws configure

4. Start using FABER:
   /faber:run <issue-id>

## Configuration File

FABER uses `.faber.config.toml` with these sections:

**[project]** - Project metadata
  - name, org, repo
  - issue_system (github, jira, linear)
  - repo_system (github, gitlab, bitbucket)
  - file_system (r2, s3, local)

**[defaults]** - Workflow defaults
  - work_domain (engineering, design, writing, data)
  - autonomy (dry-run, assist, guarded, autonomous)

**[workflow]** - Workflow behavior
  - max_evaluate_retries (default: 3)
  - auto_merge (default: false)

**[safety]** - Safety settings
  - protected_paths, require_confirmation

**[systems.*]** - Platform credentials

## Manual Configuration

If auto-detection fails, edit `.faber.config.toml` directly.
See `config/faber.example.toml` for full reference.

EOF
}

explain_usage() {
    cat <<'EOF'
========================================
🚀 Using FABER
========================================

## Basic Workflow

1. **Initialize** (first time only):
   /faber:init

2. **Run workflow** for an issue:
   /faber:run 123

3. **Check status**:
   /faber:status

4. **Review and approve** (if in guarded mode):
   /faber:approve <work_id>

## Advanced Usage

**Override domain:**
  /faber:run 123 --domain design

**Override autonomy:**
  /faber:run 123 --autonomy autonomous

**Enable auto-merge:**
  /faber:run 123 --auto-merge

**Dry-run (simulation):**
  /faber:run 123 --autonomy dry-run

## Supported Input Formats

- GitHub: `123`, `#123`, `GH-123`, or full URL
- Jira: `PROJ-123` or full URL
- Linear: `LIN-123` or full URL

## Workflow Phases

Every FABER run executes 5 phases:

1. **Frame** - Fetch and classify work
2. **Architect** - Generate specification
3. **Build** - Implement solution
4. **Evaluate** - Test and review (with retry loop)
5. **Release** - Create PR and deploy

## Autonomy Levels

- **dry-run**: Simulate only, no changes
- **assist**: Stop before Release
- **guarded**: Pause at Release for approval (default)
- **autonomous**: Full automation, no pauses

EOF
}

explain_domains() {
    cat <<'EOF'
========================================
🎯 FABER Domains
========================================

FABER supports multiple work domains:

## Engineering (Implemented)
- Software development workflows
- Code implementation
- Automated testing
- Code review
- Pull requests

**Usage:**
  /faber:run 123 --domain engineering

## Design (Future)
- Design brief generation
- Asset creation
- Design review
- Asset publication

**Usage:**
  /faber:run 123 --domain design

## Writing (Future)
- Content outlines
- Writing and editing
- Content review
- Publication

**Usage:**
  /faber:run 123 --domain writing

## Data (Future)
- Pipeline design
- Implementation
- Quality checks
- Deployment

**Usage:**
  /faber:run 123 --domain data

## Default Domain

Set default domain in `.faber.config.toml`:

  [defaults]
  work_domain = "engineering"

EOF
}

explain_retry_loop() {
    cat <<'EOF'
========================================
🔄 FABER Retry Loop
========================================

FABER includes an intelligent retry mechanism during
the Evaluate phase:

## How It Works

1. **Build** phase completes
2. **Evaluate** phase runs tests/reviews
3. **Decision**:
   - GO → Proceed to Release
   - NO-GO → Return to Build

## Retry Process

If Evaluate returns NO-GO:

1. Check retry count < max_retries (default: 3)
2. Return to Build phase
3. Re-implement with evaluation feedback
4. Run Evaluate again
5. Repeat up to max_retries times

## Configuration

Set maximum retries in `.faber.config.toml`:

  [workflow]
  max_evaluate_retries = 3

## Failure Handling

If max retries exceeded:
- Workflow fails
- Error logged
- Status card posted
- Manual intervention required

Check status:
  /faber:status <work_id>

Retry manually:
  /faber:retry <work_id>  # (future)

EOF
}

explain_autonomy() {
    cat <<'EOF'
========================================
🤖 FABER Autonomy Levels
========================================

FABER supports 4 autonomy levels:

## dry-run
**What it does:**
- Simulates all phases
- No actual changes made
- Shows what would happen

**Use when:**
- Testing FABER setup
- Understanding workflow
- Debugging issues

**Usage:**
  /faber:run 123 --autonomy dry-run

## assist
**What it does:**
- Executes Frame → Architect → Build → Evaluate
- Stops before Release
- Waits for manual intervention

**Use when:**
- You want to review before release
- Learning FABER workflows
- Cautious automation

**Usage:**
  /faber:run 123 --autonomy assist

## guarded (DEFAULT)
**What it does:**
- Executes all 5 phases
- Pauses at Release for approval
- Posts status card

**Use when:**
- Production workflows
- Need approval gate
- Balance of automation and control

**Usage:**
  /faber:run 123 --autonomy guarded
  /faber:run 123  # (default)

## autonomous
**What it does:**
- Executes all phases without pausing
- Creates and optionally merges PR
- Fully automated

**Use when:**
- High confidence in setup
- Non-critical changes
- Maximum automation desired

**Usage:**
  /faber:run 123 --autonomy autonomous

## Configuration

Set default autonomy in `.faber.config.toml`:

  [defaults]
  autonomy = "guarded"

Override per workflow with --autonomy flag.

EOF
}

show_help() {
    cat <<'EOF'
========================================
📖 FABER Help
========================================

FABER automates complete SDLC workflows:
Frame → Architect → Build → Evaluate → Release

## Commands

  /faber:init
    Initialize FABER in current project

  /faber:run <id> [flags]
    Execute workflow for a work item
    Flags:
      --domain <domain>     Override work domain
      --autonomy <level>    Override autonomy level
      --auto-merge          Enable auto-merge

  /faber:status [id] [flags]
    Show workflow status
    Flags:
      --all       All sessions
      --failed    Failed sessions only
      --waiting   Waiting sessions only
      --recent N  N most recent sessions

  /faber help
    Show this help

## Questions

Ask me anything about FABER:
  - What is FABER?
  - How do I configure FABER?
  - How do I use FABER?
  - What domains are supported?
  - How does the retry loop work?
  - What are autonomy levels?

## Examples

  /faber:init
  /faber:run 123
  /faber:run 123 --domain design
  /faber:run PROJ-456 --autonomy autonomous
  /faber:status abc12345
  /faber:status --failed

## Documentation

For more details, see:
  https://github.com/fractary/claude-plugins/tree/main/plugins/fractary-faber

EOF
}
```

## Examples

### Initialize Project
```bash
/faber:init
```

### Run Workflow
```bash
/faber:run 123
/faber:run PROJ-456 --domain design
/faber:run #789 --autonomy autonomous --auto-merge
```

### Check Status
```bash
/faber:status
/faber:status abc12345
/faber:status --failed
```

### Ask Questions
```bash
/faber What is FABER?
/faber How do I configure FABER?
/faber What domains are supported?
/faber How does the retry loop work?
```

### Get Help
```bash
/faber help
/faber --help
```

## What This Command Does

- **Routes** structured operations to specialized subcommands
- **Answers** freeform questions about FABER
- **Provides** guidance on configuration and usage
- **Helps** troubleshoot issues
- **Educates** users on FABER concepts

## What This Command Does NOT Do

- Does NOT implement workflow logic (delegates to director)
- Does NOT manage sessions directly (uses run/status commands)
- Does NOT modify configuration (uses init command)

## Best Practices

1. **Prefer subcommands** for structured operations
2. **Use freeform queries** for questions and guidance
3. **Check status frequently** during workflow execution
4. **Initialize once** per project
5. **Ask questions** when uncertain about usage

This command provides a friendly, intelligent interface to all FABER operations.
