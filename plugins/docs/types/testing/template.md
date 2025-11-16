---
title: "{{test_suite_name}}"
fractary_doc_type: testing
test_type: {{test_type}}
component: {{component}}
status: {{status}}
version: {{version}}
created: {{created}}
updated: {{updated}}
author: {{author}}
tags: {{#tags}}{{.}}, {{/tags}}
codex_sync: true
generated: true
---

# {{test_suite_name}} - Testing Documentation

**Version**: {{version}}
**Test Type**: {{test_type}}
**Component**: {{component}}
**Last Updated**: {{updated}}

---

## Overview

{{description}}

## Test Plan

{{#test_plan}}
### Objective
{{objective}}

### Scope
{{scope}}

### Test Cases

{{#test_cases}}
#### {{id}}: {{name}}
- **Type**: {{type}}
- **Priority**: {{priority}}
- **Procedure**:
  {{procedure}}
{{#preconditions}}
- **Preconditions**:
{{#preconditions}}
  - {{.}}
{{/preconditions}}
{{/preconditions}}
- **Expected Result**: {{expected_result}}

{{/test_cases}}

### Coverage Requirements
{{#coverage_requirements}}
- **Minimum Line Coverage**: {{minimum_line_coverage}}%
- **Minimum Branch Coverage**: {{minimum_branch_coverage}}%
- **Minimum Function Coverage**: {{minimum_function_coverage}}%
{{/coverage_requirements}}
{{/test_plan}}

## Test Results

{{#test_results}}
### Latest Execution: {{execution_id}}
**Executed**: {{execution_timestamp}}
**Environment**: {{environment}}
**Executed By**: {{executed_by}}

### Summary
- **Total Tests**: {{summary.total_tests}}
- **✅ Passed**: {{summary.passed}}
- **❌ Failed**: {{summary.failed}}
- **⏭️ Skipped**: {{summary.skipped}}
- **Pass Rate**: {{summary.pass_rate}}%

{{#failures}}
### Failures

{{#test_case_results}}
{{#failed}}
#### {{id}}: {{name}}
- **Error**: {{error_message}}
- **Duration**: {{duration_ms}}ms
{{#stack_trace}}
- **Stack Trace**:
  ```
  {{stack_trace}}
  ```
{{/stack_trace}}

{{/failed}}
{{/test_case_results}}
{{/failures}}

### Coverage Achieved
{{#coverage_achieved}}
- **Line Coverage**: {{line_coverage}}% {{#met_line_requirement}}✅{{/met_line_requirement}}{{^met_line_requirement}}❌{{/met_line_requirement}}
- **Branch Coverage**: {{branch_coverage}}% {{#met_branch_requirement}}✅{{/met_branch_requirement}}{{^met_branch_requirement}}❌{{/met_branch_requirement}}
- **Function Coverage**: {{function_coverage}}% {{#met_function_requirement}}✅{{/met_function_requirement}}{{^met_function_requirement}}❌{{/met_function_requirement}}

{{#uncovered_areas}}
**Uncovered Areas**:
{{#uncovered_areas}}
- `{{file}}`:{{lines}}
{{/uncovered_areas}}
{{/uncovered_areas}}
{{/coverage_achieved}}

### Performance
{{#performance_metrics}}
- **Total Duration**: {{total_duration}}
- **Avg Test Duration**: {{avg_test_duration}}
- **Slowest Test**: {{slowest_test}} ({{slowest_duration}})
{{/performance_metrics}}
{{/test_results}}

## Validation Steps

{{#validation_steps}}
### Pre-Deployment Validation
{{#pre_deployment_validation}}
{{#pre_deployment_validation}}
{{step}}. {{description}}
{{/pre_deployment_validation}}
{{/pre_deployment_validation}}

### Post-Deployment Validation
{{#post_deployment_validation}}
{{#post_deployment_validation}}
{{step}}. {{description}}
{{/post_deployment_validation}}
{{/post_deployment_validation}}

### Data Validation
{{#data_validation}}
{{#data_validation}}
- {{check}} ({{criteria}})
{{/data_validation}}
{{/data_validation}}
{{/validation_steps}}

## QA Process

{{#qa_process}}
### Quality Gates
{{#quality_gates}}
{{#quality_gates}}
- {{gate}}: {{status}}
{{/quality_gates}}
{{/quality_gates}}

### Review Checklist
{{#review_checklist}}
{{#review_checklist}}
- [ ] {{item}}
{{/review_checklist}}
{{/review_checklist}}

### Acceptance Criteria
{{#acceptance_criteria}}
{{#acceptance_criteria}}
- {{criterion}}
{{/acceptance_criteria}}
{{/acceptance_criteria}}
{{/qa_process}}

## Performance Benchmarks

{{#performance_benchmarks}}
### Baseline Metrics
{{#baseline_metrics}}
{{#baseline_metrics}}
- **{{name}}**: {{value}} {{unit}}
{{/baseline_metrics}}
{{/baseline_metrics}}

### Current Metrics
{{#current_metrics}}
{{#current_metrics}}
- **{{name}}**: {{value}} {{unit}}
{{/current_metrics}}
{{/current_metrics}}

**Status**: {{benchmark_status}}
{{#regression_detected}}
⚠️ **Regression Detected**: Performance degraded beyond {{regression_threshold}} threshold
{{/regression_detected}}
{{/performance_benchmarks}}

---

*Generated with fractary-docs plugin*
*Test specification: [testing.json](./testing.json)*
