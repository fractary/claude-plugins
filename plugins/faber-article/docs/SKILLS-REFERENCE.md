# Skills Reference Guide

**Faber-Article Plugin**
**Version:** 1.0.0

This document provides a comprehensive reference for all 8 skills in the faber-article plugin.

---

## Table of Contents

1. [content-state-manager](#1-content-state-manager)
2. [content-researcher](#2-content-researcher)
3. [content-outliner](#3-content-outliner)
4. [content-writer](#4-content-writer)
5. [content-editor](#5-content-editor)
6. [content-seo-optimizer](#6-content-seo-optimizer)
7. [image-prompt-generator](#7-image-prompt-generator)
8. [image-generator](#8-image-generator)

---

## 1. content-state-manager

**Purpose:** Manage workflow states throughout blog post lifecycle

**Name:** `fractary-faber-article:content-state-manager`

### Responsibilities
- Validate state transitions (idea → outline → draft → review → seo → scheduled → published)
- Update both frontmatter and state registry
- Record transition history with timestamps
- Query current states and generate reports
- Identify stalled posts
- Enforce workflow rules

### Inputs
- `post_slug`: Identifier for the post
- `target_state`: Desired new state
- `operation`: update-state | query-state | query-all | validate-transition
- `notes`: Optional context
- `location`: sandbox | blog

### Outputs
- Updated state confirmation
- State transition history
- Next suggested actions
- State registry updated in `.claude/content-state.json`
- Post frontmatter updated with `workflowState`

### Tools Used
- Read, Edit, Write

### Valid State Transitions
```
idea → outline
outline → draft
draft → review
review → draft (revision)
review → seo
seo → scheduled
scheduled → published
published → review (for updates)
```

### Usage Example
```
Invoke content-state-manager with:
- slug: "ai-productivity-tools"
- target_state: "draft"
- notes: "Ready for review after first draft"
```

### State Requirements

| State | Required Fields |
|-------|----------------|
| idea | title |
| outline | title, description/outline |
| draft | title, description, content (>500 words) |
| review | title, description, content (>800 words), tags |
| seo | review + 3-8 tags, category, canonical |
| scheduled | seo + pubDate (future), heroImage |
| published | scheduled + pubDate (past/today), location: blog |

---

## 2. content-researcher

**Purpose:** Research topics with configurable depth

**Name:** `fractary-faber-article:content-researcher`

### Responsibilities
- Conduct web research using WebSearch/WebFetch
- Gather credible sources with validation
- Generate research briefs with statistics
- Analyze topic trends and relevance
- Perform competitor analysis (deep mode)
- Conduct SEO keyword research (deep mode)
- Map topics to Five Freedoms Framework

### Inputs
- `topic`: Subject to research
- `depth`: basic | moderate | deep
- `target_word_count`: Optional (for scope planning)
- `specific_questions`: Optional focused questions
- `existing_coverage`: Optional context

### Outputs
- Research brief with sources
- Statistics with citations and dates
- Content angle recommendations
- Suggested outline structure
- Five Freedoms mapping
- SEO keywords (deep mode)
- Competitor analysis (deep mode)
- File saved to `src/content/sandbox/{slug}.md` with state: "outline"

### Tools Used
- WebSearch, WebFetch, Write

### Research Depth Levels

| Level | Time | Sources | Output |
|-------|------|---------|--------|
| **basic** | 2-3 min | 2+ | Brief summary, topic validation |
| **moderate** | 5-10 min | 5+ | Comprehensive brief, structure suggestions |
| **deep** | 15-30 min | 10+ | Extensive brief, competitor analysis, SEO keywords, content gaps |

### Source Credibility Hierarchy
1. **Tier 1**: Peer-reviewed academic papers
2. **Tier 2**: Government/institutional reports
3. **Tier 3**: Industry research firms, reputable think tanks
4. **Tier 4**: Established industry publications
5. **Tier 5**: Expert blogs with credentials
6. **Tier 6**: Opinion pieces from established sources
7. **Tier 7**: Anonymous/unverified sources (use sparingly)

### Usage Example
```
Invoke content-researcher with:
- topic: "AI Productivity Tools for Solopreneurs"
- depth: "moderate"
- target_word_count: 1500
```

---

## 3. content-outliner

**Purpose:** Convert research briefs into structured outlines

**Name:** `fractary-faber-article:content-outliner`

### Responsibilities
- Read and analyze research briefs
- Create hierarchical outline structure (H2 → H3 → bullets)
- Plan narrative flow and transitions
- Assign evidence and citations to sections
- Estimate word counts per section
- Map content to Five Freedoms Framework
- Design introduction hook and conclusion CTA

### Inputs
- `research_brief_path`: Path to research brief in sandbox
- `slug`: Post slug
- `target_word_count`: Desired post length (default: 1200-1500)
- `audience_notes`: Optional considerations

### Outputs
- Detailed hierarchical outline
- Word count estimates per section
- Evidence assignments
- Introduction hook plan
- Conclusion CTA plan
- Five Freedoms connections
- Outline appended to research brief file

### Tools Used
- Read, Edit, Write

### Outline Structure
```markdown
## Introduction (~150-200 words)
- Hook: {engaging opener}
- Context: {why this matters}
- Preview: {what's covered}

## Section 1: {Title} (~300 words)
### Subsection 1.1
- Point A
  - Evidence: {source} [{URL}]
- Point B
  - Example: {case study}

## Section 2: {Title} (~300 words)
...

## Conclusion (~150 words)
- Summary: {key takeaways}
- CTA: {action for reader}
```

### Usage Example
```
Invoke content-outliner with:
- research_brief_path: "src/content/sandbox/ai-productivity-tools.md"
- slug: "ai-productivity-tools"
- target_word_count: 1500
```

---

## 4. content-writer

**Purpose:** Transform outlines into complete blog posts

**Name:** `fractary-faber-article:content-writer`

### Responsibilities
- Write full blog post from outline (800-2000 words)
- Implement brand voice (empowering, practical, evidence-based, optimistic)
- Incorporate research and citations
- Ensure proper markdown formatting
- Maintain narrative flow
- Create compelling introduction and conclusion
- Include blockquotes and formatting for readability

### Inputs
- `outline_path`: Path to outline in sandbox
- `slug`: Post slug
- `target_word_count`: Desired length
- `style_notes`: Optional style guidance

### Outputs
- Complete blog post draft
- Proper markdown formatting
- Citations included
- Frontmatter populated
- Word count 800-2000
- State updated to "draft"

### Tools Used
- Read, Edit, Write

### Brand Voice Guidelines

**Realized Self Voice:**
- **Empowering**: Focus on individual capability and agency
- **Practical**: Provide actionable insights and steps
- **Evidence-based**: Incorporate research and data
- **Optimistic**: Frame AI and technology as enablers

**Tone Characteristics:**
- Conversational yet professional
- Encouraging without being preachy
- Informative without being academic
- Aspirational without being unrealistic

### Quality Standards
- Minimum 800 words for review state
- Citations for all statistics
- Engaging narrative flow
- Scannable format (headings, bullets, short paragraphs)
- Natural keyword integration

### Usage Example
```
Invoke content-writer with:
- outline_path: "src/content/sandbox/ai-productivity-tools.md"
- slug: "ai-productivity-tools"
- target_word_count: 1500
```

---

## 5. content-editor

**Purpose:** Review and enhance existing blog posts

**Name:** `fractary-faber-article:content-editor`

### Responsibilities
- Assess content quality and coherence
- Update outdated statistics and information
- Strengthen weak arguments with better evidence
- Improve clarity, flow, and structure
- Fix grammar and enhance readability
- Ensure brand voice consistency
- Add relevant examples and case studies
- Validate links and sources

### Inputs
- `post_path`: Path to post (sandbox or blog)
- `slug`: Post slug
- `depth`: basic | moderate | deep
- `focus_areas`: Optional specific areas to enhance

### Outputs
- Enhanced post content
- Change summary
- Editorial notes
- State potentially updated (published → review)

### Tools Used
- Read, Edit, WebSearch, WebFetch

### Enhancement Depth Levels

| Level | Time | Changes | Use When |
|-------|------|---------|----------|
| **basic** | 3-5 min | Grammar, clarity, formatting | Quick polish, typo fixes |
| **moderate** | 10-15 min | Structure, flow, evidence strengthening | Standard refresh |
| **deep** | 20-30 min | Research updates, major rewrites, new sections | Major update, competitive refresh |

### Usage Example
```
Invoke content-editor with:
- post_path: "src/content/blog/business-of-one.md"
- slug: "business-of-one"
- depth: "deep"
- focus_areas: "Update 2025 statistics, add AI automation section"
```

---

## 6. content-seo-optimizer

**Purpose:** Optimize SEO metadata and internal linking

**Name:** `fractary-faber-article:content-seo-optimizer`

### Responsibilities
- Optimize title (50-60 characters, keyword-rich)
- Craft compelling meta description (150-160 characters)
- Select 3-8 relevant tags from existing taxonomy
- Assign appropriate category
- Generate canonical URL
- Identify internal linking opportunities
- Validate frontmatter completeness
- Ensure mobile-friendly content structure

### Inputs
- `post_path`: Path to post in sandbox
- `slug`: Post slug
- `target_keywords`: Optional keyword suggestions

### Outputs
- Optimized frontmatter metadata
- SEO optimization report
- Internal link suggestions
- Tag recommendations
- State updated to "seo"

### Tools Used
- Read, Edit, WebSearch, Grep

### SEO Guidelines

**Title Optimization:**
- 50-60 characters (optimal for SERP display)
- Include primary keyword
- Compelling and click-worthy
- Maintain brand voice

**Meta Description:**
- 150-160 characters
- Include primary keyword
- Compelling value proposition
- Call to action or benefit statement

**Tags:**
- 3-8 relevant tags
- Use existing taxonomy when possible
- Mix broad and specific tags
- Include primary keyword tag

**Categories:**
- Technology
- Entrepreneurship
- Personal Development
- Career Development
- AI & Automation
- Freedom & Autonomy

### Internal Linking Strategy
- Link to related posts on similar topics
- Build topical clusters
- Use descriptive anchor text
- Aim for 2-5 internal links per post

### Usage Example
```
Invoke content-seo-optimizer with:
- post_path: "src/content/sandbox/ai-productivity-tools.md"
- slug: "ai-productivity-tools"
- target_keywords: ["AI productivity", "automation tools", "solopreneur efficiency"]
```

---

## 7. image-prompt-generator

**Purpose:** Generate DALL-E 3 prompts for brand-consistent hero images

**Name:** `fractary-faber-article:image-prompt-generator`

### Responsibilities
- Analyze post content and themes
- Extract key visual concepts
- Generate DALL-E 3 prompt matching brand visual style
- Ensure prompt follows established aesthetic guidelines
- Include required style elements (split composition, lighting contrast)

### Inputs
- `post_path`: Path to post
- `slug`: Post slug
- `custom_elements`: Optional visual elements to include

### Outputs
- DALL-E 3 optimized prompt (for 1792x1024 format)
- Rationale for visual choices
- Prompt ready for image-generator skill

### Tools Used
- Read

### Visual Style Requirements

**Realized Self Visual Style:**

1. **Split Composition** (Primary Pattern)
   - Left vs. Right contrast
   - Before/After, Old/New, Problem/Solution dichotomies
   - Dramatic visual contrast between sides

2. **Lighting Scheme**
   - **Warm tones**: Golden, sepia, warm orange, sunset
   - **Cool tones**: Electric blue, cyan, blue-purple, neon
   - **Contrast**: One side warm, other side cool
   - **Dramatic**: High contrast, cinematic lighting

3. **Thematic Elements**
   - **Technology/Digital**: Circuit patterns, holographic displays, digital streams
   - **Futuristic aesthetic**: AI interfaces, glowing elements, modern tech
   - **Human element**: Silhouettes, professional figures, individuals in action
   - **Symbolism**: Visual metaphors for concepts

4. **Quality Standards**
   - Professional high-quality digital rendering
   - Cinematic quality
   - Sharp focus
   - No text overlays
   - No visible AI artifacts

### Prompt Template
```
A split composition image: on the left, [warm-toned scene representing concept A]
with golden circuit patterns and warm lighting; on the right, [cool-toned scene
representing concept B] with cyan digital elements and cool lighting. Futuristic
aesthetic, dramatic contrast, professional high-quality rendering, no text.
```

### Usage Example
```
Invoke image-prompt-generator with:
- post_path: "src/content/sandbox/ai-productivity-tools.md"
- slug: "ai-productivity-tools"
```

---

## 8. image-generator

**Purpose:** Generate hero images via DALL-E 3 API

**Name:** `fractary-faber-article:image-generator`

### Responsibilities
- Receive DALL-E prompt from image-prompt-generator
- Call OpenAI DALL-E 3 API
- Download generated image
- Convert to WebP format (quality: 85)
- Save to `/public/images/hero/{slug}.webp`
- Update post frontmatter with heroImage path
- Handle errors with retries

### Inputs
- `prompt`: DALL-E 3 prompt (from image-prompt-generator)
- `slug`: Post slug for file naming
- `post_path`: Path to post for frontmatter update

### Outputs
- Hero image saved to `/public/images/hero/{slug}.webp`
- Post frontmatter updated with `heroImage: "/images/hero/{slug}.webp"`
- Cost report ($0.08 per image)
- Success confirmation

### Tools Used
- Bash, Edit

### Technical Specifications

**DALL-E 3 Settings:**
- Model: dall-e-3
- Quality: hd
- Size: 1792x1024 (landscape)
- Style: natural
- Cost: $0.08 per image

**Image Processing:**
- Format: WebP
- Quality: 85
- Compression: Automatic via Sharp library
- File size: Typically 150-300KB

### Error Handling
- API failures: Retry up to 3 times
- Invalid prompts: Report error, suggest regeneration
- File write errors: Report and suggest manual intervention
- Network issues: Pause and provide resume instructions

### Usage Example
```
Invoke image-generator with:
- prompt: "{DALL-E prompt from image-prompt-generator}"
- slug: "ai-productivity-tools"
- post_path: "src/content/sandbox/ai-productivity-tools.md"
```

---

## Skill Invocation Patterns

### Sequential Workflow Pattern

Most workflows invoke skills sequentially:

```
content-researcher
  ↓ (research brief created)
content-outliner
  ↓ (outline created)
content-writer
  ↓ (draft created)
content-seo-optimizer
  ↓ (SEO optimized)
image-prompt-generator
  ↓ (prompt created)
image-generator
  ↓ (image created)
content-state-manager
  ↓ (state: scheduled)
```

### State Manager Pattern

content-state-manager is invoked:
- **Before workflows**: To check current state
- **After skills**: To update state
- **On demand**: Via `/content:status` command

### Research → Edit Pattern

For updating existing posts:

```
content-state-manager (published → review)
  ↓
content-researcher (if moderate/deep)
  ↓
content-editor
  ↓
content-seo-optimizer (refresh)
  ↓
content-state-manager (review → published)
```

---

## Common Use Cases

### Use Case 1: Create New Post from Scratch
**Skills involved:** researcher → outliner → writer → seo-optimizer → image-prompt-generator → image-generator → state-manager

**Trigger:** `/content:new "Post Title" --depth moderate`

### Use Case 2: Research Without Writing
**Skills involved:** researcher → outliner → state-manager

**Trigger:** `/content:research "Topic" --depth moderate`

### Use Case 3: Write from Existing Outline
**Skills involved:** writer → state-manager

**Trigger:** `/content:draft post-slug`

### Use Case 4: Enhance Published Post
**Skills involved:** state-manager → (researcher) → editor → seo-optimizer → state-manager

**Trigger:** `/content:edit post-slug --depth deep`

### Use Case 5: Add SEO and Image Only
**Skills involved:** seo-optimizer → image-prompt-generator → image-generator

**Trigger:** `/content:seo post-slug && /content:image post-slug`

### Use Case 6: Generate Image Only
**Skills involved:** image-prompt-generator → image-generator

**Trigger:** `/content:image post-slug`

---

## Performance Benchmarks

| Skill | Typical Time | Complexity | Cost |
|-------|--------------|------------|------|
| content-state-manager | <1 min | Low | $0 |
| content-researcher (basic) | 2-3 min | Low | $0 |
| content-researcher (moderate) | 5-10 min | Medium | $0 |
| content-researcher (deep) | 15-30 min | High | $0 |
| content-outliner | 2-3 min | Low | $0 |
| content-writer | 10-15 min | Medium | $0 |
| content-editor (basic) | 3-5 min | Low | $0 |
| content-editor (moderate) | 10-15 min | Medium | $0 |
| content-editor (deep) | 20-30 min | High | $0 |
| content-seo-optimizer | 3-5 min | Low | $0 |
| image-prompt-generator | 1-2 min | Low | $0 |
| image-generator | 2-3 min | Low | $0.08 |

---

## Troubleshooting

### Skill Not Found
**Issue:** Skill fails to invoke
**Solution:** Verify plugin registration, check `.claude-plugin/plugin.json`

### Missing Dependencies
**Issue:** Skill fails due to missing tools
**Solution:** Verify WebSearch, WebFetch tools available for research skills

### State Transition Errors
**Issue:** content-state-manager rejects transition
**Solution:** Check valid transitions, use `/content:status` to see current state

### Image Generation Failures
**Issue:** image-generator fails to create image
**Solution:** Verify OpenAI API key set, check network, retry

### Research Returns No Results
**Issue:** content-researcher finds no sources
**Solution:** Broaden topic, try different search terms, adjust depth level

---

## Next Steps

- [User Guide](./USER-GUIDE.md) - How to use the commands
- [Architecture](./ARCHITECTURE.md) - System design details
- [Plugin Standards](../../docs/standards/FRACTARY-PLUGIN-STANDARDS.md) - Development guidelines

---

**Version:** 1.0.0
**Last Updated:** 2025-04-19
