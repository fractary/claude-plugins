# FABER & Helm Implementation Guide

**Version:** 1.0.0
**Date:** 2025-11-03
**Status:** Ready for Implementation

---

## Quick Start

This guide provides a **practical roadmap** for implementing the FABER/Helm architecture. For detailed specifications, see the referenced documents.

---

## Documentation Index

### Core Architecture
- **[faber-helm-architecture.md](./faber-helm-architecture.md)** - Vision, philosophy, and system boundaries
  - Read this **first** to understand the overall vision
  - 991 lines covering: separation of concerns, integration model, universal pattern

### Detailed Specifications
- **[helm-system-specification.md](./helm-system-specification.md)** - Complete Helm system design
  - 1778 lines covering: central Helm, domain plugins, workflows, dashboard, voice interface

### Migration Plan
- **[faber-cloud-helm-migration.md](./faber-cloud-helm-migration.md)** - Multi-phase implementation roadmap
  - 642 lines covering: 5 phases over 12-16 weeks, rollback plans, testing strategy

---

## The Vision in One Paragraph

**FABER** (Frame → Architect → Build → Evaluate → Release) handles **creation** - building and shipping things across any domain (infrastructure, applications, content, design). **Helm** (Monitor → Analyze → Alert → Remediate) handles **operations** - keeping things healthy after they're shipped. Together, they form a complete lifecycle: FABER creates, Helm monitors, Helm detects issues, Helm escalates back to FABER for fixes. A centralized Helm dashboard provides a unified view across all domains, supporting voice interface and intelligent prioritization.

---

## Current State → Target State

### Current: faber-cloud (Embedded)

```
faber-cloud/
├── infra-manager (FABER workflows)
└── ops-manager (Helm workflows)

Problem: Mixed responsibilities, no centralized dashboard
```

### Target: Hybrid Architecture

```
faber-cloud/           helm-cloud/              helm/
├── infra-manager  →  ├── ops-manager      →  ├── helm-director
(FABER only)          (Helm for infra)         ├── helm-dashboard
                                                └── (central orchestrator)

Benefits: Clear separation, centralized dashboard, scalable
```

---

## Implementation Phases

### Phase 1: Command Reorganization (2-3 weeks)

**Goal:** Simplify command structure in faber-cloud

**Before:**
```bash
/fractary-faber-cloud:infra-manage deploy --env=test
/fractary-faber-cloud:ops-manage check-health --env=test
```

**After:**
```bash
/fractary-faber-cloud:deploy --env=test
/fractary-faber-cloud:health --env=test
```

**Tasks:**
1. Create new command files (architect.md, deploy.md, health.md, etc.)
2. Implement 1:1 command-to-operation mapping
3. Add backward compatibility shims for old commands
4. Update documentation

**Deliverable:** Simpler, clearer command structure

---

### Phase 2: Extract helm-cloud (3-4 weeks)

**Goal:** Create separate helm-cloud plugin

**Structure:**
```
helm-cloud/
├── .claude-plugin/plugin.json
├── agents/ops-manager.md
├── skills/ops-{monitor,investigator,responder,auditor}/
└── config/monitoring.toml
```

**Tasks:**
1. Create helm-cloud plugin directory and structure
2. Copy ops-manager and ops-* skills from faber-cloud
3. Establish shared configuration (.fractary/registry/, .fractary/shared/)
4. Update faber-cloud to delegate to helm-cloud
5. Maintain backward compatibility via shims

**Deliverable:** Working helm-cloud plugin monitoring faber-cloud deployments

---

### Phase 3: Create Central Helm (4-5 weeks)

**Goal:** Unified dashboard across all domains

**Structure:**
```
helm/
├── agents/
│   ├── helm-director.md       # Routes to domain plugins
│   └── helm-dashboard.md      # Aggregates metrics
├── skills/
│   ├── aggregator/            # Collect from domains
│   └── prioritizer/           # Cross-domain priority
├── registry/
│   └── domain-monitors.json   # Registered domains
└── issues/
    ├── active/                # Current issues
    └── resolved/              # Historical issues
```

**Tasks:**
1. Create helm/ plugin structure
2. Implement helm-director (routing agent)
3. Implement helm-dashboard (aggregation agent)
4. Create domain monitor registry
5. Implement issue registry and prioritization
6. Register helm-cloud as first domain

**Deliverable:** Centralized dashboard showing infrastructure health

---

### Phase 4: Clean Separation (1-2 weeks) ⚠️ BREAKING

**Goal:** Remove ops from faber-cloud entirely

**Tasks:**
1. Remove ops-manager and ops-* skills from faber-cloud
2. Remove deprecated shims
3. Bump version to faber-cloud v2.0.0
4. Create migration guide for users
5. Release with deprecation notices

**Deliverable:** faber-cloud is pure infrastructure creation, all monitoring in Helm

---

### Phase 5: Future Extensions (Ongoing)

**Potential Projects:**
- helm-app (application monitoring with APM, error tracking)
- helm-content (content analytics, SEO monitoring)
- Voice interface ("Hey Helm, what's the status?")
- ML-based issue prioritization
- Web-based dashboard UI

---

## Key Commands After Migration

### Infrastructure Creation (FABER)
```bash
/faber-cloud:architect "VPC with public and private subnets"
/faber-cloud:engineer user-uploads
/faber-cloud:validate
/faber-cloud:preview --env=test
/faber-cloud:deploy --env=prod
/faber-cloud:verify --env=prod
```

### Infrastructure Monitoring (Helm - Domain)
```bash
/helm-cloud:health --env=prod
/helm-cloud:investigate "Lambda high error rate"
/helm-cloud:remediate infra-001 --action=immediate
/helm-cloud:audit --type=cost
```

### Unified Dashboard (Helm - Central)
```bash
/helm:dashboard                    # All domains, all environments
/helm:dashboard --env=prod         # Production only
/helm:dashboard --domain=infrastructure
/helm:status                       # Text summary
/helm:issues --top 5               # Top prioritized issues
/helm:escalate infra-001           # Create FABER work item
```

---

## Configuration Structure

### Shared Central Registry
```
.fractary/
├── registry/
│   └── deployments.json          # All deployments across domains
├── shared/
│   ├── aws-credentials.json      # Shared AWS config
│   └── environments.json         # Environment definitions
└── plugins/
    ├── faber-cloud/
    │   └── config/infra-config.json
    └── helm-cloud/
        └── config/monitoring-config.json
```

### Domain Configuration
```toml
# helm-cloud/config/monitoring.toml
[monitoring]
health_check_interval = "5m"

[slos.lambda]
error_rate_percent = 0.1
p95_latency_ms = 200

[remediation]
auto_remediate = ["restart_lambda"]
require_confirmation = ["scale_resources"]
```

---

## Integration Flow

### 1. FABER → Helm Handoff

```
FABER deploys infrastructure
    ↓
Registers in .fractary/registry/deployments.json
    ↓
(Optional) Runs initial health check via Helm
    ↓
FABER completes
    ↓
Helm picks up deployment from registry
    ↓
Helm begins continuous monitoring
```

### 2. Helm → FABER Feedback

```
Helm detects issue (error rate spike)
    ↓
Creates issue: helm/issues/active/infra-001.json
    ↓
User or auto-escalation: /helm:escalate infra-001
    ↓
Creates GitHub issue with domain routing metadata
    ↓
FABER Frame picks up work item
    ↓
Issue classifier routes to faber-cloud
    ↓
FABER workflow fixes issue
    ↓
Helm verifies fix, closes issue
```

---

## Testing Checklist

### Phase 1
- [ ] All new commands functional
- [ ] All old commands work via shims
- [ ] No breaking changes
- [ ] Documentation updated

### Phase 2
- [ ] helm-cloud monitors faber-cloud deployments
- [ ] Shared registry functional
- [ ] Health checks working
- [ ] Backward compatibility maintained

### Phase 3
- [ ] helm-director routes correctly
- [ ] helm-dashboard aggregates metrics
- [ ] Issue prioritization working
- [ ] Escalation to FABER successful

### Phase 4
- [ ] faber-cloud v2.0.0 clean (no ops)
- [ ] All monitoring via helm-cloud
- [ ] Migration guide complete
- [ ] Users successfully migrated

---

## Success Metrics

### Technical
- ✅ Clear separation of concerns (FABER creates, Helm monitors)
- ✅ Centralized dashboard operational
- ✅ Cross-domain issue prioritization working
- ✅ Voice-ready output format
- ✅ Zero monitoring gaps

### User Experience
- ✅ Commands intuitive and consistent
- ✅ Dashboard provides actionable insights
- ✅ Escalation to FABER seamless
- ✅ Documentation comprehensive
- ✅ Migration smooth (minimal friction)

### Scalability
- ✅ Pattern applies to any domain
- ✅ Adding new domain is straightforward
- ✅ Performance acceptable (dashboard < 5s)
- ✅ No architectural bottlenecks

---

## Timeline Summary

| Phase | Duration | Risk | Start | End |
|-------|----------|------|-------|-----|
| 1. Command Reorganization | 2-3 weeks | Low | Week 1 | Week 3 |
| 2. Extract helm-cloud | 3-4 weeks | Moderate | Week 4 | Week 7 |
| 3. Create Central Helm | 4-5 weeks | Moderate | Week 8 | Week 12 |
| 4. Clean Separation | 1-2 weeks | High | Week 13 | Week 14 |
| **Total** | **12-16 weeks** | - | - | **Week 16** |

---

## Standard Pattern for All Domains

When adding a new domain (e.g., content publishing):

### 1. Create FABER Plugin
```
faber-content/
├── agents/content-manager.md
└── skills/
    ├── content-draft/
    ├── content-review/
    └── content-publish/
```

### 2. Create Helm Plugin
```
helm-content/
├── agents/analytics-manager.md
└── skills/
    ├── engagement-monitor/
    ├── seo-analyzer/
    └── performance-tracker/
```

### 3. Register with Central Helm
```json
// helm/registry/domain-monitors.json
{
  "monitors": [
    ...,
    {
      "domain": "content",
      "plugin": "fractary-helm-content",
      "capabilities": ["engagement", "seo", "performance"]
    }
  ]
}
```

### 4. Done!
- Dashboard automatically includes new domain
- Voice interface works immediately
- Issue prioritization includes content domain

---

## FAQ

### Q: Why separate FABER and Helm?
**A:** Different mental models, temporality, and success criteria. FABER creates things (one-time workflow), Helm monitors things (continuous). Industry standard pattern (Kubernetes, Prometheus, etc.).

### Q: Can I still use faber-cloud v1.x?
**A:** Yes, during transition. v1.x will be supported for 6 months after v2.0.0 release. But migration is recommended to access centralized dashboard and future features.

### Q: What if I only want infrastructure, not monitoring?
**A:** Use faber-cloud v2.0.0 without helm-cloud. But you'll miss automated monitoring, issue detection, and centralized dashboard.

### Q: How does voice interface work?
**A:** Phase 5 feature. Natural language query → helm-director → domain plugins → aggregated response → TTS-ready text. Example: "Hey Helm, what's production status?"

### Q: Can Helm auto-remediate issues?
**A:** Yes, for configured safe operations (restart Lambda, clear cache). Risky operations (scale resources, modify security groups) require confirmation.

### Q: How do I escalate an issue to FABER?
**A:** `/helm:escalate <issue-id>` creates GitHub issue with domain routing metadata. FABER Frame picks it up and routes to appropriate domain plugin.

---

## Next Steps

1. **Review:** Read core architecture document (faber-helm-architecture.md)
2. **Approve:** Get stakeholder sign-off on this approach
3. **Plan:** Schedule Phase 1 kickoff
4. **Implement:** Begin command reorganization in faber-cloud
5. **Track:** Monitor progress against success metrics
6. **Communicate:** Keep stakeholders and users informed

---

## Resources

### Documentation
- [faber-helm-architecture.md](./faber-helm-architecture.md) - Vision & philosophy
- [helm-system-specification.md](./helm-system-specification.md) - Detailed Helm design
- [faber-cloud-helm-migration.md](./faber-cloud-helm-migration.md) - Migration roadmap

### Plugin Ecosystem
- `plugins/faber/` - Core FABER workflows
- `plugins/faber-cloud/` - Current implementation (to be migrated)
- `plugins/work/`, `plugins/repo/`, `plugins/file/` - Primitive managers

### Standards
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md` - Plugin development guidelines

---

**End of Guide**

**Ready to begin? Start with Phase 1: Command Reorganization**
