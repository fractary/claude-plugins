# Example: CSV Data Processor Workflow

## Overview

This example demonstrates creating a complete CSV data processing workflow using the FABER Agent workflow creation system. The workflow validates, transforms, and loads CSV data with user approval gates.

---

## Creating the Workflow

### Step 1: Run Creation Command

```bash
/fractary-faber-agent:create-workflow csv-processor \
  --pattern multi-phase \
  --description "Process and validate CSV files with transformations" \
  --domain data \
  --batch
```

### Step 2: Generated Structure

```
plugins/faber-agent/
├── agents/
│   └── csv-processor-manager.md          # 7-phase orchestrator
├── skills/
│   ├── csv-processor-director/           # Batch coordinator
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── expand-batch.sh
│   │       └── calculate-parallelism.sh
│   ├── csv-fetcher/                      # Phase 1: Fetch CSV
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── fetch-csv.sh
│   ├── csv-validator/                    # Phase 2: Validate
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── validate-csv.sh
│   ├── csv-transformer/                  # Phase 5: Transform
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── transform-csv.sh
│   └── csv-loader/                       # Phase 6: Load
│       ├── SKILL.md
│       └── scripts/
│           └── load-csv.sh
└── commands/
    └── csv-processor.md                  # Command router
```

---

## Implementation

### Manager Agent (Orchestrator)

**agents/csv-processor-manager.md:**

```markdown
---
name: csv-processor-manager
description: Orchestrates CSV processing workflow with validation and transformation
tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion
model: inherit
---

<CONTEXT>
You are a Manager Agent orchestrating CSV data processing workflows.

You coordinate:
- CSV fetching (csv-fetcher skill)
- Schema validation (csv-validator skill)
- Data transformation (csv-transformer skill)
- Data loading (csv-loader skill)

You manage state across all phases and get user approval before processing.
</CONTEXT>

<CRITICAL_RULES>
1. **Full Orchestration**
   - YOU own the complete workflow
   - YOU manage state across phases
   - YOU handle errors and decide retry/abort

2. **Delegate Execution**
   - NEVER do work directly
   - ALWAYS invoke skills for execution
   - Skills return results to YOU

3. **User Approval**
   - ALWAYS present validation results before processing
   - ALWAYS use AskUserQuestion for critical decisions
   - NEVER proceed without approval
</CRITICAL_RULES>

<WORKFLOW>

## Phase 1: FETCH (Retrieve CSV Data)

Use @skill-fractary-faber-agent:csv-fetcher to fetch CSV file:

```json
{
  "operation": "fetch-csv",
  "parameters": {
    "source_path": "{{SOURCE_PATH}}",
    "output_path": "/tmp/csv-raw-{{TIMESTAMP}}.csv"
  }
}
```

Store result:
```json
{
  "state": {
    "phase": "fetch",
    "fetch": {
      "source": "{{SOURCE_PATH}}",
      "raw_file": "/tmp/csv-raw-2025-01-11.csv",
      "row_count": 1000,
      "size_bytes": 45231,
      "timestamp": "2025-01-11T16:30:00Z"
    }
  }
}
```

## Phase 2: VALIDATE (Schema and Data Validation)

Use @skill-fractary-faber-agent:csv-validator to validate:

```json
{
  "operation": "validate-csv",
  "parameters": {
    "csv_file": "{{state.fetch.raw_file}}",
    "schema_file": "schemas/data-schema.json",
    "validation_rules": {
      "required_columns": ["id", "name", "email"],
      "email_format": true,
      "unique_ids": true
    }
  }
}
```

Store result:
```json
{
  "state": {
    "phase": "validate",
    "validation": {
      "valid": true,
      "schema_errors": [],
      "data_errors": [
        {
          "row": 45,
          "column": "email",
          "error": "invalid_format",
          "value": "not-an-email"
        }
      ],
      "warnings": ["missing optional field: phone"],
      "error_count": 1,
      "warning_count": 1,
      "valid_rows": 999
    }
  }
}
```

## Phase 3: PRESENT (Show Validation Results)

Present validation results to user:

```
📊 CSV Validation Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Source: {{state.fetch.source}}
Total rows: {{state.fetch.row_count}}

✓ Schema: Valid
✓ Valid rows: {{state.validation.valid_rows}}

❌ Errors: {{state.validation.error_count}}
  - Row 45: Invalid email format

⚠ Warnings: {{state.validation.warning_count}}
  - Missing optional field: phone

Options:
1. Process valid rows (skip row 45)
2. Fix errors and retry
3. Cancel processing
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Phase 4: APPROVE (Get User Decision)

Use AskUserQuestion:

```json
{
  "questions": [{
    "question": "Validation found 1 error (invalid email). How should we proceed?",
    "header": "Process CSV",
    "multiSelect": false,
    "options": [
      {
        "label": "Process valid rows (999/1000)",
        "description": "Skip row 45 with invalid email, process remaining 999 rows"
      },
      {
        "label": "Fix errors manually",
        "description": "Stop and allow manual correction of row 45"
      },
      {
        "label": "Cancel processing",
        "description": "Abort the workflow"
      }
    ]
  }]
}
```

Store decision:
```json
{
  "state": {
    "approval": {
      "decision": "process_valid_rows",
      "skip_invalid": true,
      "timestamp": "2025-01-11T16:31:00Z"
    }
  }
}
```

If user cancels → ABORT workflow and proceed to Phase 7 (REPORT)

## Phase 5: TRANSFORM (Data Transformation)

If approved, use @skill-fractary-faber-agent:csv-transformer:

```json
{
  "operation": "transform-csv",
  "parameters": {
    "input_file": "{{state.fetch.raw_file}}",
    "output_file": "/tmp/csv-transformed-{{TIMESTAMP}}.csv",
    "transformations": {
      "skip_invalid_rows": true,
      "normalize_emails": true,
      "add_timestamp": true,
      "deduplicate": true
    }
  }
}
```

Store result:
```json
{
  "state": {
    "phase": "transform",
    "transform": {
      "input_rows": 1000,
      "output_rows": 985,
      "skipped_rows": 1,
      "duplicates_removed": 14,
      "output_file": "/tmp/csv-transformed-2025-01-11.csv",
      "transformations_applied": 4
    }
  }
}
```

## Phase 6: LOAD (Data Loading)

Use @skill-fractary-faber-agent:csv-loader:

```json
{
  "operation": "load-csv",
  "parameters": {
    "input_file": "{{state.transform.output_file}}",
    "destination": "{{DESTINATION_PATH}}",
    "load_options": {
      "create_backup": true,
      "overwrite": false
    }
  }
}
```

Store result:
```json
{
  "state": {
    "phase": "load",
    "load": {
      "destination": "/data/processed/output-2025-01-11.csv",
      "rows_loaded": 985,
      "backup_created": "/data/backup/output-2025-01-11-backup.csv",
      "load_time_seconds": 2
    }
  }
}
```

## Phase 7: REPORT (Summary)

```
✅ COMPLETED: CSV Processing
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Source: {{state.fetch.source}}
Destination: {{state.load.destination}}

Fetch: 1000 rows retrieved
Validate: 1 error, 1 warning
User Decision: Process valid rows
Transform: 985 rows (1 skipped, 14 duplicates removed)
Load: 985 rows loaded successfully

Backup: {{state.load.backup_created}}
Processing Time: {{TOTAL_TIME}} seconds
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

</WORKFLOW>
```

---

## Skill Implementations

### CSV Fetcher Skill

**skills/csv-fetcher/SKILL.md:**

```markdown
---
skill: csv-fetcher
purpose: Fetch CSV files from various sources
---

<OPERATIONS>

## fetch-csv

Fetch CSV file from source location.

**Input:**
- `source_path`: Path to source CSV file
- `output_path`: Path for output file

**Process:**
1. Execute: `scripts/fetch-csv.sh "$source_path" "$output_path"`
2. Parse script output
3. Return fetch results

**Output:**
```json
{
  "status": "success",
  "fetch": {
    "source": "/data/input.csv",
    "raw_file": "/tmp/csv-raw-2025-01-11.csv",
    "row_count": 1000,
    "size_bytes": 45231,
    "timestamp": "2025-01-11T16:30:00Z"
  }
}
```

</OPERATIONS>
```

**skills/csv-fetcher/scripts/fetch-csv.sh:**

```bash
#!/bin/bash
set -euo pipefail

# fetch-csv.sh
# Fetch CSV file and return metadata

SOURCE_PATH="${1:?Error: Source path required}"
OUTPUT_PATH="${2:?Error: Output path required}"

# Validate source exists
if [[ ! -f "$SOURCE_PATH" ]]; then
  cat <<EOF
{
  "status": "error",
  "error": "source_not_found",
  "source": "$SOURCE_PATH"
}
EOF
  exit 1
fi

# Copy file to output location
cp "$SOURCE_PATH" "$OUTPUT_PATH"

# Count rows (excluding header)
ROW_COUNT=$(($(wc -l < "$OUTPUT_PATH") - 1))

# Get file size
SIZE_BYTES=$(stat -f%z "$OUTPUT_PATH" 2>/dev/null || stat -c%s "$OUTPUT_PATH")

# Output JSON
cat <<EOF
{
  "status": "success",
  "fetch": {
    "source": "$SOURCE_PATH",
    "raw_file": "$OUTPUT_PATH",
    "row_count": $ROW_COUNT,
    "size_bytes": $SIZE_BYTES,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
```

### CSV Validator Skill

**skills/csv-validator/scripts/validate-csv.sh:**

```bash
#!/bin/bash
set -euo pipefail

# validate-csv.sh
# Validate CSV schema and data

CSV_FILE="${1:?Error: CSV file required}"
SCHEMA_FILE="${2:?Error: Schema file required}"

# Validate inputs
if [[ ! -f "$CSV_FILE" ]]; then
  echo '{"status": "error", "error": "csv_not_found"}'
  exit 1
fi

if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo '{"status": "error", "error": "schema_not_found"}'
  exit 1
fi

# Extract required columns from schema
REQUIRED_COLS=$(jq -r '.required_columns[]' "$SCHEMA_FILE")

# Validate schema (check required columns exist)
HEADER=$(head -1 "$CSV_FILE")
SCHEMA_ERRORS=()
for col in $REQUIRED_COLS; do
  if ! echo "$HEADER" | grep -q "$col"; then
    SCHEMA_ERRORS+=("Missing required column: $col")
  fi
done

# Validate data (check email format, unique IDs, etc.)
DATA_ERRORS=()
ERROR_COUNT=0

# Example: Check email format in rows
awk -F',' 'NR > 1 {
  if ($3 !~ /@/) {
    print "Row " NR ": Invalid email: " $3
  }
}' "$CSV_FILE" > /tmp/email-errors.txt

if [[ -s /tmp/email-errors.txt ]]; then
  while IFS= read -r line; do
    DATA_ERRORS+=("$line")
    ((ERROR_COUNT++))
  done < /tmp/email-errors.txt
fi

# Count valid rows
TOTAL_ROWS=$(($(wc -l < "$CSV_FILE") - 1))
VALID_ROWS=$((TOTAL_ROWS - ERROR_COUNT))

# Build errors JSON array
ERRORS_JSON="["
if [[ ${#DATA_ERRORS[@]} -gt 0 ]]; then
  for i in "${!DATA_ERRORS[@]}"; do
    ERRORS_JSON+="\"${DATA_ERRORS[$i]}\""
    if [[ $i -lt $((${#DATA_ERRORS[@]} - 1)) ]]; then
      ERRORS_JSON+=","
    fi
  done
fi
ERRORS_JSON+="]"

# Output JSON
cat <<EOF
{
  "status": "success",
  "validation": {
    "valid": $([ $ERROR_COUNT -eq 0 ] && echo "true" || echo "false"),
    "schema_errors": [],
    "data_errors": $ERRORS_JSON,
    "error_count": $ERROR_COUNT,
    "valid_rows": $VALID_ROWS,
    "total_rows": $TOTAL_ROWS
  }
}
EOF
```

---

## Usage Examples

### Example 1: Single File Processing

```bash
/csv-processor /data/customers.csv --output /data/processed/customers-clean.csv
```

**Workflow execution:**
1. Fetch: Read `/data/customers.csv` (1000 rows)
2. Validate: Found 1 email error
3. Present: Show validation summary
4. User approves: "Process valid rows"
5. Transform: Output 999 rows (1 skipped)
6. Load: Write to `/data/processed/customers-clean.csv`
7. Report: Processing complete

### Example 2: Batch Processing

```bash
/csv-processor /data/input/*.csv --batch --parallel 3 --output /data/processed/
```

**Workflow execution:**
1. Director expands batch:
   - Files: `[sales.csv, customers.csv, products.csv]`
   - Parallelism: 3
2. Process each file in parallel:
   - 3 Manager instances running concurrently
   - Each follows 7-phase workflow
3. Aggregate results:
   - Total rows processed: 2,985
   - Total errors: 3
   - Files created: 3

### Example 3: With Custom Schema

```bash
/csv-processor /data/input.csv \
  --schema /schemas/custom-schema.json \
  --output /data/processed/output.csv \
  --transformations "normalize,dedupe,timestamp"
```

**Custom schema (schemas/custom-schema.json):**
```json
{
  "required_columns": ["id", "name", "email", "created_at"],
  "optional_columns": ["phone", "address"],
  "validations": {
    "email_format": true,
    "unique_ids": true,
    "date_format": "ISO8601"
  },
  "transformations": {
    "normalize_emails": true,
    "deduplicate": true,
    "add_timestamp": true
  }
}
```

---

## Testing

### Test Validation

**Test invalid email:**
```bash
echo "id,name,email
1,John,john@example.com
2,Jane,not-an-email
3,Bob,bob@example.com" > /tmp/test.csv

/csv-processor /tmp/test.csv
```

**Expected:**
- Validation finds 1 error (row 2)
- User prompted for decision
- If "process valid rows" → output has 2 rows

### Test Deduplication

**Test duplicate removal:**
```bash
echo "id,name,email
1,John,john@example.com
2,Jane,jane@example.com
1,John,john@example.com" > /tmp/test-dupes.csv

/csv-processor /tmp/test-dupes.csv --transformations dedupe
```

**Expected:**
- Transform: 3 input → 2 output (1 duplicate removed)

---

## Customization

### Add Custom Transformation

**1. Update transformer skill:**

```bash
# Edit skills/csv-transformer/scripts/transform-csv.sh
# Add transformation logic
```

**2. Update schema:**

```json
{
  "transformations": {
    "normalize_emails": true,
    "deduplicate": true,
    "uppercase_names": true  // New transformation
  }
}
```

### Add Custom Validation Rule

**1. Update validator skill:**

```bash
# Edit skills/csv-validator/scripts/validate-csv.sh
# Add validation logic
```

**2. Update schema:**

```json
{
  "validations": {
    "email_format": true,
    "unique_ids": true,
    "phone_format": true  // New validation
  }
}
```

---

## Results

**Workflow characteristics:**
- **7 phases**: Complete data processing lifecycle
- **User approval**: Before processing (Phase 4)
- **Error handling**: Skip invalid rows or abort
- **State management**: Tracked across all phases
- **Batch support**: Process multiple files in parallel

**Context efficiency:**
- Manager: ~8K tokens
- Skills: ~2K tokens each (8K total)
- Scripts: 0 tokens (executed, not in context)
- **Total: ~16K tokens**

**Benefits:**
- ✓ Clear separation of concerns
- ✓ Reusable skills
- ✓ Testable components
- ✓ User control over processing
- ✓ Comprehensive error handling
