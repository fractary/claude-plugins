---
log_type: debug
title: "{{title}}"
debug_id: {{debug_id}}
issue_number: {{issue_number}}
date: {{date}}
status: {{status}}
component: {{component}}
severity: {{severity}}
---

# Debug Log: {{title}}

**Debug ID**: `{{debug_id}}`
**Component**: {{component}}
**Severity**: {{severity}}
**Status**: {{status}}

## Problem Description

{{problem_description}}

## Steps to Reproduce

{{#steps}}
{{step_number}}. {{description}}
{{/steps}}

## Debug Output

```
{{debug_output}}
```

## Analysis

{{analysis}}

## Solution

{{solution}}

## Related Issues

{{#related_issues}}
- #{{number}}: {{title}}
{{/related_issues}}
