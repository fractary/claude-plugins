---
name: fractary-faber-article:content-ideate
description: Brainstorm content ideas with research, create top 3 as "idea" state posts
model: claude-opus-4-5
argument-hint: [topic-area]
---

Invoke the content-manager agent to brainstorm and generate content ideas.

**Parameters from command:**
- Topic area: {{ARG_1}} (optional, e.g., "entrepreneurship", "AI", "productivity")

**Workflow:** Content Ideation (exploration → ideas)

Execute Workflow 8 from content-manager agent:
1. Use WebSearch to find:
   - Trending topics in specified area (or general if none provided)
   - Topics related to solopreneurship, AI, freedom themes
   - Gaps in existing Realized Self content
2. Analyze Five Freedoms Framework:
   - Identify underrepresented freedom areas
   - Find connection opportunities across freedoms
3. Generate 5-10 content ideas:
   - Title suggestions
   - Brief rationale (why this matters)
   - Target audience fit
   - Estimated value/impact
   - Connection to freedoms
4. Create top 3 ideas as "idea" state posts:
   - Save minimal frontmatter to sandbox
   - Invoke content-state-manager
   - Set workflowState: "idea"
5. Report results:
   - List all 5-10 ideas with rationale
   - Highlight top 3 saved to sandbox
   - Suggest which to research first
   - Note any content series opportunities

**Example usage:**
```
/content:ideate entrepreneurship
/content:ideate AI automation
/content:ideate
```

**Output:**
- 5-10 content idea suggestions
- Top 3 saved as "idea" state posts in sandbox
- Recommendations for next steps

**Use Cases:**
- Overcome writer's block
- Identify content gaps
- Plan content calendar
- Discover trending topics
- Build content series

**Time:** 10-20 minutes
**Cost:** $0 (no image generation)
