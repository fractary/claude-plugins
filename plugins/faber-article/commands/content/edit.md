---
name: fractary-faber-article:content-edit
description: Review and enhance existing blog post with updated research and improvements
model: claude-opus-4-5
argument-hint: <slug> [--depth basic|moderate|deep]
---

Invoke the content-manager agent to review and enhance an existing blog post (draft or published).

**Parameters from command:**
- Slug: {{ARG_1}} (post slug in sandbox or blog)
- Enhancement depth: {{FLAG_depth}} (default: moderate, options: basic|moderate|deep)

**Workflow:** Edit Existing Post (draft/published → enhanced)

Execute Workflow 4 from content-manager agent:
1. Read existing post from sandbox or blog
2. If moderate/deep: Research updated statistics and information
3. Invoke content-editor skill to enhance content
4. CHECKPOINT: Review changes
5. Update state appropriately (published → review, or keep as draft)
6. Optionally refresh SEO metadata if published

**Example usage:**
```
/content:edit business-of-one --depth moderate
/content:edit ai-agents-guide --depth deep
/content:edit quick-productivity-tips --depth basic
```

**Output:** Enhanced post with change summary

**Use Cases:**
- Update outdated statistics
- Add new sections
- Improve clarity and flow
- Strengthen arguments
- Refresh published content
