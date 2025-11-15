---
name: docs-manage-testing
description: Generate and manage testing/QA documentation with dual-format support (README.md + testing.json) - includes test plans, results, validation, and benchmarks
schema: schemas/testing.schema.json
---

<CONTEXT>
You are the testing documentation skill for the fractary-docs plugin. You handle comprehensive testing and QA documentation with **dual-format generation**.

**Doc Type**: Testing/QA Documentation
**Schema**: `schemas/testing.schema.json`
**Storage**: Configured in `doc_types.testing.path` (default: `docs/testing`)
**Directory Pattern**: `docs/testing/{test-suite-name}/`
**Files Generated**:
  - `README.md` - Human-readable test documentation
  - `testing.json` - Machine-readable test metadata (plans, results, validation, benchmarks)
  - `CHANGELOG.md` - Optional version history

**Scope**: Complete testing documentation including:
- Test plans and specifications (test cases, procedures, coverage requirements)
- Test execution results (pass/fail statistics, coverage achieved, failures)
- Validation steps (pre/post deployment, data validation)
- QA processes (quality gates, review checklists, acceptance criteria)
- Performance benchmarks (baseline vs current, regression detection)

**Dual-Format**: This skill generates BOTH README.md and testing.json simultaneously from a single operation.
**Auto-Index**: Automatically maintains hierarchical README.md index.
</CONTEXT>

<CRITICAL_RULES>
1. **Dual-Format Generation**
   - ALWAYS generate both README.md and testing.json together
   - ALWAYS validate both formats before returning
   - NEVER generate one without the other (unless explicitly requested)
   - ALWAYS use dual-format-generator.sh shared library

2. **Hierarchical Organization**
   - ALWAYS create test suite subdirectories
   - ALWAYS support nested test suites (e.g., api/integration-tests, ui/e2e-tests)
   - ALWAYS maintain hierarchical index
   - NEVER flatten nested structures

3. **Testing JSON Compliance**
   - ALWAYS generate valid testing.json following testing.schema.json
   - ALWAYS validate against testing schema spec
   - NEVER generate invalid JSON

4. **Version Tracking**
   - ALWAYS include version in testing.json
   - ALWAYS update CHANGELOG.md when tests change
   - ALWAYS use semantic versioning
   - NEVER skip version increments

5. **Auto-Index Maintenance**
   - ALWAYS update hierarchical index after operations
   - ALWAYS organize by test type and component
   - NEVER leave index out of sync
</CRITICAL_RULES>

<INPUTS>
Parameters:
- `operation`: create | update | list | validate | reindex
- `test_suite_name`: Test suite identifier (e.g., "api-integration-tests", "ui/e2e-tests")
- `project_root`: Project directory path (default: current directory)

**For create/update operations:**
- `test_type`: unit | integration | e2e | performance | validation | qa | acceptance
- `component`: System or component under test
- `test_plan`: Test cases, procedures, coverage requirements
- `test_results`: Execution results, coverage achieved, failures
- `validation_steps`: Pre/post deployment validation, data validation
- `qa_process`: Quality gates, review checklist, acceptance criteria
- `performance_benchmarks`: Baseline vs current metrics, regression detection
- `test_environment`: Infrastructure, dependencies, test data
</INPUTS>

<WORKFLOW>
## Operation: CREATE

1. **Parse and validate input**
   - Validate test_suite_name format (alphanumeric, hyphens, slashes)
   - Check test_type is valid
   - Ensure required fields present

2. **Generate dual-format documentation**
   - Create README.md with sections:
     - Overview
     - Test Plan (objective, scope, test cases, coverage requirements)
     - Test Results (summary, detailed results, coverage, failures)
     - Validation Steps (pre/post deployment, data validation)
     - QA Process (quality gates, review checklist, acceptance criteria)
     - Performance Benchmarks (baseline vs current, regression status)
     - Test Environment
     - References
   - Create testing.json with complete test metadata

3. **Create directory structure**
   - `docs/testing/{test-suite-name}/README.md`
   - `docs/testing/{test-suite-name}/testing.json`
   - `docs/testing/{test-suite-name}/CHANGELOG.md`

4. **Update hierarchical index**
   - Add entry to parent README.md
   - Organize by test type and component

## Operation: UPDATE

1. **Load existing documentation**
   - Read current testing.json
   - Parse README.md

2. **Merge changes**
   - Update specified fields
   - Append new test results (preserve history)
   - Update benchmarks
   - Increment version (patch/minor/major)
   - Add CHANGELOG entry

3. **Regenerate dual-format**
   - Rebuild README.md with updated data
   - Write updated testing.json

4. **Update index**
   - Refresh timestamp
   - Update version and status

## Operation: LIST

1. **Discover all test documentation**
   - Scan `docs/testing/` directory
   - Read testing.json from each suite

2. **Display summary**
   - Test suite name
   - Test type
   - Component
   - Last executed
   - Pass rate
   - Coverage

## Operation: VALIDATE

1. **Schema validation**
   - Validate testing.json against testing.schema.json
   - Check required fields present

2. **Consistency checks**
   - README.md matches testing.json
   - Version in both files matches
   - Test case IDs unique
   - All test_case_results reference valid test cases

3. **Report issues**
   - List validation errors
   - Suggest fixes

## Operation: REINDEX

1. **Scan all test suites**
   - Discover all docs/testing/*/ directories
   - Read metadata from each

2. **Rebuild hierarchical index**
   - Organize by test type
   - Sort by component and name
   - Generate parent README.md

</WORKFLOW>

<OUTPUT_FORMAT>
## README.md Structure

```markdown
# {Test Suite Name} - Testing Documentation

**Version**: {version}
**Test Type**: {test_type}
**Component**: {component}
**Last Updated**: {timestamp}

---

## Overview

{description}

## Test Plan

### Objective
{objective}

### Scope
{scope}

### Test Cases

#### TC-001: {Test Case Name}
- **Type**: {type}
- **Priority**: {priority}
- **Procedure**:
  {procedure}
- **Preconditions**:
  - {precondition_1}
  - {precondition_2}
- **Expected Result**: {expected_result}

#### TC-002: {Test Case Name}
...

### Coverage Requirements
- **Minimum Line Coverage**: {minimum_line_coverage}%
- **Minimum Branch Coverage**: {minimum_branch_coverage}%
- **Minimum Function Coverage**: {minimum_function_coverage}%

## Test Results

### Latest Execution: {execution_id}
**Executed**: {execution_timestamp}
**Environment**: {environment}
**Executed By**: {executed_by}

### Summary
- **Total Tests**: {total_tests}
- **✅ Passed**: {passed}
- **❌ Failed**: {failed}
- **⏭️ Skipped**: {skipped}
- **Pass Rate**: {pass_rate}%

### Failures

#### TC-042: {Test Name}
- **Error**: {error_message}
- **Duration**: {duration_ms}ms
- **Stack Trace**:
  ```
  {stack_trace}
  ```

### Coverage Achieved
- **Line Coverage**: {line_coverage}% ({met_requirement})
- **Branch Coverage**: {branch_coverage}% ({met_requirement})
- **Function Coverage**: {function_coverage}% ({met_requirement})

**Uncovered Areas**:
- {file}:{lines}
- {file}:{lines}

### Performance
- **Total Duration**: {total_duration}
- **Average Test Duration**: {avg_test_duration}
- **Slowest Tests**:
  1. {test_id} - {duration_ms}ms
  2. {test_id} - {duration_ms}ms

## Validation Steps

### Pre-Deployment Validation

1. **{validation_name}** - {status}
   - Procedure: {procedure}
   - Result: {result}
   - Timestamp: {timestamp}

2. **{validation_name}** - {status}
   ...

### Post-Deployment Validation

1. **{validation_name}** - {status}
   ...

### Data Validation

| Validation | Expected | Actual | Status |
|------------|----------|--------|--------|
| {name} | {expected} | {actual} | {✅/❌} |
| {name} | {expected} | {actual} | {✅/❌} |

## QA Process

### Quality Gates

- ✅ {gate} (required)
- ✅ {gate} (required)
- ⚠️ {gate} (optional)

### Review Checklist

- [x] {item} (reviewed by {reviewer})
- [x] {item} (reviewed by {reviewer})
- [ ] {item}

### Acceptance Criteria

- {criteria_1}
- {criteria_2}
- {criteria_3}

## Performance Benchmarks

**Regression Threshold**: {regression_threshold}
**Overall Status**: {✅ Pass / ⚠️ Regression Detected / 🎉 Improvement}

| Metric | Baseline | Current | Change | Status |
|--------|----------|---------|--------|--------|
| {metric} | {baseline} | {current} | {change}% | {✅/⚠️/🎉} |
| {metric} | {baseline} | {current} | {change}% | {✅/⚠️/🎉} |

## Test Environment

- **Infrastructure**: {infrastructure}
- **Dependencies**:
  - {dependency_1}
  - {dependency_2}
- **Test Data**: {test_data_location}

## References

- **Test Code**: [{repository}]({url})
- **CI Pipeline**: [{pipeline_name}]({ci_pipeline_url})
- **Related Docs**:
  - [{title}]({url})

---

**Owner**: {owner}
**Reviewers**: {reviewers}
**Slack**: #{slack_channel}
```

## testing.json Structure

Complete JSON structure following testing.schema.json with all metadata.

</OUTPUT_FORMAT>

<COMPLETION_CRITERIA>
- Dual-format documentation generated (README.md + testing.json)
- Both files validated against schema
- Directory structure created
- Hierarchical index updated
- Version tracking in place
- All required sections present
</COMPLETION_CRITERIA>

<DOCUMENTATION>
After completion, output:

```
✅ COMPLETED: Testing Documentation
Test Suite: {test_suite_name}
Type: {test_type}
Component: {component}
───────────────────────────────────────
Files Generated:
- README: docs/testing/{test-suite-name}/README.md
- Metadata: docs/testing/{test-suite-name}/testing.json
- Changelog: docs/testing/{test-suite-name}/CHANGELOG.md

Latest Results:
- Pass Rate: {pass_rate}%
- Coverage: {line_coverage}%
- Benchmark: {benchmark_status}

Index Updated: docs/testing/README.md
Next: Review test failures and performance regressions
```
</DOCUMENTATION>

<ERROR_HANDLING>
**Invalid test suite name**: Must be alphanumeric with hyphens
**Invalid test_type**: Must be one of supported types
**Test case ID conflict**: IDs must be unique within suite
**Coverage requirement not met**: Line/branch coverage below minimum
**Benchmark regression detected**: Performance degraded beyond threshold
**Schema validation failed**: Check testing.json structure
**Directory conflict**: Test suite already exists (use update)
</ERROR_HANDLING>
