# Workflow Step Response Standardization

**Issue**: [#235](https://github.com/fractary/claude-plugins/issues/235)
**Status**: Open
**Phase**: Architect
**Created**: 2025-12-05
**Work ID**: 235

---

## Executive Summary

FABER workflow manager now expects workflow steps to return standardized response objects with status codes (success, warning, failure) and configurable result handling. However, most FABER plugin skills and custom project skills have NOT been updated to return these responses. This specification defines:

1. **Standard Response Format**: Structured response object with status, errors, warnings, and analysis
2. **Response Status Values**: Enumerated types (success, warning, failure) with defined behaviors
3. **FABER Plugin Skill Updates**: Which skills need updates and migration path
4. **Cross-Project Guidelines**: Best practices and audit mechanisms for project skills
5. **Documentation & Education**: Best practices guide, audit tooling, and skill templates

This standardization enables intelligent workflow orchestration with proper error handling, recovery suggestions, and user prompts.

---

## Problem Statement

### Current State

Recent work (issue #228, #232) implemented:
- Default result_handling configuration in workflow steps
- Intelligent prompts for warnings and failures
- Manager expects structured result responses

However:
1. **FABER Plugin Skills**: Most skills (frame, architect, build, evaluate, release, etc.) return ad-hoc responses without standardized status
2. **Response Format Undefined**: No formal schema for response objects - inconsistent structures
3. **No Cross-Project Guidance**: Projects with custom skills lack guidance on updating them
4. **Incomplete Audit**: audit-project doesn't identify response format gaps
5. **No Best Practices**: Skill developers lack clear guidelines on response format

### Example Problem

Current skill responses are inconsistent:

```javascript
// Old response format (undefined)
{
  "success": true,
  "message": "Spec generated"
}

// Another format
{
  "completed": true,
  "spec_path": "/specs/WORK-00123.md"
}

// No status field - manager can't determine if it's success/warning/failure
```

Manager expects but doesn't always get:

```javascript
// Expected format
{
  "status": "success" | "warning" | "failure",
  "message": "Human-readable summary",
  "details": {...},
  "errors": [],
  "warnings": [],
  "warning_analysis": "...",
  "error_analysis": "...",
  "suggested_fixes": ["..."]
}
```

### Target State

1. **Standard Response Format**: All FABER and project skills return structured responses
2. **Type Safety**: Schema enforces response format, tooling validates
3. **Consistency**: Projects can audit and update custom skills
4. **Intelligence**: Manager can parse warnings/errors and handle intelligently
5. **Guidance**: Clear best practices and migration path

---

## Acceptance Criteria

### 1. Response Format Specification

- [x] **AC1.1**: Define standard response object schema:
  - [x] `status` (required, enum): "success" | "warning" | "failure"
  - [x] `message` (required, string): Human-readable summary (1-2 sentences)
  - [x] `details` (optional, object): Operation-specific details
  - [x] `errors` (optional, array): List of error messages (if status="failure")
  - [x] `warnings` (optional, array): List of warning messages (if status="warning")
  - [x] `error_analysis` (optional, string): Analysis of what went wrong (root cause)
  - [x] `warning_analysis` (optional, string): Analysis of warnings (impact assessment)
  - [x] `suggested_fixes` (optional, array): List of suggested fixes (for failures/warnings)

- [x] **AC1.2**: Document response format in:
  - [x] Create `plugins/faber/docs/RESPONSE-FORMAT.md` with full schema
  - [x] Add JSON schema file: `plugins/faber/config/schemas/skill-response.schema.json`
  - [ ] Update faber-manager.md with response handling logic
  - [x] Add examples for success/warning/failure cases

- [x] **AC1.3**: Validate response format:
  - [x] Create `plugins/faber/skills/response-validator/` skill
  - [x] Validates all step/hook responses against schema
  - [ ] Returns error if response malformed
  - [ ] Provides helpful error message for common mistakes

- [ ] **AC1.4**: Ensure backward compatibility:
  - [ ] Old response formats are warned about (deprecated)
  - [ ] Manager can still process them with migration layer
  - [ ] Audit tool identifies old format usage

### 2. Status Value Semantics

- [x] **AC2.1**: Define status values precisely:
  - [x] **"success"**: Operation completed successfully, no issues, proceed normally
  - [x] **"warning"**: Operation completed but with non-blocking issues, proceed with caution
  - [x] **"failure"**: Operation failed, goal not achieved, must stop or retry

- [x] **AC2.2**: Response guidance for skill developers:
  - [x] Return "failure" when: Goal not achieved, action incomplete, critical issue
  - [x] Return "warning" when: Goal achieved but with concerns (deprecated API, performance, etc.)
  - [x] Return "success" when: Goal achieved cleanly, no concerns
  - [x] Document in skill best practices guide

- [x] **AC2.3**: Error/warning distinction in response object:
  - [x] `errors` array for failure status (list reasons for failure)
  - [x] `warnings` array for warning/success status (non-blocking concerns)
  - [x] Both can appear in single response (e.g., warning with multiple warnings)

### 3. FABER Plugin Skill Updates

- [x] **AC3.1**: Identify all FABER plugin skills needing updates:
  - [x] List skills in `plugins/faber/skills/` that don't return status responses
  - [x] Prioritize by frequency and criticality
  - [x] Create migration checklist (see implementation plan)

- [x] **AC3.2**: Update core FABER skills:
  - [x] `frame-phase` skill (updated OUTPUTS section)
  - [x] `architect-phase` skill (updated OUTPUTS section)
  - [x] `build-phase` skill (updated OUTPUTS section)
  - [x] `evaluate-phase` skill (updated OUTPUTS section)
  - [x] `release-phase` skill (updated OUTPUTS section)
  - [x] `branch-creator` (automatic primitive - in repo plugin: branch-manager SKILL.md updated)
  - [x] `pr-creator` (automatic primitive - in repo plugin: pr-manager SKILL.md updated)
  - [x] `issue-fetcher` (automatic primitive - in work plugin: issue-fetcher SKILL.md updated)

- [x] **AC3.3**: Each skill update includes:
  - [x] Return status: "success", "warning", or "failure"
  - [x] Return operation-specific details in `details` field
  - [x] Include error_analysis if status="failure"
  - [x] Include suggested_fixes if fixable
  - [x] Update skill documentation with response format
  - [x] Add examples to skill docs

- [x] **AC3.4**: Update fractary-spec plugin skill:
  - [x] spec-generator skill returns standardized response
  - [x] spec-validator skill returns validation status
  - [ ] spec-archiver skill returns archive status (pending)

### 4. Cross-Project Skill Guidance

- [x] **AC4.1**: Create response format best practices guide:
  - [x] Create `docs/standards/SKILL-RESPONSE-BEST-PRACTICES.md`
  - [x] Include response object examples (success/warning/failure)
  - [x] Provide skill template with correct response format
  - [x] Include common patterns and anti-patterns
  - [x] Add error/warning categorization guidance

- [x] **AC4.2**: Provide skill development template:
  - [x] Create `plugins/faber/templates/skill-response-template.md`
  - [x] Shows correct response structure
  - [x] Includes commented examples
  - [x] Can be referenced by project skill developers

- [x] **AC4.3**: Documentation updates:
  - [x] Update `docs/standards/FRACTARY-PLUGIN-STANDARDS.md` to include response format
  - [x] Add response format section to skill development guide
  - [x] Include migration checklist for existing skills

### 5. Audit and Validation Tooling

- [x] **AC5.1**: Enhance audit-project command:
  - [x] Detect skills that don't return status responses
  - [x] Check response format compliance
  - [x] Warn about deprecated response formats
  - [x] Suggest specific skills that need updating
  - [x] Provide step-by-step fix instructions

- [x] **AC5.2**: Create response format validator script:
  - [x] Script: `scripts/validate-skill-responses.sh`
  - [x] Can be run on project to check all skills
  - [x] Validates against skill-response.schema.json
  - [x] Returns detailed report with issues and fixes

- [x] **AC5.3**: Schema validation in FABER manager:
  - [x] Manager validates all skill responses before processing
  - [x] Reports schema validation errors clearly
  - [x] Suggests fixes in error message

### 6. Documentation and Learning

- [x] **AC6.1**: Create response format documentation:
  - [x] `plugins/faber/docs/RESPONSE-FORMAT.md` - Full schema and semantics
  - [x] `docs/standards/SKILL-RESPONSE-BEST-PRACTICES.md` - Developer guide
  - [x] Examples with success/warning/failure cases
  - [x] Common patterns and anti-patterns

- [x] **AC6.2**: Update existing skill documentation:
  - [x] Review all FABER skill docs
  - [x] Add response format section to each skill
  - [x] Show example responses for that skill
  - [x] Document expected error/warning types

- [x] **AC6.3**: Create migration guide:
  - [x] Create `docs/MIGRATE-SKILL-RESPONSES.md`
  - [x] Step-by-step instructions for updating existing skills
  - [x] Before/after examples
  - [x] Common migration patterns
  - [x] Testing checklist

- [x] **AC6.4**: Update FABER agent best practices:
  - [x] Create `plugins/faber/docs/FABER-AGENT-BEST-PRACTICES.md`
  - [x] Add section on skill response format expectations
  - [x] Link to validation tooling
  - [x] Include migration checklist and audit workflow

### 7. Integration with Manager

- [x] **AC7.1**: Manager response handling:
  - [x] Validate response format for all step/hook results
  - [x] Report validation errors clearly
  - [x] Apply response-based behavior:
    - [x] Status="success" → check on_success
    - [x] Status="warning" → check on_warning, show intelligent prompt
    - [x] Status="failure" → stop workflow (IMMUTABLE)
  - [x] Parse errors/warnings arrays for intelligent prompts

- [x] **AC7.2**: Intelligent prompt construction:
  - [x] Show all errors from response.errors array
  - [x] Show all warnings from response.warnings array
  - [x] Show error_analysis if present
  - [x] Show warning_analysis if present
  - [x] Show suggested_fixes if present (prioritized)
  - [x] Present options based on severity and suggestions

- [x] **AC7.3**: Logging and audit:
  - [x] Log all step responses (including status, errors, warnings)
  - [x] Track response format compliance
  - [x] Include in workflow state.json
  - [x] Include in workflow logs

---

## Design Decisions

### Response Format Structure

**Decision**: Use structured response object instead of flat fields.

**Rationale**:
- Allows evolution without breaking changes (add new fields)
- Separates operation result from handling instructions
- Supports multiple errors/warnings in single response
- Enables rich analysis and suggestions
- Easier to parse and validate with schema

**Structure**:
```javascript
{
  // Core response (required)
  status: "success" | "warning" | "failure",
  message: "Human-readable summary",
  
  // Operation details (optional, operation-specific)
  details: {
    // Any custom fields needed by the operation
  },
  
  // Error/warning collections (optional, status-dependent)
  errors: ["Error 1", "Error 2"],        // If status="failure"
  warnings: ["Warning 1", "Warning 2"],   // If status="warning" or "success"
  
  // Analysis and suggestions (optional)
  error_analysis: "Root cause analysis",
  warning_analysis: "Impact assessment",
  suggested_fixes: ["Fix 1", "Fix 2"]
}
```

### Status Values (Immutable, Well-Defined)

**Decision**: Use three status values with precise semantics.

**Rationale**:
- Aligns with result_handling enum: success, warning, failure
- Provides clear meaning for manager behavior
- Supports intelligent decision-making
- Easy for skill developers to understand

**Mapping to Result Handling**:
- status="success" → on_success behavior (continue or prompt)
- status="warning" → on_warning behavior (continue, prompt, or stop)
- status="failure" → on_failure IMMUTABLE behavior (always stop)

### Multiple Errors/Warnings Support

**Decision**: Support arrays of errors/warnings, status reflects worst case.

**Rationale**:
- Real operations often have multiple issues
- Manager can handle each differently if needed
- Overall status reflects severity: failure > warning > success
- Intelligent prompts can show all issues to user

**Example**:
```javascript
{
  status: "warning",  // Reflects worst case (multiple warnings, no errors)
  message: "Operation completed with issues",
  warnings: [
    "Deprecated API call",
    "Missing type annotations",
    "Performance warning"
  ],
  warning_analysis: "The deprecated API will be removed in v3.0..."
}
```

### Analysis and Suggestions

**Decision**: Include optional analysis and suggestions for intelligent prompts.

**Rationale**:
- Enables manager to provide helpful guidance
- Reduces user burden of diagnosing issues
- Supports recovery workflow
- Makes failures less frustrating

**Examples**:
- error_analysis: "Database connection timeout - likely network issue"
- suggested_fixes: ["Check network connectivity", "Retry with longer timeout"]

---

## Implementation Plan

### Phase 1: Response Format Specification (Week 1)

1. Create response format documentation
2. Define JSON schema for responses
3. Create response-validator skill
4. Update faber-manager to validate responses

**Artifacts**:
- `plugins/faber/docs/RESPONSE-FORMAT.md`
- `plugins/faber/config/schemas/skill-response.schema.json`
- `plugins/faber/skills/response-validator/`
- Updated faber-manager.md

### Phase 2: FABER Plugin Skill Updates (Weeks 2-4)

Priority order:
1. **Week 2**: Core phase skills (frame, architect, build, evaluate, release)
2. **Week 2**: Automatic primitives (issue-fetcher, branch-creator, pr-creator)
3. **Week 3**: fractary-spec plugin skills (spec-generator, spec-validator, spec-archiver)
4. **Week 3**: Other FABER utility skills
5. **Week 4**: Testing and validation

**Per-Skill Checklist**:
- [ ] Review current response format
- [ ] Update to return standardized response
- [ ] Add error/warning analysis
- [ ] Add suggested fixes
- [ ] Update skill documentation
- [ ] Test response validation
- [ ] Document error cases

### Phase 3: Cross-Project Guidance (Weeks 4-5)

1. Create best practices guide
2. Create skill response template
3. Update plugin standards
4. Create migration guide

**Artifacts**:
- `docs/standards/SKILL-RESPONSE-BEST-PRACTICES.md`
- `plugins/faber/templates/skill-response-template.md`
- `docs/guides/MIGRATE-SKILL-RESPONSES.md`
- Updated `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`

### Phase 4: Audit and Validation Tooling (Week 5)

1. Enhance audit-project command
2. Create response validator script
3. Integrate schema validation into manager
4. Test on multiple projects

**Artifacts**:
- Enhanced audit-project.md
- `scripts/validate-skill-responses.sh`
- Integration into faber-manager response handling

### Phase 5: Documentation and Release (Week 5)

1. Update all relevant documentation
2. Create migration guide for projects
3. Prepare release notes
4. Provide training/examples

**Artifacts**:
- Updated docs
- Migration guide
- Release notes
- Code examples

---

## Response Format Reference

### Success Response

```javascript
{
  "status": "success",
  "message": "Specification generated successfully",
  "details": {
    "spec_path": "/specs/WORK-00235-workflow-responses.md",
    "word_count": 2847,
    "sections": 7
  }
}
```

### Warning Response

```javascript
{
  "status": "warning",
  "message": "Build completed with deprecated API usage",
  "details": {
    "files_compiled": 45,
    "warnings_found": 3
  },
  "warnings": [
    "Deprecated API: useCallback (will be removed in v3.0)",
    "Performance: Large bundle size (2.5MB)",
    "Missing type annotations in 2 files"
  ],
  "warning_analysis": "The deprecated API usage should be addressed before next major version.",
  "suggested_fixes": [
    "Replace useCallback with useMemo",
    "Code split lazy-loaded components",
    "Add type annotations to exported functions"
  ]
}
```

### Failure Response

```javascript
{
  "status": "failure",
  "message": "Test suite failed - 5 tests failed",
  "details": {
    "total_tests": 47,
    "passed": 42,
    "failed": 5,
    "skipped": 0
  },
  "errors": [
    "test_auth_login: AssertionError: expected true but got false",
    "test_auth_logout: TimeoutError: HTTP request timeout",
    "test_token_refresh: KeyError: 'refresh_token' not in response"
  ],
  "error_analysis": "Authentication tests are failing due to session handling issues. The logout handler is not properly awaiting async cleanup, and token refresh validation is incorrect.",
  "suggested_fixes": [
    "Add await to session.cleanup() in logout handler",
    "Check token refresh expiry calculation",
    "Verify session state is cleared before new login"
  ]
}
```

---

## Testing Strategy

### Unit Tests

- [ ] Response format validation
- [ ] Status enum validation
- [ ] Error/warning array handling
- [ ] Multiple error/warning scenarios
- [ ] Missing optional fields

### Integration Tests

- [ ] Manager processes responses correctly
- [ ] Result handling routing works (success/warning/failure)
- [ ] Intelligent prompts generated correctly
- [ ] Error/warning arrays parsed properly

### Audit Tests

- [ ] audit-project identifies response format issues
- [ ] Validator script works on multiple projects
- [ ] Migration checklist is accurate

### E2E Tests

- [ ] Full workflow with standardized responses
- [ ] Warning prompt flow
- [ ] Failure recovery flow
- [ ] Logging includes response details

---

## Success Criteria

1. **Response Format Standardized**: All FABER and project skills return consistent response objects
2. **Schema Enforced**: JSON schema validates all responses
3. **FABER Skills Updated**: All FABER plugin skills return standardized responses
4. **Cross-Project Guidance**: Clear path for projects to update custom skills
5. **Audit Integration**: audit-project identifies response format gaps and provides fixes
6. **Manager Integration**: Manager handles all response types with intelligent prompts
7. **Documentation Complete**: Best practices guide, migration guide, and examples
8. **Backward Compatible**: Old response formats still work with deprecation warnings

---

## Related Issues

- #228 - Set default FABER workflow step result_handling
- #232 - FABER workflow validation should make sure step names are unique
- #226 - FABER workflow reliability enhancements
- #224 - Plugin init configuration refactor

---

## Deliverables

### Documentation
- `plugins/faber/docs/RESPONSE-FORMAT.md` - Full specification
- `docs/standards/SKILL-RESPONSE-BEST-PRACTICES.md` - Best practices for developers
- `docs/guides/MIGRATE-SKILL-RESPONSES.md` - Migration guide for existing projects
- `plugins/faber/templates/skill-response-template.md` - Skill template

### Code
- `plugins/faber/config/schemas/skill-response.schema.json` - JSON schema
- `plugins/faber/skills/response-validator/` - Response validator skill
- Updated FABER skills (frame, architect, build, evaluate, release, etc.)
- Updated fractary-spec plugin skills
- Enhanced audit-project tooling

### Scripts
- `scripts/validate-skill-responses.sh` - Response format validator script
- `scripts/migrate-skill-responses.sh` - Migration helper script

### Configuration
- Updated workflow schema to reference response format
- Example workflows showing response handling

---

## Notes

- This specification builds on recent work on result_handling (#228) and step validation (#232)
- Response format is backward compatible with deprecation layer
- Cross-project guidance is critical for adoption
- Audit tooling is essential for discovering gaps in existing projects
- Consider this a foundational piece for intelligent workflow orchestration

---

**Next Steps**: Begin Phase 1 - Response Format Specification. Create documentation and schema, then implement response-validator skill. This provides foundation for all subsequent work.
