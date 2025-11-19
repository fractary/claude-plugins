# Fractary DevOps Plugin - Overview

**Version:** 1.0.0
**Status:** Specification
**Last Updated:** 2025-10-28
**Authors:** Fractary Engineering

---

## Table of Contents

1. [Purpose](#purpose)
2. [Vision](#vision)
3. [Key Features](#key-features)
4. [Architecture Overview](#architecture-overview)
5. [Core Concepts](#core-concepts)
6. [Quick Reference](#quick-reference)
7. [Related Documentation](#related-documentation)

---

## Purpose

The Fractary DevOps plugin provides comprehensive infrastructure and operations management for Claude Code, enabling AI-assisted cloud infrastructure lifecycle management from design through deployment to runtime operations.

### Problem Statement

Current challenges in infrastructure management:
- ❌ Manual, error-prone deployment processes
- ❌ Inconsistent infrastructure patterns across projects
- ❌ Time-consuming permission debugging
- ❌ Lack of deployment visibility and documentation
- ❌ Difficulty tracking deployed resources
- ❌ Reinventing infrastructure workflows for each project

### Solution

A unified, intelligent DevOps plugin that:
- ✅ Automates complete infrastructure lifecycle (architect → deploy-apply → monitor)
- ✅ Provides consistent patterns across cloud providers and IaC tools
- ✅ Manages IAM permissions with audit trails
- ✅ Maintains comprehensive resource registry and documentation
- ✅ Learns from past issues to prevent recurring problems
- ✅ Works across projects with minimal configuration

---

## Vision

**Enable teams to manage cloud infrastructure through natural conversation with Claude, backed by robust automation, comprehensive documentation, and institutional knowledge.**

### Design Principles

1. **Workflow-Oriented**: Managers own complete domain workflows, not fragmented tasks
2. **Multi-Provider**: Support AWS, GCP, Azure, and other cloud providers
3. **Multi-Tool**: Support Terraform, Pulumi, CDK, and other IaC tools
4. **Configuration-Driven**: Single config file determines all behavior
5. **Documentation-First**: Every action is documented automatically
6. **Permission-Safe**: Strict IAM separation prevents over-permissioning
7. **Learning System**: Debugger learns from past issues and solutions
8. **Provider-Agnostic**: Core logic independent of specific providers/tools

---

## Key Features

### Infrastructure Lifecycle Management

**Design → Engineer → Validate → Test → Preview → Deploy → Verify → Monitor**

- 🏗️ **Architecture Design**: Analyze requirements and design complete solutions
- 🔧 **IaC Engineering**: Generate Terraform/Pulumi code from designs
- ✅ **Validation**: Syntax, security, compliance, cost validation
- 🧪 **Testing**: Pre-deployment security scanning, post-deployment verification
- 👁️ **Preview**: Show planned changes before execution
- 🚀 **Deployment**: Execute deployments with safety checks
- 📊 **Monitoring**: Health checks, performance analysis, log investigation

### Permission Management

- **Profile Separation**: discover-deploy (IAM only) vs test/prod-deploy (deployment only)
- **Environment Scoping**: Permissions restricted to environment from the start
- **Audit Trail**: Complete history of all permission grants
- **Auto-Fix**: Automatically grant missing permissions when deployment fails
- **Least Privilege**: Follow principle of least privilege with scoped permissions

### Resource Tracking

- **Resource Registry**: Track all deployed resources with ARNs, IDs, metadata
- **Console Links**: AWS Console URLs for quick access to resources
- **Deployment History**: Complete history of all deployments
- **Current State**: Always know what's deployed in each environment
- **Change Documentation**: Automatic documentation of all changes

### Intelligent Debugging

- **Issue Log**: Historical record of all issues and solutions
- **Pattern Matching**: Match new errors against known solutions
- **Root Cause Analysis**: Analyze errors and propose fixes
- **Learning System**: Success rate tracking and solution ranking
- **Guided Resolution**: Step-by-step fix proposals, not automatic changes

### Multi-Provider Support

**Hosting Providers:**
- AWS (implemented)
- GCP (planned)
- Azure (planned)

**IaC Tools:**
- Terraform (implemented)
- Pulumi (planned)
- AWS CDK (planned)
- CloudFormation (planned)

**Extensible**: Easy to add new providers and tools without changing core logic

---

## Architecture Overview

### Component Structure

```
┌─────────────────────────────────────────────┐
│         Natural Language Interface          │
│              devops-director                │
└────────────────┬────────────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌──────────────┐  ┌──────────────┐
│ infra-manager│  │  ops-manager │
│ (Design to   │  │  (Monitor to │
│  Deploy)     │  │  Remediate)  │
└──────┬───────┘  └──────┬───────┘
       │                  │
       ├─ infra-architect         ├─ ops-monitor
       ├─ infra-engineer          ├─ ops-investigator
       ├─ infra-validator         ├─ ops-responder
       ├─ infra-tester            └─ ops-auditor
       ├─ infra-previewer
       ├─ infra-deployer
       ├─ infra-permission-manager
       └─ infra-debugger
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌──────────────┐  ┌──────────────┐
│   Handler    │  │   Handler    │
│   Skills     │  │   Skills     │
│              │  │              │
│ hosting/     │  │ iac/         │
│  aws/        │  │  terraform/  │
│  gcp/        │  │  pulumi/     │
└──────────────┘  └──────────────┘
```

### Two Primary Managers

**1. infra-manager** - Infrastructure Lifecycle
- Complete workflow: Design → Engineer → Validate → Test → Preview → Deploy → Debug
- Owns all infrastructure operations from architecture through deployment
- Coordinates infrastructure skills and handler skills

**2. ops-manager** - Runtime Operations
- Complete workflow: Monitor → Detect → Investigate → Diagnose → Respond → Remediate
- Owns all runtime operations from health monitoring through incident response
- Coordinates operations skills and handler skills

### Handler Skills Pattern

**Handler skills centralize provider/tool-specific logic:**
- `handler-hosting-aws`: All AWS hosting operations
- `handler-hosting-gcp`: All GCP hosting operations
- `handler-iac-terraform`: All Terraform operations
- `handler-iac-pulumi`: All Pulumi operations

**Benefits:**
- ✅ DRY (Don't Repeat Yourself) - logic centralized
- ✅ Easy to add new providers/tools
- ✅ Skills remain provider-agnostic
- ✅ Clear separation of concerns

### Director for Natural Language

**devops-director** parses natural language and routes to appropriate manager:
- "deploy infrastructure to test" → infra-manager
- "check if API is healthy" → ops-manager
- "investigate 500 errors" → ops-manager

---

## Core Concepts

### 1. Managers Own Complete Workflows

**Not fragmented tasks:**
- ❌ Bad: separate-design, separate-deploy, separate-monitor agents
- ✅ Good: infra-manager owns design through deploy, ops-manager owns monitor through remediate

**Context flows naturally within manager:**
- Designed resource → Implemented in IaC → Deployed → Verified
- No handoffs, no coordination overhead

### 2. Skills Are Execution Units

**Skills = single-purpose execution units:**
- infra-architect: Design solutions
- infra-deployer: Execute deployments
- ops-monitor: Monitor system health

**Skills never work in isolation:**
- Always invoked by manager
- Return results to manager
- Manager coordinates multi-skill workflows

### 3. Handlers Provide Provider Abstraction

**Handler skills = provider/tool-specific implementations:**
- handler-hosting-aws knows how to deploy to AWS
- handler-iac-terraform knows how to run Terraform

**Skills use handlers through standard interface:**
- Skill: "Deploy this resource"
- Manager: "Use skill handler-hosting-aws with operation 'deploy'"
- Handler: Executes AWS-specific deployment logic

### 4. Configuration Drives Behavior

**Single config file determines everything:**
```json
{
  "handlers": {
    "hosting": { "active": "aws" },
    "iac": { "active": "terraform" }
  }
}
```

**Skills read config and adapt:**
- Same skill works with AWS or GCP
- Change config, change behavior
- No code changes needed

### 5. Documentation is Embedded

**Skills document their own work:**
- infra-deployer updates resource registry after deployment
- infra-architect updates design documentation
- infra-debugger logs resolved issues

**Always up-to-date:**
- Documentation happens atomically with work
- Even if workflow fails mid-way, completed work is documented
- No separate documentation step to forget

### 6. Permission Separation is Enforced

**Three AWS profiles with strict rules:**
- `discover-deploy`: Grant IAM permissions ONLY, never deploy
- `test-deploy`: Deploy to test ONLY, never grant IAM
- `prod-deploy`: Deploy to prod ONLY, never grant IAM

**Enforced at multiple levels:**
- Command level
- Manager level
- Skill level
- Every skill validates before AWS operations

### 7. Learning from History

**infra-debugger maintains issue log:**
- Every error encountered
- Root cause analysis
- Solution applied
- Success/failure
- Recurrence count

**Proposes solutions based on history:**
- Match new error against past errors
- Rank solutions by success rate
- Reference historical fixes
- Learn over time

---

## Quick Reference

### Commands

```bash
# Initialize configuration
/fractary-faber-cloud:init --provider aws --iac terraform

# Infrastructure Management
/fractary-faber-cloud:infra-manage deploy --env test
/fractary-faber-cloud:infra-manage architect --feature="user uploads"
/fractary-faber-cloud:infra-manage validate-config
/fractary-faber-cloud:infra-manage show-resources --env test

# Operations Management
/fractary-faber-cloud:ops-manage check-health --service=api
/fractary-faber-cloud:ops-manage investigate --issue="500 errors"
/fractary-faber-cloud:ops-manage query-logs --service=api --level=error

# Natural Language
/fractary-faber-cloud:director "deploy infrastructure to test"
/fractary-faber-cloud:director "check if services are healthy"
```

### Managers

- **infra-manager**: Infrastructure lifecycle (architect → deploy)
- **ops-manager**: Runtime operations (monitor → remediate)
- **devops-director**: Natural language routing

### Infrastructure Skills

- **infra-architect**: Design infrastructure solutions
- **infra-engineer**: Implement IaC code
- **infra-validator**: Validate configurations
- **infra-tester**: Security scans, cost estimates
- **infra-previewer**: Preview changes
- **infra-deployer**: Execute deployments
- **infra-permission-manager**: Manage IAM permissions
- **infra-debugger**: Analyze errors, propose solutions

### Operations Skills

- **ops-monitor**: Health checks, metrics
- **ops-investigator**: Log analysis, incident investigation
- **ops-responder**: Incident response, remediation
- **ops-auditor**: Security/cost auditing

### Handler Skills

- **handler-hosting-aws**: AWS operations
- **handler-hosting-gcp**: GCP operations (planned)
- **handler-iac-terraform**: Terraform operations
- **handler-iac-pulumi**: Pulumi operations (planned)

### Configuration

**Location:** `.fractary/plugins/faber-cloud/devops.json`

**Key sections:**
- `project`: Project metadata
- `handlers.hosting`: Cloud provider config
- `handlers.iac`: IaC tool config
- `resource_naming`: Naming patterns
- `environments`: Environment-specific settings

### Artifacts

**Resource Registry:** `.fractary/plugins/faber-cloud/deployments/{env}/registry.json`
- All deployed resources with ARNs, IDs, console URLs

**Deployment Docs:** `.fractary/plugins/faber-cloud/deployments/{env}/DEPLOYED.md`
- Human-readable resource list

**Design Docs:** `.fractary/plugins/faber-cloud/designs/{feature}.md`
- Architecture designs

**IAM Audit:** `.fractary/plugins/faber-cloud/deployments/iam-audit.json`
- Complete IAM permission history

---

## Related Documentation

### Detailed Specifications

- **[Architecture](fractary-faber-cloud-architecture.md)** - Detailed architecture, components, data flow
- **[Configuration](fractary-faber-cloud-configuration.md)** - Configuration file structure and options
- **[Handlers](fractary-faber-cloud-handlers.md)** - Handler pattern and implementation
- **[Permissions](fractary-faber-cloud-permissions.md)** - Permission management strategy
- **[Documentation](fractary-faber-cloud-documentation.md)** - Documentation and registry systems
- **[Implementation Phases](fractary-faber-cloud-implementation-phases.md)** - Phase-by-phase implementation plan

### Standards

- **[Fractary Plugin Standards](../../../FRACTARY-PLUGIN-STANDARDS.md)** - Universal patterns for all Fractary plugins

### Guides (To be created during implementation)

- Getting Started Guide
- User Guide
- Troubleshooting Guide
- Contributing Guide

---

## Success Criteria

This plugin is successful when:

1. ✅ Teams can manage infrastructure through natural conversation
2. ✅ Deployments are consistently documented and tracked
3. ✅ Permission errors are auto-resolved with audit trails
4. ✅ Recurring issues are prevented through learning
5. ✅ Works across multiple cloud providers and IaC tools
6. ✅ New projects can be set up in minutes with `/fractary-faber-cloud:init`
7. ✅ Deployment state is always clear and accessible
8. ✅ Production deployments are safe with mandatory confirmations
9. ✅ Plugin patterns are reusable for other domains (engineering, marketing, etc.)

---

**Next Steps:** Review detailed specifications for architecture, configuration, handlers, permissions, documentation, and implementation phases.
