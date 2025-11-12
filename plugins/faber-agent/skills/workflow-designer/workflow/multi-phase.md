# Design Multi-Phase Workflow Architecture

**Purpose:** Design architecture for workflows with sequential phases (typically 7-phase pattern)

**Pattern:** Manager-as-Agent with 7-phase workflow structure

## Step 1: Analyze Requirements

From requirements, extract:
- Workflow name
- Purpose/domain
- Number of phases
- Operations per phase
- User interaction points
- Batch operation needs
- Data storage requirements

## Step 2: Design Phase Structure

**Standard 7-Phase Pattern:**

1. **INSPECT/GATHER** - Collect input data
2. **ANALYZE/VALIDATE** - Process and validate data
3. **PRESENT** - Show results to user
4. **APPROVE** - Get user approval/decision
5. **EXECUTE** - Perform main work
6. **VERIFY** - Validate results
7. **REPORT** - Provide summary and next steps

**Adapt phases based on domain:**

**Data Processing:**
- INSPECT → Load data
- VALIDATE → Check schemas
- PRESENT → Show validation
- APPROVE → User confirms
- PROCESS → Transform data
- VERIFY → Validate output
- REPORT → Summary stats

**API Integration:**
- INSPECT → Check API status
- ANALYZE → Validate credentials
- PRESENT → Show plan
- APPROVE → User confirms
- EXECUTE → Make API calls
- VERIFY → Check responses
- REPORT → API interaction summary

**Infrastructure:**
- INSPECT → Scan current state
- ANALYZE → Detect changes needed
- PRESENT → Show plan
- APPROVE → User confirms deployment
- EXECUTE → Deploy changes
- VERIFY → Health checks
- REPORT → Deployment summary

## Step 3: Determine Components Needed

**Manager Agent (ALWAYS required):**
- Name: `{workflow-name}-manager`
- Location: `agents/{workflow-name}-manager.md`
- Type: **AGENT** (not skill)
- Tool Access: **FULL** (Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion)
- Pattern: 7-phase workflow
- Responsibilities:
  - Orchestrate all phases
  - Invoke specialist skills
  - Maintain workflow state
  - User interaction (AskUserQuestion)
  - Decision logic

**Director Skill (if batch operations):**
- Name: `{workflow-name}-director`
- Location: `skills/{workflow-name}-director/SKILL.md`
- Type: **SKILL** (not agent)
- Purpose: Pattern expansion for batch processing
- Responsibilities:
  - Expand single item to multiple items
  - Calculate parallelism
  - NO orchestration logic

**Specialist Skills (based on operations):**

For each distinct operation, create skill:

**Validator Skills:**
- Schema validation
- Format checking
- Data integrity

**Transformer Skills:**
- Data transformation
- Format conversion
- Aggregation

**Processor Skills:**
- Complex calculations
- Data enrichment
- Filtering

**API Client Skills:**
- External API calls
- Authentication
- Response parsing

**File Handler Skills:**
- File operations
- Directory management
- Archiving

**Reporter Skills:**
- Report generation
- Statistics calculation
- Visualization prep

## Step 4: Map Operations to Skills

For each phase in workflow:

**Phase 1: INSPECT**
- Read input files → file-handler skill
- Validate existence → validator skill
- Parse metadata → parser skill

**Phase 2: ANALYZE/VALIDATE**
- Validate schema → schema-validator skill
- Check format → format-checker skill
- Detect issues → issue-detector skill

**Phase 3: PRESENT**
- Format results → formatter skill
- Generate summary → summarizer skill
- (Manager handles presentation to user)

**Phase 4: APPROVE**
- (Manager uses AskUserQuestion - no skill needed)

**Phase 5: EXECUTE**
- Transform data → transformer skill
- Process records → processor skill
- Enrich data → enricher skill

**Phase 6: VERIFY**
- Validate output → output-validator skill
- Check completeness → completeness-checker skill
- Run tests → test-runner skill

**Phase 7: REPORT**
- Calculate stats → stats-calculator skill
- Generate report → report-generator skill
- (Manager handles final presentation)

## Step 5: Design Script Structure

For each specialist skill, determine scripts needed:

**Validator Skill:**
```
skills/schema-validator/
├── SKILL.md
└── scripts/
    ├── validate-json-schema.sh
    ├── check-required-fields.sh
    └── validate-data-types.sh
```

**Transformer Skill:**
```
skills/data-transformer/
├── SKILL.md
└── scripts/
    ├── transform-to-json.sh
    ├── normalize-values.sh
    └── aggregate-records.sh
```

**Script Template:**
```bash
#!/bin/bash
set -euo pipefail

# {script-name}.sh
# {Description}

# Input parameters
PARAM1="${1:?Error: Missing parameter}"

# Validation
if [[ ! -f "$PARAM1" ]]; then
  echo '{"status": "error", "error": "file_not_found"}' >&2
  exit 1
fi

# Main logic
# ...

# Output JSON
cat <<EOF
{
  "status": "success",
  "result": "..."
}
EOF
```

## Step 6: Design State Management

**State File:** `.{plugin}/workflow/{workflow-name}/{timestamp}/state.json`

**State Structure:**
```json
{
  "workflow_phase": "execute",
  "phases_completed": ["inspect", "validate", "present", "approve"],
  "timestamp": "2025-01-11T15:30:00Z",
  "workflow_data": {
    "input_file": "data.json",
    "record_count": 1000,
    "validation_results": {...}
  },
  "phase_results": {
    "inspect": {...},
    "validate": {...},
    "present": {...}
  }
}
```

## Step 7: Build Architecture Object

Return complete architecture:

```json
{
  "status": "success",
  "architecture": {
    "workflow_name": "data-processor",
    "pattern": "multi-phase",
    "components": {
      "manager_agent": {
        "name": "data-processor-manager",
        "file": "agents/data-processor-manager.md",
        "pattern": "7-phase",
        "tool_access": ["Bash", "Skill", "Read", "Write", "Glob", "Grep", "AskUserQuestion"],
        "phases": [
          {
            "number": 1,
            "name": "INSPECT",
            "description": "Load and validate input data files",
            "skills_invoked": ["file-handler", "metadata-parser"]
          },
          {
            "number": 2,
            "name": "VALIDATE",
            "description": "Validate data schema and format",
            "skills_invoked": ["schema-validator", "format-checker"]
          },
          {
            "number": 3,
            "name": "PRESENT",
            "description": "Present validation results to user",
            "skills_invoked": ["result-formatter"]
          },
          {
            "number": 4,
            "name": "APPROVE",
            "description": "Get user approval to proceed",
            "skills_invoked": [],
            "user_interaction": true
          },
          {
            "number": 5,
            "name": "PROCESS",
            "description": "Transform and enrich data",
            "skills_invoked": ["data-transformer", "data-enricher"]
          },
          {
            "number": 6,
            "name": "VERIFY",
            "description": "Verify output data quality",
            "skills_invoked": ["output-validator", "quality-checker"]
          },
          {
            "number": 7,
            "name": "REPORT",
            "description": "Generate summary report",
            "skills_invoked": ["stats-calculator", "report-generator"]
          }
        ],
        "state_management": {
          "enabled": true,
          "location": ".{plugin}/workflow/data-processor/{timestamp}/state.json"
        }
      },
      "director_skill": {
        "name": "data-processor-director",
        "file": "skills/data-processor-director/SKILL.md",
        "needed": true,
        "purpose": "Expand pattern for batch processing multiple files",
        "operations": ["expand-to-batch", "calculate-parallelism"]
      },
      "specialist_skills": [
        {
          "name": "file-handler",
          "file": "skills/file-handler/SKILL.md",
          "purpose": "Handle file operations (read, validate existence)",
          "type": "processor",
          "scripts": ["read-file.sh", "check-exists.sh", "get-metadata.sh"]
        },
        {
          "name": "schema-validator",
          "file": "skills/schema-validator/SKILL.md",
          "purpose": "Validate data against JSON schemas",
          "type": "validator",
          "scripts": ["validate-schema.sh", "check-required-fields.sh"]
        },
        {
          "name": "data-transformer",
          "file": "skills/data-transformer/SKILL.md",
          "purpose": "Transform data to target format",
          "type": "transformer",
          "scripts": ["transform-format.sh", "normalize-values.sh", "aggregate.sh"]
        },
        {
          "name": "output-validator",
          "file": "skills/output-validator/SKILL.md",
          "purpose": "Validate transformed output",
          "type": "validator",
          "scripts": ["validate-output.sh", "check-completeness.sh"]
        },
        {
          "name": "stats-calculator",
          "file": "skills/stats-calculator/SKILL.md",
          "purpose": "Calculate statistics for reporting",
          "type": "processor",
          "scripts": ["calculate-stats.sh", "generate-summary.sh"]
        }
      ],
      "command": {
        "name": "process-data",
        "file": "commands/process-data.md",
        "description": "Process and validate data files",
        "routes_to": "data-processor-manager (agent)"
      }
    },
    "file_structure": {
      "agents": [
        "agents/data-processor-manager.md"
      ],
      "skills": [
        "skills/data-processor-director/SKILL.md",
        "skills/file-handler/SKILL.md",
        "skills/schema-validator/SKILL.md",
        "skills/data-transformer/SKILL.md",
        "skills/output-validator/SKILL.md",
        "skills/stats-calculator/SKILL.md"
      ],
      "commands": [
        "commands/process-data.md"
      ],
      "scripts": [
        "skills/file-handler/scripts/read-file.sh",
        "skills/file-handler/scripts/check-exists.sh",
        "skills/file-handler/scripts/get-metadata.sh",
        "skills/schema-validator/scripts/validate-schema.sh",
        "skills/schema-validator/scripts/check-required-fields.sh",
        "skills/data-transformer/scripts/transform-format.sh",
        "skills/data-transformer/scripts/normalize-values.sh",
        "skills/data-transformer/scripts/aggregate.sh",
        "skills/output-validator/scripts/validate-output.sh",
        "skills/output-validator/scripts/check-completeness.sh",
        "skills/stats-calculator/scripts/calculate-stats.sh",
        "skills/stats-calculator/scripts/generate-summary.sh"
      ]
    },
    "totals": {
      "agents": 1,
      "skills": 6,
      "commands": 1,
      "scripts": 12,
      "total_files": 20
    }
  }
}
```

## Validation Checklist

Before returning architecture, verify:

- [ ] Manager is **Agent** (not Skill)
- [ ] Manager has **full tool access** (all 7 tools)
- [ ] Manager has 7-phase workflow structure
- [ ] Director is **Skill** (if batch operations)
- [ ] Director has NO orchestration logic
- [ ] All specialists are **Skills**
- [ ] All skills have scripts/ directory
- [ ] Command routes to **Agent** (not Skill)
- [ ] State management defined
- [ ] All file paths valid

## Output

Return architecture object as shown in Step 7.
