---
spec_id: SPEC-00084-auto-install-fractary-plugins-on-startup
issue_number: 84
issue_url: https://github.com/fractary/claude-plugins/issues/84
title: Auto Install Fractary Plugins on Startup
type: infrastructure
status: draft
created: 2025-11-12
author: Claude (spec-generator)
validated: false
---

# Infrastructure Specification: Auto Install Fractary Plugins on Startup

**Issue**: [#84](https://github.com/fractary/claude-plugins/issues/84)
**Type**: Infrastructure
**Status**: Draft
**Created**: 2025-11-12

## Summary

Implement an automated plugin installation mechanism that ensures the fractary/claude-plugins marketplace is available in every Claude Code session, regardless of whether the session starts via GitHub workers or the Claude Code virtual environment creation process.

## Objectives

- Ensure fractary plugins are automatically installed when Claude Code sessions start
- Support both GitHub worker environments and Claude Code virtual sessions
- Eliminate manual plugin installation steps for developers
- Make plugin availability seamless and transparent to users

## Current State

When Claude Code creates a new session:
- A brand-new virtual environment is created using GitHub workers
- The repository is cloned fresh
- The `.claude/settings.json` enables the plugins
- However, the plugin marketplace itself is not installed
- Any work depending on fractary plugins fails because they cannot be found
- Users must manually install the marketplace each session

## Target State

When Claude Code creates a new session:
- The environment automatically detects if the fractary plugin marketplace is installed
- If not installed, the marketplace is automatically installed before the session launches
- All enabled plugins in `.claude/settings.json` are immediately available
- Developers can immediately use FABER workflows and primitive managers (work, repo, file, codex)
- The installation process is transparent and requires no user intervention

## Architecture

### Components

- **Startup Hook/Script**: Script executed during environment initialization
  - Type: Shell script or Claude Code lifecycle hook
  - Purpose: Detect and install plugin marketplace before session starts

- **Plugin Detection Logic**: Checks if marketplace is already installed
  - Type: Conditional logic
  - Purpose: Avoid redundant installations and improve startup time

- **Installation Handler**: Executes the marketplace installation
  - Type: CLI command or API call
  - Purpose: Install fractary/claude-plugins marketplace

- **Configuration Reader**: Reads `.claude/settings.json`
  - Type: JSON parser
  - Purpose: Determine which plugins should be available

### Network Topology

Not applicable - local environment setup.

### Data Flow

1. Claude Code begins environment creation
2. Startup hook is triggered (before session launch)
3. Script checks if fractary marketplace is installed
4. If not installed:
   a. Script installs fractary/claude-plugins marketplace
   b. Waits for installation completion
   c. Verifies installation success
5. Claude Code session launches with plugins available

## Resources Required

### Compute

- Minimal CPU/memory for script execution during startup
- Installation time: estimated 5-15 seconds

### Storage

- Plugin marketplace installation: ~10-50MB (estimate)
- No additional persistent storage required

### Network

- Internet access required for initial marketplace installation
- HTTPS connection to plugin marketplace repository

### Third-Party Services

- Claude Code plugin marketplace registry
- GitHub (for GitHub worker environments)

## Configuration

### Environment Variables

- `CLAUDE_PLUGINS_PATH`: Path to plugins directory (if customizable)
- `FRACTARY_MARKETPLACE_URL`: URL to fractary plugin marketplace (default: fractary/claude-plugins)

### Secrets Management

No secrets required for basic installation. Future considerations:
- Private marketplace access tokens (if needed)
- GitHub PAT (if using private repositories)

### Configuration Files

- `.claude/settings.json`: Existing file that enables plugins
- `.claude/startup.sh`: Proposed startup script (location TBD)
- `.claude/hooks/pre-session.sh`: Alternative hook location

## Deployment Strategy

### Infrastructure as Code

Not applicable - this is a client-side environment setup.

### Deployment Steps

1. Research Claude Code startup hooks/lifecycle events
2. Determine optimal hook point for plugin installation
3. Create startup script with:
   - Marketplace detection logic
   - Installation command
   - Error handling
4. Test in GitHub worker environment
5. Test in Claude Code virtual session
6. Document the approach for other repositories
7. Update project setup documentation

### Rollback Plan

If automatic installation fails:
- Script logs error and continues (fail-safe mode)
- Session starts without plugins
- User sees clear error message with manual installation instructions
- User can manually install marketplace as fallback

## Monitoring and Observability

### Metrics

- Installation success rate: % of sessions where plugins install successfully
- Installation time: Duration of marketplace installation
- Failure rate: % of sessions where installation fails

### Logs

- Startup script output: Installation status, errors, timing
- Claude Code session logs: Plugin availability, loading errors

### Alerts

- **Installation Failure**: If installation fails > 3 times → Notify maintainers
- **Slow Installation**: If installation takes > 30 seconds → Log warning

### Dashboards

Not applicable for this infrastructure change.

## Security Considerations

### Authentication/Authorization

- Use authenticated GitHub access if marketplace is private
- Leverage existing Claude Code authentication mechanisms

### Network Security

- Download plugins only from trusted sources (fractary/claude-plugins)
- Verify checksums/signatures if available

### Data Encryption

- HTTPS for all marketplace downloads
- No sensitive data stored

### Compliance

- Respect Claude Code terms of service
- Follow plugin marketplace guidelines
- Ensure no GPL license conflicts

## Cost Estimation

- Development: ~4-8 hours
- Testing: ~2-4 hours
- Documentation: ~1-2 hours

**Total Estimated**: 7-14 development hours (no ongoing infrastructure costs)

## Dependencies

- Claude Code startup/hook mechanism (research required)
- Access to fractary/claude-plugins marketplace
- GitHub worker environment configuration (if hooks are GitHub-specific)
- `.claude/settings.json` structure and behavior

## Risks and Mitigations

- **Risk**: Startup hook mechanism doesn't exist or isn't documented
  - **Impact**: High - may need alternative approach
  - **Mitigation**: Research Claude Code documentation, contact support, explore alternative integration points

- **Risk**: Installation adds significant startup time
  - **Impact**: Medium - slows developer experience
  - **Mitigation**: Cache installation, check if already installed, optimize installation process

- **Risk**: Installation fails in offline/restricted network environments
  - **Impact**: Medium - developers can't work without plugins
  - **Mitigation**: Graceful degradation, clear error messages, manual installation fallback

- **Risk**: Different installation process for GitHub workers vs. Claude Code sessions
  - **Impact**: Medium - need to maintain two paths
  - **Mitigation**: Abstract installation logic, test both environments thoroughly

- **Risk**: Breaking changes in Claude Code plugin system
  - **Impact**: Low - stable API expected
  - **Mitigation**: Monitor Claude Code release notes, version lock if needed

## Testing Strategy

### Infrastructure Tests

- Test startup script runs successfully
- Test marketplace detection logic (already installed vs. not installed)
- Test installation command execution
- Test error handling (network failure, permission issues)

### Integration Tests

- Test full session startup with automatic installation
- Test plugin availability after installation
- Test both GitHub worker and Claude Code virtual environments
- Test with slow network conditions
- Test with no network (offline mode)

### Disaster Recovery Tests

- Test graceful failure when installation impossible
- Test manual installation fallback
- Test session continues without plugins if installation fails

## Documentation Requirements

- **Setup Guide**: How the automatic installation works
- **Troubleshooting**: What to do if installation fails
- **Developer Guide**: How to replicate for other plugin marketplaces
- **Architecture Doc**: Technical details of the implementation
- **README Update**: Note that plugins install automatically

## Acceptance Criteria

- [ ] Startup hook/script created and tested
- [ ] Marketplace detection logic works (skips if already installed)
- [ ] Installation command executes successfully
- [ ] Plugins are available immediately after session starts
- [ ] Works in GitHub worker environments
- [ ] Works in Claude Code virtual sessions
- [ ] Error handling provides clear messages
- [ ] Installation adds < 30 seconds to startup time
- [ ] Documentation updated
- [ ] Solution tested by at least 2 developers
- [ ] Rollback/manual installation path documented

## Implementation Notes

**Research Required**:
- Claude Code startup hooks documentation
- Plugin marketplace installation CLI commands
- Environment variables available during startup
- Differences between GitHub worker and Claude Code virtual environments

**Potential Approaches**:
1. `.claude/startup.sh` script executed before session
2. Pre-session hook in Claude Code lifecycle
3. GitHub Actions workflow for worker environments
4. Dockerfile/devcontainer configuration
5. Claude Code plugin that installs other plugins (meta-plugin)

**Success Criteria**:
- Zero manual intervention required
- Transparent to developers
- Fast installation (< 30 seconds)
- Reliable across environment types
