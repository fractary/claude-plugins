---
log_type: build
title: "{{title}}"
build_id: {{build_id}}
issue_number: {{issue_number}}
date: {{date}}
status: {{status}}
repository: {{repository}}
branch: {{branch}}
commit_sha: {{commit_sha}}
build_tool: {{build_tool}}
exit_code: {{exit_code}}
duration_seconds: {{duration_seconds}}
---

# Build Log: {{title}}

**Build ID**: `{{build_id}}`
**Issue**: {{#issue_number}}#{{issue_number}}{{/issue_number}}{{^issue_number}}N/A{{/issue_number}}
**Date**: {{date}}
**Status**: {{status}}
**Duration**: {{duration_seconds}}s
**Exit Code**: {{exit_code}}

## Build Metadata

- **Repository**: `{{repository}}`
- **Branch**: `{{branch}}`
- **Commit**: `{{commit_sha}}`
- **Build Tool**: `{{build_tool}}`

## Build Output

### stdout

```
{{stdout}}
```

### stderr

```
{{stderr}}
```

## Errors

{{#errors}}
- **{{file}}:{{line}}**: {{message}}
{{/errors}}

## Warnings

{{#warnings}}
- **{{file}}:{{line}}**: {{message}}
{{/warnings}}

## Artifacts

{{#artifacts}}
- `{{path}}` ({{size}})
{{/artifacts}}

## Build Summary

{{summary}}

## Performance Metrics

- **Compile Time**: {{compile_time}}s
- **Link Time**: {{link_time}}s
- **Total Time**: {{duration_seconds}}s
- **Peak Memory**: {{peak_memory_mb}}MB

## Dependencies

{{#dependencies}}
- {{name}}: {{version}}
{{/dependencies}}

## Build End

**End Time**: {{end_time}}
**Final Status**: {{final_status}}
**Exit Code**: {{exit_code}}
