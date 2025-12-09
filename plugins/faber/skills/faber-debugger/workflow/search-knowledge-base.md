# Search Knowledge Base

This workflow step searches the troubleshooting knowledge base for similar past issues.

## Overview

Before generating a fresh diagnosis, check if similar issues have been resolved before. The knowledge base is a persistent collection of troubleshooting entries stored in source control.

**Knowledge Base Location:** `.fractary/plugins/faber/debugger/knowledge-base/`

## Steps

### 1. Check Knowledge Base Availability

Verify the knowledge base exists and is accessible:

```bash
KB_PATH=".fractary/plugins/faber/debugger/knowledge-base"
INDEX_FILE="$KB_PATH/index.json"

if [ ! -f "$INDEX_FILE" ]; then
  echo "Knowledge base not found, performing fresh analysis"
  # Return empty results but don't fail
  exit 0
fi
```

**If Not Available:**
- Log info: "Knowledge base not found, performing fresh analysis"
- Return empty matches
- Do NOT fail - knowledge base is an enhancement, not requirement

---

### 2. Extract Search Terms

Generate search terms from debug context:

**From Errors:**
```bash
# Extract unique error patterns
errors=$(jq -r '.errors[].message' /tmp/faber-debugger-context.json)

# Remove file paths, line numbers, variable values
# Keep error types and key phrases
patterns=$(echo "$errors" | sed 's/:[0-9]*//g' | sed 's/"[^"]*"/"..."/g')
```

**From Explicit Problem:**
```bash
problem=$(jq -r '.explicit_problem.description // empty' /tmp/faber-debugger-context.json)
```

**Generate Keywords:**
```json
{
  "error_patterns": [
    "Type error: Expected * got *",
    "Import error: Module * not found",
    "Timeout"
  ],
  "keywords": [
    "type error",
    "import error",
    "module not found",
    "authentication",
    "timeout"
  ],
  "phase": "build",
  "step": "implement",
  "category_hint": "build"
}
```

---

### 3. Search Knowledge Base Index

Use the search script to find matching entries:

```bash
scripts/search-kb.sh \
  --keywords "type error,import,module not found" \
  --patterns "Type error: Expected*" \
  --category "build" \
  --limit 5 \
  --threshold 0.5
```

**Search Algorithm:**

1. **Keyword Matching (40% weight):**
   - Match keywords against entry keywords
   - Score = matched_keywords / total_search_keywords

2. **Pattern Matching (40% weight):**
   - Compare error patterns using fuzzy matching
   - Levenshtein distance normalized to [0,1]
   - Score = 1 - (distance / max_length)

3. **Category Match (10% weight):**
   - Exact match: 1.0
   - Related category: 0.5
   - No match: 0.0

4. **Recency Boost (10% weight):**
   - Entries used in last 30 days: 1.0
   - 30-90 days: 0.7
   - 90-180 days: 0.5
   - Older: 0.3

**Combined Score:**
```
final_score = (keyword_score * 0.4) +
              (pattern_score * 0.4) +
              (category_score * 0.1) +
              (recency_score * 0.1)
```

---

### 4. Load Matching Entries

For entries above the threshold, load full content:

```bash
for entry_id in $MATCHING_IDS; do
  entry_path=$(jq -r ".entries[\"$entry_id\"].path" "$INDEX_FILE")
  cat "$KB_PATH/$entry_path"
done
```

**Entry Structure:**
```yaml
---
kb_id: faber-debug-042
category: build
issue_pattern: "Type mismatch in implementation"
symptoms:
  - "Type error: Expected string got int"
  - "Type error: Cannot assign"
keywords:
  - type error
  - type mismatch
  - typescript
root_causes:
  - "Incorrect type annotation"
  - "API response type changed"
solutions:
  - title: "Fix type annotation"
    steps:
      - "Check the expected type from spec/API"
      - "Update type annotation to match"
      - "Run type check: npm run typecheck"
    faber_command: "/fractary-faber:run --work-id {id} --step builder --prompt 'Fix type errors identified by debugger'"
status: verified
created: 2025-11-15
last_used: 2025-12-01
usage_count: 7
references:
  - "#198"
  - "#205"
  - "#212"
---

## Detailed Analysis

This error typically occurs when...

## Solution Walkthrough

1. First, identify the location...
2. Then, check the expected type...
```

---

### 5. Rank and Filter Results

Process matching entries:

```json
{
  "kb_search_results": {
    "query": {
      "keywords": ["type error", "import", "module not found"],
      "patterns": ["Type error: Expected*"],
      "category": "build"
    },
    "matches": [
      {
        "kb_id": "faber-debug-042",
        "score": 0.85,
        "category": "build",
        "issue_pattern": "Type mismatch in implementation",
        "relevance": "high",
        "solutions_count": 2,
        "usage_count": 7,
        "last_used": "2025-12-01",
        "status": "verified"
      },
      {
        "kb_id": "faber-debug-031",
        "score": 0.72,
        "category": "build",
        "issue_pattern": "Missing module dependency",
        "relevance": "medium",
        "solutions_count": 1,
        "usage_count": 3,
        "last_used": "2025-11-20",
        "status": "verified"
      }
    ],
    "total_searched": 47,
    "matches_found": 2,
    "threshold_used": 0.5
  }
}
```

**Relevance Classification:**
- Score >= 0.8: "high" - Strong match, use solution directly
- Score >= 0.6: "medium" - Likely related, adapt solution
- Score >= 0.5: "low" - Possibly related, reference only

---

### 6. Prepare Solutions from Matches

Extract and prepare solutions for high-relevance matches:

```json
{
  "kb_solutions": [
    {
      "from_entry": "faber-debug-042",
      "relevance": "high",
      "score": 0.85,
      "title": "Fix type annotation",
      "original_problem": "Type mismatch in implementation",
      "steps": [
        "Check the expected type from spec/API",
        "Update type annotation to match",
        "Run type check: npm run typecheck"
      ],
      "faber_command": "/fractary-faber:run --work-id {id} --step builder --prompt 'Fix type errors identified by debugger'",
      "past_references": ["#198", "#205", "#212"],
      "confidence": "high",
      "reason": "Exact match to verified solution used 7 times"
    }
  ]
}
```

## Error Handling

**Index Corrupted:**
```
IF index.json parse fails:
  Log warning: "Knowledge base index corrupted, performing fresh analysis"
  Attempt to rebuild index from entries
  IF rebuild fails: Continue without KB
```

**Entry File Missing:**
```
IF entry file not found at path:
  Log warning: "Entry {kb_id} not found, removing from results"
  Remove from matches
  Continue with remaining matches
```

**No Matches Found:**
```
IF matches.length == 0:
  Return empty results (success, not failure)
  Note: "No similar issues found in knowledge base"
  Proceed to fresh diagnosis
```

## Output

Return knowledge base search results:

```json
{
  "kb_available": true,
  "search_performed": true,
  "matches_found": 2,
  "high_relevance_matches": 1,
  "top_match": {
    "kb_id": "faber-debug-042",
    "score": 0.85,
    "issue_pattern": "Type mismatch in implementation"
  },
  "kb_solutions": [...],
  "recommendation": "Use verified solution from faber-debug-042"
}
```

Save for subsequent steps:

```bash
echo "$KB_SEARCH_RESULTS" >> /tmp/faber-debugger-context.json
```
