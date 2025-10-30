---
name: fractary-repo:tag
description: Create and push semantic version tags
argument-hint: create <tag_name> [--message <text>] [--commit <sha>] [--sign] [--force] | push <tag_name|all> [--remote <name>] | list [--pattern <pattern>] [--latest <n>]
---

# /repo:tag - Version Tag Management Command

Create and push semantic version tags for releases with optional GPG signing.

## Usage

```bash
# Create a version tag
/repo:tag create <tag_name> [options]

# Push tag to remote
/repo:tag push <tag_name|all> [options]

# List tags
/repo:tag list [options]
```

## Subcommand: create

Create a new semantic version tag.

### Syntax

```bash
/repo:tag create <tag_name> [options]
```

### Required Arguments

- `tag_name`: Semantic version tag (e.g., v1.2.3, v2.0.0-beta.1)

### Optional Flags

- `--message <text>`: Tag annotation message (required for annotated tags)
- `--commit <sha>`: Commit to tag (default: HEAD)
- `--sign`: GPG sign the tag
- `--force`: Overwrite existing tag

### Examples

```bash
# Create release tag
/repo:tag create v1.2.3 --message "Release version 1.2.3"

# Create signed tag
/repo:tag create v2.0.0 --message "Major release v2.0.0" --sign

# Create pre-release tag
/repo:tag create v1.3.0-beta.1 --message "Beta release for testing"

# Tag specific commit
/repo:tag create v1.2.4 --message "Hotfix release" --commit abc123

# Force overwrite existing tag
/repo:tag create v1.0.0 --message "Updated release" --force
```

### Semantic Versioning

Tags must follow semantic versioning format:

**Format**: `vMAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]`

**Examples**:
- `v1.0.0` - Initial release
- `v1.1.0` - New feature added
- `v1.1.1` - Bug fix
- `v2.0.0` - Breaking changes
- `v1.2.0-beta.1` - Beta release
- `v1.3.0-rc.2` - Release candidate
- `v1.0.0+20250129` - With build metadata

**Version Components**:
- **MAJOR**: Incompatible API changes
- **MINOR**: Backward-compatible new features
- **PATCH**: Backward-compatible bug fixes
- **PRERELEASE**: alpha, beta, rc (release candidate)
- **BUILD**: Build metadata

### Workflow

1. Parse tag name and options
2. Validate semantic versioning format
3. Check if tag already exists
4. Validate commit exists
5. Check GPG configuration if signing
6. Invoke agent: create-tag operation
7. Display tag details

### Example Flow

```
User: /repo:tag create v1.2.3 --message "Release version 1.2.3"

1. Validate:
   - Tag format: v1.2.3 (valid semver) ✓
   - Tag exists: false ✓
   - Commit: HEAD (abc123...) ✓
   - Message provided: ✓

2. Create tag:
   {
     "operation": "create-tag",
     "parameters": {
       "tag_name": "v1.2.3",
       "message": "Release version 1.2.3",
       "commit_sha": "abc123...",
       "sign": false
     }
   }

3. Display:
   ✅ Tag created successfully

   Tag: v1.2.3
   Commit: abc123def456...
   Message: Release version 1.2.3
   Signed: No

   To push: /repo:tag push v1.2.3
```

## Subcommand: push

Push tags to remote repository.

### Syntax

```bash
/repo:tag push <tag_name|all> [options]
```

### Arguments

- `tag_name`: Specific tag to push, or "all" to push all tags

### Optional Flags

- `--remote <name>`: Remote name (default: origin)

### Examples

```bash
# Push single tag
/repo:tag push v1.2.3

# Push all tags
/repo:tag push all

# Push to specific remote
/repo:tag push v1.2.3 --remote upstream
```

### Workflow

1. Parse tag name and options
2. Validate tag exists locally
3. Check remote connectivity
4. Invoke agent: push-tag operation
5. Display push status

### Example Flow

```
User: /repo:tag push v1.2.3

1. Validate:
   - Tag exists: v1.2.3 ✓
   - Remote: origin ✓
   - Authenticated: ✓

2. Push tag:
   {
     "operation": "push-tag",
     "parameters": {
       "tag_name": "v1.2.3",
       "remote": "origin"
     }
   }

3. Display:
   ✅ Tag pushed successfully

   Tag: v1.2.3 → origin
   Remote URL: https://github.com/owner/repo.git

   Next: Create GitHub release at:
   https://github.com/owner/repo/releases/new?tag=v1.2.3
```

## Subcommand: list

List existing tags.

### Syntax

```bash
/repo:tag list [options]
```

### Optional Flags

- `--pattern <pattern>`: Filter tags by pattern (e.g., "v1.*")
- `--latest <n>`: Show only latest N tags

### Examples

```bash
# List all tags
/repo:tag list

# List v1.x tags
/repo:tag list --pattern "v1.*"

# Show latest 5 tags
/repo:tag list --latest 5
```

## GPG Signing

### Why Sign Tags?

- Verify tag authenticity
- Prove identity of tagger
- Establish trust chain
- Meet compliance requirements

### Setup GPG Signing

```bash
# Generate GPG key (if needed)
gpg --gen-key

# Configure Git
git config user.signingkey <key-id>

# Configure repo plugin to always sign
# In config/repo.example.json:
{
  "defaults": {
    "tags": {
      "require_signed_tags": true
    }
  }
}
```

### Create Signed Tag

```bash
/repo:tag create v1.0.0 --message "Signed release" --sign
```

Result:
```
✅ Tag created successfully

Tag: v1.0.0
Commit: abc123...
Signed: Yes (GPG key: 1234ABCD)
```

### Verify Signed Tag

```bash
git tag -v v1.0.0
```

## Error Handling

**Invalid Version Format**:
```
Error: Invalid tag name format: 1.2.3
Tag must follow semantic versioning: vMAJOR.MINOR.PATCH
Examples: v1.0.0, v2.1.3, v1.0.0-beta.1
```

**Tag Already Exists**:
```
Error: Tag already exists: v1.2.3
Use --force to overwrite (WARNING: this may cause issues)
```

**GPG Not Configured**:
```
Error: GPG signing requested but not configured
Configure GPG key: git config user.signingkey <key-id>
Generate key: gpg --gen-key
```

**Commit Not Found**:
```
Error: Commit not found: abc123
Check commit SHA: git log
```

**Tag Not Found (Push)**:
```
Error: Tag not found locally: v1.2.3
Create tag first: /repo:tag create v1.2.3
List tags: /repo:tag list
```

**Network Error**:
```
Error: Failed to push tag to remote: origin
Check network connection and remote URL
View remotes: git remote -v
```

## Release Workflow

Typical workflow for creating a release:

```bash
# 1. Ensure you're on main branch with latest changes
git checkout main
git pull

# 2. Create release tag
/repo:tag create v1.2.3 --message "Release version 1.2.3 - Added CSV export and fixed auth bugs"

# 3. Push tag to remote
/repo:tag push v1.2.3

# 4. Create GitHub release (automated or manual)
# GitHub will automatically create a release from the tag
```

## Pre-Release Workflow

For alpha, beta, or release candidate versions:

```bash
# Alpha release
/repo:tag create v2.0.0-alpha.1 --message "Alpha release for early testing"

# Beta release
/repo:tag create v2.0.0-beta.1 --message "Beta release - feature complete"

# Release candidate
/repo:tag create v2.0.0-rc.1 --message "Release candidate - final testing"

# Final release
/repo:tag create v2.0.0 --message "Major release version 2.0.0"
```

## Version Increment Guide

**When to increment each component**:

**MAJOR** (v1.0.0 → v2.0.0):
- Breaking API changes
- Removed features
- Changed behavior that breaks existing usage

**MINOR** (v1.0.0 → v1.1.0):
- New features (backward compatible)
- New functionality
- Deprecations (not removals)

**PATCH** (v1.0.0 → v1.0.1):
- Bug fixes
- Security patches
- Performance improvements (no new features)

**PRERELEASE** (v1.0.0 → v1.1.0-beta.1):
- Testing versions before final release
- alpha: Early testing
- beta: Feature complete, testing
- rc: Release candidate, final testing

## FABER Integration

When used within FABER workflows:
- Automatically creates tags during Release phase
- Tags include FABER metadata in annotation
- Links to work items
- Follows semantic versioning automatically
- Can trigger CI/CD deployment pipelines

## Integration

**Called By**: User via CLI

**Calls**: repo-manager agent with operations:
- create-tag
- push-tag

**Returns**: Human-readable output with tag details

## Best Practices

1. **Always use semantic versioning**: Follow vMAJOR.MINOR.PATCH format
2. **Write meaningful messages**: Explain what's in the release
3. **Sign important tags**: Use GPG for production releases
4. **Tag from stable commits**: Ensure code is tested before tagging
5. **Push after creating**: Don't forget to push tags to remote
6. **Document breaking changes**: Use MAJOR version increments
7. **Use pre-releases**: Test with alpha/beta before final release

## Notes

- Tags are immutable (should not be changed once pushed)
- Annotated tags (with messages) are preferred over lightweight tags
- Tags trigger CI/CD workflows in many systems
- GitHub automatically creates releases from tags
- Semantic versioning enables automated changelog generation
- GPG signatures provide cryptographic verification
