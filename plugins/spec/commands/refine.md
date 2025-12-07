---
name: fractary-spec:refine
description: Critically review and refine an existing specification
model: claude-opus-4-5
argument-hint: --work-id <id> [--prompt "<focus>"]
---

Critically review and refine an existing specification.

This command analyzes an existing spec, generates clarifying questions and improvement suggestions, and applies refinements based on your feedback. Questions and answers are logged to the GitHub issue for record-keeping.

**Key Features**:
- **Critical Analysis**: Identifies ambiguities, gaps, and potential improvements
- **Interactive Q&A**: Presents questions for clarification, accepts partial answers
- **Best-Effort Decisions**: Proceeds with reasonable defaults for unanswered questions
- **GitHub Documentation**: Posts questions and completion summary to the issue
- **Iterative Refinement**: Supports multiple rounds if meaningful questions remain

## Usage

```bash
/fractary-spec:refine --work-id <id> [options]
```

## Options

- `--work-id <id>`: Required - Work item ID whose spec to refine
- `--prompt "<focus>"`: Optional - Focus refinement on specific areas (e.g., "Focus on API design")

## Examples

### Basic Refinement

Refine the spec for issue #255:

```bash
/fractary-spec:refine --work-id 255
```

### Focused Refinement

Focus on specific aspects:

```bash
/fractary-spec:refine --work-id 255 --prompt "Focus on error handling and edge cases"
```

```bash
/fractary-spec:refine --work-id 123 --prompt "Consider security implications"
```

## What It Does

1. **Locate Spec**: Finds spec file matching `WORK-{id:05d}-*.md` in `/specs`
2. **Critical Analysis**: Reviews spec for ambiguities, gaps, and issues
3. **Generate Questions**: Creates meaningful questions and suggestions
4. **Post to GitHub**: Documents questions on the issue for record-keeping
5. **Present to User**: Uses interactive prompts for your answers
6. **Apply Improvements**: Updates spec based on answers
7. **Best-Effort Decisions**: Makes reasonable choices for unanswered questions
8. **Add Changelog**: Documents refinement in the spec
9. **Post Completion**: Summarizes changes on GitHub issue

## Question Quality

The refiner focuses on **meaningful questions only**:

**Good questions** (specific, actionable):
- "The spec mentions 'user data' but doesn't specify fields. Should we include preferences and settings?"
- "Error handling isn't defined. What should happen when the external API is unavailable?"

**Avoided questions** (generic, trivial):
- "Have you considered all edge cases?"
- "Is this the best approach?"

## Handling Unanswered Questions

You don't need to answer every question. For unanswered questions:
- The refiner makes a **best-effort decision**
- The decision is documented in the spec changelog
- You can override later if you disagree

This allows refinement to proceed without blocking on every detail.

## Output

### Example: Standard Refinement

```
🎯 STARTING: Spec Refiner
Work ID: #255
Spec: /specs/WORK-00255-fractary-spec-refine-command.md
Round: 1
───────────────────────────────────────

✓ Spec loaded
✓ Critical analysis complete
✓ Generated 5 questions, 3 suggestions
✓ Posted questions to GitHub issue #255

Presenting questions for your review...

[Interactive Q&A session]

✓ Received 3 of 5 answers
✓ Applied improvements
✓ Made 2 best-effort decisions
✓ Added changelog entry
✓ Posted completion summary to GitHub

✅ COMPLETED: Spec Refiner
Spec updated: /specs/WORK-00255-fractary-spec-refine-command.md
Questions asked: 5
Questions answered: 3
Improvements applied: 7
───────────────────────────────────────
Next: Begin implementation using refined spec
```

### Example: No Refinements Needed

```
🎯 STARTING: Spec Refiner
Work ID: #456
Spec: /specs/WORK-00456-simple-fix.md
───────────────────────────────────────

✓ Spec loaded
✓ Critical analysis complete
ℹ No meaningful refinements identified

⏭ SKIPPED: Spec already comprehensive
───────────────────────────────────────
Next: Begin implementation - spec is ready
```

## GitHub Integration

### Questions Comment

Posted when refinement starts:

```markdown
## 🔍 Spec Refinement: Questions & Suggestions

After reviewing the specification, the following questions and suggestions
were identified to improve clarity and completeness.

### Questions

1. **API Response Format**: The spec mentions "return user data" but doesn't
   specify fields. Should we include preferences and settings?

2. **Error Handling**: What should happen when the external service is unavailable?

### Suggestions

1. **Add Performance Targets**: Consider specifying response time requirements.

---

**Instructions**:
- Answer questions in a reply comment, or directly in the CLI if you have access
- You don't need to answer every question - unanswered items will use best-effort decisions
```

### Completion Comment

Posted after refinement completes:

```markdown
## ✅ Spec Refined

The specification has been updated based on the refinement discussion.

**Spec**: [WORK-00255-feature.md](/specs/WORK-00255-feature.md)

### Changes Applied

- Clarified API response format to include extended profile
- Added error handling section for external service failures
- Defined performance targets (200ms p99)

### Q&A Summary

<details>
<summary>Click to expand</summary>

**Q1**: What fields should user data include?
**A1**: Extended profile with preferences and settings

**Q2**: Error handling strategy?
**A2**: Best judgment: Retry with exponential backoff, return cached data if available

</details>
```

## Workflow Integration

Add as optional step after spec creation in FABER workflow:

```json
{
  "phases": {
    "architect": {
      "steps": [
        {"name": "generate-spec", "skill": "fractary-spec:spec-generator"},
        {"name": "refine-spec", "skill": "fractary-spec:spec-refiner"}
      ]
    }
  }
}
```

## Context Preservation

When invoked after `/fractary-spec:create`, the refiner inherits the spec context:

```
spec-generator (creates spec)
       │
       └── [spec content in context]
       │
spec-refiner (refines spec)
       │
       └── [inherits context - no re-read needed]
```

This makes sequential invocation efficient.

## Iterative Refinement

If meaningful questions emerge after the first round, the refiner may suggest a second round:

```
✓ Round 1 complete
ℹ New questions identified from your answers
? Would you like to proceed with round 2? [Y/n]
```

Typically 1-2 rounds are sufficient. There's no hard limit, but the refiner avoids excessive iteration.

## Troubleshooting

**Spec not found**:
- Verify work ID is correct
- Check `/specs` directory for matching files
- Create spec first: `/fractary-spec:create --work-id <id>`

**No questions generated**:
- Spec may already be comprehensive
- This is normal for well-defined specs
- Refinement is skipped, spec unchanged

**GitHub comment failed**:
- Non-critical, refinement continues
- Check GitHub authentication
- Can manually post if needed

**Want to re-refine**:
- Just run the command again
- New round considers current spec state
- Changelog tracks all refinement rounds

## See Also

- `/fractary-spec:create` - Create new specifications
- `/fractary-spec:validate` - Validate implementation against spec
- `/fractary-spec:archive` - Archive completed specs
