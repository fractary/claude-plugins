# Conversion Specification Guide

## Overview

Conversion specifications are structured JSON files that describe how to transform plugin architectures from anti-patterns to Manager-as-Agent compliant patterns. This guide explains the spec format and how to create custom conversion specs.

---

## Specification Format

### Complete Example

```json
{
  "conversion_id": "conv-20250111-001",
  "version": "1.0",
  "type": "manager-as-skill-inversion",
  "severity": "critical",
  "plugin": {
    "name": "fractary-my-plugin",
    "path": "/plugins/my-plugin",
    "version": "1.2.0"
  },
  "metadata": {
    "detected_at": "2025-01-11T16:30:00Z",
    "detected_by": "faber-agent-auditor",
    "auditor_version": "2.0.0"
  },
  "anti_pattern": {
    "type": "manager-as-skill-inversion",
    "description": "Orchestration logic implemented as Skill instead of Agent",
    "affected_files": [
      "skills/deployment-orchestrator/SKILL.md",
      "agents/deployment-director.md"
    ],
    "evidence": [
      {
        "file": "skills/deployment-orchestrator/SKILL.md",
        "issue": "Has <WORKFLOW> section with 7 phases",
        "line": 15,
        "severity": "critical"
      },
      {
        "file": "skills/deployment-orchestrator/SKILL.md",
        "issue": "Coordinates 4 other skills",
        "lines": [45, 67, 89, 102],
        "severity": "critical"
      },
      {
        "file": "skills/deployment-orchestrator/SKILL.md",
        "issue": "Needs AskUserQuestion but skills can't use it",
        "line": 78,
        "severity": "critical"
      }
    ]
  },
  "conversion_plan": {
    "description": "Convert Skill to Agent with full tool access",
    "steps": [
      {
        "step": 1,
        "action": "create",
        "file": "agents/deployment-orchestrator.md",
        "reason": "Convert orchestrator from Skill to Agent",
        "template": "manager-agent-7-phase.md.template",
        "parameters": {
          "MANAGER_NAME": "deployment-orchestrator",
          "MANAGER_DESCRIPTION": "Orchestrates deployment workflow",
          "PHASE_COUNT": 7,
          "SKILLS": [
            "deployment-preparer",
            "deployment-validator",
            "deployment-executor",
            "deployment-verifier"
          ]
        },
        "content_preview": "---\nname: deployment-orchestrator\ntools: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion\n..."
      },
      {
        "step": 2,
        "action": "modify",
        "file": "agents/deployment-director.md",
        "reason": "Update routing to use Agent not Skill",
        "changes": [
          {
            "line": 45,
            "old": "Route to @skill-deployment-orchestrator",
            "new": "Route to @agent-my-plugin:deployment-orchestrator"
          }
        ]
      },
      {
        "step": 3,
        "action": "delete",
        "file": "skills/deployment-orchestrator/SKILL.md",
        "reason": "Moved to agents/ directory",
        "backup": true,
        "backup_location": ".backup/skills/deployment-orchestrator/SKILL.md.20250111"
      }
    ],
    "validation": {
      "run_after_conversion": true,
      "validators": [
        "manager-agent-validator.sh",
        "director-skill-validator.sh"
      ],
      "expected_results": {
        "manager_in_agents": true,
        "manager_has_all_tools": true,
        "director_routes_to_agent": true
      }
    }
  },
  "estimated_impact": {
    "context_reduction_tokens": 5000,
    "context_reduction_percent": 60,
    "files_affected": 3,
    "files_created": 1,
    "files_modified": 1,
    "files_deleted": 1,
    "new_capabilities": [
      "User approval gates (AskUserQuestion)",
      "Proper state management across phases",
      "Full tool access for orchestration"
    ],
    "breaking_changes": false,
    "backwards_compatible": true
  },
  "migration": {
    "guide": "docs/migration/manager-inversion-fix.md",
    "difficulty": "medium",
    "estimated_time_minutes": 30,
    "requires_manual_review": [
      "Verify state management strategy",
      "Review user approval gates placement"
    ],
    "testing_required": [
      "Test workflow end-to-end",
      "Verify user approval flow",
      "Test error handling"
    ]
  },
  "rollback": {
    "supported": true,
    "steps": [
      {
        "step": 1,
        "action": "restore",
        "file": "skills/deployment-orchestrator/SKILL.md",
        "from_backup": ".backup/skills/deployment-orchestrator/SKILL.md.20250111"
      },
      {
        "step": 2,
        "action": "delete",
        "file": "agents/deployment-orchestrator.md"
      },
      {
        "step": 3,
        "action": "revert",
        "file": "agents/deployment-director.md",
        "to_commit": "HEAD~1"
      }
    ]
  }
}
```

---

## Spec Fields Reference

### Top-Level Fields

#### `conversion_id`
**Type:** String
**Required:** Yes
**Format:** `conv-YYYYMMDD-NNN`

Unique identifier for the conversion.

**Example:**
```json
"conversion_id": "conv-20250111-001"
```

#### `version`
**Type:** String
**Required:** Yes
**Format:** Semantic version (X.Y.Z)

Specification format version.

**Example:**
```json
"version": "1.0"
```

#### `type`
**Type:** String (enum)
**Required:** Yes

Type of conversion/anti-pattern.

**Valid values:**
- `manager-as-skill-inversion`
- `agent-chain-refactor`
- `hybrid-agent-split`
- `script-extraction`
- `director-as-agent-fix`
- `custom`

**Example:**
```json
"type": "manager-as-skill-inversion"
```

#### `severity`
**Type:** String (enum)
**Required:** Yes

Severity of the anti-pattern.

**Valid values:**
- `critical`: Breaks functionality, requires immediate fix
- `warning`: Suboptimal but functional
- `suggestion`: Best practice recommendation

**Example:**
```json
"severity": "critical"
```

### Plugin Object

#### `plugin.name`
**Type:** String
**Required:** Yes

Name of the affected plugin.

**Example:**
```json
"plugin": {
  "name": "fractary-my-plugin",
  "path": "/plugins/my-plugin",
  "version": "1.2.0"
}
```

### Anti-Pattern Object

#### `anti_pattern.evidence`
**Type:** Array of objects
**Required:** Yes

Evidence of the anti-pattern.

**Example:**
```json
"evidence": [
  {
    "file": "skills/orchestrator/SKILL.md",
    "issue": "Has <WORKFLOW> section",
    "line": 15,
    "severity": "critical"
  }
]
```

### Conversion Plan Object

#### `conversion_plan.steps`
**Type:** Array of step objects
**Required:** Yes

Ordered steps to perform conversion.

**Step actions:**
- `create`: Create new file
- `modify`: Modify existing file
- `delete`: Delete file
- `move`: Move/rename file
- `extract`: Extract content to new file

**Example (create step):**
```json
{
  "step": 1,
  "action": "create",
  "file": "agents/my-manager.md",
  "reason": "Create Manager Agent",
  "template": "manager-agent-7-phase.md.template",
  "parameters": {
    "MANAGER_NAME": "my-manager",
    "PHASE_COUNT": 7
  }
}
```

**Example (modify step):**
```json
{
  "step": 2,
  "action": "modify",
  "file": "agents/my-director.md",
  "reason": "Update routing",
  "changes": [
    {
      "line": 45,
      "old": "Route to @skill-my-manager",
      "new": "Route to @agent-my-plugin:my-manager"
    }
  ]
}
```

**Example (delete step):**
```json
{
  "step": 3,
  "action": "delete",
  "file": "skills/my-manager/SKILL.md",
  "reason": "Moved to agents/",
  "backup": true
}
```

### Estimated Impact Object

#### `estimated_impact.context_reduction_tokens`
**Type:** Integer
**Required:** No

Estimated token savings after conversion.

**Example:**
```json
"estimated_impact": {
  "context_reduction_tokens": 5000,
  "context_reduction_percent": 60
}
```

### Migration Object

#### `migration.guide`
**Type:** String (path)
**Required:** Yes

Path to relevant migration guide.

**Example:**
```json
"migration": {
  "guide": "docs/migration/manager-inversion-fix.md",
  "difficulty": "medium",
  "estimated_time_minutes": 30
}
```

---

## Creating Custom Specs

### Use Case: Custom Anti-Pattern

You've identified a custom anti-pattern not detected by the auditor.

**Example: "God Skill" (skill doing too much)**

**Step 1: Create spec file**

```json
{
  "conversion_id": "conv-custom-20250111-001",
  "version": "1.0",
  "type": "custom",
  "severity": "warning",
  "plugin": {
    "name": "fractary-my-plugin",
    "path": "/plugins/my-plugin"
  },
  "metadata": {
    "detected_at": "2025-01-11T16:30:00Z",
    "detected_by": "manual-review"
  },
  "anti_pattern": {
    "type": "god-skill",
    "description": "Single skill with too many responsibilities",
    "affected_files": [
      "skills/data-handler/SKILL.md"
    ],
    "evidence": [
      {
        "file": "skills/data-handler/SKILL.md",
        "issue": "Has 15 operations (should be 3-5)",
        "severity": "warning"
      },
      {
        "file": "skills/data-handler/SKILL.md",
        "issue": "Mixes fetch, validate, transform, load concerns",
        "severity": "warning"
      }
    ]
  },
  "conversion_plan": {
    "description": "Split god skill into focused skills",
    "steps": [
      {
        "step": 1,
        "action": "create",
        "file": "skills/data-fetcher/SKILL.md",
        "reason": "Extract fetch operations",
        "template": "specialist-skill-with-scripts.md.template",
        "parameters": {
          "SKILL_NAME": "data-fetcher",
          "OPERATIONS": ["fetch-api", "fetch-file", "fetch-db"]
        }
      },
      {
        "step": 2,
        "action": "create",
        "file": "skills/data-validator/SKILL.md",
        "reason": "Extract validation operations",
        "template": "specialist-skill-with-scripts.md.template",
        "parameters": {
          "SKILL_NAME": "data-validator",
          "OPERATIONS": ["validate-schema", "validate-data"]
        }
      },
      {
        "step": 3,
        "action": "create",
        "file": "skills/data-transformer/SKILL.md",
        "reason": "Extract transformation operations",
        "template": "specialist-skill-with-scripts.md.template",
        "parameters": {
          "SKILL_NAME": "data-transformer",
          "OPERATIONS": ["transform-format", "enrich-data"]
        }
      },
      {
        "step": 4,
        "action": "modify",
        "file": "agents/data-manager.md",
        "reason": "Update to use 3 new skills instead of god skill",
        "changes": [
          {
            "line": 25,
            "old": "Use @skill-data-handler",
            "new": "Use @skill-data-fetcher\nUse @skill-data-validator\nUse @skill-data-transformer"
          }
        ]
      },
      {
        "step": 5,
        "action": "delete",
        "file": "skills/data-handler/SKILL.md",
        "reason": "Replaced by 3 focused skills",
        "backup": true
      }
    ]
  },
  "estimated_impact": {
    "context_reduction_tokens": 2000,
    "context_reduction_percent": 30,
    "files_affected": 5,
    "files_created": 3,
    "files_modified": 1,
    "files_deleted": 1,
    "new_capabilities": [
      "Better separation of concerns",
      "Reusable focused skills",
      "Easier to test independently"
    ]
  },
  "migration": {
    "guide": "docs/migration/custom/god-skill-splitting.md",
    "difficulty": "medium",
    "estimated_time_minutes": 45,
    "requires_manual_review": [
      "Verify operation grouping makes sense",
      "Check dependencies between operations"
    ],
    "testing_required": [
      "Test each new skill independently",
      "Test complete workflow end-to-end"
    ]
  }
}
```

**Step 2: Apply spec**

```bash
/fractary-faber-agent:apply-conversion /path/to/conv-custom-20250111-001.json
```

---

## Spec Templates

### Template 1: Manager-as-Skill Inversion

```json
{
  "conversion_id": "conv-YYYYMMDD-NNN",
  "version": "1.0",
  "type": "manager-as-skill-inversion",
  "severity": "critical",
  "plugin": {
    "name": "{{PLUGIN_NAME}}",
    "path": "{{PLUGIN_PATH}}"
  },
  "anti_pattern": {
    "type": "manager-as-skill-inversion",
    "description": "Orchestration logic in Skill instead of Agent",
    "affected_files": [
      "skills/{{SKILL_NAME}}/SKILL.md"
    ],
    "evidence": [
      {
        "file": "skills/{{SKILL_NAME}}/SKILL.md",
        "issue": "Has <WORKFLOW> section",
        "severity": "critical"
      }
    ]
  },
  "conversion_plan": {
    "steps": [
      {
        "step": 1,
        "action": "create",
        "file": "agents/{{AGENT_NAME}}.md",
        "template": "manager-agent-7-phase.md.template",
        "parameters": {
          "MANAGER_NAME": "{{AGENT_NAME}}",
          "PHASE_COUNT": 7
        }
      },
      {
        "step": 2,
        "action": "delete",
        "file": "skills/{{SKILL_NAME}}/SKILL.md",
        "backup": true
      }
    ]
  },
  "migration": {
    "guide": "docs/migration/manager-inversion-fix.md"
  }
}
```

### Template 2: Agent Chain Refactor

```json
{
  "conversion_id": "conv-YYYYMMDD-NNN",
  "version": "1.0",
  "type": "agent-chain-refactor",
  "severity": "critical",
  "plugin": {
    "name": "{{PLUGIN_NAME}}",
    "path": "{{PLUGIN_PATH}}"
  },
  "anti_pattern": {
    "type": "agent-chain",
    "description": "Sequential agent invocations",
    "affected_files": [
      "agents/{{AGENT_1}}.md",
      "agents/{{AGENT_2}}.md",
      "agents/{{AGENT_3}}.md"
    ],
    "evidence": [
      {
        "file": "agents/{{AGENT_1}}.md",
        "issue": "Invokes {{AGENT_2}}",
        "severity": "critical"
      }
    ]
  },
  "conversion_plan": {
    "steps": [
      {
        "step": 1,
        "action": "create",
        "file": "agents/{{MANAGER_NAME}}.md",
        "template": "manager-agent-7-phase.md.template"
      },
      {
        "step": 2,
        "action": "move",
        "from": "agents/{{AGENT_2}}.md",
        "to": "skills/{{SKILL_2}}/SKILL.md"
      },
      {
        "step": 3,
        "action": "move",
        "from": "agents/{{AGENT_3}}.md",
        "to": "skills/{{SKILL_3}}/SKILL.md"
      },
      {
        "step": 4,
        "action": "delete",
        "file": "agents/{{AGENT_1}}.md",
        "backup": true
      }
    ]
  },
  "estimated_impact": {
    "context_reduction_tokens": 45000,
    "context_reduction_percent": 75
  },
  "migration": {
    "guide": "docs/migration/agent-chain-to-skills.md"
  }
}
```

### Template 3: Script Extraction

```json
{
  "conversion_id": "conv-YYYYMMDD-NNN",
  "version": "1.0",
  "type": "script-extraction",
  "severity": "warning",
  "plugin": {
    "name": "{{PLUGIN_NAME}}",
    "path": "{{PLUGIN_PATH}}"
  },
  "anti_pattern": {
    "type": "inline-scripts",
    "description": "Bash commands in markdown instead of scripts/",
    "affected_files": [
      "skills/{{SKILL_NAME}}/SKILL.md"
    ],
    "evidence": [
      {
        "file": "skills/{{SKILL_NAME}}/SKILL.md",
        "issue": "Contains {{COUNT}} bash commands",
        "severity": "warning"
      },
      {
        "file": "skills/{{SKILL_NAME}}/",
        "issue": "No scripts/ directory",
        "severity": "warning"
      }
    ]
  },
  "conversion_plan": {
    "steps": [
      {
        "step": 1,
        "action": "create",
        "file": "skills/{{SKILL_NAME}}/scripts/{{OPERATION}}.sh",
        "reason": "Extract bash operations to script"
      },
      {
        "step": 2,
        "action": "modify",
        "file": "skills/{{SKILL_NAME}}/SKILL.md",
        "reason": "Replace inline bash with script calls"
      }
    ]
  },
  "estimated_impact": {
    "context_reduction_tokens": 1500,
    "context_reduction_percent": 75
  },
  "migration": {
    "guide": "docs/migration/script-extraction.md"
  }
}
```

---

## Validation

### Validate a Spec

```bash
/fractary-faber-agent:validate-spec /path/to/spec.json
```

**Checks:**
- ✓ Valid JSON structure
- ✓ Required fields present
- ✓ Valid field types
- ✓ Valid enum values
- ✓ File paths exist (for affected files)
- ✓ Templates exist (if specified)
- ✓ Migration guide exists

**Example output:**
```
✅ Conversion Spec Validation

File: conv-20250111-001.json

Structure:
  ✓ Valid JSON
  ✓ All required fields present
  ✓ Valid field types

Content:
  ✓ Conversion ID format correct
  ✓ Severity valid (critical)
  ✓ Type valid (manager-as-skill-inversion)
  ✓ Plugin path exists
  ✓ Affected files exist
  ✓ Templates exist
  ✓ Migration guide exists

Conversion Plan:
  ✓ 3 steps defined
  ✓ Step actions valid
  ✓ No circular dependencies

Overall: ✅ VALID
```

---

## Best Practices

### 1. Use Descriptive Conversion IDs

```json
// ✓ Good - includes type and date
"conversion_id": "conv-manager-inversion-deployment-20250111"

// ❌ Bad - generic
"conversion_id": "conv-001"
```

### 2. Provide Clear Evidence

```json
"evidence": [
  {
    "file": "skills/orchestrator/SKILL.md",
    "issue": "Has <WORKFLOW> section with 7 phases",  // ✓ Specific
    "line": 15,
    "severity": "critical"
  }
]

// ❌ Bad - vague
"evidence": [{"issue": "Wrong pattern"}]
```

### 3. Include Detailed Steps

```json
{
  "step": 1,
  "action": "create",
  "file": "agents/my-manager.md",
  "reason": "Convert orchestrator from Skill to Agent",  // ✓ Why
  "template": "manager-agent-7-phase.md.template",      // ✓ How
  "parameters": {...}                                    // ✓ Details
}
```

### 4. Estimate Impact Accurately

```json
"estimated_impact": {
  "context_reduction_tokens": 5000,        // Calculate based on file sizes
  "new_capabilities": [                     // List concrete benefits
    "User approval gates",
    "State management"
  ],
  "breaking_changes": false                 // Be honest
}
```

### 5. Always Backup Before Deletes

```json
{
  "action": "delete",
  "file": "skills/old-skill/SKILL.md",
  "backup": true,                           // ✓ Always backup
  "backup_location": ".backup/..."
}
```

### 6. Provide Rollback Steps

```json
"rollback": {
  "supported": true,
  "steps": [
    {
      "step": 1,
      "action": "restore",
      "file": "skills/old-skill/SKILL.md",
      "from_backup": ".backup/..."
    }
  ]
}
```

---

## Common Mistakes

### Mistake 1: Missing Required Fields

```json
{
  "conversion_id": "conv-001",
  "type": "manager-as-skill-inversion"
  // ❌ Missing: version, severity, plugin, anti_pattern, conversion_plan
}
```

### Mistake 2: Invalid Step Actions

```json
{
  "action": "update"  // ❌ Invalid - should be "modify"
}
```

**Valid actions:** `create`, `modify`, `delete`, `move`, `extract`

### Mistake 3: No Reason for Steps

```json
{
  "action": "delete",
  "file": "skills/old.md"
  // ❌ Missing "reason" field
}
```

### Mistake 4: Circular Dependencies

```json
"steps": [
  {
    "step": 1,
    "action": "modify",
    "file": "agents/a.md",
    "depends_on": "agents/b.md"
  },
  {
    "step": 2,
    "action": "modify",
    "file": "agents/b.md",
    "depends_on": "agents/a.md"  // ❌ Circular dependency
  }
]
```

---

## Next Steps

- Create custom conversion specs for your anti-patterns
- Validate specs before applying
- Test conversions in non-production first
- Document custom patterns in migration guides
- Share specs with team for review

For related guides, see:
- [Audit Usage Guide](audit-usage-guide.md)
- [Workflow Creation Guide](workflow-creation-guide.md)
- [Migration Guides](../migration/)
