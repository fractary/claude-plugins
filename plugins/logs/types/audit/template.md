---
log_type: audit
title: "{{title}}"
audit_id: {{audit_id}}
date: {{date}}
status: {{status}}
audit_type: {{audit_type}}
severity: {{severity}}
user: {{user}}
action: {{action}}
resource: {{resource}}
---

# Audit Log: {{title}}

**Audit ID**: `{{audit_id}}`
**Type**: {{audit_type}}
**Severity**: {{severity}}
**User**: {{user}}
**Date**: {{date}}

## Action Summary

**Action**: {{action}}
**Resource**: {{resource}}
**Status**: {{status}}

## Details

{{details}}

## Context

{{#context}}
- **{{key}}**: {{value}}
{{/context}}

## Security Information

{{#security_context}}
- **IP Address**: {{ip_address}}
- **User Agent**: {{user_agent}}
- **Authentication Method**: {{auth_method}}
- **Session ID**: {{session_id}}
{{/security_context}}

## Changes Made

{{#changes}}
### {{resource_type}}: {{resource_name}}

**Before**:
```
{{before}}
```

**After**:
```
{{after}}
```
{{/changes}}

## Compliance Notes

{{compliance_notes}}

## Related Events

{{#related_events}}
- **{{event_id}}**: {{event_description}} ({{event_date}})
{{/related_events}}

## Audit Trail

{{audit_trail}}
