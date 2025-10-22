---
version: 1.0

domain_mappings:
  # =============================
  # SOFTWARE ENGINEERING (already present)
  # =============================
  software:
    owner:
      agent: software-product-manager
      commands: [requirements-define, roadmap-create, roadmap-prioritize, define-kpis]
    manager:
      agent: software-project-manager
      commands: [plan-iteration, assign-tasks, track-status, manage-risks]
    designer:
      agent: software-architect
      commands: [design-architecture, define-standards, produce-spec]
    builder:
      agent: software-engineer
      commands: [build, review, refine, maintain]
    tester:
      agent: software-qa-engineer
      commands: [test-plan, test-execute, defect-triage, quality-gate]
    deployer:
      agent: software-devops-engineer
      commands: [prepare-release, deploy, activate, rollback, runbook-execute]
    monitor:
      agent: product-analyst
      commands: [collect-telemetry, kpi-report, anomaly-detect]
    success:
      agent: customer-success-agent
      commands: [onboard, resolve-issue, escalate, health-check]
    feedback_intake:
      agent: feedback-agent
      commands: [feedback-capture, synthesize-insights, propose-priorities]

  # =============================
  # DATA SCIENCE / ANALYTICS
  # =============================
  data_science:
    owner:
      agent: data-product-manager
      commands: [problem-define, hypothesis-frame, metric-design, roadmap-create]
    manager:
      agent: data-project-manager
      commands: [experiment-plan, backlog-prioritize, resource-allocate, milestone-track]
    designer:
      agent: data-architect
      commands: [schema-design, pipeline-blueprint, governance-standard]
    builder:
      agent: data-engineer
      commands: [etl-build, dataset-curate, query-optimize, model-deploy]
    tester:
      agent: data-quality-analyst
      commands: [data-validate, anomaly-detect, schema-verify, quality-report]
    deployer:
      agent: mlops-engineer
      commands: [model-deploy, monitor-drift, rollback-model, pipeline-trigger]
    monitor:
      agent: data-analyst
      commands: [dashboard-build, insight-generate, kpi-track]
    success:
      agent: data-evangelist
      commands: [communicate-insights, support-business-users, conduct-training]
    feedback_intake:
      agent: research-analyst
      commands: [hypothesis-review, dataset-feedback, improvement-propose]

  # =============================
  # AI / MACHINE LEARNING RESEARCH
  # =============================
  ai_research:
    owner:
      agent: research-director
      commands: [research-goal-define, hypothesis-prioritize, resource-plan]
    manager:
      agent: research-program-manager
      commands: [experiment-schedule, milestone-track, publication-manage]
    designer:
      agent: ml-research-architect
      commands: [model-architecture-design, training-framework-select, data-policy-define]
    builder:
      agent: ml-researcher
      commands: [train-model, evaluate-results, experiment-run, publish-findings]
    tester:
      agent: eval-scientist
      commands: [benchmark-setup, test-suite-run, bias-assess, interpret-results]
    deployer:
      agent: mlops-research-engineer
      commands: [integrate-model, package-release, environment-sync]
    monitor:
      agent: ai-observability-engineer
      commands: [drift-detect, performance-track, fairness-monitor]
    success:
      agent: ai-adoption-specialist
      commands: [educate-teams, enable-integration, promote-adoption]
    feedback_intake:
      agent: ai-feedback-analyst
      commands: [user-feedback-capture, explainability-review, retraining-request]

  # =============================
  # DATA PLATFORM / INFRASTRUCTURE (IT)
  # =============================
  infrastructure:
    owner:
      agent: platform-product-owner
      commands: [infrastructure-roadmap, reliability-goals, budget-plan]
    manager:
      agent: platform-operations-manager
      commands: [incident-assign, change-schedule, asset-track, capacity-plan]
    designer:
      agent: systems-architect
      commands: [network-design, compute-architecture, storage-layout]
    builder:
      agent: systems-engineer
      commands: [server-provision, configuration-apply, service-integrate]
    tester:
      agent: site-reliability-tester
      commands: [load-test, failover-test, resilience-validate, monitoring-check]
    deployer:
      agent: release-engineer
      commands: [release-package, deploy-service, rollback-system, verify-uptime]
    monitor:
      agent: observability-engineer
      commands: [uptime-monitor, alert-tune, performance-report]
    success:
      agent: it-support-engineer
      commands: [resolve-incident, service-request, user-support]
    feedback_intake:
      agent: ops-analyst
      commands: [incident-trend-analyze, improvement-suggest, feedback-capture]

  # =============================
  # CYBERSECURITY
  # =============================
  cybersecurity:
    owner:
      agent: security-program-manager
      commands: [threat-priority-define, policy-roadmap, compliance-goal-set]
    manager:
      agent: security-operations-lead
      commands: [incident-plan, alert-triage, vulnerability-assign]
    designer:
      agent: security-architect
      commands: [security-model-design, network-policy-define, identity-framework]
    builder:
      agent: security-engineer
      commands: [patch-deploy, policy-implement, script-automate]
    tester:
      agent: penetration-tester
      commands: [exploit-test, vulnerability-scan, red-team-run, report]
    deployer:
      agent: security-deployment-engineer
      commands: [rollout-controls, monitor-firewall, apply-ruleset]
    monitor:
      agent: soc-analyst
      commands: [threat-monitor, log-analyze, detect-anomaly, escalate-incident]
    success:
      agent: security-awareness-officer
      commands: [train-staff, communicate-policy, report-phishing]
    feedback_intake:
      agent: risk-analyst
      commands: [incident-postmortem, control-gap-analyze, policy-update-propose]

  # =============================
  # MARKETING
  # =============================
  marketing:
    owner:
      agent: marketing-strategist
      commands: [persona-define, campaign-roadmap, define-kpis]
    manager:
      agent: campaign-manager
      commands: [timeline-build, deliverable-assign, status-report]
    designer:
      agent: brand-designer
      commands: [brand-guideline, creative-spec, asset-system]
    builder:
      agent: content-creator
      commands: [draft, produce-asset, publish-draft]
    tester:
      agent: marketing-qa
      commands: [link-check, compliance-verify, a11y-check]
    deployer:
      agent: campaign-launcher
      commands: [schedule-posts, launch-campaign, rollback-content]
    monitor:
      agent: analytics-manager
      commands: [roi-report, cohort-analyze, experiment-readout]
    success:
      agent: client-success
      commands: [optimize-account, resolve-issue, QBR-prepare]
    feedback_intake:
      agent: insight-researcher
      commands: [survey-run, feedback-synthesize, priority-propose]

  # =============================
  # HR
  # =============================
  hr:
    owner:
      agent: talent-strategy-manager
      commands: [role-design, hiring-plan, define-kpis]
    manager:
      agent: recruiting-operations
      commands: [pipeline-plan, schedule-interviews, status-update]
    designer:
      agent: org-designer
      commands: [org-architecture, process-map, policy-draft]
    builder:
      agent: recruiter
      commands: [source-candidates, screen, recommend]
    tester:
      agent: compliance-officer
      commands: [policy-audit, training-validate, risk-review]
    deployer:
      agent: onboarding-specialist
      commands: [offer-issue, access-provision, day1-runbook]
    monitor:
      agent: people-analyst
      commands: [engagement-report, attrition-analyze, kpi-track]
    success:
      agent: employee-relations
      commands: [resolve-issue, mediate, case-manage]
    feedback_intake:
      agent: pulse-survey-agent
      commands: [collect-feedback, trend-report, propose-actions]

  # =============================
  # SALES
  # =============================
  sales:
    owner:
      agent: sales-director
      commands: [sales-strategy-define, quota-set, target-market-select, forecast-create]
    manager:
      agent: sales-manager
      commands: [pipeline-plan, territory-assign, deal-review, team-coach]
    designer:
      agent: sales-ops-architect
      commands: [crm-design, sales-process-map, automation-define]
    builder:
      agent: account-executive
      commands: [prospect, pitch, negotiate, close-deal]
    tester:
      agent: sales-auditor
      commands: [deal-review, compliance-check, discount-audit]
    deployer:
      agent: deal-desk-analyst
      commands: [contract-prepare, pricing-apply, approval-route, finalize-sale]
    monitor:
      agent: revenue-analyst
      commands: [sales-performance-report, conversion-analyze, pipeline-health]
    success:
      agent: account-manager
      commands: [renewal-manage, upsell-plan, relationship-maintain, satisfaction-check]
    feedback_intake:
      agent: customer-feedback-agent
      commands: [collect-feedback, analyze-objection, share-insights]

  # =============================
  # FINANCE
  # =============================
  finance:
    owner:
      agent: cfo
      commands: [financial-strategy-define, capital-allocate, forecast-create, policy-approve]
    manager:
      agent: finance-manager
      commands: [budget-plan, expense-track, report-generate, variance-analyze]
    designer:
      agent: financial-systems-architect
      commands: [chart-of-accounts-design, reporting-framework-build, integration-map]
    builder:
      agent: accountant
      commands: [record-transaction, reconcile-ledger, manage-payables, manage-receivables]
    tester:
      agent: internal-auditor
      commands: [audit-run, compliance-check, fraud-detect, reconcile-report]
    deployer:
      agent: payroll-specialist
      commands: [process-payroll, remit-taxes, distribute-salary, file-compliance]
    monitor:
      agent: financial-analyst
      commands: [profitability-analyze, cashflow-track, kpi-report, scenario-model]
    success:
      agent: finance-business-partner
      commands: [advise-department, support-forecast, optimize-spend]
    feedback_intake:
      agent: budget-feedback-agent
      commands: [collect-feedback, improve-budget-process, update-policy]

  # =============================
  # LEGAL
  # =============================
  legal:
    owner:
      agent: general-counsel
      commands: [legal-strategy-define, policy-draft, compliance-plan, risk-assess]
    manager:
      agent: legal-operations-manager
      commands: [contract-workflow-manage, request-intake, assign-counsel, track-matters]
    designer:
      agent: legal-architect
      commands: [contract-template-design, policy-framework-build, approval-flow-define]
    builder:
      agent: corporate-counsel
      commands: [draft-contract, negotiate-terms, review-document, advise-client]
    tester:
      agent: compliance-officer
      commands: [policy-audit, risk-assess, control-test, regulation-check]
    deployer:
      agent: contract-administrator
      commands: [execute-contract, store-document, manage-version, record-signature]
    monitor:
      agent: risk-analyst
      commands: [litigation-track, exposure-analyze, kpi-report]
    success:
      agent: legal-advisor
      commands: [respond-query, support-transaction, interpret-policy]
    feedback_intake:
      agent: policy-feedback-agent
      commands: [collect-feedback, improve-policy, identify-gaps]

  # =============================
  # OPERATIONS (General / Business Ops)
  # =============================
  operations:
    owner:
      agent: operations-director
      commands: [operations-strategy-define, process-prioritize, kpi-set, capacity-plan]
    manager:
      agent: operations-manager
      commands: [workflow-manage, schedule-coordinate, resource-assign, report-progress]
    designer:
      agent: process-architect
      commands: [process-map, workflow-design, optimization-plan, automation-define]
    builder:
      agent: operations-specialist
      commands: [execute-process, document-sop, maintain-systems, coordinate-teams]
    tester:
      agent: quality-assurance-officer
      commands: [process-audit, efficiency-test, gap-analysis, continuous-improvement]
    deployer:
      agent: implementation-manager
      commands: [rollout-process, deploy-change, train-staff, verify-adoption]
    monitor:
      agent: business-analyst
      commands: [kpi-track, efficiency-report, variance-analyze, trend-monitor]
    success:
      agent: internal-support-agent
      commands: [resolve-issue, enable-team, maintain-inventory, provide-training]
    feedback_intake:
      agent: improvement-analyst
      commands: [collect-feedback, suggest-improvement, prioritize-initiatives]

---