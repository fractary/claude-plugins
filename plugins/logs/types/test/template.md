---
log_type: test
title: "{{title}}"
test_id: {{test_id}}
date: {{date}}
status: {{status}}
test_suite: {{test_suite}}
test_framework: {{test_framework}}
total_tests: {{total_tests}}
passed_tests: {{passed_tests}}
failed_tests: {{failed_tests}}
duration_seconds: {{duration_seconds}}
---

# Test Log: {{title}}

**Test ID**: `{{test_id}}`
**Suite**: {{test_suite}}
**Framework**: {{test_framework}}
**Status**: {{status}}

## Test Results

- **Total**: {{total_tests}}
- **Passed**: {{passed_tests}}
- **Failed**: {{failed_tests}}
- **Skipped**: {{skipped_tests}}
- **Duration**: {{duration_seconds}}s

## Failed Tests

{{#failed_test_cases}}
- **{{name}}**: {{error_message}}
  ```
  {{stack_trace}}
  ```
{{/failed_test_cases}}

## Test Coverage

- **Lines**: {{coverage_lines}}%
- **Branches**: {{coverage_branches}}%
- **Functions**: {{coverage_functions}}%

## Summary

{{summary}}
