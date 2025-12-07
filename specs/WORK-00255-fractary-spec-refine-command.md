---
spec_id: WORK-00255-fractary-spec-refine-command
work_id: 255
issue_url: https://github.com/fractary/claude-plugins/issues/255
title: "fractary-spec refine command"
type: feature
status: draft
created: 2025-12-07
updated: 2025-12-07
author: fractary
validated: false
source: conversation+issue
---

# Feature Specification: fractary-spec refine command

**Issue**: [#255](https://github.com/fractary/claude-plugins/issues/255)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-07

## Changelog

| Date | Changes |
|------|---------|
| 2025-12-07 | Initial spec created |
| 2025-12-07 | Refined based on Q&A: simplified to standalone command only, removed modes/polling, clarified skill-based architecture |

## Summary

Create a `/fractary-spec:refine` command that critically reviews an existing specification, asks clarifying questions, and suggests improvements. Questions and responses are logged to the GitHub issue for record-keeping, and the spec is updated based on the user's answers. This is implemented as a **skill** (not an agent) to enable context sharing when invoked sequentially after `spec-generator`.

## Problem Statement

After a spec is created, users have been manually prompting Claude to "review the spec critically and think hard about any clarifying questions you could ask or improvements you could suggest." This additional step results in significantly better specifications. The workflow should be formalized and integrated into the plugin.

## Design Decisions (from Q&A)

| Decision | Rationale |
|----------|-----------|
| **Standalone command only** (no `--refine` flag on create) | Allows workflows to optionally include refinement as a step. Repetitive workflows can skip it; default workflow can include it. |
| **Skill, not agent** | Enables context sharing when spec-manager invokes `spec-generator` → `spec-refiner` sequentially. More context-efficient than separate agents. |
| **Trust Claude for question quality** | Generic prompt has worked well. Over-constraining may become a limitation as models improve. |
| **No formal state management** | User re-triggers FABER to continue. No polling, no timeouts, no "continue" flags. Questions are posted; answers are optional. |
| **Edit spec in place** | No versioned files (v1, v2). Git history provides audit trail. Add changelog section to spec. |
| **Iterative rounds allowed** | If meaningful questions remain after answers, a second round is acceptable. Focus on quality over quantity. |
| **No hard limits** | Goal is typically 1 round, maybe 2. No artificial caps. User can tell it to continue at any time. |

## User Stories

### Story 1: Standalone Refinement
**As a** developer with an existing spec
**I want** to refine a spec at any time
**So that** I can improve specs after creation or when requirements evolve

**Acceptance Criteria**:
- [ ] `/fractary-spec:refine --work-id 123` loads the spec and initiates refinement
- [ ] Works on any existing spec regardless of when it was created
- [ ] Questions and suggestions are presented to the user

### Story 2: Workflow Integration
**As a** workflow author
**I want** refinement as an optional step after spec creation
**So that** I can include it in workflows that benefit from it

**Acceptance Criteria**:
- [ ] `spec-refiner` skill can be added to workflow config after `spec-generator`
- [ ] Context from spec creation is preserved when skills run sequentially
- [ ] Workflows can omit refinement for repetitive/simple tasks

### Story 3: GitHub Documentation
**As a** team member reviewing a spec
**I want** questions and answers logged to the GitHub issue
**So that** there's a record of the refinement discussion

**Acceptance Criteria**:
- [ ] Questions are posted as a GitHub comment on the issue
- [ ] After refinement, a summary comment is posted with changes made
- [ ] Unanswered questions are noted (spec proceeds with best-effort decisions)

## Functional Requirements

- **FR1**: Create `/fractary-spec:refine` standalone command
- **FR2**: Create `spec-refiner` skill that can be invoked by spec-manager
- **FR3**: Load and analyze existing spec content
- **FR4**: Generate meaningful questions and improvement suggestions
- **FR5**: Present questions to user (CLI context)
- **FR6**: Post questions to GitHub issue for record-keeping
- **FR7**: Accept user answers (inline in CLI)
- **FR8**: Apply improvements to spec based on answers
- **FR9**: Handle unanswered questions gracefully (make best-effort decisions)
- **FR10**: Support iterative refinement if meaningful questions remain
- **FR11**: Add changelog section to spec tracking refinements
- **FR12**: Post completion comment to GitHub with changes summary

## Non-Functional Requirements

- **NFR1**: Questions should be meaningful and specific, not generic or trivial
- **NFR2**: Skill should preserve conversation context when invoked after spec-generator
- **NFR3**: All Q&A should be logged to the issue for audit trail

## Technical Design

### Architecture

```
/fractary-spec:refine --work-id 255
         │
         ▼
    refine.md (command)
         │
         ▼
    spec-manager (agent) ──or── direct skill invocation
         │
         ▼
    spec-refiner (skill)
         │
         ├── 1. Load spec
         ├── 2. Analyze critically
         ├── 3. Generate questions/suggestions
         ├── 4. Post to GitHub
         ├── 5. Present to user (CLI)
         ├── 6. Receive answers
         ├── 7. Apply improvements
         ├── 8. Update spec (with changelog)
         └── 9. Post completion to GitHub
```

### Sequential Invocation (Context Sharing)

When spec-manager invokes skills sequentially:
```
spec-manager
    │
    ├── spec-generator (creates spec)
    │       │
    │       └── [spec content in context]
    │
    └── spec-refiner (refines spec)
            │
            └── [inherits spec content from context]
```

This is more context-efficient than separate agent invocations.

### New Skill: spec-refiner

Location: `plugins/spec/skills/spec-refiner/`

**Structure**:
```
plugins/spec/skills/spec-refiner/
├── SKILL.md                    # Skill definition
└── workflow/
    └── refine-spec.md          # Detailed workflow steps
```

**Responsibilities**:
1. Load existing spec (by work_id)
2. Analyze spec content critically (trust Claude's judgment)
3. Generate meaningful questions and suggestions
4. Post questions to GitHub issue
5. Present questions to user in CLI
6. Accept and parse user answers
7. Apply improvements based on answers
8. Handle unanswered questions (make best-effort decisions)
9. Determine if additional round is warranted
10. Update spec file with changelog entry
11. Post completion summary to GitHub

### Question Generation

The skill prompts Claude to critically review the spec. **No rigid structure imposed** - trust Claude to:
- Identify ambiguities and gaps
- Question assumptions
- Consider edge cases
- Suggest alternatives
- Propose improvements

The prompt should emphasize **meaningful questions only** - skip trivial or generic questions.

### Refinement Session Tracking

Light-weight state for resumability (optional enhancement):
```json
// .fractary/plugins/spec/refinements/255.json
{
  "work_id": 255,
  "spec_path": "/specs/WORK-00255-feature-name.md",
  "questions_comment_id": 123456,
  "status": "questions_posted",
  "created_at": "2025-12-07T...",
  "rounds": 1
}
```

This enables `/fractary-spec:refine --work-id 255` to detect prior questions and fetch any GitHub answers. **Not required for MVP** - can be added later.

### GitHub Comment Formats

**Questions Comment**:
```markdown
## 🔍 Spec Refinement: Questions & Suggestions

After reviewing the specification, the following questions and suggestions were identified to improve clarity and completeness.

### Questions

1. **[Brief topic]**: [Detailed question]

2. **[Brief topic]**: [Detailed question]

### Suggestions

1. **[Brief topic]**: [Suggested improvement]

---

**Instructions**:
- Answer questions in a reply comment, or directly in the CLI if you have access
- You don't need to answer every question - unanswered items will use best-effort decisions
- When ready to apply refinements, re-run the workflow or tell FABER to continue
```

**Completion Comment**:
```markdown
## ✅ Spec Refined

The specification has been updated based on the refinement discussion.

**Spec**: [WORK-00255-feature-name.md](/specs/WORK-00255-feature-name.md)

### Changes Applied

- [Change 1 summary]
- [Change 2 summary]
- [Change 3 summary]

### Q&A Summary

<details>
<summary>Click to expand</summary>

**Q1**: [Question]
**A1**: [Answer or "Not answered - used best judgment: {decision}"]

**Q2**: [Question]
**A2**: [Answer or "Not answered - used best judgment: {decision}"]

</details>
```

## Implementation Plan

### Phase 1: Core Skill
1. Create `plugins/spec/skills/spec-refiner/SKILL.md`
2. Create `plugins/spec/skills/spec-refiner/workflow/refine-spec.md`
3. Implement spec loading and analysis
4. Implement question generation (simple prompt, trust Claude)
5. Implement spec update with changelog

### Phase 2: Command & Integration
1. Create `/fractary-spec:refine` command (`plugins/spec/commands/refine.md`)
2. Register skill in `plugin.json`
3. Enable spec-manager to invoke skill
4. Test sequential invocation (spec-generator → spec-refiner)

### Phase 3: GitHub Integration
1. Implement questions posting to GitHub
2. Implement completion comment posting
3. Parse answers from GitHub comments (when re-invoked)

### Phase 4: Polish
1. Add changelog section to spec template
2. Handle iterative rounds (if meaningful questions remain)
3. Documentation updates

## Files to Create/Modify

### New Files
- `plugins/spec/skills/spec-refiner/SKILL.md`: Skill definition
- `plugins/spec/skills/spec-refiner/workflow/refine-spec.md`: Workflow steps
- `plugins/spec/commands/refine.md`: Standalone command

### Modified Files
- `plugins/spec/.claude-plugin/plugin.json`: Register new skill
- `plugins/spec/agents/spec-manager.md`: Add refine operation routing
- `plugins/spec/skills/spec-generator/templates/*.template`: Add changelog section

## Command Design

### `/fractary-spec:refine`

```bash
# Refine spec for work item
/fractary-spec:refine --work-id 255

# Refine with explicit prompt/focus
/fractary-spec:refine --work-id 255 --prompt "Focus on API design"
```

**Arguments**:
- `--work-id <id>`: Required. Work item ID whose spec to refine
- `--prompt "<instructions>"`: Optional. Additional focus or instructions for refinement

**Behavior**:
1. Locate spec file for work_id (`WORK-{id:05d}-*.md`)
2. Load spec content
3. Check for prior questions on GitHub (if session tracking exists)
4. Fetch any new GitHub comment answers
5. Generate questions/suggestions (or apply answers if resuming)
6. Present to user, accept answers
7. Apply refinements
8. Update spec with changelog
9. Post summary to GitHub

## Workflow Configuration

Example workflow including refinement:
```json
{
  "phases": {
    "architect": {
      "enabled": true,
      "steps": [
        {"name": "generate-spec", "skill": "fractary-spec:spec-generator"},
        {"name": "refine-spec", "skill": "fractary-spec:spec-refiner"}
      ]
    }
  }
}
```

Workflows can omit the `refine-spec` step for simpler/repetitive tasks.

## Testing Strategy

### Manual Testing
- Refine a freshly created spec
- Refine an older existing spec
- Answer some questions, skip others
- Verify changelog is added
- Verify GitHub comments are posted

### Integration Testing
- Sequential skill invocation preserves context
- spec-generator → spec-refiner flow works
- GitHub comment parsing

## Dependencies

- `fractary-spec` plugin (existing)
- `gh` CLI (for GitHub API operations)

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Question quality varies | Medium | Medium | Trust improving models; emphasize "meaningful only" in prompt |
| Users don't answer questions | Medium | Low | Proceed with best-effort decisions; document what was assumed |
| Context lost between skills | Low | High | Skill architecture preserves context; test thoroughly |

## Open Questions (Resolved)

| Question | Resolution |
|----------|------------|
| Should refinement be automatic by default? | No - standalone command, added to workflows optionally |
| How many refinement rounds? | No hard limit; typically 1, sometimes 2; quality over quantity |
| Should answers be stored separately? | Optional enhancement - not required for MVP |
| CLI vs GitHub modes? | No separate modes; CLI is primary, GitHub for logging |

## Implementation Notes

- The refine prompt should emphasize **meaningful questions only** - no generic filler
- Leverage conversation context when spec-generator runs first
- Preserve spec structure when applying improvements
- Changelog should be human-readable, not exhaustive
- Git commits provide additional audit trail
- Unanswered questions should result in documented best-effort decisions, not blocking
