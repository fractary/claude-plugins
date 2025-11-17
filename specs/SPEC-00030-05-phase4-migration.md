# Phase 4: Migration & Optimization

**Specification ID:** SPEC-00030-05
**Phase:** 4 of 4
**Parent Spec:** [SPEC-00030-01](./SPEC-00030-01-codex-knowledge-retrieval-architecture.md)
**Previous Phase:** [SPEC-00030-04](./SPEC-00030-04-phase3-mcp-integration.md)
**Version:** 1.0.0
**Status:** Planning
**Duration:** 2-3 weeks

---

## Table of Contents

1. [Phase Overview](#phase-overview)
2. [Migration Strategy](#migration-strategy)
3. [Optimization Targets](#optimization-targets)
4. [Implementation Tasks](#implementation-tasks)
5. [Rollout Plan](#rollout-plan)

---

## Phase Overview

### Purpose

Complete the transition from push-based sync (SPEC-00012) to pull-based retrieval (SPEC-00030), optimize performance based on real-world usage, and provide comprehensive migration support for existing projects.

### Scope

**In Scope:**
- Migration guide and tools
- Backward compatibility layer
- Performance optimization
- Documentation updates
- Deprecation timeline
- Monitoring and metrics

**Out of Scope:**
- New features (future phases)
- Vector store integration (future)
- Advanced semantic search (future)

### Dependencies

- **Phases 1-3**: All previous phases must be complete
- **SPEC-00012**: Understanding of existing sync system
- **Real-world usage data**: From Phases 1-3 adoption

---

## Migration Strategy

### Coexistence Model

**Timeline**: 6-12 months of parallel operation

```
Month 0-3: Phase 1-3 Implementation + Initial Adoption
  ├── Both systems run in parallel
  ├── SPEC-00012 sync continues (publish to codex)
  ├── SPEC-00030 retrieval begins (fetch from codex)
  └── Early adopters test new system

Month 3-6: Adoption Period
  ├── Disable --from-codex sync (stop pull-sync)
  ├── Rely on @codex/ retrieval (cache-based)
  ├── Clean up old synced files manually
  └── Gather feedback and optimize

Month 6-9: Full Migration
  ├── Rename /codex:sync-project → /codex:publish
  ├── Remove --from-codex, --bidirectional options
  ├── Update all documentation
  └── Announce deprecation timeline

Month 9-12: Deprecation Complete
  ├── Remove old sync code (workflows, scripts)
  ├── Clean up obsolete configuration
  ├── Archive SPEC-00012 as legacy
  └── SPEC-00030 fully operational
```

### Migration Phases

#### Stage 1: Publish-Only (Months 0-3)

**What Changes:**
- Projects continue: `/codex:sync-project --to-codex` (publish)
- Projects start using: `@codex/` references (retrieval)
- Bidirectional sync deprecated but still works

**User Impact:**
- No breaking changes
- Opt-in to new retrieval
- Old sync continues to work

**Actions:**
```bash
# Keep doing (publishing)
/codex:sync-project --to-codex

# Start doing (retrieving)
/codex:fetch @codex/other-project/docs/api.md
```

#### Stage 2: Retrieval Adoption (Months 3-6)

**What Changes:**
- Projects disable: `--from-codex` sync (no more pull-sync)
- Projects rely on: `@codex/` retrieval (cache-based)
- Old synced files cleaned up manually

**User Impact:**
- Stop receiving automatic syncs from codex
- Must explicitly fetch with `@codex/` or prefetch
- Old `.fractary/codex-*` folders can be deleted

**Actions:**
```bash
# Stop doing
/codex:sync-project --from-codex  # ❌ Deprecated

# Start doing
/codex:cache-prefetch             # Pre-fetch all references
@codex/project/path references    # On-demand retrieval
```

**Migration Script**:
```bash
# cleanup-old-sync.sh
#!/usr/bin/env bash
# Remove old synced files from SPEC-0012

echo "Cleaning up old codex sync files..."

# Remove old sync directories
if [ -d ".fractary/codex" ]; then
  echo "Removing .fractary/codex/"
  rm -rf ".fractary/codex"
fi

# Remove old config files
if [ -f ".fractary/codex-sync.json" ]; then
  echo "Removing old config: .fractary/codex-sync.json"
  rm ".fractary/codex-sync.json"
fi

echo "✅ Cleanup complete"
echo "💡 Tip: Run /codex:cache-prefetch to populate new cache"
```

#### Stage 3: Full Migration (Months 6-9)

**What Changes:**
- Rename: `/codex:sync-project` → `/codex:publish`
- Remove: `--from-codex`, `--bidirectional` options
- Keep: Cache management commands
- Update: All documentation

**User Impact:**
- Command name changes (alias provided for transition)
- Simpler interface (only publish)
- Clearer semantics

**Actions:**
```bash
# Old way (deprecated but aliased)
/codex:sync-project --to-codex

# New way
/codex:publish
```

**Alias Configuration** (temporary):
```json
{
  "commandAliases": {
    "codex:sync-project --to-codex": "codex:publish"
  }
}
```

#### Stage 4: Deprecation Complete (Months 9-12)

**What Changes:**
- Remove old sync code (workflows, scripts)
- Clean up obsolete configuration
- Archive SPEC-00012 as legacy
- SPEC-00030 fully operational

**User Impact:**
- Old commands no longer work
- Must use new retrieval system
- Full benefits of new architecture

---

## Optimization Targets

### 1. Cache Performance

**Baseline (Phase 1)**:
- Cache hit: 50-100ms
- Cache miss: 1-2s
- Index operations: 5-10ms

**Target (Phase 4)**:
- Cache hit: 10-50ms (2-5x faster)
- Cache miss: 500ms-1s (2x faster)
- Index operations: 1-5ms (2x faster)

**Optimizations:**
1. **In-memory index cache**: Load .cache-index.json into memory
2. **Parallel fetching**: Fetch multiple docs simultaneously
3. **Compression**: Compress large cached documents
4. **Index sharding**: Split index by source for faster lookups

### 2. Reference Resolution

**Baseline (Phase 1)**:
- Parse reference: 5ms
- Validate format: 2ms
- Resolve to path: 3ms

**Target (Phase 4)**:
- Parse reference: 1ms (5x faster)
- Validate format: 0.5ms (4x faster)
- Resolve to path: 0.5ms (6x faster)

**Optimizations:**
1. **Compiled regex**: Pre-compile reference regex
2. **LRU cache**: Cache recent resolutions
3. **Path normalization**: Optimize path operations

### 3. Permission Checking

**Baseline (Phase 2)**:
- Parse frontmatter: 10-20ms
- Check permissions: 5-10ms
- Pattern matching: 5ms

**Target (Phase 4)**:
- Parse frontmatter: 2-5ms (4x faster)
- Check permissions: 1-2ms (5x faster)
- Pattern matching: 1ms (5x faster)

**Optimizations:**
1. **Frontmatter cache**: Cache parsed frontmatter
2. **Permission cache**: Cache permission decisions (TTL: 1 hour)
3. **Optimized pattern matching**: Use compiled regex

### 4. MCP Server Performance

**Baseline (Phase 3)**:
- Resource list: 100-200ms
- Resource read: 50-100ms
- Subscription: 10ms

**Target (Phase 4)**:
- Resource list: 20-50ms (4-5x faster)
- Resource read: 10-20ms (5x faster)
- Subscription: 2ms (5x faster)

**Optimizations:**
1. **Resource caching**: Cache resource list in memory
2. **Lazy loading**: Only load resources on-demand
3. **Binary protocol**: Use MessagePack for faster serialization
4. **Connection pooling**: Reuse connections

### 5. Context7 Integration

**Baseline (Phase 3)**:
- First query: 2-3s (API call)
- Cached query: 50-100ms
- Auto-caching: 50ms overhead

**Target (Phase 4)**:
- First query: 1-2s (optimized)
- Cached query: 10-20ms (5x faster)
- Auto-caching: 10ms overhead (5x faster)

**Optimizations:**
1. **Predictive caching**: Pre-fetch related docs
2. **Background refresh**: Refresh stale cache in background
3. **Batch queries**: Query multiple libraries at once
4. **Smart prefetch**: Analyze project deps, prefetch relevant docs

---

## Implementation Tasks

### Task 1: Migration Tooling (3 days)

**Subtasks:**
1. Create cleanup-old-sync.sh script
2. Create migration-checker.sh script (verify state)
3. Create prefetch-helper.sh (scan & prefetch)
4. Test migration scripts

**Acceptance Criteria:**
- Scripts work correctly
- Safe (no data loss)
- Clear output and logging

### Task 2: Backward Compatibility (2 days)

**Subtasks:**
1. Add command aliases
2. Add deprecation warnings
3. Maintain old config support (read-only)
4. Test backward compatibility

**Acceptance Criteria:**
- Old commands work with warnings
- Old configs still read
- Clear migration path shown

### Task 3: Performance Optimization (5 days)

**Subtasks:**
1. Implement in-memory index cache
2. Add compression for large docs
3. Optimize reference resolution
4. Optimize permission checking
5. Benchmark all changes

**Acceptance Criteria:**
- All optimization targets met
- No regressions
- Benchmarks documented

### Task 4: MCP Server Optimization (3 days)

**Subtasks:**
1. Implement resource caching
2. Optimize serialization
3. Add connection pooling
4. Benchmark MCP performance

**Acceptance Criteria:**
- MCP performance targets met
- Reduced CPU/memory usage
- Scales to 1000+ resources

### Task 5: Monitoring & Metrics (2 days)

**Subtasks:**
1. Add performance metrics logging
2. Add cache hit/miss tracking
3. Add fetch time tracking
4. Create metrics dashboard (simple)

**Acceptance Criteria:**
- Metrics logged correctly
- Can analyze performance
- Identify bottlenecks

### Task 6: Documentation Updates (3 days)

**Subtasks:**
1. Write migration guide
2. Update all command documentation
3. Update CLAUDE.md
4. Create troubleshooting guide

**Acceptance Criteria:**
- Migration guide complete
- All docs updated
- Troubleshooting covers common issues

### Task 7: Testing & Validation (3 days)

**Subtasks:**
1. Test migration path (Stage 1→4)
2. Performance regression testing
3. Load testing (1000+ docs)
4. User acceptance testing

**Acceptance Criteria:**
- Migration works smoothly
- No performance regressions
- Handles large scales
- Users can migrate successfully

### Task 8: Rollout Support (2 days)

**Subtasks:**
1. Create rollout checklist
2. Prepare announcement
3. Setup support channels
4. Monitor early adopters

**Acceptance Criteria:**
- Rollout plan ready
- Communication prepared
- Support available

---

## Rollout Plan

### Pre-Rollout (Week -1)

**Actions:**
1. ✅ All phases 1-3 complete and tested
2. ✅ Documentation finalized
3. ✅ Migration tools ready
4. ✅ Announcement drafted
5. ✅ Support team trained

**Checklist:**
- [ ] Performance targets met
- [ ] All tests passing
- [ ] Documentation reviewed
- [ ] Migration tools tested
- [ ] Backward compatibility verified

### Week 0: Soft Launch

**Actions:**
1. Announce to internal team
2. Enable for 1-2 pilot projects
3. Monitor closely
4. Gather feedback
5. Fix any critical issues

**Success Criteria:**
- Pilot projects migrated successfully
- No critical bugs
- Positive feedback
- Performance acceptable

### Week 1-2: Limited Rollout

**Actions:**
1. Announce to broader team
2. Enable for 10-20 projects
3. Continue monitoring
4. Iterate based on feedback
5. Update documentation as needed

**Success Criteria:**
- 10+ projects migrated
- Performance stable
- Minor bugs fixed
- Documentation accurate

### Week 3-4: General Availability

**Actions:**
1. Public announcement
2. Enable for all projects
3. Provide migration support
4. Monitor adoption metrics
5. Plan future enhancements

**Success Criteria:**
- 50%+ projects migrated
- Performance optimizations deployed
- Support tickets handled
- Deprecation timeline announced

### Month 2-3: Deprecation Warning

**Actions:**
1. Add warnings to old commands
2. Reminder emails
3. Migration assistance
4. Update examples

**Target:**
- 80%+ projects migrated
- Old sync usage declining
- Feedback incorporated

### Month 6: Deprecation

**Actions:**
1. Remove old sync code
2. Update to SPEC-00030 only
3. Archive SPEC-0012
4. Celebrate success! 🎉

**Target:**
- 95%+ projects migrated
- Legacy code removed
- Full benefits realized

---

## Success Criteria

### Phase 4 Complete When:

✅ **Migration**
- Migration guide complete
- Migration tools tested
- 80%+ projects migrated successfully
- Old sync deprecated

✅ **Performance**
- All optimization targets met
- No regressions
- Scales to 1000+ cached docs
- MCP server performant

✅ **Documentation**
- All docs updated
- Migration guide clear
- Troubleshooting comprehensive
- Examples provided

✅ **Quality**
- Backward compatibility works
- No data loss during migration
- Support available
- Metrics tracked

✅ **Adoption**
- Positive user feedback
- Active usage
- Few support tickets
- Clear benefits demonstrated

---

## Post-Phase 4: Future Enhancements

### Vector Store Integration

**Capability**: Semantic search across all knowledge
**Timeline**: 3-6 months post-Phase 4
**Spec**: SPEC-00031 (future)

**Features:**
- Index all docs in vector store
- Semantic similarity search
- RAG-ready knowledge base
- Cross-project discovery

### Advanced Caching

**Capability**: Intelligent predictive caching
**Timeline**: 2-3 months post-Phase 4

**Features:**
- Analyze dependencies, prefetch relevant docs
- Background refresh of stale cache
- Smart eviction (usage-based)
- Cache warming on startup

### Analytics & Insights

**Capability**: Knowledge usage analytics
**Timeline**: 2-3 months post-Phase 4

**Features:**
- Most-accessed documents
- Stale document detection
- Coverage metrics (what's not documented)
- Recommendation engine

---

## Appendix: Migration Checklist

### For Project Maintainers

**Pre-Migration:**
- [ ] Review current codex sync configuration
- [ ] Understand what docs are synced
- [ ] Identify critical dependencies on synced docs
- [ ] Backup current configuration

**Migration Steps:**
- [ ] Update codex plugin to latest version
- [ ] Run migration checker: `./migration-checker.sh`
- [ ] Review migration report
- [ ] Run cleanup script: `./cleanup-old-sync.sh`
- [ ] Run prefetch: `/codex:cache-prefetch`
- [ ] Verify cached docs: `/codex:cache-list`
- [ ] Test retrieval: `/codex:fetch @codex/...`
- [ ] Update documentation with @codex/ references
- [ ] Remove old sync commands from scripts/CI

**Post-Migration:**
- [ ] Monitor cache usage
- [ ] Verify performance
- [ ] Update team documentation
- [ ] Share feedback with platform team

### For Platform Team

**Pre-Launch:**
- [ ] All phases 1-3 complete
- [ ] Performance targets met
- [ ] Documentation finalized
- [ ] Migration tools ready
- [ ] Support plan in place

**Launch:**
- [ ] Announce to pilot users
- [ ] Monitor pilot adoption
- [ ] Fix critical issues
- [ ] Iterate on feedback
- [ ] Expand rollout

**Post-Launch:**
- [ ] Monitor adoption metrics
- [ ] Provide migration support
- [ ] Gather feedback
- [ ] Plan future enhancements
- [ ] Archive old system

---

**Status:** Ready for implementation after Phase 3
**Document Version:** 1.0.0
**Last Updated:** 2025-01-15
