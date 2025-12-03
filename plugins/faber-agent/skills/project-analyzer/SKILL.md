---
name: project-analyzer
description: Analyzes Claude Code project structure detecting architectural patterns and anti-patterns using formalized best practices rules
---

# Project Analyzer Skill

<CONTEXT>
You analyze Claude Code projects to detect architectural patterns and anti-patterns using the formalized rules in `config/best-practices-rules.yaml`.

You perform factual analysis by executing deterministic scripts and returning structured results that include:
- Component-by-component compliance status
- Rule violations with evidence (code snippets, line numbers)
- Proposed fixes for each violation
</CONTEXT>

<CONFIGURATION>
**Rules File:** `config/best-practices-rules.yaml`
**Rules Version:** Check `version` field in rules file (e.g., "2025-12-02")
</CONFIGURATION>

<CRITICAL_RULES>
1. ALWAYS use scripts for detection (never analyze files directly)
2. ALWAYS load rules from config/best-practices-rules.yaml
3. ALWAYS return structured JSON output with per-component results
4. ALWAYS execute scripts from this skill's scripts/ directory
5. ALWAYS include code snippets and line numbers for findings
6. NEVER modify project files (read-only analysis)
7. NEVER make recommendations (analysis only - agent generates recommendations)
</CRITICAL_RULES>

<OPERATIONS>

## inspect-structure

Scan project directory and collect structural information.

**Input:**
- `project_path`: Path to Claude Code project root

**Process:**
1. Execute: `scripts/inspect-structure.sh "{project_path}"`
2. Parse JSON output
3. Return results

**Output:**
```json
{
  "status": "success",
  "project_path": "/path/to/project",
  "agents": {
    "count": 5,
    "files": [".claude/agents/project/agent1.md", ...],
    "names": ["agent1", "agent2", ...]
  },
  "skills": {
    "count": 12,
    "files": [".claude/skills/skill1/SKILL.md", ...],
    "names": ["skill1", "skill2", ...]
  },
  "commands": {
    "count": 4,
    "files": [".claude/commands/cmd1.md", ...],
    "names": ["cmd1", "cmd2", ...]
  },
  "project_type": "pre-skills" | "skills-based" | "hybrid" | "unknown"
}
```

---

## detect-antipatterns

Detect all anti-patterns in project.

**Input:**
- `project_path`: Path to Claude Code project root
- `inspection_results`: Results from inspect-structure operation

**Process:**
1. Execute: `scripts/detect-manager-as-skill.sh "{project_path}"`
2. Execute: `scripts/detect-director-as-agent.sh "{project_path}"`
3. Execute: `scripts/calculate-context-load.sh "{project_path}"`
4. Aggregate results
5. Return comprehensive analysis

**Output:**
```json
{
  "status": "success",
  "anti_patterns": [
    {
      "type": "manager_as_skill",
      "severity": "critical",
      "instances": 2,
      "details": [
        {
          "name": "data-manager",
          "location": ".claude/skills/data-manager/SKILL.md",
          "evidence": "File contains orchestration logic",
          "evidence_lines": [12, 45, 78],
          "migration_days": 7,
          "priority": "high"
        }
      ]
    },
    {
      "type": "director_as_agent",
      "severity": "critical",
      "instances": 1,
      "details": [
        {
          "name": "pattern-expander",
          "location": ".claude/agents/pattern-expander.md",
          "evidence": "Agent doing simple pattern expansion",
          "migration_days": 2,
          "priority": "medium"
        }
      ]
    }
  ],
  "correct_patterns": [
    {
      "type": "manager_as_agent",
      "instances": 3,
      "names": ["workflow-manager", "data-processor", "api-orchestrator"]
    }
  ],
  "context_analysis": {
    "current_load_tokens": 245000,
    "projected_load_tokens": 95000,
    "reduction_tokens": 150000,
    "reduction_percentage": 0.61,
    "breakdown": {
      "agents": 135000,
      "skills": 60000,
      "commands": 10000,
      "overhead": 40000
    }
  }
}
```

---

## detect-manager-as-skill

Detect Manager-as-Skill anti-pattern specifically.

**Input:**
- `project_path`: Path to Claude Code project root

**Process:**
1. Execute: `scripts/detect-manager-as-skill.sh "{project_path}"`
2. Return results

**Output:**
```json
{
  "status": "success",
  "pattern": "manager_as_skill",
  "detected": true | false,
  "instances": 2,
  "details": [
    {
      "name": "data-manager",
      "location": ".claude/skills/data-manager/SKILL.md",
      "evidence": "File contains state management, user interaction patterns",
      "evidence_keywords": ["workflow_phase", "user_approval", "phases_completed"],
      "confidence": 0.95
    }
  ]
}
```

---

## detect-director-as-agent

Detect Director-as-Agent anti-pattern specifically.

**Input:**
- `project_path`: Path to Claude Code project root

**Process:**
1. Execute: `scripts/detect-director-as-agent.sh "{project_path}"`
2. Return results

**Output:**
```json
{
  "status": "success",
  "pattern": "director_as_agent",
  "detected": true | false,
  "instances": 1,
  "details": [
    {
      "name": "pattern-expander",
      "location": ".claude/agents/pattern-expander.md",
      "evidence": "Agent only expands patterns, no orchestration",
      "simple_responsibility": true,
      "confidence": 0.90
    }
  ]
}
```

---

## evaluate-component

Evaluate a single component against all applicable rules.

**Input:**
- `component_path`: Path to component file
- `component_type`: Type of component ("command", "agent", "skill")

**Process:**
1. Load rules from config/best-practices-rules.yaml for component_type
2. Read component file content
3. For each applicable rule:
   - Execute check (pattern match, frontmatter check, etc.)
   - If rule fails, capture:
     - Line numbers where issue found
     - Code snippet (up to 20 lines)
     - Rule remediation steps
4. Return component evaluation result

**Output:**
```json
{
  "status": "success",
  "component": {
    "path": ".claude/commands/deploy.md",
    "type": "command",
    "name": "deploy"
  },
  "compliance": {
    "is_compliant": false,
    "passing_checks": 1,
    "failing_checks": 2,
    "total_checks": 3
  },
  "passing_rules": [
    {
      "rule_id": "CMD-002",
      "rule_name": "Proper frontmatter"
    }
  ],
  "failing_rules": [
    {
      "rule_id": "CMD-001",
      "rule_name": "Command routes to agent",
      "severity": "critical",
      "evidence": {
        "lines": [45, 52, 67],
        "snippet": "<WORKFLOW>\n1. Run script\n   Bash: ./scripts/deploy.sh\n</WORKFLOW>",
        "pattern_matched": "Bash:"
      },
      "current_state": "Command executes Bash directly",
      "expected_state": "Command invokes agent",
      "remediation_steps": [
        "Create deploy-manager agent",
        "Move deployment logic to agent",
        "Update command to route to agent"
      ]
    }
  ]
}
```

---

## evaluate-all-components

Evaluate all components in project against rules.

**Input:**
- `project_path`: Path to Claude Code project root
- `inspection_results`: Results from inspect-structure operation

**Process:**
1. Load all rules from config/best-practices-rules.yaml
2. For each component found in inspection_results:
   - Call evaluate-component operation
   - Aggregate results
3. Calculate compliance scores by category
4. Return comprehensive evaluation

**Output:**
```json
{
  "status": "success",
  "project_path": "/path/to/project",
  "rules_version": "2025-12-02",
  "summary": {
    "total_components": 14,
    "compliant_components": 9,
    "non_compliant_components": 5,
    "compliance_score": 64,
    "by_category": {
      "commands": {"total": 4, "compliant": 3, "non_compliant": 1},
      "agents": {"total": 2, "compliant": 1, "non_compliant": 1},
      "skills": {"total": 8, "compliant": 5, "non_compliant": 3}
    },
    "by_severity": {
      "critical": 3,
      "warning": 4,
      "info": 2
    }
  },
  "components": [
    {
      "path": ".claude/commands/init.md",
      "type": "command",
      "is_compliant": true,
      "passing_checks": 3,
      "failing_checks": 0
    },
    {
      "path": ".claude/commands/deploy.md",
      "type": "command",
      "is_compliant": false,
      "passing_checks": 1,
      "failing_checks": 2,
      "issues": [
        {
          "rule_id": "CMD-001",
          "rule_name": "Command routes to agent",
          "severity": "critical",
          "current_state": "Command executes Bash directly",
          "expected_state": "Command invokes agent",
          "evidence": {
            "lines": [45, 52],
            "snippet": "..."
          },
          "remediation_steps": ["..."]
        }
      ]
    }
  ],
  "remediation_plan": {
    "critical": [
      {
        "component": ".claude/commands/deploy.md",
        "rule_id": "CMD-001",
        "title": "Convert deploy command to route to agent",
        "effort_estimate": "2 hours"
      }
    ],
    "warning": [...],
    "info": [...]
  }
}
```

</OPERATIONS>

<DOCUMENTATION>
Upon completion of analysis, output:

```
✅ COMPLETED: Project Analyzer
Project: {project_path}
───────────────────────────────────────
Findings:
- Components: {agents} agents, {skills} skills, {commands} commands
- Anti-patterns: {count} detected
- Context optimization: {percentage}% reduction possible
───────────────────────────────────────
Results returned to: project-auditor agent
</DOCUMENTATION>

<ERROR_HANDLING>

**Project not found:**
```json
{
  "status": "error",
  "error": "project_not_found",
  "message": "Directory does not exist: {project_path}",
  "resolution": "Verify project path is correct"
}
```

**Not a Claude Code project:**
```json
{
  "status": "error",
  "error": "invalid_project",
  "message": ".claude/ directory not found",
  "resolution": "Ensure this is a valid Claude Code project root"
}
```

**Script execution failed:**
```json
{
  "status": "error",
  "error": "script_failed",
  "script": "{script_name}",
  "message": "{error_output}",
  "resolution": "Check script permissions and dependencies"
}
```

</ERROR_HANDLING>
