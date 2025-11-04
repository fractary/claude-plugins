# Content State Manager Skill

## Purpose
Manage workflow states for blog posts, tracking content through the entire lifecycle from idea to publication.

## Workflow States

1. **idea** - Initial concept or topic brainstorming
2. **outline** - Structured outline with research notes
3. **draft** - Full blog post written but needs review
4. **review** - Under editorial review/enhancement
5. **seo** - SEO optimization and metadata refinement
6. **scheduled** - Ready for publication with future date
7. **published** - Live on the blog

## State Tracking

Content state is tracked in two ways:

1. **Frontmatter Field** (for sandbox posts):
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

## Responsibilities

### 1. State Transitions
- Validate state transitions follow logical workflow
- Update both frontmatter and state registry
- Record transition history with timestamps
- Prevent invalid transitions (e.g., idea → published)

### 2. Status Queries
- Get current state of any post
- List all posts in a specific state
- Show state history and timeline
- Identify stalled posts (no updates in X days)

### 3. Workflow Enforcement
- Ensure posts move through appropriate stages
- Flag posts missing required fields for their state
- Suggest next actions based on current state
- Track completion of state-specific tasks

## Usage Instructions

When invoked, this skill should:

1. **Initialize State Tracking**
   - Create `.claude/content-state.json` if it doesn't exist
   - Scan existing posts and register their states
   - Validate frontmatter consistency

2. **Update State**
   ```
   Usage: Update post to new state
   - Post slug: {slug}
   - Current state: {current}
   - New state: {new}
   - Location: sandbox|blog
   - Notes: Optional context
   ```

3. **Query States**
   ```
   - Get state of post: {slug}
   - List all posts in state: {state}
   - Show posts updated before: {date}
   - Get workflow timeline for: {slug}
   ```

4. **Validate Transitions**
   Valid transitions:
   - idea → outline
   - outline → draft
   - draft → review
   - review → draft (revision)
   - review → seo
   - seo → scheduled
   - scheduled → published
   - published → review (for updates)

## Integration Points

- **Before**: Receives post slug and desired state
- **After**: Updates state files and returns confirmation
- **Used by**: All content workflow commands and content-manager agent

## File Operations

When updating state:
1. Read `.claude/content-state.json`
2. Read post frontmatter from appropriate location
3. Validate transition is allowed
4. Update frontmatter `workflowState` field
5. Update state registry with timestamp
6. Write both files back
7. Return updated state and next suggested actions

## State-Specific Requirements

### idea
- Required: title (can be in filename or frontmatter)
- Location: sandbox preferred

### outline
- Required: title, description or outline structure
- Location: sandbox

### draft
- Required: title, description, content (>500 words)
- Location: sandbox

### review
- Required: title, description, content (>800 words), tags
- Location: sandbox

### seo
- Required: title, description, tags (3+), category, canonical URL
- Location: sandbox

### scheduled
- Required: All seo requirements + pubDate (future), heroImage
- Location: sandbox

### published
- Required: All scheduled requirements + pubDate (past/today)
- Location: blog

## Error Handling

- If state file is corrupted, rebuild from post frontmatter
- If frontmatter is missing state, use registry as source of truth
- If both are missing, infer from location and content completeness
- Log all state transitions for audit trail

## Output Format

When reporting state:
```
Post: {title}
Slug: {slug}
Current State: {state}
Location: {location}
Last Updated: {timestamp}
Next Actions:
  - {action 1}
  - {action 2}

Timeline:
  {state} | {timestamp}
  {state} | {timestamp}
  ...
```
