---
spec_id: WORK-00192-documentation-maintenance-automation
work_id: 192
issue_url: https://github.com/fractary/claude-plugins/issues/192
title: Documentation Maintenance Automation - FABER Integration
type: feature
status: implemented
created: 2025-12-02
author: Claude
validated: true
source: conversation+issue
---

# Feature Specification: Documentation Maintenance Automation

**Issue**: [#192](https://github.com/fractary/claude-plugins/issues/192)
**Type**: Feature
**Status**: Implemented
**Created**: 2025-12-02

## Summary

This specification documents the analysis and implementation of comprehensive documentation maintenance automation for the FABER workflow. The implementation addresses gaps in session logging, high-level documentation synchronization, and integration between fractary-logs, fractary-docs, and fractary-faber plugins.

The user identified that documentation maintenance "fell through the cracks" - specifically:
1. Session/conversation logging was available but disabled by default
2. High-level docs (CLAUDE.md, README.md) had no automatic update mechanism
3. FABER's Release phase had a generic doc update step, not a structured skill-based approach

## Problem Analysis

### Current State Assessment

#### Session Logging (fractary-logs)
| Feature | Status | Default |
|---------|--------|---------|
| Session capture capability | Available | Disabled (`auto_capture: false`) |
| AI-generated summaries | Available | Disabled (`summarization.enabled: false`) |
| FABER integration | Configured | Disabled in config |
| Auto-backup to cloud | Working | Enabled (7-day threshold) |

**Gap**: Session capture required manual start with `/fractary-logs:capture`. Summaries disabled to avoid API costs.

#### Documentation Sync (fractary-docs)
| Feature | Status | Default |
|---------|--------|---------|
| Doc write/update | Full | - |
| Doc validation | Full | - |
| CLAUDE.md updates | Partial | Via `_untyped` type only |
| Change detection | Missing | No automated trigger |

**Gap**: No specialized handling for CLAUDE.md/README.md. No detection of stale documentation.

#### FABER Integration
| Feature | Status | Default |
|---------|--------|---------|
| Release phase doc step | Exists | Prompt-based (not skill-based) |
| docs-manager invocation | Optional | Must configure manually |
| CLAUDE.md handling | Missing | Not referenced |

**Gap**: Release phase used generic prompt, not structured skill. No CLAUDE.md-specific logic.

### Root Cause

Documentation maintenance gaps occurred because:
1. **Opt-in Architecture**: Most doc features disabled by default to avoid API costs
2. **Generic vs Specific**: CLAUDE.md/README.md treated as generic `_untyped` docs
3. **No Change Detection**: No automated detection of stale documentation
4. **Decoupled Plugins**: No tight integration between logs, docs, and faber by default

## Implementation Plan

### Phase 1: Enable Session Logging in FABER

**Goal**: Automatically capture and summarize all FABER workflow sessions

**Files Modified**:
- `plugins/faber/config/workflows/default.json` - Add integrations and logging sections
- `plugins/logs/config/config.example.json` - Enable auto_capture and summarization

**Changes**:
```json
// Added to default.json
"integrations": {
  "work_plugin": "fractary-work",
  "repo_plugin": "fractary-repo",
  "spec_plugin": "fractary-spec",
  "logs_plugin": "fractary-logs",
  "docs_plugin": "fractary-docs"
},
"logging": {
  "use_logs_plugin": true,
  "auto_capture": true,
  "auto_summarize_on_complete": true,
  "log_type": "workflow"
}
```

### Phase 2: Add Structured Doc Update Step to Release Phase

**Goal**: Ensure CLAUDE.md, README.md, etc. are reviewed/updated before PR creation

**Files Modified**:
- `plugins/faber/skills/release/workflow/basic.md` - Add Step 3: "Update High-Level Project Documentation"
- `plugins/faber/config/workflows/default.json` - Add update-project-docs step

**New Release Phase Steps**:
1. Post Release Start Notification
2. Build PR Description
3. **Update High-Level Project Documentation** (NEW)
4. Create Pull Request
5. Check Auto-Merge
6. Update Additional Documentation (Optional)
7. Generate Deployment Doc (Optional)
8. Archive Workflow Artifacts
9. Delete Branch
10. Close/Update Work Item
11. Update Session
12. Post Release Complete
13. Return Results

**Configuration**:
```json
{
  "name": "update-project-docs",
  "description": "Update high-level project documentation",
  "skill": "fractary-docs:docs-manager",
  "config": {
    "targets": ["CLAUDE.md", "README.md", "docs/README.md", "CONTRIBUTING.md"],
    "mode": "confirm",
    "check_consistency": true
  }
}
```

### Phase 3: Create doc-consistency-checker Skill

**Goal**: Detect when high-level docs are stale based on code/config changes

**New Files Created**:
- `plugins/docs/skills/doc-consistency-checker/SKILL.md`
- `plugins/docs/skills/doc-consistency-checker/scripts/check-consistency.sh`
- `plugins/docs/skills/doc-consistency-checker/scripts/generate-suggestions.sh`
- `plugins/docs/skills/doc-consistency-checker/scripts/apply-updates.sh`
- `plugins/docs/commands/check-consistency.md`

**Operations**:
- `check`: Analyze git diff and detect stale documentation
- `suggest`: Generate update suggestions for stale docs
- `apply`: Apply approved updates to documents
- `report`: Generate consistency report without suggestions

**Change Detection Categories**:
- **API Changes** (High Priority): New endpoints, schema changes, auth changes
- **Feature Changes** (High Priority): New commands, skills, functionality
- **Architecture Changes** (High Priority): New components, dependencies
- **Configuration Changes** (Medium Priority): Environment variables, config formats

### Phase 4: Add Post-Release Documentation Hook

**Goal**: Validate documentation completeness after release

**Files Modified**:
- `plugins/faber/config/workflows/default.json` - Add post_release hook

**Configuration**:
```json
"post_release": [
  {
    "name": "validate-project-docs",
    "description": "Validate high-level documentation is up to date",
    "skill": "fractary-docs:doc-validator",
    "targets": ["CLAUDE.md", "README.md", "docs/README.md", "CONTRIBUTING.md"],
    "on_failure": "warn",
    "config": {
      "checks": ["frontmatter", "structure"],
      "strict": false
    }
  }
]
```

### Phase 5: Session Summary to Docs Integration

**Goal**: Automatically update `/docs/conversations/` from session summaries

**Files Modified**:
- `plugins/logs/config/config.example.json` - Add docs_integration section
- `plugins/logs/skills/log-archiver/SKILL.md` - Add Step 10 for copying summaries

**New Files Created**:
- `plugins/logs/skills/log-archiver/scripts/copy-to-docs.sh`

**Configuration**:
```json
"docs_integration": {
  "enabled": true,
  "copy_summary_to_docs": true,
  "docs_path": "docs/conversations",
  "update_index": true,
  "index_file": "docs/conversations/README.md",
  "summary_filename_pattern": "{date}-{issue_number}-{slug}.md",
  "index_format": "table",
  "max_index_entries": 50
}
```

## Files Created/Modified

### New Files (7)
| Path | Description |
|------|-------------|
| `plugins/docs/skills/doc-consistency-checker/SKILL.md` | Skill definition for documentation staleness detection |
| `plugins/docs/skills/doc-consistency-checker/scripts/check-consistency.sh` | Analyzes git diff for doc-relevant changes |
| `plugins/docs/skills/doc-consistency-checker/scripts/generate-suggestions.sh` | Generates update suggestions |
| `plugins/docs/skills/doc-consistency-checker/scripts/apply-updates.sh` | Applies approved updates |
| `plugins/docs/commands/check-consistency.md` | New `/docs:check-consistency` command |
| `plugins/logs/skills/log-archiver/scripts/copy-to-docs.sh` | Copies session summaries to docs/conversations/ |

### Modified Files (4)
| Path | Changes |
|------|---------|
| `plugins/faber/config/workflows/default.json` | Added integrations, logging, update-project-docs step, post_release hook |
| `plugins/faber/skills/release/workflow/basic.md` | Added Step 3 for high-level doc updates, renumbered subsequent steps |
| `plugins/logs/config/config.example.json` | Enabled auto_capture, summarization, added docs_integration |
| `plugins/logs/skills/log-archiver/SKILL.md` | Added Step 10 for copying summaries to docs |

## Testing Strategy

### Unit Tests
- Validate check-consistency.sh correctly categorizes git changes
- Validate generate-suggestions.sh creates appropriate suggestions
- Validate copy-to-docs.sh correctly copies and updates index

### Integration Tests
- End-to-end FABER workflow with doc updates enabled
- Session capture → archive → docs copy flow
- Consistency check before PR creation

### Manual Testing
- Run FABER workflow and verify doc update prompt appears
- Verify session summaries appear in docs/conversations/
- Verify post-release hook validates documentation

## Dependencies

- fractary-faber plugin (core workflow)
- fractary-docs plugin (doc operations)
- fractary-logs plugin (session logging)
- fractary-repo plugin (git operations)
- jq (JSON processing in scripts)
- git (change detection)

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| API costs from auto-summarization | Medium | Low | User can disable via config; ~$0.01-0.05/session |
| False positives in change detection | Medium | Low | Use "confirm" mode by default, user reviews |
| Performance impact on large diffs | Low | Medium | Limit analysis to relevant file patterns |
| Index corruption in docs/conversations | Low | Medium | Backup before modification |

## Success Metrics

| Metric | Target |
|--------|--------|
| Session capture rate during FABER | 100% when enabled |
| Doc update prompts in Release phase | 100% when targets exist |
| Consistency check accuracy | >80% relevant suggestions |
| Summary copy success rate | 100% |

## Implementation Notes

### User Decisions Captured
1. **AI Summaries**: Enabled by default for all FABER sessions
2. **Doc Update Behavior**: Auto-update with confirmation (show diff, user confirms)
3. **Doc Scope**: All high-level docs (CLAUDE.md, README.md, docs/README.md, CONTRIBUTING.md)
4. **Priority**: Full implementation - all 5 phases

### Key Design Decisions
- **Confirm Mode Default**: Updates are suggested but require user confirmation to avoid unwanted changes
- **Graceful Degradation**: If docs don't exist, steps are skipped without error
- **Plugin Independence**: Each plugin can function independently; integration is optional
- **Config-Driven**: All behavior controlled by configuration, not hardcoded

### Backward Compatibility
- Existing workflows continue to work unchanged
- New features are opt-in via configuration
- No breaking changes to existing commands or skills
