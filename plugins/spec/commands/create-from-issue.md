---
name: fractary-spec:create-from-issue
description: Create specification from GitHub issue data
argument-hint: <issue_number> [--phase <n>] [--title "<title>"] [--template <type>]
---

Create a specification from a GitHub issue.

This command fetches full issue data (including description and all comments via repo plugin), classifies the work type, selects an appropriate template, and creates a structured specification document.

## Usage

```bash
/fractary-spec:create-from-issue <issue_number> [options]
```

## Arguments

- `<issue_number>`: GitHub issue number (required)

## Options

- `--phase <n>`: Phase number for multi-spec support
- `--title "<title>"`: Phase title for naming
- `--template <type>`: Override auto-detection (basic|feature|infrastructure|api|bug)

## Examples

### Basic Usage

```bash
/fractary-spec:create-from-issue 123
```

Generates: `/specs/WORK-00123-<slug>.md`

### Multi-Spec (Phases)

```bash
/fractary-spec:create-from-issue 123 --phase 1 --title "User Authentication"
/fractary-spec:create-from-issue 123 --phase 2 --title "OAuth Integration"
```

Generates:
- `/specs/WORK-00123-01-user-authentication.md`
- `/specs/WORK-00123-02-oauth-integration.md`

### Template Override

```bash
/fractary-spec:create-from-issue 123 --template infrastructure
```

Forces infrastructure template instead of auto-detection.

## What It Does

1. **Fetch Issue**: Gets full issue data from GitHub (description + all comments via repo plugin)
2. **Classify**: Determines work type from labels, title, and content
3. **Select Template**: Chooses appropriate spec template
4. **Parse Data**: Extracts requirements, criteria, files from issue and comments
5. **Generate Spec**: Fills template with issue data
6. **Save Local**: Writes to `/specs` directory
7. **Link to Issue**: Comments on GitHub with spec location

## Template Selection

### Auto-Detection

Based on labels and keywords:

- **bug**: Labels contain "bug", "defect", or title starts with "Fix"
- **feature**: Labels contain "feature", "enhancement", or title starts with "Add"
- **infrastructure**: Labels contain "infrastructure", "devops", "cloud"
- **api**: Labels contain "api", "endpoint" or title contains "API"
- **basic**: Default fallback

### Templates

- `spec-basic.md.template`: General-purpose
- `spec-feature.md.template`: User stories, UI/UX, rollout
- `spec-infrastructure.md.template`: Resources, deployment, monitoring
- `spec-api.md.template`: Endpoints, models, authentication
- `spec-bug.md.template`: Root cause, fix approach, prevention

## Output

```
🎯 STARTING: Spec Generator
Issue: #123
Template: feature
───────────────────────────────────────

Fetching issue #123 (with comments)...
Classifying work type: feature
Selecting template: spec-feature.md.template
Generating spec: WORK-00123-implement-auth.md
Linking to issue #123...

✅ COMPLETED: Spec Generator
Spec created: /specs/WORK-00123-implement-auth.md
Template used: feature
GitHub comment: ✓ Added
───────────────────────────────────────
Next: Begin implementation using spec as guide
```

## GitHub Integration

A comment is added to the issue:

```markdown
📋 Specification Created

Specification generated for this issue:
- [WORK-00123-implement-auth.md](/specs/WORK-00123-implement-auth.md)

This spec will guide implementation and be validated before archival.
```

## FABER Integration

In FABER workflow, this command is automatically invoked during the Architect phase:

```toml
[workflow.architect]
generate_spec = true
spec_plugin = "fractary-spec"
```

## Troubleshooting

**Error: Issue not found**:
- Check issue number is correct
- Ensure you have GitHub access
- Verify repository is correct

**Error: Template not found**:
- Falls back to spec-basic.md.template
- Check plugin installation

**Warning: GitHub comment failed**:
- Non-critical, spec still created
- Can manually link if needed
