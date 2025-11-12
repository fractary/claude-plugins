---
spec_id: spec-99-new-status-plugin
issue_number: 99
issue_url: https://github.com/fractary/claude-plugins/issues/99
title: New Status Plugin
type: feature
status: draft
created: 2025-11-12
author: jmcwilliam
validated: false
---

# Feature Specification: New Status Plugin

**Issue**: [#99](https://github.com/fractary/claude-plugins/issues/99)
**Type**: Feature
**Status**: Draft
**Created**: 2025-11-12

## Summary

Create a new status line plugin for Claude Code that provides enhanced git status information in the terminal status bar. The plugin will leverage the git status cache from the fractary-repo plugin and display current issue number and PR number when available. This will replace the user's current custom status line implementation with a more maintainable, shareable solution.

## User Stories

### Status Line Installation
**As a** developer using Claude Code
**I want** to easily install a status line plugin in my project
**So that** I can see git status, issue numbers, and PR numbers without manual configuration

**Acceptance Criteria**:
- [ ] Plugin can be installed via simple command
- [ ] Installation includes both hook configuration and script
- [ ] No manual file editing required
- [ ] Works across different projects

### Git Status Display
**As a** developer working in a repository
**I want** to see current git status in my terminal status line
**So that** I can quickly understand my working tree state without running git commands

**Acceptance Criteria**:
- [ ] Shows current branch name
- [ ] Displays uncommitted changes count
- [ ] Shows staged files count
- [ ] Indicates if branch is ahead/behind remote
- [ ] Uses git status cache for performance

### Work Context Display
**As a** developer working on an issue
**I want** to see the current issue number and PR number in my status line
**So that** I can maintain context about what I'm working on

**Acceptance Criteria**:
- [ ] Displays current issue number from branch metadata
- [ ] Shows PR number if one exists for current branch
- [ ] Updates automatically when switching branches
- [ ] Gracefully handles branches without associated issues/PRs

## Functional Requirements

- **FR1**: Plugin installation command that sets up status line in project
- **FR2**: Hook integration to trigger status line updates on appropriate events
- **FR3**: Git status cache integration from fractary-repo plugin
- **FR4**: Issue number extraction from branch naming conventions
- **FR5**: PR number detection for current branch
- **FR6**: Status line formatting and display
- **FR7**: Performance optimization to prevent slowdowns in terminal

## Non-Functional Requirements

- **NFR1**: Status line updates must complete in <100ms (Performance)
- **NFR2**: Must work with existing fractary-repo plugin without conflicts (Compatibility)
- **NFR3**: Should follow Fractary plugin architecture patterns (Maintainability)
- **NFR4**: Must handle missing or incomplete data gracefully (Reliability)
- **NFR5**: Configuration should be project-specific (Portability)

## Technical Design

### Architecture Changes

The new plugin will follow the standard Fractary plugin architecture:

```
plugins/status/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata
├── commands/
│   └── install.md               # /status:install command
├── skills/
│   └── status-line-manager/
│       ├── SKILL.md            # Status line setup skill
│       └── scripts/
│           ├── install.sh       # Installation script
│           └── status-line.sh   # Status line generation script
├── hooks/
│   └── status-update.json       # Hook configuration template
└── README.md
```

### Data Model

**Git Status Cache** (from fractary-repo):
```json
{
  "branch": "feat/99-new-status-plugin",
  "ahead": 2,
  "behind": 0,
  "staged": 3,
  "unstaged": 1,
  "untracked": 2,
  "remote": "origin/feat/99-new-status-plugin"
}
```

**Branch Metadata**:
```json
{
  "branch": "feat/99-new-status-plugin",
  "issue_number": 99,
  "pr_number": 123,
  "work_type": "feature"
}
```

### API Design

N/A - This is a CLI plugin, not an API

### UI/UX Changes

**Status Line Format**:
```
[branch] [±files] [#issue] [PR#pr] [↑ahead ↓behind]
```

**Examples**:
```
feat/99-new-status-plugin ±4 #99 ↑2
main ±0
fix/bug-authentication ±2 #87 PR#91 ↑1 ↓3
```

**Color Scheme** (if supported):
- Branch name: Cyan
- Modified files: Yellow (if any), Green (if clean)
- Issue number: Magenta
- PR number: Blue
- Ahead/behind: Green/Red

## Implementation Plan

### Phase 1: Plugin Structure
Setup basic plugin structure following Fractary standards

**Tasks**:
- [ ] Create plugin directory structure
- [ ] Add plugin.json with metadata and dependencies
- [ ] Create README with plugin documentation
- [ ] Add installation command definition

### Phase 2: Status Line Script
Implement core status line generation logic

**Tasks**:
- [ ] Create status-line.sh script
- [ ] Integrate with fractary-repo git status cache
- [ ] Implement issue number extraction from branch names
- [ ] Implement PR number detection via gh CLI
- [ ] Add status line formatting logic
- [ ] Add error handling for missing data

### Phase 3: Installation System
Build installation mechanism

**Tasks**:
- [ ] Create install.sh script
- [ ] Implement hook configuration
- [ ] Add status line script to project
- [ ] Create .claude/settings.json updates
- [ ] Add validation checks
- [ ] Test installation across different environments

### Phase 4: Testing & Documentation
Comprehensive testing and documentation

**Tasks**:
- [ ] Test with various branch naming patterns
- [ ] Test with/without PRs
- [ ] Test with different git states
- [ ] Performance testing
- [ ] Write usage documentation
- [ ] Create troubleshooting guide

## Files to Create/Modify

### New Files
- `plugins/status/.claude-plugin/plugin.json`: Plugin metadata
- `plugins/status/README.md`: Plugin documentation
- `plugins/status/commands/install.md`: Installation command
- `plugins/status/skills/status-line-manager/SKILL.md`: Installation skill
- `plugins/status/skills/status-line-manager/scripts/install.sh`: Installation script
- `plugins/status/skills/status-line-manager/scripts/status-line.sh`: Status line generator
- `plugins/status/hooks/status-update.json`: Hook configuration template
- `specs/spec-99-new-status-plugin.md`: This specification

### Modified Files
- `.claude/settings.json`: Updated with status line hook (per-project)
- `.fractary/plugins/status/config.json`: Plugin configuration (per-project)

## Testing Strategy

### Unit Tests
- Test status line formatting with various git states
- Test issue number extraction from different branch patterns
- Test PR number detection
- Test fallback behavior for missing data

### Integration Tests
- Test integration with fractary-repo git status cache
- Test hook triggering on git operations
- Test installation across different project types
- Test compatibility with existing hooks

### E2E Tests
- Install plugin in fresh project
- Make git changes and verify status updates
- Create branch with issue number, verify display
- Create PR, verify PR number appears
- Switch branches, verify updates

### Performance Tests
- Measure status line generation time (<100ms requirement)
- Test with large repositories
- Test with slow network connections (PR detection)
- Profile cache hit/miss scenarios

## Dependencies

- fractary-repo plugin (for git status cache)
- gh CLI (for PR number detection)
- git (for branch information)
- bash (for script execution)

## Risks and Mitigations

- **Risk**: Performance degradation in large repositories
  - **Likelihood**: Medium
  - **Impact**: High
  - **Mitigation**: Leverage git status cache, implement timeouts, cache PR numbers

- **Risk**: Breaking changes in fractary-repo plugin
  - **Likelihood**: Low
  - **Impact**: High
  - **Mitigation**: Define stable cache format, version dependencies properly

- **Risk**: Different terminal environments not supporting status lines
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Detect terminal capabilities, provide fallback display options

- **Risk**: GitHub API rate limiting for PR detection
  - **Likelihood**: Medium
  - **Impact**: Low
  - **Mitigation**: Cache PR numbers, use local git data when possible, graceful degradation

## Documentation Updates

- `plugins/status/README.md`: Complete plugin documentation
- `CLAUDE.md`: Add status plugin to plugin ecosystem section
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`: Reference as example if novel patterns emerge

## Rollout Plan

1. **Development**: Implement in feature branch
2. **Internal Testing**: Test on maintainer machines
3. **Beta Release**: Make available for early adopters
4. **Feedback**: Gather user feedback and iterate
5. **Production Release**: Merge to main, announce availability
6. **Migration Support**: Provide migration guide for users with custom status lines

## Success Metrics

- Installation time: < 30 seconds
- Status line update latency: < 100ms
- User adoption: 10+ projects using within 1 month
- Zero reported performance issues
- Positive user feedback on usability

## Implementation Notes

- Study existing user custom status line for feature parity
- Ensure compatibility with WSL environments
- Consider cross-platform support (Linux, macOS)
- Follow existing Fractary plugin patterns strictly
- Reuse git status cache infrastructure from repo plugin
- Consider future extensibility (custom formatters, additional info)
