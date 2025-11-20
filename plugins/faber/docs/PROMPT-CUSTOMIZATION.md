# FABER Prompt Customization Guide

Complete guide to customizing FABER workflows using the `prompt` field for powerful, flexible workflow control.

## Table of Contents

- [Overview](#overview)
- [Core Concepts](#core-concepts)
- [Execution Patterns](#execution-patterns)
- [Customization Examples](#customization-examples)
- [Advanced Techniques](#advanced-techniques)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)

## Overview

FABER v2.0 introduces the `prompt` field, enabling two powerful capabilities:

1. **Direct Claude Execution** - Steps without skills can execute custom logic via prompt
2. **Skill Customization** - Steps with skills can customize plugin behavior without forking

This makes workflows highly adaptable to project-specific requirements while maintaining the benefits of reusable plugin skills.

## Core Concepts

### The Hybrid Execution Model

FABER supports three execution modes:

```
┌─────────────────────────────────────────┐
│  Step Configuration                     │
├─────────────────────────────────────────┤
│                                         │
│  Has skill?                             │
│    ├─ Yes → Invoke plugin skill         │
│    │         └─ Has prompt? Customize!  │
│    │                                    │
│    └─ No  → Direct Claude execution    │
│              └─ Use prompt or description│
│                                         │
└─────────────────────────────────────────┘
```

### Field Purposes

| Field | Purpose | Required | Usage |
|-------|---------|----------|-------|
| `name` | Step identifier | Yes | References, logging |
| `description` | Documentation | Recommended | Human understanding |
| `prompt` | Execution instruction | Optional | Claude behavior |
| `skill` | Plugin reference | Optional | Reusable operations |
| `config` | Skill parameters | Optional | Skill configuration |

## Execution Patterns

### Pattern 1: Pure Skill Execution

**Use Case**: Standard plugin operation with default behavior

```json
{
  "name": "fetch-work",
  "description": "Fetch work item details from issue tracker",
  "skill": "fractary-work:issue-fetcher"
}
```

**Execution**:
- ✅ Skill invoked with default parameters
- ✅ Description used for logs and documentation
- ✅ Reliable, tested, reusable behavior

**When to use**: Standard operations that don't need customization

---

### Pattern 2: Customized Skill Execution

**Use Case**: Plugin operation with project-specific requirements

```json
{
  "name": "create-pr",
  "description": "Create pull request for review",
  "skill": "fractary-repo:pr-manager",
  "prompt": "Create PR with: 1) Summary of changes, 2) Testing checklist, 3) Screenshots if UI changes, 4) FABER attribution",
  "config": {
    "draft_if_assist": true,
    "auto_link_issue": true
  }
}
```

**Execution**:
- ✅ Skill invoked with customized behavior via prompt
- ✅ Config parameters still apply
- ✅ No need to fork plugin for small changes

**When to use**: Need slight customization beyond config parameters

---

### Pattern 3: Direct Claude Execution

**Use Case**: Project-specific logic that doesn't fit existing plugins

```json
{
  "name": "update-changelog",
  "description": "Update CHANGELOG.md with release notes",
  "prompt": "Update CHANGELOG.md following Keep a Changelog format. Add new entry under [Unreleased] with: Added, Changed, Fixed, Removed sections based on commits since last release."
}
```

**Execution**:
- ✅ Claude executes directly using prompt
- ✅ Full flexibility for custom workflows
- ✅ Perfect for project-specific patterns

**When to use**: Custom logic unique to your project

---

### Pattern 4: Legacy Compatibility

**Use Case**: Existing configs without prompt field

```json
{
  "name": "implement",
  "description": "Implement solution based on specification"
}
```

**Execution**:
- ✅ Description used as prompt (backward compatible)
- ⚠️ Less clear that it's an execution instruction
- 💡 Recommended to add explicit `prompt` field

**When to use**: Migrating from v1.x, temporary solution

---

## Customization Examples

### Example 1: Testing with Coverage Requirements

**Default** (no customization):
```json
{
  "name": "test",
  "description": "Run automated tests",
  "prompt": "Run tests and report results"
}
```

**Customized** (project requirements):
```json
{
  "name": "test",
  "description": "Run automated test suite with coverage tracking",
  "prompt": "Run all tests with coverage enabled. Require: 1) All tests pass, 2) Coverage >= 80% for new code, 3) No regression in overall coverage. Report: test count, pass/fail, coverage %, any warnings."
}
```

**Result**: Tests run with specific coverage requirements enforced.

---

### Example 2: Code Review Standards

**Default**:
```json
{
  "name": "review",
  "description": "Code review and quality checks"
}
```

**Customized for startup**:
```json
{
  "name": "review",
  "description": "Lightweight code review focused on velocity",
  "prompt": "Quick code review focusing on: 1) Correctness (does it work?), 2) Security (any obvious vulnerabilities?), 3) Readability (can team understand it?). Skip: style nitpicks, perfect test coverage, extensive documentation. Goal: ship fast while staying safe."
}
```

**Customized for enterprise**:
```json
{
  "name": "review",
  "description": "Comprehensive code review with compliance checks",
  "prompt": "Thorough code review checking: 1) Correctness & edge cases, 2) Security (OWASP Top 10), 3) Performance implications, 4) Test coverage (95%+ required), 5) Documentation completeness, 6) Accessibility (WCAG 2.1 AA), 7) Compliance (SOC2 controls). Generate detailed report."
}
```

**Result**: Same step, dramatically different execution based on organizational needs.

---

### Example 3: Customizing Commit Creation

**Using skill with default behavior**:
```json
{
  "name": "commit",
  "description": "Create semantic commit",
  "skill": "fractary-repo:commit-creator"
}
```

**Customizing skill behavior**:
```json
{
  "name": "commit",
  "description": "Create commit following team conventions",
  "skill": "fractary-repo:commit-creator",
  "prompt": "Create commit with: 1) Conventional commit format (type(scope): message), 2) Link to work item in footer, 3) Co-author: Claude, 4) Include 'Closes #123' if work complete, 5) Add [skip ci] if docs-only change"
}
```

**Result**: Skill still handles git operations, but commit message follows team-specific conventions.

---

### Example 4: Implementation Style Guidance

**Generic**:
```json
{
  "name": "implement",
  "description": "Implement solution",
  "prompt": "Implement based on specification"
}
```

**TDD-focused team**:
```json
{
  "name": "implement",
  "description": "Implement using Test-Driven Development",
  "prompt": "Implement following TDD: 1) Write failing test first, 2) Implement minimal code to pass, 3) Refactor for clarity, 4) Repeat for each requirement. Ensure: 100% branch coverage, clear test names, no implementation without tests."
}
```

**Prototype/MVP team**:
```json
{
  "name": "implement",
  "description": "Implement MVP solution quickly",
  "prompt": "Implement quick MVP focusing on: 1) Core functionality (happy path), 2) Basic error handling, 3) Inline comments for edge cases to address later, 4) TODOs for production hardening. Skip: extensive validation, performance optimization, exhaustive tests. Goal: validate concept fast."
}
```

**Result**: Same phase, completely different implementation philosophy.

---

## Advanced Techniques

### Technique 1: Context-Aware Prompts

Use prompts that reference workflow state:

```json
{
  "name": "implement",
  "description": "Context-aware implementation",
  "prompt": "Implement based on specification in .fractary/specs/. If spec includes performance requirements, add benchmarks. If spec mentions breaking changes, update migration guide. If spec references specific libraries, use those versions from package.json."
}
```

### Technique 2: Conditional Logic in Prompts

```json
{
  "name": "deploy",
  "description": "Deploy to appropriate environment",
  "prompt": "Deploy based on branch: main → production (require manual approval), develop → staging (automatic), feature/* → preview environment (automatic, ephemeral). Use deployment checklist from .github/deploy-checklist.md"
}
```

### Technique 3: Multi-Step Instructions

```json
{
  "name": "database-migration",
  "description": "Safe database migration",
  "prompt": "Execute database migration safely: 1) Backup current schema, 2) Run migration in transaction, 3) Verify data integrity with checksums, 4) Test rollback procedure, 5) Document changes in migrations/README.md, 6) Only commit if all validations pass"
}
```

### Technique 4: Tool-Specific Instructions

```json
{
  "name": "lint-and-format",
  "description": "Code quality enforcement",
  "prompt": "Run linting and formatting: 1) eslint --fix for JS/TS, 2) prettier --write for all files, 3) cargo fmt for Rust, 4) black for Python. If any linting errors remain after auto-fix, report them and request guidance. Commit formatting changes separately if substantial."
}
```

---

## Best Practices

### 1. Keep Prompts Focused

❌ **Too Vague**:
```json
"prompt": "Do the testing"
```

❌ **Too Detailed** (belongs in docs):
```json
"prompt": "Testing is critical because... [300 word essay]... therefore run: npm test"
```

✅ **Just Right**:
```json
"prompt": "Run full test suite (npm test), verify 80%+ coverage, report any failures with stack traces"
```

### 2. Use Description for "What", Prompt for "How"

✅ **Good Separation**:
```json
{
  "description": "Create pull request for code review",
  "prompt": "Create PR with summary, testing notes, and link to issue #123"
}
```

❌ **Redundant**:
```json
{
  "description": "Create PR with summary, testing notes, and link to issue",
  "prompt": "Create PR with summary, testing notes, and link to issue"
}
```

### 3. Make Prompts Actionable

❌ **Passive/Vague**:
```json
"prompt": "The code should be checked"
```

✅ **Active/Clear**:
```json
"prompt": "Run static analysis: mypy for type checking, bandit for security, report any HIGH severity issues"
```

### 4. Reference Project Conventions

✅ **Project-Aware**:
```json
"prompt": "Follow coding standards in CONTRIBUTING.md, use project error handling patterns from src/utils/errors.ts"
```

### 5. Specify Success Criteria

✅ **Clear Completion**:
```json
"prompt": "Refactor for performance. Success: 1) Response time < 200ms, 2) Memory usage reduced 20%+, 3) All existing tests pass"
```

---

## Common Patterns

### Pattern: Different Rules by File Type

```json
{
  "name": "implement",
  "description": "Implement with language-specific best practices",
  "prompt": "Implement following language conventions: TypeScript (strict types, functional style, React hooks), Python (type hints, PEP 8, dataclasses), Rust (idiomatic patterns, comprehensive error handling), SQL (parameterized queries, indexes on foreign keys)"
}
```

### Pattern: Progressive Enhancement

```json
{
  "name": "implement-mvp",
  "description": "Implement MVP with clear upgrade path",
  "prompt": "Implement MVP: 1) Core functionality with basic validation, 2) Add TODO comments for production improvements, 3) Mark enhancement opportunities with // FUTURE:, 4) Keep architecture extensible for later hardening"
}
```

### Pattern: Compliance Requirements

```json
{
  "name": "implement-with-compliance",
  "description": "Implement with SOC2 compliance",
  "prompt": "Implement with compliance controls: 1) Log all data access, 2) Encrypt sensitive fields, 3) Validate inputs against whitelist, 4) Add audit trail, 5) Document security controls in SECURITY.md"
}
```

### Pattern: Team Communication

```json
{
  "name": "document-changes",
  "description": "Document changes for team",
  "prompt": "Update documentation: 1) Add API changes to docs/api/CHANGELOG.md, 2) Update examples if behavior changed, 3) Add migration notes if breaking change, 4) Post summary to #engineering Slack with PR link"
}
```

### Pattern: Environment-Specific Behavior

```json
{
  "name": "deploy",
  "description": "Deploy to target environment",
  "prompt": "Deploy with environment config: production (use blue-green, require health checks, enable monitoring), staging (rapid deployment, verbose logging), development (hot reload, debug symbols)"
}
```

---

## Migration Guide

### Upgrading Existing Workflows

**Before** (v1.x or early v2.0):
```json
{
  "name": "test",
  "description": "Run tests and check coverage"
}
```

**After** (v2.0 with prompts):
```json
{
  "name": "test",
  "description": "Run automated test suite with coverage",
  "prompt": "Run tests with coverage, require 80%+ coverage, report failures"
}
```

**Benefits**:
- ✅ Clearer execution intent
- ✅ Better audit trail (description vs execution)
- ✅ Easier to customize later

---

## Troubleshooting

### Issue: Prompt Ignored

**Symptom**: Step executes with default behavior despite prompt

**Cause**: Skill doesn't use prompt for customization

**Solution**: Check skill documentation. Some skills may not support prompt customization yet. File issue or create custom step without skill.

### Issue: Prompt Too Complex

**Symptom**: Claude confused by multi-step prompt

**Solution**: Break into multiple steps:

❌ **Single Complex Step**:
```json
{
  "name": "build-and-deploy",
  "prompt": "Build app, run tests, create docker image, push to registry, update k8s manifests, deploy to cluster, run smoke tests, notify team"
}
```

✅ **Multiple Focused Steps**:
```json
[
  {
    "name": "build",
    "prompt": "Build production bundle with optimization"
  },
  {
    "name": "containerize",
    "prompt": "Create and push Docker image to registry"
  },
  {
    "name": "deploy",
    "prompt": "Update k8s manifests and deploy to cluster"
  },
  {
    "name": "verify",
    "prompt": "Run smoke tests and notify team on #deploys"
  }
]
```

---

## See Also

- [configuration.md](./configuration.md) - Complete configuration guide
- [workflow-guide.md](./workflow-guide.md) - Workflow fundamentals
- [HOOKS.md](./HOOKS.md) - Phase-level hooks
- [architecture.md](./architecture.md) - FABER architecture

---

**Made with ❤️ by Fractary**

*Customize your workflow. Ship your way.*
