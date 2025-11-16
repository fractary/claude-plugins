---
spec_id: spec-00125-refactor-logs-plugin-with-log-types
issue_number: 125
issue_url: https://github.com/fractary/claude-plugins/issues/125
title: Refactor Logs Plugin with Log Types Like Docs Plugin
type: refactor
status: draft
created: 2025-01-16
author: Claude Code
validated: false
---

# Specification: Refactor Logs Plugin with Log Types Like Docs Plugin

**Issue**: [#125](https://github.com/fractary/claude-plugins/issues/125)
**Type**: Refactor
**Status**: Draft
**Created**: 2025-01-16

## Summary

Transform the logs plugin from its current architecture to match the docs plugin v2.0 pattern: operation-specific skills with data-driven type context. This refactoring will eliminate code duplication, improve extensibility (adding new log types becomes trivial), and establish consistent architectural patterns across the fractary plugin ecosystem.

The docs plugin recently underwent a successful v2.0 refactoring that:
- Reduced code duplication from 93% to <7%
- Reduced total codebase by 64% (~7,000 → ~2,500 lines)
- Replaced 14 type-specific skills with 4 universal operation skills
- Introduced type context system (5 files per type in `types/{type}/`)
- Split coordination from agent to dedicated skills (manager-skill, director-skill)

We will replicate this pattern in the logs plugin with 8 log types: session, build, deployment, debug, test, audit, operational, _untyped.

## Requirements

### Functional Requirements

- **Type Context System**: Create `types/{log_type}/` directories with 5 files each (schema.json, template.md, standards.md, validation-rules.md, retention-config.json) for 8 log types
- **Operation-Specific Skills**: Create universal skills that work with ANY log type:
  - log-writer: Create/append logs (replaces type-specific capture logic)
  - log-classifier: Auto-detect log type from path or content
  - log-validator: Validate logs against type schema
  - log-lister: List and filter logs with multiple output formats
- **Coordination Layer**: Split coordination into dedicated skills:
  - log-manager-skill: Single-log workflow orchestration (capture → validate → archive)
  - log-director-skill: Multi-log workflows with parallel execution
- **Type-Agnostic Refactoring**: Update existing skills to load type context dynamically:
  - log-capturer: Use log-writer for file creation, focus on streaming coordination
  - log-archiver: Load retention-config.json per type (7d sessions, 3d builds, 90d audits)
  - log-searcher: Support type-based filtering and field search
  - log-analyzer: Load type-specific standards for analysis patterns
  - log-summarizer: Use type templates for summary structure
- **Streamlined Agent**: Reduce log-manager agent from 500+ lines to ~200 lines (routing wrapper only)
- **Command Updates**: Update all 11 commands to route appropriately (single-log → manager-skill, multi-log → director-skill)
- **Backward Compatibility**: Existing logs must continue to work (frontmatter migration: `type:` → `log_type:`)

### Non-Functional Requirements

- **Code Reduction**: Target 15-18% reduction in total codebase (~800 lines)
- **Maintainability**: Changes should affect 1-2 places instead of 6+ skills
- **Extensibility**: Adding new log type = 5 data files (not skill changes)
- **Consistency**: Match docs plugin architecture exactly for ecosystem coherence
- **Performance**: No degradation in log capture, archive, or search operations
- **Testing**: All 8 log types tested with new architecture
- **Documentation**: Complete migration guide and architectural documentation

## Technical Approach

### Phase 1: Type Context System (40 files)
Create `types/{log_type}/` directories for 8 log types × 5 files each:

**Log Types**: session, build, deployment, debug, test, audit, operational, _untyped

**Files per type**:
1. **schema.json** - JSON Schema Draft 7 for frontmatter validation
   - Required fields: log_type, title, status, date, session_id/build_id/etc.
   - Type-specific fields (session: issue_number, conversation_id; build: build_id, exit_code)
2. **template.md** - Mustache template for log structure
   - Frontmatter template
   - Content sections (metadata, summary, entries/events, diagnostics)
3. **standards.md** - Logging conventions
   - What to capture (session: full conversation; build: stdout/stderr + metadata)
   - Redaction rules (PII, secrets, sensitive paths)
   - Naming conventions
4. **validation-rules.md** - Quality checks
   - Required sections
   - Format validation
   - Completeness checks
5. **retention-config.json** - Type-specific retention policies
   ```json
   {
     "local_retention_days": 7,
     "cloud_retention_policy": "forever",
     "priority": "high",
     "auto_archive": true,
     "compression": true
   }
   ```

**Example retention policies**:
- session: 7 days local, forever cloud, high priority
- build: 3 days local, 30 days cloud, medium priority
- deployment: 30 days local, forever cloud, critical priority
- debug: 7 days local, 30 days cloud, medium priority
- test: 3 days local, 7 days cloud, low priority
- audit: 90 days local, forever cloud, critical priority
- operational: 14 days local, 90 days cloud, high priority
- _untyped: 1 day local, 7 days cloud, low priority

### Phase 2: Operation Skills (4 new skills)

#### log-writer Skill
**Location**: `skills/log-writer/`
- **SKILL.md**: Universal log creation (loads type context from `types/{log_type}/`)
- **scripts/write-log.sh**: Create log file with frontmatter and initial structure
- **scripts/render-template.sh**: Mustache renderer for template.md
- **scripts/append-entry.sh**: Append entry to existing log (for streaming sessions)

**Critical Rules**:
- NEVER hardcode type-specific logic
- ALWAYS load type context from `types/{log_type}/`
- Support both create (new log) and append (add to existing)
- Generate frontmatter from schema.json

#### log-classifier Skill
**Location**: `skills/log-classifier/`
- **SKILL.md**: Auto-detect log type from path or content
- **scripts/classify-by-path.sh**: Detect from directory pattern
  - `/logs/sessions/` → session
  - `/logs/builds/` → build
  - `/logs/deployments/` → deployment
- **scripts/classify-by-content.sh**: Detect from frontmatter `log_type` field

**Fallback**: `_untyped` if unable to determine

#### log-validator Skill
**Location**: `skills/log-validator/`
- **SKILL.md**: Validate logs against type schema and rules
- **scripts/validate-frontmatter.sh**: JSON Schema validation against `types/{log_type}/schema.json`
- **scripts/validate-retention.sh**: Check retention compliance against `types/{log_type}/retention-config.json`

**Validation checks**:
- Frontmatter structure (required fields, type constraints)
- Content structure (required sections from standards.md)
- Retention rules (expired vs active)

#### log-lister Skill
**Location**: `skills/log-lister/`
- **SKILL.md**: List and filter logs with multiple output formats
- **scripts/list-logs.sh**: Scan directories, extract frontmatter, filter by type/date/status
- **scripts/format-output.sh**: Format as table (ASCII), JSON, or markdown

**Filters**: `--log-type <type>`, `--status <status>`, `--date-range <start> <end>`, `--limit <n>`

### Phase 3: Coordination Skills (2 new skills)

#### log-manager-skill
**Location**: `skills/log-manager-skill/`
- **SKILL.md**: Single-log workflow orchestration
- **scripts/coordinate-capture.sh**: capture → validate → archive pipeline
  1. Classify log type (if not provided)
  2. Create log file via log-writer
  3. Stream capture (delegate to log-capturer for session streaming)
  4. Validate via log-validator
  5. Archive if auto_archive enabled
- **scripts/coordinate-archive.sh**: classify → validate → upload → index
  1. Classify log type
  2. Validate via log-validator
  3. Upload to cloud storage (via fractary-file plugin)
  4. Update archive index
- **scripts/coordinate-cleanup.sh**: validate retention → delete → update index
  1. Load retention config for type
  2. Check expiration
  3. Delete expired logs
  4. Update archive index

**Operations**: capture, archive, cleanup (single log at a time)

#### log-director-skill
**Location**: `skills/log-director-skill/`
- **SKILL.md**: Multi-log workflows with parallel execution
- **scripts/batch-archive.sh**: Archive multiple logs in parallel
  - File locking with `flock` for concurrent safety
  - Configurable max concurrency (default: 10)
  - Aggregated result reporting
- **scripts/batch-cleanup.sh**: Cleanup multiple expired logs
  - Load retention policies per type
  - Parallel deletion with locking
- **scripts/audit-logs.sh**: Generate audit report across all logs
  - Count by type and status
  - Identify retention violations
  - Detect missing `log_type` fields
  - Report storage usage

**Operations**: batch-archive, batch-cleanup, audit

### Phase 4: Refactor Existing Skills (5 skills)

#### log-capturer
**Changes**:
- Remove hardcoded session creation logic
- Delegate to log-writer skill for file creation
- Focus on streaming coordination (real-time capture from Claude Code)
- Load `types/session/` context dynamically
- Support other log types (build, deployment, debug) via log-writer

#### log-archiver
**Changes**:
- Load `types/{log_type}/retention-config.json` for type-specific policies
- Use log-classifier to detect type if not provided
- Remove hardcoded 30-day retention logic
- Support per-type retention (session: 7d, build: 3d, audit: 90d)
- Respect `auto_archive` flag from retention config

#### log-searcher
**Changes**:
- Load type schemas for field-based search
- Support `--log-type <type>` filtering
- Use log-classifier for untyped logs
- Search across multiple types with aggregated results

#### log-analyzer
**Changes**:
- Load `types/{log_type}/standards.md` for type-specific analysis
- Different analysis patterns per type:
  - session: conversation flow, decisions, context switches
  - build: error patterns, warnings, performance metrics
  - deployment: success rate, rollback triggers, resource usage
  - audit: compliance violations, security events

#### log-summarizer
**Changes**:
- Load `types/{log_type}/template.md` for summary structure
- Type-specific summarization prompts:
  - session: key decisions, action items, outcomes
  - build: errors, warnings, build time, artifacts
  - deployment: status, changes deployed, issues
- Use AI with type-aware prompt engineering

### Phase 5: Update log-manager Agent
**Changes**:
- Streamline from 500+ lines to ~200 lines
- Remove embedded workflow logic (move to log-manager-skill)
- Add routing logic:
  ```
  Single-log operations → log-manager-skill
  Multi-log operations → log-director-skill
  ```
- Keep agent as thin orchestrator (like docs-manager agent)

**Routing table**:
```
capture <issue> → log-manager-skill (coordinate-capture)
archive <path> → log-manager-skill (coordinate-archive)
archive <pattern> --batch → log-director-skill (batch-archive)
cleanup → log-director-skill (batch-cleanup)
audit → log-director-skill (audit-logs)
```

### Phase 6: Update Commands (11 commands)

**Routing pattern**:
```
/logs:capture → log-manager agent → log-manager-skill → log-writer
/logs:archive → log-manager agent → log-manager-skill/log-director-skill
/logs:search → log-manager agent → log-searcher (direct)
/logs:audit → log-manager agent → log-director-skill
```

**Commands to update**:
1. `capture.md` - Route to log-manager-skill (single session)
2. `stop.md` - Route to log-manager-skill
3. `log.md` - Route to log-lister skill (direct)
4. `read.md` - Direct operation (no changes)
5. `archive.md` - Route to manager-skill (single) or director-skill (batch with `--batch` flag)
6. `cleanup.md` - Route to director-skill (batch operation)
7. `search.md` - Route to log-searcher (direct)
8. `analyze.md` - Route to log-analyzer (direct)
9. `summarize.md` - Route to log-summarizer (direct)
10. `audit.md` - Route to director-skill
11. `init.md` - No changes (configuration)

### Phase 7: Shared Scripts Enhancement

#### Create type-context-loader.sh
**Location**: `skills/_shared/lib/type-context-loader.sh`
- Load all 5 type context files
- Validate type directory exists
- Provide context bundle to skills
- Cache loaded contexts for performance

#### Enhance archive-index.sh
**Location**: `skills/_shared/lib/archive-index.sh`
- Add type-aware indexing (include `log_type` field in index)
- Support filtering by type
- Load retention config per type for expiration calculations

#### Create retention-policy.sh
**Location**: `skills/_shared/lib/retention-policy.sh`
- Load `types/{log_type}/retention-config.json`
- Calculate expiration based on type policy
- Support priority levels (critical, high, medium, low)
- Return retention decisions (keep, archive, delete)

### Phase 8: Testing & Documentation

#### Testing
- Test all 8 log types with new architecture
- Test type classification (path-based and content-based)
- Test per-type retention policies (7d sessions vs 90d audits)
- Test batch operations with parallel execution
- Test backward compatibility (existing logs with `type:` field)
- Integration tests with fractary-file plugin (cloud archival)

#### Documentation
- **README.md**: Update with v2.0 architecture overview, examples
- **MIGRATION.md**: Guide for migrating from v1.x (frontmatter field change)
- **ADR-001-operation-specific-architecture.md**: Document refactoring decision
- **CONTRIBUTING.md**: How to add new log types (5-file process)
- **CHANGELOG.md**: v2.0 release notes with breaking changes

### Phase 9: Cleanup & Metadata

#### Delete Deprecated Files
- Review for type-specific logic to remove (minimal, logs already operation-based)
- Clean up unused scripts

#### Update Metadata
- `plugin.json`: Version 2.0.0
- Description: "Type-agnostic log management with operation-specific skills and data-driven type context"

## Files to Modify

### New Files to Create (60+ files)

**Type Context (40 files)**:
- `types/session/` (5 files: schema.json, template.md, standards.md, validation-rules.md, retention-config.json)
- `types/build/` (5 files)
- `types/deployment/` (5 files)
- `types/debug/` (5 files)
- `types/test/` (5 files)
- `types/audit/` (5 files)
- `types/operational/` (5 files)
- `types/_untyped/` (5 files)

**New Skills (20+ files)**:
- `skills/log-writer/` (SKILL.md + 3 scripts)
- `skills/log-classifier/` (SKILL.md + 2 scripts)
- `skills/log-validator/` (SKILL.md + 2 scripts)
- `skills/log-lister/` (SKILL.md + 2 scripts)
- `skills/log-manager-skill/` (SKILL.md + 3 scripts)
- `skills/log-director-skill/` (SKILL.md + 3 scripts)
- `skills/_shared/lib/type-context-loader.sh`
- `skills/_shared/lib/retention-policy.sh`

**Documentation (4 files)**:
- `docs/ADR-001-operation-specific-architecture.md`
- `MIGRATION.md`
- `CONTRIBUTING.md`
- `CHANGELOG.md`

### Files to Modify (20+ files)

**Existing Skills (5 skills)**:
- `skills/log-capturer/SKILL.md` - Refactor to use log-writer, load type context
- `skills/log-archiver/SKILL.md` - Add type-specific retention, use log-classifier
- `skills/log-searcher/SKILL.md` - Add type filtering, schema-based field search
- `skills/log-analyzer/SKILL.md` - Load type standards, type-specific analysis
- `skills/log-summarizer/SKILL.md` - Load type templates, type-aware prompts

**Agent (1 file)**:
- `agents/log-manager.md` - Streamline to routing wrapper (~500 → ~200 lines)

**Commands (11 files)**:
- `commands/capture.md` - Update routing to log-manager-skill
- `commands/stop.md` - Update routing
- `commands/log.md` - Route to log-lister
- `commands/read.md` - No changes
- `commands/archive.md` - Add batch routing to director-skill
- `commands/cleanup.md` - Route to director-skill
- `commands/search.md` - Update for type filtering
- `commands/analyze.md` - Update for type-specific analysis
- `commands/summarize.md` - Update for type templates
- `commands/audit.md` - Route to director-skill
- `commands/init.md` - No changes

**Shared Scripts (1 file)**:
- `skills/_shared/lib/archive-index.sh` - Add type-aware indexing

**Metadata (2 files)**:
- `.claude-plugin/plugin.json` - Version 2.0.0, updated description
- `README.md` - v2.0 architecture overview

## Acceptance Criteria

- [ ] All 8 log types have complete type context (5 files each, 40 files total)
- [ ] 4 new operation skills created (log-writer, log-classifier, log-validator, log-lister)
- [ ] 2 coordination skills created (log-manager-skill, log-director-skill)
- [ ] 5 existing skills refactored to be type-agnostic (load type context dynamically)
- [ ] log-manager agent streamlined to ~200 lines (routing wrapper only)
- [ ] All 11 commands updated with correct routing
- [ ] 3 shared scripts created/enhanced (type-context-loader, retention-policy, archive-index)
- [ ] All 8 log types tested (create, validate, archive, search, analyze)
- [ ] Type classification works (path-based and content-based)
- [ ] Per-type retention policies work (7d sessions, 3d builds, 90d audits)
- [ ] Batch operations work with parallel execution and file locking
- [ ] Backward compatibility verified (existing logs with `type:` field work)
- [ ] Documentation complete (README, ADR-001, MIGRATION, CONTRIBUTING, CHANGELOG)
- [ ] Code reduction achieved (target: 15-18% reduction, ~800 lines)
- [ ] No performance degradation in capture, archive, or search operations
- [ ] Plugin.json updated to v2.0.0
- [ ] All tests pass

## Testing Strategy

### Unit Testing
- Test each operation skill independently with mock type context
- Test type context loading from directories
- Test retention policy calculations per type
- Test classification logic (path and content)
- Test template rendering (Mustache variables)

### Integration Testing
- Test complete workflows:
  - capture session → validate → auto-archive → verify in cloud
  - create build log → archive with 3-day retention → verify cleanup
  - create audit log → archive with 90-day retention → verify long-term storage
- Test batch operations:
  - Archive 10 logs in parallel (verify file locking, no corruption)
  - Cleanup expired logs across all types (verify retention policies respected)
- Test backward compatibility:
  - Existing logs with `type: session` still work
  - Migration path from `type:` to `log_type:` documented and tested

### Regression Testing
- Verify existing functionality not broken:
  - Session capture still works (streaming, real-time)
  - Search still finds logs (local + cloud)
  - Summarization still generates AI summaries
  - Archive index still updated correctly
- Performance testing:
  - Capture performance: no degradation
  - Archive performance: no degradation (parallel may improve)
  - Search performance: no degradation

### Type Coverage Testing
Test all 8 log types:
1. **session**: Create session log, validate, archive (7-day retention), search
2. **build**: Create build log, validate, archive (3-day retention), analyze errors
3. **deployment**: Create deployment log, validate, archive (forever), audit
4. **debug**: Create debug log, validate, archive (7-day retention), analyze
5. **test**: Create test log, validate, archive (3-day retention), summarize
6. **audit**: Create audit log, validate, archive (90-day retention), compliance check
7. **operational**: Create operational log, validate, archive (14-day retention), monitor
8. **_untyped**: Create untyped log, classify as _untyped, archive (1-day retention)

## Dependencies

- **fractary-file plugin**: For cloud storage operations (R2, S3, local)
- **fractary-work plugin** (optional): For linking logs to work items (issues)
- **docs plugin v2.0**: Reference implementation for architecture patterns
- **jq**: For JSON processing in scripts
- **flock**: For file locking in parallel operations
- **mustache** or bash-based renderer: For template rendering

## Risks

- **Risk**: Type context loading adds complexity to skills
  - **Mitigation**: Create shared type-context-loader.sh library, standardize loading pattern, comprehensive error handling
- **Risk**: Breaking changes disrupt existing workflows
  - **Mitigation**: Frontmatter migration guide, backward compatibility layer for `type:` field, clear CHANGELOG with migration steps
- **Risk**: Performance degradation from dynamic type loading
  - **Mitigation**: Cache loaded type contexts, type context files are small (~1-5KB each), load once per operation
- **Risk**: Parallel batch operations cause file corruption
  - **Mitigation**: Use flock for file locking, test with concurrent operations, verify no data loss
- **Risk**: Retention policies incorrectly delete logs
  - **Mitigation**: Dry-run mode for cleanup, comprehensive testing of retention calculations, priority-based safeguards (critical logs never auto-delete)
- **Risk**: Template auto-detection fails for some log types
  - **Mitigation**: Explicit type specification via `--log-type` flag, fallback to _untyped, clear error messages
- **Risk**: Large refactoring introduces regressions
  - **Mitigation**: Comprehensive testing (unit, integration, regression), phased rollout (create new skills before deleting old), feature flags for gradual migration

## Implementation Notes

### Breaking Changes (v1.x → v2.0)

**Frontmatter Field Change**:
```yaml
# Before (v1.x)
type: session

# After (v2.0)
log_type: session
```

**Migration Path**:
- Existing logs with `type:` field will be auto-migrated on first read
- log-classifier will detect and update frontmatter
- MIGRATION.md provides manual migration script for bulk updates

**Retention Configuration**:
- Before: Single policy (30 days local, configurable cloud)
- After: Per-type policies in `types/{log_type}/retention-config.json`
- Migration: Existing config becomes default for _untyped type

**Commands (No Breaking Changes)**:
- All commands remain the same (`/logs:capture`, `/logs:archive`, etc.)
- New flags added for type-specific operations (`--log-type`, `--batch`)

### Implementation Phases

**Recommended approach**: Incremental implementation
1. **Phase 1-2** (Type context + Operation skills): Foundation, no breaking changes
2. **Phase 3** (Coordination skills): New layer, no impact on existing
3. **Phase 4-6** (Refactor + Agent + Commands): Gradual migration, test thoroughly
4. **Phase 7-9** (Enhancement + Testing + Cleanup): Finalize and validate

**Estimated Effort**: 8-10 hours for complete implementation
- Type context creation: 2 hours (40 files, templated)
- New skills: 3 hours (6 skills with scripts)
- Refactoring: 2 hours (5 skills + agent + commands)
- Testing: 2 hours (all types, integration, regression)
- Documentation: 1 hour (ADR, MIGRATION, README, CHANGELOG)

### Feature Flags (Optional)

Consider feature flags for gradual rollout:
```json
{
  "feature_flags": {
    "use_type_context": true,
    "use_coordination_skills": true,
    "per_type_retention": true,
    "parallel_batch": true
  }
}
```

Allows testing new architecture alongside old until confidence is high.

### Success Metrics

Post-implementation validation:
- **Code reduction**: Measure lines of code before/after (target: -15-18%)
- **Duplication reduction**: Measure duplicated code blocks (target: <10%)
- **Extensibility**: Time to add new log type (target: <30 minutes for 5 files)
- **Performance**: Capture/archive/search latency (target: no degradation)
- **Adoption**: All 8 log types in use, no fallback to old patterns
- **Maintainability**: Time to make cross-type changes (target: 1-2 files vs 6+)

### References

- **Docs Plugin v2.0**: `/plugins/docs/` (reference implementation)
- **Docs Plugin PR**: Commit `1305da0` (architecture refactor)
- **Docs Plugin ADR**: `/plugins/docs/docs/ADR-001-operation-specific-architecture.md`
- **Docs Plugin README**: `/plugins/docs/README.md` (architecture overview)
- **Fractary Plugin Standards**: `/docs/standards/FRACTARY-PLUGIN-STANDARDS.md`
- **Issue #125**: https://github.com/fractary/claude-plugins/issues/125
