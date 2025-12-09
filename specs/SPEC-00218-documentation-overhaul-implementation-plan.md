# SPEC-00218: Documentation Overhaul Implementation Plan

| Field | Value |
|-------|-------|
| **Spec ID** | SPEC-00218 |
| **Title** | Documentation Overhaul Implementation Plan |
| **Type** | Feature |
| **Status** | Draft |
| **Created** | 2025-12-09 |
| **Author** | Claude (Opus 4.5) |
| **Priority** | High |

---

## 1. Executive Summary

This specification defines a comprehensive plan to overhaul documentation across the Fractary Claude Plugins repository. Analysis has identified critical gaps affecting 6 plugins with missing documentation directories, structural inconsistencies in skill naming, orphaned temporary files, and organizational chaos in the specs directory. The implementation addresses ~150 documentation files requiring creation or updates across 16 plugins.

### 1.1 Problem Statement

The Fractary Claude Plugins repository has grown organically, resulting in:

1. **Critical Documentation Gaps**: 4 plugins completely lack documentation directories
2. **Inconsistent Standards**: Some skills use non-standard naming conventions
3. **Orphaned Files**: Temporary implementation files remain in repository root
4. **Organizational Chaos**: The specs directory mixes work items with specifications
5. **Migration Sprawl**: 9 migration files totaling 4,396 lines are scattered across plugins

### 1.2 Success Metrics

| Metric | Current State | Target State |
|--------|---------------|--------------|
| Plugins with complete docs/ | 10/16 (62.5%) | 16/16 (100%) |
| Undocumented commands | 32+ | 0 |
| Undocumented skills | 26+ | 0 |
| Non-compliant SKILL.md files | 2 | 0 |
| Orphaned temporary files | 2 | 0 |
| Specs directory organization | Chaotic | Organized with README |

---

## 2. Scope

### 2.1 In Scope

- Creating missing docs/ directories for work, file, status, helm plugins
- Writing comprehensive documentation for all undocumented commands and skills
- Restructuring non-standard skill files to follow SKILL.md conventions
- Removing orphaned temporary files
- Organizing the specs directory with proper separation
- Consolidating migration documentation
- Adding XML markup to non-compliant skill files
- Processing archive directories

### 2.2 Out of Scope

- Rewriting existing documentation that meets standards
- Adding new features or functionality
- Changing plugin behavior
- Automated documentation generation tooling (future work)

### 2.3 Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| FRACTARY-PLUGIN-STANDARDS.md | Reference | Documentation standards to follow |
| Existing plugin manifests | Input | Define command/skill inventory |
| XML markup standards | Reference | SKILL.md structure requirements |

---

## 3. Current State Analysis

### 3.1 Tier 1: CRITICAL - Missing Documentation

#### 3.1.1 WORK Plugin (Highest Priority)

The work plugin is the largest in the system and completely lacks documentation.

| Component | Count | Documentation Status |
|-----------|-------|---------------------|
| Commands | 26 | None |
| Skills | 17 | None |
| Handlers | 3 (GitHub, Jira, Linear) | None |
| docs/ directory | N/A | Missing |

**Commands requiring documentation:**
```
comment-create.md    issue-assigner.md    issue-linker.md      milestone-manager.md
comment-list.md      issue-classifier.md  issue-searcher.md    state-manager.md
handler-github.md    issue-creator.md     issue-updater.md
handler-jira.md      issue-fetch.md       label-manager.md
handler-linear.md
```

**Skills requiring documentation:**
```
comment-creator/     handler-work-tracker-jira/    issue-linker/
comment-lister/      handler-work-tracker-linear/  issue-searcher/
handler-work-tracker-github/  issue-assigner/     issue-updater/
issue-classifier/    issue-creator/                label-manager/
issue-fetcher/       milestone-manager/            state-manager/
work-common/
```

#### 3.1.2 FILE Plugin

| Component | Count | Documentation Status |
|-----------|-------|---------------------|
| Commands | 4 | None |
| Skills | 7 | None |
| Handlers | 3 (R2, S3, local) | None |
| docs/ directory | N/A | Missing |

**Components requiring documentation:**
- Commands: file operations, storage management
- Skills: upload, download, list, delete operations
- Handlers: R2, S3, local filesystem adapters

#### 3.1.3 STATUS Plugin

| Component | Count | Documentation Status |
|-----------|-------|---------------------|
| Commands | 1 | Minimal |
| Skills | 2 | None |
| docs/ directory | N/A | Missing |

#### 3.1.4 HELM Plugin

| Component | Count | Documentation Status |
|-----------|-------|---------------------|
| Commands | 4 | None |
| Agents | 2 | None |
| Skills | 0 | N/A |
| docs/ directory | N/A | Missing |

#### 3.1.5 FABER-DB Plugin

| Issue | Description |
|-------|-------------|
| Root README.md | Missing (exists at docs/README.md instead) |
| Workflow docs | Located in config/workflows/ instead of docs/ |

### 3.2 Tier 2: Structural Issues

#### 3.2.1 FABER-ARTICLE Plugin Non-Standard Skills

The faber-article plugin uses individual .md files instead of the standard SKILL.md directory structure:

```
plugins/faber-article/skills/
├── content-editor.md      # Should be content-editor/SKILL.md
├── content-linter.md      # Should be content-linter/SKILL.md
├── content-outliner.md    # Should be content-outliner/SKILL.md
├── content-publisher.md   # Should be content-publisher/SKILL.md
├── content-researcher.md  # Should be content-researcher/SKILL.md
├── content-writer.md      # Should be content-writer/SKILL.md
├── seo-optimizer.md       # Should be seo-optimizer/SKILL.md
└── source-manager.md      # Should be source-manager/SKILL.md
```

#### 3.2.2 Temporary Files to Remove

| File | Location | Reason for Removal |
|------|----------|-------------------|
| IMPLEMENTATION-NOTES-292.md | Repository root | Work item artifact, should not persist |
| TESTING-GUIDE-165.md | Repository root | Work item artifact, should not persist |

#### 3.2.3 Archive Directories

| Location | Size | Action Required |
|----------|------|-----------------|
| faber-cloud/.archive/ | 248KB | Document or remove |
| helm-cloud/.archive/ | 8KB | Document or remove |

### 3.3 Tier 3: Organization Issues

#### 3.3.1 Specs Directory Analysis

```
Total files: 119
├── WORK-*.md files: 66 (work item artifacts)
├── SPEC-*.md files: 53 (actual specifications)
└── README.md: 1 (exists but inadequate)
```

**Problems:**
- Work item files mixed with specifications
- Gaps in spec numbering (e.g., SPEC-00016 through SPEC-00023 missing)
- No clear versioning strategy for spec revisions
- Missing organization guide

#### 3.3.2 Migration Documentation Redundancy

| File | Location | Lines |
|------|----------|-------|
| MIGRATION-v2.md | plugins/faber/docs/ | ~500 |
| MIGRATION.md | plugins/codex/docs/ | ~400 |
| MIGRATION-GUIDE.md | plugins/repo/docs/ | ~350 |
| Various migration files | Scattered | ~3,146 |
| **Total** | - | **~4,396** |

### 3.4 Tier 4: Standards Compliance

#### 3.4.1 XML Markup Missing

Two SKILL.md files lack required XML markup structure:

1. `/plugins/faber-cloud/skills/cloud-common/SKILL.md`
2. `/plugins/faber/skills/core/SKILL.md`

**Required XML Tags:**
```xml
<CONTEXT>Who you are, what you do</CONTEXT>
<CRITICAL_RULES>Must-never-violate rules</CRITICAL_RULES>
<INPUTS>What you receive</INPUTS>
<WORKFLOW>Steps to execute</WORKFLOW>
<COMPLETION_CRITERIA>How to know you're done</COMPLETION_CRITERIA>
<OUTPUTS>What you return</OUTPUTS>
```

---

## 4. Implementation Plan

### 4.1 Phase 1: Critical Documentation Creation (Priority: CRITICAL)

**Duration:** 3-5 days
**Objective:** Create documentation for all plugins missing docs/ directories

#### 4.1.1 WORK Plugin Documentation

**Step 1: Create directory structure**
```bash
mkdir -p plugins/work/docs/
```

**Step 2: Create core documentation files**

| File | Description | Priority |
|------|-------------|----------|
| README.md | Plugin overview, quick start | P0 |
| CONFIGURATION.md | Handler configuration for GitHub/Jira/Linear | P0 |
| COMMANDS.md | All 26 commands with examples | P1 |
| SKILLS.md | All 17 skills reference | P1 |
| HANDLERS.md | Platform-specific handler documentation | P1 |
| TROUBLESHOOTING.md | Common issues and solutions | P2 |

**Step 3: Document each command (26 total)**

Each command documentation should include:
- Purpose and description
- Syntax with all arguments
- Required vs optional parameters
- Examples (success and error cases)
- Related commands

**Step 4: Document each skill (17 total)**

Each skill documentation should follow SKILL.md format:
- CONTEXT section
- CRITICAL_RULES section
- INPUTS section
- WORKFLOW section
- OUTPUTS section
- ERROR_HANDLING section

#### 4.1.2 FILE Plugin Documentation

**Step 1: Create directory structure**
```bash
mkdir -p plugins/file/docs/
```

**Step 2: Create documentation files**

| File | Description |
|------|-------------|
| README.md | Plugin overview |
| CONFIGURATION.md | Handler configuration for R2/S3/local |
| COMMANDS.md | All 4 commands |
| SKILLS.md | All 7 skills |
| HANDLERS.md | Storage backend documentation |

#### 4.1.3 STATUS Plugin Documentation

```bash
mkdir -p plugins/status/docs/
```

| File | Description |
|------|-------------|
| README.md | Plugin overview and installation |
| CONFIGURATION.md | Status line customization |
| SKILLS.md | Skills reference |

#### 4.1.4 HELM Plugin Documentation

```bash
mkdir -p plugins/helm/docs/
```

| File | Description |
|------|-------------|
| README.md | Dashboard overview |
| COMMANDS.md | All 4 commands |
| AGENTS.md | Agent documentation |

#### 4.1.5 FABER-DB Root README

**Action:** Move `plugins/faber-db/docs/README.md` to `plugins/faber-db/README.md`

```bash
mv plugins/faber-db/docs/README.md plugins/faber-db/README.md
# Update any internal links
```

### 4.2 Phase 2: Structural Fixes (Priority: HIGH)

**Duration:** 1-2 days
**Objective:** Align non-standard structures with conventions

#### 4.2.1 FABER-ARTICLE Skill Restructuring

Transform 8 skill files from flat structure to directory structure:

**Before:**
```
skills/content-editor.md
```

**After:**
```
skills/content-editor/
├── SKILL.md
└── workflow/
    └── (extracted workflow files if applicable)
```

**Transformation script:**
```bash
#!/bin/bash
for skill_file in plugins/faber-article/skills/*.md; do
    skill_name=$(basename "$skill_file" .md)
    mkdir -p "plugins/faber-article/skills/$skill_name"
    mv "$skill_file" "plugins/faber-article/skills/$skill_name/SKILL.md"
done
```

#### 4.2.2 FABER-DB Workflow Docs Relocation

**Current:** `plugins/faber-db/config/workflows/`
**Target:** `plugins/faber-db/docs/workflows/`

```bash
mkdir -p plugins/faber-db/docs/workflows/
mv plugins/faber-db/config/workflows/*.md plugins/faber-db/docs/workflows/
```

### 4.3 Phase 3: Cleanup (Priority: MEDIUM)

**Duration:** 0.5-1 day
**Objective:** Remove orphaned files and process archives

#### 4.3.1 Remove Temporary Files

```bash
# Archive to .archive/ first for safety
mkdir -p .archive/orphaned-files/
mv IMPLEMENTATION-NOTES-292.md .archive/orphaned-files/
mv TESTING-GUIDE-165.md .archive/orphaned-files/

# If confirmed unnecessary after review, delete
rm -rf .archive/orphaned-files/
```

#### 4.3.2 Process Archive Directories

**faber-cloud/.archive/ (248KB)**

Decision tree:
1. Review contents for historical value
2. If valuable: Document purpose in archive README
3. If obsolete: Remove after confirmation

**helm-cloud/.archive/ (8KB)**

Same process as above.

#### 4.3.3 Work Item File Migration

Move WORK-*.md files from specs/ to appropriate location:

**Option A: Separate work-items/ directory**
```bash
mkdir -p work-items/
mv specs/WORK-*.md work-items/
```

**Option B: Archive to .archive/**
```bash
mkdir -p .archive/work-items/
mv specs/WORK-*.md .archive/work-items/
```

**Recommendation:** Option A - preserves history without polluting specs directory

### 4.4 Phase 4: Organization (Priority: MEDIUM)

**Duration:** 1-2 days
**Objective:** Improve repository organization and discoverability

#### 4.4.1 Specs Directory README

Create comprehensive `specs/README.md`:

```markdown
# Specifications Directory

## Overview
This directory contains technical specifications for the Fractary Claude Plugins repository.

## Naming Convention
- Format: `SPEC-NNNNN-short-description.md`
- NNNNN: 5-digit zero-padded number
- Sequential numbering (no gaps expected, but gaps are acceptable)

## Categories
| Prefix | Category |
|--------|----------|
| SPEC-00001-00099 | Core FABER Framework |
| SPEC-00100-00199 | Primitive Plugins (work, repo, file) |
| SPEC-00200-00299 | Orchestrator Plugins (faber-cloud, faber-app) |
| SPEC-00300+ | Future/Miscellaneous |

## Status Definitions
| Status | Meaning |
|--------|---------|
| Draft | Under development |
| Review | Awaiting approval |
| Approved | Ready for implementation |
| Implemented | Complete |
| Deprecated | Superseded |

## Adding New Specs
1. Find next available number: `ls SPEC-*.md | tail -1`
2. Use template: `docs/templates/SPEC-TEMPLATE.md`
3. Include all required sections
```

#### 4.4.2 Migration Documentation Consolidation

Create unified migration guide:

```
docs/
├── MIGRATION-GUIDE.md          # Central migration overview
└── migrations/
    ├── faber-v1-to-v2.md       # Specific migration
    ├── codex-v1-to-v2.md
    ├── repo-v1-to-v2.md
    └── ...
```

**Central MIGRATION-GUIDE.md structure:**
1. Migration Overview
2. Version Compatibility Matrix
3. Plugin-Specific Migrations (links)
4. Common Migration Patterns
5. Troubleshooting

### 4.5 Phase 5: Standards Compliance (Priority: LOW)

**Duration:** 0.5 day
**Objective:** Ensure all skill files meet XML markup standards

#### 4.5.1 Add XML Markup

**Files to update:**
1. `plugins/faber-cloud/skills/cloud-common/SKILL.md`
2. `plugins/faber/skills/core/SKILL.md`

**Template to apply:**
```markdown
# [Skill Name]

<CONTEXT>
[Skill purpose and role]
</CONTEXT>

<CRITICAL_RULES>
1. [Rule 1]
2. [Rule 2]
</CRITICAL_RULES>

<INPUTS>
[Input specification]
</INPUTS>

<WORKFLOW>
## Step 1: [Name]
[Description]

## Step 2: [Name]
[Description]
</WORKFLOW>

<COMPLETION_CRITERIA>
[How to know skill is complete]
</COMPLETION_CRITERIA>

<OUTPUTS>
[Output specification]
</OUTPUTS>

<ERROR_HANDLING>
[Error handling approach]
</ERROR_HANDLING>
```

---

## 5. Documentation Templates

### 5.1 Plugin README Template

```markdown
# [Plugin Name]

> Brief one-line description

## Overview

[2-3 paragraphs describing the plugin purpose and capabilities]

## Quick Start

### Installation
[Installation steps]

### Basic Usage
[Simple example]

## Configuration

See [CONFIGURATION.md](docs/CONFIGURATION.md) for detailed setup.

## Commands

| Command | Description |
|---------|-------------|
| /plugin:command1 | Brief description |
| /plugin:command2 | Brief description |

See [COMMANDS.md](docs/COMMANDS.md) for full reference.

## Architecture

[High-level architecture diagram or description]

## Related Plugins

- [plugin-a](../plugin-a/) - Relationship
- [plugin-b](../plugin-b/) - Relationship
```

### 5.2 Command Documentation Template

```markdown
# /plugin:command-name

## Synopsis

\`\`\`
/plugin:command-name <required-arg> [optional-arg] [--flag]
\`\`\`

## Description

[What this command does]

## Arguments

| Argument | Type | Required | Description |
|----------|------|----------|-------------|
| required-arg | string | Yes | Description |
| optional-arg | string | No | Description |

## Flags

| Flag | Default | Description |
|------|---------|-------------|
| --flag | false | Description |

## Examples

### Basic usage
\`\`\`
/plugin:command-name "value"
\`\`\`

### With options
\`\`\`
/plugin:command-name "value" --flag
\`\`\`

## Related Commands

- [/plugin:related-command](./related-command.md)
```

### 5.3 SKILL.md Template

```markdown
# [Skill Name]

<CONTEXT>
You are the [skill name] for the [plugin] plugin. You [primary responsibility].

**Role**: [Role description]
**Scope**: [What this skill handles]
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS [rule 1]
2. NEVER [rule 2]
3. [Additional rules]
</CRITICAL_RULES>

<INPUTS>
```json
{
  "operation": "[operation type]",
  "parameters": {
    "param1": "[description]",
    "param2": "[description]"
  }
}
```
</INPUTS>

<WORKFLOW>
## Step 1: [Initialize]
[Description of step]

## Step 2: [Execute]
[Description of step]

## Step 3: [Finalize]
[Description of step]
</WORKFLOW>

<COMPLETION_CRITERIA>
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3
</COMPLETION_CRITERIA>

<OUTPUTS>
```json
{
  "status": "success|error",
  "result": {}
}
```
</OUTPUTS>

<ERROR_HANDLING>
| Error | Cause | Resolution |
|-------|-------|------------|
| ERROR_1 | Cause | How to fix |
</ERROR_HANDLING>

<DOCUMENTATION>
Output structured messages:
- Start: "[Skill] Starting: [operation]"
- End: "[Skill] Completed: [result summary]"
</DOCUMENTATION>
```

---

## 6. Validation Checklist

### 6.1 Per-Plugin Validation

For each plugin, verify:

- [ ] README.md exists at plugin root
- [ ] docs/ directory exists
- [ ] docs/CONFIGURATION.md exists (if configurable)
- [ ] All commands documented
- [ ] All skills documented with SKILL.md format
- [ ] All skills have XML markup
- [ ] All handlers documented (if multi-provider)

### 6.2 Repository-Level Validation

- [ ] No orphaned temporary files in root
- [ ] specs/ directory has comprehensive README
- [ ] Work item files moved out of specs/
- [ ] Archive directories processed
- [ ] Migration docs consolidated
- [ ] All 16 plugins pass per-plugin validation

### 6.3 Automated Validation Script

```bash
#!/bin/bash
# validate-documentation.sh

PLUGINS_DIR="plugins"
ERRORS=0

for plugin in "$PLUGINS_DIR"/*; do
    plugin_name=$(basename "$plugin")
    
    # Check README
    if [[ ! -f "$plugin/README.md" ]]; then
        echo "ERROR: $plugin_name missing README.md"
        ((ERRORS++))
    fi
    
    # Check docs directory
    if [[ ! -d "$plugin/docs" ]]; then
        echo "ERROR: $plugin_name missing docs/ directory"
        ((ERRORS++))
    fi
    
    # Check skills have SKILL.md
    if [[ -d "$plugin/skills" ]]; then
        for skill in "$plugin/skills"/*; do
            if [[ -d "$skill" && ! -f "$skill/SKILL.md" ]]; then
                echo "ERROR: $(basename "$skill") missing SKILL.md"
                ((ERRORS++))
            fi
        done
    fi
done

if [[ $ERRORS -eq 0 ]]; then
    echo "All validations passed!"
else
    echo "Total errors: $ERRORS"
    exit 1
fi
```

---

## 7. Implementation Timeline

| Phase | Duration | Start | End | Dependencies |
|-------|----------|-------|-----|--------------|
| Phase 1: Critical Docs | 3-5 days | Day 1 | Day 5 | None |
| Phase 2: Structural | 1-2 days | Day 6 | Day 7 | Phase 1 |
| Phase 3: Cleanup | 0.5-1 day | Day 8 | Day 8 | None (parallel) |
| Phase 4: Organization | 1-2 days | Day 9 | Day 10 | Phase 3 |
| Phase 5: Compliance | 0.5 day | Day 11 | Day 11 | None |
| **Total** | **~11 days** | - | - | - |

### 7.1 Parallel Execution Opportunities

- Phase 3 (Cleanup) can run parallel to Phase 2
- Different plugins in Phase 1 can be worked on in parallel
- Phase 5 can start after Phase 1 for individual plugins

**Optimized timeline with parallelization: ~7-8 days**

---

## 8. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Documentation becomes stale | Medium | High | Add doc validation to CI |
| Breaking existing workflows | Low | High | Review all changes before merge |
| Incomplete skill documentation | Medium | Medium | Use templates consistently |
| Resistance to structural changes | Low | Low | Document migration path |

---

## 9. Success Criteria

### 9.1 Quantitative

| Metric | Target |
|--------|--------|
| Plugins with complete docs/ | 16/16 (100%) |
| Commands with documentation | 100% |
| Skills with SKILL.md format | 100% |
| Skills with XML markup | 100% |
| Orphaned files | 0 |

### 9.2 Qualitative

- New contributors can onboard using documentation alone
- Each command has at least one working example
- Error scenarios are documented
- Configuration is fully documented for all handlers

---

## 10. Appendix

### 10.1 Complete Plugin Inventory

| Plugin | Commands | Skills | Agents | Handlers | Docs Status |
|--------|----------|--------|--------|----------|-------------|
| faber | 5 | 8 | 2 | - | Partial |
| faber-agent | 3 | 4 | 1 | - | Partial |
| faber-app | 0 | 0 | 0 | - | Stub |
| faber-article | 3 | 8 | 1 | - | Partial |
| faber-cloud | 8 | 12 | 2 | 2 | Complete |
| faber-db | 4 | 6 | 1 | - | Partial |
| work | 26 | 17 | 1 | 3 | Missing |
| repo | 12 | 10 | 1 | 3 | Partial |
| file | 4 | 7 | 1 | 3 | Missing |
| codex | 6 | 8 | 1 | - | Partial |
| logs | 4 | 5 | 1 | - | Partial |
| helm | 4 | 0 | 2 | - | Missing |
| helm-cloud | 5 | 6 | 1 | - | Partial |
| status | 1 | 2 | 0 | - | Missing |
| spec | 4 | 5 | 1 | - | Partial |
| docs | 0 | 0 | 0 | - | N/A |

### 10.2 File Count Summary

| Category | Count | Action |
|----------|-------|--------|
| Documentation files to create | ~100 | Phase 1-4 |
| Documentation files to update | ~50 | Phase 2, 5 |
| Files to restructure | 8 | Phase 2 |
| Files to remove | 2 | Phase 3 |
| Files to relocate | ~66 | Phase 3 |
| **Total files affected** | **~226** | - |

### 10.3 Reference Documents

- [FRACTARY-PLUGIN-STANDARDS.md](../docs/standards/FRACTARY-PLUGIN-STANDARDS.md)
- [CLAUDE.md](../CLAUDE.md)
- [Existing faber-cloud documentation](../plugins/faber-cloud/docs/) (reference implementation)

---

## Changelog

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-09 | Claude (Opus 4.5) | Initial specification |

