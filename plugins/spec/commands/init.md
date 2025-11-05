---
name: fractary-spec:init
description: Initialize fractary-spec plugin configuration
---

Initialize the fractary-spec plugin in the current project.

This command:
1. Creates configuration file from example
2. Creates /specs directory
3. Initializes archive index
4. Sets up integration with fractary-work and fractary-file

## Usage

```bash
/fractary-spec:init
```

## What It Does

1. **Copy Configuration**:
   - Copies `config.example.json` to project's config location
   - User can customize settings afterward

2. **Create Specs Directory**:
   - Creates `/specs` directory (or configured path)
   - This is where active specs are stored

3. **Initialize Archive Index**:
   - Creates `.fractary/plugins/spec/archive-index.json`
   - Empty index ready for archival entries

4. **Verify Dependencies**:
   - Checks fractary-work plugin installed
   - Checks fractary-file plugin installed
   - Warns if missing

## Output

```
🎯 Initializing fractary-spec plugin...

✓ Configuration created: .fractary/plugins/spec/config.json
✓ Specs directory created: /specs
✓ Archive index initialized: .fractary/plugins/spec/archive-index.json
✓ Dependencies verified:
  - fractary-work: ✓ Installed
  - fractary-file: ✓ Installed

✅ fractary-spec plugin initialized!

Next steps:
1. Review configuration: .fractary/plugins/spec/config.json
2. Generate your first spec: /fractary-spec:generate <issue>
```

## Configuration

After initialization, review and customize:

```json
{
  "storage": {
    "local_path": "/specs",
    "cloud_archive_path": "archive/specs/{year}/{issue_number}.md"
  },
  "archive": {
    "auto_archive_on": {
      "issue_close": true,
      "pr_merge": true,
      "faber_release": true
    }
  }
}
```

## Troubleshooting

**Error: Directory already exists**:
- Safe to run multiple times
- Existing config not overwritten

**Warning: Dependencies not found**:
- Install fractary-work plugin
- Install fractary-file plugin
- Required for full functionality
