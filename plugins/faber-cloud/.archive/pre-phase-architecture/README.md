# Pre-Phase Architecture - Archived

**Status:** DEPRECATED
**Archived Date:** 2025-10-28
**Reason:** Superseded by Phase 1-4 layered architecture

---

## What's in This Archive

This directory contains the **original architecture** files that were developed before the Phase 1-4 implementation. All functionality has been migrated to the new architecture with significant improvements.

### Archived Files

**Old Agents (3 files):**
- `agents/devops-deployer.md` - Deployment orchestration agent
- `agents/devops-debugger.md` - Error debugging agent
- `agents/devops-permissions.md` - IAM permission management agent

**Old Commands (4 files):**
- `commands/devops-deploy.md` - Deployment command
- `commands/devops-validate.md` - Validation command
- `commands/devops-status.md` - Status display command
- `commands/devops-permissions.md` - Permission management command

**Old Skills (1 directory):**
- `skills/devops-deployer/` - Legacy Terraform and AWS bash scripts
  - `iac-tools/terraform/` - Terraform operation scripts
  - `providers/aws/` - AWS provider scripts

---

## Why These Were Deprecated

### Old Architecture Limitations

**Flat Structure:**
```
Commands → Agents → Scripts
devops-deploy → devops-deployer → terraform scripts
```

**Problems:**
- No natural language interface
- Limited separation of concerns
- Agents doing too much work directly
- Bash-centric with inline execution
- No clear handler abstraction
- Limited extensibility

### New Architecture (Phase 1-4)

**Layered Structure:**
```
Natural Language → Director → Managers → Skills → Handlers
"deploy to test" → devops-director → infra-manager → infra-deployer → handler-hosting-aws
```

**Improvements:**
- Natural language interface (Phase 4)
- Clear workflow orchestration via managers
- Single-purpose skills
- Handler abstraction for providers
- Configuration-driven behavior
- Intelligent debugging with learning (Phase 2)
- Comprehensive testing (Phase 2)
- Runtime operations (Phase 3)
- Complete documentation (Phase 4)

---

## Migration Guide

### Command Mapping

| Old Command | New Command | Natural Language Alternative |
|-------------|-------------|------------------------------|
| `/devops:deploy test` | `/fractary-devops:infra-manage deploy --env=test` | `/fractary-devops:director "deploy to test"` |
| `/devops:validate` | `/fractary-devops:infra-manage validate-config` | `/fractary-devops:director "validate configuration"` |
| `/devops:status test` | `/fractary-devops:infra-manage show-resources --env=test` | `/fractary-devops:director "show test resources"` |
| `/devops:permissions add <perm> test` | Automatic via infra-manager on errors | N/A (handled automatically) |
| `/devops:debug` | Automatic via infra-manager on errors | `/fractary-devops:director "debug error"` |

### Functionality Preserved

All functionality from the old architecture has been preserved and enhanced:

**From devops-deployer:**
- ✅ Authentication workflows → handler-hosting-aws
- ✅ IaC workflows → handler-iac-terraform
- ✅ Error delegation → infra-manager + infra-debugger
- ✅ Environment safety → All managers
- ✅ Output formatting → All skills

**From devops-debugger:**
- ✅ Error categorization → infra-debugger (enhanced: 6 categories)
- ✅ Fix strategies → infra-debugger with solution ranking
- ✅ Multi-error handling → infra-debugger workflow
- ✅ Learning system → Issue log with success rate tracking

**From devops-permissions:**
- ✅ Profile separation → infra-permission-manager
- ✅ IAM audit system → infra-permission-manager
- ✅ Permission scope → infra-permission-manager
- ✅ Least privilege → Documentation and enforcement

---

## Functional Improvements in New Architecture

1. **Natural Language**: Use plain English instead of remembering command syntax
2. **Intelligent Debugging**: Learning system improves error resolution over time
3. **Comprehensive Testing**: Pre and post-deployment validation with security scans
4. **Runtime Operations**: Full monitoring, investigation, and remediation capabilities
5. **Better Documentation**: Complete documentation suite with guides and references
6. **Production Safety**: Multiple confirmation levels for production deployments
7. **Performance**: Optimized context usage (30-50% reduction)

---

## Why Keep This Archive

**Historical Reference:**
- Documents evolution of the plugin
- Shows design decisions and patterns
- May contain implementation details useful for future development

**No Active Use:**
- These files are not loaded by the plugin
- Git history also preserves all versions
- Can safely ignore this directory

---

## See Current Documentation

For current plugin documentation, see:
- [README.md](../../README.md) - Plugin overview and quick start
- [ARCHITECTURE.md](../../docs/architecture/ARCHITECTURE.md) - Current architecture
- [docs/guides/getting-started.md](../../docs/guides/getting-started.md) - Getting started
- [docs/guides/user-guide.md](../../docs/guides/user-guide.md) - Complete user guide
- [PHASE-4-COMPLETE.md](../../docs/specs/status/PHASE-4-COMPLETE.md) - Phase 4 summary

---

**This archive is for reference only. All active development uses the Phase 1-4 architecture.**
