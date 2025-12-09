# Technical Specification: Documentation Audit and Cleanup

**Issue:** #271
**Title:** Update documentation and cleanup old files in all plugins
**Created:** 2025-12-09

## Problem Statement

The Fractary Claude Plugins repository has undergone significant evolution with major restructuring and feature additions across multiple plugins. Documentation may be outdated, obsolete files may exist, and file organization may not reflect current architecture.

**Goals:**
1. Conduct comprehensive audit of all plugin documentation
2. Identify and update outdated documentation
3. Identify obsolete files and scripts
4. Remove no-longer-used files
5. Ensure documentation accuracy across all plugins

## Scope

### Plugins to Audit
- faber/ - Core FABER workflow orchestration
- faber-app/ - Application development workflows
- faber-cloud/ - Cloud infrastructure workflows
- work/ - Work tracking primitive
- repo/ - Source control primitive
- file/ - File storage primitive
- codex/ - Memory and knowledge management
- status/ - Custom status line display

### Documentation to Review
- README.md and documentation files
- SKILL.md files in each skill directory
- Agent documentation files
- Configuration templates and examples
- API documentation and technical specs

### Files to Assess for Removal
- Deprecated workflow definitions
- Old script versions
- Example files no longer relevant
- Template files replaced by newer versions
- Configuration examples from previous versions

## Implementation Approach

### Phase 1: Analysis (Build Phase)
1. Directory tree analysis of each plugin
2. Documentation completeness check
   - Check for SKILL.md in all skills
   - Verify agent documentation
   - Check for command documentation
3. Script audit
   - Identify deprecated scripts
   - Check for orphaned scripts
   - Verify script relevance to current workflows
4. Configuration audit
   - Review config templates
   - Assess example files
   - Check for versioning mismatches

### Phase 2: Documentation Update (Build Phase)
1. Update outdated references in documentation
2. Add missing documentation
3. Fix incorrect architectural descriptions
4. Update configuration examples
5. Document recent changes

### Phase 3: Cleanup (Build Phase)
1. Create list of files identified for removal
2. Remove obsolete files with clear commit messages
3. Remove deprecated script versions
4. Clean up outdated configuration examples

### Phase 4: Verification (Evaluate Phase)
1. Validate all remaining documentation is accurate
2. Verify no critical files were accidentally removed
3. Check that documentation matches implementation
4. Ensure configuration examples are functional

## Expected Outcomes

### Deliverables
1. Updated documentation across all plugins
2. Cleaned codebase with obsolete files removed
3. Clear git history with documented removals
4. Pull request with all changes for review

### Artifacts
- Specification file (this document)
- Comprehensive audit report
- List of files removed with justification
- Updated documentation files
- Git commits with clear messaging

## Success Criteria

- [ ] All plugin documentation reviewed
- [ ] Outdated information updated or removed
- [ ] Obsolete files identified and removed
- [ ] Documentation matches current implementation
- [ ] PR created with all changes
- [ ] Passing code review

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Accidentally remove still-used files | Verify usage before removal, test after removal |
| Break plugin functionality | Create comprehensive list before removal, validate after |
| Miss outdated documentation | Systematic review of all files, cross-reference with code |
