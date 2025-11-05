# SPEC-0029-08: Spec Plugin Architecture

**Issue**: #29
**Phase**: 3 (fractary-spec Plugin)
**Dependencies**: SPEC-0029-01, SPEC-0029-02, SPEC-0029-03 (fractary-file), SPEC-0029-04 (fractary-docs concepts)
**Status**: Draft
**Created**: 2025-01-15

## Overview

Create the fractary-spec plugin for managing ephemeral specifications tied to work items. Unlike docs (living state), specs are point-in-time requirements that become stale once work completes. This plugin manages the full lifecycle: generation from issues, validation against implementation, and archival to cloud storage when work completes.

## Key Principles

1. **Issue-Centric**: Specs tied to issue numbers (not work_id)
2. **Ephemeral**: Specs are temporary, archived after completion
3. **Lifecycle-Based**: Archive on issue close, PR merge, not time-based
4. **Multi-Spec Support**: One issue can have multiple specs (phases)
5. **Dual Storage**: Local while active, cloud when archived
6. **Prevents Confusion**: Old specs removed from local to avoid context pollution

## Plugin Structure

```
plugins/spec/
├── .claude-plugin/
│   └── plugin.json                  # Dependencies: fractary-file, fractary-work
├── agents/
│   └── spec-manager.md             # Specification orchestrator
├── commands/
│   ├── init.md                     # /fractary-spec:init
│   ├── generate.md                 # /fractary-spec:generate <issue>
│   ├── validate.md                 # /fractary-spec:validate <issue>
│   ├── archive.md                  # /fractary-spec:archive <issue>
│   └── read.md                     # /fractary-spec:read <issue>
├── skills/
│   ├── spec-generator/             # Generate from issue
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   └── spec-format-guide.md
│   │   ├── templates/
│   │   │   ├── spec-basic.md.template
│   │   │   ├── spec-infrastructure.md.template
│   │   │   ├── spec-api.md.template
│   │   │   └── spec-feature.md.template
│   │   ├── scripts/
│   │   │   ├── fetch-issue.sh
│   │   │   ├── generate-spec.sh
│   │   │   └── link-to-issue.sh
│   │   └── workflow/
│   │       └── generate-from-issue.md
│   ├── spec-validator/             # Validate implementation
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   └── validation-checklist.md
│   │   ├── scripts/
│   │   │   ├── check-completeness.sh
│   │   │   ├── validate-requirements.sh
│   │   │   └── update-validation-status.sh
│   │   └── workflow/
│   │       └── validate-against-spec.md
│   ├── spec-archiver/              # Archive to cloud
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   └── archive-process.md
│   │   ├── scripts/
│   │   │   ├── collect-specs.sh
│   │   │   ├── upload-to-cloud.sh
│   │   │   ├── update-index.sh
│   │   │   └── comment-on-issue.sh
│   │   └── workflow/
│   │       └── archive-issue-specs.md
│   └── spec-linker/                # Link specs to issues/PRs
│       ├── SKILL.md
│       └── scripts/
│           ├── link-spec-to-issue.sh
│           └── update-issue-comment.sh
├── config/
│   └── config.example.json
└── README.md
```

## Configuration Schema

```json
{
  "schema_version": "1.0",
  "storage": {
    "local_path": "/specs",
    "cloud_archive_path": "archive/specs/{year}/{issue_number}.md",
    "archive_index_file": ".archive-index.json"
  },
  "naming": {
    "pattern": "spec-{issue_number}-{slug}.md",
    "multi_spec_pattern": "spec-{issue_number}-phase{phase}-{slug}.md"
  },
  "archive": {
    "strategy": "lifecycle",
    "auto_archive_on": {
      "issue_close": true,
      "pr_merge": true,
      "faber_release": true
    },
    "pre_archive": {
      "check_docs_updated": "warn",
      "prompt_user": true,
      "require_validation": false
    },
    "post_archive": {
      "update_archive_index": true,
      "comment_on_issue": true,
      "comment_on_pr": true,
      "remove_from_local": true
    }
  },
  "integration": {
    "work_plugin": "fractary-work",
    "file_plugin": "fractary-file",
    "link_to_issue": true,
    "update_issue_on_create": true,
    "update_issue_on_archive": true
  },
  "templates": {
    "default": "spec-basic",
    "custom_template_dir": null
  }
}
```

## Spec Format

### Basic Spec Template (spec-basic.md.template)

```markdown
---
spec_id: spec-{{issue_number}}-{{slug}}
issue_number: {{issue_number}}
issue_url: {{issue_url}}
title: {{title}}
type: {{work_type}}
status: draft
created: {{date}}
author: {{author}}
validated: false
---

# Specification: {{title}}

**Issue**: [#{{issue_number}}]({{issue_url}})
**Type**: {{work_type}}
**Status**: Draft
**Created**: {{date}}

## Summary

{{summary}}

## Requirements

### Functional Requirements
{{#functional_requirements}}
- {{.}}
{{/functional_requirements}}

### Non-Functional Requirements
{{#non_functional_requirements}}
- {{.}}
{{/non_functional_requirements}}

## Technical Approach

{{technical_approach}}

## Files to Modify

{{#files}}
- `{{path}}`: {{description}}
{{/files}}

## Acceptance Criteria

{{#acceptance_criteria}}
- [ ] {{.}}
{{/acceptance_criteria}}

## Testing Strategy

{{testing_strategy}}

## Dependencies

{{#dependencies}}
- {{.}}
{{/dependencies}}

## Risks

{{#risks}}
- **{{risk}}**: {{mitigation}}
{{/risks}}

## Implementation Notes

{{notes}}
```

## Archive Index Format

```json
{
  "schema_version": "1.0",
  "last_updated": "2025-01-15T10:30:00Z",
  "archives": [
    {
      "issue_number": "123",
      "issue_url": "https://github.com/org/repo/issues/123",
      "pr_url": "https://github.com/org/repo/pull/456",
      "archived_at": "2025-01-15T10:00:00Z",
      "specs": [
        {
          "filename": "spec-123-phase1-user-auth.md",
          "cloud_url": "https://storage.example.com/archive/specs/2025/123-phase1.md",
          "size_bytes": 15420,
          "checksum": "sha256:abc...",
          "validated": true
        },
        {
          "filename": "spec-123-phase2-oauth.md",
          "cloud_url": "https://storage.example.com/archive/specs/2025/123-phase2.md",
          "size_bytes": 18920,
          "checksum": "sha256:def...",
          "validated": true
        }
      ]
    }
  ]
}
```

## Agent Specification

**agents/spec-manager.md**:

```markdown
<CONTEXT>
You are the spec-manager agent for the fractary-spec plugin. You orchestrate the lifecycle of ephemeral specifications tied to work items: generation from issues, validation against implementation, and archival to cloud storage when work completes.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS tie specs to issue numbers (not work_id)
2. ALWAYS archive specs when work completes (keep local clean)
3. ALWAYS update GitHub issue with spec location
4. NEVER delete specs without archiving first
5. ALWAYS warn if docs not updated before archiving
6. ALWAYS support multiple specs per issue
</CRITICAL_RULES>

<WORKFLOW>

## Generate Spec
1. Receive issue number
2. Fetch issue details via fractary-work plugin
3. Classify work type (bug, feature, infrastructure, etc.)
4. Select appropriate template
5. Generate spec from issue metadata
6. Save to local /specs directory
7. Link spec to issue (comment on GitHub)
8. Return spec path

## Validate Spec
1. Receive issue number
2. Find all specs for issue
3. Check acceptance criteria against implementation
4. Update validation status in spec
5. Report completeness
6. Return validation result

## Archive Spec
1. Receive issue number
2. Find all specs for issue (multi-spec support)
3. Check pre-archive conditions:
   - Is issue closed or PR merged?
   - Are docs updated? (warn if not)
4. Upload specs to cloud via fractary-file plugin
5. Update archive index
6. Comment on GitHub issue with archive URLs
7. Comment on PR with archive URLs (if exists)
8. Remove specs from local
9. Commit index update
10. Return archive confirmation

## Read Archived Spec
1. Receive issue number
2. Look up in archive index
3. Read from cloud via fractary-file plugin (no download)
4. Return spec content
</WORKFLOW>

<SKILLS>
- spec-generator: Create specs from issues
- spec-validator: Validate implementation completeness
- spec-archiver: Archive completed work
- spec-linker: Link specs to issues/PRs
</SKILLS>

<INTEGRATION>
- **fractary-work**: Fetch issue details, comment on issues
- **fractary-file**: Upload to cloud, read archived specs
- **faber**: FABER Release phase triggers archival
</INTEGRATION>
```

## Integration with Work Plugin

### Fetch Issue Data
```bash
# Use fractary-work to get issue details
issue_data=$(gh issue view $ISSUE_NUMBER --json title,body,labels,milestone)
```

### Comment on Issue
```bash
# Use fractary-work to comment
gh issue comment $ISSUE_NUMBER --body "Specification created: /specs/spec-123-feature.md"
```

### Archive Comment
```bash
# Comment after archival
gh issue comment $ISSUE_NUMBER --body "
Work completed and archived!

**Specifications**:
- [spec-123-phase1.md](https://storage.example.com/archive/specs/2025/123-phase1.md)
- [spec-123-phase2.md](https://storage.example.com/archive/specs/2025/123-phase2.md)

Archived: 2025-01-15
"
```

## Success Criteria

- [ ] Plugin structure created
- [ ] spec-manager agent implemented
- [ ] Issue-centric (no work_id)
- [ ] Multi-spec support per issue
- [ ] Lifecycle-based archival
- [ ] Archive index maintained
- [ ] GitHub integration (comments on issues/PRs)
- [ ] Cloud storage via fractary-file
- [ ] Read operation for archived specs

## Timeline

**Estimated**: 1 week for core architecture

## Next Steps

- **SPEC-0029-09**: Detailed spec lifecycle management
- **SPEC-0029-10**: Archive workflow implementation
- **SPEC-0029-11**: FABER integration
