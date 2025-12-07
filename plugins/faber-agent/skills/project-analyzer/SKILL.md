---
name: project-analyzer
description: Analyzes Claude Code project structure detecting architectural patterns and anti-patterns by executing detection scripts
model: claude-haiku-4-5
---

# Project Analyzer Skill

<CONTEXT>
You analyze Claude Code projects by executing detection scripts that check for architectural patterns and anti-patterns.

All detection is done by bash scripts in the `scripts/` directory. You execute the scripts and return their output.
</CONTEXT>

<CRITICAL_RULES>
1. ALL detection is done by executing bash scripts
2. DO NOT analyze files directly - run the scripts
3. DO NOT fabricate or hallucinate results
4. Return script output as the authoritative result
5. Read-only analysis - never modify project files
</CRITICAL_RULES>

<OPERATIONS>

## run-full-audit

Run all detection scripts and return comprehensive audit results.

**Input:**
- `project_path`: Path to Claude Code project root

**Execute:**
```
bash plugins/faber-agent/skills/project-analyzer/scripts/run-all-detections.sh {project_path}
```

**Output:** JSON from script containing:
- `summary.compliance_score`: Overall compliance percentage
- `summary.total_violations`: Count of all violations
- `summary.by_severity`: Breakdown by error/warning/info
- `detections.*`: Results from each detection script
- `structure`: Project structure info

---

## detect-project-specific-director (NEW v2.0 - ERROR SEVERITY)

Detect project-specific director skills - these are anti-patterns and BLOCK workflows.

**Input:**
- `project_path`: Path to Claude Code project root

**Execute:**
```
bash plugins/faber-agent/skills/project-analyzer/scripts/detect-project-specific-director.sh {project_path}
```

**Detection Logic:**
1. Search for skill files matching `*-director/SKILL.md` pattern
2. Exclude core FABER director (`faber-director`)
3. Search for commands with `-direct` suffix
4. Check for pattern expansion logic in skills

**Output:** JSON with:
```json
{
  "status": "error|clean",
  "rule_id": "ARC-006",
  "severity": "error",
  "message": "Project-specific director detected - use core faber-director instead",
  "violations": [
    {
      "file": "skills/{project}-director/SKILL.md",
      "line": null,
      "description": "Project-specific director skill",
      "migration_proposal": {
        "action": "delete",
        "replacement": "Use core faber-director with workflow config",
        "workflow_config_example": "..."
      }
    }
  ]
}
```

---

## detect-project-specific-manager (NEW v2.0 - ERROR SEVERITY)

Detect project-specific manager agents - these are anti-patterns and BLOCK workflows.

**Input:**
- `project_path`: Path to Claude Code project root

**Execute:**
```
bash plugins/faber-agent/skills/project-analyzer/scripts/detect-project-specific-manager.sh {project_path}
```

**Detection Logic:**
1. Search for agent files matching `*-manager.md` pattern
2. Exclude core FABER manager (`faber-manager`)
3. Check for orchestration/workflow logic in agents
4. Identify manager agents by content patterns

**Output:** JSON with:
```json
{
  "status": "error|clean",
  "rule_id": "ARC-007",
  "severity": "error",
  "message": "Project-specific manager detected - use core faber-manager with workflow config",
  "violations": [
    {
      "file": "agents/{project}-manager.md",
      "line": null,
      "description": "Project-specific manager agent",
      "migration_proposal": {
        "action": "delete",
        "replacement": "Use core faber-manager with workflow config",
        "workflow_config": {
          "id": "{project}-workflow",
          "phases": "..."
        },
        "invocation": "/faber run <id> --workflow {project}-workflow"
      }
    }
  ]
}
```

---

## inspect-structure

Scan project and collect structural information.

**Input:**
- `project_path`: Path to Claude Code project root

**Execute:**
```
bash plugins/faber-agent/skills/project-analyzer/scripts/inspect-structure.sh {project_path}
```

**Output:** JSON with agents, skills, commands counts and locations.

---

## detect-manager-as-skill

Detect Manager-as-Skill anti-pattern.

**Input:**
- `project_path`: Path to Claude Code project root

**Execute:**
```
bash plugins/faber-agent/skills/project-analyzer/scripts/detect-manager-as-skill.sh {project_path}
```

**Output:** JSON with detection results.

---

## detect-director-as-agent

Detect Director-as-Agent anti-pattern.

**Input:**
- `project_path`: Path to Claude Code project root

**Execute:**
```
bash plugins/faber-agent/skills/project-analyzer/scripts/detect-director-as-agent.sh {project_path}
```

**Output:** JSON with detection results.

---

## detect-workflow-logging

Detect missing workflow event logging in manager agents (AGT-005).

**Input:**
- `project_path`: Path to Claude Code project root

**Execute:**
```
bash plugins/faber-agent/skills/project-analyzer/scripts/detect-workflow-logging.sh {project_path}
```

**Output:** JSON with detection results.

---

## detect-direct-skill-commands

Detect commands that invoke skills directly instead of routing through manager (CMD-004).

**Input:**
- `project_path`: Path to Claude Code project root

**Execute:**
```
bash plugins/faber-agent/skills/project-analyzer/scripts/detect-direct-skill-commands.sh {project_path}
```

**Output:** JSON with detection results.

---

## detect-director-patterns

Detect missing director argument patterns (ARC-004).

**Input:**
- `project_path`: Path to Claude Code project root

**Execute:**
```
bash plugins/faber-agent/skills/project-analyzer/scripts/detect-director-patterns.sh {project_path}
```

**Output:** JSON with detection results.

---

## calculate-context-load

Calculate context token load and optimization opportunities.

**Input:**
- `project_path`: Path to Claude Code project root

**Execute:**
```
bash plugins/faber-agent/skills/project-analyzer/scripts/calculate-context-load.sh {project_path}
```

**Output:** JSON with context load analysis.

</OPERATIONS>

<DOCUMENTATION>
Upon completion, output:
```
✅ COMPLETED: Project Analyzer
Project: {project_path}
Results returned to agent
```
</DOCUMENTATION>

<ERROR_HANDLING>
**Project not found:**
```json
{"status": "error", "error": "project_not_found", "message": "Directory does not exist"}
```

**Not a Claude Code project:**
```json
{"status": "error", "error": "invalid_project", "message": ".claude/ directory not found"}
```

**Script failed:**
```json
{"status": "error", "error": "script_failed", "message": "Script execution error"}
```
</ERROR_HANDLING>
