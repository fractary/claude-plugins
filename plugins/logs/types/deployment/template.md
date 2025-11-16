---
log_type: deployment
title: "{{title}}"
deployment_id: {{deployment_id}}
issue_number: {{issue_number}}
date: {{date}}
status: {{status}}
environment: {{environment}}
version: {{version}}
commit_sha: {{commit_sha}}
deployment_tool: {{deployment_tool}}
duration_seconds: {{duration_seconds}}
---

# Deployment Log: {{title}}

**Deployment ID**: `{{deployment_id}}`
**Environment**: {{environment}}
**Version**: {{version}}
**Status**: {{status}}
**Duration**: {{duration_seconds}}s

## Deployment Metadata

- **Commit**: `{{commit_sha}}`
- **Tool**: {{deployment_tool}}
- **Triggered By**: {{triggered_by}}
- **Date**: {{date}}

## Pre-Deployment Checks

{{#pre_checks}}
- {{check_name}}: {{status}}
{{/pre_checks}}

## Deployment Steps

{{#steps}}
{{step_number}}. **{{name}}** ({{duration}}s)
   - Status: {{status}}
   - Details: {{details}}
{{/steps}}

## Changes Deployed

{{#changes}}
- {{type}}: {{description}} ({{commit_short}})
{{/changes}}

## Services Updated

{{#services}}
- **{{name}}**: {{old_version}} → {{new_version}}
{{/services}}

## Health Checks

{{#health_checks}}
- {{service}}: {{status}} ({{response_time}}ms)
{{/health_checks}}

## Rollback Plan

{{rollback_plan}}

## Deployment Summary

{{summary}}

## Issues Encountered

{{#issues}}
- **{{severity}}**: {{description}}
  - Resolution: {{resolution}}
{{/issues}}

## Deployment End

**End Time**: {{end_time}}
**Final Status**: {{final_status}}
**Services Healthy**: {{services_healthy}}/{{services_total}}
