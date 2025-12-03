---
name: fractary-faber-article:content-publish
description: Finalize and publish blog post (move from sandbox to blog, set publication date)
model: claude-haiku-4-5
argument-hint: <slug> [--date YYYY-MM-DD]
---

Invoke the content-manager agent to finalize and publish a blog post.

**Parameters from command:**
- Slug: {{ARG_1}} (post slug in sandbox)
- Publication date: {{FLAG_date}} (optional, format: YYYY-MM-DD, default: today)

**Workflow:** Publish Post (seo/scheduled → published)

Execute Workflow 7 from content-manager agent:
1. Validate prerequisites:
   - Content complete (>800 words)
   - SEO metadata present (title, description, tags, category, canonical)
   - Hero image exists (or will be auto-generated)
   - Valid frontmatter
2. If hero image missing:
   - Auto-invoke image-prompt-generator
   - Auto-invoke image-generator ($0.08)
   - Update frontmatter
3. Set pubDate in frontmatter (today or specified date)
4. Move file from `src/content/sandbox/` to `src/content/blog/`
5. Invoke content-state-manager
   - Set state to "published"
   - Log publication timestamp
6. CHECKPOINT: Confirm publication
   - Show final metadata
   - Display public URL
   - Request final approval
7. If confirmed:
   - Complete file move
   - Report success
   - Suggest build/deploy steps

**Example usage:**
```
/content:publish ai-agents-guide
/content:publish building-online-business --date 2025-04-25
```

**Prerequisites:**
- Post must exist in sandbox
- Content must be complete (>800 words)
- SEO metadata must be present
- Post typically in "seo" or "scheduled" state

**Output:**
- Post moved to `src/content/blog/{slug}.md`
- State: "published"
- Public URL: `https://www.realizedself.com/blog/{slug}/`

**Next Steps (suggested):**
1. Build site: `npm run build`
2. Preview: `npm run preview`
3. Deploy to production
