# Test Log Standards

## Purpose
Capture test execution results for quality assurance and regression tracking.

## Required Sections
- Test Results (total, passed, failed, skipped, duration)
- Failed Tests (with error messages and stack traces)
- Test Coverage (lines, branches, functions)

## Capture Rules
**ALWAYS capture**: All test results, failures with stack traces, coverage metrics
**REDACT**: Test data containing PII or secrets

## Retention
- Local: 3 days
- Cloud: 7 days
- Priority: low
