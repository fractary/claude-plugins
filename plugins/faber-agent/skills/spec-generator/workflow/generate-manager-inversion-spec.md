# Generate Manager Inversion Conversion Specification

**Purpose:** Create detailed conversion specification for Manager-as-Skill anti-pattern

**Target:** Convert orchestration skill to Manager-as-Agent with proper tool access

## Step 1: Analyze Current Implementation

1. **Read skill file:** `skills/{entity_name}/SKILL.md`

2. **Identify manager characteristics:**
   - Orchestration logic (coordinates multiple operations)
   - Workflow phases (multi-step processes)
   - User interaction needs (should use AskUserQuestion)
   - State management (tracks progress)
   - Decision-making (conditional logic)

3. **Identify tool needs:**
   - Currently uses: Skill tool only (limited)
   - Actually needs: Skill, AskUserQuestion, Read, Write, Bash, Grep, Glob

4. **Extract execution logic:**
   - File operations → Move to skills
   - Data processing → Move to skills
   - API calls → Move to skills

## Step 2: Design Target Architecture

1. **Design Manager Agent:**
   - Name: `{entity_name}.md` (note: agent, not manager in name if entity already indicates purpose)
   - Location: `agents/{entity_name}.md`
   - Tool access: Full toolset (Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion)
   - Workflow: Extract from current skill's orchestration logic

2. **Design Supporting Skills:**
   - For each execution operation in current skill:
     - Create new skill: `skills/{operation-name}/SKILL.md`
     - Extract logic to scripts
     - Define clear interface

## Step 3: Build Before/After Examples

1. **BEFORE - Manager as Skill (Anti-pattern):**
   ```
   Command: /manage-{entity}
     ↓
   WRONG: Skill: {entity_name} (trying to orchestrate)
     - Limited to Skill tool only
     - Cannot ask user questions
     - Cannot manage state properly
     - Awkward workflow hacks

   Problems:
   - Skill shouldn't orchestrate
   - Missing tool access
   - Cannot interact with user
   - Poor error handling
   ```

2. **AFTER - Manager as Agent (Correct):**
   ```
   Command: /manage-{entity}
     ↓
   CORRECT: Agent: {entity_name}.md (proper orchestration)
     - Full tool access: Skill, AskUserQuestion, Read, Write, Bash
     - Proper workflow phases
     - User interaction points
     - State management
     ↓
     ├─ Skill: {operation1}
     ├─ Skill: {operation2}
     └─ Skill: {operation3}

   Benefits:
   + Proper orchestration capabilities
   + Can ask user for input
   + Better error handling
   + Clean separation of concerns
   ```

## Step 4: Create Conversion Steps

### Phase 1: Preparation (1 day)

1. Create feature branch
2. Back up current skill file
3. Create agent directory structure
4. Plan skill extraction

### Phase 2: Create Manager Agent (1-2 days)

1. **Create agent file:** `agents/{entity_name}.md`

2. **Define frontmatter with full tools:**
   ```yaml
   ---
   name: {entity_name}
   description: {description from current skill}
   tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
   model: inherit
   ---
   ```

3. **Extract orchestration logic:**
   - Copy workflow structure from skill
   - Add user interaction points
   - Add state management
   - Improve error handling

### Phase 3: Extract Execution to Skills (1-2 days)

1. For each execution operation:
   - Create skill directory: `skills/{operation}/`
   - Create SKILL.md with operation definition
   - Create scripts/ directory
   - Extract deterministic logic to scripts

2. Test each skill independently

### Phase 4: Update Command Routing (0.5 days)

1. Modify command to route to agent (not skill)
2. Update command documentation

### Phase 5: Testing (1 day)

1. Test agent orchestration
2. Test user interaction
3. Test error handling
4. Verify all operations work

### Phase 6: Cleanup (0.5 days)

1. Delete old skill file
2. Update documentation
3. Commit changes

### Total Effort: {estimated_effort_days} days (typically 3-7 days)

## Step 5: Define Testing Criteria

### Functional Testing

- [ ] Manager agent orchestrates all operations
- [ ] User interaction works (AskUserQuestion)
- [ ] State management functional
- [ ] All execution delegated to skills
- [ ] Error handling improved

### Context Testing

- [ ] Measure context change
- [ ] Manager agent: ~45K tokens (new load)
- [ ] Old skill: removed (~10K tokens saved)
- [ ] Net change: +35K tokens (acceptable for proper pattern)
- [ ] Justification: Proper architecture worth the cost

### Pattern Compliance

- [ ] Manager is now Agent (not Skill)
- [ ] Has full tool access
- [ ] Orchestration is clear
- [ ] No execution in agent
- [ ] Follows 7-phase or Builder/Debugger pattern

## Step 6: Populate Template

Use `agent-to-skill-conversion.md.template` and fill in:

- **Entity name:** `{entity_name}`
- **Conversion type:** Manager-as-Skill → Manager-as-Agent
- **Current location:** `skills/{entity_name}/SKILL.md`
- **Target location:** `agents/{entity_name}.md`
- **Justification:** Why this needs to be an agent
- **Tool access needed:** Full list with reasoning
- **Orchestration logic:** Description of workflow
- **Execution extraction:** What moves to skills
- **Context trade-off:** Cost vs benefit analysis
- **Conversion steps:** Full phase breakdown
- **Testing criteria:** Validation checklist

## Output

Return complete specification with emphasis on:
- WHY this must be an agent (orchestration needs)
- WHAT tool access is required and why
- HOW execution is properly separated to skills
- JUSTIFICATION for context increase (proper pattern)
