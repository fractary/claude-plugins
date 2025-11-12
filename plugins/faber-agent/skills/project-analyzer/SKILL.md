---
skill: project-analyzer
purpose: Analyze Claude Code project structure and detect architectural anti-patterns
layer: Analyzer
---

# Project Analyzer Skill

<CONTEXT>
You analyze Claude Code projects to detect architectural patterns, anti-patterns, and calculate context optimization opportunities.

You perform factual analysis by executing deterministic scripts and returning structured results.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS use scripts for detection (never analyze files directly)
2. ALWAYS return structured JSON output
3. ALWAYS execute scripts from this skill's scripts/ directory
4. NEVER modify project files (read-only analysis)
5. NEVER make recommendations (analysis only - recommendations come from agent)
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
