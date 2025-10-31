---
version: 1.0
universal_principles:
  - knowledge-capture       # every agent documents what it creates/decides
  - communication           # every agent exposes state & publishes updates
  - measurement             # every agent defines success metrics & emits telemetry
  - auditability            # changes & approvals are traceable
  - interoperability        # contracts for handoffs between agents

layers:
  meta_system:
    function: governance_policy
    description: Defines global standards, risk frameworks, ethics, and constraints.
    default_agents:
      - agent: org-governance-agent
        commands: [policy-create, policy-update, policy-enforce, risk-audit, exception-approve]
      - agent: security-compliance-agent
        commands: [control-map, audit-run, vuln-scan, incident-review]
      - agent: ethics-alignment-agent
        commands: [decision-audit, bias-detect, principle-check]
  strategic:
    function: director
    description: Sets strategy, allocates resources, ensures alignment with governance.
    default_agents:
      - agent: director
        commands: [set-okr, allocate-budget, set-priorities, approve-portfolio]
  tactical:
    functions:
      - key: owner
        alias: [product-owner, business-owner]
        description: Defines what to build/do and why; owns success metrics.
        default_commands: [requirements-define, roadmap-create, roadmap-prioritize, define-kpis]
      - key: manager
        alias: [project-manager, scrum-master, operations-manager]
        description: Plans, sequences, tracks work; manages dependencies & risks.
        default_commands: [plan-iteration, assign-tasks, track-status, manage-risks]
      - key: architect_designer
        alias: [architect, designer]
        description: Designs systems/processes/experiences; sets patterns & standards.
        default_commands: [design-architecture, define-standards, produce-spec]
  operational:
    functions:
      - key: builder
        alias: [engineer, implementer, maker]
        description: Produces the tangible deliverable.
        default_commands: [build, review, refine, maintain]
      - key: tester
        alias: [validator, qa]
        description: Verifies outputs meet specs, policies, and quality bars.
        default_commands: [test-plan, test-execute, defect-triage, quality-gate]
      - key: deployer
        alias: [launcher, release-manager]
        description: Puts outputs into production/public use; manages rollbacks.
        default_commands: [prepare-release, deploy, activate, rollback, runbook-execute]
  feedback:
    functions:
      - key: monitor
        alias: [analyst, observability]
        description: Measures performance and outcomes; generates insights.
        default_commands: [collect-telemetry, kpi-report, anomaly-detect]
      - key: success_support
        alias: [customer-success, support, enablement]
        description: Ensures adoption, satisfaction, and ongoing value.
        default_commands: [onboard, resolve-issue, escalate, health-check]
      - key: feedback_intake
        alias: [research, insights]
        description: Captures user/stakeholder feedback; curates signals for prioritization.
        default_commands: [feedback-capture, synthesize-insights, propose-priorities]

---