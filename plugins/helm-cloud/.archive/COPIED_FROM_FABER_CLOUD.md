# Files Copied from faber-cloud Plugin

**Date:** 2025-11-03
**Phase:** Phase 2 - Extract helm-cloud Plugin

## Agents Copied

- `agents/ops-manager.md` - Runtime operations orchestrator
  - **Source:** `plugins/faber-cloud/agents/ops-manager.md`
  - **Changes:** Updated all `/fractary-faber-cloud` references to `/fractary-helm-cloud`

## Skills Copied

1. **ops-monitor/** - Health checks and metrics collection
   - Source: `plugins/faber-cloud/skills/ops-monitor/`
   - Includes: SKILL.md, workflow/health-check.md, scripts/

2. **ops-investigator/** - Log analysis and incident investigation
   - Source: `plugins/faber-cloud/skills/ops-investigator/`
   - Includes: SKILL.md, workflow/, scripts/

3. **ops-responder/** - Remediation actions
   - Source: `plugins/faber-cloud/skills/ops-responder/`
   - Includes: SKILL.md, workflow/, scripts/

4. **ops-auditor/** - Cost/security/compliance audits
   - Source: `plugins/faber-cloud/skills/ops-auditor/`
   - Includes: SKILL.md, workflow/, scripts/

## Changes Made

### Agent Updates
- Updated command examples from `/fractary-faber-cloud:ops-manage` to `/fractary-helm-cloud:{operation}`
- Updated skill invocation format from `/fractary-faber-cloud:skill:` to `/fractary-helm-cloud:skill:`

### Configuration Dependencies
All skills depend on:
- Shared configuration (to be created in `.fractary/shared/`)
- Shared deployment registry (to be created in `.fractary/registry/`)
- Monitoring configuration (created in `config/monitoring.example.toml`)

## Next Steps
- [ ] Create monitoring configuration template
- [ ] Establish shared configuration structure
- [ ] Create helm-cloud commands
- [ ] Set up delegation from faber-cloud
