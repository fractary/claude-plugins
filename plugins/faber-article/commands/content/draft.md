---
name: fractary-faber-article:content-draft
description: Convert existing outline into full blog post draft (800-2000 words)
model: claude-opus-4-5
argument-hint: <slug>
---

Invoke the content-manager agent to convert an outline into a full draft.

**Parameters from command:**
- Slug: {{ARG_1}} (post slug in sandbox)

**Workflow:** Draft from Outline (outline → draft)

Execute Workflow 3 from content-manager agent:
1. Verify post exists in sandbox with state "outline"
2. Read existing outline and research brief
3. Invoke content-writer skill
4. Write full blog post (800-2000 words)
5. CHECKPOINT: Review draft
6. Set state to "draft"

**Example usage:**
```
/content:draft ai-agents-guide
/content:draft building-online-business
```

**Prerequisites:** Post must exist in sandbox with workflowState: "outline"

**Output:** Full draft content in `src/content/sandbox/{slug}.md`
