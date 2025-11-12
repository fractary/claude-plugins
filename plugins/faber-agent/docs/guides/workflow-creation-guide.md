# Workflow Creation Guide

## Overview

This guide shows how to create new workflows using the FABER Agent workflow creation system. The system automatically generates Manager agents, Director skills, specialist skills, and supporting scripts following the Manager-as-Agent pattern.

---

## Quick Start

### Create a Workflow in 3 Steps

1. **Run the command:**
   ```bash
   /fractary-faber-agent:create-workflow my-workflow --pattern multi-phase --interactive
   ```

2. **Answer questions:**
   - Workflow purpose
   - Number of phases
   - Batch operation needs
   - User interaction requirements

3. **Generated files:**
   ```
   agents/my-workflow-manager.md
   skills/my-workflow-director/SKILL.md
   skills/my-workflow-[specialist]/SKILL.md
   commands/my-workflow.md
   ```

---

## Workflow Patterns

### Pattern 1: Multi-Phase (7-Phase Standard)

**Best for:** Data processing, deployments, migrations, conversions

**Structure:**
```
Phase 1: GATHER/INSPECT    - Collect input data
Phase 2: ANALYZE/VALIDATE  - Process and validate
Phase 3: PRESENT           - Show results to user
Phase 4: APPROVE           - Get user decision
Phase 5: EXECUTE           - Perform main work
Phase 6: VERIFY            - Validate results
Phase 7: REPORT            - Provide summary
```

**Example command:**
```bash
/fractary-faber-agent:create-workflow data-processor \
  --pattern multi-phase \
  --description "Process and validate data files" \
  --domain data
```

**Generated components:**
- **Manager Agent**: `agents/data-processor-manager.md`
  - Orchestrates all 7 phases
  - Manages state across phases
  - Has user approval gate (Phase 4)

- **Specialist Skills**:
  - `skills/data-fetcher/` - Fetch data (Phase 1)
  - `skills/data-validator/` - Validate data (Phase 2)
  - `skills/data-processor/` - Process data (Phase 5)
  - `skills/data-verifier/` - Verify results (Phase 6)

- **Director** (if --batch specified):
  - `skills/data-processor-director/` - Batch coordination

**Use case examples:**
- CSV data processing workflows
- API data migration
- File format conversions
- Configuration deployments

### Pattern 2: Builder/Debugger (Iterative Fixing)

**Best for:** Build processes, test fixing, code quality, debugging

**Structure:**
```
Iteration Loop (max N iterations):
  Phase 1: INSPECT    - Inspector observes state
  Phase 2: ANALYZE    - Debugger diagnoses issues
  → If no issues: REPORT success
  → If issues found:
      Phase 3: PRESENT    - Show findings
      Phase 4: APPROVE    - Get user approval
      Phase 5: BUILD      - Builder applies fixes
      Phase 6: VERIFY     - Inspector re-checks
      → Repeat until resolved or max iterations
```

**Example command:**
```bash
/fractary-faber-agent:create-workflow code-builder \
  --pattern builder-debugger \
  --description "Build code with automatic error fixing" \
  --domain code \
  --max-iterations 5
```

**Generated components:**
- **Manager Agent**: `agents/code-builder-manager.md`
  - Manages iterative loop
  - Tracks issue log across iterations
  - Decides retry/abort

- **Specialist Skills** (3 roles):
  - **Inspector**: `skills/code-inspector/`
    - Role: Observer (WHAT IS)
    - Operations: observe-state, count-errors
    - NO analysis or recommendations

  - **Debugger**: `skills/code-debugger/`
    - Role: Analyzer (WHY + HOW)
    - Operations: diagnose-issues, search-kb, recommend-fixes
    - Confidence scoring (0.0-1.0)

  - **Builder**: `skills/code-builder/`
    - Role: Executor (DO)
    - Operations: apply-fix, build, rollback
    - NO analysis

- **Knowledge Base Template**:
  - `templates/kb/build-errors.md` - Troubleshooting patterns

**Use case examples:**
- TypeScript compilation with error fixing
- Lint error resolution
- Test failure debugging
- Build optimization

### Pattern 3: Simple Workflow (Custom Phases)

**Best for:** Custom workflows that don't fit standard patterns

**Example command:**
```bash
/fractary-faber-agent:create-workflow custom-flow \
  --pattern simple \
  --description "Custom workflow" \
  --phases "fetch,transform,load,verify"
```

**Generates minimal structure:**
- Manager agent with specified phases
- One skill per phase
- No batch support
- No iterative logic

---

## Command Reference

### Basic Usage

```bash
/fractary-faber-agent:create-workflow <workflow-name> [options]
```

### Required Arguments

- `<workflow-name>`: Name of workflow (kebab-case)
  - Good: `data-processor`, `code-builder`, `api-migrator`
  - Bad: `DataProcessor`, `code_builder`, `API Migrator`

### Options

#### `--pattern <pattern>`

Workflow pattern to use:
- `multi-phase`: 7-phase standard workflow (default)
- `builder-debugger`: Iterative fixing workflow
- `simple`: Minimal custom workflow

**Example:**
```bash
--pattern builder-debugger
```

#### `--description <description>`

Human-readable description of workflow:

**Example:**
```bash
--description "Process CSV files and load into database"
```

#### `--domain <domain>`

Domain for workflow categorization:
- `data`: Data processing workflows
- `code`: Code build/test workflows
- `api`: API integration workflows
- `infrastructure`: Infrastructure deployment
- `other`: Custom domain

**Example:**
```bash
--domain data
```

#### `--batch`

Enable batch operations with Director skill:

**Example:**
```bash
/fractary-faber-agent:create-workflow file-processor --batch
```

**Generates:**
- Director skill for batch coordination
- Parallelism calculation
- Batch item expansion

#### `--interactive`

Interactive mode with guided questions:

**Example:**
```bash
/fractary-faber-agent:create-workflow my-workflow --interactive
```

**Questions asked:**
1. Workflow purpose? (data, code, api, infrastructure, other)
2. How many steps? (3-5, 6-8, 9+, iterative)
3. Need user approval gates? (yes/no)
4. Support batch operations? (yes/no)
5. Store data/state? (none, temporary, persistent)

#### `--max-iterations <n>`

Max iterations for builder-debugger pattern:

**Example:**
```bash
/fractary-faber-agent:create-workflow code-fixer \
  --pattern builder-debugger \
  --max-iterations 10
```

**Default:** 5 iterations

---

## Complete Examples

### Example 1: Data Processing Workflow

**Goal:** Process CSV files with validation and transformation

**Command:**
```bash
/fractary-faber-agent:create-workflow csv-processor \
  --pattern multi-phase \
  --description "Process and validate CSV files" \
  --domain data \
  --batch
```

**Generated structure:**
```
agents/csv-processor-manager.md        # 7-phase orchestrator
skills/csv-processor-director/         # Batch coordinator
  SKILL.md
  scripts/
    expand-batch.sh
    calculate-parallelism.sh
skills/csv-fetcher/                    # Phase 1: Fetch CSV
  SKILL.md
  scripts/
    fetch-csv.sh
skills/csv-validator/                  # Phase 2: Validate
  SKILL.md
  scripts/
    validate-csv.sh
skills/csv-processor/                  # Phase 5: Process
  SKILL.md
  scripts/
    process-csv.sh
skills/csv-verifier/                   # Phase 6: Verify
  SKILL.md
  scripts/
    verify-csv.sh
commands/csv-processor.md              # Command router
```

**Usage:**
```bash
# Single file
/csv-processor input.csv --output processed.csv

# Batch processing
/csv-processor *.csv --batch --parallel 3
```

**Workflow:**
1. Fetcher: Read CSV files
2. Validator: Check schema, data types
3. Present: Show validation summary
4. Approve: User decides to proceed
5. Processor: Transform data
6. Verifier: Validate output
7. Report: Summary with stats

### Example 2: Code Build with Error Fixing

**Goal:** Build TypeScript code with automatic error fixing

**Command:**
```bash
/fractary-faber-agent:create-workflow ts-builder \
  --pattern builder-debugger \
  --description "Build TypeScript with automatic error fixes" \
  --domain code \
  --max-iterations 5
```

**Generated structure:**
```
agents/ts-builder-manager.md           # Iterative loop manager
skills/ts-inspector/                   # Observer role
  SKILL.md
  scripts/
    observe-errors.sh
    count-issues.sh
skills/ts-debugger/                    # Analyzer role
  SKILL.md
  scripts/
    diagnose-error.sh
    search-kb.sh
    recommend-fix.sh
  kb/
    type-errors.md
    import-errors.md
skills/ts-builder/                     # Executor role
  SKILL.md
  scripts/
    apply-fix.sh
    build-project.sh
    rollback.sh
commands/ts-builder.md                 # Command router
```

**Usage:**
```bash
/ts-builder /path/to/project --auto-fix
```

**Workflow (per iteration):**
1. Inspector: Run tsc, count errors (factual only)
2. Debugger: Analyze error types, search KB, recommend fixes
3. Present: Show errors and recommendations
4. Approve: User approves fixes
5. Builder: Apply recommended fixes
6. Verify: Inspector re-counts errors
7. Loop: Repeat if errors remain (max 5 iterations)

**Example iteration:**
```
Iteration 1:
  Inspector: "Found 3 type errors in src/index.ts"
  Debugger: "Root cause: missing type annotations. Confidence: 0.95"
  Approve: User approves fix
  Builder: "Applied type annotations to 3 locations"
  Verify: Inspector: "Found 0 errors"
  Result: Success after 1 iteration
```

### Example 3: API Migration

**Goal:** Migrate data from API v1 to API v2

**Command:**
```bash
/fractary-faber-agent:create-workflow api-migrator \
  --pattern multi-phase \
  --description "Migrate data from API v1 to v2" \
  --domain api \
  --interactive
```

**Interactive prompts:**
```
? Workflow purpose: api
? How many steps: 6-8 (multi-phase)
? Need user approval gates: yes
? Support batch operations: yes
? Store data/state: temporary
```

**Generated structure:**
```
agents/api-migrator-manager.md
skills/api-migrator-director/
skills/api-v1-fetcher/
skills/data-transformer/
skills/api-v2-uploader/
skills/migration-verifier/
commands/api-migrator.md
```

**Usage:**
```bash
/api-migrator --source-api v1.example.com --target-api v2.example.com --batch
```

---

## Customization

### After Generation

Generated files are templates - customize for your needs:

#### 1. Update Manager Agent

**agents/my-workflow-manager.md:**
```markdown
<WORKFLOW>

## Phase 1: GATHER

Use @skill-my-plugin:data-fetcher:

```json
{
  "operation": "fetch-data",
  "parameters": {
    "source": "{{SOURCE_API}}",        ← Add your parameters
    "format": "json",
    "auth_token": "{{AUTH_TOKEN}}"     ← Add authentication
  }
}
```

Store result in state:
```json
{
  "state": {
    "phase": "gather",
    "data": {
      "record_count": "{{skill_result.data.count}}",
      "data_file": "{{skill_result.data.file}}"
    }
  }
}
```
</WORKFLOW>
```

#### 2. Implement Skill Scripts

**skills/data-fetcher/scripts/fetch-data.sh:**
```bash
#!/bin/bash
set -euo pipefail

SOURCE_API="${1:?Error: Source API required}"
AUTH_TOKEN="${2:?Error: Auth token required}"

# Fetch data from API
curl -X GET "$SOURCE_API/data" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -o /tmp/data.json

# Count records
RECORD_COUNT=$(jq '. | length' /tmp/data.json)

# Output JSON
cat <<EOF
{
  "status": "success",
  "data": {
    "count": $RECORD_COUNT,
    "file": "/tmp/data.json",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
```

#### 3. Add Knowledge Base (Builder/Debugger pattern)

**skills/my-debugger/kb/common-errors.md:**
```markdown
# Common Build Errors

## Error: Missing Type Annotation

**Symptoms:**
- Error TS7006: Parameter implicitly has an 'any' type

**Root Cause:**
- TypeScript strict mode requires explicit type annotations
- Function parameter missing type

**Fix:**
```typescript
// Before
function process(data) { ... }

// After
function process(data: ProcessData) { ... }
```

**Confidence:** 0.95
**Success Rate:** 98%
```

#### 4. Update Command Router

**commands/my-workflow.md:**
```markdown
Parse arguments:
- `--source <path>`: Source file/directory
- `--output <path>`: Output location
- `--batch`: Enable batch processing
- `--parallel <n>`: Parallelism level

Route to @agent-my-plugin:my-workflow-manager with:
```json
{
  "source": "{{SOURCE}}",
  "output": "{{OUTPUT}}",
  "batch_mode": {{BATCH}},
  "parallelism": {{PARALLEL}}
}
```
```

---

## Validation

### Validate Generated Workflow

After generation, validate the workflow:

```bash
/fractary-faber-agent:validate my-workflow
```

**Checks:**
- ✓ Manager is Agent (not Skill)
- ✓ Manager has all 7 tools
- ✓ Director is Skill (not Agent)
- ✓ Specialist skills have scripts/
- ✓ All scripts are executable
- ✓ No orchestration in skills
- ✓ No Manager-as-Skill inversion

**Example output:**
```
✅ Workflow Validation: my-workflow

Manager Agent (agents/my-workflow-manager.md):
  ✓ Location correct (agents/ directory)
  ✓ All 7 tools present
  ✓ Has <WORKFLOW> section
  ✓ Has <CRITICAL_RULES> section
  ✓ Pattern: Manager-as-Agent ✓

Director Skill (skills/my-workflow-director/SKILL.md):
  ✓ Location correct (skills/ directory)
  ✓ No orchestration logic
  ✓ Simple pattern expansion only
  ✓ Pattern: Director-as-Skill ✓

Specialist Skills:
  skills/data-fetcher/
    ✓ Has scripts/ directory
    ✓ Scripts executable
    ✓ Operations reference scripts
  skills/data-validator/
    ✓ Has scripts/ directory
    ✓ Scripts executable
    ✓ Operations reference scripts

Overall: ✅ PASSED (0 issues, 0 warnings)
```

---

## Best Practices

### 1. Naming Conventions

**Workflow names:**
- Use kebab-case: `data-processor`, `code-builder`
- Be descriptive: `csv-to-json-converter` not `converter`
- Include domain: `api-migrator`, `infra-deployer`

**Agent names:**
- Format: `{workflow-name}-manager`
- Example: `data-processor-manager`

**Director names:**
- Format: `{workflow-name}-director`
- Example: `data-processor-director`

**Skill names:**
- Format: `{workflow-name}-{role}`
- Examples: `data-fetcher`, `data-validator`, `data-processor`

### 2. Phase Design

**Keep phases focused:**
```markdown
# ✓ Good - focused phase
## Phase 1: GATHER
Use data-fetcher skill to retrieve data

# ❌ Bad - doing too much
## Phase 1: GATHER
1. Fetch data
2. Validate schema
3. Transform format
4. Check duplicates
```

**Separate concerns:**
- GATHER: Just fetch data
- VALIDATE: Separate phase for validation
- TRANSFORM: Separate phase for transformation

### 3. State Management

**Store minimal state:**
```json
{
  "state": {
    "phase": "gather",
    "data_file": "/tmp/data.json",      ✓ Path to data
    "record_count": 1000                ✓ Metadata
    // ❌ Don't store: entire data content
  }
}
```

**Use references:**
```json
{
  "state": {
    "artifacts": {
      "raw_data": "/tmp/raw.json",      ✓ File path
      "processed": "/tmp/processed.json"
    }
  }
}
```

### 4. Error Handling

**Add error handling to scripts:**
```bash
#!/bin/bash
set -euo pipefail

# Trap errors
trap 'echo "{\"status\": \"error\", \"line\": $LINENO}" >&2; exit 1' ERR

# Validate inputs
SOURCE="${1:?Error: Source required}"
if [[ ! -f "$SOURCE" ]]; then
  echo '{"status": "error", "error": "file_not_found"}'
  exit 1
fi
```

**Handle errors in Manager:**
```markdown
## Phase 5: EXECUTE

Use processor skill.

If skill returns error:
- Store error in state
- Proceed to Phase 7 (REPORT) with failure
- DO NOT continue to Phase 6
```

### 5. User Approval

**Always ask for critical operations:**
```markdown
## Phase 4: APPROVE

Use AskUserQuestion for:
- Destructive operations (delete, overwrite)
- Cost-incurring operations (cloud deployments)
- Irreversible operations (data migrations)

```json
{
  "questions": [{
    "question": "About to delete 1000 records. Proceed?",
    "header": "Confirm",
    "options": [...]
  }]
}
```
```

---

## Troubleshooting

### Issue: "Manager missing tools"

**Error:**
```
❌ Manager missing critical tools: AskUserQuestion
```

**Fix:**
Add all 7 tools to agent frontmatter:
```yaml
---
name: my-manager
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
---
```

### Issue: "Director has orchestration"

**Error:**
```
❌ Director has <WORKFLOW> section (anti-pattern)
```

**Fix:**
Director should only expand patterns:
```markdown
---
skill: my-director
---

## expand-to-batch

Calculate batch parameters and return list.

NO orchestration logic here.
```

### Issue: "Scripts not executable"

**Error:**
```
⚠ Script not executable: fetch-data.sh
```

**Fix:**
```bash
chmod +x skills/*/scripts/*.sh
```

### Issue: "Skill has orchestration"

**Error:**
```
❌ Skill has Phase 1-7 structure (should be in Agent)
```

**Fix:**
Move workflow to Agent, skill should only have operations:
```markdown
# ❌ Wrong (in Skill)
## Phase 1: GATHER
## Phase 2: ANALYZE

# ✓ Correct (in Agent)
<WORKFLOW>
## Phase 1: GATHER
Use @skill-data-fetcher
</WORKFLOW>

# ✓ Correct (in Skill)
<OPERATIONS>
## fetch-data
Execute: scripts/fetch-data.sh
</OPERATIONS>
```

---

## Next Steps

- **Implement scripts**: Add bash logic to generated scripts
- **Test workflow**: Run end-to-end with sample data
- **Add KB articles**: For builder-debugger patterns
- **Customize phases**: Adjust for specific needs
- **Add error handling**: Improve robustness
- **Document usage**: Add examples to README

For migration guides, see:
- [Agent Chain Migration](../migration/agent-chain-to-skills.md)
- [Hybrid Agent Splitting](../migration/hybrid-agent-splitting.md)
- [Script Extraction](../migration/script-extraction.md)
- [Manager Inversion Fix](../migration/manager-inversion-fix.md)
