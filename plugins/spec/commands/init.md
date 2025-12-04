---
name: fractary-spec:init
description: Initialize fractary-spec plugin configuration
model: claude-haiku-4-5
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

3. **Initialize Archive Index** (Two-Tier Storage):
   - **Local Cache**: `.fractary/plugins/spec/archive-index.json`
     - Fast access for lookups
     - Git-ignored (not in version control)
   - **Cloud Backup**: `archive/specs/.archive-index.json`
     - Durable storage, recoverable if local lost
     - Synced automatically during archival
   - On init, attempts to sync from cloud if available
   - If cloud unavailable or empty, creates new local index

4. **Verify Dependencies**:
   - Checks fractary-work plugin installed
   - Checks fractary-file plugin installed
   - Warns if missing

## Output

### First-Time Init (No Cloud Index)

```
🎯 Initializing fractary-spec plugin...

✓ Configuration created: .fractary/plugins/spec/config.json
✓ Specs directory created: /specs
ℹ No cloud index found, creating new local index
✓ Archive index initialized: .fractary/plugins/spec/archive-index.json
✓ Dependencies verified:
  - fractary-work: ✓ Installed
  - fractary-file: ⚠ Not available (cloud sync disabled)

✅ fractary-spec plugin initialized!

Next steps:
1. Review configuration: .fractary/plugins/spec/config.json
2. Generate your first spec: /fractary-spec:generate <issue>
```

### Init with Cloud Sync (Recovering Lost Local Environment)

```
🎯 Initializing fractary-spec plugin...

✓ Configuration created: .fractary/plugins/spec/config.json
✓ Specs directory created: /specs
Syncing archive index from cloud...
✓ Archive index synced from cloud
✓ Local cache updated: .fractary/plugins/spec/archive-index.json
✓ Dependencies verified:
  - fractary-work: ✓ Installed
  - fractary-file: ✓ Installed

✅ fractary-spec plugin initialized!
✅ Recovered 15 archived specs from cloud index!

Next steps:
1. Review configuration: .fractary/plugins/spec/config.json
2. Read archived specs: /fractary-spec:read <issue>
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

---

<MANDATORY_IMPLEMENTATION>
**YOU MUST EXECUTE THESE STEPS - DO NOT SKIP ANY STEP:**

**Step 1: Check if config already exists**
```bash
if [ -f ".fractary/plugins/spec/config.json" ]; then
    echo "⚠️ Configuration already exists at .fractary/plugins/spec/config.json"
    # Safe to continue - will not overwrite
fi
```

**Step 2: Create the configuration directory and specs directory**
This is the CRITICAL step - you MUST run these commands:
```bash
# Create plugin config directory
mkdir -p .fractary/plugins/spec

# Create specs directory
mkdir -p specs
```

**Step 3: Create the configuration file**
```bash
# Create config file
cat > .fractary/plugins/spec/config.json << 'EOF'
{
  "schema_version": "1.0",
  "storage": {
    "local_path": "/specs",
    "cloud_archive_path": "archive/specs/{year}/{spec_id}.md",
    "archive_index": {
      "local_cache": ".fractary/plugins/spec/archive-index.json",
      "cloud_backup": "archive/specs/.archive-index.json"
    }
  },
  "naming": {
    "issue_specs": {
      "prefix": "WORK",
      "digits": 5,
      "phase_format": "numeric",
      "phase_separator": "-"
    },
    "standalone_specs": {
      "prefix": "SPEC",
      "digits": 4,
      "auto_increment": true,
      "start_from": null
    }
  },
  "archive": {
    "strategy": "lifecycle",
    "auto_archive_on": {
      "issue_close": true,
      "pr_merge": true,
      "faber_release": true
    }
  },
  "integration": {
    "work_plugin": "fractary-work",
    "file_plugin": "fractary-file",
    "link_to_issue": true
  },
  "templates": {
    "default": "spec-basic"
  }
}
EOF

# Set permissions
chmod 600 .fractary/plugins/spec/config.json
```

**Step 4: Create empty archive index**
```bash
# Create archive index file
echo '{"specs": [], "last_updated": null}' > .fractary/plugins/spec/archive-index.json
chmod 600 .fractary/plugins/spec/archive-index.json
```

**Step 5: Verify the files were created**
```bash
if [ -f ".fractary/plugins/spec/config.json" ]; then
    echo "✅ Configuration created: .fractary/plugins/spec/config.json"
else
    echo "❌ Failed to create configuration file"
fi

if [ -d "specs" ]; then
    echo "✅ Specs directory created: specs/"
else
    echo "❌ Failed to create specs directory"
fi
```

**Step 6: Show success message and next steps**
Display:
```
✅ Fractary Spec Plugin initialized!

Configuration: .fractary/plugins/spec/config.json
Specs directory: specs/
Archive index: .fractary/plugins/spec/archive-index.json

Next steps:
1. Generate your first spec: /fractary-spec:create --work-id 123
2. Review configuration: cat .fractary/plugins/spec/config.json
```

</MANDATORY_IMPLEMENTATION>
