---
log_type: session
title: "{{title}}"
session_id: {{session_id}}
issue_number: {{issue_number}}
date: {{date}}
status: {{status}}
conversation_id: {{conversation_id}}
repository: {{repository}}
branch: {{branch}}
model: {{model}}
token_count: {{token_count}}
duration_seconds: {{duration_seconds}}
---

# Session Log: {{title}}

**Session ID**: `{{session_id}}`
**Issue**: {{#issue_number}}#{{issue_number}}{{/issue_number}}{{^issue_number}}N/A{{/issue_number}}
**Date**: {{date}}
**Status**: {{status}}
**Duration**: {{duration_seconds}}s
**Tokens Used**: {{token_count}}

## Session Metadata

- **Conversation ID**: `{{conversation_id}}`
- **Repository**: `{{repository}}`
- **Branch**: `{{branch}}`
- **Model**: `{{model}}`

## Conversation Log

{{conversation_content}}

## Session Summary

{{summary}}

## Key Decisions

{{#decisions}}
- {{.}}
{{/decisions}}

## Action Items

{{#action_items}}
- [ ] {{.}}
{{/action_items}}

## Files Modified

{{#files_modified}}
- `{{path}}`: {{description}}
{{/files_modified}}

## Commands Executed

{{#commands}}
- `{{command}}`: {{result}}
{{/commands}}

## Context Switches

{{#context_switches}}
- {{timestamp}}: {{description}}
{{/context_switches}}

## Session End

**End Time**: {{end_time}}
**Final Status**: {{final_status}}
**Outcome**: {{outcome}}
