# Parse Input and Determine Source

This workflow step parses the free-text instructions to determine the input source and extract relevant context.

**IMPORTANT:** This step uses the `parse-input.sh` script for deterministic parsing operations, keeping them outside LLM context to reduce token usage.

## Input

- Free-text instructions (may be empty, file reference, or direct instructions)

## Process

### 1. Invoke Parse Script

Execute the parse-input.sh script with the instructions:

```bash
# Invoke deterministic parsing script
PARSE_RESULT=$(./scripts/parse-input.sh "$INSTRUCTIONS")

if [ $? -ne 0 ]; then
    echo "❌ Input parsing failed"
    exit 1
fi

echo "✅ Input parsed successfully"
```

The script handles all pattern matching and validation.

## Pattern Matching Priority

The `parse-input.sh` script uses the following **priority order** to resolve ambiguous inputs:

### Priority 1: FABER Spec Paths (Most Specific)
```
".faber/specs/123-add-feature.md"
"Implement .faber/specs/123-api.md"
```
→ Highest priority because most specific

### Priority 2: Design Directory Paths
```
".fractary/plugins/faber-cloud/designs/api-backend.md"
"Use .fractary/plugins/faber-cloud/designs/uploads.md"
```
→ Second priority for explicit design paths

### Priority 3: Standalone .md Files
```
"user-uploads.md"
"api-backend.md"
```
→ Treated as design files (prepend design directory)

### Priority 4: Natural Language with Keywords
```
"Implement design from api-backend.md"
"Use design in user-uploads.md"
"Fix design from api-backend.md"  ← This now has clear resolution
```
→ Extract filename using keywords: from, in, using, implement, design

### Priority 5: Direct Instructions (No File Reference)
```
"Fix IAM permissions - Lambda needs s3:PutObject"
"Add CloudWatch alarms for all Lambda functions"
```
→ No .md file found, treat as instructions

### Priority 6: Empty Input
```
""
null
```
→ Find latest design document

### Ambiguity Resolution Example

**Input:** `"Fix design from api-backend.md"`

**Parsing Steps:**
1. Check Pattern 1 (FABER spec): ❌ No `.faber/specs/` found
2. Check Pattern 2 (Design path): ❌ No full design path found
3. Check Pattern 3 (Standalone .md): ✅ Found `api-backend.md`
4. **Result:** `design_file` with path `.fractary/plugins/faber-cloud/designs/api-backend.md`
5. **Additional context:** `"Fix"` is preserved as additional context

**Input:** `"Implement infrastructure for .faber/specs/123-add-api.md and add CloudWatch alarms"`

**Parsing Steps:**
1. Check Pattern 1 (FABER spec): ✅ Found `.faber/specs/123-add-api.md`
2. **Result:** `faber_spec` with full path
3. **Additional context:** `"and add CloudWatch alarms"` extracted

## Security: Path Sanitization

The script includes path validation to prevent directory traversal attacks:

```bash
# Example: "../../../etc/passwd" would be rejected
# Only paths within allowed directories are accepted:
# - .fractary/plugins/faber-cloud/designs/
# - .faber/specs/
```

**Security checks performed:**
- Resolve paths using `realpath -m` (no symlink following)
- Verify resolved path starts with allowed base directory
- Reject paths outside allowed directories
- Return error for invalid or malicious paths

## Output

The script returns JSON:
```json
{
  "source_type": "design_file|faber_spec|direct_instructions|latest_design",
  "file_path": "/absolute/path/to/file.md",
  "instructions": "original instructions text",
  "additional_context": "extra instructions extracted from mixed input"
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
