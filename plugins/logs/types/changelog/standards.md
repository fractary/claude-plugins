# Changelog Log Standards

## Purpose

Changelog logs track software releases following the [Keep a Changelog](https://keepachangelog.com/) format. They document version numbers, features, bug fixes, breaking changes, and other modifications in a structured, human-readable format.

**Use for**:
- Software version releases
- Public-facing release notes
- Version history tracking
- Breaking change documentation
- Migration planning

**Do NOT use for**:
- Workflow execution logs (use `workflow` type)
- Build logs (use `build` type)
- Deployment logs (use `deployment` type)

---

## Required Sections

Every changelog log MUST include:

1. **Frontmatter** - Structured metadata
   - `log_type: changelog`
   - `changelog_id` - Unique identifier
   - `version` - Semantic version (MAJOR.MINOR.PATCH)
   - `release_date` - ISO 8601 timestamp
   - `status` - One of: draft, planned, released, deprecated, archived

2. **Version Header** - Clear version identification
   - Version number with semantic versioning
   - Release date
   - Status

3. **Changes Section** - At least one category of changes
   - Added, Changed, Deprecated, Removed, Fixed, or Security

4. **Breaking Changes** (if applicable)
   - Clear description of breaking changes
   - Migration notes for users

---

## Capture Rules

### ✅ ALWAYS Capture

- **Semantic version number** - Follow semver (MAJOR.MINOR.PATCH)
- **All user-facing changes** - Features, fixes, deprecations
- **Breaking changes** with migration notes
- **Security fixes** in dedicated section
- **Work item references** - Link to issues/PRs
- **Release date** - ISO 8601 format

### ❌ NEVER Capture

- Internal refactoring (unless it impacts users)
- Code comments or documentation typos
- CI/CD configuration changes
- Development tooling updates
- Secrets or credentials
- Personally identifiable information (PII)

### 🔍 Categorization Rules

Use Keep a Changelog categories:

- **Added** - New features
- **Changed** - Changes to existing functionality
- **Deprecated** - Soon-to-be removed features
- **Removed** - Removed features
- **Fixed** - Bug fixes
- **Security** - Security fixes and vulnerability patches

---

## Redaction Rules

Before creating changelog logs, redact:

1. **Credentials** - API keys, tokens, passwords
2. **Internal URLs** - Replace with public-facing URLs
3. **Customer data** - Any PII or customer-specific information
4. **Proprietary information** - Trade secrets, internal metrics

**Example**:
```
❌ "Fixed authentication bug affecting customer acme-corp (API key: sk-1234)"
✅ "Fixed authentication bug in OAuth2 flow"
```

---

## Naming Conventions

Changelog log files MUST follow this pattern:

```
CHANGELOG-v{version}.md
```

**Examples**:
- `CHANGELOG-v1.0.0.md`
- `CHANGELOG-v2.3.1.md`
- `CHANGELOG-v1.0.0-beta.1.md`

**changelog_id pattern**:
```
changelog-v{version}-{timestamp}
```

**Example**: `changelog-v1.2.0-20250117`

---

## Status Values

Changelog logs progress through these states:

- **draft** - Work in progress, not yet finalized
- **planned** - Scheduled for future release
- **released** - Published and available
- **deprecated** - Superseded by newer version
- **archived** - Historical record, no longer relevant

---

## Semantic Versioning Guide

Follow [semver.org](https://semver.org/) conventions:

- **MAJOR** (1.0.0) - Incompatible API changes (breaking changes)
- **MINOR** (0.1.0) - New functionality, backwards-compatible
- **PATCH** (0.0.1) - Backwards-compatible bug fixes

**Pre-release**: `1.0.0-alpha.1`, `1.0.0-beta.2`, `1.0.0-rc.1`
**Build metadata**: `1.0.0+20240101`

---

## Breaking Changes Protocol

When documenting breaking changes:

1. **List in dedicated section** - Before other changes
2. **Provide migration notes** - How to upgrade
3. **Reference work items** - Link to detailed documentation
4. **Increment MAJOR version** - Following semver

**Example**:
```markdown
## ⚠️ Breaking Changes

### Removed Python 2 support

Python 2 reached end-of-life. This release requires Python 3.8+.

**Migration Notes**: Update your environment to Python 3.8 or later.
See [migration guide](https://example.com/py3-migration) for details.
```

---

## Best Practices

1. **Write for users** - Use clear, non-technical language
2. **Group related changes** - Organize by feature/component
3. **Link to documentation** - Reference detailed guides
4. **Highlight breaking changes** - Make them obvious
5. **Credit contributors** - Acknowledge community contributions
6. **Keep it concise** - Save details for linked documentation
7. **Update regularly** - Don't wait until release day
8. **Compare versions** - Include compare URL for diffs

---

## Example Entry

```markdown
---
log_type: changelog
title: "Version 2.1.0 Release"
changelog_id: changelog-v2.1.0-20250117
version: 2.1.0
release_date: 2025-01-17T10:00:00Z
status: released
compare_url: https://github.com/org/repo/compare/v2.0.0...v2.1.0
---

# Version 2.1.0 Release

**Version**: `2.1.0`
**Release Date**: 2025-01-17
**Status**: released

## ✨ Added

- New plugin system for extensibility (#142)
- Support for custom log types (#156)
- Auto-classification of workflow logs (#163)

## 🐛 Fixed

- Fixed memory leak in log archiver (#145)
- Resolved timezone handling in timestamps (#151)

## 📋 Related Work Items

- **pr** [#142](https://github.com/org/repo/pull/142): Add plugin system
- **issue** [#145](https://github.com/org/repo/issues/145): Memory leak in archiver

## 👥 Contributors

- @alice
- @bob
- @charlie
```
