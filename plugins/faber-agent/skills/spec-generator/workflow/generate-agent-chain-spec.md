# Generate Agent Chain Conversion Specification

**Purpose:** Create detailed conversion specification for agent chain anti-pattern (Agent1 → Agent2 → Agent3 → Agent4)

**Target:** Convert sequential agent chain to Manager-as-Agent + Skills pattern

## Step 1: Analyze Current Chain

1. **Read all agents in chain:**
   - Start from entry point agent
   - Follow Task tool invocations
   - Map complete chain: Agent1 → Agent2 → Agent3 → Agent4

2. **For each agent in chain, identify:**
   - **Orchestration logic:** Decision-making, workflow steps, conditionals
   - **Execution logic:** File operations, API calls, data transformations
   - **Data passed:** What each agent receives and returns
   - **Dependencies:** What each step requires from previous

3. **Calculate context metrics:**
   - Current total: (agent_count × 45K tokens) + (overhead × 10K tokens)
   - Projected total: (1 Manager × 45K) + (skill_count × 5K) + (overhead × 2K)
   - Savings: Current - Projected

## Step 2: Design Target Architecture

1. **Design Manager Agent:**
   - Name: `{entity_name}-manager.md`
   - Location: `agents/{entity_name}-manager.md`
   - Tool access: Skill, AskUserQuestion, Read, Write, Bash, Grep, Glob
   - Workflow: Map agent chain steps to orchestration phases
   - State management: Track progress across skills

2. **Design Skills (one per agent in chain):**
   - For each agent, create corresponding skill:
     - Name: `{entity_name}-{step_name}`
     - Location: `skills/{entity_name}-{step_name}/SKILL.md`
     - Operations: What this step does
     - Scripts: Extract deterministic logic

3. **Design Scripts:**
   - For each skill, identify deterministic operations:
     - File operations → `scripts/file-ops.sh`
     - Data transformations → `scripts/transform.sh`
     - API calls → `scripts/api-call.sh`
     - Validation → `scripts/validate.sh`

## Step 3: Build Before/After Examples

1. **BEFORE - Current Architecture:**
   ```
   Command: /{entity_name}
     ↓
   Agent: step1-agent.md (45K tokens)
     ↓ Task tool invocation
   Agent: step2-agent.md (45K tokens)
     ↓ Task tool invocation
   Agent: step3-agent.md (45K tokens)
     ↓ Task tool invocation
   Agent: step4-agent.md (45K tokens)

   Total Context: {current_total}K tokens
   Sequential execution (slow)
   No shared state management
   Error recovery difficult
   ```

2. **AFTER - Target Architecture:**
   ```
   Command: /{entity_name}
     ↓
   Manager Agent: {entity_name}-manager.md (45K tokens)
     - Orchestrates all steps
     - Maintains workflow state
     - Handles errors gracefully
     - User interaction points
     ↓
     ├─ Skill: {entity_name}-step1 (5K tokens)
     │   └─ scripts/step1-logic.sh (0K - executed)
     ├─ Skill: {entity_name}-step2 (5K tokens)
     │   └─ scripts/step2-logic.sh (0K - executed)
     ├─ Skill: {entity_name}-step3 (5K tokens)
     │   └─ scripts/step3-logic.sh (0K - executed)
     └─ Skill: {entity_name}-step4 (5K tokens)
         └─ scripts/step4-logic.sh (0K - executed)

   Total Context: {projected_total}K tokens
   Context Savings: {savings}K tokens ({percentage}% reduction)
   Better error handling
   Centralized state management
   Maintainable skill units
   ```

## Step 4: Create Conversion Steps

Generate detailed step-by-step instructions:

### Phase 1: Preparation (1-2 days)

1. **Create feature branch:**
   ```bash
   git checkout -b refactor/{entity_name}-to-manager-pattern
   ```

2. **Back up existing files:**
   ```bash
   mkdir -p .backup/{date}/
   cp agents/step*.md .backup/{date}/
   ```

3. **Create directory structure:**
   ```bash
   mkdir -p agents/
   mkdir -p skills/{entity_name}-step1/scripts/
   mkdir -p skills/{entity_name}-step2/scripts/
   # ... for each step
   ```

### Phase 2: Extract Logic (3-5 days)

For each agent in chain:

1. **Read agent file:** `agents/step{N}-agent.md`

2. **Identify execution logic:**
   - Look for: Read tool, Write tool, Bash commands, grep/awk/sed
   - Mark sections for extraction

3. **Create skill file:** `skills/{entity_name}-step{N}/SKILL.md`
   - Copy description and purpose
   - Define operations
   - Document inputs/outputs

4. **Extract to scripts:** `skills/{entity_name}-step{N}/scripts/*.sh`
   - Move bash commands to scripts
   - Move file operations to scripts
   - Move data transformations to scripts
   - Make scripts executable: `chmod +x scripts/*.sh`

5. **Test skill in isolation:**
   ```bash
   # Test script directly
   ./skills/{entity_name}-step{N}/scripts/process.sh "test-input"

   # Test skill invocation
   # (manual test via skill interface)
   ```

### Phase 3: Create Manager Agent (3-5 days)

1. **Create manager agent file:** `agents/{entity_name}-manager.md`

2. **Define frontmatter:**
   ```yaml
   ---
   name: {entity_name}-manager
   description: Orchestrates {entity_name} workflow using {N}-phase pattern
   tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
   model: inherit
   ---
   ```

3. **Define workflow structure:**
   - Map each agent to a phase
   - Define state management
   - Add user approval points
   - Define error handling

4. **Implement skill orchestration:**
   - For each phase, invoke corresponding skill
   - Pass data between phases
   - Track progress in state
   - Handle skill failures

### Phase 4: Update Command Routing (1 day)

1. **Modify command file:** `commands/{entity_name}.md`

2. **Change routing:**
   - OLD: Invokes `step1-agent.md`
   - NEW: Invokes `{entity_name}-manager.md`

3. **Update documentation in command**

### Phase 5: Testing (2-3 days)

1. **Unit testing:**
   - Test each script in isolation
   - Test each skill with mock data
   - Verify all operations work

2. **Integration testing:**
   - Test Manager agent orchestration
   - Test end-to-end workflow
   - Test error handling
   - Test state management

3. **Context verification:**
   - Measure actual context usage
   - Verify reduction matches estimate
   - Document actual savings

### Phase 6: Cleanup (1 day)

1. **Delete old agent files:**
   ```bash
   git rm agents/step1-agent.md
   git rm agents/step2-agent.md
   # ... for each old agent
   ```

2. **Update documentation:**
   - Update README if present
   - Update any architecture docs
   - Update command help text

3. **Commit changes:**
   ```bash
   git add agents/{entity_name}-manager.md
   git add skills/{entity_name}-step*/
   git add commands/{entity_name}.md
   git commit -m "refactor: Convert {entity_name} from agent chain to Manager pattern

   - Extract 4 agents to skills with scripts
   - Create Manager agent for orchestration
   - Reduce context by {savings}K tokens ({percentage}%)
   - Improve error handling and state management"
   ```

### Total Effort Estimate

- Preparation: 1-2 days
- Logic extraction: 3-5 days
- Manager creation: 3-5 days
- Command update: 1 day
- Testing: 2-3 days
- Cleanup: 1 day

**Total: {estimated_effort_days} days**

## Step 5: Define Testing Criteria

Specifications must include clear testing validation:

### Functional Testing

- [ ] Each skill executes successfully with test data
- [ ] Manager agent orchestrates all skills in correct order
- [ ] Data flows correctly between phases
- [ ] Error handling works (test with invalid inputs)
- [ ] State management persists across phases

### Context Testing

- [ ] Measure context before conversion
- [ ] Measure context after conversion
- [ ] Verify reduction matches estimate (±10%)
- [ ] Document actual token counts

### Regression Testing

- [ ] All existing functionality preserved
- [ ] Output matches previous implementation
- [ ] No new bugs introduced
- [ ] Performance acceptable (or improved)

## Step 6: Populate Template

Use the `conversion-spec.md.template` and fill in:

- **Entity name:** `{entity_name}`
- **Conversion type:** Agent Chain → Manager + Skills
- **Current architecture:** Full chain diagram with context
- **Target architecture:** Manager + Skills diagram with context
- **Conversion steps:** Full phase breakdown from Step 4
- **Before/after examples:** Code snippets from Step 3
- **Testing criteria:** Checklist from Step 5
- **Effort estimate:** Total days from Step 4
- **Context savings:** Calculations from Step 1
- **Files to create:** List from Step 2
- **Files to modify:** Command routing from Step 4
- **Files to delete:** Old agent files

## Output

Return complete specification with all sections populated.
