---
name: fractary-spec:read
description: Read archived specification from cloud storage
---

Read an archived specification from cloud storage without downloading it locally.

After specs are archived, they're removed from local storage. This command retrieves them from cloud storage for reference.

## Usage

```bash
/fractary-spec:read <issue_number> [options]
```

## Arguments

- `<issue_number>`: GitHub issue number (required)

## Options

- `--phase <n>`: Read specific phase for multi-spec issues

## Examples

### Single Spec

```bash
/fractary-spec:read 123
```

Reads the archived spec for issue #123.

### Multi-Spec (Specific Phase)

```bash
/fractary-spec:read 123 --phase 1
```

Reads phase 1 spec only.

### Multi-Spec (All Phases)

```bash
/fractary-spec:read 123
```

Lists all phases, prompts which to read.

## What It Does

1. **Look Up in Index**: Finds archive entry in `.fractary/plugins/spec/archive-index.json`
2. **Get Cloud URL**: Retrieves cloud storage URL
3. **Stream Content**: Reads from cloud via fractary-file plugin
4. **Display**: Shows spec content
5. **No Download**: No local file created

## Output

```
🎯 Reading archived spec for issue #123...

Found 2 specs:
1. Phase 1: Authentication (15.4 KB)
2. Phase 2: OAuth Integration (18.9 KB)

Select phase [1-2] or 'all': 1

───────────────────────────────────────
Spec: spec-123-phase1-authentication.md
Archived: 2025-01-15
Cloud URL: https://storage.example.com/specs/2025/123-phase1.md
───────────────────────────────────────

[Spec content displayed here]

───────────────────────────────────────
✅ Read complete
```

## Single Spec (No Phases)

If issue has only one spec:

```
🎯 Reading archived spec for issue #123...

───────────────────────────────────────
Spec: spec-123-feature.md
Archived: 2025-01-15
Cloud URL: https://storage.example.com/specs/2025/123.md
───────────────────────────────────────

[Spec content displayed here]

───────────────────────────────────────
✅ Read complete
```

## Use Cases

### Reference During Development

```bash
# Working on related feature, need to check original spec
/fractary-spec:read 100
```

### Code Review

```bash
# Reviewing PR, want to verify against spec
/fractary-spec:read 123
```

### Historical Context

```bash
# Understanding why something was built a certain way
/fractary-spec:read 50
```

### Documentation

```bash
# Writing docs, need to reference requirements
/fractary-spec:read 123
```

## Archive Index Lookup

Looks up in `.fractary/plugins/spec/archive-index.json`:

```json
{
  "archives": [
    {
      "issue_number": "123",
      "specs": [
        {
          "filename": "spec-123-phase1-auth.md",
          "cloud_url": "https://storage.example.com/specs/2025/123-phase1.md",
          "public_url": "https://storage.example.com/specs/2025/123-phase1.md"
        }
      ]
    }
  ]
}
```

## Cloud Storage

Uses fractary-file plugin to read from cloud:
- No local file created
- Streamed directly from cloud
- Efficient for large specs
- Always get latest archived version

## Output Formats

### Interactive Display

Default: displays content in terminal with formatting.

### Copy to Clipboard

```bash
/fractary-spec:read 123 | pbcopy  # macOS
/fractary-spec:read 123 | xclip   # Linux
```

### Save to File (Temporary)

```bash
/fractary-spec:read 123 > /tmp/spec-123.md
```

Note: Better to use the command directly rather than maintaining local copies.

## Troubleshooting

**Error: Issue not found in archive**:
- Check issue number
- Verify specs were archived
- Look at archive index: `cat .fractary/plugins/spec/archive-index.json`

**Error: Cloud storage unavailable**:
- Check network connection
- Verify fractary-file plugin configuration
- Check cloud storage credentials

**Error: Spec not found**:
- Spec may not have been archived yet
- Check if still in local /specs directory
- Verify archival completed successfully

## Comparison with Local Specs

| Aspect | Local Specs | Archived Specs |
|--------|-------------|----------------|
| Location | /specs/*.md | Cloud storage |
| Access | Direct file read | Via fractary-spec:read |
| Context | Active development | Historical reference |
| Lifecycle | Temporary | Permanent |
| Updates | Can be edited | Immutable |

## Best Practices

1. **Read Only When Needed**: Don't maintain local copies
2. **Reference in PRs**: Link to archived specs in PR descriptions
3. **Documentation Links**: Link to archived specs in docs
4. **Historical Context**: Use for understanding past decisions

## Integration with Other Tools

### With Git Blame

```bash
# Find when code was added
git blame src/auth.ts

# Read original spec
/fractary-spec:read 123
```

### With Issue References

```bash
# From commit message or PR, get issue number
# Then read spec
/fractary-spec:read 123
```

### With Documentation

```markdown
<!-- In README.md -->
For details on authentication design, see:
- [Spec #123](https://storage.example.com/specs/2025/123.md)
```
