---
pattern: Director-Skill
category: Batch Operations
difficulty: beginner
tags: [director, skill, batch, pattern-expansion, parallelism]
version: 1.0
---

# Pattern: Director Skill

## Intent

Enable batch operations through lightweight pattern expansion that returns entity lists for parallel Manager invocation by Core Claude Agent.

## Problem

Users need to operate on multiple entities using patterns:
- Wildcards: `*`, `dataset/*`, `domain/subdomain/*`
- Comma-separated: `entity1,entity2,entity3`
- Combinations: `domain/a,domain/b,other/*`

Requirements:
- Fast pattern expansion (< 1 second)
- Parallel execution (5x speedup vs. sequential)
- No orchestration overhead
- Minimal context usage for pattern expansion itself

## Solution

**Create Director as a SKILL** that only expands patterns and returns entity lists. Core Claude Agent handles parallel Manager invocations.

```
Location: .claude/skills/{project}-director/

Responsibility: Parse pattern → Expand wildcards → Return list

Does NOT: Orchestrate, invoke Managers, aggregate results
```

## Structure

```markdown
---
skill: {project}-director
purpose: Expand batch patterns for parallel Manager invocation
layer: Pattern Expander
---

# {Project} Director

## Purpose
Lightweight pattern expansion. Returns entity list for Core Agent
to invoke Manager agents in parallel.

## Operations

### expand-pattern

**Invocation:**
```json
{
  "operation": "expand-pattern",
  "pattern": "dataset/*"
}
```

**Implementation:**
```bash
scripts/expand-pattern.sh --pattern "$pattern"
```

**Output:**
```json
{
  "entities": ["dataset/users", "dataset/orders", "dataset/products"],
  "count": 3,
  "parallelism_recommendation": 3
}
```

## Critical Constraints
- Does NOT invoke Manager agents
- Does NOT orchestrate workflows
- Does NOT aggregate results
- Pure pattern expansion only

## Usage by Core Agent
1. Director skill expands pattern
2. Director returns entity list
3. Core Agent invokes Manager for each (parallel, max 5)
4. Core Agent aggregates results
```

## Applicability

Use this pattern when:
- ✅ Batch operations needed (operate on multiple entities)
- ✅ Patterns like `*`, `domain/*`, `a,b,c` used by users
- ✅ Parallel execution desired (5x faster)
- ✅ 31% of operations are batch (this is SECONDARY pattern)

Don't use when:
- ❌ Only single-entity operations (no Director needed)
- ❌ Need orchestration logic (use Manager Agent)
- ❌ Need to aggregate results (Core Agent does this)

## Consequences

**Benefits:**
- ✅ Lightweight (pure pattern expansion, minimal context)
- ✅ Fast (< 1 second for pattern expansion)
- ✅ Enables parallelism (Core Agent invokes 5 concurrent Managers)
- ✅ Simple to test (deterministic script)
- ✅ 5x faster batch operations vs. sequential

**Trade-offs:**
- ⚠️ Batch operations have higher total context load (2 + N Manager loads)
- ⚠️ Justified by 5x speedup and infrequent use (31% of operations)

**Anti-Patterns to Avoid:**
- ❌ Director as Agent (over-engineered, prevents parallelism)
- ❌ Director doing orchestration (wrong layer)
- ❌ Director invoking Managers (Core Agent's job)
- ❌ Director aggregating results (Core Agent's job)

## Implementation

### 1. Create Director Skill

```bash
mkdir -p .claude/skills/{project}-director/scripts
touch .claude/skills/{project}-director/SKILL.md
```

### 2. Define expand-pattern Operation

```markdown
### expand-pattern

Parse batch pattern and expand to entity list.

**Input:**
- pattern: Pattern string (*, dataset/*, a,b,c)
- base_path: Base directory for entity lookup (optional)

**Output:**
- entities: Array of entity IDs
- count: Number of entities
- parallelism_recommendation: Max concurrent (usually 5)
```

### 3. Create Pattern Expansion Script

**Script:** `scripts/expand-pattern.sh`

```bash
#!/bin/bash
set -euo pipefail

PATTERN=""
BASE_PATH="${BASE_PATH:-.}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --pattern) PATTERN="$2"; shift 2;;
    --base-path) BASE_PATH="$2"; shift 2;;
    *) echo "Unknown: $1"; exit 1;;
  esac
done

# Wildcard pattern
if [[ "$PATTERN" == *"*"* ]]; then
  ENTITIES=$(find "$BASE_PATH" -type f -path "*${PATTERN}*" | sort)

# Comma-separated
elif [[ "$PATTERN" == *","* ]]; then
  IFS=',' read -ra ENTITIES <<< "$PATTERN"

# Single entity
else
  ENTITIES=("$PATTERN")
fi

# Validate entities exist
VALID=()
for entity in "${ENTITIES[@]}"; do
  if [[ -e "$BASE_PATH/$entity" ]]; then
    VALID+=("$entity")
  fi
done

# Output JSON
PARALLEL=$((${#VALID[@]} < 5 ? ${#VALID[@]} : 5))
cat <<EOF
{
  "entities": [$(printf '"%s",' "${VALID[@]}" | sed 's/,$//')]
  "count": ${#VALID[@]},
  "parallelism_recommendation": $PARALLEL
}
EOF
```

### 4. Update Command Routing

**Single Entity (skip Director):**
```markdown
IF pattern is single entity:
  Invoke: {project}-manager agent directly
```

**Batch (use Director):**
```markdown
IF pattern contains "*" or ",":
  1. Invoke Skill: {project}-director
     Input: {pattern: "*"}

  2. Director returns: {entities: [...]}

  3. Core Agent invokes {project}-manager for each (parallel)

  4. Core Agent aggregates results
```

## Examples

### Example 1: Dataset Director

```markdown
---
skill: myproject-dataset-director
purpose: Expand dataset patterns for batch operations
---

## Operations

### expand-pattern

**Examples:**

Input: `dataset/*`
Output: `["dataset/users", "dataset/orders", "dataset/products"]`

Input: `ipeds/hd,ipeds/ic,nces/ccd`
Output: `["ipeds/hd", "ipeds/ic", "nces/ccd"]`

Input: `single-dataset`
Output: `["single-dataset"]`

**Script:** `scripts/expand-pattern.sh`
- Searches: `.myproject/datasets/` directory
- Matches: Wildcard patterns or splits comma-separated
- Validates: Each entity exists
- Returns: JSON with entity list
```

### Example 2: Service Director

```markdown
---
skill: myproject-service-director
purpose: Expand service patterns for batch deployments
---

## Operations

### expand-pattern

**Examples:**

Input: `production/*`
Output: All services in production environment

Input: `api-*`
Output: All API services

Input: `frontend,backend,database`
Output: Specific 3 services

**Script:** Queries service registry, expands patterns
```

## Command Integration

**Example command using Director:**

```markdown
# Command: /myproject-process

## Arguments
- entity_pattern: Entity or pattern (single, *, domain/*, a,b,c)

## Routing

```python
IF "*" in entity_pattern OR "," in entity_pattern:
    # Batch operation via Director
    result = Skill("myproject-director", {
        "operation": "expand-pattern",
        "pattern": entity_pattern
    })

    entities = result["entities"]

    # Core Agent invokes Managers in parallel
    for entity in entities (parallel, max 5):
        Task("myproject-manager", {"entity": entity})

ELSE:
    # Single entity - skip Director
    Task("myproject-manager", {"entity": entity_pattern})
```
```

## Performance Metrics

**Pattern Expansion:**
- Time: < 1 second (deterministic script)
- Context: Minimal (skill invocation only)

**Batch Execution (10 entities):**
- Old (sequential): 10 × 45s = 450s (7.5 min)
- New (parallel 5): ⌈10/5⌉ × 45s = 90s (1.5 min)
- **Speedup: 5x faster**

**Context Trade-off (10 entities):**
- Old (sequential): 2 loads total
- New (parallel): 2 + 10 = 12 loads
- **Acceptable:** 5x speedup justifies higher context

## Testing

**Unit Tests:**
```bash
# Test wildcard
Input: {pattern: "dataset/*"}
Expected: All entities matching dataset/*

# Test comma-separated
Input: {pattern: "a,b,c"}
Expected: ["a", "b", "c"]

# Test single
Input: {pattern: "single"}
Expected: ["single"]

# Test invalid
Input: {pattern: "nonexistent/*"}
Expected: {entities: [], count: 0}
```

**Integration Tests:**
```bash
# Verify Core Agent parallelism
1. Invoke Director with pattern (10 entities)
2. Observe Core Agent launches 5 concurrent Managers
3. Verify wall-clock time ~ N/5
4. Verify all results aggregated correctly
```

## Related Patterns

- **Manager-as-Agent**: Primary pattern for single-entity operations
- **Specialist Skills**: Execution units invoked by Manager

## Known Uses

- **Lake.Corthonomy.AI**: Dataset batch operations
  - Pattern: `ipeds/*` → 14 datasets
  - Pattern: `*` → 76 datasets
  - Results: 5x faster batch operations

## Tags

`#director` `#skill` `#batch` `#pattern-expansion` `#parallelism` `#wildcard`
