---
name: fractary-faber-article:content-new
description: Create new blog post from scratch with full workflow (research → outline → draft → SEO → image → publish)
model: claude-haiku-4-5
argument-hint: '"<title>" [--depth basic|moderate|deep]'
---

Invoke the content-manager agent to execute the full content creation workflow (research → outline → draft → SEO → image → publish).

**Parameters from command:**
- Title: {{ARG_1}}
- Research depth: {{FLAG_depth}} (default: moderate, options: basic|moderate|deep)

**Workflow:** Full Creation (idea → published)

Execute Workflow 1 from content-manager agent with semi-automated checkpoints:
1. Research topic at specified depth
2. Create detailed outline
3. CHECKPOINT: Review outline
4. Write full draft
5. CHECKPOINT: Review draft
6. Optimize SEO metadata
7. Generate hero image
8. CHECKPOINT: Final approval before publish
9. Publish (if approved)

**Example usage:**
```
/content:new "AI Agents for Solopreneurs" --depth moderate
/content:new "Building Online Business in 2025" --depth deep
/content:new "Quick Guide to Email Automation" --depth basic
```
