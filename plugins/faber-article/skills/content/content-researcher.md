---
name: fractary-faber-article:content-researcher
description: |
  Research topics with configurable depth (basic/moderate/deep) - gather credible sources, validate
  claims, analyze trends, generate research briefs with statistics, perform competitor analysis,
  conduct SEO keyword research, and create comprehensive content research documentation.
tools: WebSearch, WebFetch, Write
---

# Content Researcher Skill

## Purpose
Research topics for blog posts with configurable depth, gathering sources, validating claims, and analyzing content opportunities aligned with Realized Self's mission.

## Research Depth Levels

### Basic (2-3 minutes)
**Use Cases:** Quick fact-checking, validating simple claims, organizing provided ideas

**Tasks:**
- Validate topic relevance to Realized Self themes (Five Freedoms Framework)
- Check basic facts and common misconceptions
- Identify 1-2 authoritative sources
- Suggest initial content angle

**Output:** Brief research summary with 1-2 sources

---

### Moderate (5-10 minutes) - **DEFAULT**
**Use Cases:** Standard new blog posts, balanced research-to-writing ratio

**Tasks:**
- All Basic level tasks
- Find 3-5 credible sources (academic, industry reports, reputable blogs)
- Gather supporting statistics and data points
- Identify key claims that need fact-checking
- Analyze topic trends and relevance
- Suggest content structure and key sections
- Check for existing coverage on Realized Self

**Output:** Comprehensive research brief with 3-5 sources, statistics, suggested outline

---

### Deep (15-30 minutes)
**Use Cases:** Cornerstone content, competitive analysis, SEO-focused strategy, content series

**Tasks:**
- All Moderate level tasks
- Competitor content analysis (top 5-10 articles on topic)
- SEO keyword research and search volume
- Content gap analysis (what's missing from existing coverage)
- Find 10+ diverse sources (academic papers, case studies, interviews)
- Identify unique angles and differentiation opportunities
- Trending discussions on social media/forums
- Related subtopics and content series potential

**Output:** Extensive research brief with 10+ sources, competitor analysis, SEO keywords, content gaps

---

## Research Process

### 1. Topic Analysis
- Break down topic into key concepts
- Identify target audience's questions and pain points
- Map to Realized Self's Five Freedoms Framework:
  - **Financial Freedom**: Money autonomy, income generation
  - **Time Freedom**: Schedule control, efficiency
  - **Mental & Spiritual Freedom**: Mindset, purpose, fulfillment
  - **Health & Energy**: Wellbeing, vitality, sustainability
  - **Purpose & Impact**: Meaning, contribution, legacy

### 2. Source Discovery Strategy

**Web Search (all depths):**
- Current articles and industry blogs
- News and trend reports
- Expert opinions and thought leaders

**Academic Search (moderate/deep):**
- Research papers and studies
- Meta-analyses and systematic reviews
- University publications

**Data Sources (moderate/deep):**
- Statistics and surveys
- Market research reports
- Government/institutional data

**Community Insights (deep):**
- Forums (Reddit, Hacker News, etc.)
- Social media discussions
- User experiences and questions

### 3. Source Credibility Hierarchy

1. **Tier 1**: Peer-reviewed academic papers
2. **Tier 2**: Government/institutional reports
3. **Tier 3**: Industry research reports
4. **Tier 4**: Expert books and thought leaders
5. **Tier 5**: Reputable news and media outlets
6. **Tier 6**: Established blogs and online publications
7. **Tier 7**: User-generated content (for anecdotes only)

### 4. Fact Validation
- Cross-reference claims across multiple sources
- Check publication dates for currency (prefer within 2-3 years)
- Evaluate source credibility and potential bias
- Note controversial or disputed claims
- Flag statistics requiring verification

### 5. Content Angle Development
- Identify unique perspectives not covered elsewhere
- Find connections to personal development and autonomy
- Suggest narrative hooks and opening angles
- Recommend examples, case studies, or stories
- Align with Realized Self voice: empowering, practical, evidence-based

---

## Output Format: Research Brief

When generating research briefs, use this markdown structure:

```markdown
# Research Brief: {Topic}

## Overview
- **Topic**: {full title}
- **Research Depth**: {basic|moderate|deep}
- **Relevance to Realized Self**: {how it fits mission and audience}
- **Target Audience**: {who this serves - solopreneurs, knowledge workers, etc.}
- **Freedom Framework Alignment**: {which freedoms this addresses}

## Key Findings
1. {Main finding or insight} - <cite>Source Name</cite>
2. {Main finding or insight} - <cite>Source Name</cite>
3. {Main finding or insight} - <cite>Source Name</cite>
[Continue based on depth level]

## Statistics & Data Points
- {Statistic with context} - <cite>Source Name, Year</cite>
- {Statistic with context} - <cite>Source Name, Year</cite>
[3-5 for moderate, 10+ for deep]

## Recommended Content Angle
{2-3 paragraphs describing:}
- The unique angle or perspective
- Narrative approach and key message
- Why this matters to the Realized Self audience
- How it connects to AI-enabled freedom and autonomy

## Suggested Outline
1. **Introduction**
   - Hook: {compelling opening - question, statistic, or story}
   - Problem/Question the post addresses
   - Preview of key insights

2. **Main Section 1**: {Section title}
   - Key points to cover
   - Evidence/examples

3. **Main Section 2**: {Section title}
   - Key points to cover
   - Evidence/examples

4. **Main Section 3**: {Section title}
   - Key points to cover
   - Evidence/examples

[Adjust sections based on topic complexity]

5. **Conclusion**
   - Key takeaway
   - Practical action steps
   - Call to action

## Sources

### Primary Sources
1. <cite>[Source Title](URL)</cite> - {What it provides: data, framework, case study, etc.}
2. <cite>[Source Title](URL)</cite> - {What it provides}
[Continue...]

### Supporting Sources
[Additional sources for moderate/deep research]

## SEO Considerations
*[Only for DEEP research level]*

- **Primary Keywords**: {keyword 1}, {keyword 2}, {keyword 3}
- **Secondary Keywords**: {keyword 4}, {keyword 5}
- **Search Intent**: {informational|navigational|transactional}
- **Competition Level**: {high|medium|low}
- **Content Gap Opportunity**: {what competitors are missing}

### Competitor Analysis
*[Only for DEEP research level]*

| Competitor | Title | Strengths | Weaknesses | Our Differentiation |
|------------|-------|-----------|------------|---------------------|
| {Site} | {Title} | {What they do well} | {What's missing} | {Our unique angle} |
[Top 3-5 competitors]

## Related Topics for Future Posts
- {Related topic 1} - {Brief note on connection}
- {Related topic 2} - {Brief note on connection}
- {Related topic 3} - {Brief note on connection}

## Notes & Caveats
- {Any controversial claims requiring careful handling}
- {Areas needing additional fact-checking}
- {Limitations of current research}
- {Questions still requiring investigation}

---

*Research completed: {date and time}*
*Depth level: {basic|moderate|deep}*
```

---

## Usage Instructions

When this skill is invoked:

### Input Parameters Expected
```yaml
topic: "The topic or title to research"
depth: "basic|moderate|deep"  # Optional, default: moderate
questions: ["Specific question 1", "Question 2"]  # Optional
wordCount: 1200  # Optional target word count for final post
```

### Execution Steps

1. **Validate Input**
   - Ensure topic is clear and focused
   - If too broad, suggest narrowing and provide 3-4 focused angles
   - Confirm depth level (default to moderate if not specified)

2. **Conduct Research**
   - Use WebSearch tool for current information and trends
   - Use WebFetch tool to read full articles and gather detailed insights
   - Follow depth-appropriate time limits
   - Document all sources with full URLs

3. **Cross-Reference & Validate**
   - Verify key claims across multiple sources
   - Check dates and ensure currency
   - Evaluate credibility
   - Note any conflicting information

4. **Analyze & Synthesize**
   - Identify patterns and key themes
   - Find unique angles and insights
   - Map to Five Freedoms Framework
   - Develop compelling narrative approach

5. **Generate Research Brief**
   - Create comprehensive markdown document
   - Include all required sections based on depth
   - Provide actionable recommendations
   - List all sources with proper citations

6. **Save Output**
   - Create file: `src/content/sandbox/{slug}.md`
   - Include frontmatter with `workflowState: "outline"`
   - Register in `.claude/content-state.json`

7. **Update State**
   - Invoke content-state-manager skill
   - Set state to "outline"
   - Add timestamp and notes

---

## Integration Points

### Before
- Receives topic and parameters from:
  - `/content:research` command
  - `/content:new` command
  - `/content:edit` command (for enhancements)
  - content-manager agent

### After
- Produces research brief file in sandbox
- Updates content state to "outline"
- Passes control to content-outliner (if part of workflow)

### Used By
- `/content:research` - Direct research command
- `/content:new` - First step in full creation workflow
- `/content:edit` - Enhancement research for existing posts
- content-manager agent - Part of orchestrated workflows

---

## Quality Standards

### Minimum Source Requirements
- **Basic**: 1-2 credible sources
- **Moderate**: 3-5 diverse credible sources
- **Deep**: 10+ sources including academic, data, expert perspectives

### Citation Format
- Use `<cite>` tags for all sources
- Include URLs in markdown links: `<cite>[Title](URL)</cite>`
- Add year for statistics: `<cite>Source Name, 2024</cite>`
- Provide context for what each source contributes

### Fact-Checking Standards
- All statistics must have citations
- Claims cross-referenced across 2+ sources
- Recent data preferred (within 2-3 years unless historical context)
- Note any contradictory findings explicitly
- Flag unverified claims for further investigation

---

## Special Considerations for Realized Self

### Brand Voice & Tone
- **Empowering**: Focus on individual capability and autonomy
- **Practical**: Actionable insights over pure theory
- **Evidence-based**: Data and research-backed recommendations
- **Optimistic**: AI as enabler, not threat

### Target Audience
- Solopreneurs and aspiring entrepreneurs
- Knowledge workers seeking autonomy
- AI-curious professionals
- People pursuing the Five Freedoms

### Content Differentiation
- **Unique Angle**: AI as tool for individual freedom and capability
- **Avoid**: Generic productivity advice, overly academic tone, AI fear-mongering
- **Emphasize**: Personal sovereignty, practical AI applications, entrepreneurial mindset

### Alignment Check
Before finalizing research, verify:
- ✅ Connects to at least one of the Five Freedoms
- ✅ Relevant to solopreneurs/knowledge workers
- ✅ AI or technology enablement angle (when applicable)
- ✅ Actionable, not just informational
- ✅ Empowering and optimistic tone

---

## Error Handling

### Topic Too Broad
- **Action**: Suggest narrowing the topic
- **Output**: Provide 3-4 focused angles to choose from
- **Example**: "AI in business" → "AI-powered customer service for solopreneurs"

### Limited Sources Available
- **Action**: Acknowledge limitation and suggest adjacent topics
- **Output**: Note in research brief, suggest related topics with better coverage

### Controversial or Disputed Topic
- **Action**: Present multiple perspectives objectively
- **Output**: Include "Notes & Caveats" section with balanced view
- **Example**: Note conflicting studies, present various viewpoints

### Outdated Information
- **Action**: Note and seek current sources
- **Output**: Explicitly state when recent data is unavailable
- **Fallback**: Use best available data with clear date context

### API Rate Limits or Errors
- **Action**: Gracefully handle search tool failures
- **Output**: Use cached knowledge, note limitations
- **Recovery**: Suggest manual research for specific gaps

---

## Examples

### Example: Basic Research Request
```
Input:
  topic: "Morning routines for productivity"
  depth: basic

Output: Research brief with:
  - 2 authoritative sources
  - 2-3 key findings
  - Simple outline (3 main sections)
  - Connection to Time Freedom
  - Estimated time: 3 minutes
```

### Example: Moderate Research Request (Default)
```
Input:
  topic: "Building AI agents for business automation"
  depth: moderate

Output: Research brief with:
  - 5 diverse sources (AI blogs, case studies, tutorials)
  - 5-7 key findings and statistics
  - Detailed outline (4-5 main sections)
  - Connection to Time Freedom + Financial Freedom
  - Existing Realized Self content check
  - Estimated time: 8 minutes
```

### Example: Deep Research Request
```
Input:
  topic: "The solopreneur economy in 2025"
  depth: deep

Output: Research brief with:
  - 12+ sources (academic papers, market research, expert opinions)
  - 10+ statistics and data points
  - Competitor analysis (5 top articles)
  - SEO keywords and search volume
  - Content gap analysis
  - Comprehensive outline (5-6 sections)
  - Related content series suggestions
  - Connection to all Five Freedoms
  - Estimated time: 25 minutes
```

---

## Performance Metrics

Track and optimize:
- **Research time** per depth level
- **Source quality** distribution (Tier 1-7)
- **Citation accuracy** and completeness
- **Content angle relevance** to Realized Self mission
- **Outline usefulness** for subsequent writing phase

---

## Future Enhancements

Ideas for plugin version:
- Configurable source preferences (academic vs. practical)
- Custom credibility hierarchy per brand
- Automated fact-checking API integration
- Source archiving for evergreen reference
- Research template customization
- Multi-language research support
