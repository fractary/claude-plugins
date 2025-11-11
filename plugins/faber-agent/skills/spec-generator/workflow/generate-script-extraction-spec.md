# Generate Script Extraction Conversion Specification

**Purpose:** Create detailed conversion specification for inline logic anti-pattern

**Target:** Extract deterministic logic from prompts to bash scripts

## Step 1: Analyze Inline Logic

1. **Read skill or agent file:** `{file_path}`

2. **Identify inline logic patterns:**

   **Bash Commands (should be in scripts):**
   - `grep`, `awk`, `sed`, `cut`, `sort`, `uniq`
   - `find`, `ls`, `wc`, `head`, `tail`
   - `jq`, `curl`, `wget`
   - `cp`, `mv`, `rm`, `mkdir`, `chmod`, `chown`

   **Algorithms (should be in scripts):**
   - "for each..." loops described in text
   - "step 1, step 2, step 3..." sequences
   - Data transformations described procedurally
   - Calculations and aggregations
   - Validation checks and rules

   **Data Processing (should be in scripts):**
   - JSON parsing and manipulation
   - CSV/TSV processing
   - Text transformations
   - Format conversions
   - Schema validation

3. **Exclude legitimate orchestration:**
   - `Invoke:` skill calls (correct)
   - `Use the @skill` references (correct)
   - `AskUserQuestion` usage (correct)
   - `Phase N:` workflow structure (correct)
   - High-level workflow descriptions (correct)

4. **Calculate context impact:**
   - Count inline logic instances
   - Estimate tokens per instance (~500-2000 tokens)
   - Calculate total inline logic tokens
   - Estimate script tokens (30% of original - compression factor)
   - Calculate savings (70% reduction per operation)

## Step 2: Design Script Structure

1. **Group related operations:**
   - File operations → `file-ops.sh`
   - Data validation → `validate.sh`
   - Data transformation → `transform.sh`
   - API interactions → `api-call.sh`
   - Calculations → `calculate.sh`

2. **Design script interface:**
   - Input parameters (command-line args)
   - Output format (JSON, structured text)
   - Error handling (exit codes, error messages)
   - Documentation (comments, usage examples)

3. **Script template:**
   ```bash
   #!/bin/bash
   set -euo pipefail

   # {script-name}.sh
   # {Description of what this script does}

   # Input parameters
   PARAM1="${1:?Error: Missing parameter 1}"
   PARAM2="${2:-default_value}"

   # Validation
   if [[ ! -f "$PARAM1" ]]; then
     echo '{"status": "error", "error": "file_not_found"}' >&2
     exit 1
   fi

   # Main logic
   # ... deterministic operations ...

   # Output
   cat <<EOF
   {
     "status": "success",
     "result": "..."
   }
   EOF
   ```

## Step 3: Build Before/After Examples

1. **BEFORE - Inline Logic (Anti-pattern):**
   ```markdown
   ## Operation: Validate Data

   Execute:
   1. Read the data file
   2. For each line in the file:
      - Parse the JSON
      - Check if required fields exist
      - Validate field types
      - Validate field values against schema
      - If validation fails, add to errors list
   3. Calculate total errors
   4. If errors > 0, return failure
   5. Otherwise, return success

   Use grep to find all JSON files:
   ```bash
   find . -name "*.json" -type f
   ```

   Use jq to parse and validate:
   ```bash
   jq -r '.data[] | select(.id != null) | .id' file.json
   ```

   Calculate statistics with awk:
   ```bash
   awk '{sum+=$1} END {print sum/NR}' data.txt
   ```

   Problems:
   - ~1,500 tokens for procedural description
   - ~300 tokens for bash commands
   - ~200 tokens for validation rules
   - Total: ~2,000 tokens loaded every invocation
   - Logic executed in LLM context (slow, unreliable)
   ```

2. **AFTER - Script Extraction:**
   ```markdown
   ## Operation: Validate Data

   Use script:
   ```bash
   ./scripts/validate-data.sh "{data_file}"
   ```

   Script handles:
   - JSON parsing
   - Field validation
   - Schema checking
   - Error aggregation
   - Statistics calculation

   Returns JSON:
   ```json
   {
     "status": "success|error",
     "total_records": 1000,
     "valid_records": 995,
     "errors": [...],
     "stats": {...}
   }
   ```

   Benefits:
   - ~200 tokens for operation description
   - ~0 tokens for script execution (runs outside LLM)
   - 1,800 token savings (90% reduction)
   - Deterministic, fast, testable
   ```

## Step 4: Create Conversion Steps

### Phase 1: Preparation (0.5 days)

1. Create feature branch
2. Back up current file
3. Create scripts directory
4. List all inline logic to extract

### Phase 2: Extract Logic to Scripts (1-3 days)

For each inline logic pattern:

1. **Create script file:** `scripts/{operation}.sh`

2. **Extract logic:**
   - Copy bash commands from prompt
   - Copy procedural steps as code
   - Add error handling
   - Add input validation
   - Add JSON output

3. **Make executable:**
   ```bash
   chmod +x scripts/{operation}.sh
   ```

4. **Test script:**
   ```bash
   ./scripts/{operation}.sh "test-input"
   # Verify output format
   # Test error cases
   # Test edge cases
   ```

5. **Document in SKILL.md:**
   ```markdown
   ## {operation-name}

   Description of operation.

   **Input:**
   - `param1`: Description
   - `param2`: Description

   **Process:**
   Execute: `scripts/{operation}.sh "{param1}" "{param2}"`

   **Output:**
   ```json
   {
     "status": "success",
     "result": "..."
   }
   ```
   ```

### Phase 3: Update Skill/Agent File (0.5-1 day)

1. **Replace inline logic with script invocation:**

   **BEFORE:**
   ```markdown
   1. Parse the JSON
   2. For each item:
      - Validate schema
      - Transform data
      - Calculate stats
   3. Aggregate results
   ```

   **AFTER:**
   ```markdown
   Execute: `scripts/process-data.sh "{input_file}" "{output_file}"`
   ```

2. **Update operation descriptions:**
   - Keep high-level description
   - Remove procedural details
   - Reference script for implementation
   - Document input/output format

### Phase 4: Testing (0.5-1 day)

1. **Script testing:**
   - Test each script independently
   - Verify correct output format
   - Test error handling
   - Test edge cases

2. **Integration testing:**
   - Test skill/agent with new scripts
   - Verify all operations work
   - Check error handling
   - Regression test

3. **Context verification:**
   - Measure context before/after
   - Verify reduction matches estimate
   - Document actual savings

### Phase 5: Cleanup (0.5 days)

1. Remove old inline logic comments
2. Update documentation
3. Commit changes

### Total Effort: {estimated_effort_days} days (typically 2-6 days)

## Step 5: Define Testing Criteria

### Script Testing

- [ ] Each script executes successfully
- [ ] Scripts handle errors gracefully
- [ ] Scripts return proper JSON format
- [ ] Scripts validate input parameters
- [ ] Scripts are idempotent (safe to re-run)

### Context Testing

- [ ] Inline logic tokens: ~{inline_tokens}K (before)
- [ ] Script reference tokens: ~{reference_tokens}K (after)
- [ ] Savings: ~{savings}K tokens ({percentage}% reduction)
- [ ] Scripts execute outside LLM (0 context cost)

### Functional Testing

- [ ] All operations produce same results
- [ ] Performance improved (scripts faster than LLM)
- [ ] Error handling equivalent or better
- [ ] No regressions in functionality

### Code Quality

- [ ] Scripts follow bash best practices
- [ ] Set `set -euo pipefail` for safety
- [ ] Proper error messages
- [ ] Clear variable names
- [ ] Comments explain complex logic

## Step 6: Populate Template

Use `script-extraction-spec.md.template` and fill in:

- **Entity name:** `{entity_name}`
- **File path:** `{file_path}`
- **Conversion type:** Inline Logic → Script Extraction
- **Inline logic instances:** Count with types
- **Patterns detected:** Bash, algorithms, data processing
- **Current context:** Tokens consumed by inline logic
- **Target context:** Tokens after extraction
- **Context savings:** Reduction amount and percentage
- **Scripts to create:** List with operations
- **Conversion steps:** Full phase breakdown
- **Testing criteria:** Validation checklist
- **Effort estimate:** Total days
- **Before/after examples:** Code snippets showing transformation

## Step 7: Special Considerations

### Compression Estimate

Inline logic in prompts is verbose:
- Procedural descriptions: 500-2000 tokens
- Code examples: 100-500 tokens
- Validation rules: 200-800 tokens

Scripts are compact:
- Reference to script: 20-50 tokens
- Script execution: 0 tokens (outside LLM)
- Typical compression: 70-95%

### When NOT to Extract

Keep in prompts if:
- High-level orchestration description
- Decision logic (not deterministic)
- User interaction flow
- Workflow structure
- Error handling strategy (description, not implementation)

Extract to scripts if:
- Bash commands
- File operations
- Data transformations
- Calculations
- API calls
- Validation checks
- Any deterministic algorithm

## Output

Return complete specification with emphasis on:
- TOKEN REDUCTION: 70-95% savings per operation
- DETERMINISM: Scripts are predictable and testable
- PERFORMANCE: Scripts execute faster than LLM
- MAINTAINABILITY: Logic in one place, not scattered in prompts
