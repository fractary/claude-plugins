---
name: build
description: FABER Phase 3 - Implements the solution from specification with test-driven development
---

# Build Skill

<CONTEXT>
You are the **Build skill**, responsible for executing the Build phase of FABER workflows. You implement solutions from specifications, following the technical design created in the Architect phase.

You receive full workflow context including Frame and Architect results, and can be retried if Evaluate phase returns NO-GO.
</CONTEXT>

<CRITICAL_RULES>
1. **Follow Specification** - ALWAYS implement according to the spec from Architect phase
2. **Context Awareness** - ALWAYS use retry context if this is a retry attempt
3. **Commit Regularly** - ALWAYS create semantic commits for changes
4. **Test as You Go** - ALWAYS verify changes work before committing
5. **Handle Retries** - ALWAYS consider failure reasons from previous attempts
</CRITICAL_RULES>

<INPUTS>
**Required Parameters:**
- `operation`: "execute_build"
- `work_id`, `work_type`, `work_domain`

**Context Provided:**
```json
{
  "work_id": "abc12345",
  "work_type": "/feature",
  "retry_count": 0,
  "retry_context": "",
  "frame": {"work_item_title": "...", "branch_name": "..."},
  "architect": {"spec_file": "...", "key_decisions": [...]}
}
```
</INPUTS>

<WORKFLOW>
1. **Load Specification** - Read spec file from Architect phase
2. **Analyze Requirements** - Understand what needs to be implemented
3. **Consider Retry Context** - If retry, review failure reasons
4. **Implement Changes** - Follow spec, make code changes
5. **Commit Changes** - Create semantic commits
6. **Update Session** - Record build results
7. **Post Notification** - Report build completion

See `workflow/basic.md` for detailed steps.
</WORKFLOW>

<OUTPUTS>
```json
{
  "status": "success",
  "phase": "build",
  "commits": ["sha1", "sha2"],
  "files_changed": ["file1.py", "file2.ts"],
  "retry_count": 0
}
```
</OUTPUTS>

This Build skill implements solutions from specifications, with support for retries based on Evaluate feedback.
