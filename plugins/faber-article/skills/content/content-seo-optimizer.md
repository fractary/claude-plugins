---
name: fractary-faber-article:content-seo-optimizer
description: |
  Optimize SEO metadata and internal linking - craft SEO-friendly titles (50-60 chars), write
  compelling meta descriptions (150-160 chars), select relevant tags, assign categories, generate
  canonical URLs, identify internal link opportunities, and validate frontmatter completeness.
tools: Read, Edit, WebSearch, Grep
---

# Content SEO Optimizer Skill

## Purpose
Optimize blog post metadata, internal linking, and on-page SEO elements to improve discoverability while maintaining content quality and brand voice.

## Responsibilities

1. **Metadata Optimization**
   - Craft SEO-friendly titles (50-60 characters)
   - Write compelling meta descriptions (150-160 characters)
   - Select relevant tags from existing taxonomy
   - Assign appropriate category
   - Generate canonical URL

2. **Internal Linking**
   - Identify related existing posts for internal links
   - Suggest contextual linking opportunities
   - Build topical clusters and content hubs
   - Strengthen site architecture

3. **On-Page SEO**
   - Optimize headings for keywords
   - Ensure keyword presence in key locations
   - Validate URL slug is SEO-friendly
   - Check image alt text (when applicable)

4. **Technical Validation**
   - Verify all required frontmatter fields complete
   - Check formatting for search engine readability
   - Ensure mobile-friendly content structure
   - Validate schema markup potential

---

## SEO Metadata Standards

### Title Optimization

**Requirements:**
- 50-60 characters (with spaces)
- Include primary keyword naturally
- Front-load important words
- Compelling and click-worthy
- Match search intent
- Brand voice consistent

**Formula:**
```
[Primary Keyword] + [Benefit/Hook] + [Context if space]
```

**Examples:**

**Before (weak):**
```
title: "Some Thoughts on AI Agents"
```

**After (optimized):**
```
title: "AI Agents for Solopreneurs: Automate Your Business"
```
- 51 characters ✓
- Primary keyword: "AI Agents for Solopreneurs"
- Benefit: "Automate Your Business"
- Compelling and specific

**Examples by Intent:**

**Informational:**
```
title: "What Are AI Agents? Complete Guide for 2025"
title: "How to Build AI Agents Without Coding"
title: "AI Agent Use Cases: 12 Practical Examples"
```

**Transactional:**
```
title: "Best AI Tools for Solopreneurs (2025 Review)"
title: "Top Email Automation Tools Compared"
```

**Navigational:**
```
title: "Claude Code Tutorial: Getting Started Guide"
title: "Realized Self Framework: Five Freedoms Explained"
```

---

### Meta Description Optimization

**Requirements:**
- 150-160 characters (with spaces)
- Include primary keyword early
- Compelling value proposition
- Call to action or question
- Accurately summarize content
- Match search intent

**Formula:**
```
[Hook/Problem] + [Solution/Benefit] + [CTA/Question]
```

**Examples:**

**Before (weak):**
```
description: "This post talks about AI agents and how they can help your business."
```

**After (optimized):**
```
description: "Discover how AI agents automate 70% of repetitive tasks for solopreneurs. Learn to implement your first agent in under 2 hours—no coding required."
```
- 157 characters ✓
- Keyword: "AI agents...solopreneurs"
- Benefit: "automate 70% of tasks"
- Specific: "2 hours, no coding"
- Compelling and action-oriented

**Template Patterns:**

**How-To:**
```
"Learn how to [achieve goal]. This step-by-step guide shows you [method] to [outcome]. Start [action] today."
```

**List:**
```
"Discover [number] [solutions] for [problem]. From [example 1] to [example 2], find the right [tool/strategy] for your needs."
```

**Guide:**
```
"Master [topic] with this comprehensive guide. Understand [concept], implement [strategy], and achieve [outcome]."
```

---

### Tag Selection

**Tag Taxonomy (Realized Self):**

**Core Tags (use frequently):**
- artificial intelligence
- entrepreneurship
- solopreneurship
- personal development
- productivity
- career development
- automation
- future of work
- technology
- financial freedom

**Secondary Tags (topical):**
- AI agents
- AI ethics
- AI tools
- business automation
- career planning
- consulting
- content creation
- critical thinking
- digital literacy
- freelancing
- income diversification
- job security
- leadership
- learning & development
- machine learning
- management
- marketing
- mindset
- professional growth
- remote work
- self-employment
- side hustle
- skill development
- strategic thinking
- time management
- work-life balance
- workplace automation

**Requirements:**
- 3-8 tags per post
- Mix of broad and specific tags
- Use existing taxonomy (check `/src/content/blog/`)
- Lowercase, hyphenated format
- Relevant to content
- Include at least one core tag

**Selection Strategy:**
1. Start with 1-2 core tags (primary topics)
2. Add 2-3 specific tags (secondary topics)
3. Add 1-2 niche tags (unique angles)
4. Total: 3-8 tags

**Example:**
```yaml
# Post about AI-powered email automation for solopreneurs
tags:
  - "solopreneurship"           # Core tag
  - "artificial intelligence"    # Core tag
  - "email automation"           # Specific tag
  - "productivity"               # Secondary tag
  - "business automation"        # Specific tag
  - "time management"            # Secondary tag
```

---

### Category Assignment

**Available Categories:**
- Career Development
- Digital Wellness
- Education
- Entrepreneurship
- Financial Freedom
- Health & Wellness
- Learning & Development
- Mindset & Success
- Personal Development
- Productivity
- Technology

**Selection Criteria:**
- Choose ONE primary category
- Pick the most specific applicable category
- When multiple fit, choose based on primary theme
- Prefer specific over general
  - "Entrepreneurship" > "Career Development" for business topics
  - "Financial Freedom" > "Personal Development" for money topics
  - "Productivity" > "Technology" for workflow topics

**Decision Tree:**
```
Topic: AI tools for business
→ Business-focused? YES
  → Solopreneurship/startup? YES
    → Category: "Entrepreneurship"
  → General career? NO

Topic: Personal finance strategies
→ Money-related? YES
  → Achieving financial independence? YES
    → Category: "Financial Freedom"
  → General money management? NO

Topic: Meditation and mindfulness
→ Mental/spiritual? YES
  → Wellness and health? YES
    → Category: "Health & Wellness"
  → Success mindset? NO
```

---

### Canonical URL Generation

**Format:**
```
https://www.realizedself.com/blog/{slug}/
```

**Requirements:**
- Full URL with protocol (https://)
- Include trailing slash
- Match post slug exactly
- Lowercase only

**Example:**
```yaml
# Slug: ai-agents-guide
canonical: "https://www.realizedself.com/blog/ai-agents-guide/"
```

---

## Internal Linking Strategy

### Identifying Link Opportunities

**When to Link:**
1. **Contextual relevance**: Topic directly relates
2. **Value add**: Link enhances understanding
3. **Natural flow**: Doesn't disrupt reading
4. **Depth enhancement**: Expands on mentioned concept

**Link Placement Strategy:**
- Early in post (first 2-3 paragraphs) for cornerstone content
- Throughout body where concepts referenced
- In conclusion for "next steps" content
- Avoid link stuffing (max 3-5 internal links per 1000 words)

---

### Finding Related Content

**Search Strategy:**
1. **Tag overlap**: Posts sharing 2+ tags
2. **Category match**: Posts in same category
3. **Keyword search**: Search blog for key terms
4. **Topical clusters**: Related concepts in Five Freedoms

**Link Target Priority:**
1. **Cornerstone content**: Comprehensive guides
2. **Recent posts**: Keep fresh content circulating
3. **Complementary topics**: Related but different angle
4. **Depth expanders**: Detailed exploration of concept

---

### Link Format

**Inline Links:**
```markdown
AI agents can automate up to 70% of knowledge work tasks. If you're new to this concept, our [complete guide to AI agents for solopreneurs](/blog/ai-agents-complete-guide/) covers the fundamentals.
```

**List Format (conclusion):**
```markdown
## Continue Learning

- **Ready to implement?** Check out our [AI tools comparison for solopreneurs](/blog/best-ai-tools-solopreneurs/)
- **Want to go deeper?** Read [Building your first AI automation workflow](/blog/build-first-ai-automation/)
- **Need the big picture?** See [The complete guide to solopreneur AI adoption](/blog/solopreneur-ai-adoption-guide/)
```

**Callout Format:**
```markdown
> **Related**: For a step-by-step tutorial on implementing this, see our guide on [Getting started with AI agents](/blog/getting-started-ai-agents/).
```

---

### Building Topical Clusters

**Hub and Spoke Model:**

**Hub (Pillar Content):**
- Comprehensive topic guide
- 2000-3000+ words
- Links to all spoke content
- Example: "The Complete Guide to AI Agents for Solopreneurs"

**Spokes (Supporting Content):**
- Specific subtopics
- 800-1500 words each
- Link back to hub and to each other
- Examples:
  - "How to Choose Your First AI Agent"
  - "AI Agent Use Cases for Email Management"
  - "Building Custom AI Agents Without Code"
  - "Measuring ROI of AI Agent Implementation"

**Internal Linking Structure:**
- Hub → all spokes
- Each spoke → hub
- Spokes → related spokes (2-3 links)

---

## On-Page SEO Checklist

### Keyword Optimization

**Primary Keyword Placement:**
- [ ] In title (first 60 characters ideally)
- [ ] In meta description (first 120 characters)
- [ ] In first paragraph (first 100 words)
- [ ] In at least one H2 heading
- [ ] In URL slug
- [ ] Naturally throughout content (1-2% density)

**Secondary Keywords:**
- [ ] In subheadings (H3s)
- [ ] Scattered throughout content
- [ ] In image alt text (when applicable)

---

### Heading Optimization

**H1 (Post Title):**
- Only one per page
- Include primary keyword
- 50-60 characters
- Compelling and clear

**H2 (Main Sections):**
- 3-6 per post
- Descriptive and keyword-rich
- Parallel structure when possible
- Clear section purpose

**H3 (Subsections):**
- Support H2s logically
- Include secondary keywords
- Break up long sections
- Maintain hierarchy

**Example Heading Structure:**
```markdown
# AI Agents for Solopreneurs: Automate Your Business (H1 - Title)

## What Are AI Agents? (H2)
### Key Characteristics of AI Agents (H3)
### How AI Agents Differ from Simple Automation (H3)

## Benefits of AI Agents for Solopreneurs (H2)
### Time Savings and Efficiency Gains (H3)
### Cost Reduction Compared to Hiring (H3)
### Scalability Without Team Growth (H3)

## Implementing Your First AI Agent (H2)
### Choosing the Right Use Case (H3)
### Step-by-Step Setup Process (H3)
### Measuring Success and ROI (H3)
```

---

### URL Slug Optimization

**Best Practices:**
- Lowercase only
- Hyphens separate words (not underscores)
- 3-5 words ideal
- Include primary keyword
- Avoid stop words when possible (the, a, and, etc.)
- Keep under 60 characters

**Examples:**

**Good:**
```
ai-agents-solopreneurs
build-first-ai-agent
email-automation-guide
```

**Bad:**
```
the-complete-and-ultimate-guide-to-understanding-ai-agents-for-solopreneurs
ai_agents_guide
Post123
new-post-draft-v2-final
```

---

## Usage Instructions

### Input Parameters Expected
```yaml
slug: "post-slug-in-sandbox"
targetKeywords: ["primary keyword", "secondary keyword"]  # Optional
findInternalLinks: true  # Optional, default: true
```

### Execution Steps

1. **Read Current Post**
   - Load post from sandbox
   - Parse frontmatter and content
   - Identify current metadata state
   - Extract main topics and themes

2. **Keyword Research (if not provided)**
   - Analyze post content for main topics
   - Identify primary keyword (1-3 words)
   - Identify 2-3 secondary keywords
   - Note keyword variations and synonyms

3. **Optimize Title**
   - Review current title
   - Incorporate primary keyword
   - Ensure 50-60 characters
   - Make compelling and clear
   - Test multiple versions if needed

4. **Craft Meta Description**
   - Summarize post value
   - Include primary keyword early
   - Keep 150-160 characters
   - Add compelling hook
   - Include call to action

5. **Select Tags**
   - Review existing blog tags (`.grep "^tags:" src/content/blog/*.md`)
   - Choose 3-8 relevant tags
   - Mix core and specific tags
   - Use existing taxonomy
   - Add new tags only if necessary

6. **Assign Category**
   - Review available categories
   - Choose most specific applicable
   - Use decision tree logic
   - One category only

7. **Generate Canonical URL**
   - Use slug to create URL
   - Format: `https://www.realizedself.com/blog/{slug}/`
   - Include trailing slash

8. **Find Internal Links** (if enabled)
   - Search existing blog posts by tags
   - Search by keywords in content
   - Identify 3-5 related posts
   - Determine best placement in content
   - Draft link suggestions with context

9. **Optimize Headings** (if needed)
   - Review heading structure
   - Ensure keyword inclusion
   - Verify hierarchy (H2 → H3 → H4)
   - Make descriptive and clear

10. **Update Frontmatter**
    - Write optimized metadata to frontmatter
    - Ensure all required fields present
    - Maintain existing fields not related to SEO
    - Set workflowState to "seo"

11. **Update State**
    - Invoke content-state-manager
    - Set state to "seo"
    - Add timestamp and notes

12. **Generate SEO Report**
    - Summary of optimizations made
    - Internal link suggestions
    - Keyword usage analysis
    - Checklist completion status

---

## Integration Points

### Before
- Receives post from content-writer or content-editor
- May receive parameters from:
  - `/content:seo` command
  - `/content:new` command (via content-manager)
  - content-manager agent

### After
- Produces SEO-optimized post
- Updates content state to "seo"
- Generates optimization report
- Ready for image generation and publishing

### Used By
- `/content:seo` - Direct SEO command
- `/content:new` - Step 4 in full creation workflow
- content-manager agent - Part of orchestrated workflows

---

## SEO Optimization Report Template

```markdown
## SEO Optimization Report

**Post:** {title}
**Slug:** {slug}
**Date:** {timestamp}
**Primary Keyword:** {keyword}
**Secondary Keywords:** {keyword2}, {keyword3}

---

### Metadata Optimized

**Title:**
- **Before**: {old title}
- **After**: {new title}
- **Length**: {char count} characters
- **Keyword included**: ✓
- **Compelling**: ✓

**Meta Description:**
```
{optimized description}
```
- **Length**: {char count} characters
- **Keyword included**: ✓
- **Call to action**: ✓

**Tags:** {tag1}, {tag2}, {tag3}, {tag4}
- **Count**: {number} tags
- **Core tags included**: ✓
- **Mix of broad/specific**: ✓

**Category:** {category}

**Canonical URL:** {canonical URL}

---

### Internal Linking Opportunities

**Suggested Links:**

1. **In Section: "{section name}"**
   - Link to: [{Post Title}](/blog/{slug}/)
   - Anchor text: "{suggested anchor}"
   - Context: {why this link makes sense}

2. **In Section: "{section name}"**
   - Link to: [{Post Title}](/blog/{slug}/)
   - Anchor text: "{suggested anchor}"
   - Context: {why this link makes sense}

[Continue for 3-5 links]

---

### On-Page SEO Checklist

**Keyword Placement:**
- [✓] Title
- [✓] Meta description
- [✓] First 100 words
- [✓] H2 heading(s)
- [✓] URL slug
- [✓] Throughout content (natural density)

**Heading Structure:**
- [✓] One H1 (title)
- [✓] 3-6 H2s with keywords
- [✓] H3s properly nested
- [✓] Descriptive and clear

**Technical:**
- [✓] Slug SEO-friendly
- [✓] All frontmatter complete
- [✓] Proper markdown formatting
- [✓] Mobile-friendly structure

---

### Keyword Analysis

**Primary Keyword Density:** {percentage}%
- Target: 1-2%
- Status: {On Target|Too Low|Too High}

**Keyword Positions:**
- Title: ✓
- First paragraph: ✓
- {X} H2 headings: ✓
- {Y} times in body: ✓

---

### Next Steps

- [ ] Review suggested internal links and add where appropriate
- [ ] Generate hero image with /content:image
- [ ] Review and approve all SEO optimizations
- [ ] Run /content:publish when ready

---

**SEO Score:** {85/100}
**Optimization Level:** {Excellent|Good|Needs Work}
```

---

## Quality Standards

### SEO Optimization Checklist

**Must Have:**
- ✅ Title 50-60 characters with primary keyword
- ✅ Meta description 150-160 characters
- ✅ 3-8 relevant tags from existing taxonomy
- ✅ One appropriate category
- ✅ Canonical URL properly formatted
- ✅ Primary keyword in first 100 words
- ✅ Keywords in at least one H2

**Should Have:**
- ✅ 3-5 internal links identified
- ✅ Secondary keywords in H3s
- ✅ SEO-friendly slug
- ✅ Heading hierarchy optimized
- ✅ Keyword density 1-2%

**Nice to Have:**
- ✅ Topical cluster connections
- ✅ Related posts section
- ✅ FAQ schema potential
- ✅ Featured snippet opportunities

---

## Error Handling

### No Related Posts Found
- **Symptom**: Can't find internal linking opportunities
- **Action**: Broaden search, look for tangentially related topics
- **Output**: Note opportunity for future content cluster

### Slug Already Exists
- **Symptom**: Generated slug conflicts with existing post
- **Action**: Append differentiator (-guide, -2025, -complete, etc.)
- **Output**: Unique slug with note about conflict

### Category Ambiguous
- **Symptom**: Post fits multiple categories equally
- **Action**: Use decision tree, default to most specific
- **Output**: Category with note explaining choice

### Keyword Cannibalization
- **Symptom**: Multiple posts targeting same keyword
- **Action**: Note conflict, suggest keyword variation
- **Output**: Warning in SEO report with recommendation

---

## Best Practices

### Do
✅ Use existing tag taxonomy (check current tags first)
✅ Make titles compelling, not just keyword-stuffed
✅ Write for humans first, search engines second
✅ Include keywords naturally, not forcedly
✅ Internal link to genuinely related content
✅ Keep descriptions accurate to content
✅ Use consistent category taxonomy

### Don't
❌ Stuff keywords unnaturally
❌ Create new tags when existing ones work
❌ Change voice/tone just for SEO
❌ Add internal links that don't add value
❌ Optimize for keywords irrelevant to content
❌ Sacrifice readability for SEO
❌ Use misleading titles or descriptions

---

## Future Enhancements

Ideas for plugin version:
- Automated keyword research via API
- Search volume and competition data
- Automated schema markup generation
- Featured snippet optimization
- Image alt text optimization
- External link health checking
- Broken link monitoring
- Competitor analysis integration
- SEO score calculation
- Performance tracking integration
