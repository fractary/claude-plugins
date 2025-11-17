---
org: fractary
system: claude-plugins
title: Faber-Agent Plugin Comprehensive Enhancement
spec_number: SPEC-025
status: approved
created: 2025-01-15
updated: 2025-01-15
authors: [AI-assisted design with user validation]
tags: [faber-agent, audit, conversion, workflow-creation, pre-skills-migration, manager-as-agent]
codex_sync_includes: ["*"]
codex_sync_excludes: []
visibility: internal
---

# SPEC-025: Faber-Agent Plugin Comprehensive Enhancement

## Executive Summary

Enhance the faber-agent plugin to support comprehensive project auditing and workflow creation capabilities, with specific focus on migrating pre-skills era projects (agent chains) to the Manager-as-Agent + Skills architecture.

**Current State:**
- faber-agent plugin can generate individual artifacts (agents, skills, commands, plugins)
- No project auditing capabilities
- No conversion/migration tooling
- Standards document (agentic-control-plane-standards-2.md) has Manager/Director inversion error
- No support for detecting and converting pre-skills agent chains

**Target State:**
- Comprehensive project auditing with all anti-pattern detection
- Automated conversion specification generation
- Workflow creation following Manager-as-Agent pattern
- Corrected standards documentation
- Full support for pre-skills migration paths

**Capabilities to Add:**
1. **Project Audit** - Scan existing .claude/ directories, detect patterns (correct and legacy)
2. **Conversion Spec Generation** - Create actionable migration plans with before/after examples
3. **Workflow Creation** - Generate Manager agents (not skills!), Director skills, specialist skills with scripts
4. **Standards Correction** - Fix Manager/Director inversion, document Manager-as-Agent pattern

## Background

### Historical Context

**Pre-Skills Era (before skills existed):**
- Workflows implemented as agent chains: Command → Agent1 → Agent2 → Agent3 → Agent4
- Each workflow step was its own agent
- All logic embedded in agent prompts (no script abstraction)
- Heavy context usage (each agent loads full context)
- No separation between orchestration and execution

**Standards Evolution:**
- agentic-control-plane-standards-2.md currently has Manager/Director inversion
- SPEC-024 (Lake.Corthonomy.AI) identified correct pattern: Manager-as-Agent
- Many existing projects follow incorrect or legacy patterns

**Current Challenge:**
- Multiple projects have pre-skills agent chains needing conversion
- Need to detect these patterns and generate migration paths
- Need to prevent future incorrect implementations

### Correct Architecture Pattern (Manager-as-Agent)

```
┌─────────────────────────────────────────────────────────┐
│                   USER INVOCATION                        │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│              LAYER 1: COMMANDS                           │
│  Lightweight routing to Manager Agent or Director Skill │
└────────────────────┬────────────────────────────────────┘
                     ↓
            ┌────────┴────────┐
            │                 │
            ↓                 ↓
┌───────────────────┐  ┌──────────────────────────────────┐
│  SINGLE ENTITY    │  │       BATCH OPERATION            │
│  (69% of usage)   │  │       (31% of usage)             │
└─────────┬─────────┘  └────────┬─────────────────────────┘
          │                     │
          │                     ↓
          │            ┌────────────────────────────────────┐
          │            │  DIRECTOR SKILL                    │
          │            │  Location: .claude/skills/         │
          │            │                                    │
          │            │  Responsibilities:                 │
          │            │  - Parse pattern (*, */*, a,b,c)  │
          │            │  - Expand wildcards                │
          │            │  - Return dataset list             │
          │            │  - Recommend parallelism           │
          │            │                                    │
          │            │  Returns to: Core Claude Agent     │
          │            └────────┬───────────────────────────┘
          │                     │
          │                     ↓
          │            ┌────────────────────────────────────┐
          │            │   CORE CLAUDE AGENT                │
          │            │   (Built-in)                       │
          │            │                                    │
          │            │   Invokes Manager Agents in       │
          │            │   parallel (max 5 concurrent):    │
          │            │     → Manager Agent (Task tool)   │
          │            │     → Manager Agent (Task tool)   │
          │            │     → ...                          │
          │            │                                    │
          │            │   Aggregates results               │
          │            └────────┬───────────────────────────┘
          │                     │
          └─────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│          LAYER 2: MANAGER AGENT                          │
│          Location: .claude/agents/project/               │
│                    {name}-manager.md                     │
│                                                          │
│  Full Agent Capabilities:                               │
│  - Persistent state across workflow                     │
│  - Full tool access (Read/Write/Bash/Skill/AskUser)     │
│  - Natural user interaction                             │
│  - Graceful error handling                              │
│  - Skill invocation via Skill tool                      │
│                                                          │
│  7-Phase Workflow:                                       │
│  1. INSPECT  → Invoke inspector skill                   │
│  2. ANALYZE  → Invoke debugger skill (if issues)        │
│  3. PRESENT  → Show analysis to user                    │
│  4. APPROVE  → Get user decision (AskUserQuestion)      │
│  5. EXECUTE  → Invoke builder skills                    │
│  6. VERIFY   → Re-invoke inspector                      │
│  7. REPORT   → Show final status                        │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│            LAYER 3: SPECIALIST SKILLS                    │
│            Location: .claude/skills/                     │
│                                                          │
│  Each skill:                                            │
│  - Focused execution (one task)                         │
│  - Script-backed (deterministic logic outside LLM)      │
│  - Workflow files (conditional loading for multi-step)  │
│  - Minimal context usage                                │
│  - Returns structured results                           │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│               SCRIPTS & TEMPLATES                        │
│  Deterministic execution outside LLM context            │
└─────────────────────────────────────────────────────────┘
```

**Key Principles:**
- **Manager = AGENT** (orchestration, state, user interaction, full tools)
- **Director = SKILL** (simple pattern expansion for batch operations)
- **Specialists = SKILLS** (focused execution, script-backed)
- **Scripts** = Deterministic operations (outside LLM context)

## Problem Statement

### Anti-Patterns to Detect and Convert

**1. Manager-as-Skill (Inverted Pattern)**
- Current: Manager implemented as skill instead of agent
- Impact: Limited capabilities, no natural user interaction, poor state management
- Detection: Manager in `.claude/skills/` directory
- Conversion: Move to `.claude/agents/`, add full tool access, enhance with agent capabilities

**2. Director-as-Agent (Over-engineered Pattern)**
- Current: Director implemented as agent instead of skill
- Impact: Unnecessary complexity, doesn't leverage Core Agent parallelism
- Detection: Director in `.claude/agents/` doing pattern expansion
- Conversion: Demote to skill in `.claude/skills/`, simplify to pattern expansion only

**3. Agent Chains (Pre-Skills Pattern)** ⭐ CRITICAL
- Current: Agent1 → Agent2 → Agent3 → Agent4 (each step is an agent)
- Impact: Heavy context usage, no script abstraction, difficult to maintain
- Detection: Agents invoking other agents via Task tool, no skills directory
- Conversion: Consolidate to 1 Manager Agent + N Skills
- **User Priority: High** - Many existing projects follow this pattern

**4. Hybrid Agents (Orchestration + Execution)**
- Current: Single agent doing both orchestration AND execution work
- Impact: Violates single responsibility, hard to test, poor separation of concerns
- Detection: Agent has both Task/Skill tool calls AND Bash/Read/Write operations
- Conversion: Split into Manager Agent (orchestration) + Skill (execution)

**5. Inline Deterministic Logic (No Script Abstraction)**
- Current: File operations, data transforms, API calls, validations embedded in agent/skill prompts
- Impact: Heavy context usage, not reusable, hard to test
- Detection: curl, aws cli, gh cli, jq, sed, awk, file ops in prompts
- Conversion: Extract to scripts in `skills/*/scripts/`, skill invokes script

**6. Heavy Context Usage (No Conditional Loading)**
- Current: All logic in single large file, no workflow file splits
- Impact: Unnecessary context loading, slow operations
- Detection: Large skill files (>500 lines), no `workflow/` directory
- Conversion: Split into `workflow/*.md` files, conditionally load based on operation

### Detection Requirements

The audit system must identify:

**Architectural Patterns:**
- Manager location (agent vs. skill)
- Director location (agent vs. skill)
- Agent chain patterns (Agent → Agent invocations)
- Hybrid agent patterns (orchestration + execution)
- Layer violations (agents doing work directly)

**Script Extraction Opportunities:**
- File operations (cp, mv, mkdir, rm, chmod, chown)
- Data transformations (jq, sed, awk, cut, sort, uniq)
- API calls (curl, wget, aws cli, gh cli, gcloud cli)
- Validation checks (schema validation, format checks, existence checks)

**Context Optimization Opportunities:**
- Large monolithic skill files
- No workflow file structure
- No conditional loading patterns
- Repeated logic across files

**Standards Compliance:**
- XML markup completeness
- Naming conventions
- Tool access patterns
- Documentation integration

## Proposed Solution

### Three-Track Implementation

#### Track 1: Project Audit & Conversion Spec Generation

**Capabilities:**
1. Scan .claude/ directory structure
2. Build dependency graph (who invokes whom)
3. Detect all architectural patterns (correct and anti-patterns)
4. Identify script extraction opportunities
5. Recommend context optimizations
6. Generate comprehensive audit reports
7. Create actionable conversion specifications

**Components:**

**Commands:**
- `/faber-agent:audit-project [path]` - Entry point for project auditing
- `/faber-agent:generate-conversion-spec <plugin-name>` - Generate migration specification

**Agents:**
- `project-auditor.md` - Orchestrates comprehensive audit workflow
- `conversion-spec-generator.md` - Creates detailed migration specifications

**Skills:**
- `project-analyzer/` - Scans structure, builds dependency graph, detects patterns
- `agent-chain-analyzer/` - Identifies and analyzes agent chains (pre-skills pattern)
- `script-extractor/` - Identifies deterministic logic for extraction
- `hybrid-agent-detector/` - Finds agents doing orchestration + execution
- `architecture-validator/` - Validates against all standards
- `context-optimizer/` - Recommends context efficiency improvements
- `gap-analyzer/` - Comprehensive gap analysis
- `spec-generator/` - Generates migration specifications

**Templates:**
- `project-audit-report.md.template` - Comprehensive audit report structure
- `conversion-spec.md.template` - Migration specification with all phases
- `gap-analysis.md.template` - Gap identification format
- `agent-to-skill-conversion.md.template` - Individual agent conversion guide
- `script-extraction-spec.md.template` - Script extraction specifications

#### Track 2: Workflow Creation from Scratch

**Capabilities:**
1. Create Manager agents (not skills!) following 7-phase or Builder/Debugger patterns
2. Create Director skills for batch operation support
3. Create specialist skills with proper script structure
4. Generate workflow files for conditional loading
5. Validate all generated components

**Components:**

**Commands:**
- `/faber-agent:create-workflow <name> --pattern <multi-phase|builder-debugger>` - Create new workflow

**Agents:**
- `workflow-creator.md` - Orchestrates workflow creation using FABER

**Skills:**
- `workflow-designer/` - Interactive workflow design and generation
- `workflow-validator/` - Validates generated workflows

**Templates:**

**Manager Agent Templates:**
- `manager-agent-7-phase.md.template` - 7-phase workflow Manager agent
  - Full tool access: Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob
  - State management patterns
  - User interaction examples
  - Skill coordination logic

- `manager-agent-builder-debugger.md.template` - Builder/Debugger pattern Manager agent
  - Coordinates Inspector, Debugger, Builder skills
  - Knowledge base integration
  - Issue log tracking
  - Approval workflows

**Director Skill Template:**
- `director-skill-pattern-expansion.md.template` - Simple pattern expansion skill
  - Operations: expand-pattern, validate-pattern
  - Input: Pattern string (*, dataset/*, a,b,c)
  - Output: Dataset list + parallelism recommendation
  - No orchestration logic

**Specialist Skill Templates:**
- `specialist-skill-with-scripts.md.template` - Skill with script structure
  - Scripts directory for deterministic logic
  - Workflow files for multi-step operations
  - Proper invocation patterns

**Builder/Debugger Pattern Templates:**
- `inspector-skill.md.template` - Observer (WHAT IS - factual only)
- `debugger-skill.md.template` - Analyzer (WHY + HOW with knowledge base)
- `builder-skill.md.template` - Executor (operations router)
- `troubleshooting-kb.md.template` - Knowledge base document

**Validators:**
- `manager-agent-validator.sh` - Ensures Manager created as agent with proper tools
- `director-skill-validator.sh` - Ensures Director created as simple skill
- `skill-script-validator.sh` - Validates script structure and invocation

#### Track 3: Standards Correction & Documentation

**Capabilities:**
1. Correct agentic-control-plane-standards-2.md (fix Manager/Director inversion)
2. Create comprehensive pattern guides
3. Create migration guides for all anti-patterns
4. Document Manager-as-Agent rationale and trade-offs

**Components:**

**Standards Documents:**
- `agentic-control-plane-standards-2.md` (corrected) - Fix Manager/Director inversion, add Manager-as-Agent principle
- `manager-as-agent-pattern.md` (new) - Complete Manager-as-Agent explanation
- `agent-to-skill-migration.md` (new) - Guide for converting agent chains

**Pattern Guides:**
- `patterns/manager-as-agent.md` - Complete pattern guide
- `patterns/director-skill.md` - Director skill pattern
- `patterns/builder-debugger.md` - Builder/Debugger with Manager agent
- `patterns/pre-skills-migration.md` - Converting agent chains

**Migration Guides:**
- `migration/agent-chain-to-skills.md` - Step-by-step agent chain conversion
- `migration/hybrid-agent-splitting.md` - Splitting hybrid agents
- `migration/script-extraction.md` - Extracting deterministic logic to scripts
- `migration/context-optimization.md` - Workflow file patterns and conditional loading

**Usage Guides:**
- `guides/auditing-projects.md` - How to audit existing projects
- `guides/generating-conversion-specs.md` - How to use conversion specs
- `guides/creating-workflows.md` - How to create new workflows

## Anti-Pattern Detection Matrix

| Anti-Pattern | Detection Skill | Indicators | Conversion Path | Template |
|--------------|----------------|------------|-----------------|----------|
| Manager as Skill | architecture-validator | Manager in `.claude/skills/` | Convert to Manager Agent | manager-agent-7-phase.md.template |
| Director as Agent | architecture-validator | Director in `.claude/agents/` doing pattern expansion | Demote to Director Skill | director-skill-pattern-expansion.md.template |
| Agent Chain (pre-skills) | agent-chain-analyzer | Agent1 → Agent2 → Agent3, no skills directory | Consolidate to Manager + Skills | agent-to-skill-conversion.md.template |
| Hybrid Agent | hybrid-agent-detector | Agent has Task/Skill AND Bash/Read/Write operations | Split to Manager + Skill | agent-to-skill-conversion.md.template |
| Inline File Ops | script-extractor | `cp`, `mv`, `mkdir`, `rm`, `chmod` in prompts | Extract to scripts | script-extraction-spec.md.template |
| Inline Data Transforms | script-extractor | `jq`, `sed`, `awk`, `cut` in prompts | Extract to scripts | script-extraction-spec.md.template |
| Inline API Calls | script-extractor | `curl`, `aws`, `gh`, `gcloud` in prompts | Extract to scripts | script-extraction-spec.md.template |
| Inline Validations | script-extractor | Schema/format checks in prompts | Extract to scripts | script-extraction-spec.md.template |
| Heavy Context | context-optimizer | Large files (>500 lines), no `workflow/` dir | Split to workflow files | conversion-spec.md.template |
| No Conditional Loading | context-optimizer | All logic in single file | Add workflow file pattern | conversion-spec.md.template |

## Agent Chain Conversion Pattern

**Pre-Skills Agent Chain Example:**
```
Command: /myproject-process
  ↓
Agent: step1-agent.md
  ↓ (invokes via Task)
Agent: step2-agent.md
  ↓ (invokes via Task)
Agent: step3-agent.md
  ↓ (invokes via Task)
Agent: step4-agent.md
```

**Converted to Manager-as-Agent + Skills:**
```
Command: /myproject-process
  ↓
Manager Agent: myproject-manager.md
  - Orchestrates workflow
  - Maintains state across phases
  - User interaction (AskUserQuestion)
  - Full tool access
  ↓
  ├─ Skill: myproject-step1 (scripts/step1-logic.sh)
  ├─ Skill: myproject-step2 (scripts/step2-logic.sh)
  ├─ Skill: myproject-step3 (scripts/step3-logic.sh)
  └─ Skill: myproject-step4 (scripts/step4-logic.sh)
```

**Conversion Steps:**
1. Identify chain start (entry point agent)
2. Map workflow steps (what each agent does)
3. Classify agent roles (orchestration vs. execution)
4. Create Manager agent from orchestration logic
5. Convert execution agents to skills
6. Extract deterministic logic to scripts
7. Update command routing
8. Test end-to-end workflow

## Context Load Trade-offs

**Single Entity Operations (69% of usage):**
- Current: 2 context loads
- With Manager-as-Agent: 2 context loads
- **NO CHANGE** ✅

**Batch Operations (31% of usage):**
- Current: 2 context loads (but sequential, slow)
- With Manager-as-Agent: 20-112 context loads (but 5x faster with parallelism)
- **ACCEPTABLE TRADE-OFF** ✅

**Rationale:**
1. Single operations (primary use case) unaffected
2. Batch operations are infrequent
3. Wall-clock time reduction (5x speedup) matters more than context load cost
4. Better state management per entity
5. Proper error isolation between parallel executions
6. Context load is one-time cost, better outcomes justify it

## Technical Specifications

### Project Analyzer Skill

**Purpose:** Scan .claude/ directory and build comprehensive project understanding

**Operations:**
1. `scan-structure` - Inventory all commands, agents, skills, hooks
2. `build-dependency-graph` - Map who invokes whom (Task tool calls)
3. `detect-agent-chains` - Find Agent → Agent patterns
4. `classify-patterns` - Identify all architectural patterns

**Scripts:**
- `scan-claude-directory.sh` - Recursive directory scan
  - Input: Path to .claude/
  - Output: JSON inventory of all components
  - Extracts: Frontmatter metadata, file sizes, modification dates

- `build-dependency-graph.sh` - Parse Task tool invocations
  - Input: List of agent files
  - Output: Dependency graph (JSON)
  - Identifies: Agent → Agent, Agent → Skill, Skill → Skill patterns

- `detect-agent-chains.sh` - Find pre-skills patterns
  - Input: Dependency graph
  - Output: List of agent chains with start/end points
  - Heuristics: No skills directory, Agent → Agent pattern, sequential flow

- `parse-agent-metadata.sh` - Extract agent details
  - Input: Agent file path
  - Output: Frontmatter, allowed-tools, XML sections, line count
  - Validates: Structure completeness

**Output Format:**
```json
{
  "project_path": "/path/to/project/.claude",
  "scan_timestamp": "2025-01-15T14:30:00Z",
  "inventory": {
    "commands": 7,
    "agents": 12,
    "skills": 0,
    "hooks": 2
  },
  "dependency_graph": {
    "nodes": ["command-a", "agent-1", "agent-2", ...],
    "edges": [
      {"from": "command-a", "to": "agent-1", "type": "Task"},
      {"from": "agent-1", "to": "agent-2", "type": "Task"}
    ]
  },
  "agent_chains_detected": [
    {
      "chain_id": "workflow-1",
      "start": "agent-1",
      "steps": ["agent-1", "agent-2", "agent-3", "agent-4"],
      "entry_point": "command-process"
    }
  ],
  "patterns_detected": {
    "manager_as_skill": false,
    "director_as_agent": false,
    "agent_chains": 1,
    "hybrid_agents": 2,
    "no_skills_directory": true
  }
}
```

### Agent Chain Analyzer Skill

**Purpose:** Analyze agent chains and recommend consolidation

**Operations:**
1. `identify-chain-start` - Find entry point of chain
2. `map-workflow-steps` - Extract workflow from chain
3. `classify-agent-role` - Orchestration vs. Execution vs. Hybrid
4. `extract-skill-candidates` - Identify agents that should become skills

**Scripts:**
- `identify-chain-start.sh` - Find first agent in chain
  - Input: Dependency graph, command name
  - Output: Entry point agent name
  - Logic: Follow command → agent path

- `map-workflow-steps.sh` - Extract workflow from agents
  - Input: List of agents in chain
  - Output: Workflow steps with descriptions
  - Parses: Agent prompts for "Steps", "Workflow", etc.

- `classify-agent-role.sh` - Determine orchestration vs. execution
  - Input: Agent file path
  - Output: Role classification (orchestrator, executor, hybrid)
  - Heuristics:
    - Orchestrator: Has Task/Skill tool calls, invokes others
    - Executor: Has Bash/Read/Write, does work directly
    - Hybrid: Has both (violation)

- `extract-skill-candidates.sh` - Identify conversion targets
  - Input: Agent chain analysis
  - Output: List of agents to convert to skills
  - Logic: All non-orchestrator agents should become skills

**Output Format:**
```json
{
  "chain_id": "workflow-1",
  "analysis": {
    "start_agent": "process-step1-agent",
    "workflow_steps": [
      {
        "agent": "process-step1-agent",
        "role": "executor",
        "description": "Validates input data",
        "should_be_skill": true
      },
      {
        "agent": "process-step2-agent",
        "role": "executor",
        "description": "Transforms data",
        "should_be_skill": true
      },
      {
        "agent": "process-step3-agent",
        "role": "executor",
        "description": "Saves results",
        "should_be_skill": true
      }
    ],
    "orchestration_logic": "Currently distributed across agents, should consolidate to single Manager agent",
    "recommended_structure": {
      "manager_agent": "myproject-process-manager",
      "skills": [
        "myproject-input-validator",
        "myproject-data-transformer",
        "myproject-result-saver"
      ]
    }
  }
}
```

### Script Extractor Skill

**Purpose:** Identify deterministic logic for script extraction

**Operations:**
1. `detect-file-operations` - Find file manipulation
2. `detect-data-transforms` - Find jq, sed, awk usage
3. `detect-api-calls` - Find curl, aws cli, gh cli
4. `detect-validation-logic` - Find deterministic checks
5. `calculate-context-savings` - Estimate token reduction

**Scripts:**
- `detect-file-operations.sh` - Find file ops in prompts
  - Input: Agent/skill file paths
  - Output: List of file operations with locations
  - Pattern matching: cp, mv, mkdir, rm, chmod, chown, touch, ln

- `detect-data-transforms.sh` - Find data processing
  - Input: Agent/skill file paths
  - Output: List of transforms with locations
  - Pattern matching: jq, sed, awk, cut, sort, uniq, tr, grep

- `detect-api-calls.sh` - Find external service calls
  - Input: Agent/skill file paths
  - Output: List of API calls with locations
  - Pattern matching: curl, wget, aws, gh, gcloud, az, kubectl

- `detect-validation-logic.sh` - Find checks
  - Input: Agent/skill file paths
  - Output: List of validations with locations
  - Pattern matching: test, [, [[, if conditions, schema checks

- `calculate-context-savings.sh` - Estimate improvements
  - Input: Extraction opportunities list
  - Output: Estimated token reduction
  - Logic: Count lines of deterministic logic × avg tokens/line

**Output Format:**
```json
{
  "extraction_opportunities": [
    {
      "type": "file-operations",
      "component": "process-step2-agent.md",
      "lines": [45, 46, 47],
      "code": "mkdir -p output/data\ncp input/*.csv output/data/\nchmod 644 output/data/*.csv",
      "recommended_script": "scripts/setup-output-directory.sh",
      "estimated_token_savings": 120
    },
    {
      "type": "api-call",
      "component": "process-step3-agent.md",
      "lines": [78, 79, 80, 81, 82],
      "code": "curl -X POST https://api.example.com/data \\\n  -H \"Authorization: Bearer $TOKEN\" \\\n  -d @output/data/results.json",
      "recommended_script": "scripts/upload-results.sh",
      "estimated_token_savings": 180
    }
  ],
  "total_opportunities": 12,
  "total_estimated_savings": 2340
}
```

### Conversion Spec Generator Skill

**Purpose:** Generate comprehensive migration specifications

**Phases:**
1. **Phase 1: Manager/Director Corrections**
   - Manager skill → Manager agent conversion
   - Director agent → Director skill demotion

2. **Phase 2: Agent Chain Consolidation** ⭐ CRITICAL FOR PRE-SKILLS
   - Create Manager agent from orchestration logic
   - Convert execution agents to skills
   - Update command routing

3. **Phase 3: Hybrid Agent Splitting**
   - Separate orchestration from execution
   - Create Manager agent + Skill pair

4. **Phase 4: Script Extraction**
   - Extract deterministic logic to scripts
   - Update skills to invoke scripts

5. **Phase 5: Context Optimization**
   - Split large files into workflow files
   - Add conditional loading patterns

6. **Phase 6: Testing & Validation**
   - Test plan per phase
   - Validation criteria
   - Rollback procedures

**For Each Component Conversion:**
- Current state (file path, content summary)
- Target state (new structure)
- Step-by-step conversion instructions
- Before/after code examples
- Testing strategy
- Estimated effort (hours)

**Output:** Complete conversion-spec.md document with all phases, ready to follow

## Implementation Plan

### Phase 1: Standards Correction & Documentation (Week 1)

**Objectives:**
- Correct agentic-control-plane-standards-2.md
- Create manager-as-agent-pattern.md
- Create agent-to-skill-migration.md
- Create all pattern guides

**Tasks:**
1. Update `docs/standards/agentic-control-plane-standards-2.md`:
   - Fix Manager/Director inversion throughout
   - Add "Manager-as-Agent Principle" section
   - Add "Context Load Trade-offs" section
   - Include examples from SPEC-024
   - Add pre-skills migration section

2. Create `docs/standards/manager-as-agent-pattern.md`:
   - Complete pattern explanation
   - Why Manager needs agent capabilities
   - Why Director should be skill
   - Context load analysis
   - Testing strategies

3. Create `docs/standards/agent-to-skill-migration.md`:
   - Converting agent chains
   - Script extraction best practices
   - Context optimization strategies
   - Before/after examples

4. Create pattern guides in `docs/patterns/`:
   - `manager-as-agent.md`
   - `director-skill.md`
   - `builder-debugger.md`
   - `pre-skills-migration.md`

**Deliverables:**
- All standards documents corrected
- Pattern guides complete
- Foundation for implementation

**Validation:**
- Documentation reviewed for correctness
- Examples tested for accuracy
- Cross-references validated

### Phase 2: Audit Infrastructure - Basic Detection (Week 2)

**Objectives:**
- Create project-auditor agent
- Create basic detection skills
- Create audit command
- Test basic audit capability

**Tasks:**
1. Create `agents/project-auditor.md`:
   - FABER workflow structure
   - Coordinates all audit skills
   - Presents findings to user

2. Create `skills/project-analyzer/`:
   - `SKILL.md` with operations
   - `workflow/basic.md` for workflow steps
   - `scripts/scan-claude-directory.sh`
   - `scripts/build-dependency-graph.sh`
   - `scripts/detect-agent-chains.sh`
   - `scripts/parse-agent-metadata.sh`

3. Create `skills/architecture-validator/`:
   - `SKILL.md` with validation operations
   - Scripts for pattern checking

4. Create `commands/audit-project.md`:
   - Routes to project-auditor agent
   - Argument parsing

5. Create `templates/audit/project-audit-report.md.template`:
   - Basic structure (will enhance in Phase 3)

6. Test basic audit:
   - Test on project with correct architecture
   - Test on project with Manager/Director inversion
   - Verify detection accuracy

**Deliverables:**
- `/faber-agent:audit-project` command functional
- Basic pattern detection working
- Audit report generation

**Validation:**
- Command invokes successfully
- Detects Manager/Director patterns correctly
- Report is readable and actionable

### Phase 3: Audit Infrastructure - Advanced Detection (Week 3)

**Objectives:**
- Add advanced detection skills
- Enhance audit reports
- Test on pre-skills projects

**Tasks:**
1. Create `skills/agent-chain-analyzer/`:
   - `SKILL.md` with operations
   - `scripts/identify-chain-start.sh`
   - `scripts/map-workflow-steps.sh`
   - `scripts/classify-agent-role.sh`
   - `scripts/extract-skill-candidates.sh`

2. Create `skills/script-extractor/`:
   - `SKILL.md` with operations
   - `scripts/detect-file-operations.sh`
   - `scripts/detect-data-transforms.sh`
   - `scripts/detect-api-calls.sh`
   - `scripts/detect-validation-logic.sh`
   - `scripts/calculate-context-savings.sh`

3. Create `skills/hybrid-agent-detector/`:
   - `SKILL.md` with operations
   - `scripts/detect-orchestration-logic.sh`
   - `scripts/detect-execution-logic.sh`
   - `scripts/classify-hybrid-agents.sh`

4. Create `skills/context-optimizer/`:
   - `SKILL.md` with operations
   - `scripts/analyze-context-usage.sh`
   - `scripts/recommend-workflow-splits.sh`
   - `scripts/recommend-conditional-loading.sh`
   - `scripts/calculate-optimization-impact.sh`

5. Create `skills/gap-analyzer/`:
   - `SKILL.md` with comprehensive gap analysis
   - Scripts for comparing current vs. target

6. Enhance `templates/audit/project-audit-report.md.template`:
   - Add all detection sections
   - Context efficiency analysis
   - Script extraction opportunities
   - Complete format

7. Create `templates/audit/gap-analysis.md.template`

8. Test on pre-skills project:
   - Verify agent chain detection
   - Verify script extraction identification
   - Check audit report completeness

**Deliverables:**
- Full audit capability operational
- All anti-patterns detected
- Comprehensive audit reports

**Validation:**
- Test on multiple project types
- Verify all detection accuracy
- Audit reports actionable

### Phase 4: Conversion Spec Generation (Week 4)

**Objectives:**
- Create conversion-spec-generator agent
- Create spec-generator skill
- Create all conversion templates
- Generate actionable conversion specs

**Tasks:**
1. Create `agents/conversion-spec-generator.md`:
   - Takes audit results as input
   - Orchestrates spec generation
   - Prioritizes conversions

2. Create `skills/spec-generator/`:
   - `SKILL.md` with generation operations
   - `workflow/generate-spec.md` for multi-phase generation
   - Logic for all conversion types

3. Create conversion templates:
   - `templates/audit/conversion-spec.md.template` (all 6 phases)
   - `templates/audit/agent-to-skill-conversion.md.template`
   - `templates/audit/script-extraction-spec.md.template`

4. Create `commands/generate-conversion-spec.md`:
   - Routes to conversion-spec-generator agent
   - Argument parsing

5. Test conversion spec generation:
   - Generate spec for pre-skills project
   - Verify spec is actionable
   - Check before/after examples

**Deliverables:**
- `/faber-agent:generate-conversion-spec` functional
- Generates complete specifications
- All conversion types supported

**Validation:**
- Generated specs are actionable
- Before/after examples accurate
- Effort estimates reasonable

### Phase 5: Workflow Creation - Manager Agents (Week 5)

**Objectives:**
- Create workflow-creator agent
- Create workflow-designer skill
- Create Manager agent templates
- Create Director skill template

**Tasks:**
1. Create `agents/workflow-creator.md`:
   - FABER workflow structure
   - Interactive requirements gathering
   - Generates all workflow components

2. Create `skills/workflow-designer/`:
   - `SKILL.md` with design operations
   - `workflow/multi-phase.md` - Steps for 7-phase workflows
   - `workflow/builder-debugger.md` - Steps for Builder/Debugger pattern

3. Create Manager agent templates:
   - `templates/workflow/manager-agent-7-phase.md.template`:
     - Full tool access metadata
     - 7-phase workflow structure
     - State management patterns
     - User interaction examples
     - Skill coordination logic

   - `templates/workflow/manager-agent-builder-debugger.md.template`:
     - Coordinates Inspector, Debugger, Builder
     - Knowledge base integration
     - Issue log tracking
     - Approval workflows

4. Create Director skill template:
   - `templates/workflow/director-skill-pattern-expansion.md.template`:
     - Simple skill interface
     - Pattern expansion operations
     - Parallelism calculation
     - No orchestration logic

5. Test Manager agent creation:
   - Create 7-phase Manager agent
   - Create Builder/Debugger Manager agent
   - Verify proper tool access
   - Validate structure

**Deliverables:**
- Can create Manager agents (not skills)
- Can create Director skills
- Generated agents have correct structure

**Validation:**
- Generated Manager is agent (not skill)
- Tool access correct
- Structure validates

### Phase 6: Workflow Creation - Skills & Scripts (Week 6)

**Objectives:**
- Create specialist skill templates
- Create script templates
- Create validators
- Create workflow command

**Tasks:**
1. Create specialist skill templates:
   - `templates/workflow/specialist-skill-with-scripts.md.template`:
     - Scripts directory structure
     - Workflow files for multi-step
     - Proper invocation patterns

   - `templates/workflow/inspector-skill.md.template`:
     - Observer role (WHAT IS)
     - Factual observations only
     - Targeted check types

   - `templates/workflow/debugger-skill.md.template`:
     - Analyzer role (WHY + HOW)
     - Knowledge base integration
     - Confidence scoring

   - `templates/workflow/builder-skill.md.template`:
     - Executor role (operations)
     - Multiple operations pattern
     - State updates

   - `templates/workflow/troubleshooting-kb.md.template`:
     - Issue type structure
     - Symptoms, root causes, fixes
     - Success rates

2. Create `skills/workflow-validator/`:
   - `SKILL.md` with validation operations
   - Validates generated workflows

3. Create validators:
   - `validators/manager-agent-validator.sh`:
     - Ensures Manager is agent
     - Checks tool access
     - Validates structure

   - `validators/director-skill-validator.sh`:
     - Ensures Director is skill
     - Validates simple interface

   - `validators/skill-script-validator.sh`:
     - Validates script structure
     - Checks invocation patterns

4. Create `commands/create-workflow.md`:
   - Routes to workflow-creator agent
   - Pattern selection argument

5. Test complete workflow creation:
   - Create workflow with Manager + Skills + Scripts
   - Verify script structure
   - Validate all components
   - Test generated workflow works

**Deliverables:**
- `/faber-agent:create-workflow` functional
- Creates complete workflows
- Skills have script structure
- All validations pass

**Validation:**
- Generated workflows pass all validators
- Script structure correct
- Manager agents have proper capabilities

### Phase 7: Migration Guides (Week 7)

**Objectives:**
- Create all migration guides
- Create usage guides
- Create examples
- Update README

**Tasks:**
1. Create migration guides in `docs/migration/`:
   - `agent-chain-to-skills.md`:
     - Step-by-step conversion
     - Identifying chain start/end
     - Creating Manager agent
     - Converting agents to skills

   - `hybrid-agent-splitting.md`:
     - Identifying hybrid agents
     - Separating concerns
     - Creating Manager + Skill

   - `script-extraction.md`:
     - Identifying deterministic logic
     - Writing scripts properly
     - Integrating with skills

   - `context-optimization.md`:
     - Workflow file patterns
     - Conditional loading
     - Measuring improvements

2. Create usage guides in `docs/guides/`:
   - `auditing-projects.md`:
     - Running audits
     - Understanding reports
     - Interpreting findings

   - `generating-conversion-specs.md`:
     - Using conversion specs
     - Following migration steps
     - Testing conversions

   - `creating-workflows.md`:
     - Creating from scratch
     - Pattern selection
     - Best practices

3. Create examples in `docs/examples/`:
   - Complete audit → conversion → creation flow
   - Before/after for each anti-pattern
   - Real project conversions

4. Update `README.md`:
   - Document new capabilities
   - Show audit → spec → creation flow
   - Link to documentation

**Deliverables:**
- Complete documentation suite
- Step-by-step guides for all use cases
- Examples for all patterns

**Validation:**
- Documentation complete and accurate
- Examples tested and working
- README updated

### Phase 8: Integration & Testing (Week 8)

**Objectives:**
- End-to-end testing
- Integration validation
- Final documentation review
- Production readiness

**Tasks:**
1. End-to-end testing on real projects:
   - Test audit on pre-skills project
   - Generate conversion spec
   - Verify spec is actionable
   - Test workflow creation
   - Verify validation catches violations

2. Integration testing:
   - Audit → Spec → Creation flow
   - All tools use consistent standards
   - Validators work across tools
   - Documentation cross-references correct

3. Performance testing:
   - Audit performance on large projects
   - Spec generation time
   - Workflow creation time

4. Documentation review:
   - All documentation complete
   - Cross-references valid
   - Examples accurate
   - README comprehensive

5. Final validation:
   - All commands work
   - All validators catch violations
   - All templates generate valid output
   - All scripts execute correctly

**Deliverables:**
- Fully tested plugin
- Complete documentation
- Production-ready release

**Validation:**
- All tests pass
- Documentation approved
- Ready for use

## Success Criteria

### Standards Compliance
- ✅ agentic-control-plane-standards-2.md corrected (Manager-as-Agent documented)
- ✅ All templates generate Manager as agent (never skill)
- ✅ All examples follow Manager-as-Agent architecture
- ✅ Pre-skills migration patterns documented

### Audit Capabilities
- ✅ Detects Manager/Director pattern (correct vs. inverted)
- ✅ Detects agent chains (pre-skills pattern) ⭐ CRITICAL
- ✅ Detects hybrid agents (orchestration + execution)
- ✅ Identifies script extraction opportunities (file ops, API calls, transforms, validation)
- ✅ Recommends context optimizations (workflow files, conditional loading)
- ✅ Produces comprehensive audit reports with all findings

### Conversion Spec Generation
- ✅ Generates complete migration specifications
- ✅ Includes all conversion types (Manager/Director, agent chains, hybrid splits, script extraction)
- ✅ Provides before/after code examples for every component
- ✅ Prioritizes: Critical → Important → Optimization
- ✅ Estimates effort per phase
- ✅ Includes testing and rollback strategies

### Workflow Creation
- ✅ Creates Manager as AGENT (with full tool access)
- ✅ Creates Director as SKILL (for batch operations)
- ✅ Creates Specialist Skills with script structure
- ✅ Supports 7-phase workflows
- ✅ Supports Builder/Debugger pattern
- ✅ Generated workflows pass all validation
- ✅ Proper state management built-in

### Integration
- ✅ Audit → Conversion Spec → Creation flow works end-to-end
- ✅ All tools use consistent standards
- ✅ Validators work across audit and creation
- ✅ Documentation complete and cross-referenced
- ✅ Examples tested and accurate

## File Changes Summary

### New Files (~60 files):

**Standards & Documentation (15 files):**
- `docs/standards/manager-as-agent-pattern.md`
- `docs/standards/agent-to-skill-migration.md`
- `docs/standards/agentic-control-plane-standards-2.md` (corrected)
- `docs/patterns/manager-as-agent.md`
- `docs/patterns/director-skill.md`
- `docs/patterns/builder-debugger.md`
- `docs/patterns/pre-skills-migration.md`
- `docs/migration/agent-chain-to-skills.md`
- `docs/migration/hybrid-agent-splitting.md`
- `docs/migration/script-extraction.md`
- `docs/migration/context-optimization.md`
- `docs/guides/auditing-projects.md`
- `docs/guides/generating-conversion-specs.md`
- `docs/guides/creating-workflows.md`
- `docs/examples/pre-skills-conversion-complete.md`

**Commands (3 files):**
- `commands/audit-project.md`
- `commands/generate-conversion-spec.md`
- `commands/create-workflow.md`

**Agents (3 files):**
- `agents/project-auditor.md`
- `agents/conversion-spec-generator.md`
- `agents/workflow-creator.md`

**Skills (10 skills with workflows and scripts, ~25 files):**
- `skills/project-analyzer/` (SKILL.md, workflow/, 4 scripts)
- `skills/agent-chain-analyzer/` (SKILL.md, 4 scripts)
- `skills/script-extractor/` (SKILL.md, 5 scripts)
- `skills/hybrid-agent-detector/` (SKILL.md, 3 scripts)
- `skills/architecture-validator/` (SKILL.md, scripts/)
- `skills/context-optimizer/` (SKILL.md, 4 scripts)
- `skills/gap-analyzer/` (SKILL.md, scripts/)
- `skills/spec-generator/` (SKILL.md, workflow/)
- `skills/workflow-designer/` (SKILL.md, workflow/multi-phase.md, workflow/builder-debugger.md)
- `skills/workflow-validator/` (SKILL.md)

**Templates (13 files):**
- `templates/audit/project-audit-report.md.template`
- `templates/audit/conversion-spec.md.template`
- `templates/audit/gap-analysis.md.template`
- `templates/audit/agent-to-skill-conversion.md.template`
- `templates/audit/script-extraction-spec.md.template`
- `templates/workflow/manager-agent-7-phase.md.template`
- `templates/workflow/manager-agent-builder-debugger.md.template`
- `templates/workflow/director-skill-pattern-expansion.md.template`
- `templates/workflow/specialist-skill-with-scripts.md.template`
- `templates/workflow/inspector-skill.md.template`
- `templates/workflow/debugger-skill.md.template`
- `templates/workflow/builder-skill.md.template`
- `templates/workflow/troubleshooting-kb.md.template`

**Validators (3 files):**
- `validators/manager-agent-validator.sh`
- `validators/director-skill-validator.sh`
- `validators/skill-script-validator.sh`

**Modified Files (2 files):**
- `README.md` (add audit, conversion, workflow creation docs)
- `.claude-plugin/plugin.json` (update version, add commands)

## Timeline

- **Week 1:** Standards correction and documentation
- **Week 2:** Basic audit infrastructure
- **Week 3:** Advanced audit (agent chains, script extraction)
- **Week 4:** Conversion spec generation
- **Week 5:** Workflow creation - Manager agents
- **Week 6:** Workflow creation - Skills and scripts
- **Week 7:** Migration guides and usage documentation
- **Week 8:** Integration testing and final validation

**Total: 8 weeks for complete implementation**

## Risk Assessment

### High Priority Risks

**Risk 1: Agent Chain Detection False Positives**
- **Probability:** Medium
- **Impact:** High (incorrect migration recommendations)
- **Mitigation:**
  - Multiple heuristics for detection
  - Manual validation of audit reports
  - Conservative classification (flag uncertain cases)
  - User review before spec generation

**Risk 2: Script Extraction Complexity**
- **Probability:** Medium
- **Impact:** Medium (incomplete extraction recommendations)
- **Mitigation:**
  - Start with simple, clear patterns
  - Extensive testing on real projects
  - Conservative recommendations
  - Manual review required for complex cases

**Risk 3: Context Load Misunderstanding**
- **Probability:** Low
- **Impact:** High (user rejects approach)
- **Mitigation:**
  - Clear documentation of trade-offs
  - Emphasis on single-op no-change
  - Show wall-clock time benefits
  - Provide opt-out for pure sequential

### Medium Priority Risks

**Risk 4: Standards Correction Breaking Existing Docs**
- **Probability:** Medium
- **Impact:** Medium (temporary confusion)
- **Mitigation:**
  - Comprehensive review before commit
  - Update all cross-references
  - Clear changelog of corrections
  - Migration guide for any breaking changes

**Risk 5: Conversion Spec Complexity**
- **Probability:** Medium
- **Impact:** Low (specs too complex to follow)
- **Mitigation:**
  - Clear step-by-step instructions
  - Before/after code examples
  - Testing section per phase
  - Effort estimates

### Low Priority Risks

**Risk 6: Validator False Negatives**
- **Probability:** Low
- **Impact:** Low (invalid patterns not caught)
- **Mitigation:**
  - Comprehensive test suite
  - Multiple validation layers
  - Regular validator updates

## Future Enhancements (Post-Implementation)

### Phase 2 Features

**1. Automated Migration (Semi-Automated with Approval)**
- Not just specs, but actual code generation
- User approval at each phase
- Automatic testing of conversions

**2. Interactive Audit Dashboard**
- Visual representation of dependency graphs
- Interactive exploration of anti-patterns
- Live comparison before/after

**3. Conversion Progress Tracking**
- Track which conversions completed
- Resume partial migrations
- Version control integration

**4. Batch Project Analysis**
- Analyze multiple projects at once
- Organization-wide anti-pattern reports
- Prioritization across projects

### Phase 3 Features

**5. Machine Learning Pattern Detection**
- Learn from successful conversions
- Improve detection accuracy over time
- Custom pattern definitions

**6. Live Migration Mode**
- Step-by-step guided migration
- Real-time validation
- Rollback on failures

**7. Conversion Testing Framework**
- Automated testing of converted workflows
- Performance comparison before/after
- Regression detection

## Appendix A: Example Audit Report

```markdown
# Project Audit Report

**Project:** myproject
**Audit Date:** 2025-01-15
**Auditor:** faber-agent v2.0.0

## Executive Summary

**Overall Status:** ⚠️ NEEDS MIGRATION

This project was created before the skills abstraction existed and follows a pre-skills agent chain pattern. Significant refactoring required to align with current Manager-as-Agent architecture.

**Priority:** HIGH - Agent chain pattern detected
**Estimated Migration Effort:** 2-3 days
**Estimated Context Savings:** 45% (180K → 100K tokens per workflow)

## Architecture Analysis

### Current Pattern: Pre-Skills Agent Chain

**Detected Chain:**
```
Command: /myproject-process
  ↓
Agent: validate-input-agent.md (executor)
  ↓
Agent: transform-data-agent.md (executor)
  ↓
Agent: save-results-agent.md (executor)
  ↓
Agent: notify-completion-agent.md (executor)
```

**Issues:**
- ❌ No Manager agent (orchestration distributed)
- ❌ No skills directory (agents doing execution)
- ❌ Heavy context usage (4 agents × 45K tokens = 180K)
- ❌ No script abstraction (logic in agent prompts)

### Target Pattern: Manager-as-Agent + Skills

**Recommended Structure:**
```
Command: /myproject-process
  ↓
Manager Agent: myproject-process-manager.md
  - Orchestrates 7-phase workflow
  - State management
  - User interaction
  ↓
  ├─ Skill: myproject-input-validator (script-backed)
  ├─ Skill: myproject-data-transformer (script-backed)
  ├─ Skill: myproject-result-saver (script-backed)
  └─ Skill: myproject-notifier (script-backed)
```

## Component Inventory

**Commands:** 1
- `/myproject-process`

**Agents:** 4
- `validate-input-agent.md` → Should be skill
- `transform-data-agent.md` → Should be skill
- `save-results-agent.md` → Should be skill
- `notify-completion-agent.md` → Should be skill

**Skills:** 0 (should have 4-5)

**Scripts:** 0 (should have 4-5)

## Anti-Patterns Detected

### 1. Agent Chain (Pre-Skills Pattern) ⭐ CRITICAL

**Severity:** CRITICAL
**Impact:** HIGH context usage, poor maintainability

**Details:**
- 4 agents in sequential chain
- Each agent invokes next via Task tool
- No central orchestration
- No state management
- No script abstraction

**Recommendation:** Consolidate to Manager + Skills (see conversion spec)

### 2. Inline Deterministic Logic (No Script Abstraction)

**Severity:** HIGH
**Impact:** Context bloat, code duplication

**Extraction Opportunities:**
- `validate-input-agent.md` lines 45-67: File validation logic → `scripts/validate-input-files.sh`
- `transform-data-agent.md` lines 23-89: jq transformations → `scripts/transform-data.sh`
- `save-results-agent.md` lines 12-34: File operations → `scripts/save-results.sh`

**Estimated Savings:** 2,340 tokens

### 3. No Context Optimization

**Severity:** MEDIUM
**Impact:** Unnecessary context loading

**Recommendations:**
- Create workflow files for conditional loading
- Split operations into targeted files
- Use workflow/*.md pattern

## Context Efficiency Analysis

**Current:**
- Workflow execution: 180K tokens
- Per-operation: 45K tokens average
- Total for 4 steps: 180K tokens

**After Migration:**
- Manager agent: 25K tokens
- Skills: 15K tokens each (4 × 15K = 60K)
- Scripts: 0K (outside context)
- Total: 85K tokens

**Savings:** 95K tokens (53% reduction)

## Migration Roadmap

### Phase 1: Create Manager Agent
- Create `agents/myproject-process-manager.md`
- Implement 7-phase workflow structure
- Add state management
- Estimated: 4 hours

### Phase 2: Convert Agents to Skills
- Create `skills/myproject-input-validator/`
- Create `skills/myproject-data-transformer/`
- Create `skills/myproject-result-saver/`
- Create `skills/myproject-notifier/`
- Estimated: 6 hours

### Phase 3: Extract Scripts
- Create 4 scripts in `skills/*/scripts/`
- Update skills to invoke scripts
- Estimated: 4 hours

### Phase 4: Update Command
- Update `/myproject-process` to route to Manager
- Remove old agent invocations
- Estimated: 1 hour

### Phase 5: Testing & Validation
- Test complete workflow
- Validate against standards
- Performance testing
- Estimated: 3 hours

**Total Effort:** 18 hours (2-3 days)

## Next Steps

1. ✅ Review this audit report
2. ⏭️  Generate detailed conversion specification:
   ```
   /faber-agent:generate-conversion-spec myproject
   ```
3. ⏭️  Follow conversion spec step-by-step
4. ⏭️  Test converted workflow
5. ⏭️  Validate with standards

## Questions or Issues?

Contact: [maintainer] or see docs/guides/auditing-projects.md
```

## Appendix B: Example Conversion Spec (Excerpt)

```markdown
# Conversion Specification: myproject

**Generated:** 2025-01-15
**Project:** myproject
**Pattern:** Pre-Skills Agent Chain → Manager-as-Agent + Skills

## Phase 2: Agent Chain Consolidation

### Overview

Convert 4-agent chain to 1 Manager Agent + 4 Skills with script abstraction.

**Current State:**
- `validate-input-agent.md` (executor)
- `transform-data-agent.md` (executor)
- `save-results-agent.md` (executor)
- `notify-completion-agent.md` (executor)

**Target State:**
- `agents/myproject-process-manager.md` (orchestrator)
- `skills/myproject-input-validator/` (skill + script)
- `skills/myproject-data-transformer/` (skill + script)
- `skills/myproject-result-saver/` (skill + script)
- `skills/myproject-notifier/` (skill + script)

### Step 2.1: Create Manager Agent

**File:** `.claude/agents/myproject-process-manager.md`

**Before:** (does not exist)

**After:**
```markdown
---
name: myproject-process-manager
description: Orchestrates data processing workflow with validation, transformation, and notification
allowed_tools: [Read, Write, Skill, AskUserQuestion, Bash, Edit, Grep, Glob]
---

# myproject-process-manager

<CONTEXT>
You are the Process Manager for MyProject. You orchestrate the complete data processing workflow: validation → transformation → saving → notification.

You maintain state throughout the workflow and coordinate specialist skills to accomplish tasks.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS use skills for execution (NEVER do work directly)
2. ALWAYS maintain state across workflow phases
3. ALWAYS get user approval before executing changes
4. ALWAYS verify completion after operations
5. NEVER proceed after failures without user decision
</CRITICAL_RULES>

<WORKFLOW>

## 7-Phase Workflow

### Phase 1: INSPECT
- Invoke `myproject-input-validator` skill with check operation
- Collect validation results

### Phase 2: ANALYZE
- If validation failures, analyze issues
- Determine if proceeding is safe
- Identify required fixes

### Phase 3: PRESENT
- Show validation results to user
- Explain any issues found
- Recommend next steps

### Phase 4: APPROVE
- Get user decision: proceed, fix issues, or abort
- Use AskUserQuestion for approval

### Phase 5: EXECUTE
- Invoke `myproject-data-transformer` skill
- Invoke `myproject-result-saver` skill
- Invoke `myproject-notifier` skill
- Update state.json after each step

### Phase 6: VERIFY
- Re-invoke `myproject-input-validator` to verify results
- Check that all files created correctly

### Phase 7: REPORT
- Show final status to user
- Summarize what was done
- Provide next steps if any

</WORKFLOW>

</CONTEXT>
```

**Testing:**
```bash
# Test Manager agent creation
/faber-agent:create-workflow myproject-process --pattern multi-phase

# Validate structure
validators/manager-agent-validator.sh .claude/agents/myproject-process-manager.md
```

**Estimated Effort:** 3 hours

### Step 2.2: Convert validate-input-agent to Skill

**Current File:** `.claude/agents/validate-input-agent.md`

**New Structure:**
```
.claude/skills/myproject-input-validator/
├── SKILL.md
├── scripts/
│   └── validate-input-files.sh
└── README.md
```

**SKILL.md:**
```markdown
---
skill: myproject-input-validator
purpose: Validate input files before processing
layer: Validator
---

# myproject-input-validator

## Purpose
Validates input data files for format, schema, and completeness.

## Operations

### validate
Check input files for issues.

**Invocation:**
```json
{
  "operation": "validate",
  "input_path": "path/to/input",
  "checks": ["format", "schema", "completeness"]
}
```

**Implementation:**
Invokes: `scripts/validate-input-files.sh --input $input_path --checks $checks`

**Output:**
```json
{
  "status": "success" | "error",
  "valid": true | false,
  "issues": [...]
}
```
```

**scripts/validate-input-files.sh:**
```bash
#!/bin/bash
# Validate input files for processing

set -euo pipefail

# Parse arguments
INPUT_PATH=""
CHECKS="format,schema,completeness"

while [[ $# -gt 0 ]]; do
  case $1 in
    --input) INPUT_PATH="$2"; shift 2;;
    --checks) CHECKS="$2"; shift 2;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

# Validate required arguments
if [[ -z "$INPUT_PATH" ]]; then
  echo "Error: --input required"
  exit 1
fi

# Check format
if [[ "$CHECKS" == *"format"* ]]; then
  # Validate CSV format
  for file in "$INPUT_PATH"/*.csv; do
    if ! head -1 "$file" | grep -q ","; then
      echo "Format error: $file not valid CSV"
      exit 1
    fi
  done
fi

# Check schema (simplified)
if [[ "$CHECKS" == *"schema"* ]]; then
  # Validate required columns
  for file in "$INPUT_PATH"/*.csv; do
    header=$(head -1 "$file")
    if ! echo "$header" | grep -q "id,name,value"; then
      echo "Schema error: $file missing required columns"
      exit 1
    fi
  done
fi

# Check completeness
if [[ "$CHECKS" == *"completeness"* ]]; then
  # Ensure files exist
  file_count=$(ls "$INPUT_PATH"/*.csv 2>/dev/null | wc -l)
  if [[ $file_count -eq 0 ]]; then
    echo "Completeness error: No input files found"
    exit 1
  fi
fi

echo "Validation passed: All checks successful"
exit 0
```

**Migration Steps:**
1. Create skill directory structure
2. Copy validation logic from agent to script
3. Create SKILL.md that invokes script
4. Test skill in isolation
5. Archive old agent file

**Testing:**
```bash
# Test skill
Skill: myproject-input-validator
Input: {"operation": "validate", "input_path": "test/input"}

# Validate structure
validators/skill-script-validator.sh .claude/skills/myproject-input-validator
```

**Estimated Effort:** 2 hours

### Steps 2.3-2.5: Convert Remaining Agents
[Similar detailed conversion steps for each agent...]

**Total Phase 2 Effort:** 10 hours
```

---

**Status:** APPROVED - Ready for Implementation
**Next Steps:** Begin Phase 1 (Standards Correction) in Week 1
