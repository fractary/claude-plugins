# Parse Input and Determine Source

This workflow step parses the free-text instructions to determine the input source and extract relevant context.

## Input

- Free-text instructions (may be empty, file reference, or direct instructions)

## Process

### 1. Analyze Input Text

Check the instructions for patterns:

**Pattern 1: File path with .md extension**
```
"user-uploads.md"
".fractary/plugins/faber-cloud/designs/api-backend.md"
".faber/specs/123-add-feature.md"
```
→ Extract file path, determine if design or spec

**Pattern 2: Natural language with file reference**
```
"Implement design from user-uploads.md"
"Use the design in api-backend.md"
"Implement infrastructure for .faber/specs/123-add-api.md"
```
→ Extract file path from text

**Pattern 3: Direct instructions**
```
"Fix IAM permissions - Lambda needs s3:PutObject"
"Add CloudWatch alarms for all Lambda functions"
```
→ No file reference, treat as direct implementation guidance

**Pattern 4: Empty/No input**
```
""
null
```
→ Find latest design document

### 2. Determine Source Type

Based on analysis:

- **design_file**: References `.fractary/plugins/faber-cloud/designs/` or standalone .md file
- **faber_spec**: References `.faber/specs/` directory
- **direct_instructions**: No file reference found
- **latest_design**: No input provided

### 3. Resolve File Paths

**For design files:**
- If relative (just filename): Prepend `.fractary/plugins/faber-cloud/designs/`
- If absolute: Use as-is
- Verify file exists

**For FABER specs:**
- Must include `.faber/specs/` in path
- Verify file exists

**For latest design:**
```bash
# Find most recently modified design
DESIGN_DIR=".fractary/plugins/faber-cloud/designs"
LATEST_DESIGN=$(ls -t "$DESIGN_DIR"/*.md 2>/dev/null | head -1)

if [ -z "$LATEST_DESIGN" ]; then
    echo "❌ No design documents found in $DESIGN_DIR"
    exit 1
fi
```

## Output

Return parsed result:
```json
{
  "source_type": "design_file|faber_spec|direct_instructions|latest_design",
  "file_path": "/path/to/file.md",
  "instructions": "original or extracted instructions",
  "additional_context": "any extra instructions from mixed input"
}
```

## Examples

**Example 1: Simple design reference**
```
Input: "user-uploads.md"
Output:
{
  "source_type": "design_file",
  "file_path": ".fractary/plugins/faber-cloud/designs/user-uploads.md",
  "instructions": "user-uploads.md"
}
```

**Example 2: FABER spec**
```
Input: ".faber/specs/123-add-api.md"
Output:
{
  "source_type": "faber_spec",
  "file_path": ".faber/specs/123-add-api.md",
  "instructions": ".faber/specs/123-add-api.md"
}
```

**Example 3: Mixed context**
```
Input: "Implement api-backend.md and add CloudWatch alarms"
Output:
{
  "source_type": "design_file",
  "file_path": ".fractary/plugins/faber-cloud/designs/api-backend.md",
  "instructions": "Implement api-backend.md and add CloudWatch alarms",
  "additional_context": "and add CloudWatch alarms"
}
```

**Example 4: Direct instructions**
```
Input: "Fix IAM permissions - Lambda needs s3:PutObject"
Output:
{
  "source_type": "direct_instructions",
  "file_path": null,
  "instructions": "Fix IAM permissions - Lambda needs s3:PutObject"
}
```

## Success Criteria

✅ Source type determined
✅ File paths resolved (if applicable)
✅ Files exist (if file-based)
✅ Instructions extracted and preserved
