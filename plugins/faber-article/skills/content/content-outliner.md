# Content Outliner Skill

## Purpose
Convert research briefs and ideas into detailed, structured outlines ready for content creation, ensuring logical flow and comprehensive coverage.

## Responsibilities

1. **Structure Development**
   - Transform research findings into logical content structure
   - Organize ideas hierarchically (sections → subsections → key points)
   - Plan narrative flow and transitions
   - Ensure comprehensive coverage of topic

2. **Framework Alignment**
   - Map content to Realized Self's Five Freedoms Framework
   - Identify opportunities to connect concepts
   - Ensure brand voice and mission alignment

3. **Evidence Planning**
   - Assign research findings and statistics to appropriate sections
   - Plan where to incorporate citations
   - Identify examples and case studies placement
   - Note areas needing additional support

4. **Word Count Planning**
   - Estimate word counts per section
   - Balance section lengths appropriately
   - Ensure meets minimum requirements (800+ words for review state)

---

## Outline Structure Template

```markdown
# {Post Title}

## Frontmatter
---
title: "{Compelling, SEO-friendly title}"
description: "{Brief 1-2 sentence summary}"
workflowState: "outline"
tags: ["{preliminary tag 1}", "{tag 2}", "{tag 3}"]
category: "{Primary category}"
draft: true
---

## Outline

### Introduction (150-200 words)
**Hook Options:**
1. {Compelling question}
2. {Surprising statistic} - <cite>Source</cite>
3. {Relatable story or scenario}

**Problem/Question:**
- What challenge or question does this address?
- Why should the reader care?
- How does this relate to their journey toward freedom/autonomy?

**Preview:**
- Brief overview of what the post will cover
- Key insight or takeaway teaser
- Connection to Realized Self's mission

**Freedom Framework Connection:**
- {Which of the Five Freedoms this primarily addresses}
- {Brief note on why it matters}

---

### Section 1: {Section Title} (250-350 words)
**Main Points:**
- {Key point 1}
  - Supporting evidence: {statistic/source}
  - Example: {brief example}
- {Key point 2}
  - Supporting evidence: {statistic/source}
  - Example: {brief example}
- {Key point 3}

**Evidence to Include:**
- <cite>Source 1</cite> - {What it provides}
- <cite>Source 2</cite> - {What it provides}

**Narrative Approach:**
{How to present this section - storytelling, analytical, instructional, etc.}

**Transition to Next Section:**
{Bridge concept or question that leads to next section}

---

### Section 2: {Section Title} (250-350 words)
**Main Points:**
- {Key point 1}
- {Key point 2}
- {Key point 3}

**Evidence to Include:**
- <cite>Source</cite> - {What it provides}

**Examples/Case Studies:**
- {Example 1}: {Brief description}
- {Example 2}: {Brief description}

**Narrative Approach:**
{How to present this section}

**Transition to Next Section:**
{Bridge concept}

---

### Section 3: {Section Title} (250-350 words)
[Same structure as Section 2]

---

### Section 4: {Section Title} (Optional, 200-300 words)
[Add more sections as needed based on topic complexity]

---

### Conclusion (150-200 words)
**Key Takeaway:**
- {Main insight or lesson}
- {How it empowers the reader}
- {Connection back to opening hook}

**Practical Action Steps:**
1. {Immediate action reader can take}
2. {Next step in their journey}
3. {How to go deeper}

**Call to Action:**
- {Invitation to engage - explore related content, try a tool, reflect on a question}

**Freedom Framework Tie-In:**
- {How applying this knowledge leads to specific freedom(s)}

---

## Research Summary Reference

**Sources Used:**
1. <cite>[Source 1](URL)</cite>
2. <cite>[Source 2](URL)</cite>
[List all sources for easy reference during writing]

**Key Statistics:**
- {Stat 1} - <cite>Source</cite>
- {Stat 2} - <cite>Source</cite>

**Unique Angle:**
{Reiterate the differentiation and unique perspective}

---

**Estimated Total Word Count:** {1200-2000 words}
**Target Audience:** {Solopreneurs/Knowledge workers/Aspiring entrepreneurs}
**Tone:** {Empowering, Practical, Optimistic}
**Primary Freedom:** {Financial/Time/Mental/Health/Purpose}
```

---

## Usage Instructions

### Input Parameters Expected
```yaml
researchBrief: "Path to research brief file or research content"
targetWordCount: 1200  # Optional, default: 1200-1500
sections: 4  # Optional, default: 3-4
focus: "specific aspect to emphasize"  # Optional
```

### Execution Steps

1. **Read Research Brief**
   - Parse research brief from sandbox file
   - Extract key findings, sources, and recommended angle
   - Identify main themes and subtopics

2. **Determine Structure**
   - Decide number of main sections (typically 3-5)
   - Assign key findings to appropriate sections
   - Plan logical progression of ideas
   - Ensure balanced coverage

3. **Create Section Framework**
   - Title each section descriptively
   - List 2-4 main points per section
   - Assign evidence and sources
   - Note examples and case studies
   - Plan transitions

4. **Plan Introduction**
   - Generate 2-3 hook options
   - Define the problem/question clearly
   - Create preview that entices reading
   - Connect to Freedom Framework

5. **Plan Conclusion**
   - Synthesize key takeaway
   - Develop 2-3 actionable steps
   - Craft compelling call to action
   - Tie back to mission and freedoms

6. **Estimate Word Counts**
   - Assign word count targets per section
   - Ensure total meets target (default: 1200-1500)
   - Balance sections appropriately
   - Note if any section needs more/less depth

7. **Add Metadata**
   - Include preliminary frontmatter
   - Set workflowState to "outline"
   - Add preliminary tags based on topic
   - Assign category

8. **Save Outline**
   - Update existing sandbox file or create new
   - Replace research brief section with detailed outline
   - Keep research summary at bottom for reference
   - Ensure proper markdown formatting

9. **Update State**
   - Invoke content-state-manager
   - Set state to "outline"
   - Add timestamp and notes

---

## Outline Quality Standards

### Completeness
- ✅ Introduction with hook, problem, and preview
- ✅ 3-5 main content sections
- ✅ Conclusion with takeaway, action steps, and CTA
- ✅ All sections have 2-4 main points
- ✅ Evidence assigned to relevant sections
- ✅ Transitions planned between sections

### Clarity
- ✅ Section titles are descriptive and parallel
- ✅ Main points are specific and clear
- ✅ Logical flow from introduction to conclusion
- ✅ No orphaned ideas or gaps in logic

### Strategic Planning
- ✅ Sources distributed throughout (not clustered)
- ✅ Examples and case studies identified
- ✅ Hook options provided for introduction
- ✅ Word count targets set per section
- ✅ Tone and narrative approach specified

### Brand Alignment
- ✅ Connected to Five Freedoms Framework
- ✅ Unique angle from research brief maintained
- ✅ Empowering and practical tone planned
- ✅ Target audience considerations noted

---

## Section Count Guidelines

Choose number of sections based on topic complexity:

### 3 Sections (Simple Topics)
- **Best for**: Single-concept posts, how-to guides, quick insights
- **Example**: "3 AI Tools for Email Management"
  - Section 1: Tool 1
  - Section 2: Tool 2
  - Section 3: Tool 3

### 4 Sections (Standard Topics)
- **Best for**: Most blog posts, balanced coverage
- **Example**: "Building an AI-Powered Workflow"
  - Section 1: Understanding workflow automation
  - Section 2: Choosing the right tools
  - Section 3: Implementation strategies
  - Section 4: Measuring impact and iteration

### 5+ Sections (Complex Topics)
- **Best for**: Comprehensive guides, cornerstone content, multi-faceted topics
- **Example**: "The Complete Guide to Solopreneurship"
  - Section 1: The solopreneur mindset
  - Section 2: Business model selection
  - Section 3: AI tools and automation
  - Section 4: Marketing and client acquisition
  - Section 5: Scaling sustainably
  - Section 6: Long-term strategy

---

## Narrative Approaches

### Problem-Solution
- **Structure**: Problem → Impact → Solution → Implementation → Results
- **Best for**: Addressing specific challenges
- **Example**: "Overcoming Time Scarcity as a Solopreneur"

### Framework/Process
- **Structure**: Overview → Step 1 → Step 2 → Step 3 → Summary
- **Best for**: How-to guides, methodologies
- **Example**: "5 Steps to Launch Your AI-Powered Business"

### Analytical
- **Structure**: Context → Analysis → Implications → Recommendations
- **Best for**: Trend analysis, research-heavy topics
- **Example**: "The Rise of AI Agents in 2025"

### Story-Driven
- **Structure**: Story → Lessons → Application → Your Turn
- **Best for**: Inspirational content, case studies
- **Example**: "How One Entrepreneur Achieved Time Freedom with AI"

### Comparative
- **Structure**: Option A → Option B → Comparison → Recommendation
- **Best for**: Tool reviews, approach comparisons
- **Example**: "Building vs. Buying AI Agents for Your Business"

---

## Integration Points

### Before
- Receives research brief from content-researcher skill
- May receive target parameters from:
  - `/content:research` command
  - `/content:new` command
  - content-manager agent

### After
- Produces detailed outline in sandbox file
- Updates content state to "outline"
- Ready for content-writer skill or human review

### Used By
- `/content:research` - Final output of research workflow
- `/content:new` - Step 2 in full creation workflow
- content-manager agent - Part of orchestrated workflows

---

## Examples

### Example: Simple 3-Section Outline
```markdown
Topic: "3 AI Tools Every Solopreneur Should Use"
Target: 1000 words
Sections: 3 (one per tool)

Introduction (150 words)
  Hook: "What if you could reclaim 10 hours per week?"
  Problem: Time scarcity for solopreneurs
  Preview: 3 essential AI tools

Section 1: AI Writing Assistant (250 words)
  What it is, how it saves time, example use cases

Section 2: AI Email Management (250 words)
  Features, benefits, real-world application

Section 3: AI Meeting Scheduler (250 words)
  Automation benefits, implementation tips

Conclusion (150 words)
  Takeaway: Small AI investments, big time returns
  Action: Start with one tool this week
  CTA: Explore advanced automation strategies
```

### Example: Complex 5-Section Outline
```markdown
Topic: "Building Your Freedom-Based Business Model"
Target: 2000 words
Sections: 5 (multi-faceted topic)

Introduction (200 words)
  Hook: Statistics on solopreneur growth
  Problem: Traditional business models limit freedom
  Preview: New model for freedom-based entrepreneurship

Section 1: Defining Freedom in Business (350 words)
  Five Freedoms framework application
  Personal freedom metrics

Section 2: Revenue Model Design (350 words)
  Passive vs. active income
  Scalability considerations

Section 3: AI-Powered Operations (350 words)
  Automation strategies
  Tool ecosystem

Section 4: Time Architecture (350 words)
  Calendar design for freedom
  Batching and delegation

Section 5: Growth Without Sacrifice (350 words)
  Sustainable scaling
  Maintaining freedom as you grow

Conclusion (200 words)
  Takeaway: Freedom is designed, not accidental
  Action: Audit current business model
  CTA: Design your freedom metrics
```

---

## Error Handling

### Insufficient Research
- **Symptom**: Research brief lacks depth for outline
- **Action**: Request additional research or note areas needing more investigation
- **Output**: Create outline with gaps marked for future research

### Topic Too Broad
- **Symptom**: Outline requires 8+ sections for coverage
- **Action**: Suggest narrowing scope or splitting into series
- **Output**: Provide option to focus on specific aspect or create content series plan

### Unclear Narrative Flow
- **Symptom**: Sections don't connect logically
- **Action**: Reorganize sections, add better transitions
- **Output**: Test different organizational structures (chronological, priority-based, etc.)

### Imbalanced Sections
- **Symptom**: One section is 600 words while others are 200
- **Action**: Redistribute content or split oversized section
- **Output**: Balance word counts while maintaining topic integrity

---

## Best Practices

### For the Outliner
1. **Start with the why**: Every section should have clear purpose
2. **Plan transitions**: Don't leave sections disconnected
3. **Be specific**: "Main point" isn't enough - spell out the actual point
4. **Assign evidence**: Don't save source-matching for writing phase
5. **Think reader journey**: How does each section move them forward?

### For the Writer (using this outline)
1. Follow the structure but adapt if needed
2. Expand on points naturally - word counts are targets, not limits
3. Use transitions as bridges between sections
4. Incorporate all assigned sources but add more if helpful
5. Let the outline guide, not constrain, your writing

---

## Future Enhancements

Ideas for plugin version:
- Alternative outline structures (listicle, pillar page, ultimate guide)
- A/B outline options for user selection
- Auto-generate internal linking opportunities
- Outline templates by content type
- Collaborative outline editing workflow
