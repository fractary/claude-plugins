# Generate Hybrid Agent Conversion Specification

**Purpose:** Create detailed conversion specification for Hybrid Agent anti-pattern

**Target:** Separate execution logic from orchestration agent to skills

## Step 1: Analyze Current Hybrid Agent

1. **Read agent file:** `agents/{entity_name}.md`

2. **Categorize tool usage:**
   - **Orchestration tools (correct):** Skill, AskUserQuestion, Task
   - **Execution tools (should be in skills):** Read, Write, Edit, Bash, Grep, Glob, WebFetch

3. **Calculate hybrid score:**
   - Hybrid score = execution_tool_count / total_tool_count
   - If score >= 0.2 (20% execution) → Hybrid agent detected
   - If score >= 0.5 (50% execution) → Primarily executor
   - If score >= 0.8 (80% execution) → Pure executor (severe anti-pattern)

4. **Identify execution patterns:**
   - **File operations:** Read, Write, Edit, cp, mv, mkdir, chmod
   - **Data processing:** jq, awk, sed, grep, parse, transform
   - **API calls:** curl, WebFetch, http requests
   - **System operations:** Bash commands, find, ls

5. **Calculate context metrics:**
   - Current agent size: ~{current_size}K tokens
   - Execution logic portion: ~{execution_portion}K tokens
   - Projected agent size: ~{projected_size}K tokens (orchestration only)
   - New skills total: ~{skills_total}K tokens
   - Context savings: {savings}K tokens ({percentage}% reduction)

## Step 2: Design Separation

1. **Keep in Agent (Orchestration):**
   - Skill invocations
   - User interaction (AskUserQuestion)
   - Workflow decision logic
   - State management
   - Phase coordination

2. **Move to Skills (Execution):**
   - All file operations → `file-operations` skill
   - All data processing → `data-processor` skill
   - All API calls → `api-client` skill
   - All system operations → `system-executor` skill

3. **Design skill structure:**
   - For each pattern type:
     - Create skill: `skills/{pattern-type}/SKILL.md`
     - Create scripts: `skills/{pattern-type}/scripts/*.sh`
     - Define operations and interfaces

## Step 3: Build Before/After Examples

1. **BEFORE - Hybrid Agent (Anti-pattern):**
   ```
   Agent: {entity_name}.md ({current_size}K tokens)

   Contains both orchestration AND execution:

   ❌ Orchestration (correct):
     - Skill invocations
     - User questions
     - Workflow logic

   ❌ Execution (wrong - should be in skills):
     - Read files directly
     - Write files directly
     - Execute bash commands
     - Make API calls
     - Process data with jq/awk

   Problems:
   - Mixed concerns (orchestration + execution)
   - Large context load
   - Difficult to test execution logic
   - Logic not reusable
   - Violates separation of concerns

   Hybrid Score: {hybrid_score} ({percentage}% execution)
   ```

2. **AFTER - Pure Orchestrator + Skills:**
   ```
   Agent: {entity_name}.md ({projected_size}K tokens)

   ✅ Pure Orchestration:
     - Coordinates workflow
     - Invokes skills
     - Asks user questions
     - Manages state
     - Handles errors

   Skills (Execution):
     ├─ {pattern1}-skill ({skill_size}K tokens)
     │   └─ scripts/{operation}.sh (0K - executed)
     ├─ {pattern2}-skill ({skill_size}K tokens)
     │   └─ scripts/{operation}.sh (0K - executed)
     └─ {pattern3}-skill ({skill_size}K tokens)
         └─ scripts/{operation}.sh (0K - executed)

   Benefits:
   + Clear separation of concerns
   + {savings}K token reduction ({percentage}%)
   + Execution logic testable independently
   + Skills reusable across agents
   + Proper architectural pattern

   Hybrid Score: 0.0 (pure orchestrator)
   ```

## Step 4: Create Conversion Steps

### Phase 1: Preparation (1 day)

1. Create feature branch
2. Back up agent file
3. Create skill directories
4. Map execution patterns to skills

### Phase 2: Create Skills with Scripts (2-4 days)

For each execution pattern:

1. **Create skill directory:** `skills/{pattern-name}/`

2. **Create SKILL.md:**
   - Define operations
   - Document inputs/outputs
   - Reference scripts

3. **Extract logic to scripts:**
   - Find all instances in agent
   - Extract to `scripts/{operation}.sh`
   - Make executable
   - Test independently

4. **Examples:**

   **File Operations Skill:**
   ```bash
   skills/file-operations/
   ├── SKILL.md
   └── scripts/
       ├── copy-files.sh
       ├── create-directory.sh
       └── set-permissions.sh
   ```

   **Data Processor Skill:**
   ```bash
   skills/data-processor/
   ├── SKILL.md
   └── scripts/
       ├── parse-json.sh
       ├── transform-data.sh
       └── calculate-stats.sh
   ```

   **API Client Skill:**
   ```bash
   skills/api-client/
   ├── SKILL.md
   └── scripts/
       ├── make-request.sh
       └── parse-response.sh
   ```

### Phase 3: Update Agent (1-2 days)

1. **Remove execution logic from agent:**
   - Delete all Read/Write/Bash tool usage
   - Delete inline file operations
   - Delete inline data processing
   - Delete inline API calls

2. **Add skill invocations:**
   - Replace execution with skill calls
   - Pass data to/from skills
   - Handle skill results

3. **Example transformation:**

   **BEFORE:**
   ```markdown
   ## Phase 2: Process Data

   Execute:
   1. Read data file
   2. Parse JSON with jq
   3. Transform data
   4. Write output
   ```

   **AFTER:**
   ```markdown
   ## Phase 2: Process Data

   Use the @skill-{plugin}:data-processor skill:
   ```json
   {
     "operation": "transform-data",
     "input_file": "{data_file}",
     "output_file": "{output_file}"
   }
   ```

### Phase 4: Testing (1-2 days)

1. Test each skill independently
2. Test agent orchestration
3. Test end-to-end workflow
4. Verify context reduction
5. Regression test all functionality

### Phase 5: Cleanup (0.5 days)

1. Remove execution tools from agent frontmatter
2. Update documentation
3. Commit changes

### Total Effort: {estimated_effort_days} days (typically 4-9 days)

## Step 5: Define Testing Criteria

### Separation Testing

- [ ] Agent contains NO execution tools (Read, Write, Bash, etc.)
- [ ] Agent only uses orchestration tools (Skill, AskUserQuestion)
- [ ] All execution delegated to skills
- [ ] Hybrid score = 0.0 (pure orchestrator)

### Functional Testing

- [ ] Each skill works independently
- [ ] Agent orchestrates skills correctly
- [ ] All original functionality preserved
- [ ] Data flows correctly between skills

### Context Testing

- [ ] Agent size reduced by ~{reduction}K tokens
- [ ] Skills add ~{skills_total}K tokens
- [ ] Net savings: {savings}K tokens
- [ ] Reduction percentage: {percentage}%

### Reusability Testing

- [ ] Skills can be used by other agents
- [ ] Scripts are parameterized (not hardcoded)
- [ ] Interfaces are clear and documented

## Step 6: Populate Template

Use `conversion-spec.md.template` and fill in:

- **Entity name:** `{entity_name}`
- **Conversion type:** Hybrid Agent → Pure Orchestrator + Skills
- **Hybrid score:** `{hybrid_score}` ({percentage}% execution)
- **Execution patterns:** List of patterns detected
- **Current architecture:** Agent with mixed concerns
- **Target architecture:** Agent (orchestration) + Skills (execution)
- **Conversion steps:** Full phase breakdown
- **Skills to create:** List with script details
- **Agent modifications:** What changes in agent file
- **Testing criteria:** Validation checklist
- **Context analysis:** Before/after with savings
- **Effort estimate:** Total days

## Output

Return complete specification with emphasis on:
- SEPARATION: Clear boundary between orchestration and execution
- REUSABILITY: Skills usable across multiple agents
- TESTABILITY: Execution logic testable in isolation
- EFFICIENCY: Context reduction through script extraction
