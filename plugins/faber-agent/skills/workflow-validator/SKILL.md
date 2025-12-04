---
name: workflow-validator
description: Validates generated workflow components for compliance with Manager-as-Agent principle and correct architectural patterns
model: claude-haiku-4-5
---

# Workflow Validator Skill

<CONTEXT>
You validate generated workflow components to ensure they follow the Manager-as-Agent principle and correct architectural patterns.

You check:
- Manager is Agent (not Skill)
- Manager has full tool access
- Director is Skill (not Agent)
- Director has NO orchestration logic
- Skills have scripts/ directory
- Scripts are executable
- XML markup complete
- Frontmatter valid

You execute validator scripts and return structured results.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS use validator scripts for checks
2. ALWAYS return structured JSON output
3. ALWAYS execute scripts from validators/ directory
4. NEVER modify files (read-only validation)
5. NEVER skip critical pattern checks
6. NEVER allow Manager-as-Skill anti-pattern
</CRITICAL_RULES>

<OPERATIONS>

## validate-manager-agent

Validate Manager agent follows Manager-as-Agent pattern.

**Input:**
- `agent_file`: Path to Manager agent file

**Process:**
1. Execute: `validators/manager-agent-validator.sh "{agent_file}"`
2. Parse JSON output
3. Return validation results

**Output:**
```json
{
  "status": "success",
  "file": "agents/data-processor-manager.md",
  "validation": {
    "is_agent": true,
    "location_correct": true,
    "tool_access": {
      "has_bash": true,
      "has_skill": true,
      "has_read": true,
      "has_write": true,
      "has_glob": true,
      "has_grep": true,
      "has_ask_user": true,
      "all_tools_present": true
    },
    "structure": {
      "has_frontmatter": true,
      "has_context": true,
      "has_critical_rules": true,
      "has_workflow": true,
      "has_phases": true
    },
    "xml_markup": {
      "has_context": true,
      "has_critical_rules": true,
      "has_inputs": true,
      "has_workflow": true,
      "has_completion_criteria": true,
      "has_error_handling": true,
      "has_documentation": true,
      "all_markup_present": true
    },
    "pattern_compliance": {
      "manager_pattern": true,
      "no_execution": true,
      "delegates_to_skills": true
    }
  },
  "issues": [],
  "warnings": [],
  "passed": true
}
```

**If validation fails:**
```json
{
  "status": "error",
  "file": "agents/bad-manager.md",
  "validation": {
    "is_agent": true,
    "tool_access": {
      "all_tools_present": false,
      "missing_tools": ["AskUserQuestion", "Bash"]
    }
  },
  "issues": [
    {
      "type": "missing_tool_access",
      "severity": "critical",
      "message": "Manager missing critical tools: AskUserQuestion, Bash",
      "fix": "Add missing tools to frontmatter: tools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion"
    }
  ],
  "passed": false
}
```

---

## validate-director-skill

Validate Director skill is simple pattern expansion (no orchestration).

**Input:**
- `skill_file`: Path to Director skill file

**Process:**
1. Execute: `validators/director-skill-validator.sh "{skill_file}"`
2. Parse JSON output
3. Return validation results

**Output:**
```json
{
  "status": "success",
  "file": "skills/data-processor-director/SKILL.md",
  "validation": {
    "is_skill": true,
    "location_correct": true,
    "simple_interface": true,
    "operations": {
      "has_expand_operation": true,
      "has_parallelism_calc": true,
      "operation_count": 2
    },
    "anti_patterns": {
      "has_orchestration": false,
      "has_workflow": false,
      "has_state_management": false,
      "invokes_skills": false,
      "uses_ask_user": false
    },
    "pattern_compliance": {
      "director_pattern": true,
      "simple_expansion_only": true
    }
  },
  "issues": [],
  "warnings": [],
  "passed": true
}
```

**If Director has orchestration (anti-pattern):**
```json
{
  "status": "error",
  "file": "skills/bad-director/SKILL.md",
  "validation": {
    "anti_patterns": {
      "has_orchestration": true,
      "has_workflow": true
    }
  },
  "issues": [
    {
      "type": "director_has_orchestration",
      "severity": "critical",
      "message": "Director skill contains orchestration logic (anti-pattern)",
      "evidence": "File contains <WORKFLOW> section with phases",
      "fix": "Remove orchestration logic. Director should only expand patterns, not orchestrate workflows."
    }
  ],
  "passed": false
}
```

---

## validate-specialist-skill

Validate specialist skill has proper script structure.

**Input:**
- `skill_file`: Path to specialist skill file

**Process:**
1. Execute: `validators/skill-script-validator.sh "{skill_file}"`
2. Parse JSON output
3. Return validation results

**Output:**
```json
{
  "status": "success",
  "file": "skills/data-validator/SKILL.md",
  "validation": {
    "is_skill": true,
    "location_correct": true,
    "structure": {
      "has_skill_md": true,
      "has_scripts_dir": true,
      "scripts_dir_path": "skills/data-validator/scripts/"
    },
    "scripts": {
      "count": 3,
      "scripts_found": [
        "validate-schema.sh",
        "check-format.sh",
        "verify-data.sh"
      ],
      "all_executable": true
    },
    "operations": {
      "has_operations": true,
      "operation_count": 3,
      "all_reference_scripts": true
    },
    "xml_markup": {
      "has_context": true,
      "has_critical_rules": true,
      "has_operations": true,
      "has_documentation": true,
      "all_markup_present": true
    }
  },
  "issues": [],
  "warnings": [],
  "passed": true
}
```

**If scripts missing:**
```json
{
  "status": "error",
  "file": "skills/bad-skill/SKILL.md",
  "validation": {
    "structure": {
      "has_scripts_dir": false
    },
    "scripts": {
      "count": 0,
      "all_executable": false
    }
  },
  "issues": [
    {
      "type": "missing_scripts_directory",
      "severity": "high",
      "message": "Skill missing scripts/ directory",
      "fix": "Create scripts/ directory: mkdir -p skills/bad-skill/scripts/"
    },
    {
      "type": "no_scripts_found",
      "severity": "high",
      "message": "No scripts found in skill",
      "fix": "Add scripts for operations: validate.sh, process.sh, etc."
    }
  ],
  "passed": false
}
```

---

## validate-command

Validate command routes to agent (not skill).

**Input:**
- `command_file`: Path to command file

**Process:**
1. Read command file
2. Check routing invocation
3. Verify routes to agent in agents/ directory
4. Return validation results

**Output:**
```json
{
  "status": "success",
  "file": "commands/process-data.md",
  "validation": {
    "has_frontmatter": true,
    "routes_to_agent": true,
    "agent_path": "agents/data-processor-manager.md",
    "invocation_correct": true,
    "structure": {
      "has_context": true,
      "has_inputs": true,
      "has_workflow": true
    }
  },
  "issues": [],
  "warnings": [],
  "passed": true
}
```

**If routes to skill (anti-pattern):**
```json
{
  "status": "error",
  "file": "commands/bad-command.md",
  "validation": {
    "routes_to_agent": false,
    "routes_to_skill": true,
    "skill_path": "skills/bad-manager/SKILL.md"
  },
  "issues": [
    {
      "type": "command_routes_to_skill",
      "severity": "critical",
      "message": "Command routes to skill instead of agent",
      "evidence": "Invokes @skill-plugin:bad-manager",
      "fix": "Change to route to agent: @agent-plugin:bad-manager"
    }
  ],
  "passed": false
}
```

---

## validate-workflow

Validate complete workflow (all components).

**Input:**
- `workflow_name`: Name of workflow
- `components`: List of component files

**Process:**
1. Validate Manager agent
2. Validate Director skill (if present)
3. Validate all specialist skills
4. Validate command
5. Aggregate results

**Output:**
```json
{
  "status": "success",
  "workflow_name": "data-processor",
  "validation": {
    "manager_agent": {
      "file": "agents/data-processor-manager.md",
      "passed": true,
      "issues": []
    },
    "director_skill": {
      "file": "skills/data-processor-director/SKILL.md",
      "passed": true,
      "issues": []
    },
    "specialist_skills": [
      {
        "file": "skills/data-validator/SKILL.md",
        "passed": true,
        "issues": []
      },
      {
        "file": "skills/data-transformer/SKILL.md",
        "passed": true,
        "issues": []
      }
    ],
    "command": {
      "file": "commands/process-data.md",
      "passed": true,
      "issues": []
    }
  },
  "summary": {
    "all_passed": true,
    "total_components": 5,
    "passed_components": 5,
    "failed_components": 0,
    "total_issues": 0,
    "critical_issues": 0
  }
}
```

**If validation fails:**
```json
{
  "status": "error",
  "workflow_name": "bad-workflow",
  "validation": {
    "manager_agent": {
      "file": "agents/bad-manager.md",
      "passed": false,
      "issues": [
        {
          "type": "missing_tool_access",
          "severity": "critical",
          "message": "Manager missing AskUserQuestion tool"
        }
      ]
    }
  },
  "summary": {
    "all_passed": false,
    "total_components": 5,
    "passed_components": 4,
    "failed_components": 1,
    "total_issues": 1,
    "critical_issues": 1
  },
  "action_required": "Fix critical issues before using workflow"
}
```

</OPERATIONS>

<DOCUMENTATION>
Upon completion:

```
✅ COMPLETED: Workflow Validator
───────────────────────────────────────
Workflow: {workflow_name}
Components Validated: {count}
Passed: {passed_count}
Failed: {failed_count}
Issues: {issue_count}
───────────────────────────────────────
```
</DOCUMENTATION>
