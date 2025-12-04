---
name: fractary-faber-article:content-image
description: Generate hero image using DALL-E 3 with brand-consistent visual style
model: claude-haiku-4-5
argument-hint: '<slug> [--prompt "custom prompt"]'
---

Invoke the content-manager agent to generate a hero image for a blog post.

**Parameters from command:**
- Slug: {{ARG_1}} (post slug in sandbox or blog)
- Custom prompt: {{FLAG_prompt}} (optional, override auto-generated prompt)

**Workflow:** Image Generation (any state → with image)

Execute Workflow 6 from content-manager agent:
1. Read post content
2. If no custom prompt: Invoke image-prompt-generator skill
   - Analyze post content and themes
   - Generate DALL-E 3 prompt matching Realized Self visual style
   - Use split composition with warm/cool contrast
3. Invoke image-generator skill
   - Call OpenAI DALL-E 3 API (cost: $0.08)
   - Generate 1792x1024 HD image
   - Download and convert to WebP (quality: 85)
   - Save to `/public/images/hero/{slug}.webp`
   - Update frontmatter with `heroImage` path
4. Report success with image path and cost

**Example usage:**
```
/content:image ai-agents-guide
/content:image building-online-business --prompt "Custom DALL-E prompt here"
```

**Output:**
- Hero image: `/public/images/hero/{slug}.webp`
- Frontmatter updated with `heroImage` path
- Cost: $0.08 per image

**Auto-generation:** Images are generated automatically per user preference (no approval needed)

**Visual Style:** Split composition, warm/cool lighting contrast, circuit patterns, futuristic aesthetic, professional quality, no text
