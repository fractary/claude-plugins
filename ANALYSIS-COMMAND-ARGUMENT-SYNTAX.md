# Command Argument Parsing Analysis

## Executive Summary

There are **two competing argument syntax patterns** across the plugin ecosystem:

1. **Space-separated syntax**: `--flag value` (used by work, repo, codex, faber, faber-article)
2. **Equals syntax**: `--flag=value` (used by faber-cloud, helm, helm-cloud)

This inconsistency creates:
- **User confusion** - Users must remember different syntax for different plugins
- **Documentation inconsistency** - Different patterns documented across plugins
- **Parsing complexity** - Different parsing logic in different places
- **Edge case ambiguity** - Unclear handling of spaces in values

## Current State

### Plugins Using Space-Separated Syntax (`--flag value`)

**Plugins:**
- `faber` - Core FABER workflow orchestration
- `work` - Work tracking primitive
- `repo` - Source control primitive
- `codex` - Memory management
- `faber-article` - Article generation workflow

**Examples:**
```bash
/faber:run 123 --domain design --autonomy guarded
/repo:commit "Add feature" --type feat --work-id 123
/work:issue-create "Bug fix" --type bug --body "Description here"
/codex:sync-project my-project --to-codex --dry-run
```

**Parsing Pattern:**
```bash
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --autonomy)
            AUTONOMY="$2"
            shift 2
            ;;
        --auto-merge)
            AUTO_MERGE="true"
            shift
            ;;
    esac
done
```

**Documentation for Multi-Word Values:**
- Both `repo/commands/commit.md` and `work/commands/issue-create.md` have explicit `<ARGUMENT_SYNTAX>` sections
- Clearly state: "Multi-word values: MUST be enclosed in quotes"
- Examples: `--body "This is a description"` ✅
- Wrong: `--body This is a description` ❌

### Plugins Using Equals Syntax (`--flag=value`)

**Plugins:**
- `faber-cloud` - Cloud infrastructure workflow
- `helm` - Operations monitoring
- `helm-cloud` - Cloud operations monitoring

**Examples:**
```bash
/fractary-faber-cloud:deploy-apply --env=test --auto-approve
/fractary-faber-cloud:deploy-plan --env=prod
/fractary-helm:status --domain=infrastructure --env=prod
```

**Parsing Pattern:**
```bash
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment=*)
            ENVIRONMENT="${1#*=}"
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE="true"
            shift
            ;;
    esac
done
```

**Documentation for Multi-Word Values:**
- NO explicit guidance found in faber-cloud or helm commands
- No `<ARGUMENT_SYNTAX>` section
- Unclear how to handle: `--description="Multi word description"`

## Key Differences

| Aspect | Space-Separated | Equals Syntax |
|--------|----------------|---------------|
| **Syntax** | `--flag value` | `--flag=value` |
| **Parsing** | `shift 2` for flags with values | `${1#*=}` and `shift` |
| **Multi-word values** | Requires quotes: `"value with spaces"` | Requires quotes: `"value with spaces"` |
| **Boolean flags** | `--flag` (no value) | `--flag` (no value) |
| **Documentation** | ✅ Explicit in work/repo | ❌ Not documented |
| **Quote handling** | Well documented | Not documented |
| **Plugins using** | 5 plugins (primitives + faber) | 3 plugins (cloud/helm workflows) |

## Issues Identified

### 1. User Experience Confusion
Users must remember:
- `/repo:commit "msg" --type feat` (space)
- `/fractary-faber-cloud:deploy-apply --env=test` (equals)

### 2. Documentation Gaps
- faber-cloud commands lack `<ARGUMENT_SYNTAX>` sections
- No guidance on multi-word values with equals syntax
- Inconsistent examples across plugins

### 3. Parsing Complexity
- Two different parsing patterns maintained
- Different error handling approaches
- No shared parsing library/function

### 4. Edge Cases
- How to handle: `--env="test env"` (space in value with equals syntax)?
- How to handle: `--description "Has = sign"` (equals in value with space syntax)?
- Not documented anywhere

## Recommendation

### Proposed Standard: **Space-Separated Syntax with Quotes**

**Rationale:**

1. **More intuitive** - Matches common CLI tool patterns (git, npm, docker)
2. **Clearer separation** - Visual distinction between flag and value
3. **Already documented** - work/repo plugins have comprehensive docs
4. **More prevalent** - 5 plugins vs 3 plugins
5. **Quote handling is explicit** - Users know when quotes are needed
6. **Positional-friendly** - Better for optional flags mixed with positional args

### Recommended Syntax

**Flags with values:**
```bash
--flag value          # Single word value
--flag "value"        # Multi-word value (REQUIRED for spaces)
```

**Boolean flags:**
```bash
--flag                # No value, presence = true
```

**Complete examples:**
```bash
# Good ✅
/repo:commit "Add CSV export" --type feat --work-id 123
/work:issue-create "Bug title" --body "Multi word description" --type bug
/faber-cloud:deploy-apply --env test --auto-approve

# Bad ❌
/repo:commit "Add CSV export" --type=feat
/work:issue-create Bug title --body Multi word description
/faber-cloud:deploy-apply --env="test env"
```

### Quote Rules

1. **Multi-word values MUST use double quotes:**
   - ✅ `--body "This is a description"`
   - ❌ `--body This is a description`

2. **Single-word values MAY omit quotes:**
   - ✅ `--type feat`
   - ✅ `--type "feat"`
   - Both acceptable

3. **Boolean flags NEVER have values:**
   - ✅ `--auto-merge`
   - ❌ `--auto-merge true`
   - ❌ `--auto-merge=true`

4. **Special characters require quotes:**
   - ✅ `--description "Value with = or : or other chars"`
   - ✅ `--url "https://example.com/path?param=value"`

### Standard Parsing Function

Create a shared parsing function in `docs/standards/argument-parsing.sh`:

```bash
#!/bin/bash

# Parse command arguments with standard syntax
# Usage: parse_arguments "$@"
#
# Arguments should be:
#   --flag value          # Flag with value
#   --boolean-flag        # Boolean flag
#   "positional arg"      # Positional arguments
#
# Multi-word values MUST be quoted:
#   --description "Multi word value"

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --*=*)
                # Error: equals syntax not supported
                local flag="${1%%=*}"
                echo "Error: Use space-separated syntax: $flag <value>" >&2
                echo "Not: $1" >&2
                exit 2
                ;;
            --*)
                # Flag detected
                local flag="$1"
                shift

                # Check if next arg is a value (not a flag, not empty)
                if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
                    # Flag with value
                    local value="$1"
                    shift
                    # Store in associative array or handle as needed
                else
                    # Boolean flag
                    # Store true or handle as needed
                fi
                ;;
            *)
                # Positional argument
                local positional="$1"
                shift
                # Handle positional
                ;;
        esac
    done
}
```

## Migration Plan

### Phase 1: Documentation (1-2 days)

1. **Create standard document**
   - Location: `docs/standards/COMMAND-ARGUMENT-SYNTAX.md`
   - Content: Syntax rules, quote handling, examples
   - Add to `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`

2. **Update all commands**
   - Add `<ARGUMENT_SYNTAX>` section to all command files
   - Update `argument-hint` in frontmatter
   - Add explicit quote usage examples

### Phase 2: Update faber-cloud & helm Plugins (2-3 days)

1. **Update command documentation**
   - Change argument-hint from `--env=<value>` to `--env <value>`
   - Add `<ARGUMENT_SYNTAX>` sections
   - Update examples throughout

2. **Update parsing logic**
   - Change from `--flag=*` pattern to `--flag` pattern
   - Update case statements
   - Change `${1#*=}` to `$2` with `shift 2`

3. **Test all commands**
   - Verify parsing works correctly
   - Test multi-word values with quotes
   - Test boolean flags

### Phase 3: Create Shared Parsing Library (1 day)

1. **Create standard parser**
   - Location: `docs/standards/scripts/parse-arguments.sh`
   - Reusable function for common patterns
   - Error messages for equals syntax (helpful migration)

2. **Add to plugin template**
   - Include in new plugin scaffolding
   - Reference from command templates

### Phase 4: Testing & Validation (1 day)

1. **Integration tests**
   - Test each command with new syntax
   - Test edge cases (spaces, quotes, special chars)
   - Verify error messages

2. **Documentation review**
   - Ensure all examples use correct syntax
   - Check agent/skill files for command examples
   - Update any README files

## Implementation Details

### Commands to Update (faber-cloud)

All faber-cloud commands need updating:
- `/fractary-faber-cloud:deploy-apply`
- `/fractary-faber-cloud:deploy-plan`
- `/fractary-faber-cloud:init`
- `/fractary-faber-cloud:configure`
- `/fractary-faber-cloud:validate`
- `/fractary-faber-cloud:test`
- `/fractary-faber-cloud:debug`
- `/fractary-faber-cloud:design`
- `/fractary-faber-cloud:status`
- `/fractary-faber-cloud:resources`
- `/fractary-faber-cloud:teardown`
- `/fractary-faber-cloud:manage`
- `/fractary-faber-cloud:director`

### Commands to Update (helm)

All helm commands need updating:
- `/fractary-helm:status`
- `/fractary-helm:issues`
- `/fractary-helm:dashboard`
- `/fractary-helm:escalate`
- `/fractary-helm-cloud:health`
- `/fractary-helm-cloud:investigate`
- `/fractary-helm-cloud:audit`
- `/fractary-helm-cloud:remediate`

### Scripts to Update

Scripts with equals-syntax parsing:
- `plugins/faber-cloud/skills/cloud-common/scripts/generate-deployed-doc.sh`
- `plugins/faber-cloud/skills/cloud-common/scripts/log-resolution.sh`
- `plugins/faber-cloud/skills/cloud-common/scripts/update-registry.sh`
- Any other scripts that parse `--flag=value` syntax

## Benefits of Standardization

1. **User Experience**
   - Single syntax to learn
   - Consistent across all plugins
   - Clear documentation

2. **Developer Experience**
   - Reusable parsing logic
   - Consistent error handling
   - Easier to maintain

3. **Documentation**
   - One standard to document
   - Examples work everywhere
   - Less confusion in guides

4. **Reliability**
   - Well-tested pattern
   - Clear edge case handling
   - Explicit quote requirements

## Alternative Considered: Equals Syntax

**Why NOT chosen:**

1. **Less common** - Only 3 plugins use it currently
2. **Less intuitive** - Doesn't match common CLI patterns
3. **Quote handling unclear** - How to handle `--env="test env"`?
4. **Positional mixing** - Harder to mix with positional args
5. **More complex parsing** - Requires `${1#*=}` pattern matching
6. **No better benefits** - Doesn't solve multi-word values issue

**The equals syntax doesn't provide advantages over space-separated**, and has more downsides.

## Examples of Updated Documentation

### Before (faber-cloud):
```markdown
argument-hint: "--env=<environment> [--auto-approve]"

# Examples
/fractary-faber-cloud:deploy-apply --env=test
/fractary-faber-cloud:deploy-apply --env=prod --auto-approve
```

### After (faber-cloud):
```markdown
argument-hint: "--env <environment> [--auto-approve]"

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Example**: `--description "Multi word value"` ✅
- **Wrong**: `--description Multi word value` ❌

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /fractary-faber-cloud:deploy-apply --env test --description "Deploy to test"
❌ /fractary-faber-cloud:deploy-apply --env=test --description=Deploy to test
```

**Single-word values don't require quotes:**
```bash
✅ /fractary-faber-cloud:deploy-apply --env test
✅ /fractary-faber-cloud:deploy-apply --env prod
```

**Boolean flags have no value:**
```bash
✅ /fractary-faber-cloud:deploy-apply --env test --auto-approve
❌ /fractary-faber-cloud:deploy-apply --env test --auto-approve=true
```
</ARGUMENT_SYNTAX>

# Examples
/fractary-faber-cloud:deploy-apply --env test
/fractary-faber-cloud:deploy-apply --env prod --auto-approve
```

## Questions to Consider

1. **Backward compatibility**: Should we support both syntaxes temporarily?
   - Recommendation: **No** - Clean break is clearer, fewer plugins to migrate

2. **Error messages**: Should we detect and suggest correct syntax?
   - Recommendation: **Yes** - Parser should detect `--flag=value` and suggest `--flag value`

3. **Migration timeline**: How quickly to implement?
   - Recommendation: **1 week** - It's straightforward, better to do it quickly

## Conclusion

**Adopt space-separated syntax (`--flag value`) as the standard** across all plugins.

This provides:
- ✅ Consistency across the ecosystem
- ✅ Clear, well-documented behavior
- ✅ Better user experience
- ✅ Easier maintenance
- ✅ Explicit quote handling

The migration affects only 3 plugins (faber-cloud, helm, helm-cloud) and can be completed in approximately 1 week.
