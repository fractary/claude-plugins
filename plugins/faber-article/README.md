# Realized Self Content Creation System

**Version:** 1.0 (Prototype)
**Status:** Ready for testing
**Created:** 2025-04-19

---

## Overview

An AI-assisted content creation system for the Realized Self blog that automates the entire content lifecycle from ideation to publication.

**Key Features:**
- ✅ Configurable research depth (basic, moderate, deep)
- ✅ Automated hero image generation with DALL-E 3
- ✅ SEO optimization with internal linking
- ✅ Workflow state tracking
- ✅ Semi-automated with checkpoints for review
- ✅ 9 slash commands for workflow control

---

## Quick Start

### Create a New Blog Post (Full Workflow)

```bash
/content:new "Your Post Title" --depth moderate
```

This will:
1. Research your topic
2. Generate an outline
3. Wait for your approval ⏸️
4. Write a full draft
5. Wait for your approval ⏸️
6. Optimize SEO
7. Generate hero image ($0.08)
8. Wait for final approval ⏸️
9. Publish

**Time:** 30-45 minutes
**Cost:** $0.08 (image generation)

---

## Available Commands

| Command | Purpose | Time | Cost |
|---------|---------|------|------|
| `/content:new <title> [--depth]` | Full creation workflow | 30-45min | $0.08 |
| `/content:research <topic> [--depth]` | Research + outline | 5-30min | $0 |
| `/content:draft <slug>` | Convert outline to draft | 10-20min | $0 |
| `/content:edit <slug> [--depth]` | Enhance existing post | 10-45min | $0 |
| `/content:seo <slug>` | Optimize SEO metadata | 5-10min | $0 |
| `/content:image <slug> [--prompt]` | Generate hero image | 2-5min | $0.08 |
| `/content:publish <slug> [--date]` | Finalize and publish | 2-10min | $0-0.08 |
| `/content:ideate [topic]` | Brainstorm content ideas | 10-20min | $0 |
| `/content:status [slug]` | Check workflow status | <1min | $0 |

---

## Workflow States

Posts move through these states:

```
idea → outline → draft → review → seo → scheduled → published
```

**State Descriptions:**
- **idea**: Initial concept or topic brainstorming
- **outline**: Structured outline with research notes
- **draft**: Full blog post written but needs review
- **review**: Under editorial review/enhancement
- **seo**: SEO optimization and metadata refinement
- **scheduled**: Ready for publication with future date
- **published**: Live on the blog

---

## Directory Structure

```
.claude/
├── README-CONTENT-SYSTEM.md         # This file
├── agents/
│   └── content-manager.md            # Workflow orchestration
├── skills/
│   └── content/
│       ├── content-state-manager.md  # State tracking
│       ├── content-researcher.md     # Research with configurable depth
│       ├── content-outliner.md       # Outline creation
│       ├── content-writer.md         # Draft writing
│       ├── content-editor.md         # Review and enhancement
│       ├── content-seo-optimizer.md  # SEO optimization
│       ├── image-prompt-generator.md # DALL-E prompt creation
│       └── image-generator.md        # Hero image generation
├── commands/
│   └── content/
│       ├── new.md                    # /content:new
│       ├── research.md               # /content:research
│       ├── draft.md                  # /content:draft
│       ├── edit.md                   # /content:edit
│       ├── seo.md                    # /content:seo
│       ├── image.md                  # /content:image
│       ├── publish.md                # /content:publish
│       ├── ideate.md                 # /content:ideate
│       └── status.md                 # /content:status
└── content-state.json                # Workflow state registry
```

---

## Research Depth Levels

### Basic (2-3 minutes)
- Quick fact-checking
- 1-2 authoritative sources
- Basic topic validation
- Use for: Simple posts, quick updates

### Moderate (5-10 minutes) - **DEFAULT**
- 3-5 credible sources
- Supporting statistics
- Content structure suggestions
- Use for: Standard blog posts

### Deep (15-30 minutes)
- 10+ diverse sources
- Competitor analysis
- SEO keyword research
- Content gap analysis
- Use for: Cornerstone content, competitive topics

---

## Example Workflows

### Workflow 1: Quick Research

```bash
# Research a topic without full creation
/content:research "AI productivity tools" --depth moderate

# Result: Research brief + outline in sandbox
# Next: Review and decide to draft or refine
```

---

### Workflow 2: Create from Scratch

```bash
# Full creation with moderate research
/content:new "How to Build AI Agents for Business" --depth moderate

# Checkpoints:
# 1. After outline → review
# 2. After draft → review
# 3. Before publish → final approval
```

---

### Workflow 3: Enhance Published Post

```bash
# Update existing post with deep research
/content:edit business-of-one --depth deep

# Updates statistics, adds sections, improves flow
# State: published → review
```

---

### Workflow 4: Just Add Image

```bash
# Generate hero image for existing post
/content:image my-existing-post

# Auto-generates DALL-E prompt from content
# Cost: $0.08
```

---

### Workflow 5: Batch Ideation

```bash
# Get 5-10 content ideas
/content:ideate entrepreneurship

# Top 3 saved as "idea" state posts
# Choose one to /content:new or /content:research
```

---

## Checkpoints (Semi-Automated)

The system pauses at 3 key checkpoints for your review:

### Checkpoint 1: After Outline
```
✅ Research completed
✅ Outline created

Review outline structure before drafting?
[Proceed] [Revise] [Pause]
```

### Checkpoint 2: After Draft
```
✅ Full draft written (1,350 words)
✅ Citations included

Review draft before SEO optimization?
[Proceed] [Edit] [Pause]
```

### Checkpoint 3: Before Publish
```
✅ SEO optimized
✅ Hero image generated
✅ Ready for publication

Publish now?
[Yes] [No] [Schedule Later]
```

---

## File Locations

**Drafts & Work-in-Progress:**
- Location: `src/content/sandbox/`
- States: idea, outline, draft, review, seo, scheduled

**Published Posts:**
- Location: `src/content/blog/`
- State: published

**Hero Images:**
- Location: `/public/images/hero/`
- Format: WebP (1792x1024, quality 85)
- Naming: `{slug}.webp`

**State Tracking:**
- Location: `.claude/content-state.json`
- Tracks: Current state, history, timestamps, notes

---

## Cost Tracking

| Operation | Cost |
|-----------|------|
| Research (any depth) | $0 |
| Writing/Editing | $0 |
| SEO Optimization | $0 |
| **Hero Image Generation** | **$0.08** |
| Full workflow (`/content:new`) | **$0.08** |

**Budget Tip:** Only `/content:new`, `/content:image`, and `/content:publish` (if image missing) incur costs.

---

## Prerequisites

### Required
- OpenAI API key in `.env` file:
  ```
  OPENAI_API_KEY=sk-...your-key-here
  ```

### Directories
- `src/content/sandbox/` (for drafts)
- `src/content/blog/` (for published)
- `public/images/hero/` (for images)

All directories are created automatically if missing.

---

## Tips & Best Practices

### For Best Results
✅ Use moderate depth for most posts (good balance)
✅ Review checkpoints carefully (catch issues early)
✅ Let skills complete before manual editing
✅ Use `/content:status` to track progress
✅ Batch ideation, then research winners

### Avoid
❌ Skipping checkpoints (harder to fix later)
❌ Manually editing between workflow steps
❌ Using deep research for every post (time-consuming)
❌ Generating images multiple times (costs add up)

---

## Troubleshooting

### Issue: "OPENAI_API_KEY not found"
**Solution:** Add API key to `.env` file in project root

### Issue: "Post not found in sandbox"
**Solution:** Check slug spelling, verify file exists in `src/content/sandbox/`

### Issue: "State transition invalid"
**Solution:** Check current state with `/content:status <slug>`, follow valid transitions

### Issue: "Image generation failed"
**Solution:** Check API key, verify network connection, retry

### Issue: "Research returned no sources"
**Solution:** Topic may be too niche, try broader search terms or different angle

---

## Next Steps

### After Installation
1. ✅ System is installed and ready
2. Test with a simple post:
   ```bash
   /content:new "Test Post" --depth basic
   ```
3. Check status:
   ```bash
   /content:status
   ```

### Regular Usage
1. Ideate:
   ```bash
   /content:ideate [topic]
   ```
2. Research top idea:
   ```bash
   /content:research "chosen topic" --depth moderate
   ```
3. Review outline, then draft:
   ```bash
   /content:draft chosen-topic-slug
   ```
4. Finalize and publish:
   ```bash
   /content:seo chosen-topic-slug
   /content:publish chosen-topic-slug
   ```

---

## Future Migration to Faber-Content Plugin

This is a **prototype** implementation in the Realized Self project.

**Phase 2 Goals:**
- Extract into `fractary-faber:content` or `fractary-faber:article` plugin
- Generalize for multi-brand use
- Add configuration for:
  - Brand voice and style
  - Visual style preferences
  - Frontmatter schema
  - Custom workflow states
  - Research source preferences

---

## Documentation

- **Full Specification:** `docs/specs/content-creation-system.md`
- **Skills Documentation:** `.claude/skills/content/`
- **Agent Documentation:** `.claude/agents/content-manager.md`
- **Command Reference:** `.claude/commands/content/`

---

## Support & Feedback

This is a prototype system. For issues or suggestions:
1. Test thoroughly with non-critical content first
2. Document any issues encountered
3. Note ideas for improvements
4. Prepare feedback for plugin version

---

**Happy Creating! 🎉**

Generate great content faster with AI assistance while maintaining quality and brand voice.
