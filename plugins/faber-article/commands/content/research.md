---
name: fractary-faber-article:content-research
description: Research topic and create detailed outline with sources (research → outline)
model: claude-opus-4-5
argument-hint: '"<topic>" [--depth basic|moderate|deep]'
---

Invoke the content-manager agent to execute research and outline creation workflow (research → outline).

**Parameters from command:**
- Topic: {{ARG_1}}
- Research depth: {{FLAG_depth}} (default: moderate, options: basic|moderate|deep)

**Workflow:** Research Only (idea → outline)

Execute Workflow 2 from content-manager agent:
1. Research topic using WebSearch and WebFetch
2. Generate research brief with sources
3. Create detailed outline from research
4. Save to sandbox with state: "outline"

**Example usage:**
```
/content:research "AI-powered productivity tools" --depth moderate
/content:research "Solopreneur business models" --depth deep
/content:research "Email automation basics" --depth basic
```

**Output:** Research brief and outline in `src/content/sandbox/{slug}.md`
