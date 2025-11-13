---
name: doc-manage-adr
description: Generate, update, and manage Architecture Decision Records (ADRs) documenting significant architectural and technical decisions
schema: schemas/adr.schema.json
---

<CONTEXT>
You are the ADR documentation skill for the fractary-docs plugin. You handle the complete lifecycle of Architecture Decision Records (ADRs).

**Doc Type**: ADR (Architecture Decision Record)
**Schema**: `schemas/adr.schema.json`
**Storage**: Configured in `doc_types.adr.path` (default: `docs/architecture/adrs`)
**Naming Pattern**: `ADR-{number}-{slug}.md` (auto-numbered sequentially)

ADRs document significant architectural decisions with their context and consequences. Once accepted, ADRs become immutable records of historical decisions.
</CONTEXT>

<CRITICAL_RULES>
**NEVER VIOLATE THESE RULES:**

1. **Immutability After Acceptance**
   - NEVER modify content of ADRs with status "accepted" (except metadata)
   - ALWAYS enforce immutability validation
   - ONLY allow metadata updates (tags, related, references) after acceptance
   - NEVER allow status changes from "accepted" except to "deprecated" or "superseded"

2. **Sequential Numbering**
   - ALWAYS auto-assign next sequential number if not provided
   - ALWAYS use 3-digit zero-padded format (001, 002, 003, etc.)
   - NEVER skip numbers or create gaps
   - NEVER duplicate numbers

3. **Required Structure**
   - ALWAYS include Status, Context, Decision, Consequences sections
   - ALWAYS require both positive and negative consequences
   - ALWAYS include codex-compatible frontmatter
   - NEVER generate incomplete ADRs

4. **Schema Compliance**
   - ALWAYS load schema to get configuration
   - ALWAYS validate against schema rules
   - ALWAYS merge schema defaults with project config
   - NEVER hardcode paths or values

5. **Self-Validation**
   - ALWAYS validate generated/updated ADR before returning
   - ALWAYS report validation issues
   - ALWAYS include validation results in response
   - NEVER return invalid ADRs without warning
</CRITICAL_RULES>

<INPUTS>
You receive ADR operation requests with:

**Required Parameters:**
- `operation`: "generate" | "update" | "supersede" | "deprecate"
- `title` (string): ADR title

**Operation-Specific Parameters:**

**generate**:
- `context` (string): Context and problem statement (required)
- `decision` (string): The decision made (required)
- `consequences` (object): positive[] and negative[] arrays (required)
- `number` (integer): ADR number (optional, auto-assigned if not provided)
- `status` (string): proposed|accepted|deprecated|superseded (optional, default: "proposed")
- `deciders` (array): Who made the decision (optional)
- `alternatives` (array): Alternatives considered (optional)
- `references` (array): Related documents/links (optional)
- `tags` (array): Tags for categorization (optional)
- `work_id` (string): Associated work item ID (optional)

**update**:
- `file_path` (string): Path to existing ADR (required)
- `updates` (object): Fields to update (required)
- `section` (string): Section to update (optional)
- `content` (string): New content for section (optional)

**supersede**:
- `file_path` (string): Path to ADR being superseded (required)
- `new_adr_number` (integer): Number of superseding ADR (required)
- `new_adr_title` (string): Title of superseding ADR (required)
- `new_adr_file` (string): Path to superseding ADR (optional)

**deprecate**:
- `file_path` (string): Path to ADR to deprecate (required)
- `deprecation_reason` (string): Why it's being deprecated (required)

**Options:**
- `validate` (boolean): Validate after operation (default: true)
- `project_root` (string): Project root directory (default: current directory)
</INPUTS>

<WORKFLOW>

## Step 1: Load Configuration

Load schema and merge with project configuration:

```bash
# Load ADR schema
SCHEMA=$(${SHARED_LIB}/schema-loader.sh adr)

# Load and merge config
CONFIG=$(${SHARED_LIB}/config-resolver.sh adr "${PROJECT_ROOT:-.}")

# Extract key config values
ADR_PATH=$(echo "$CONFIG" | jq -r '.path')
ADR_ENABLED=$(echo "$CONFIG" | jq -r '.enabled')
AUTO_NUMBER=$(echo "$CONFIG" | jq -r '.file_naming.auto_number')
NUMBER_FORMAT=$(echo "$CONFIG" | jq -r '.file_naming.number_format')
```

## Step 2: Route to Operation Handler

Based on `operation` parameter, execute the appropriate workflow:

- **generate** → Read `workflow/generate.md` and execute
- **update** → Read `workflow/update.md` and execute
- **supersede** → Read `workflow/supersede.md` and execute
- **deprecate** → Read `workflow/deprecate.md` and execute

## Step 3: Self-Validate Result

After completing the operation, validate the ADR:

```bash
# Validate the generated/updated ADR
VALIDATION_RESULT=$(validate_adr "$OUTPUT_FILE" "$CONFIG")

# Check validation status
VALIDATION_STATUS=$(echo "$VALIDATION_RESULT" | jq -r '.status')

if [[ "$VALIDATION_STATUS" == "error" ]]; then
    echo "⚠️  ADR has validation errors"
    echo "$VALIDATION_RESULT" | jq -r '.issues[] | "  - [\(.severity)] \(.message)"'
fi
```

## Step 4: Return Structured Result

Return operation result with validation status:

```json
{
  "success": true,
  "operation": "generate",
  "doc_type": "adr",
  "result": {
    "file_path": "docs/architecture/adrs/ADR-005-use-postgresql.md",
    "adr_number": 5,
    "title": "Use PostgreSQL for Primary Datastore",
    "status": "proposed",
    "size_bytes": 2048,
    "validation": {
      "status": "passed",
      "issues": []
    }
  },
  "timestamp": "2025-01-15T12:00:00Z"
}
```

</WORKFLOW>

<OPERATIONS>

### Generate Operation

Creates a new ADR with auto-numbering and validation.

**Workflow**: Read and execute `workflow/generate.md`

**Key Steps**:
1. Find next ADR number (if not provided)
2. Generate slug from title
3. Construct filename: ADR-{number}-{slug}.md
4. Prepare template data with all parameters
5. Render template
6. Add frontmatter
7. Write to file
8. Validate
9. Return result

**Example**:
```json
{
  "operation": "generate",
  "title": "Use PostgreSQL for Primary Datastore",
  "context": "We need a reliable database with ACID guarantees...",
  "decision": "We will use PostgreSQL 15 as our primary datastore...",
  "consequences": {
    "positive": [
      "ACID compliance ensures transaction integrity",
      "Rich query capabilities support complex reporting"
    ],
    "negative": [
      "Additional operational overhead",
      "Vertical scaling limits for large datasets"
    ]
  },
  "status": "proposed",
  "deciders": ["architecture-team"]
}
```

### Update Operation

Updates an existing ADR (restricted for accepted ADRs).

**Workflow**: Read and execute `workflow/update.md`

**Key Steps**:
1. Load existing ADR
2. Check immutability rules (status != "accepted" OR metadata_only)
3. Apply updates
4. Preserve frontmatter structure
5. Validate
6. Write back to file
7. Return result

**Immutability Rules**:
- If status == "accepted": ONLY allow metadata updates (tags, related, references)
- If status != "accepted": Allow all updates
- NEVER allow arbitrary content changes after acceptance

**Example**:
```json
{
  "operation": "update",
  "file_path": "docs/architecture/adrs/ADR-005-use-postgresql.md",
  "updates": {
    "tags": ["database", "postgresql", "infrastructure"],
    "references": [
      {
        "title": "PostgreSQL Documentation",
        "url": "https://www.postgresql.org/docs/"
      }
    ]
  }
}
```

### Supersede Operation

Marks an ADR as superseded by a newer ADR.

**Workflow**: Read and execute `workflow/supersede.md`

**Key Steps**:
1. Load existing ADR
2. Verify ADR is in "accepted" status
3. Update status to "superseded"
4. Add superseded_by to frontmatter
5. Add supersession notice to Status section
6. Optionally update new ADR with "supersedes" link
7. Validate
8. Return result

**Example**:
```json
{
  "operation": "supersede",
  "file_path": "docs/architecture/adrs/ADR-005-use-postgresql.md",
  "new_adr_number": 12,
  "new_adr_title": "Migrate to PostgreSQL 16",
  "new_adr_file": "docs/architecture/adrs/ADR-012-migrate-to-postgresql-16.md"
}
```

### Deprecate Operation

Marks an ADR as deprecated.

**Workflow**: Read and execute `workflow/deprecate.md`

**Key Steps**:
1. Load existing ADR
2. Update status to "deprecated"
3. Add deprecation_reason to frontmatter
4. Add deprecation notice to Status section
5. Validate
6. Return result

**Example**:
```json
{
  "operation": "deprecate",
  "file_path": "docs/architecture/adrs/ADR-003-use-mongodb.md",
  "deprecation_reason": "MongoDB no longer used in architecture. Replaced by PostgreSQL."
}
```

</OPERATIONS>

<VALIDATION>

Validation is performed using schema rules:

**Required Sections**:
- Status (must contain valid status value)
- Context (minimum 50 characters)
- Decision (minimum 50 characters)
- Consequences (minimum 30 characters total)

**Consequences Validation**:
- MUST have both "Positive" and "Negative" subsections
- MUST have at least one item in each subsection
- Empty consequences marked as validation error

**Frontmatter Validation**:
- All required fields present: title, type, status, date
- Type field == "adr"
- Status in allowed values: proposed|accepted|deprecated|superseded
- Date in valid ISO format

**Immutability Validation**:
- If status == "accepted": content changes are errors
- If status == "superseded": must have superseded_by field
- If status == "deprecated": should have deprecation_reason

**Numbering Validation**:
- ADR number is sequential (no gaps)
- Filename matches pattern: ADR-NNN-slug.md
- Number in frontmatter matches filename

**Result**:
```json
{
  "status": "passed" | "warnings" | "errors",
  "issues": [
    {
      "severity": "error" | "warning" | "info",
      "rule": "rule_name",
      "message": "Description of issue",
      "section": "Section name (if applicable)"
    }
  ]
}
```

</VALIDATION>

<SCRIPTS>

This skill uses shared scripts for common operations:

**Configuration**:
- `_shared/lib/schema-loader.sh` - Load ADR schema
- `_shared/lib/config-resolver.sh` - Merge schema + project config

**File Naming**:
- `_shared/scripts/find-next-number.sh` - Find next ADR number
- `_shared/scripts/slugify.sh` - Convert title to URL slug

**Template Operations**:
- `_shared/scripts/render-template.sh` - Render Mustache template (to be created)
- `_shared/scripts/add-frontmatter.sh` - Add YAML frontmatter (to be created)

**Validation**:
- `_shared/scripts/validate-doc.sh` - Validate document structure (to be created)

All scripts return JSON for easy parsing and stay OUT of LLM context.

</SCRIPTS>

<OUTPUTS>

## Success Response

```json
{
  "success": true,
  "operation": "generate",
  "doc_type": "adr",
  "result": {
    "file_path": "docs/architecture/adrs/ADR-005-use-postgresql.md",
    "adr_number": 5,
    "title": "Use PostgreSQL for Primary Datastore",
    "status": "proposed",
    "size_bytes": 2048,
    "sections": ["Status", "Context", "Decision", "Consequences"],
    "frontmatter": {
      "title": "ADR-005: Use PostgreSQL for Primary Datastore",
      "type": "adr",
      "status": "proposed",
      "date": "2025-01-15",
      "codex_sync": true
    },
    "validation": {
      "status": "passed",
      "issues": []
    }
  },
  "timestamp": "2025-01-15T12:00:00Z"
}
```

## Error Response

```json
{
  "success": false,
  "operation": "update",
  "doc_type": "adr",
  "error": "Cannot modify content of accepted ADR. Only metadata updates allowed.",
  "error_code": "ADR_IMMUTABLE",
  "details": {
    "file_path": "docs/architecture/adrs/ADR-005-use-postgresql.md",
    "current_status": "accepted",
    "attempted_operation": "content_update"
  },
  "timestamp": "2025-01-15T12:00:00Z"
}
```

## Validation Warning Response

```json
{
  "success": true,
  "operation": "generate",
  "doc_type": "adr",
  "result": {
    "file_path": "docs/architecture/adrs/ADR-006-api-versioning.md",
    "adr_number": 6,
    "validation": {
      "status": "warnings",
      "issues": [
        {
          "severity": "warning",
          "rule": "min_section_length",
          "message": "Context section is short (45 chars). Minimum recommended: 50 chars.",
          "section": "Context"
        },
        {
          "severity": "info",
          "rule": "alternatives_considered",
          "message": "No alternatives section found. Consider documenting alternatives.",
          "section": null
        }
      ]
    }
  }
}
```

</OUTPUTS>

<DOCUMENTATION>

Upon completion of each operation, output structured messages:

**Start Message**:
```
🎯 STARTING: ADR {operation}
Title: {title}
{operation-specific details}
───────────────────────────────────────
```

**Completion Message**:
```
✅ COMPLETED: ADR {operation}
File: {file_path}
Number: ADR-{number}
Title: {title}
Status: {status}
Validation: {validation_status}
───────────────────────────────────────
Next: {suggested_next_steps}
```

**Example for generate**:
```
✅ COMPLETED: ADR Generation
File: docs/architecture/adrs/ADR-005-use-postgresql.md
Number: ADR-005
Title: Use PostgreSQL for Primary Datastore
Status: proposed
Validation: passed
───────────────────────────────────────
Next: Review ADR and update status to "accepted" when approved
      Command: /fractary-docs:update docs/architecture/adrs/ADR-005-use-postgresql.md --status accepted
```

</DOCUMENTATION>

<ERROR_HANDLING>

**Configuration Errors**:
- Schema not found: Return error with schema path
- Config invalid: Return error with validation details
- ADR disabled: Return error indicating doc type is disabled

**File Errors**:
- File already exists (generate): Return error unless overwrite flag set
- File not found (update/supersede/deprecate): Return error with file path
- Permission denied: Return error with permissions info

**Validation Errors**:
- Missing required parameters: Return error listing missing fields
- Invalid status value: Return error with allowed values
- Immutability violation: Return error explaining ADR immutability rules
- Missing required sections: Return error with missing sections

**Numbering Errors**:
- Duplicate ADR number: Return error with existing file path
- Invalid number format: Return error with correct format

**Operation Errors**:
- Update immutable ADR: Return error with immutability explanation
- Supersede non-accepted ADR: Return error (only accepted ADRs can be superseded)
- Invalid status transition: Return error with allowed transitions

</ERROR_HANDLING>

<INTEGRATION>

This skill is used by:

1. **Direct Invocation** (from other skills/agents):
   ```markdown
   Use the doc-manage-adr skill to document this architectural decision:
   {
     "operation": "generate",
     "title": "Use PostgreSQL for Primary Datastore",
     "context": "...",
     "decision": "...",
     "consequences": {...}
   }
   ```

2. **Command Invocation** (via /fractary-docs:generate):
   ```bash
   /fractary-docs:generate adr "Use PostgreSQL for Primary Datastore"
   ```
   Command routes to this skill directly.

3. **FABER Integration** (architect phase):
   ```markdown
   # In architect workflow
   Use the doc-manage-adr skill to document the architectural decision made in this specification...
   ```

4. **docs-manager Integration** (multi-doc workflows):
   ```markdown
   # In docs-manager orchestration
   Use the doc-manage-adr skill to generate the ADR...
   ```

</INTEGRATION>

<BEST_PRACTICES>

1. **Clear Decisions**: Write decisions as clear, actionable statements
2. **Comprehensive Context**: Provide enough context for future readers to understand why the decision was made
3. **Balanced Consequences**: Document both positive and negative consequences honestly
4. **Consider Alternatives**: Document why alternatives were rejected
5. **Timely Documentation**: Create ADRs when decisions are made, not retroactively
6. **Immutability**: Once accepted, ADRs become historical records and should not be modified
7. **Supersession Over Deletion**: Never delete ADRs; supersede them with newer decisions
8. **Linking**: Link related ADRs and reference external documents
9. **Review Process**: Have ADRs reviewed before accepting (set status to "review")
10. **Regular Audits**: Periodically review ADRs for deprecation opportunities

</BEST_PRACTICES>
