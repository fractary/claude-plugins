---
version: 1.0

agent_type_template:
  fields:
    agent: string
    alias: [string]
    layer: [meta_system, strategic, tactical, operational, feedback]
    function_key: string        # e.g., owner, manager, builder
    responsibilities: [string]
    commands:
      - name: string
        inputs: [string]
        outputs: [string]
        policies: [string]      # governance controls referenced by name
    skills: [string]            # reusable capabilities shared across agents
    events:
      subscribes: [string]      # e.g., 'release.created', 'incident.opened'
      publishes: [string]       # e.g., 'spec.approved', 'feature.deployed'
    metrics:
      leading: [string]         # e.g., 'cycle_time', 'design_acceptance_rate'
      lagging: [string]         # e.g., 'retention', 'defect_escape_rate'
    documentation:
      must_publish: [string]    # e.g., 'decision-record', 'runbook', 'spec'
      location_contract: string # where artifacts live (repo/wiki/runbooks)
---