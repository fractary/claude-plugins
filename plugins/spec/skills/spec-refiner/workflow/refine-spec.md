# Workflow: Refine Spec

This workflow describes the detailed steps for critically reviewing a specification, generating questions and suggestions, and applying refinements based on user feedback.

## Overview

**Primary Goal**: Improve specification quality through critical analysis and user clarification
**Input**: Work ID (and optional focus prompt)
**Output**: Updated spec with improvements, changelog entry, GitHub documentation

This workflow is designed to be context-efficient when invoked after spec-generator, inheriting the spec content from the prior skill invocation.

## Step 1: Locate and Load Spec

Find the spec file for the given work_id.

**Process**:
1. Look for files matching `WORK-{work_id:05d}-*.md` in `/specs` directory
2. If multiple specs found, refine all or ask user which to focus on
3. If no spec found, return error with suggestion to create one first
4. Read spec content into context

**Implementation**:
```bash
# Find spec files for work_id (zero-padded to 5 digits)
PADDED_ID=$(printf "%05d" "$WORK_ID")
SPEC_FILES=$(ls specs/WORK-${PADDED_ID}-*.md 2>/dev/null)

if [ -z "$SPEC_FILES" ]; then
    echo "Error: No spec found for issue #${WORK_ID}"
    echo "Create one first: /fractary-spec:create --work-id ${WORK_ID}"
    exit 1
fi
```

**Context Inheritance**: If invoked immediately after spec-generator, the spec content is already in context. Skip file read in this case to preserve efficiency.

## Step 2: Critical Analysis

Analyze the spec content thoroughly.

**Analysis Focus Areas**:
1. **Completeness**: Are all necessary sections filled in?
2. **Clarity**: Are requirements unambiguous?
3. **Feasibility**: Are technical approaches realistic?
4. **Testability**: Can acceptance criteria be verified?
5. **Scope**: Are boundaries clearly defined?
6. **Risks**: Are potential issues identified?
7. **Dependencies**: Are external requirements documented?
8. **Edge Cases**: Are unusual scenarios considered?

**Process**:
1. Read through each section of the spec
2. Note areas that are vague, incomplete, or potentially problematic
3. Identify assumptions that should be validated
4. Consider alternative approaches that might be better
5. Flag missing information that's critical for implementation

**Important**: This is a thoughtful analysis, not a checklist. Focus on what ACTUALLY matters for this specific spec.

## Step 3: Generate Questions and Suggestions

Create meaningful questions and improvement suggestions.

**Question Quality Standards**:
- Be SPECIFIC - reference exact sections/statements
- Explain WHY the question matters
- Suggest possible answers when helpful
- Skip trivial questions that don't improve the spec

**Categories to Consider** (not required):
- Requirements clarification
- Technical approach validation
- Scope boundaries
- Edge case handling
- Risk assessment
- Alternative approaches

**Example Good Questions**:

```markdown
### Questions

1. **API Response Format**: The spec mentions "return user data" but doesn't specify the exact fields. Should we include:
   - Basic info only (id, name, email)?
   - Extended profile (preferences, settings)?
   - Related entities (teams, roles)?
   This affects API contract and client implementation.

2. **Error Handling Strategy**: The spec describes the happy path but doesn't address failure scenarios. What should happen when:
   - External service is unavailable?
   - Rate limits are exceeded?
   - Invalid input is provided?

3. **Performance Requirements**: No performance targets are specified. Should we:
   - Target specific response times (e.g., <200ms p99)?
   - Consider caching strategy?
   - Plan for specific load (requests/sec)?
```

**Example Good Suggestions**:

```markdown
### Suggestions

1. **Add Acceptance Criteria Section**: The spec lacks explicit acceptance criteria. Consider adding testable conditions like:
   - "User can export data in CSV format"
   - "Export completes within 30 seconds for up to 10,000 records"

2. **Clarify Scope Boundary**: The phrase "and related functionality" is vague. Recommend explicitly listing what's in-scope and out-of-scope to prevent scope creep.
```

**Output**: Structured list of questions and suggestions with clear rationale.

## Step 4: Post Questions to GitHub

Post questions and suggestions to the GitHub issue for record-keeping.

**Process**:
1. Format questions and suggestions using the template from SKILL.md
2. Post as a comment on the work item's GitHub issue
3. Record the comment ID for reference

**Implementation**:
```bash
# Post questions to GitHub issue
gh issue comment "$WORK_ID" --repo "$REPO" --body "$(cat <<'EOF'
## 🔍 Spec Refinement: Questions & Suggestions

After reviewing the specification, the following questions and suggestions were identified to improve clarity and completeness.

### Questions

[Generated questions here]

### Suggestions

[Generated suggestions here]

---

**Instructions**:
- Answer questions in a reply comment, or directly in the CLI if you have access
- You don't need to answer every question - unanswered items will use best-effort decisions
- When ready to apply refinements, re-run the workflow or tell FABER to continue
EOF
)"
```

**Error Handling**: If GitHub comment fails, log warning and continue. This is non-critical.

## Step 5: Present Questions to User

Use AskUserQuestion tool to present questions interactively in CLI.

**Process**:
1. Format questions for AskUserQuestion tool
2. Present each question with context
3. Allow user to skip questions (will use best-effort)
4. Collect answers for answered questions

**Question Presentation**:
For each question, create an AskUserQuestion with:
- Clear question text
- 2-4 answer options if applicable
- Option for custom answer ("Other")

**Example**:
```
Question: The spec mentions "return user data" but doesn't specify fields. What should be included?

Options:
1. Basic info only (id, name, email)
2. Extended profile (preferences, settings)
3. Full data including related entities
4. [Custom answer]
```

**Handling Skipped Questions**: If user doesn't answer, note it for best-effort decision in Step 7.

## Step 6: Collect User Answers

Gather and organize user responses.

**Process**:
1. Record each answer with its corresponding question
2. Note which questions were skipped/unanswered
3. Parse any custom text answers
4. Validate answers make sense in context

**Data Structure**:
```json
{
  "questions": [
    {
      "id": 1,
      "question": "What fields should user data include?",
      "answered": true,
      "answer": "Extended profile with preferences and settings"
    },
    {
      "id": 2,
      "question": "What's the error handling strategy?",
      "answered": false,
      "answer": null
    }
  ],
  "suggestions_accepted": [1, 3],
  "suggestions_rejected": [2]
}
```

## Step 7: Apply Improvements

Update the spec based on answers and best-effort decisions.

**Process**:
1. For answered questions: Apply user's specified changes
2. For unanswered questions: Make best-effort decisions and document them
3. For accepted suggestions: Implement the improvements
4. Preserve spec structure and frontmatter
5. Update modification date in frontmatter

**Best-Effort Decision Making**:
When a question isn't answered:
1. Consider the context and common practices
2. Make a reasonable decision
3. Document the decision clearly
4. Note it can be changed if user disagrees

**Example Best-Effort**:
```
Q: Should we include caching?
A: [Not answered]
Decision: Yes, implement Redis caching with 5-minute TTL for read endpoints.
Rationale: Common pattern for APIs with read-heavy workloads. Can be adjusted.
```

**Important**: Never leave a gap. Every question should result in either an applied answer or a documented best-effort decision.

## Step 8: Add Changelog Entry

Add a changelog entry to the spec documenting the refinement.

**Process**:
1. Find or create Changelog section in spec
2. Add dated entry with summary of changes
3. Note questions asked vs answered
4. Document best-effort decisions

**Changelog Format**:
```markdown
## Changelog

| Date | Changes |
|------|---------|
| 2025-12-07 | Initial spec created |
| 2025-12-07 | Refined: Clarified API response format, added error handling section, defined performance targets. 3/5 questions answered, 2 best-effort decisions. |
```

**Frontmatter Update**:
```yaml
---
...
updated: 2025-12-07
refinement_rounds: 1
---
```

## Step 9: Check for Additional Round

Determine if another refinement round is warranted.

**Criteria for Additional Round**:
- New significant questions emerged from answers
- User explicitly requested follow-up
- Critical ambiguities remain after best-effort decisions

**Criteria to STOP**:
- All meaningful questions addressed
- Only minor/trivial questions remain
- User indicates spec is sufficient
- Already completed 2+ rounds (soft limit)

**Process**:
1. Review applied changes for new questions
2. Assess remaining ambiguity level
3. If additional round warranted, return to Step 3
4. Otherwise, proceed to Step 10

**Note**: Goal is typically 1 round, sometimes 2. Avoid excessive iteration.

## Step 10: Post Completion Summary

Post completion summary to GitHub issue.

**Process**:
1. Format completion comment using template from SKILL.md
2. Include summary of changes
3. Include Q&A log (in collapsible section)
4. Post to GitHub issue

**Implementation**:
```bash
gh issue comment "$WORK_ID" --repo "$REPO" --body "$(cat <<'EOF'
## ✅ Spec Refined

The specification has been updated based on the refinement discussion.

**Spec**: [WORK-00255-feature-name.md](/specs/WORK-00255-feature-name.md)

### Changes Applied

- [List of changes]

### Q&A Summary

<details>
<summary>Click to expand</summary>

[Q&A log here]

</details>
EOF
)"
```

## Step 11: Return Refinement Report

Return structured output documenting the refinement.

**Success Response**:
```json
{
  "status": "success",
  "message": "Specification refined: WORK-00255-feature.md",
  "details": {
    "spec_path": "/specs/WORK-00255-feature.md",
    "work_id": "255",
    "round": 1,
    "questions_asked": 5,
    "questions_answered": 3,
    "improvements_applied": 7,
    "best_effort_decisions": 2,
    "github_questions_comment": true,
    "github_completion_comment": true,
    "additional_round_recommended": false
  }
}
```

## Error Recovery

At each step, if error occurs:

1. **Step 1 (Spec Not Found)**: Return failure, suggest creating spec first
2. **Step 3 (No Questions)**: Return skipped, spec is already comprehensive
3. **Step 4 (GitHub Failed)**: Log warning, continue without GitHub documentation
4. **Step 5 (User Cancels)**: Return skipped, spec unchanged
5. **Step 7 (Write Failed)**: Return failure, preserve original spec
6. **Step 10 (GitHub Failed)**: Log warning, return success (refinement still applied)

## Example Execution

### Example 1: Standard Refinement

```
Input:
  work_id: "255"
  prompt: null
  round: 1

Steps:
  1. ✓ Spec located: /specs/WORK-00255-fractary-spec-refine-command.md
  2. ✓ Critical analysis complete
  3. ✓ Generated 5 questions, 3 suggestions
  4. ✓ Posted questions to GitHub issue #255
  5. ✓ Presented questions to user
  6. ✓ Collected answers: 3/5 answered
  7. ✓ Applied 3 answer-based changes, 2 best-effort decisions, 3 suggestions
  8. ✓ Added changelog entry
  9. ✓ No additional round needed
  10. ✓ Posted completion summary to GitHub
  11. ✓ Returned success response

Output:
  {
    "status": "success",
    "spec_path": "/specs/WORK-00255-fractary-spec-refine-command.md",
    "questions_asked": 5,
    "questions_answered": 3,
    "improvements_applied": 8,
    "best_effort_decisions": 2
  }
```

### Example 2: Focused Refinement

```
Input:
  work_id: "123"
  prompt: "Focus on API design and error handling"
  round: 1

Steps:
  1. ✓ Spec located: /specs/WORK-00123-user-auth.md
  2. ✓ Critical analysis (focused on API and errors)
  3. ✓ Generated 3 API questions, 2 error handling questions
  4. ✓ Posted to GitHub
  5. ✓ Presented to user
  6. ✓ All 5 questions answered
  7. ✓ Applied all improvements
  8. ✓ Added changelog
  9. ✓ No additional round
  10. ✓ Posted completion
  11. ✓ Success

Output:
  {
    "status": "success",
    "questions_asked": 5,
    "questions_answered": 5,
    "improvements_applied": 5,
    "best_effort_decisions": 0
  }
```

### Example 3: No Refinements Needed

```
Input:
  work_id: "456"
  round: 1

Steps:
  1. ✓ Spec located: /specs/WORK-00456-simple-fix.md
  2. ✓ Critical analysis complete
  3. ✓ No meaningful questions identified - spec is comprehensive
  4. ✗ Skipped (nothing to post)
  5. ✗ Skipped (nothing to ask)
  ... remaining steps skipped

Output:
  {
    "status": "skipped",
    "message": "No meaningful refinements identified",
    "reason": "Spec is already comprehensive and well-defined"
  }
```

## Key Differences from spec-generator

| Aspect | spec-generator | spec-refiner |
|--------|----------------|--------------|
| Input | Issue data + conversation | Existing spec + conversation |
| Output | New spec file | Updated spec file |
| User Interaction | None (generates from context) | Q&A via AskUserQuestion |
| GitHub Posts | 1 (spec created) | 2 (questions + completion) |
| Idempotent | Yes (skips if exists) | Yes (can re-run for new round) |
| Primary Purpose | Create from scratch | Improve existing |
