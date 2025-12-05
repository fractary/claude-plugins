# FABER Response Format Validation Integration Tests

This document defines integration test scenarios for validating FABER skill response format compliance.

## Test Categories

1. **Schema Validation Tests** - Verify responses validate against skill-response.schema.json
2. **Conditional Requirement Tests** - Verify conditional field requirements (errors for failure, warnings for warning)
3. **Format Compliance Tests** - Verify all required and recommended fields are present
4. **Migration Tests** - Verify backward compatibility and migration paths

---

## Test 1: Schema Validation - Success Response

**Scenario**: Skill returns properly formatted success response

**Setup**:
```json
{
  "status": "success",
  "message": "Operation completed successfully",
  "details": {
    "operation": "test-operation",
    "artifacts": []
  }
}
```

**Expected Behavior**:
- Response passes JSON schema validation
- All required fields present (status, message)
- Response is accepted by workflow manager
- Workflow proceeds to next step

**Verification**:
```bash
# Validate response against schema
plugins/faber/skills/response-validator/scripts/validate-response.sh \
  '{"status":"success","message":"Test successful","details":{}}'

# Expected: "✓ Response is valid"
```

---

## Test 2: Schema Validation - Failure Response Missing Errors

**Scenario**: Skill returns failure response without required errors array

**Setup**:
```json
{
  "status": "failure",
  "message": "Operation failed"
}
```

**Expected Behavior**:
- Response fails JSON schema validation
- Error indicates missing required "errors" field
- Validation message suggests: "When status is 'failure', errors array is required with at least 1 item"
- Workflow stops with validation error

**Verification**:
```bash
# Validate response against schema
plugins/faber/skills/response-validator/scripts/validate-response.sh \
  '{"status":"failure","message":"Test failed"}'

# Expected: "✗ Schema validation failed"
# Expected error: Contains "errors" and "required"
```

---

## Test 3: Schema Validation - Warning Response Missing Warnings

**Scenario**: Skill returns warning response without required warnings array

**Setup**:
```json
{
  "status": "warning",
  "message": "Operation completed with warnings",
  "details": {}
}
```

**Expected Behavior**:
- Response fails JSON schema validation
- Error indicates missing required "warnings" field
- Validation message suggests: "When status is 'warning', warnings array is required with at least 1 item"
- Workflow stops with validation error

**Verification**:
```bash
# Validate response against schema
plugins/faber/skills/response-validator/scripts/validate-response.sh \
  '{"status":"warning","message":"Test warning","details":{}}'

# Expected: "✗ Schema validation failed"
# Expected error: Contains "warnings" and "required"
```

---

## Test 4: Schema Validation - Invalid Status Value

**Scenario**: Skill returns response with invalid status value

**Setup**:
```json
{
  "status": "unknown",
  "message": "Invalid status"
}
```

**Expected Behavior**:
- Response fails JSON schema validation
- Error indicates invalid enum value
- Validation message suggests valid values: "success", "warning", "failure"
- Workflow stops with validation error

**Verification**:
```bash
# Validate response against schema
plugins/faber/skills/response-validator/scripts/validate-response.sh \
  '{"status":"unknown","message":"Invalid","errors":[]}'

# Expected: "✗ Schema validation failed"
# Expected error: Contains "enum" or "unknown"
```

---

## Test 5: Format Compliance - Complete Failure Response

**Scenario**: Skill returns fully compliant failure response with all recommended fields

**Setup**:
```json
{
  "status": "failure",
  "message": "Authentication failed",
  "details": {
    "attempt": 3,
    "auth_type": "token"
  },
  "errors": [
    "Invalid token signature",
    "Token expired"
  ],
  "error_analysis": "The authentication token has expired and is no longer valid. This typically happens after the token's TTL (time to live) expires.",
  "suggested_fixes": [
    "Refresh the authentication token",
    "Run 'gh auth login' to re-authenticate"
  ]
}
```

**Expected Behavior**:
- Response passes all schema validations
- All recommended fields are present
- Response is accepted by workflow manager
- FABER can extract error_analysis and suggested_fixes for failure prompt
- Workflow stops but user sees rich failure information

**Verification**:
```bash
# Validate response
plugins/faber/skills/response-validator/scripts/validate-response.sh \
  '{"status":"failure","message":"Auth failed","details":{},"errors":["Invalid token"],"error_analysis":"Token expired","suggested_fixes":["Refresh token"]}'

# Expected: "✓ Response is valid"
```

---

## Test 6: Format Compliance - Complete Warning Response

**Scenario**: Skill returns fully compliant warning response with all recommended fields

**Setup**:
```json
{
  "status": "warning",
  "message": "Build completed with deprecated API usage",
  "details": {
    "files_compiled": 45,
    "build_time": "12.5s"
  },
  "warnings": [
    "Deprecated API useCallback will be removed in v3.0",
    "Bundle size exceeds recommended limit"
  ],
  "warning_analysis": "Deprecated APIs should be updated before the next major version. Bundle size optimization is recommended for production deployments.",
  "suggested_fixes": [
    "Replace useCallback with useMemo",
    "Implement code splitting for lazy-loaded routes"
  ]
}
```

**Expected Behavior**:
- Response passes all schema validations
- All recommended fields are present
- Response is accepted by workflow manager
- FABER can extract warning_analysis and suggested_fixes for warning prompt
- Workflow logs warnings and proceeds (or prompts if configured)

**Verification**:
```bash
# Validate response
plugins/faber/skills/response-validator/scripts/validate-response.sh \
  '{"status":"warning","message":"Build completed","details":{},"warnings":["Deprecated API"],"warning_analysis":"Update needed","suggested_fixes":["Fix API calls"]}'

# Expected: "✓ Response is valid"
```

---

## Test 7: Migration - Old Format Response

**Scenario**: Skill returns response in old format (pre-standardization)

**Setup**:
```json
{
  "success": true,
  "result": "Operation completed",
  "output": {
    "file": "/path/to/file"
  }
}
```

**Expected Behavior**:
- Old format is detected during validation
- Validation script reports as "non-compliant"
- Error message suggests: "Use standard FABER response format with 'status' field"
- Migration guide (`docs/MIGRATE-SKILL-RESPONSES.md`) is referenced
- Workflow stops with migration suggestion

**Verification**:
```bash
# Check with validation script
./scripts/validate-skill-responses.sh --verbose plugins/skill-using-old-format

# Expected: Reports as "Non-compliant (missing standard format)"
# Expected: Shows migration guide reference
```

---

## Test 8: Audit Script - Compliance Checking

**Scenario**: Run compliance audit on all skills

**Setup**:
- Several skills with updated OUTPUTS sections
- One or more skills with old/incomplete OUTPUTS

**Expected Behavior**:
- Audit script finds all skills
- Generates compliance report
- Shows summary: compliant, partial, non-compliant counts
- Exits with code 1 if non-compliant skills found
- Can output JSON for CI/CD integration

**Verification**:
```bash
# Run audit on all plugins
./scripts/validate-skill-responses.sh

# Expected output includes:
# - Compliant count
# - Partial count
# - Non-compliant count
# - Compliance percentage

# Run with JSON output
./scripts/validate-skill-responses.sh --json | jq .

# Expected: Valid JSON with summary and results array

# Check exit code
./scripts/validate-skill-responses.sh
echo $?
# Expected: 0 if all compliant, 1 if any non-compliant
```

---

## Test 9: Response Validator Skill - Format Check

**Scenario**: Use response-validator skill to check response format

**Setup**:
```bash
# Create test response file
cat > /tmp/test-response.json <<'EOF'
{
  "status": "success",
  "message": "Test completed"
}
EOF
```

**Expected Behavior**:
- Skill can validate response against JSON schema
- Provides quick format check without full schema validation
- Returns pass/fail status
- Helpful error messages for failures

**Verification**:
```bash
# Run format check script
plugins/faber/skills/response-validator/scripts/check-format.sh /tmp/test-response.json

# Expected: "✓ Response format is valid"

# Run full validation
plugins/faber/skills/response-validator/scripts/validate-response.sh /tmp/test-response.json

# Expected: "✓ Response validates against schema"
```

---

## Test 10: Conditional Field Requirements - Errors with Success

**Scenario**: Skill returns success response with errors array (should not be required)

**Setup**:
```json
{
  "status": "success",
  "message": "Operation succeeded",
  "details": {},
  "errors": []
}
```

**Expected Behavior**:
- Response passes schema validation (errors is optional for success)
- No validation errors
- Workflow proceeds normally

**Verification**:
```bash
# Validate response
plugins/faber/skills/response-validator/scripts/validate-response.sh \
  '{"status":"success","message":"Success","details":{},"errors":[]}'

# Expected: "✓ Response is valid"
```

---

## Test 11: Conditional Field Requirements - Warnings with Failure

**Scenario**: Skill returns failure response with warnings array (should not affect validation)

**Setup**:
```json
{
  "status": "failure",
  "message": "Operation failed",
  "details": {},
  "errors": ["Error occurred"],
  "warnings": []
}
```

**Expected Behavior**:
- Response passes schema validation (warnings is optional for failure)
- Errors array requirement is satisfied
- No validation errors
- Workflow stops with failure

**Verification**:
```bash
# Validate response
plugins/faber/skills/response-validator/scripts/validate-response.sh \
  '{"status":"failure","message":"Failed","details":{},"errors":["Error"],"warnings":[]}'

# Expected: "✓ Response is valid"
```

---

## Test 12: Message Length Validation

**Scenario**: Skill returns response with message exceeding max length

**Setup**:
```json
{
  "status": "success",
  "message": "[500+ character message exceeding 500 char limit]"
}
```

**Expected Behavior**:
- Response fails schema validation
- Error indicates message exceeds maxLength of 500
- Validation message suggests: "Message should be 1-2 sentences (max 500 characters)"

**Verification**:
```bash
# Create message exceeding 500 chars
LONG_MSG=$(printf 'x%.0s' {1..501})

# Validate response
plugins/faber/skills/response-validator/scripts/validate-response.sh \
  "{\"status\":\"success\",\"message\":\"$LONG_MSG\"}"

# Expected: "✗ Schema validation failed"
# Expected error: Contains "maxLength" or "500"
```

---

## Test 13: Errors Array With Empty Items

**Scenario**: Skill returns failure with errors array containing empty strings

**Setup**:
```json
{
  "status": "failure",
  "message": "Operation failed",
  "details": {},
  "errors": ["", "Actual error"]
}
```

**Expected Behavior**:
- Response fails schema validation
- Error indicates empty string not allowed in errors array
- Validation message suggests: "Each error must be a non-empty string"

**Verification**:
```bash
# Validate response
plugins/faber/skills/response-validator/scripts/validate-response.sh \
  '{"status":"failure","message":"Failed","details":{},"errors":[""]}'

# Expected: "✗ Schema validation failed"
# Expected error: Contains "minLength"
```

---

## Test 14: Additional Properties Not Allowed

**Scenario**: Skill returns response with unknown additional properties

**Setup**:
```json
{
  "status": "success",
  "message": "Success",
  "extra_field": "not allowed"
}
```

**Expected Behavior**:
- Response fails schema validation
- Error indicates additional properties are not allowed
- Validation message suggests: "Unknown field 'extra_field'. Use 'details' for operation-specific data"

**Verification**:
```bash
# Validate response
plugins/faber/skills/response-validator/scripts/validate-response.sh \
  '{"status":"success","message":"Success","extra_field":"not allowed"}'

# Expected: "✗ Schema validation failed"
# Expected error: Contains "additionalProperties" or "extra_field"
```

---

## Running All Tests

To run all response format validation tests:

```bash
# 1. Validate the schema itself
jq -f /dev/null plugins/faber/config/schemas/skill-response.schema.json

# 2. Run compliance audit
./scripts/validate-skill-responses.sh --verbose

# 3. Test individual response formats
for test in /tmp/test-responses/*.json; do
  plugins/faber/skills/response-validator/scripts/validate-response.sh "$test"
done

# 4. Check audit script outputs JSON correctly
./scripts/validate-skill-responses.sh --json | jq '.summary'
```

## Success Criteria

✓ All schema validation tests pass
✓ Conditional field requirements enforced correctly
✓ Audit script identifies compliant/non-compliant skills
✓ Migration guidance available for old format responses
✓ Validator skills provide clear error messages
✓ Exit codes correct (0 for success, 1 for failures)
