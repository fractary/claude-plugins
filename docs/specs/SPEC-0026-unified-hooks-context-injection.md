# SPEC-0026: Unified Hooks and Context Injection System

**Status**: Draft
**Created**: 2025-11-12
**Author**: System
**Supersedes**: N/A
**Related**: SPEC-0002 (FABER Architecture)

## Overview

This specification defines a **unified hook and context injection system** for Fractary plugins that enables project-specific customization without requiring wrapper commands. It extends the proven hook patterns from `faber-cloud` to all plugins and introduces **prompt-based context injection** for documentation and standards.

## Problem Statement

### Current State

- **faber-cloud** has mature hooks (script + skill types)
- **repo** has session lifecycle hooks
- **docs** has document generation hooks
- **No hooks exist for FABER workflow phases**
- **No unified configuration format across plugins**
- **No mechanism to inject context/documentation via config**

### Pain Points

1. **Repetitive Wrapper Commands**: Projects create lightweight wrapper commands just to inject project-specific context
2. **Inconsistent Hook Patterns**: Each plugin implements hooks differently
3. **Script-Heavy Customization**: Most hooks are shell scripts, not discoverable/testable
4. **No Context Injection**: Can't reference standards/guides without code changes
5. **Limited Phase Extensibility**: Can't customize FABER phases without skill overrides

### Desired Outcome

- **Single hook configuration format** across all plugins
- **Context injection via config** (reference docs, add prompt context)
- **FABER phase hooks** (pre/post Frame, Architect, Build, Evaluate, Release)
- **Eliminate wrapper commands** by making baseline plugins fully customizable
- **Backward compatible** with existing hook implementations

## Design

### 1. Hook Types

Extend the proven `faber-cloud` pattern with a new **prompt/context** type:

#### A. Script Hooks (Existing)

Execute shell scripts with environment variables:

```json
{
  "type": "script",
  "path": "./scripts/setup-environment.sh",
  "name": "setup-env",
  "required": true,
  "failureMode": "stop",
  "timeout": 300,
  "environments": ["test", "prod"]
}
```

**Use Cases**: Build steps, validation, deployment preparation

#### B. Skill Hooks (Existing)

Invoke Claude Code skills with structured interfaces:

```json
{
  "type": "skill",
  "name": "dataset-validator",
  "required": true,
  "failureMode": "stop",
  "timeout": 300,
  "description": "Validate data integrity"
}
```

**Use Cases**: Complex validation, decision-making, orchestration

#### C. **Context Hooks (NEW)**

Inject additional context/prompts into the agent's execution:

```json
{
  "type": "context",
  "name": "project-standards",
  "prompt": "Apply the coding standards defined in STANDARDS.md when implementing changes.",
  "references": [
    {
      "path": "STANDARDS.md",
      "description": "Project coding standards",
      "sections": ["Code Style", "Testing Requirements"]
    },
    {
      "path": "docs/architecture/patterns.md",
      "description": "Architectural patterns",
      "sections": ["Database Access", "API Design"]
    }
  ],
  "weight": "high"
}
```

**Use Cases**:
- Project-specific coding standards
- Architectural guidance
- Testing requirements
- Documentation templates
- Domain-specific constraints

#### D. **Prompt Hooks (NEW - Lightweight Variant)**

Simple text injection without file references:

```json
{
  "type": "prompt",
  "name": "production-reminder",
  "content": "CRITICAL: This is a production deployment. Triple-check all changes before proceeding.",
  "weight": "critical",
  "environments": ["prod"]
}
```

**Use Cases**:
- Environment-specific reminders
- Quick guidance without external files
- Critical safety checks

### 2. Hook Configuration Format

#### Unified Structure (All Plugins)

**Location Options**:
- `.faber.config.toml` → `[hooks]` section
- `.fractary/plugins/{plugin}/config.json` → `hooks` object
- Plugin-specific config files

**TOML Format** (FABER):

```toml
[hooks]

# Workflow phase hooks
[[hooks.frame.pre]]
type = "context"
name = "project-context"
prompt = "Use the project's established patterns for work item classification."
references = [
  { path = "docs/WORK_CLASSIFICATION.md", description = "Work classification rules" }
]

[[hooks.architect.pre]]
type = "prompt"
name = "architecture-standards"
content = "Follow the microservices patterns documented in our architecture guide."
weight = "high"

[[hooks.architect.pre]]
type = "context"
name = "design-standards"
references = [
  { path = "docs/architecture/DESIGN_STANDARDS.md", description = "Design standards" },
  { path = "docs/architecture/API_PATTERNS.md", description = "API design patterns" }
]

[[hooks.build.pre]]
type = "script"
path = "./scripts/setup-build-env.sh"
name = "setup-build"
required = true
timeout = 120

[[hooks.build.post]]
type = "skill"
name = "custom-code-review"
required = false
description = "Run project-specific code review checks"

[[hooks.evaluate.pre]]
type = "context"
name = "testing-standards"
prompt = "Ensure all tests follow the patterns in our testing guide."
references = [
  { path = "docs/TESTING_GUIDE.md", description = "Testing standards and patterns" }
]

[[hooks.release.pre]]
type = "prompt"
name = "release-checklist"
content = """
Before releasing, verify:
- All tests pass
- Documentation is updated
- Migration scripts are reviewed
- Monitoring alerts are configured
"""
weight = "critical"

[[hooks.release.pre]]
type = "context"
name = "changelog-format"
references = [
  { path = ".github/CHANGELOG_TEMPLATE.md", description = "Changelog format" }
]
```

**JSON Format** (Plugin Configs):

```json
{
  "hooks": {
    "frame": {
      "pre": [
        {
          "type": "context",
          "name": "project-context",
          "prompt": "Use the project's established patterns.",
          "references": [
            {
              "path": "docs/WORK_CLASSIFICATION.md",
              "description": "Work classification rules"
            }
          ]
        }
      ],
      "post": []
    },
    "architect": {
      "pre": [
        {
          "type": "prompt",
          "name": "architecture-standards",
          "content": "Follow the microservices patterns.",
          "weight": "high"
        }
      ],
      "post": []
    }
  }
}
```

### 3. Hook Execution Lifecycle

#### Phase Execution with Hooks

```
Start Phase (e.g., "architect")
  ↓
Execute pre-phase hooks (in order):
  1. Context hooks → Inject prompts + load referenced docs
  2. Prompt hooks → Inject prompt text
  3. Script hooks → Execute shell scripts
  4. Skill hooks → Invoke Claude Code skills
  ↓
Execute phase with injected context
  ↓
Execute post-phase hooks (in order):
  1. Script hooks → Execute shell scripts
  2. Skill hooks → Invoke Claude Code skills
  3. Context hooks → (optional: validate outputs)
  ↓
Complete Phase
```

#### Context Hook Execution

When a context hook is encountered:

```markdown
1. Read hook configuration (prompt, references, weight)
2. Load referenced documents from filesystem
3. Build context injection block:

   ```
   ═══════════════════════════════════════════════════════════
   📋 PROJECT CONTEXT: {hook.name}
   ═══════════════════════════════════════════════════════════

   {hook.prompt}

   ## Referenced Documentation

   ### {reference.description}
   Source: {reference.path}
   {reference.sections ? "Sections: " + sections.join(", ") : ""}

   {file_content}

   ═══════════════════════════════════════════════════════════
   ```

4. Inject into agent's context at appropriate point
5. Track context injection in workflow state
```

#### Weight/Priority System

```
critical → Always included, shown at top
high     → Always included
medium   → Included (default)
low      → Included if context budget allows
```

### 4. FABER Integration

#### A. Phase Hook Points

Each FABER phase supports hooks:

| Phase | Hook Points | Purpose |
|-------|-------------|---------|
| **Frame** | `pre`, `post` | Setup, work item classification, environment prep |
| **Architect** | `pre`, `post` | Design guidance, spec templates, standards |
| **Build** | `pre`, `post` | Build setup, validation, code review |
| **Evaluate** | `pre`, `post` | Test requirements, quality gates, validation |
| **Release** | `pre`, `post` | Deployment checks, changelog, documentation |

#### B. Workflow Manager Integration

The `workflow-manager.md` agent needs minimal changes:

```markdown
<WORKFLOW>
## Phase Execution Pattern

For each phase (frame, architect, build, evaluate, release):

1. **Load Configuration**
   - Read `.faber.config.toml` hooks section
   - Read `.fractary/plugins/faber/config.json` hooks

2. **Execute Pre-Phase Hooks**
   - Run hooks in order: context → prompt → script → skill
   - Inject context hooks into agent's context
   - Execute script/skill hooks via bash/skill invocation

3. **Execute Phase with Context**
   - Invoke phase skill (e.g., `frame`, `architect`)
   - Phase skill receives injected context
   - Phase executes normally with additional context

4. **Execute Post-Phase Hooks**
   - Run hooks in order: script → skill → context (validation)
   - Validate outputs if context hooks specify validation

5. **Handle Hook Failures**
   - `failureMode: stop` → Halt workflow, report error
   - `failureMode: warn` → Log warning, continue
   - `required: false` → Optional, always continue
</WORKFLOW>
```

#### C. Hook Invocation Utility

Create a reusable skill for hook execution:

**File**: `plugins/faber/skills/hook-executor/SKILL.md`

```markdown
# Hook Executor Skill

<CONTEXT>
You are the hook executor skill for FABER plugins. You handle execution of
all hook types (script, skill, context, prompt) at appropriate lifecycle points.
</CONTEXT>

<CRITICAL_RULES>
- Execute hooks in declared order
- Respect failureMode settings (stop vs warn)
- Apply environment filtering before execution
- Track hook execution state for debugging
- Never skip required hooks
</CRITICAL_RULES>

<INPUTS>
- `hookType`: "pre" | "post"
- `phase`: "frame" | "architect" | "build" | "evaluate" | "release"
- `workflowContext`: Current workflow state
- `hooks`: Array of hook configurations
</INPUTS>

<WORKFLOW>
For each hook in hooks array:

1. **Filter by Environment**
   - If hook.environments specified, check current environment
   - Skip if current environment not in list

2. **Execute by Type**

   **Context Hook**:
   - Read hook.prompt
   - Load all referenced files from hook.references[]
   - Build context injection block with formatting
   - Return context block for injection into agent prompt

   **Prompt Hook**:
   - Read hook.content
   - Build simple prompt block with formatting
   - Return prompt block for injection

   **Script Hook**:
   - Resolve hook.path (support template variables)
   - Set environment variables (FABER_*, AWS_*, etc.)
   - Execute script via Bash tool
   - Capture output and exit code
   - Handle failure per hook.failureMode

   **Skill Hook**:
   - Build WorkflowContext JSON
   - Invoke skill via Skill tool
   - Parse WorkflowResult JSON
   - Handle failure per hook.failureMode

3. **Timeout Enforcement**
   - Set timeout for script/skill execution
   - Kill if exceeds hook.timeout seconds

4. **Failure Handling**
   - `required: true` + `failureMode: stop` → Halt, return error
   - `required: true` + `failureMode: warn` → Log warning, continue
   - `required: false` → Always continue

5. **Track Execution**
   - Log hook execution (name, type, duration, result)
   - Return execution summary
</WORKFLOW>

<OUTPUTS>
Return JSON:
```json
{
  "executed": [
    {
      "name": "project-standards",
      "type": "context",
      "duration_ms": 45,
      "status": "success",
      "contextInjection": "📋 PROJECT CONTEXT: project-standards\n..."
    }
  ],
  "failed": [],
  "skipped": [
    {
      "name": "prod-only-check",
      "reason": "environment_mismatch"
    }
  ]
}
```
</OUTPUTS>
</markdown>
```

### 5. Context Injection Format

#### Context Hook Output Format

```markdown
═══════════════════════════════════════════════════════════
📋 PROJECT CONTEXT: {hook.name}
Priority: {hook.weight}
═══════════════════════════════════════════════════════════

{hook.prompt}

## Referenced Documentation

### {reference[0].description}
**Source**: `{reference[0].path}`
**Sections**: {reference[0].sections.join(", ")}

{content of reference[0].path}

---

### {reference[1].description}
**Source**: `{reference[1].path}`

{content of reference[1].path}

═══════════════════════════════════════════════════════════
```

#### Prompt Hook Output Format

```markdown
─────────────────────────────────────────────────────────
⚠️  PROMPT: {hook.name}
Priority: {hook.weight}
─────────────────────────────────────────────────────────

{hook.content}

─────────────────────────────────────────────────────────
```

#### Example Combined Output (in Architect Phase)

```markdown
<INJECTED_CONTEXT>
═══════════════════════════════════════════════════════════
📋 PROJECT CONTEXT: design-standards
Priority: high
═══════════════════════════════════════════════════════════

Follow the architectural patterns and design standards documented below.

## Referenced Documentation

### Design Standards
**Source**: `docs/architecture/DESIGN_STANDARDS.md`

# Design Standards

## Microservices Architecture
- Each service owns its data
- Communication via REST APIs
- Event-driven where appropriate

[... full content ...]

═══════════════════════════════════════════════════════════

─────────────────────────────────────────────────────────
⚠️  PROMPT: api-versioning
Priority: high
─────────────────────────────────────────────────────────

All APIs must use semantic versioning (v1, v2, etc.).
Breaking changes require a new major version.

─────────────────────────────────────────────────────────
</INJECTED_CONTEXT>
```

### 6. Configuration Schema

#### Hook Configuration Schema (JSON Schema)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "hooks": {
      "type": "object",
      "properties": {
        "frame": {"$ref": "#/definitions/phaseHooks"},
        "architect": {"$ref": "#/definitions/phaseHooks"},
        "build": {"$ref": "#/definitions/phaseHooks"},
        "evaluate": {"$ref": "#/definitions/phaseHooks"},
        "release": {"$ref": "#/definitions/phaseHooks"}
      }
    }
  },
  "definitions": {
    "phaseHooks": {
      "type": "object",
      "properties": {
        "pre": {
          "type": "array",
          "items": {"$ref": "#/definitions/hook"}
        },
        "post": {
          "type": "array",
          "items": {"$ref": "#/definitions/hook"}
        }
      }
    },
    "hook": {
      "type": "object",
      "required": ["type", "name"],
      "properties": {
        "type": {
          "enum": ["script", "skill", "context", "prompt"]
        },
        "name": {"type": "string"},
        "required": {"type": "boolean", "default": false},
        "failureMode": {
          "enum": ["stop", "warn"],
          "default": "stop"
        },
        "timeout": {"type": "integer", "default": 300},
        "environments": {
          "type": "array",
          "items": {"type": "string"}
        }
      },
      "allOf": [
        {
          "if": {"properties": {"type": {"const": "script"}}},
          "then": {
            "required": ["path"],
            "properties": {
              "path": {"type": "string"},
              "description": {"type": "string"}
            }
          }
        },
        {
          "if": {"properties": {"type": {"const": "skill"}}},
          "then": {
            "required": ["name"],
            "properties": {
              "description": {"type": "string"}
            }
          }
        },
        {
          "if": {"properties": {"type": {"const": "context"}}},
          "then": {
            "properties": {
              "prompt": {"type": "string"},
              "references": {
                "type": "array",
                "items": {
                  "type": "object",
                  "required": ["path", "description"],
                  "properties": {
                    "path": {"type": "string"},
                    "description": {"type": "string"},
                    "sections": {
                      "type": "array",
                      "items": {"type": "string"}
                    }
                  }
                }
              },
              "weight": {
                "enum": ["critical", "high", "medium", "low"],
                "default": "medium"
              }
            }
          }
        },
        {
          "if": {"properties": {"type": {"const": "prompt"}}},
          "then": {
            "required": ["content"],
            "properties": {
              "content": {"type": "string"},
              "weight": {
                "enum": ["critical", "high", "medium", "low"],
                "default": "medium"
              }
            }
          }
        }
      ]
    }
  }
}
```

### 7. Implementation Plan

#### Phase 1: Core Infrastructure

1. **Create hook executor skill**
   - `plugins/faber/skills/hook-executor/SKILL.md`
   - `plugins/faber/skills/hook-executor/scripts/execute-hooks.sh`
   - `plugins/faber/skills/hook-executor/scripts/load-context.sh`

2. **Update workflow-manager**
   - Add hook execution before/after each phase
   - Inject context from context/prompt hooks
   - Pass workflow context to hooks

3. **Add configuration schema**
   - JSON schema for hook validation
   - TOML schema for `.faber.config.toml`
   - Configuration loading utilities

#### Phase 2: Hook Types

4. **Implement context hooks**
   - Document loading with path resolution
   - Section extraction (if specified)
   - Context injection formatting
   - Weight/priority handling

5. **Implement prompt hooks**
   - Simple text injection
   - Weight/priority handling
   - Environment filtering

6. **Extend script/skill hooks**
   - Add FABER-specific environment variables
   - Add WorkflowContext interface
   - Add template variable support

#### Phase 3: Documentation & Examples

7. **Create hook documentation**
   - User guide for hooks configuration
   - Examples for each hook type
   - Migration guide from wrapper commands

8. **Create example configurations**
   - Common patterns (testing, standards, deployment)
   - Domain-specific examples (app, cloud, data)
   - Complete project examples

9. **Update plugin standards**
   - Add hook patterns to standards doc
   - Add configuration guidelines
   - Add best practices

#### Phase 4: Plugin Adoption

10. **Add hooks to faber-app**
    - Application-specific hook points
    - Testing and quality gate hooks
    - Deployment hooks

11. **Add hooks to faber-cloud**
    - Extend existing hooks with context type
    - Infrastructure standards injection
    - Cloud provider guidance

12. **Add hooks to primitive plugins**
    - work: Work item hooks
    - repo: Repository operation hooks
    - file: File operation hooks

### 8. Backward Compatibility

#### Existing Hooks (faber-cloud)

- **All existing script/skill hooks continue to work**
- Configuration format is identical
- Environment variables preserved
- WorkflowContext interface unchanged

#### Migration Path

Projects can adopt incrementally:

1. **Phase 1**: Keep existing wrapper commands, add simple prompt hooks
2. **Phase 2**: Add context hooks for standards/docs
3. **Phase 3**: Remove wrapper commands, fully config-driven

#### Deprecation Policy

- No deprecations required
- New features are purely additive
- Existing patterns remain valid

### 9. Benefits

#### For Users

- **No wrapper commands needed**: Configure via `.faber.config.toml`
- **Inject project context**: Reference standards, guides, patterns
- **Environment-specific behavior**: Filter hooks by environment
- **Discoverable hooks**: Config-driven, not code-driven
- **Testable customization**: Skill hooks > shell scripts

#### For Plugin Authors

- **Consistent pattern**: Same hook system across all plugins
- **Minimal implementation**: Reuse hook-executor skill
- **Extensible**: Add new hook types as needed
- **Well-documented**: Standards and examples provided

#### For the Ecosystem

- **Reduces custom code**: Projects use baseline plugins
- **Improves maintainability**: Configuration > code
- **Enables sharing**: Hook patterns can be shared across projects
- **Better defaults**: Plugins work out of box, customize via config

### 10. Examples

#### Example 1: Inject Coding Standards

`.faber.config.toml`:
```toml
[[hooks.build.pre]]
type = "context"
name = "coding-standards"
prompt = "Follow the coding standards and patterns defined in our documentation."
references = [
  { path = "docs/CODING_STANDARDS.md", description = "Coding standards" },
  { path = "docs/TESTING_PATTERNS.md", description = "Testing patterns" }
]
weight = "high"
```

**Result**: The Build phase includes your standards as context, no wrapper command needed.

#### Example 2: Environment-Specific Reminders

`.faber.config.toml`:
```toml
[[hooks.release.pre]]
type = "prompt"
name = "production-warning"
content = """
⚠️  PRODUCTION RELEASE

This release will deploy to production. Verify:
- All tests pass
- Database migrations are backward compatible
- Feature flags are properly configured
- Rollback plan is documented
"""
weight = "critical"
environments = ["prod"]
```

**Result**: Only shown for production releases, provides critical checklist.

#### Example 3: Custom Build Validation

`.faber.config.toml`:
```toml
[[hooks.build.post]]
type = "skill"
name = "security-scanner"
description = "Run security scanning on built artifacts"
required = true
failureMode = "stop"
timeout = 600
```

**Result**: Custom security checks run after every build, blocking release if they fail.

#### Example 4: Reference Multiple Guides

`.faber.config.toml`:
```toml
[[hooks.architect.pre]]
type = "context"
name = "architecture-guidance"
prompt = "Design the solution following our established architectural patterns and API standards."
references = [
  { path = "docs/architecture/MICROSERVICES.md", description = "Microservices patterns" },
  { path = "docs/architecture/API_DESIGN.md", description = "API design guide", sections = ["Versioning", "Error Handling"] },
  { path = "docs/architecture/DATABASE.md", description = "Database patterns", sections = ["Schema Design"] }
]
weight = "high"
```

**Result**: Architect phase has access to relevant sections of multiple guides.

### 11. Open Questions

1. **Context Budget Management**: How do we handle context limit when many hooks inject large docs?
   - Proposed: Weight-based pruning (drop low-weight hooks first)
   - Proposed: Section-based extraction (only include specified sections)
   - Proposed: Summarization (use LLM to summarize long docs)

2. **Hook Discovery**: Should we provide a `/faber:hooks` command to list available hooks?
   - Proposed: Yes, show configured hooks and their status

3. **Hook Testing**: How should users test their hook configurations?
   - Proposed: `--dry-run` mode that shows what hooks would execute
   - Proposed: Hook validation command that checks config syntax

4. **Cross-Plugin Hooks**: Should hooks in one plugin be able to reference hooks from another?
   - Proposed: No, keep plugins isolated. Use project-level hooks for cross-cutting concerns.

5. **Hook Composition**: Should hooks support dependencies (hook A must run before hook B)?
   - Proposed: Not initially. Use hook order in config. Add if needed later.

## References

### Related Documentation

- `plugins/faber-cloud/docs/guides/HOOKS.md` - Existing hook implementation
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md` - Plugin development standards
- `docs/specs/SPEC-0002-faber-architecture.md` - FABER architecture

### Prior Art

- **faber-cloud hooks**: Proven pattern for infrastructure lifecycle
- **repo session hooks**: Session lifecycle management
- **docs generation hooks**: Document lifecycle integration
- **GitHub Actions**: Workflow hook model
- **Git hooks**: Event-driven script execution

## Changelog

- 2025-11-12: Initial draft
