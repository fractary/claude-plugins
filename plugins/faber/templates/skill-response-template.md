# Skill Response Template

This template shows how to implement the standard FABER response format in your skills.

## Template: OUTPUTS Section

Add this to your skill's `<OUTPUTS>` section:

```markdown
<OUTPUTS>
Return results using the **standard FABER response format**.

See: `plugins/faber/docs/RESPONSE-FORMAT.md` for complete specification.

**Success Response:**
```json
{
  "status": "success",
  "message": "[Brief description of successful outcome]",
  "details": {
    // Operation-specific data
    "artifact_path": "/path/to/created/file",
    "items_processed": 10,
    "duration_ms": 1234
  }
}
```

**Warning Response:**
```json
{
  "status": "warning",
  "message": "[Brief description with warning summary]",
  "details": {
    // Same structure as success
  },
  "warnings": [
    "[Specific warning 1]",
    "[Specific warning 2]"
  ],
  "warning_analysis": "[Explanation of warning impact and urgency]",
  "suggested_fixes": [
    "[Actionable fix 1]",
    "[Actionable fix 2]"
  ]
}
```

**Failure Response:**
```json
{
  "status": "failure",
  "message": "[Brief description of failure]",
  "details": {
    // Partial results if any
  },
  "errors": [
    "[Specific error 1]",
    "[Specific error 2]"
  ],
  "error_analysis": "[Root cause explanation]",
  "suggested_fixes": [
    "[Actionable fix 1]",
    "[Actionable fix 2]"
  ]
}
```
</OUTPUTS>
```

## Implementation Patterns

### Bash Script Pattern

```bash
#!/usr/bin/env bash
# skill-operation.sh

set -euo pipefail

# Success response helper
success_response() {
    local message="$1"
    local details="$2"
    jq -n \
        --arg status "success" \
        --arg message "$message" \
        --argjson details "$details" \
        '{status: $status, message: $message, details: $details}'
}

# Warning response helper
warning_response() {
    local message="$1"
    local details="$2"
    local warnings="$3"
    local analysis="$4"
    local fixes="$5"
    jq -n \
        --arg status "warning" \
        --arg message "$message" \
        --argjson details "$details" \
        --argjson warnings "$warnings" \
        --arg analysis "$analysis" \
        --argjson fixes "$fixes" \
        '{status: $status, message: $message, details: $details, warnings: $warnings, warning_analysis: $analysis, suggested_fixes: $fixes}'
}

# Failure response helper
failure_response() {
    local message="$1"
    local errors="$2"
    local analysis="$3"
    local fixes="$4"
    jq -n \
        --arg status "failure" \
        --arg message "$message" \
        --argjson errors "$errors" \
        --arg analysis "$analysis" \
        --argjson fixes "$fixes" \
        '{status: $status, message: $message, errors: $errors, error_analysis: $analysis, suggested_fixes: $fixes}'
}

# Example usage
main() {
    local result
    local errors=()
    local warnings=()

    # ... perform operation ...

    if [[ ${#errors[@]} -gt 0 ]]; then
        errors_json=$(printf '%s\n' "${errors[@]}" | jq -R . | jq -s .)
        failure_response \
            "Operation failed - ${#errors[@]} errors" \
            "$errors_json" \
            "Root cause explanation" \
            '["Fix suggestion 1", "Fix suggestion 2"]'
        exit 1
    elif [[ ${#warnings[@]} -gt 0 ]]; then
        warnings_json=$(printf '%s\n' "${warnings[@]}" | jq -R . | jq -s .)
        warning_response \
            "Operation completed with warnings" \
            '{"items": 10}' \
            "$warnings_json" \
            "Warning impact" \
            '["Fix suggestion"]'
        exit 0
    else
        success_response \
            "Operation completed successfully" \
            '{"items": 10}'
        exit 0
    fi
}

main "$@"
```

### TypeScript/JavaScript Pattern

```typescript
interface SkillResponse {
  status: 'success' | 'warning' | 'failure';
  message: string;
  details?: Record<string, unknown>;
  errors?: string[];
  warnings?: string[];
  error_analysis?: string;
  warning_analysis?: string;
  suggested_fixes?: string[];
}

function successResponse(message: string, details?: Record<string, unknown>): SkillResponse {
  return {
    status: 'success',
    message,
    ...(details && { details }),
  };
}

function warningResponse(
  message: string,
  warnings: string[],
  options?: {
    details?: Record<string, unknown>;
    warning_analysis?: string;
    suggested_fixes?: string[];
  }
): SkillResponse {
  return {
    status: 'warning',
    message,
    warnings,
    ...options,
  };
}

function failureResponse(
  message: string,
  errors: string[],
  options?: {
    details?: Record<string, unknown>;
    error_analysis?: string;
    suggested_fixes?: string[];
  }
): SkillResponse {
  return {
    status: 'failure',
    message,
    errors,
    ...options,
  };
}

// Example usage
function processItems(items: string[]): SkillResponse {
  const errors: string[] = [];
  const warnings: string[] = [];
  const processed: string[] = [];

  for (const item of items) {
    try {
      // ... process item ...
      processed.push(item);
    } catch (e) {
      errors.push(`Failed to process ${item}: ${e.message}`);
    }
  }

  if (errors.length > 0) {
    return failureResponse(
      `Processing failed - ${errors.length} items failed`,
      errors,
      {
        details: { processed_count: processed.length, total: items.length },
        error_analysis: 'Some items could not be processed due to validation errors',
        suggested_fixes: ['Check item format matches expected schema'],
      }
    );
  }

  return successResponse(
    `Processed ${processed.length} items successfully`,
    { processed_count: processed.length }
  );
}
```

### Python Pattern

```python
from typing import TypedDict, List, Optional, Literal
import json

class SkillResponse(TypedDict, total=False):
    status: Literal['success', 'warning', 'failure']
    message: str
    details: dict
    errors: List[str]
    warnings: List[str]
    error_analysis: str
    warning_analysis: str
    suggested_fixes: List[str]

def success_response(message: str, details: Optional[dict] = None) -> SkillResponse:
    response: SkillResponse = {'status': 'success', 'message': message}
    if details:
        response['details'] = details
    return response

def warning_response(
    message: str,
    warnings: List[str],
    details: Optional[dict] = None,
    warning_analysis: Optional[str] = None,
    suggested_fixes: Optional[List[str]] = None
) -> SkillResponse:
    response: SkillResponse = {
        'status': 'warning',
        'message': message,
        'warnings': warnings
    }
    if details:
        response['details'] = details
    if warning_analysis:
        response['warning_analysis'] = warning_analysis
    if suggested_fixes:
        response['suggested_fixes'] = suggested_fixes
    return response

def failure_response(
    message: str,
    errors: List[str],
    details: Optional[dict] = None,
    error_analysis: Optional[str] = None,
    suggested_fixes: Optional[List[str]] = None
) -> SkillResponse:
    response: SkillResponse = {
        'status': 'failure',
        'message': message,
        'errors': errors
    }
    if details:
        response['details'] = details
    if error_analysis:
        response['error_analysis'] = error_analysis
    if suggested_fixes:
        response['suggested_fixes'] = suggested_fixes
    return response

# Example usage
def process_files(files: List[str]) -> SkillResponse:
    errors = []
    warnings = []
    processed = []

    for file in files:
        try:
            # ... process file ...
            processed.append(file)
        except FileNotFoundError:
            errors.append(f"File not found: {file}")
        except PermissionError:
            warnings.append(f"Permission warning for {file}")

    if errors:
        return failure_response(
            f"Processing failed - {len(errors)} files could not be processed",
            errors,
            details={'processed': len(processed), 'total': len(files)},
            error_analysis="Some files were not found or inaccessible",
            suggested_fixes=["Verify file paths exist", "Check file permissions"]
        )

    if warnings:
        return warning_response(
            f"Processed {len(processed)} files with {len(warnings)} warnings",
            warnings,
            details={'processed': len(processed)},
            warning_analysis="Some files had permission issues but were still processed"
        )

    return success_response(
        f"Successfully processed {len(processed)} files",
        {'processed': len(processed)}
    )

# Output as JSON
if __name__ == '__main__':
    result = process_files(['file1.txt', 'file2.txt'])
    print(json.dumps(result))
```

## Checklist for New Skills

When creating a new skill:

- [ ] Add `<OUTPUTS>` section with response format examples
- [ ] Show success, warning, and failure response examples
- [ ] Include realistic `details` structure for your operation
- [ ] Document expected `errors` types
- [ ] Document expected `warnings` types
- [ ] Implement response helpers in your scripts
- [ ] Validate responses with response-validator skill
- [ ] Link to RESPONSE-FORMAT.md documentation

## See Also

- [Response Format Specification](../docs/RESPONSE-FORMAT.md)
- [Best Practices Guide](../../docs/standards/SKILL-RESPONSE-BEST-PRACTICES.md)
- [JSON Schema](../config/schemas/skill-response.schema.json)
