# Faber-Article Plugin User Guide

**Version:** 1.0.0

Welcome to the Faber-Article Plugin! This guide will help you automate your blog content creation from ideation through publication.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Commands Reference](#commands-reference)
3. [Workflows](#workflows)
4. [Best Practices](#best-practices)
5. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Installation

The plugin is automatically available if installed in your Claude Code plugins directory:

```bash
# Plugin should be at:
~/.claude/plugins/faber-article/
# or
/path/to/claude-plugins/plugins/faber-article/
```

### First Time Setup

No configuration required! The plugin works out of the box.

**Optional:** Set up OpenAI API key for automatic hero image generation:
```bash
export OPENAI_API_KEY="sk-..."
```

### Your First Blog Post

Create a complete blog post in one command:

```bash
/content:new "AI Productivity Tools for 2025" --depth moderate
```

**What happens:**
1. Researches the topic (5-10 minutes)
2. Creates detailed outline
3. ⏸️ **CHECKPOINT:** Review outline before continuing
4. Writes full draft (1000+ words)
5. ⏸️ **CHECKPOINT:** Review draft before SEO
6. Optimizes SEO metadata
7. Generates hero image ($0.08)
8. ⏸️ **CHECKPOINT:** Final approval before publish
9. Publishes if approved

**Total time:** 25-35 minutes
**Cost:** $0.08 (image only)

---

## Commands Reference

### `/content:new` - Create New Post

Create a complete blog post from scratch.

**Syntax:**
```bash
/content:new "<title>" [--depth basic|moderate|deep]
```

**Parameters:**
- `<title>` (required): Blog post title
- `--depth` (optional): Research depth, default: moderate

**Examples:**
```bash
/content:new "Getting Started with AI Agents"
/content:new "Solopreneur Business Models 2025" --depth deep
/content:new "Quick Email Tips" --depth basic
```

**Output:**
- Complete post in sandbox
- Hero image generated
- SEO metadata optimized
- State: scheduled (ready to publish)

**Time:** 15-45 minutes depending on depth
**Cost:** $0.08

---

### `/content:research` - Research Only

Research a topic and create an outline without writing the full post.

**Syntax:**
```bash
/content:research "<topic>" [--depth basic|moderate|deep]
```

**Parameters:**
- `<topic>` (required): Topic to research
- `--depth` (optional): Research depth, default: moderate

**Examples:**
```bash
/content:research "AI automation for small business"
/content:research "Digital nomad lifestyle" --depth deep
```

**Output:**
- Research brief with sources in sandbox
- Detailed outline
- State: outline

**Time:** 2-30 minutes
**Cost:** $0

**Use when:**
- Planning content calendar
- Need research without commitment to write
- Want to review outline before drafting

---

### `/content:draft` - Write from Outline

Convert an existing outline into a full blog post draft.

**Syntax:**
```bash
/content:draft <slug>
```

**Parameters:**
- `<slug>` (required): Post slug in sandbox

**Prerequisites:**
- Post must exist in sandbox with state: "outline"

**Examples:**
```bash
/content:draft ai-automation-guide
/content:draft digital-nomad-tips
```

**Output:**
- Full draft (800-2000 words)
- State: draft

**Time:** 10-15 minutes
**Cost:** $0

---

### `/content:edit` - Enhance Existing Post

Review and improve an existing post (draft or published).

**Syntax:**
```bash
/content:edit <slug> [--depth basic|moderate|deep]
```

**Parameters:**
- `<slug>` (required): Post slug
- `--depth` (optional): Enhancement depth, default: moderate

**Examples:**
```bash
/content:edit business-of-one
/content:edit ai-agents-guide --depth deep
/content:edit quick-tips --depth basic
```

**Depth Levels:**
- **basic**: Grammar, clarity, formatting (3-5 min)
- **moderate**: + Structure, flow, evidence (10-15 min)
- **deep**: + Updated research, new sections (20-30 min)

**Output:**
- Enhanced post with improvements
- Change summary
- State: review (or remains published)

**Time:** 5-30 minutes
**Cost:** $0

---

### `/content:seo` - Optimize Metadata

Optimize SEO metadata, tags, and find internal linking opportunities.

**Syntax:**
```bash
/content:seo <slug>
```

**Parameters:**
- `<slug>` (required): Post slug in sandbox

**Examples:**
```bash
/content:seo ai-productivity-tools
/content:seo business-models-2025
```

**What gets optimized:**
- Title (50-60 characters, keyword-rich)
- Meta description (150-160 characters, compelling)
- Tags (3-8 relevant tags)
- Category (single primary category)
- Canonical URL
- Internal link suggestions

**Output:**
- Optimized frontmatter
- SEO report
- Internal link opportunities
- State: seo

**Time:** 3-5 minutes
**Cost:** $0

---

### `/content:image` - Generate Hero Image

Create a hero image using DALL-E 3 with brand-consistent styling.

**Syntax:**
```bash
/content:image <slug> [--prompt "custom prompt"]
```

**Parameters:**
- `<slug>` (required): Post slug
- `--prompt` (optional): Custom DALL-E prompt override

**Examples:**
```bash
/content:image ai-productivity-tools
/content:image business-guide --prompt "A professional workspace with..."
```

**Visual Style (Auto-Generated):**
- Split composition (left/right contrast)
- Warm tones (golden, sepia) vs cool tones (cyan, blue)
- Futuristic aesthetic with circuit patterns
- Professional high-quality rendering
- No text overlays

**Output:**
- Hero image: `/public/images/hero/{slug}.webp`
- Frontmatter updated with `heroImage` path
- 1792x1024 resolution, WebP format (quality: 85)

**Time:** 2-3 minutes
**Cost:** $0.08 per image

---

### `/content:publish` - Finalize & Publish

Move a post from sandbox to blog and set publication date.

**Syntax:**
```bash
/content:publish <slug> [--date YYYY-MM-DD]
```

**Parameters:**
- `<slug>` (required): Post slug in sandbox
- `--date` (optional): Publication date, default: today

**Prerequisites:**
- Content >800 words
- SEO metadata complete
- Hero image present (or will auto-generate)

**Examples:**
```bash
/content:publish ai-productivity-tools
/content:publish business-guide --date 2025-04-25
```

**What happens:**
1. Validates prerequisites
2. Generates hero image if missing ($0.08)
3. Sets publication date
4. ⏸️ **CHECKPOINT:** Final approval
5. Moves file from sandbox to blog
6. Sets state: published

**Output:**
- Post in `src/content/blog/{slug}.md`
- State: published
- Public URL: `https://yourdomain.com/blog/{slug}/`

**Time:** 2-3 minutes
**Cost:** $0 (unless image needs generation: +$0.08)

---

### `/content:ideate` - Brainstorm Ideas

Generate content ideas with research and analysis.

**Syntax:**
```bash
/content:ideate [topic-area]
```

**Parameters:**
- `[topic-area]` (optional): Focus area for ideation

**Examples:**
```bash
/content:ideate
/content:ideate entrepreneurship
/content:ideate "AI automation"
```

**What it does:**
1. WebSearch for trending topics
2. Analyze your existing content for gaps
3. Map to Five Freedoms Framework
4. Generate 5-10 content ideas with rationale
5. Create top 3 as "idea" state posts in sandbox

**Output:**
- 5-10 content ideas with descriptions
- Top 3 saved to sandbox (state: idea)
- Recommendations for which to pursue first

**Time:** 10-20 minutes
**Cost:** $0

**Use for:**
- Overcoming writer's block
- Planning content calendar
- Identifying content gaps
- Discovering trending topics

---

### `/content:status` - Check Progress

View workflow status and progress of blog posts.

**Syntax:**
```bash
/content:status [slug]
```

**Parameters:**
- `[slug]` (optional): Specific post slug, or all if omitted

**Examples:**
```bash
/content:status ai-productivity-tools   # Single post
/content:status                          # All posts overview
```

**Output (Single Post):**
```
Post: AI Productivity Tools for 2025
Slug: ai-productivity-tools
Current State: draft
Location: sandbox
Last Updated: 2025-04-19 10:30 AM

Next Actions:
  - Review draft content
  - Run /content:seo ai-productivity-tools
  - Run /content:image ai-productivity-tools

Timeline:
  idea     | 2025-04-18 14:00
  outline  | 2025-04-18 16:30
  draft    | 2025-04-19 10:30
```

**Output (All Posts):**
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

⚠️  Stalled Posts (no updates in 7+ days):
  - email-automation-guide (draft, 14 days)
```

**Time:** <1 minute
**Cost:** $0

---

## Workflows

### Complete Creation Workflow

**Goal:** Idea to published post

```
/content:new "Topic" --depth moderate
  ↓ (5-10 min research)
  ↓
📋 Outline created
  ↓
⏸️  CHECKPOINT: Review outline
  ↓ (User approves)
  ↓ (10-15 min writing)
  ↓
✍️  Draft complete (1200 words)
  ↓
⏸️  CHECKPOINT: Review draft
  ↓ (User approves)
  ↓ (3-5 min SEO)
  ↓
🎯 SEO optimized
  ↓ (2 min image generation, $0.08)
  ↓
🖼️  Hero image created
  ↓
⏸️  CHECKPOINT: Final approval
  ↓ (User approves)
  ↓
✅ Published!
```

**Total:** 20-35 minutes, $0.08

---

### Research → Manual Writing

**Goal:** Get research and outline, write yourself

```
/content:research "Topic" --depth deep
  ↓ (15-30 min)
  ↓
📋 Research brief + outline in sandbox

[Manually write/edit the post]

/content:seo post-slug
  ↓ (3-5 min)
  ↓
🎯 SEO optimized

/content:image post-slug
  ↓ (2 min, $0.08)
  ↓
🖼️  Hero image

/content:publish post-slug
  ↓
✅ Published!
```

---

### Update Published Post

**Goal:** Refresh existing content

```
/content:edit existing-post --depth deep
  ↓ (Automatically transitions published → review)
  ↓ (15-30 min with new research)
  ↓
✍️  Enhanced content
  ↓
⏸️  CHECKPOINT: Review changes
  ↓ (User approves)
  ↓ (3-5 min SEO refresh)
  ↓
🎯 SEO refreshed
  ↓
⏸️  CHECKPOINT: Confirm publication
  ↓ (User approves)
  ↓ (Automatically transitions review → published)
  ↓
✅ Updated post live!
```

**Total:** 20-40 minutes, $0

---

## Best Practices

### Content Creation

**DO:**
- ✅ Use moderate depth by default (good balance of quality and speed)
- ✅ Review outlines before proceeding to draft (saves time on rewrites)
- ✅ Let AI handle first drafts, then enhance with your voice
- ✅ Run `/content:status` regularly to track your pipeline

**DON'T:**
- ❌ Skip SEO optimization (crucial for discoverability)
- ❌ Rush through checkpoints (they're there for quality)
- ❌ Use deep research for every post (save it for cornerstone content)

### Research Depth Selection

| Depth | When to Use | Output Quality |
|-------|-------------|----------------|
| **basic** | • Quick posts <br>• Simple topics <br>• Fact-checking | 1-2 sources, basic validation |
| **moderate** | • Standard blog posts <br>• Balanced approach <br>• Most use cases | 3-5 sources, comprehensive |
| **deep** | • Cornerstone content <br>• Competitive topics <br>• SEO focus | 10+ sources, competitive analysis, keyword research |

### Workflow Management

**Batching:** Maximize efficiency by batching similar work:
```bash
# Morning: Generate 3 outlines
/content:research "Topic 1" --depth moderate
/content:research "Topic 2" --depth moderate
/content:research "Topic 3" --depth moderate

# Afternoon: Review outlines, write drafts
/content:draft topic-1
/content:draft topic-2
/content:draft topic-3

# End of day: SEO and images
/content:seo topic-1 && /content:image topic-1
/content:seo topic-2 && /content:image topic-2
/content:seo topic-3 && /content:image topic-3
```

**Check Your Pipeline:**
```bash
# Every Monday
/content:status  # See what's in progress

# Clear stalled items
# Publish scheduled posts
# Plan next week's topics
```

### Cost Management

**Image Generation Costs:**
- $0.08 per image via DALL-E 3
- Automatic in `/content:new` and `/content:publish`
- Optional with `/content:image`

**To Skip Image Generation:**
- Run `/content:research` + `/content:draft` + `/content:seo` separately
- Manually add image later
- Or use `--no-image` flag (if implemented)

**Budget Example:**
- 10 posts/month = $0.80/month
- 50 posts/month = $4.00/month

---

## Troubleshooting

### "Invalid state transition" Error

**Problem:** Trying to move between incompatible states

**Solution:**
```bash
# Check current state
/content:status post-slug

# Follow the workflow:
# idea → outline → draft → review → seo → scheduled → published

# Can't skip states!
```

### "Missing required fields" Error

**Problem:** Post doesn't meet requirements for target state

**Solution:**
```
draft state requires: title, description, 500+ words
review state requires: draft + 800+ words + tags
seo state requires: review + 3-8 tags + category + canonical

# Manually add missing fields or run appropriate command
```

### "OpenAI API Key not found" Error

**Problem:** Image generation attempted without API key

**Solution:**
```bash
# Set API key
export OPENAI_API_KEY="sk-..."

# Or skip image generation
# Manually add image later
```

### Post Not Found

**Problem:** Command can't find the post

**Solution:**
```bash
# Check if post exists in sandbox or blog
ls src/content/sandbox/
ls src/content/blog/

# Use correct slug (filename without .md)
# Check spelling and hyphens
```

### Checkpoint Stuck

**Problem:** Workflow paused at checkpoint, not sure what to do

**Solution:**
- Read the checkpoint message carefully
- Options usually: Proceed / Edit / Cancel
- Type your choice to continue
- If confused, type "cancel" and start over

### State Registry Corrupted

**Problem:** `.claude/content-state.json` is malformed

**Solution:**
```bash
# Run status command to auto-rebuild
/content:status

# Or manually delete and rebuild
rm .claude/content-state.json
/content:status  # Rebuilds from frontmatter
```

---

## Tips & Tricks

### Keyboard Shortcuts

Speed up your workflow:
```bash
# Alias common commands (add to .bashrc or .zshrc)
alias cn='/content:new'
alias cr='/content:research'
alias cd='/content:draft'
alias cs='/content:status'
alias cp='/content:publish'
```

### Content Ideas from Status

```bash
# See what topics are trending in your drafts
/content:status

# Notice gaps in your published content
# Use those gaps for new ideas
/content:ideate "topic from gaps"
```

### Quick Daily Workflow

**Morning (15 minutes):**
```bash
/content:status                    # Check pipeline
/content:ideate                    # Get today's ideas
/content:research "chosen topic"   # Start research
```

**Afternoon (30 minutes):**
```bash
/content:draft topic-slug          # Write the draft
/content:edit previous-draft       # Polish yesterday's work
```

**End of Day (10 minutes):**
```bash
/content:seo topic-slug            # Optimize
/content:image topic-slug          # Generate image
/content:publish topic-slug        # Ship it!
```

**Result:** 1 published post per day, 55 minutes total

---

## FAQ

**Q: Can I edit posts manually after AI generates them?**
A: Yes! All posts are markdown files. Edit freely, then continue the workflow.

**Q: Do I have to use all checkpoints?**
A: Checkpoints are built into `/content:new`. Use individual commands (`/content:research`, `/content:draft`, etc.) for more control.

**Q: Can I customize the brand voice?**
A: Currently configured for "Realized Self" voice. Future versions will support custom brand voice configuration.

**Q: What if I don't like the generated image?**
A: Run `/content:image post-slug` again to regenerate, or provide custom prompt: `/content:image post-slug --prompt "your prompt"`

**Q: Can I use this for non-blog content?**
A: Designed for blog posts but can adapt. Frontmatter schema may need adjustment for other content types.

**Q: How do I know what state my post is in?**
A: `/content:status post-slug` shows current state, history, and next actions.

**Q: Can I have multiple posts in draft simultaneously?**
A: Yes! Work on as many as you want. Use `/content:status` to track all of them.

---

## Next Steps

- [Architecture Overview](./ARCHITECTURE.md) - Understand how the plugin works
- [Skills Reference](./SKILLS-REFERENCE.md) - Deep dive into each skill
- [Fractary Plugin Standards](../../docs/standards/FRACTARY-PLUGIN-STANDARDS.md) - Development guidelines

---

**Need Help?**
- Check `/content:status` for current state and next actions
- Read error messages carefully - they include solutions
- Consult this guide for command syntax
- Review [Architecture](./ARCHITECTURE.md) for system design

**Happy writing! 📝✨**
