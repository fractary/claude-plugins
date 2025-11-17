# Faber-Article Plugin Architecture

## Overview

The **faber-article plugin** automates blog content creation lifecycle - from ideation through publication. It implements the Fractary 3-layer architecture pattern with semi-automated checkpoints for human review at key stages.

**Version:** 1.0.0
**Status:** Production-Ready
**Domain:** Content Creation & Publishing

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                  Slash Commands Layer                    │
│  /content:new | /content:research | /content:draft      │
│  /content:edit | /content:seo | /content:image          │
│  /content:publish | /content:ideate | /content:status   │
└────────────────────┬────────────────────────────────────┘
                     │ Parse arguments
                     │ Invoke agent with structured request
                     ▼
┌────────────────────────────────────────────────────────┐
│              Content Manager Agent                      │
│  - Routes tasks to appropriate skills                   │
│  - Orchestrates multi-step workflows                    │
│  - Manages checkpoints and approvals                    │
│  - Handles state transitions                            │
│  - Maintains context across workflow                    │
└────────────────────┬───────────────────────────────────┘
                     │ Invokes skills
                     ▼
┌─────────────────────────────────────────────────────────┐
│                   Skills Layer                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │ content-state-manager    │ content-researcher    │  │
│  │ content-outliner         │ content-writer        │  │
│  │ content-editor           │ content-seo-optimizer │  │
│  │ image-prompt-generator   │ image-generator       │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │ Uses tools
                     ▼
┌─────────────────────────────────────────────────────────┐
│              External Integrations                       │
│  - Claude Code Tools (Read, Edit, Write, Bash)          │
│  - WebSearch/WebFetch (research)                         │
│  - OpenAI DALL-E 3 API (image generation)               │
│  - File system (markdown files, state registry)         │
└─────────────────────────────────────────────────────────┘
```

---

## Three-Layer Architecture

### Layer 1: Commands (Entry Points)

**Location:** `commands/content/*.md`

**Purpose:** Lightweight routers that parse user input and invoke the agent

**9 Commands:**
1. `/content:new` - Full creation workflow (research → published)
2. `/content:research` - Research and outline only
3. `/content:draft` - Convert outline to draft
4. `/content:edit` - Enhance existing post
5. `/content:seo` - Optimize metadata and linking
6. `/content:image` - Generate hero image
7. `/content:publish` - Finalize and publish
8. `/content:ideate` - Brainstorm content ideas
9. `/content:status` - Check workflow progress

**Responsibilities:**
- Parse command arguments and flags
- Build structured request for agent
- Pass control to content-manager agent
- Do NOT contain workflow logic

### Layer 2: Agent (Workflow Orchestration)

**Location:** `agents/content-manager.md`

**Purpose:** Orchestrate multi-step workflows with checkpoint management

**Responsibilities:**
- Analyze user requests to determine workflow type
- Route to appropriate skills in correct sequence
- Manage semi-automated checkpoints for review:
  - After outline creation
  - After full draft
  - Before publication
- Maintain context across skill invocations
- Handle error recovery and user feedback
- Report progress and completion

**Key Design:** Semi-automated workflow
- Runs autonomously between checkpoints
- Pauses for human review at key stages
- Incorporates user feedback and continues

### Layer 3: Skills (Focused Execution)

**Location:** `skills/content/*.md`

**Purpose:** Perform specific content operations

**8 Skills:**

| Skill | Purpose | Key Operations |
|-------|---------|----------------|
| **content-state-manager** | Workflow state tracking | Validate transitions, update registry, enforce rules |
| **content-researcher** | Topic research | WebSearch, gather sources, create research brief |
| **content-outliner** | Outline creation | Structure content, plan sections, map evidence |
| **content-writer** | Blog post writing | Transform outline to full post, brand voice, citations |
| **content-editor** | Content enhancement | Update info, improve clarity, strengthen arguments |
| **content-seo-optimizer** | SEO optimization | Metadata, internal linking, keyword optimization |
| **image-prompt-generator** | DALL-E prompt creation | Analyze content, generate brand-consistent prompts |
| **image-generator** | Hero image generation | OpenAI API, WebP conversion, frontmatter update |

**Responsibilities:**
- Execute specific focused task
- Use appropriate tools (Read, Edit, Write, WebSearch, Bash)
- Output start/end messages for visibility
- Document work performed
- Report results to agent

---

## Workflow State Machine

Content moves through 7 states with validation:

```
┌──────┐    ┌─────────┐    ┌───────┐    ┌────────┐
│ idea ├───►│ outline ├───►│ draft ├───►│ review │
└──────┘    └─────────┘    └───────┘    └───┬────┘
                                             │
                    ┌────────────────────────┴──────┐
                    │                               │
                    ▼                               │ (revision)
             ┌──────────┐    ┌───────────┐         │
             │   seo    ├───►│ scheduled ├───┐     │
             └──────────┘    └───────────┘   │     │
                                              │     │
                    ┌─────────────────────────┘     │
                    │                               │
                    ▼                               │
             ┌───────────┐                          │
             │ published │◄─────────────────────────┘
             └───────────┘      (update/enhance)
```

**State Tracking:** Dual system for reliability
1. **Frontmatter:** `workflowState` field in each post
2. **Registry:** `.claude/content-state.json` with full history

---

## Content Workflow Examples

### Full Creation Workflow

**Trigger:** `/content:new "AI Agents for Solopreneurs" --depth moderate`

**Flow:**
```
1. content-researcher (5-10 min)
   └─► Research brief with 3-5 sources

2. content-outliner (2-3 min)
   └─► Structured outline

3. ⏸️  CHECKPOINT: Review outline

4. content-writer (10-15 min)
   └─► Full 1200-word draft

5. ⏸️  CHECKPOINT: Review draft

6. content-seo-optimizer (3-5 min)
   └─► Optimized metadata + internal links

7. image-prompt-generator (1 min)
   └─► DALL-E 3 prompt

8. image-generator (2 min, $0.08)
   └─► Hero image saved

9. ⏸️  CHECKPOINT: Final approval

10. Publish (if approved)
    └─► Move to blog, set published state

Total: 20-40 minutes, $0.08
```

### Edit Existing Post

**Trigger:** `/content:edit business-of-one --depth deep`

**Flow:**
```
1. content-state-manager
   └─► Transition published → review

2. content-researcher (15-30 min, deep mode)
   └─► Updated research with competitor analysis

3. content-editor
   └─► Enhanced content with new data

4. ⏸️  CHECKPOINT: Review changes

5. content-seo-optimizer
   └─► Refresh metadata

6. content-state-manager
   └─► Transition review → published

Total: 20-40 minutes, $0
```

---

## Data Flow

### State Registry (`.claude/content-state.json`)

```json
{
  "posts": {
    "ai-agents-solopreneurs": {
      "state": "draft",
      "lastUpdated": "2025-04-19T10:30:00Z",
      "location": "sandbox",
      "history": [
        {"state": "idea", "timestamp": "2025-04-18T14:00:00Z"},
        {"state": "outline", "timestamp": "2025-04-18T16:30:00Z"},
        {"state": "draft", "timestamp": "2025-04-19T10:30:00Z"}
      ],
      "notes": "Needs fact-check on AI agent costs"
    }
  }
}
```

### Post Frontmatter

```yaml
---
title: "AI Agents for Solopreneurs: Your 2025 Guide"
description: "Learn how AI agents can automate your business..."
pubDate: "Apr 19 2025"
author: "Josh McWilliam"
tags: ["AI", "solopreneurship", "automation"]
category: "Entrepreneurship"
heroImage: "/images/hero/ai-agents-solopreneurs.webp"
workflowState: "draft"
canonical: "https://www.realizedself.com/blog/ai-agents-solopreneurs/"
---
```

### Directory Structure

```
project-root/
├── src/content/
│   ├── blog/              # Published posts (workflowState: "published")
│   │   └── {slug}.md
│   └── sandbox/           # Drafts and WIP (workflowState: idea → scheduled)
│       └── {slug}.md
├── public/images/hero/    # Generated hero images
│   └── {slug}.webp
└── .claude/
    └── content-state.json # State registry
```

---

## Integration Points

### External APIs

1. **WebSearch / WebFetch**
   - Used by: content-researcher, content-editor, content-ideate
   - Purpose: Topic research, trend analysis, source gathering

2. **OpenAI DALL-E 3 API**
   - Used by: image-generator
   - Settings: HD quality, 1792x1024, $0.08/image
   - Requires: `OPENAI_API_KEY` in environment

### File Operations

**Read Operations:**
- Post content from sandbox or blog
- Research briefs
- Existing outlines
- State registry

**Write Operations:**
- New posts to sandbox
- Updated post content
- State registry updates
- Generated images to public/images/hero/

**Edit Operations:**
- Post frontmatter (state, metadata, heroImage)
- Post content (enhancement, SEO)

---

## Configuration

### Research Depth Levels

| Level | Time | Sources | Use Case |
|-------|------|---------|----------|
| **basic** | 2-3 min | 1-2 | Quick fact-checking, simple validation |
| **moderate** | 5-10 min | 3-5 | Standard new posts (DEFAULT) |
| **deep** | 15-30 min | 10+ | Cornerstone content, SEO focus, competitive analysis |

### Brand Voice Guidelines

**Realized Self Voice:**
- **Empowering:** Focus on individual capability and agency
- **Practical:** Provide actionable insights and steps
- **Evidence-based:** Incorporate research and data
- **Optimistic:** Frame AI and technology as enablers

**Framework:** Five Freedoms
- Financial Freedom
- Time Freedom
- Mental/Spiritual Freedom
- Health Freedom
- Purpose Freedom

### Quality Standards

| State | Minimum Requirements |
|-------|---------------------|
| idea | Title only |
| outline | Title + description/outline |
| draft | 500+ words, title, description |
| review | 800+ words, title, description, tags |
| seo | All review + 3-8 tags, category, canonical |
| scheduled | All seo + pubDate (future), heroImage |
| published | All scheduled + pubDate (past/today), location: blog |

---

## Extension Points

### Future Enhancements

1. **Workflow Customization**
   - Custom checkpoint configuration
   - Workflow templates for common patterns
   - Parallel skill execution where possible

2. **Multi-Brand Support**
   - Configurable brand voice guidelines
   - Custom visual styles for images
   - Flexible frontmatter schemas

3. **Advanced Features**
   - A/B testing for headlines
   - SEO performance tracking
   - Content refresh scheduling
   - Collaborative workflows (multi-user)

4. **Analytics**
   - Workflow efficiency metrics
   - State transition analytics
   - Cost tracking and reporting
   - Quality scoring

---

## Dependencies

**Required:**
- Claude Code CLI
- File system access (Read, Edit, Write tools)
- Web access (WebSearch, WebFetch tools)

**Optional:**
- OpenAI API key (for image generation)
- Existing blog infrastructure (Astro content collections or similar)

**No Plugin Dependencies:**
- Operates independently
- Does not require fractary-work, fractary-repo, or other plugins

---

## Troubleshooting

### Common Issues

**State Registry Corrupted:**
```bash
# Rebuild from frontmatter
/content:status  # Will auto-rebuild if corrupted
```

**Missing API Key:**
```bash
# Set OpenAI API key
export OPENAI_API_KEY="sk-..."
# Or skip image generation and add manually later
```

**Invalid State Transition:**
```
# Check current state
/content:status post-slug

# Follow suggested next actions
# States must follow: idea → outline → draft → review → seo → scheduled → published
```

---

## Performance Characteristics

**Workflow Times:**
- Full creation (basic): 15-20 minutes
- Full creation (moderate): 25-35 minutes
- Full creation (deep): 40-60 minutes
- Research only: 5-30 minutes
- SEO optimization: 3-5 minutes
- Image generation: 2-3 minutes
- Status check: <1 minute

**Costs:**
- Image generation: $0.08 per image
- All other operations: $0 (no external API costs)

**Context Usage:**
- Efficient 3-layer architecture
- Skills contain focused instructions
- Agent maintains workflow context
- Minimal token usage compared to monolithic approaches

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-04-19 | Initial production release |

---

## References

- [User Guide](./USER-GUIDE.md) - How to use all commands
- [Skills Reference](./SKILLS-REFERENCE.md) - Detailed skill documentation
- [SPEC-00011](../../specs/SPEC-00011-faber-article-plugin.md) - Original specification
- [Fractary Plugin Standards](../../docs/standards/FRACTARY-PLUGIN-STANDARDS.md) - Development guidelines
