# Changelog Standards

Standards for maintaining changelogs across the Fractary plugin ecosystem.

**Version**: 1.0 (2025-01-15)

## Overview

This document defines standards for:
- Changelog format and structure
- When and how to update changelogs
- Version numbering conventions
- Breaking change documentation
- Automation strategies
- Integration with FABER workflows

## Philosophy

**Changelogs are for humans, not machines.**

A good changelog:
- **Summarizes** what changed and why
- **Highlights** breaking changes prominently
- **Guides** users through migrations
- **Groups** changes by impact category
- **Explains** the benefits of changes

**Changelogs ≠ Commit Messages:**
- Commit messages = technical, granular, for developers
- Changelog entries = user-focused, consolidated, for all audiences

## Format Standard

### Keep a Changelog

All changelogs follow **[Keep a Changelog](https://keepachangelog.com/en/1.0.0/)** v1.0.0 format with **[Semantic Versioning](https://semver.org/spec/v2.0.0.html)**.

**Template**: Use `plugins/docs/skills/doc-generator/templates/changelog.md.template`

**Structure:**
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New features

### Changed
- Changes to existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security fixes

## [1.2.0] - 2025-01-15

### Added
- Feature X for better Y
- Support for Z platform

### Changed
- Improved performance of A by 50%

### Fixed
- Bug causing B to fail

## [1.1.0] - 2025-01-01

...

[Unreleased]: https://github.com/org/repo/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/org/repo/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/org/repo/releases/tag/v1.1.0
```

### Categories

Use these categories **in this order**:

1. **Added** - New features, capabilities, or functionality
2. **Changed** - Changes to existing functionality (non-breaking)
3. **Deprecated** - Features marked for future removal (with timeline)
4. **Removed** - Features removed in this version
5. **Fixed** - Bug fixes
6. **Security** - Security fixes or improvements

**Category Guidelines:**

- **Added**: User-visible new features only (not internal refactoring)
  ```markdown
  ### Added
  - Support for AWS Terraform backend
  - `/faber:status` command for workflow monitoring
  - Configuration validation on startup
  ```

- **Changed**: Improvements or modifications to existing features
  ```markdown
  ### Changed
  - Improved error messages for configuration validation
  - Updated default retention policy to 30 days
  - Optimized log search performance by 60%
  ```

- **Deprecated**: Features to be removed (with migration path)
  ```markdown
  ### Deprecated
  - `--legacy-mode` flag (use `--mode=compat` instead, removal in v2.0)
  - Old configuration format (migrate using `/plugin:migrate`, removal in v3.0)
  ```

- **Removed**: Features removed (with migration guide)
  ```markdown
  ### Removed
  - Legacy API endpoints (use v2 API, see migration guide)
  - Support for Node.js 14 (upgrade to Node.js 16+)
  ```

- **Fixed**: Bug fixes only
  ```markdown
  ### Fixed
  - Fixed crash when processing empty log files
  - Corrected timestamp parsing for ISO 8601 formats
  - Resolved race condition in concurrent uploads
  ```

- **Security**: Security-related changes
  ```markdown
  ### Security
  - Updated dependencies with security vulnerabilities
  - Added input validation to prevent command injection
  - Improved secret redaction in log output
  ```

**Empty Categories:**
- Omit categories with no changes (don't show empty sections)
- Exception: Keep all categories in templates for guidance

## Semantic Versioning

### Version Format

Use **Semantic Versioning** (SemVer): `MAJOR.MINOR.PATCH`

- **MAJOR** (x.0.0): Breaking changes, incompatible API changes
- **MINOR** (0.x.0): New features, backward-compatible additions
- **PATCH** (0.0.x): Bug fixes, backward-compatible fixes

### Version Increment Rules

**Increment MAJOR when:**
- Breaking API changes
- Removing features (unless deprecated for 2+ versions)
- Incompatible configuration changes
- Changes requiring user action

**Increment MINOR when:**
- Adding new features (backward-compatible)
- Deprecating features (with timeline)
- Adding optional configuration
- Performance improvements

**Increment PATCH when:**
- Bug fixes
- Documentation updates
- Internal refactoring (no user impact)
- Dependency updates (no breaking changes)

### Pre-Release Versions

Use pre-release identifiers for development versions:

- **Alpha**: `1.0.0-alpha.1` - Early development, unstable
- **Beta**: `1.0.0-beta.1` - Feature complete, testing phase
- **RC**: `1.0.0-rc.1` - Release candidate, final testing

**Rules:**
- Always test pre-releases before stable release
- Document known issues in pre-release notes
- Don't use pre-releases in production

## Breaking Changes

### Documentation

Breaking changes **MUST** be documented prominently:

```markdown
## [2.0.0] - 2025-02-01

### ⚠️ BREAKING CHANGES

#### Configuration Format Updated

**What changed**: Configuration now uses TOML instead of JSON.

**Why**: TOML provides better readability and supports comments.

**Impact**: Existing JSON configurations will not work.

**Migration**:
1. Backup existing config: `cp config.json config.json.backup`
2. Convert to TOML: `/plugin:migrate-config`
3. Verify: `/plugin:validate-config`
4. Remove old config: `rm config.json.backup`

**Rollback**: Keep JSON config backup, downgrade to v1.x if needed.

---

### Removed
- JSON configuration support (use TOML, see breaking changes)

### Added
- TOML configuration support with inline comments
```

### Breaking Change Requirements

Every breaking change **MUST** include:

1. **Title**: Clear description of what changed
2. **What changed**: Technical description
3. **Why**: Rationale for the change
4. **Impact**: Who is affected and how
5. **Migration**: Step-by-step migration guide
6. **Rollback**: How to revert if needed

### Deprecation Process

Before removing features:

1. **Deprecate** in MINOR release (e.g., v1.5.0)
   - Mark as deprecated in changelog
   - Add deprecation warnings
   - Document migration path
   - Set removal timeline (minimum 2 versions or 6 months)

2. **Warn** for 2+ MINOR releases (e.g., v1.5.0, v1.6.0)
   - Keep feature functional
   - Show deprecation warnings
   - Maintain documentation

3. **Remove** in MAJOR release (e.g., v2.0.0)
   - Remove feature
   - Document as breaking change
   - Provide migration guide

**Example:**
```markdown
## [1.5.0] - 2025-01-15
### Deprecated
- `--old-flag` (use `--new-flag` instead, removal in v2.0.0)

## [1.6.0] - 2025-02-15
### Deprecated
- `--old-flag` still works but will be removed in v2.0.0

## [2.0.0] - 2025-06-15
### ⚠️ BREAKING CHANGES
#### Removed --old-flag
Use `--new-flag` instead. See migration guide.

### Removed
- `--old-flag` (use `--new-flag`, deprecated since v1.5.0)
```

## Update Timing

### When to Update Changelog

**On Every Release:**
- ✅ Move `[Unreleased]` section to new version
- ✅ Add version number and date
- ✅ Create new empty `[Unreleased]` section
- ✅ Update version comparison links
- ✅ Tag release in Git

**During Development (Optional):**
- Update `[Unreleased]` section as changes are made
- Helps track upcoming release content
- Makes release process faster

**NOT on every commit:**
- Don't update changelog for every commit
- Consolidate related changes into single entries
- Focus on user impact, not implementation details

### Release Workflow

```bash
# 1. Review unreleased changes
cat CHANGELOG.md

# 2. Determine version number (MAJOR.MINOR.PATCH)
# Based on types of changes in [Unreleased]

# 3. Update CHANGELOG.md
# - Move [Unreleased] to [X.Y.Z] - YYYY-MM-DD
# - Add new [Unreleased] section
# - Update comparison links
vim CHANGELOG.md

# 4. Update version in plugin.json (if applicable)
vim .claude-plugin/plugin.json

# 5. Commit changes
git add CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore: release v1.2.0"

# 6. Tag release
git tag -a v1.2.0 -m "Release v1.2.0"

# 7. Push changes and tags
git push origin main --tags
```

## Writing Style

### Entry Format

**Structure**: `- [Action] [What] [Additional context]`

**Good entries:**
```markdown
- Added support for Terraform remote state backends
- Improved log search performance by 60% using optimized indexing
- Fixed crash when processing empty configuration files
- Deprecated `--legacy-mode` flag (use `--mode=compat`, removal in v2.0)
- Removed support for Node.js 14 (upgrade to Node.js 16+)
```

**Bad entries:**
```markdown
- Added feature (too vague)
- Bug fixes (not specific)
- Updated code (not user-focused)
- Refactored (no user impact)
- Minor improvements (meaningless)
```

### Writing Guidelines

**Be specific:**
- ❌ "Improved performance"
- ✅ "Improved log search performance by 60%"

**User-focused:**
- ❌ "Refactored internal API"
- ✅ "Reduced memory usage by 40% through internal optimizations"

**Action-oriented:**
- ❌ "There is now support for X"
- ✅ "Added support for X"

**Provide context:**
- ❌ "Fixed bug"
- ✅ "Fixed crash when processing empty log files"

**Benefits over features:**
- ❌ "Added caching layer"
- ✅ "Improved response time by 50% using intelligent caching"

### Voice and Tense

- **Past tense**: "Added", "Fixed", "Removed"
- **Active voice**: "Added feature X" not "Feature X was added"
- **Direct language**: "Improved performance" not "Performance has been improved"

## Integration with FABER

### Release Phase

During FABER Release phase, update changelog automatically:

**Workflow:**
1. **Build phase**: Implement feature
2. **Evaluate phase**: Test and verify
3. **Release phase**: Update changelog + create PR

**Release skill should:**
- Read commit messages since last release
- Categorize changes (Added, Changed, Fixed, etc.)
- Generate changelog entries
- Update `[Unreleased]` section
- Include in release commit

**Example integration:**
```markdown
## Release Skill Workflow

### Step 3: Update Changelog
1. Read commits since last release: `git log v1.1.0..HEAD`
2. Categorize changes by type (feat→Added, fix→Fixed)
3. Generate changelog entries from commit messages
4. Update CHANGELOG.md [Unreleased] section
5. Review with user before committing
```

### Commit Message Conventions

Use **Conventional Commits** to automate changelog generation:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types → Categories:**
- `feat:` → **Added**
- `fix:` → **Fixed**
- `perf:` → **Changed** (if user-visible)
- `docs:` → Omit from changelog
- `style:` → Omit from changelog
- `refactor:` → Omit from changelog
- `test:` → Omit from changelog
- `chore:` → Omit from changelog

**Breaking changes:**
- `feat!:` or `fix!:` → **⚠️ BREAKING CHANGES**
- Or footer: `BREAKING CHANGE: description`

**Examples:**
```bash
feat(logs): add cloud archival support
# → Added: Cloud archival support for historical logs

fix(config): correct validation for nested objects
# → Fixed: Configuration validation for nested objects

feat(api)!: remove deprecated v1 endpoints
# → ⚠️ BREAKING CHANGES + Removed: Deprecated v1 endpoints
```

## Changelog Location

### File Location

```
plugin/
├── CHANGELOG.md          # Plugin-specific changelog (required)
└── .claude-plugin/
    └── plugin.json       # Plugin metadata with version
```

**Repository-level:**
```
repository/
├── CHANGELOG.md          # Overall repository changelog
└── plugins/
    ├── plugin-a/
    │   └── CHANGELOG.md  # Plugin A changelog
    └── plugin-b/
        └── CHANGELOG.md  # Plugin B changelog
```

### Multi-Plugin Repositories

For repositories with multiple plugins:

1. **Repository-level changelog**: High-level changes across all plugins
2. **Plugin-level changelogs**: Detailed changes per plugin

**Repository CHANGELOG.md:**
```markdown
## [1.5.0] - 2025-01-15

### Fractary-FABER Plugin
- Added v2.0 architecture with single workflow-manager
- Improved context efficiency by 60%

### Fractary-Logs Plugin
- Added audit command for log management
- Added cloud archival support

### Fractary-Docs Plugin
- Added audit command for documentation gaps
```

**Plugin-specific CHANGELOG.md:**
```markdown
# Fractary-Logs Changelog

## [2.1.0] - 2025-01-15

### Added
- Audit command for comprehensive log analysis
- Cloud archival support via fractary-file integration
- Search across local and cloud logs
```

## Automation

### Changelog Generation Tools

**Option 1: Manual (Recommended for quality)**
- Manually update CHANGELOG.md during development
- Review and edit before release
- Ensures high quality, user-focused entries

**Option 2: Semi-Automated**
- Generate from conventional commits
- Review and edit generated entries
- Add breaking change details manually
- Good balance of speed and quality

**Option 3: Fully Automated**
- Auto-generate from commits
- Auto-tag releases
- Fast but lower quality
- Best for internal tools

**Recommended: Semi-Automated**
- Generate draft from commits
- Review and improve entries
- Add context and benefits
- Expand breaking changes

### Tools

**For Node.js projects:**
```bash
# Generate changelog from commits
npx conventional-changelog-cli -p angular -i CHANGELOG.md -s

# With custom configuration
npx conventional-changelog-cli -p angular -i CHANGELOG.md -s -r 0
```

**For Python projects:**
```bash
# Using gitchangelog
pip install gitchangelog
gitchangelog > CHANGELOG.md
```

**Generic (Git-based):**
```bash
# Simple script to extract commits
git log --pretty=format:"- %s" v1.0.0..HEAD
```

### Integration with CI/CD

**GitHub Actions example:**
```yaml
name: Update Changelog

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  changelog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Generate Changelog
        run: npx conventional-changelog-cli -p angular -i CHANGELOG.md -s
      - name: Commit Changelog
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add CHANGELOG.md
          git commit -m "docs: update changelog" || true
          git push
```

## Examples

### Complete Plugin Changelog

```markdown
# Fractary-Logs Plugin Changelog

All notable changes to the Fractary-Logs plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- WIP: Filtering support for log search

## [2.1.0] - 2025-01-15

### Added
- `/fractary-logs:audit` command for comprehensive log analysis
- Cloud archival support via fractary-file integration
- Unified search across local and cloud logs
- Discovery patterns for automatic log detection
- Retention policy enforcement (30 days local, then cloud)

### Changed
- Improved log indexing performance by 50%
- Enhanced error messages for configuration issues
- Updated documentation with audit workflow examples

### Fixed
- Fixed timestamp parsing for non-ISO formats
- Corrected path resolution on Windows
- Resolved race condition in concurrent writes

## [2.0.0] - 2024-12-01

### ⚠️ BREAKING CHANGES

#### Configuration Schema Updated to v2.0

**What changed**: Configuration now uses nested handler structure.

**Why**: Supports multiple storage providers and better organization.

**Impact**: Existing v1.0 configurations will not load.

**Migration**:
1. Backup config: `cp config.json config.json.backup`
2. Run migration: `/fractary-logs:migrate-config`
3. Verify: `/fractary-logs:init --validate`
4. Test: `/fractary-logs:search "test"`

---

### Added
- Handler-based architecture for storage providers
- Support for multiple cloud storage backends
- Hybrid retention strategy (local + cloud)

### Removed
- Direct S3 configuration (use handlers, see breaking changes)

## [1.5.0] - 2024-11-01

### Added
- Session log capture integration
- Build log auto-capture
- Deployment log tracking

### Deprecated
- Direct S3 configuration (use handler config, removal in v2.0.0)

### Fixed
- Memory leak in long-running sessions
- Incorrect log rotation behavior

## [1.0.0] - 2024-10-01

### Added
- Initial release
- Basic log storage and retrieval
- Local log management
- .gitignore integration

[Unreleased]: https://github.com/fractary/claude-plugins/compare/fractary-logs-v2.1.0...HEAD
[2.1.0]: https://github.com/fractary/claude-plugins/compare/fractary-logs-v2.0.0...fractary-logs-v2.1.0
[2.0.0]: https://github.com/fractary/claude-plugins/compare/fractary-logs-v1.5.0...fractary-logs-v2.0.0
[1.5.0]: https://github.com/fractary/claude-plugins/compare/fractary-logs-v1.0.0...fractary-logs-v1.5.0
[1.0.0]: https://github.com/fractary/claude-plugins/releases/tag/fractary-logs-v1.0.0
```

### Release with Breaking Changes

```markdown
## [3.0.0] - 2025-03-01

### ⚠️ BREAKING CHANGES

#### Removed Support for Node.js 14

**What changed**: Minimum Node.js version is now 16.

**Why**: Node.js 14 reached end-of-life, newer features require Node.js 16+.

**Impact**: Plugin will not run on Node.js 14.

**Migration**:
1. Check Node version: `node --version`
2. If < 16, install Node.js 16+: https://nodejs.org
3. Reinstall dependencies: `npm install`
4. Test: `npm test`

**Rollback**: Downgrade to v2.x if Node.js upgrade not possible.

---

#### Configuration Commands Renamed

**What changed**: Commands renamed for consistency.
- `/logs:config` → `/fractary-logs:configure`
- `/logs:setup` → `/fractary-logs:init`

**Why**: Consistent naming across all Fractary plugins.

**Impact**: Old commands will not work.

**Migration**: Update scripts and documentation to use new commands.

---

### Added
- Support for Node.js 18 and 20
- Performance improvements using async/await
- Better error handling and messages

### Removed
- Support for Node.js 14 (see breaking changes)
- Legacy command names (see breaking changes)
- Deprecated `--old-format` flag (removed, use `--format=new`)
```

## Quality Checklist

Before releasing a changelog:

- [ ] All user-facing changes documented
- [ ] Changes grouped by category (Added, Changed, Fixed, etc.)
- [ ] Breaking changes prominently documented
- [ ] Migration guides provided for breaking changes
- [ ] Version number follows Semantic Versioning
- [ ] Date is accurate (YYYY-MM-DD)
- [ ] Comparison links updated
- [ ] Grammar and spelling checked
- [ ] Entries are user-focused (not technical implementation)
- [ ] Benefits explained, not just features listed
- [ ] Reviewed by another person (for major releases)

## Anti-Patterns

### Don't Do This

❌ **Vague entries**
```markdown
- Various improvements
- Bug fixes
- Updated dependencies
```

❌ **Technical jargon**
```markdown
- Refactored AbstractFactoryProvider to use Singleton pattern
- Optimized O(n²) algorithm to O(n log n)
```

❌ **No user benefit**
```markdown
- Updated tests
- Improved code coverage
- Renamed variables
```

❌ **Missing migration guide**
```markdown
### BREAKING CHANGES
- Changed configuration format
```

❌ **Inconsistent formatting**
```markdown
### Added
- feature 1
* Feature 2
+ feature three
```

### Do This Instead

✅ **Specific, user-focused**
```markdown
- Improved log search performance by 60% using optimized indexing
- Fixed crash when processing empty configuration files
- Updated 5 dependencies with security vulnerabilities (CVE-2024-XXXX)
```

✅ **User benefits**
```markdown
- Reduced memory usage by 40% through internal optimizations
- Faster startup time (2s → 0.5s) via lazy initialization
```

✅ **Complete breaking change**
```markdown
### ⚠️ BREAKING CHANGES

#### Configuration Format Changed

**What changed**: Configuration uses TOML instead of JSON.
**Why**: Better readability, supports comments.
**Impact**: Existing JSON configs will not work.
**Migration**: Run `/plugin:migrate-config` to convert.
```

✅ **Consistent formatting**
```markdown
### Added
- Feature 1 with benefit
- Feature 2 with benefit
- Feature 3 with benefit
```

## Further Reading

- [Keep a Changelog](https://keepachangelog.com/) - Changelog format standard
- [Semantic Versioning](https://semver.org/) - Version numbering standard
- [Conventional Commits](https://www.conventionalcommits.org/) - Commit message format
- [DOCUMENTATION-STANDARDS.md](./DOCUMENTATION-STANDARDS.md) - General documentation standards

---

**Standards Version**: 1.0 (2025-01-15)
**Last Updated**: 2025-01-15
**Next Review**: 2025-04-15
