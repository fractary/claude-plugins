---
name: fractary-spec:create
description: Create specification from conversation context
argument-hint: [--work-id <id>] [--template <type>] [--context "<text>"]
---

Create a specification from current conversation context.

This command uses the full conversation context as the primary source for generating a specification. Optionally enrich with GitHub issue data by providing `--work-id`.

**Key Feature**: This command directly invokes the spec-generator skill to preserve conversation context, bypassing the agent layer.

## Usage

```bash
/fractary-spec:create [options]
```

## Options

- `--work-id <id>`: Optional - Link to issue and enrich with issue data (description + all comments)
- `--template <type>`: Optional - Override auto-detection (basic|feature|infrastructure|api|bug)
- `--context "<text>"`: Optional - Additional explicit context to consider

## Examples

### Basic Usage (Context Only)

After a planning discussion in the current session:

```bash
/fractary-spec:create
```

Generates: `/specs/SPEC-20250115143000-<slug>.md`
- Uses full conversation context
- Auto-detects template from discussion
- No GitHub linking
- Standalone specification

### With Work Item (Context + Issue Enrichment)

After refining approach for issue #123:

```bash
/fractary-spec:create --work-id 123
```

Generates: `/specs/WORK-00123-<slug>.md`
- Uses conversation context as primary source
- Fetches issue #123 (description + all comments via repo plugin)
- Merges conversation + issue data
- Auto-detects template from merged context
- Links to issue #123 (GitHub comment added)

### With Template Override

Force specific template type:

```bash
/fractary-spec:create --template infrastructure --work-id 123
```

Generates: `/specs/WORK-00123-<slug>.md`
- Uses infrastructure template regardless of auto-detection
- Links to issue #123

### With Additional Context

Provide explicit context alongside conversation:

```bash
/fractary-spec:create --context "Focus on REST API design with OAuth2" --work-id 123
```

Generates: `/specs/WORK-00123-<slug>.md`
- Considers: conversation + explicit context + issue data
- Auto-detects or uses provided template

## What It Does

1. **Extract Conversation Context**: Uses full conversation history as primary source
2. **Fetch Issue (if `--work-id`)**: Gets issue description + all comments via repo plugin
3. **Merge Contexts**: Combines conversation + explicit context + issue data (if provided)
4. **Auto-Detect Template**: Infers appropriate template from merged context
5. **Generate Spec**: Creates specification from merged context
6. **Save Local**: Writes to `/specs` directory
   - With `--work-id`: `WORK-{id:05d}-{slug}.md`
   - Without: `SPEC-{timestamp}-{slug}.md`
7. **Link to Issue (if `--work-id`)**: Comments on GitHub with spec location

## Template Auto-Detection

Template is automatically inferred from context:

- **bug**: Keywords like "fix", "bug", "defect", "regression"
- **feature**: Keywords like "add", "implement", "new feature", "enhancement"
- **infrastructure**: Keywords like "deploy", "AWS", "Terraform", "infrastructure"
- **api**: Keywords like "API", "endpoint", "REST", "GraphQL"
- **basic**: Default fallback

No prompting required - the best template is selected automatically.

## Naming Convention

### With `--work-id`
Pattern: `WORK-{issue:05d}-{slug}.md`

Examples:
- `WORK-00123-user-authentication.md`
- `WORK-00084-api-redesign.md`

### Without `--work-id`
Pattern: `SPEC-{timestamp}-{slug}.md`

Examples:
- `SPEC-20250115143000-user-authentication.md`
- `SPEC-20250115150000-api-redesign.md`

Timestamp format: `YYYYMMDDHHmmss`

## Output

### Example: Context Only

```
🎯 STARTING: Spec Generator (Context Mode)
Template: feature (auto-detected)
───────────────────────────────────────

Analyzing conversation context...
Auto-detecting template: feature
Generating spec: SPEC-20250115143000-user-auth.md
Spec saved locally.

✅ COMPLETED: Spec Generator
Spec created: /specs/SPEC-20250115143000-user-auth.md
Template used: feature
Source: Conversation context
───────────────────────────────────────
Next: Begin implementation using spec as guide
```

### Example: Context + Issue Enrichment

```
🎯 STARTING: Spec Generator (Context Mode)
Work ID: #123
Template: feature (auto-detected)
───────────────────────────────────────

Analyzing conversation context...
Fetching issue #123 (with comments)...
Merging conversation + issue data...
Auto-detecting template: feature
Generating spec: WORK-00123-user-auth.md
Linking to issue #123...

✅ COMPLETED: Spec Generator
Spec created: /specs/WORK-00123-user-auth.md
Template used: feature
Source: Conversation + Issue #123
GitHub comment: ✓ Added
───────────────────────────────────────
Next: Begin implementation using spec as guide
```

## GitHub Integration

When `--work-id` is provided, a comment is added to the issue:

```markdown
📋 Specification Created

Specification generated for this issue:
- [WORK-00123-user-auth.md](/specs/WORK-00123-user-auth.md)

This spec will guide implementation and be validated before archival.
```

## Context Preservation

**Why this command bypasses the agent:**

Traditional flow:
```
Command → Agent → Skill
         └─ Context lost here (agent starts fresh conversation)
```

This command:
```
Command → Skill (direct)
         └─ Full conversation context preserved
```

This design ensures the specification captures the full planning discussion, not just the final command arguments.

## FABER Integration

In FABER workflow, you can configure which command to use in the Architect phase:

```toml
[workflow.architect]
generate_spec = true
spec_plugin = "fractary-spec"
spec_command = "create"  # Use context-centric command
```

## Use Cases

### Standalone Exploratory Specs
After a design discussion with no tied work item:
```bash
/fractary-spec:create --template feature
```
Results in standalone spec for reference.

### Work Item with Rich Context
After extensive planning for issue #123:
```bash
/fractary-spec:create --work-id 123
```
Captures both the planning discussion AND the issue details.

### Multi-Phase Planning
After discussing phase 1 of a complex feature:
```bash
/fractary-spec:create --work-id 123 --context "Phase 1: User Authentication"
```

## Comparison with `/fractary-spec:create-from-issue`

| Aspect | `create` | `create-from-issue` |
|--------|----------|---------------------|
| Primary Source | Conversation context | Issue data |
| Context Preserved | ✓ Yes (direct to skill) | ✗ No (goes through agent) |
| Issue Fetch | Optional (with `--work-id`) | Required (argument) |
| Use Case | Planning discussions | Issue-driven work |
| Work ID | Optional flag | Required argument |
| Naming (no issue) | `SPEC-{timestamp}-*` | N/A (requires issue) |
| Naming (with issue) | `WORK-{id:05d}-*` | `WORK-{id:05d}-*` |

## Troubleshooting

**No slug generated**:
- Ensure conversation has meaningful content
- Use `--context` to provide explicit description
- Fallback: timestamp-based naming

**Template detection unclear**:
- Use `--template` to override
- Provide clearer keywords in discussion

**Issue not found** (when using `--work-id`):
- Check issue number is correct
- Ensure you have GitHub access
- Verify repository is correct

**Warning: GitHub comment failed**:
- Non-critical, spec still created
- Can manually link if needed
