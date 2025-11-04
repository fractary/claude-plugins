# Content Creation System Specification

## Version: 1.0
**Date:** 2025-04-19
**Status:** Prototype (before migration to Faber-content plugin)
**Author:** AI-Assisted Design for Realized Self Blog

---

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Research Requirements](#research-requirements)
4. [Workflow States](#workflow-states)
5. [Skills Specification](#skills-specification)
6. [Manager Agent Specification](#manager-agent-specification)
7. [Slash Commands Specification](#slash-commands-specification)
8. [File Structure](#file-structure)
9. [Integration Points](#integration-points)
10. [User Preferences](#user-preferences)

---

## Overview

### Purpose
Create a comprehensive AI-assisted content creation system for the Realized Self blog that automates and streamlines the entire content lifecycle from ideation to publication.

### Goals
- **Efficiency**: Reduce time from idea to published post by 50%+
- **Quality**: Maintain high editorial standards with AI-assisted research and editing
- **Consistency**: Ensure all posts follow brand guidelines and SEO best practices
- **Flexibility**: Support multiple workflow depths and use cases
- **Automation**: Auto-generate hero images, optimize SEO, manage state transitions

### Scope
**Phase 1 (Current)**: Prototype implementation in Realized Self project
**Phase 2 (Future)**: Migration to Fractary Faber plugin system for multi-project use

---

## System Architecture

### Components Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│                  Slash Commands Layer                    │
│  /content:new | /content:research | /content:draft      │
│  /content:edit | /content:seo | /content:image          │
│  /content:publish | /content:ideate | /content:status   │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              Content Manager Agent                       │
│  - Routes tasks to appropriate skills                    │
│  - Orchestrates multi-step workflows                     │
│  - Manages checkpoints and approvals                     │
│  - Handles state transitions                             │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│                   Skills Layer                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │ content-state-manager    │ content-researcher    │  │
│  │ content-outliner         │ content-writer        │  │
│  │ content-editor           │ content-seo-optimizer │  │
│  │ image-prompt-generator   │ image-generator       │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│              External Integrations                       │
│  - OpenAI DALL-E 3 API (image generation)               │
│  - WebSearch/WebFetch (research)                         │
│  - Existing scripts (generate-hero-images.ts)           │
│  - Astro content collections                             │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

```
User Command → Manager Agent → Skill(s) → Content Files → State Update
                      ↓
              Checkpoint Review (if needed)
                      ↓
              Next Skill or Complete
```

---

## Research Requirements

### Depth Levels

User has specified that all depth levels should be available with configurable selection:

#### Basic (2-3 minutes)
**Use Cases:**
- Quick fact-checking for existing posts
- Validating simple claims
- Organizing provided ideas into structure

**Tasks:**
- Validate topic relevance to Realized Self themes
- Check basic facts and common misconceptions
- Identify 1-2 authoritative sources
- Suggest initial content angle

**Output:**
- Brief research summary
- 1-2 credible sources
- Basic topic validation

---

#### Moderate (5-10 minutes) - **DEFAULT**
**Use Cases:**
- Standard new blog post creation
- Enhancement of existing posts
- Balanced research-to-writing ratio

**Tasks:**
- All Basic level tasks
- Find 3-5 credible sources (academic, industry reports, reputable blogs)
- Gather supporting statistics and data points
- Identify key claims that need fact-checking
- Analyze topic trends and relevance
- Suggest content structure and key sections
- Check for existing coverage on Realized Self

**Output:**
- Comprehensive research brief
- 3-5 diverse credible sources
- Statistics with citations
- Suggested outline structure
- Content angle recommendations

---

#### Deep (15-30 minutes)
**Use Cases:**
- Cornerstone content pieces
- Competitive analysis needed
- SEO-focused content strategy
- Content series planning

**Tasks:**
- All Moderate level tasks
- Competitor content analysis (top 5-10 articles on topic)
- SEO keyword research and search volume
- Content gap analysis (what's missing from existing coverage)
- Find 10+ diverse sources (academic papers, case studies, interviews)
- Identify unique angles and differentiation opportunities
- Trending discussions on social media/forums
- Related subtopics and content series potential

**Output:**
- Extensive research brief
- 10+ diverse sources
- Competitor analysis summary
- SEO keyword recommendations
- Content gap analysis
- Related topic suggestions
- Unique angle differentiation

---

## Workflow States

### State Definitions

Content moves through these states in the workflow lifecycle:

| State | Description | Location | Required Fields | Next States |
|-------|-------------|----------|-----------------|-------------|
| **idea** | Initial concept or topic brainstorming | sandbox | title | outline |
| **outline** | Structured outline with research notes | sandbox | title, description/outline | draft |
| **draft** | Full blog post written but needs review | sandbox | title, description, content (>500 words) | review |
| **review** | Under editorial review/enhancement | sandbox | title, description, content (>800 words), tags | draft, seo |
| **seo** | SEO optimization and metadata refinement | sandbox | title, description, tags (3+), category, canonical | scheduled |
| **scheduled** | Ready for publication with future date | sandbox | All seo + pubDate (future), heroImage | published |
| **published** | Live on the blog | blog | All scheduled + pubDate (past/today) | review |

### State Tracking

**Dual-tracking system:**

1. **Frontmatter Field** (embedded in post):
```yaml
---
title: "Post Title"
workflowState: "draft"
---
```

2. **State Registry** (`.claude/content-state.json`):
```json
{
  "posts": {
    "post-slug": {
      "state": "draft",
      "lastUpdated": "2025-04-19T10:30:00Z",
      "history": [
        {"state": "idea", "timestamp": "2025-04-18T14:00:00Z"},
        {"state": "outline", "timestamp": "2025-04-18T16:30:00Z"},
        {"state": "draft", "timestamp": "2025-04-19T10:30:00Z"}
      ],
      "location": "sandbox",
      "notes": "Waiting for fact-check on statistics"
    }
  }
}
```

### Valid State Transitions

```
idea → outline
outline → draft
draft → review
review → draft (revision)
review → seo
seo → scheduled
scheduled → published
published → review (for updates/enhancements)
```

**Invalid transitions** (e.g., `idea → published`) should be blocked by content-state-manager skill.

---

## Skills Specification

### 1. content-state-manager

**Purpose:** Manage workflow states for blog posts, track content lifecycle.

**Responsibilities:**
- Validate state transitions
- Update frontmatter and state registry
- Record transition history
- Query current states
- Identify stalled posts
- Enforce workflow rules

**Inputs:**
- Post slug
- Desired state
- Optional notes

**Outputs:**
- Updated state confirmation
- Next suggested actions
- State timeline

**Files Modified:**
- `.claude/content-state.json`
- Post frontmatter in sandbox or blog

---

### 2. content-researcher

**Purpose:** Research topics with configurable depth.

**Responsibilities:**
- Conduct web research using WebSearch/WebFetch
- Gather and validate sources
- Analyze topic trends and relevance
- Generate research briefs
- Perform competitor analysis (deep mode)
- SEO keyword research (deep mode)

**Inputs:**
- Topic/title
- Research depth (basic|moderate|deep)
- Optional specific questions
- Optional target word count

**Outputs:**
- Research brief with sources
- Statistics and data points
- Recommended content angle
- Suggested outline structure
- SEO considerations (deep mode)

**Files Created:**
- `src/content/sandbox/{slug}.md` with research brief

---

### 3. content-outliner

**Purpose:** Create structured outlines from ideas or research.

**Responsibilities:**
- Convert research briefs into detailed outlines
- Structure content into logical sections
- Identify key points and supporting evidence
- Plan narrative flow and transitions
- Map to Five Freedoms Framework

**Inputs:**
- Research brief or topic
- Desired post length (words)
- Target audience considerations

**Outputs:**
- Detailed outline with:
  - Introduction hook
  - Main sections with subsections
  - Key points and evidence
  - Conclusion and CTA
  - Estimated word counts per section

**Files Modified:**
- `src/content/sandbox/{slug}.md` - adds outline to content

---

### 4. content-writer

**Purpose:** Generate full blog posts from outlines.

**Responsibilities:**
- Write engaging introduction with hook
- Develop main content sections
- Incorporate research and citations
- Maintain brand voice and tone
- Include blockquotes and formatting
- Write compelling conclusion with CTA
- Ensure proper markdown formatting

**Inputs:**
- Outline (from content-outliner)
- Research brief
- Target word count
- Style guidelines

**Outputs:**
- Full blog post draft (800-2000 words)
- Proper markdown formatting
- Citations included
- Frontmatter populated

**Files Modified:**
- `src/content/sandbox/{slug}.md` - full content

**Quality Standards:**
- Minimum 800 words for review state
- Citations for all statistics
- Engaging narrative flow
- Realized Self voice (empowering, practical, evidence-based)

---

### 5. content-editor

**Purpose:** Review and enhance existing posts.

**Responsibilities:**
- Review content quality and coherence
- Enhance clarity and engagement
- Fact-check claims and update statistics
- Improve structure and flow
- Strengthen introduction and conclusion
- Optimize readability
- Update outdated information

**Inputs:**
- Post slug (existing draft or published)
- Enhancement depth (basic|moderate|deep)
- Specific areas to focus on (optional)

**Outputs:**
- Enhanced post content
- Editorial notes on changes made
- Suggestions for further improvement

**Files Modified:**
- Post file in sandbox or blog
- State potentially updated (published → review)

**Enhancement Types:**
- **Basic**: Grammar, clarity, formatting
- **Moderate**: Structure, flow, evidence strengthening
- **Deep**: Research updates, major rewrites, new sections

---

### 6. content-seo-optimizer

**Purpose:** Optimize SEO metadata and internal linking.

**Responsibilities:**
- Optimize title for SEO (while maintaining quality)
- Craft compelling meta description (150-160 chars)
- Select appropriate tags (3-8 tags)
- Assign category
- Generate canonical URL
- Identify internal linking opportunities
- Validate frontmatter completeness

**Inputs:**
- Post slug
- Target keywords (optional)

**Outputs:**
- Optimized frontmatter metadata
- Internal link suggestions
- SEO checklist completion status

**Files Modified:**
- Post frontmatter (title, description, tags, category, canonical)

**SEO Guidelines:**
- Title: 50-60 characters, include keyword
- Description: 150-160 characters, compelling, include keyword
- Tags: 3-8 relevant tags from existing taxonomy
- Category: One primary category
- Canonical: Full URL format

---

### 7. image-prompt-generator

**Purpose:** Create DALL-E prompts matching Realized Self visual style.

**Responsibilities:**
- Analyze post content and theme
- Generate DALL-E 3 prompt following style guidelines
- Ensure prompt matches brand aesthetic
- Include required style elements (split composition, lighting contrast)

**Inputs:**
- Post title
- Post content/summary
- Key themes and concepts

**Outputs:**
- DALL-E 3 prompt (optimized for 1792x1024)
- Rationale for visual choices

**Style Requirements (from existing prompts.ts):**
- **Composition**: Split composition (left/right contrast)
- **Lighting**: Warm tones (golden, sepia) vs cool tones (blue, cyan)
- **Aesthetic**: Futuristic/digital with circuit patterns
- **Quality**: Professional high-quality rendering
- **Text**: No text overlays
- **Contrast**: Dramatic lighting contrasts

**Example Prompt Pattern:**
```
A split composition image: on the left, [warm-toned scene representing concept A]
with golden circuit patterns and warm lighting; on the right, [cool-toned scene
representing concept B] with cyan digital elements and cool lighting. Futuristic
aesthetic, dramatic contrast, professional high-quality rendering, no text.
```

---

### 8. image-generator

**Purpose:** Generate and apply hero images automatically.

**Responsibilities:**
- Generate DALL-E prompt (via image-prompt-generator)
- Call OpenAI API to generate image
- Download image to temp location
- Convert to WebP format (quality: 85)
- Save to `/public/images/hero/{slug}.webp`
- Update post frontmatter with heroImage path
- Handle errors and retries

**Inputs:**
- Post slug
- Optional: custom prompt override

**Outputs:**
- Hero image file saved
- Frontmatter updated with heroImage path
- Cost report ($0.08 per image)

**Files Created:**
- `/public/images/hero/{slug}.webp`

**Files Modified:**
- Post frontmatter: `heroImage: "/images/hero/{slug}.webp"`

**Integration:**
- Leverages existing `scripts/generate-hero-images.ts` functionality
- Uses OpenAI DALL-E 3 API (HD quality, 1792x1024)
- Uses Sharp library for WebP conversion

**Error Handling:**
- API failures: retry up to 3 times
- Invalid prompts: regenerate with fallback template
- File write errors: report and suggest manual intervention

---

## Manager Agent Specification

### content-manager Agent

**Purpose:** Orchestrate multi-step content workflows with semi-automated checkpoints.

**Workflow Style:** Semi-automated (user preference)
- Runs autonomously through logical workflow steps
- Pauses at key checkpoints for user review
- Continues after approval or incorporates feedback

**Checkpoints:**
1. **After outline creation** → Review before drafting
2. **After full draft** → Review before SEO optimization
3. **Before publish** → Final approval and state transition

**Responsibilities:**

1. **Task Routing**
   - Analyze user request
   - Determine required skills
   - Route to appropriate skill(s)
   - Chain multiple skills if needed

2. **Workflow Orchestration**
   - Execute multi-step workflows
   - Manage state transitions between steps
   - Handle dependencies (e.g., research before outline)
   - Coordinate checkpoint pauses

3. **Context Management**
   - Maintain context across skill invocations
   - Pass outputs from one skill as inputs to next
   - Track overall workflow progress

4. **Error Recovery**
   - Handle skill failures gracefully
   - Suggest alternatives if blocked
   - Report issues clearly to user

**Supported Workflows:**

### Full Creation (idea → published)
```
1. content-researcher (depth: user-specified)
   → CHECKPOINT: Review research brief
2. content-outliner
   → CHECKPOINT: Review outline
3. content-writer
   → CHECKPOINT: Review draft
4. content-seo-optimizer
5. image-generator
6. content-state-manager (move to blog, set published)
   → CHECKPOINT: Final approval before publish
```

### Enhancement (published → updated)
```
1. content-state-manager (published → review)
2. content-researcher (depth: user-specified)
3. content-editor
   → CHECKPOINT: Review changes
4. content-seo-optimizer (refresh metadata)
5. content-state-manager (review → published)
   → CHECKPOINT: Final approval
```

### Quick Draft (outline → seo)
```
1. content-writer
   → CHECKPOINT: Review draft
2. content-seo-optimizer
```

**Input Format:**
```
Request: {user command or natural language request}
Context: {current state, existing files, user preferences}
```

**Output Format:**
```
Workflow Plan:
  1. {skill} - {purpose}
  2. {skill} - {purpose}
  ...

Current Step: {N/M}
Status: {in-progress|checkpoint|completed}

[Checkpoint prompts when applicable]
Next: {action description}
```

---

## Slash Commands Specification

### Command Structure

All commands follow pattern: `/content:{action} [args] [--flags]`

---

### /content:new

**Purpose:** Create new blog post from scratch (full workflow).

**Syntax:**
```
/content:new <title> [--depth basic|moderate|deep]
```

**Arguments:**
- `<title>` (required): Blog post title
- `--depth` (optional): Research depth, default: moderate

**Workflow:**
1. Invoke content-manager with "full creation" workflow
2. Research → Outline → CHECKPOINT → Draft → CHECKPOINT → SEO → Image → CHECKPOINT

**Example:**
```
/content:new "AI-Powered Personal Branding" --depth deep
```

**Output:**
- Complete blog post in sandbox
- Hero image generated
- State: scheduled (ready for publish)

---

### /content:research

**Purpose:** Research topic and create outline only.

**Syntax:**
```
/content:research <topic> [--depth basic|moderate|deep]
```

**Arguments:**
- `<topic>` (required): Topic or title to research
- `--depth` (optional): Research depth, default: moderate

**Workflow:**
1. Invoke content-researcher
2. Invoke content-outliner
3. Set state to "outline"

**Example:**
```
/content:research "Building AI-First Workflows" --depth moderate
```

**Output:**
- Research brief + outline in sandbox
- State: outline

---

### /content:draft

**Purpose:** Convert outline to full draft.

**Syntax:**
```
/content:draft <slug>
```

**Arguments:**
- `<slug>` (required): Post slug in sandbox

**Prerequisites:**
- Post must exist in sandbox with state "outline"

**Workflow:**
1. Invoke content-writer
2. CHECKPOINT: Review draft
3. Set state to "draft"

**Example:**
```
/content:draft building-ai-workflows
```

**Output:**
- Full draft content
- State: draft

---

### /content:edit

**Purpose:** Review and enhance existing post.

**Syntax:**
```
/content:edit <slug> [--depth basic|moderate|deep]
```

**Arguments:**
- `<slug>` (required): Post slug (sandbox or blog)
- `--depth` (optional): Enhancement depth, default: moderate

**Workflow:**
1. If published, transition to "review" state
2. Invoke content-researcher (if moderate/deep)
3. Invoke content-editor
4. CHECKPOINT: Review changes

**Example:**
```
/content:edit business-of-one --depth deep
```

**Output:**
- Enhanced content
- State: review

---

### /content:seo

**Purpose:** Optimize SEO metadata and internal links.

**Syntax:**
```
/content:seo <slug>
```

**Arguments:**
- `<slug>` (required): Post slug in sandbox

**Workflow:**
1. Invoke content-seo-optimizer
2. Set state to "seo"

**Example:**
```
/content:seo business-of-one
```

**Output:**
- Optimized frontmatter
- Internal link suggestions
- State: seo

---

### /content:image

**Purpose:** Generate hero image for post.

**Syntax:**
```
/content:image <slug> [--prompt "custom prompt"]
```

**Arguments:**
- `<slug>` (required): Post slug
- `--prompt` (optional): Override with custom DALL-E prompt

**Workflow:**
1. Invoke image-prompt-generator (unless custom prompt)
2. Invoke image-generator
3. Update frontmatter with image path

**Example:**
```
/content:image business-of-one
```

**Output:**
- Hero image generated and saved
- Frontmatter updated
- Cost: $0.08

---

### /content:publish

**Purpose:** Finalize and publish post.

**Syntax:**
```
/content:publish <slug> [--date "YYYY-MM-DD"]
```

**Arguments:**
- `<slug>` (required): Post slug in sandbox
- `--date` (optional): Publication date, default: today

**Prerequisites:**
- Post must have:
  - Complete content (>800 words)
  - SEO metadata (title, description, tags, category)
  - Hero image
  - Valid frontmatter

**Workflow:**
1. Validate prerequisites
2. Generate hero image if missing
3. Set pubDate in frontmatter
4. Move file from sandbox to blog
5. Set state to "published"
6. CHECKPOINT: Confirm publication

**Example:**
```
/content:publish business-of-one --date "2025-04-20"
```

**Output:**
- Post moved to `src/content/blog/`
- State: published
- Ready for build/deployment

---

### /content:ideate

**Purpose:** Brainstorm content ideas with research.

**Syntax:**
```
/content:ideate [topic-area]
```

**Arguments:**
- `[topic-area]` (optional): General area to brainstorm

**Workflow:**
1. Use WebSearch to find trending topics
2. Analyze existing blog posts for gaps
3. Map to Five Freedoms Framework
4. Generate 5-10 content ideas with brief rationale
5. Create "idea" state posts for top 3

**Example:**
```
/content:ideate entrepreneurship
```

**Output:**
- List of 5-10 content ideas
- Top 3 saved as "idea" state posts in sandbox

---

### /content:status

**Purpose:** Show content workflow state and next steps.

**Syntax:**
```
/content:status [slug]
```

**Arguments:**
- `[slug]` (optional): Specific post slug, or all if omitted

**Workflow:**
1. Invoke content-state-manager query
2. Display current state, timeline, next actions

**Example:**
```
/content:status business-of-one
```

**Output:**
```
Post: The Business of One
Slug: business-of-one
Current State: draft
Location: sandbox
Last Updated: 2025-04-19 10:30 AM

Next Actions:
  - Review draft content for quality
  - Run /content:seo business-of-one
  - Run /content:image business-of-one

Timeline:
  idea     | 2025-04-18 14:00
  outline  | 2025-04-18 16:30
  draft    | 2025-04-19 10:30
```

---

## File Structure

### Claude Configuration

```
.claude/
├── agents/
│   └── content-manager.md              # Manager agent orchestration
├── skills/
│   └── content/
│       ├── content-state-manager.md    # State tracking
│       ├── content-researcher.md       # Research skill
│       ├── content-outliner.md         # Outline creation
│       ├── content-writer.md           # Draft writing
│       ├── content-editor.md           # Enhancement/editing
│       ├── content-seo-optimizer.md    # SEO optimization
│       ├── image-prompt-generator.md   # DALL-E prompt creation
│       └── image-generator.md          # Image generation
├── commands/
│   └── content/
│       ├── new.md                      # /content:new
│       ├── research.md                 # /content:research
│       ├── draft.md                    # /content:draft
│       ├── edit.md                     # /content:edit
│       ├── seo.md                      # /content:seo
│       ├── image.md                    # /content:image
│       ├── publish.md                  # /content:publish
│       ├── ideate.md                   # /content:ideate
│       └── status.md                   # /content:status
└── content-state.json                  # State registry
```

### Content Files

```
src/content/
├── blog/                               # Published posts
│   ├── business-of-one.md
│   ├── ai-agents-guide.md
│   └── ...
└── sandbox/                            # Draft/WIP posts
    ├── new-post-idea.md               # workflowState: idea
    ├── post-outline.md                # workflowState: outline
    └── post-draft.md                  # workflowState: draft
```

### Generated Assets

```
public/images/hero/
├── business-of-one.webp
├── ai-agents-guide.webp
└── ...
```

---

## Integration Points

### Existing Systems

1. **Astro Content Collections**
   - Schema: `src/content.config.ts`
   - Blog collection: `src/content/blog/`
   - Sandbox collection: `src/content/sandbox/`

2. **Image Generation Script**
   - Script: `scripts/generate-hero-images.ts`
   - Prompts: `scripts/prompts.ts`
   - Integration: image-generator skill wraps this functionality

3. **OpenAI API**
   - DALL-E 3 for image generation
   - Requires: `OPENAI_API_KEY` in `.env`
   - Cost: $0.08 per HD image (1792x1024)

4. **Claude Plugins**
   - `fractary-repo`: Git operations, commits, PRs
   - `fractary-work`: Issue tracking
   - `fractary-faber`: Workflow management (future integration)

### External APIs

- **WebSearch**: Topic research, trend analysis
- **WebFetch**: Full article reading, source validation
- **OpenAI DALL-E 3**: Hero image generation

### File Formats

- **Markdown (.md)**: All blog content
- **YAML frontmatter**: Post metadata
- **JSON**: State tracking (`.claude/content-state.json`)
- **WebP**: Hero images (quality: 85)

---

## User Preferences

Based on requirements gathering:

### Research Depth
- **Default**: Moderate
- **Configurable**: Per-command via `--depth` flag
- **Use cases**: All depth levels (basic, moderate, deep) are valid

### Image Generation
- **Mode**: Automatic - Generate & apply
- **No approval needed**: System generates and updates frontmatter automatically
- **Cost tolerance**: Accepted at $0.08/image

### Workflow States
- **Track**: idea, outline, draft, review, seo, scheduled, published
- **Purpose**: Full visibility into content lifecycle
- **Enhancement**: Support updating published posts back to review state

### Workflow Automation
- **Style**: Semi-automated with checkpoints
- **Checkpoints**:
  1. After outline → review before drafting
  2. After draft → review before SEO
  3. Before publish → final approval
- **Autonomous**: Between checkpoints, system runs without interruption

### Content Standards

- **Brand Voice**: Empowering, practical, evidence-based
- **Tone**: Professional yet accessible
- **Focus**: AI-enabled individual freedom and autonomy
- **Audience**: Solopreneurs, knowledge workers, aspiring entrepreneurs
- **Framework**: Five Freedoms (Financial, Time, Mental/Spiritual, Health, Purpose)

### Quality Minimums

- **Draft state**: 500+ words
- **Review state**: 800+ words
- **Sources**:
  - Basic: 1-2
  - Moderate: 3-5
  - Deep: 10+
- **SEO**: Tags (3-8), description (150-160 chars), category, canonical URL
- **Images**: Required before publish, 1792x1024 WebP format

---

## Migration Path to Faber-Content

### Phase 1: Prototype (Current)
- Build and test in Realized Self project
- Validate workflows and user experience
- Refine based on real-world usage
- Document lessons learned

### Phase 2: Abstraction
- Extract Realized Self-specific configuration
- Generalize skills for multi-brand use
- Create plugin configuration schema
- Add customization points

### Phase 3: Plugin Development
- Create `fractary-faber:content` or `fractary-faber:article` plugin
- Integrate with existing Faber workflow system
- Add multi-project support
- Create plugin documentation

### Customization Points for Plugin
- Brand voice and tone guidelines
- Visual style for images
- Frontmatter schema
- Content directory structure
- SEO requirements
- Publishing workflows
- Research source preferences

---

## Appendix: Frontmatter Schema

### Complete Schema (Astro Content Collection)

```yaml
---
# Required fields
title: "Post Title"                           # String, 50-60 chars for SEO
description: "Brief summary"                   # String, 150-160 chars
pubDate: "Apr 19 2025"                        # String, format: "MMM DD YYYY"

# Optional fields
updatedDate: "Apr 20 2025"                    # String, same format as pubDate
author: "Josh McWilliam"                      # String, author name
tags: ["tag1", "tag2", "tag3"]                # Array of strings, 3-8 tags
category: "Entrepreneurship"                   # String, single category
heroImage: "/images/hero/post-slug.webp"      # String, path to hero image
draft: false                                   # Boolean, default: false
canonical: "https://www.realizedself.com/blog/post-slug/" # String, full URL

# Workflow tracking (added by content system)
workflowState: "draft"                        # String, one of workflow states
---
```

### Valid Categories
- Technology
- Entrepreneurship
- Personal Development
- Career Development
- AI & Automation
- Freedom & Autonomy

### Tag Taxonomy (Examples)
- artificial intelligence
- entrepreneurship
- solopreneurship
- personal growth
- productivity
- financial freedom
- time management
- mental health
- ai agents
- automation
- business strategy

---

## Appendix: Example Workflows

### Example 1: New Post from Idea

**Command:**
```bash
/content:new "How to Build Your First AI Agent" --depth moderate
```

**Execution:**
1. content-researcher: Research AI agents, tutorials, beginner resources (5-10 min)
2. content-outliner: Create structured outline from research
3. **CHECKPOINT**: User reviews outline, approves or requests changes
4. content-writer: Write full 1200-word draft
5. **CHECKPOINT**: User reviews draft, approves or requests edits
6. content-seo-optimizer: Optimize metadata and suggest internal links
7. image-prompt-generator + image-generator: Create hero image
8. content-state-manager: Set to "scheduled"
9. **CHECKPOINT**: Final approval before publish

**Result:**
- File: `src/content/sandbox/build-first-ai-agent.md`
- State: scheduled
- Image: `/public/images/hero/build-first-ai-agent.webp`
- Ready for `/content:publish`

---

### Example 2: Enhance Existing Post

**Command:**
```bash
/content:edit business-of-one --depth deep
```

**Execution:**
1. content-state-manager: Transition from "published" to "review"
2. content-researcher: Deep research with competitor analysis, new data (15-30 min)
3. content-editor: Update statistics, add new sections, improve flow
4. **CHECKPOINT**: User reviews changes
5. content-seo-optimizer: Refresh metadata
6. content-state-manager: Back to "published"
7. **CHECKPOINT**: Confirm publication

**Result:**
- File: `src/content/blog/business-of-one.md` (updated)
- State: published
- Updated with latest research and improved content

---

### Example 3: Quick Image for Existing Post

**Command:**
```bash
/content:image productivity-hacks-ai
```

**Execution:**
1. Read post content
2. image-prompt-generator: Create DALL-E prompt based on content
3. image-generator: Generate and save image
4. Update frontmatter with `heroImage` path

**Result:**
- Image: `/public/images/hero/productivity-hacks-ai.webp`
- Frontmatter updated
- Cost: $0.08

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-04-19 | Initial specification based on requirements gathering |

---

## References

- Existing image generation: `scripts/generate-hero-images.ts`
- Visual style guidelines: `scripts/prompts.ts`
- Content schema: `src/content.config.ts`
- Example posts: `src/content/blog/`
- Claude plugins: `.claude/settings.json`
