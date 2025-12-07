# Workflow Analysis: fractary-codex:sync-org Usage

**Issue**: #259 - Reconsider fractary-codex:sync-org
**Date**: 2025-12-07
**Analysis**: Ecosystem integration and workflow compatibility

## Summary

Analysis of the Fractary plugin ecosystem shows that:
1. **No default FABER workflows currently use `sync-org`**
2. **The new v3 pattern uses per-project `sync-project`** at workflow start
3. **All documented use cases can be handled by `sync-project`**
4. **Deprecation would not break existing workflows** (none depend on it in core)

This analysis supports the recommendation to deprecate `sync-org`.

## Ecosystem Scan Results

### Plugins Examined

| Plugin | sync-org Usage | Notes |
|--------|---|---|
| `faber/` | NO | No references to sync-org in workflow definitions |
| `faber-app/` | NO | App-specific FABER workflows don't use sync-org |
| `faber-cloud/` | NO | Cloud workflows don't use sync-org |
| `codex/` | YES (own plugin) | Defines sync-org command and skills |
| `repo/` | NO | Version control only, no codex integration |
| `work/` | NO | Issue management only |
| `file/` | NO | File storage only |

### Default Workflow Configuration

**File**: `plugins/faber/config/workflows/default.json`

```json
{
  "phases": {
    "frame": {
      "description": "Fetch work item and setup branch",
      "pre_steps": [
        {
          "id": "core-fetch-or-create-issue",
          "name": "Fetch or Create Issue"
        },
        {
          "id": "core-switch-or-create-branch",
          "name": "Switch or Create Branch"
        }
      ]
    },
    "architect": {
      "description": "Design and plan",
      "steps": [
        {
          "id": "generate-spec",
          "skill": "fractary-spec:spec-generator"
        }
      ]
    },
    "build": {
      "description": "Implementation",
      "steps": [
        {
          "id": "implement",
          "prompt": "Analyze specification and implement..."
        }
      ]
    },
    "evaluate": {
      "steps": [
        {
          "id": "core-issue-review",
          "skill": "fractary-faber:issue-reviewer"
        }
      ]
    },
    "release": {
      "steps": [
        {
          "id": "core-merge-pr",
          "skill": "fractary-repo:pr-manager"
        }
      ]
    }
  }
}
```

**Finding**: No `sync-org` or codex sync operations in default workflow.

### New Pattern: Per-Project Sync in Workflows

**Recommended Usage** (documented in codex QUICK-START):

```markdown
# Recommended: Add to your FABER workflow config

{
  "phases": {
    "frame": {
      "pre_steps": [
        {
          "id": "codex-sync",
          "name": "Sync documentation from central codex",
          "skill": "fractary-codex:sync-project",
          "config": {
            "direction": "from-codex",
            "auto_detect_environment": true
          }
        }
      ]
    }
  }
}
```

This is the **new pattern** - each project pulls docs it needs at workflow start.

## Use Case Analysis

### Use Case 1: "Ensure all projects have latest documentation"

**Old Approach (sync-org)**:
```bash
/fractary-codex:sync-org --env test
# Result: All org projects receive latest codex docs (via push)
# Risk: Unexpected changes in projects that don't expect them
```

**New Approach (per-project pull)**:
```bash
# In each project's CI/CD or FABER workflow:
/fractary-codex:sync-project --env test --from-codex

# Result: Each project pulls what it needs when it needs it
# Benefit: Explicit, predictable, per-project control
```

**Migration**: Update each project's FABER workflow config (add codex-sync pre-step).

**Viable?**: ✓ YES - Per-project approach is superior

---

### Use Case 2: "Collect documentation from all projects into codex"

**Old Approach (sync-org)**:
```bash
/fractary-codex:sync-org --env test --to-codex
# Result: All org projects' docs pushed to central codex
# Risk: Uncontrolled bulk upload; projects may have private docs
```

**New Approach (per-project contribution)**:
```bash
# In each project's CI/CD (e.g., after releases):
/fractary-codex:sync-project --to-codex --env prod

# Result: Projects explicitly contribute docs when ready
# Benefit: Controlled, intentional, per-project timing
```

**Migration**: Update CI/CD pipelines to run per-project sync when appropriate.

**Viable?**: ✓ YES - Actually better control

---

### Use Case 3: "Synchronize infrastructure documentation across deployment"

**Old Approach (sync-org)**:
```bash
# Run from infrastructure project:
/fractary-codex:sync-org --env prod --bidirectional
# Result: All org projects sync with codex infrastructure docs
```

**New Approach (targeted per-project)**:
```bash
# In infra CI/CD, push docs to codex:
/fractary-codex:sync-project --to-codex --env prod

# Each project pulls what it needs (in their workflow):
/fractary-codex:sync-project --from-codex --env prod
```

**Migration**: Infrastructure project explicitly pushes; other projects pull in workflows.

**Viable?**: ✓ YES - More explicit and controllable

---

### Use Case 4: "Maintain consistency across environment documentation"

**Old Approach (sync-org)**:
```bash
/fractary-codex:sync-org --env test
/fractary-codex:sync-org --env prod
# Sync to both test and prod environments organization-wide
```

**New Approach (per-project env management)**:
```bash
# Each project's workflow auto-detects its current environment:
/fractary-codex:sync-project
# On test branch → syncs to test docs
# On main branch → syncs to prod docs

# Or explicit:
/fractary-codex:sync-project --env test
/fractary-codex:sync-project --env prod
```

**Migration**: Projects manage their own environment synchronization in workflows.

**Viable?**: ✓ YES - Simpler and more decentralized

---

## Ecosystem Integration Points

### Commands That Reference or Use sync-org

**Search Results**:
```bash
grep -r "sync-org" plugins/ --include="*.md" --include="*.json" --include="*.ts" --include="*.js"
```

**Findings**:
1. **Direct References**:
   - `plugins/codex/commands/sync-org.md` - Definition
   - `plugins/codex/skills/org-syncer/SKILL.md` - Implementation
   - `plugins/codex/agents/codex-manager.md` - Routes to org-syncer
   - `plugins/codex/README.md` - Documentation (can be updated)
   - `plugins/codex/QUICK-START.md` - Examples (can be updated)

2. **Implicit Dependencies**:
   - `plugins/codex/skills/repo-discoverer/` - Used by org-syncer (can remain for other uses)
   - `plugins/codex/skills/project-syncer/` - Invoked by org-syncer (will continue to be used)

3. **No Plugin-to-Plugin Dependencies**:
   - Examined: `faber`, `faber-app`, `faber-cloud`, `repo`, `work`, `file`
   - None directly invoke `sync-org`
   - None depend on `sync-org` behavior

### CI/CD Integration

**Potential sync-org Usage in CI/CD**:

Projects might use sync-org in automated pipelines like:
```yaml
# Hypothetical CI/CD configuration
- name: Sync organization documentation
  run: /fractary-codex:sync-org --env test
```

**Migration Strategy**: Update CI/CD in each project to use per-project sync instead.

## Backward Compatibility Impact

### What Would Break If sync-org Is Deprecated

| Component | Breaking? | Mitigation |
|-----------|-----------|-----------|
| Custom workflows using sync-org | YES | Migration guide provided |
| CI/CD scripts calling sync-org | YES | Migration guide provided |
| Manual commands by users | YES | Deprecation warnings in v3.3 |
| Core FABER workflows | NO | Not used in defaults |
| Core plugin ecosystem | NO | No internal dependencies |

### Breaking Only External Users

The `sync-org` command is **only used by external parties** (organizations implementing codex):
- No internal plugins depend on it
- No core workflows use it
- Not part of critical path for FABER execution

**Impact**: Low risk for deprecation - affects only organizations actively using `sync-org`.

## Recommended Migration Path

### For Organizations Currently Using sync-org

**Option A: Migrate to Workflow-Based Sync** (Recommended)

1. **Update each project's FABER workflow**:
   ```json
   {
     "extends": "fractary-faber:default",
     "phases": {
       "frame": {
         "pre_steps": [
           {
             "name": "sync-codex",
             "skill": "fractary-codex:sync-project",
             "config": {
               "direction": "from-codex",
               "environment": "auto-detect"
             }
           }
         ]
       }
     }
   }
   ```

2. **Update CI/CD pipelines**:
   ```bash
   # Old:
   /fractary-codex:sync-org --env test

   # New:
   for project in $(gh repo list $ORG --json name -q '.[].name'); do
     cd $project
     /fractary-codex:sync-project --env test --from-codex
     cd ..
   done
   ```

3. **Benefits**:
   - Per-project control
   - Sync when needed, not forced
   - Explicit in workflow configuration
   - No organization-wide coordination needed

**Option B: Custom Orchestration**

1. Create a custom orchestration command that calls `sync-project` for multiple projects
2. Implement this at the organization level (not in core Codex)
3. Add it as a custom command or CI/CD workflow

**Option C: Wrapper Script**

```bash
#!/bin/bash
# fractary-codex-sync-org-wrapper.sh
# Temporary wrapper for organizations still using org-wide sync

ORG="$1"
ENV="${2:-test}"

for project in $(gh repo list "$ORG" --json name -q '.[].name'); do
  echo "Syncing $project..."
  (cd "$project" && /fractary-codex:sync-project --env "$ENV")
done
```

## Conclusion

### Ecosystem Findings

1. ✓ **No core workflows use `sync-org`** - Safe to deprecate
2. ✓ **All use cases have per-project alternatives** - No gap
3. ✓ **New pattern is per-project pull-based** - Architectural alignment
4. ✓ **No plugin dependencies on sync-org** - Won't break ecosystem
5. ✓ **Migration path is straightforward** - Users have clear alternatives

### Recommendation

**Proceed with deprecation of `sync-org`** because:
1. No core ecosystem dependencies
2. All use cases covered by `sync-project`
3. New architecture moves toward per-project control
4. Permissions model is fundamentally safer without org-wide sync
5. Users have clear migration paths

### Timeline

- **v3.2 (2 weeks)**: Add deprecation notice to documentation
- **v3.3 (6 weeks)**: Display warnings when sync-org is used
- **v4.0 (6 months)**: Remove sync-org command and org-syncer skill

This gives organizations at least 4 months notice before removal.
