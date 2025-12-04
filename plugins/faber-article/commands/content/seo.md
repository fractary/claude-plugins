---
name: fractary-faber-article:content-seo
description: Optimize SEO metadata (title, description, tags, category) and find internal links
model: claude-sonnet-4-5
argument-hint: <slug>
---

Invoke the content-manager agent to optimize SEO metadata and identify internal linking opportunities.

**Parameters from command:**
- Slug: {{ARG_1}} (post slug in sandbox)

**Workflow:** SEO Optimization (draft → seo)

Execute Workflow 5 from content-manager agent:
1. Read post content from sandbox
2. Invoke content-seo-optimizer skill
3. Optimize title (50-60 characters, include keywords)
4. Craft meta description (150-160 characters)
5. Select 3-8 relevant tags from existing taxonomy
6. Assign appropriate category
7. Generate canonical URL
8. Find internal linking opportunities
9. Set state to "seo"
10. Generate SEO optimization report

**Example usage:**
```
/content:seo ai-agents-guide
/content:seo building-online-business
```

**Prerequisites:** Post must exist in sandbox (typically in "draft" or "review" state)

**Output:**
- Optimized frontmatter metadata
- SEO optimization report
- Internal link suggestions
- State updated to "seo"

**What Gets Optimized:**
- title: SEO-friendly, keyword-rich
- description: Compelling, 150-160 chars
- tags: 3-8 relevant tags
- category: Single appropriate category
- canonical: Full URL format
