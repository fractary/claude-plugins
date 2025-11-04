---
name: fractary-faber-article:image-generator
description: |
  Generate hero images via DALL-E 3 API - call OpenAI API with prompt, download image, convert to
  WebP format (quality: 85), save to /public/images/hero/{slug}.webp, update post frontmatter with
  heroImage path, handle errors with retries. Cost: $0.08 per 1792x1024 HD image.
tools: Bash, Edit
---

# Image Generator Skill

## Purpose
Generate hero images for blog posts using DALL-E 3 API, convert to WebP format, save to appropriate location, and update post frontmatter automatically.

## Overview

This skill wraps the existing `scripts/generate-hero-images.ts` script functionality, allowing automated hero image generation as part of the content workflow.

**Cost:** $0.08 per image (DALL-E 3 HD, 1792x1024)

---

## How It Works

### Image Generation Flow

```
1. Receive prompt from image-prompt-generator skill
2. Call OpenAI DALL-E 3 API with prompt
3. Download generated image (PNG format)
4. Convert to WebP (quality: 85)
5. Save to /public/images/hero/{slug}.webp
6. Update post frontmatter with heroImage path
7. Report success and cost
```

### Technical Details

**DALL-E 3 Settings:**
- Model: `dall-e-3`
- Size: `1792x1024` (widescreen hero format)
- Quality: `hd` (high definition)
- Number: 1 image per request
- Cost: $0.08 per HD image

**WebP Conversion:**
- Library: Sharp
- Quality: 85 (balance of file size and visual quality)
- Output format: WebP

**File Locations:**
- Output: `/public/images/hero/{slug}.webp`
- Post: `src/content/sandbox/{slug}.md` or `src/content/blog/{slug}.md`

**Frontmatter Update:**
```yaml
heroImage: "/images/hero/{slug}.webp"
```

---

## Integration with Existing Script

This skill leverages `scripts/generate-hero-images.ts` which handles:
- OpenAI API calls
- Image downloading
- WebP conversion
- Frontmatter updates

**Key Functions from Script:**
- `generateHeroImage()`: Main generation function
- `downloadImage()`: Fetches image from DALL-E URL
- `convertToWebP()`: Converts PNG to WebP with Sharp
- `updateBlogPostFrontmatter()`: Updates frontmatter using gray-matter

---

## Usage Instructions

### Input Parameters Expected
```yaml
slug: "post-slug"
prompt: "DALL-E 3 prompt from image-prompt-generator"
postPath: "src/content/sandbox/post-slug.md"  # Optional, inferred from slug
customFilename: "custom-name.webp"  # Optional, default: {slug}.webp
```

### Execution Steps

1. **Validate Prerequisites**
   - Check `OPENAI_API_KEY` exists in environment
   - Verify post file exists at postPath
   - Ensure `/public/images/hero/` directory exists
   - Confirm prompt is valid and not empty

2. **Prepare Generation Parameters**
   - Extract/generate filename (default: `{slug}.webp`)
   - Determine post path if not provided
   - Validate prompt against DALL-E requirements

3. **Call DALL-E 3 API**
   ```typescript
   const response = await openai.images.generate({
     model: "dall-e-3",
     prompt: prompt,
     n: 1,
     size: "1792x1024",
     quality: "hd",
   });
   ```

4. **Handle API Response**
   - Extract image URL from response
   - Handle errors (rate limits, API failures, invalid prompts)
   - Retry up to 3 times on transient failures

5. **Download Image**
   - Fetch image from DALL-E URL
   - Convert response to Buffer
   - Handle download failures

6. **Convert to WebP**
   ```typescript
   await sharp(imageBuffer)
     .webp({ quality: 85 })
     .toFile(outputPath);
   ```

7. **Update Post Frontmatter**
   - Read post file
   - Parse frontmatter with gray-matter
   - Add/update `heroImage` field
   - Write back to file

8. **Report Results**
   - Log success message
   - Report file location
   - Note cost ($0.08)
   - Return image path for workflow continuation

9. **Error Handling**
   - Log detailed error information
   - Distinguish error types (API, network, file system)
   - Provide actionable recovery steps
   - Fail gracefully without breaking workflow

---

## Implementation Approach

Since this is a skill file (not executable code), it provides **instructions** for Claude to execute when invoked:

### When Invoked, Claude Should:

1. **Receive prompt from image-prompt-generator skill** (or custom prompt)

2. **Use Bash tool to execute the generation script** with appropriate parameters:
   ```bash
   # For automatic mode using existing script pattern:
   # First, add prompt to prompts.ts
   # Then run generation script

   # OR invoke Node.js directly with custom implementation:
   node -e "
   const OpenAI = require('openai');
   const fs = require('fs');
   const path = require('path');
   const sharp = require('sharp');
   const matter = require('gray-matter');

   async function generate() {
     // [Implementation using script functions]
   }

   generate().catch(console.error);
   "
   ```

3. **Monitor output** for success/failure

4. **Update content state** if successful

5. **Report results** to user or content-manager agent

---

## Alternative: Direct Node.js Execution

For more control, Claude can execute Node.js directly using the Bash tool:

```javascript
// Create temporary script
const script = `
import OpenAI from 'openai';
import sharp from 'sharp';
import matter from 'gray-matter';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config();

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

async function downloadImage(url) {
  const response = await fetch(url);
  const arrayBuffer = await response.arrayBuffer();
  return Buffer.from(arrayBuffer);
}

async function generate() {
  const prompt = \`${prompt}\`;
  const slug = '${slug}';
  const postPath = '${postPath}';

  console.log('🎨 Generating image with DALL-E 3...');

  const response = await openai.images.generate({
    model: "dall-e-3",
    prompt: prompt,
    n: 1,
    size: "1792x1024",
    quality: "hd",
  });

  const imageUrl = response.data[0]?.url;
  if (!imageUrl) throw new Error('No image URL returned');

  console.log('⬇️  Downloading image...');
  const imageBuffer = await downloadImage(imageUrl);

  const outputPath = path.join(process.cwd(), 'public', 'images', 'hero', \`\${slug}.webp\`);

  console.log('🔄 Converting to WebP...');
  await sharp(imageBuffer)
    .webp({ quality: 85 })
    .toFile(outputPath);

  console.log('📝 Updating frontmatter...');
  const fileContent = fs.readFileSync(postPath, 'utf-8');
  const { data, content } = matter(fileContent);
  data.heroImage = \`/images/hero/\${slug}.webp\`;
  fs.writeFileSync(postPath, matter.stringify(content, data), 'utf-8');

  console.log(\`✅ Success! Image saved to \${outputPath}\`);
  console.log('💰 Cost: $0.08');
}

generate().catch(console.error);
`;

// Save and execute
fs.writeFileSync('/tmp/generate-image.mjs', script);
await exec('node /tmp/generate-image.mjs');
```

---

## Integration Points

### Before
- Receives prompt from image-prompt-generator skill
- May receive parameters from:
  - `/content:image` command
  - `/content:new` command (via content-manager)
  - `/content:publish` command (if image missing)
  - content-manager agent

### After
- Updates post frontmatter with heroImage path
- Reports success/failure with details
- Passes control to next workflow step
- May trigger content-state-manager if state change needed

### Used By
- `/content:image` - Direct image generation command
- `/content:new` - Step 5 in full creation workflow
- `/content:publish` - Pre-publish image check
- content-manager agent - Part of orchestrated workflows

---

## Error Handling

### OpenAI API Errors

**Rate Limit Exceeded:**
```
Error: Rate limit reached for requests
Action: Wait 60 seconds and retry
Max retries: 3
Fallback: Report to user, suggest manual generation later
```

**Invalid Prompt:**
```
Error: Prompt violates content policy
Action: Regenerate prompt with image-prompt-generator
Max retries: 2
Fallback: Suggest manual prompt adjustment
```

**API Key Missing:**
```
Error: OPENAI_API_KEY not found
Action: Check .env file exists and contains key
Fallback: Cannot proceed, report clear instructions to user
```

---

### File System Errors

**Directory Missing:**
```
Error: /public/images/hero/ does not exist
Action: Create directory automatically
Command: mkdir -p public/images/hero
```

**Post File Not Found:**
```
Error: Post file doesn't exist at path
Action: Verify slug, check sandbox vs blog location
Fallback: Report error with suggestions
```

**Permission Denied:**
```
Error: Cannot write to file
Action: Check file permissions
Fallback: Report with manual resolution steps
```

---

### Network/Download Errors

**Image Download Failed:**
```
Error: Failed to download from DALL-E URL
Action: Retry download up to 3 times
Fallback: Report URL for manual download
```

**Conversion Failed:**
```
Error: Sharp conversion error
Action: Check image buffer integrity
Fallback: Save as PNG instead of WebP, note in report
```

---

## Quality Assurance

### Pre-Generation Checks
- [ ] `OPENAI_API_KEY` environment variable set
- [ ] Post file exists and is readable
- [ ] `/public/images/hero/` directory exists
- [ ] Prompt is valid (not empty, under character limit)
- [ ] No existing image with same filename (or confirm overwrite)

### Post-Generation Validation
- [ ] Image file created successfully
- [ ] File size reasonable (typically 100-500 KB for WebP)
- [ ] Frontmatter updated correctly
- [ ] `heroImage` path is correct format
- [ ] Image accessible at public path

### Cost Tracking
- Log each generation with cost
- Track total spend per session
- Warn if multiple failed attempts (wasted cost)
- Report cumulative cost for batch operations

---

## Output Format

When reporting results to user or agent:

```markdown
## Image Generation Result

**Post:** {title}
**Slug:** {slug}
**Status:** ✅ Success / ❌ Failed

### Details
- **Prompt Used:** {first 100 chars of prompt}...
- **Image Location:** `/public/images/hero/{slug}.webp`
- **Public Path:** `/images/hero/{slug}.webp`
- **File Size:** {size} KB
- **Cost:** $0.08

### Frontmatter Updated
```yaml
heroImage: "/images/hero/{slug}.webp"
```

### Preview
🖼️  Image saved successfully. View at: `/images/hero/{slug}.webp`

---

**Time:** {duration}s
**Next Step:** Ready for publishing or further optimization
```

---

## Best Practices

### Do
✅ Validate prompt before API call (save cost on obvious failures)
✅ Check for existing images (avoid unnecessary regeneration)
✅ Use slug-based filenames for consistency
✅ Report cost transparently
✅ Handle errors gracefully with retries
✅ Update frontmatter atomically (read, modify, write)
✅ Log generation details for debugging

### Don't
❌ Retry indefinitely (cap at 3 attempts)
❌ Proceed without API key
❌ Overwrite images without confirmation
❌ Ignore file system errors
❌ Skip frontmatter updates
❌ Generate before prompt validation
❌ Fail silently

---

## Workflow Integration Examples

### Example 1: Part of Full Creation Workflow

```
content-manager orchestrates:
  1. content-researcher → research brief
  2. content-outliner → outline
  3. content-writer → draft
  4. [CHECKPOINT] User reviews draft
  5. content-seo-optimizer → SEO metadata
  6. image-prompt-generator → prompt
  7. image-generator → hero image  ← THIS SKILL
  8. content-state-manager → set to 'scheduled'
  9. [CHECKPOINT] Final approval
```

---

### Example 2: Standalone Image Generation

```
User: /content:image my-blog-post

Flow:
  1. /content:image command invoked
  2. Reads post: src/content/sandbox/my-blog-post.md
  3. Invokes image-prompt-generator
     → Generates DALL-E prompt from post content
  4. Invokes image-generator  ← THIS SKILL
     → Calls DALL-E 3 API
     → Downloads and converts image
     → Updates frontmatter
  5. Reports success
```

---

### Example 3: Publishing with Missing Image

```
User: /content:publish my-blog-post

Flow:
  1. /content:publish command checks requirements
  2. Detects heroImage is missing from frontmatter
  3. Automatically invokes:
     - image-prompt-generator
     - image-generator  ← THIS SKILL
  4. Continues with publish after image ready
```

---

## Configuration

### Environment Variables Required

```bash
# .env file
OPENAI_API_KEY=sk-...your-key-here
```

### File Paths

```
Project Root/
├── .env                                    # API key
├── public/
│   └── images/
│       └── hero/                           # Generated images output
│           └── {slug}.webp
├── src/
│   └── content/
│       ├── sandbox/{slug}.md               # Draft posts
│       └── blog/{slug}.md                  # Published posts
└── scripts/
    ├── generate-hero-images.ts             # Existing script
    └── prompts.ts                          # Prompt library
```

---

## Future Enhancements

Ideas for plugin version:
- Batch image generation for multiple posts
- Image style variations (not just split composition)
- Automatic retry with prompt refinement on failures
- Image optimization (additional compression)
- CDN upload integration
- Alt text generation for accessibility
- Multiple size variants for responsive images
- Cost budgeting and limits
- Image quality validation
- A/B testing with multiple prompt variations
- Fallback to other image generation APIs
