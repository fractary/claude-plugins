---
name: fractary-faber-article:content-status
description: Check workflow status and progress of blog posts (single post or all posts overview)
model: claude-haiku-4-5
argument-hint: [slug]
---

Invoke the content-manager agent to check the workflow status of blog posts.

**Parameters from command:**
- Slug: {{ARG_1}} (optional, specific post slug to check)

**Workflow:** Status Check (query → report)

Execute Workflow 9 from content-manager agent:

**If slug provided:**
1. Invoke content-state-manager query for specific post
2. Show detailed status report:
   - Current workflow state
   - Location (sandbox or blog)
   - Last updated timestamp
   - State transition history
   - Next recommended actions
   - Estimated time to completion

**If no slug (show all posts):**
1. Query all posts in content workflow
2. Group posts by state:
   - idea: X posts
   - outline: X posts
   - draft: X posts
   - review: X posts
   - seo: X posts
   - scheduled: X posts
   - published: Recently published
3. Show recent activity
4. Identify stalled posts (no updates in 7+ days)
5. Provide workflow overview statistics

**Example usage:**
```
/content:status ai-agents-guide
/content:status
```

**Output:**

**Single Post:**
```
Post: AI Agents for Solopreneurs
Slug: ai-agents-solopreneurs
Current State: draft
Location: sandbox
Last Updated: 2025-04-19 10:30 AM

Next Actions:
  - Review draft content for quality
  - Run /content:seo ai-agents-solopreneurs
  - Run /content:image ai-agents-solopreneurs

Timeline:
  idea     | 2025-04-18 14:00
  outline  | 2025-04-18 16:30
  draft    | 2025-04-19 10:30

Estimated Time to Publish: 20-30 minutes
```

**All Posts:**
```
Content Workflow Overview

Total Posts in Workflow: 15

By State:
  📝 idea: 3 posts
  📋 outline: 2 posts
  ✍️  draft: 4 posts
  👀 review: 2 posts
  🎯 seo: 2 posts
  📅 scheduled: 1 post
  ✅ published: 62 posts (3 in last week)

Recent Activity:
  - ai-agents-guide: draft → review (2 hours ago)
  - productivity-tips: outline → draft (1 day ago)
  - online-business-guide: idea → outline (3 days ago)

⚠️  Stalled Posts (no updates in 7+ days):
  - email-automation-guide (draft, 14 days)
  - solopreneur-mindset (outline, 10 days)
```

**Use Cases:**
- Check progress on specific post
- Get overview of all content in pipeline
- Identify stalled posts needing attention
- Plan next content actions
- Track workflow efficiency

**Time:** <1 minute
**Cost:** $0 (read-only)
