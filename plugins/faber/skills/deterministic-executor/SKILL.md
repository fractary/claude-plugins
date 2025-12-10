# Deterministic FABER Executor (Prototype)

<CONTEXT>
This is a **prototype** for a deterministic workflow executor that addresses the
"hallucinated completion" problem identified in Issue #346 investigation.

**Problem**: The LLM-based faber-manager can skip steps by emitting events without
actually executing the underlying commands/skills.

**Solution**: Move orchestration control to a bash script that:
1. Owns the step iteration loop (deterministic)
2. Invokes Claude for each step individually (via --resume for context)
3. Verifies external evidence before marking steps complete
4. Updates state deterministically (not via LLM)
5. Emits events deterministically (not via LLM)

**Key Principle**: Claude does the "thinking" and tool execution, but bash controls
the workflow progression. Claude cannot skip ahead because it only receives one
step at a time.
</CONTEXT>

<ARCHITECTURE>
```
┌─────────────────────────────────────────────────────────────────┐
│  execute-workflow.sh (Deterministic Orchestrator)               │
│                                                                 │
│  1. Initialize Claude session (get SESSION_ID)                  │
│  2. For each step in plan:                                      │
│     a. emit-event.sh step_start        ← Bash (deterministic)   │
│     b. update-state.sh in_progress     ← Bash (deterministic)   │
│     c. claude --resume $SESSION_ID     ← Claude (execute step)  │
│     d. verify-step.sh                  ← Bash (check reality)   │
│     e. emit-event.sh step_complete     ← Bash (deterministic)   │
│     f. update-state.sh completed       ← Bash (deterministic)   │
│  3. emit-event.sh workflow_complete    ← Bash (deterministic)   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**What Claude Controls:**
- Actual execution of commands (Read, Write, Bash, etc.)
- Decision-making within a step
- Tool selection and usage

**What Bash Controls:**
- Which step to execute next
- When to emit events
- When to update state
- Whether to continue or halt
- External verification
</ARCHITECTURE>

<SCRIPTS>

## execute-workflow.sh
Main orchestration script. Owns the loop, invokes Claude per step.

## verify-step.sh
External evidence verification. Checks real-world state (GitHub, git, filesystem).

## update-state.sh
Deterministic state updates. Uses jq to modify state.json.

## init-session.sh
Initializes Claude session with workflow context, returns SESSION_ID.

</SCRIPTS>

<USAGE>
```bash
# Execute via command (recommended)
/fractary-faber:execute-deterministic my-plan-id

# Execute via command with serialized input (fewer API calls)
/fractary-faber:execute-deterministic my-plan-id --serialized-input

# Direct script execution (standard mode - one message per step)
./plugins/faber/skills/deterministic-executor/scripts/execute-workflow.sh \
  --plan logs/fractary/plugins/faber/plans/my-plan.json \
  --run-id "fractary/claude-plugins/abc123"

# Serialized input mode (all steps in single message)
./plugins/faber/skills/deterministic-executor/scripts/execute-workflow.sh \
  --plan logs/fractary/plugins/faber/plans/my-plan.json \
  --run-id "fractary/claude-plugins/abc123" \
  --serialized-input

# Resume from a specific step (after failure)
./plugins/faber/skills/deterministic-executor/scripts/execute-workflow.sh \
  --plan logs/fractary/plugins/faber/plans/my-plan.json \
  --run-id "fractary/claude-plugins/abc123" \
  --resume-from 5
```
</USAGE>

<EXECUTION_MODES>
## Standard Mode (default)

Each step is sent to Claude individually via `--resume`:
- More API calls (N+1 for N steps)
- Bash controls which step runs next
- Claude cannot skip ahead
- Highest guarantee against step skipping

## Serialized Input Mode (`--serialized-input`)

All steps sent in a single message:
- Fewer API calls (2 total: init + execute)
- Claude receives complete step list upfront
- Bash verifies results after completion
- Trade-off: relies on Claude to execute sequentially
- Useful for cost/latency optimization once workflow is validated
</EXECUTION_MODES>

<STATUS>
**PROTOTYPE** - Not yet integrated into main FABER workflow.

This is being developed as an alternative to the LLM-based faber-manager
orchestration to solve the step-skipping problem.
</STATUS>
