# Solution: Shared Parsing Logic Distribution

## Problem

The proposed shared script `docs/standards/scripts/parse-arguments.sh` has a distribution problem:

1. **Docs aren't distributed** - When plugins are installed from marketplace, docs/ folder isn't included
2. **Cross-plugin references unclear** - Can one plugin reference scripts from another plugin?
3. **Dependency management** - Would require all plugins to depend on fractary-util/fractary-core
4. **Installation complexity** - Users would need to enable multiple plugins

## Potential Solutions Evaluated

### Option 1: fractary-core Plugin (Future Solution)

**Approach:**
- Create `fractary-core` plugin with shared utilities
- All plugins declare dependency on fractary-core
- Core plugin installed automatically with any Fractary plugin

**Structure:**
```
plugins/fractary-core/
  ├── lib/
  │   ├── parse-arguments.sh
  │   ├── error-messages.sh
  │   └── validation.sh
  ├── .claude-plugin/
  │   └── plugin.json
  └── README.md
```

**Pros:**
- ✅ Single source of truth
- ✅ Shared code maintenance
- ✅ Consistent behavior

**Cons:**
- ❌ Requires plugin dependency system
- ❌ Adds installation complexity
- ❌ Not available for immediate use
- ❌ Unclear if Claude Code plugins support cross-plugin script references

**Verdict:** Good future solution, but not available now

### Option 2: Inline Parsing with Standard Pattern (RECOMMENDED)

**Approach:**
- Each plugin contains its own parsing logic
- Use consistent pattern across all plugins
- Maintain through templates and code generation

**Structure:**
```
plugins/my-plugin/
  ├── commands/
  │   └── my-command.md (contains inline parsing example)
  ├── skills/
  │   └── my-skill/
  │       └── scripts/
  │           └── parse-args.sh (local copy of pattern)
```

**Pros:**
- ✅ Each plugin is self-contained
- ✅ No cross-plugin dependencies
- ✅ Works with current architecture
- ✅ Simple installation
- ✅ Available immediately

**Cons:**
- ⚠️ Code duplication across plugins
- ⚠️ Must update multiple files for changes

**Mitigation:**
- Use templates during development
- Maintain standard pattern in docs
- Code generation tools (future)

**Verdict:** Best solution for immediate implementation

### Option 3: Fractary CLI/SDK (Long-term Vision)

**Approach:**
- Create `fractary-cli` npm package or similar
- Provides common utilities as library
- Plugins use via `#!/usr/bin/env fractary-cli`

**Structure:**
```
npm install -g @fractary/cli

# In plugin scripts
#!/usr/bin/env fractary-cli
source fractary-lib parse-arguments
```

**Pros:**
- ✅ Professional SDK approach
- ✅ Version management
- ✅ Rich utility library

**Cons:**
- ❌ Requires significant architecture
- ❌ Long development timeline
- ❌ Installation prerequisites

**Verdict:** Excellent long-term vision, not viable now

## Recommended Solution: Inline Parsing with Standard Pattern

### Implementation Approach

1. **Define Standard Pattern**
   - Document in `docs/standards/COMMAND-ARGUMENT-SYNTAX.md`
   - Provide reference implementation
   - Include common patterns

2. **Template for New Commands**
   - Create command template with parsing code
   - Developers copy template when creating commands
   - Consistent pattern emerges naturally

3. **Reference Implementation**
   - Keep canonical example in standards doc
   - Use as copy-paste source
   - Maintain as single source of truth (for copying)

4. **Code Review Standards**
   - Verify parsing follows standard pattern
   - Check error messages match standard
   - Ensure consistency during PR review

### Standard Parsing Pattern

Create this in `docs/standards/COMMAND-ARGUMENT-SYNTAX.md`:

```bash
#!/bin/bash
# Standard argument parsing pattern for Fractary plugins
# Copy this pattern into your command's workflow section

# Initialize variables for your flags
FLAG_VALUE=""
BOOLEAN_FLAG=""
POSITIONAL_ARG=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --flag)
            # Flag with value
            if [[ $# -lt 2 || "$2" =~ ^-- ]]; then
                echo "Error: --flag requires a value" >&2
                echo "" >&2
                echo "Usage: /plugin:command [args] --flag <value>" >&2
                echo "" >&2
                echo "Example:" >&2
                echo "  ✅ /plugin:command --flag value" >&2
                echo "  ✅ /plugin:command --flag \"multi word value\"" >&2
                exit 2
            fi
            FLAG_VALUE="$2"
            shift 2
            ;;

        --boolean-flag)
            # Boolean flag (no value)
            BOOLEAN_FLAG="true"
            shift
            ;;

        --*=*)
            # Detect and reject equals syntax
            FLAG_NAME="${1%%=*}"
            echo "Error: Use space-separated syntax, not equals syntax" >&2
            echo "" >&2
            echo "Use: $FLAG_NAME <value>" >&2
            echo "Not: $1" >&2
            echo "" >&2
            echo "Example:" >&2
            echo "  ✅ /plugin:command $FLAG_NAME value" >&2
            echo "  ❌ /plugin:command $1" >&2
            exit 2
            ;;

        --*)
            # Unknown flag
            echo "Error: Unknown flag: $1" >&2
            echo "" >&2
            echo "Valid flags:" >&2
            echo "  --flag <value>      Description of flag" >&2
            echo "  --boolean-flag      Description of boolean flag" >&2
            exit 2
            ;;

        *)
            # Positional argument
            if [[ -z "$POSITIONAL_ARG" ]]; then
                POSITIONAL_ARG="$1"
            else
                echo "Error: Unexpected argument: $1" >&2
                exit 2
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$POSITIONAL_ARG" ]]; then
    echo "Error: Missing required argument" >&2
    echo "" >&2
    echo "Usage: /plugin:command <required-arg> [--flag <value>]" >&2
    exit 2
fi
```

### Usage in Plugins

When a developer creates a new command:

1. **Copy the standard pattern** from the docs
2. **Customize for their flags**:
   - Replace `--flag` with actual flag names
   - Add/remove flags as needed
   - Update error messages
3. **Paste into command markdown** in the `<WORKFLOW>` section
4. **Test thoroughly**

### Maintaining Consistency

**During Development:**
- Use the standard pattern template
- Copy-paste from docs when creating commands
- Follow the exact structure

**During Code Review:**
- Verify parsing matches standard pattern
- Check error messages are helpful
- Ensure equals syntax is rejected

**During Updates:**
- Update the standard pattern in docs
- Gradually update existing commands
- No rush - done during normal maintenance

### Example: Creating a New Command

```markdown
---
name: my-plugin:my-command
argument-hint: <arg> [--flag <value>] [--boolean-flag]
---

# My Command

<WORKFLOW>
## Step 1: Parse Arguments

```bash
#!/bin/bash

# [Copy standard parsing pattern from docs/standards/COMMAND-ARGUMENT-SYNTAX.md]
# Then customize for this command's specific flags...

FLAG_VALUE=""
BOOLEAN_FLAG=""
ARG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --flag)
            if [[ $# -lt 2 || "$2" =~ ^-- ]]; then
                echo "Error: --flag requires a value" >&2
                # ... helpful error message
                exit 2
            fi
            FLAG_VALUE="$2"
            shift 2
            ;;
        # ... rest of pattern
    esac
done
```

## Step 2: Use Parsed Values
...
</WORKFLOW>
```

## Benefits of This Approach

### Immediate Benefits
1. ✅ **Works Now** - No architecture changes needed
2. ✅ **Self-Contained** - Each plugin stands alone
3. ✅ **Simple Install** - No dependencies
4. ✅ **Clear Pattern** - Easy to copy and customize

### Long-term Benefits
1. ✅ **Consistent** - Same pattern everywhere
2. ✅ **Maintainable** - Update docs, devs copy new version
3. ✅ **Documented** - Single source of truth in docs
4. ✅ **Testable** - Each plugin can test independently

### Transition Path
1. **Now**: Inline parsing with standard pattern
2. **Later**: Create fractary-core plugin when needed
3. **Future**: Migrate to fractary-core gradually
4. **Vision**: Fractary CLI/SDK for rich tooling

## Documentation Strategy

### In Standards Doc
```markdown
## Standard Parsing Pattern

**Copy this pattern when creating new commands:**

```bash
#!/bin/bash
# [Full standard pattern here]
```

**Customize by:**
1. Replace flag names
2. Update error messages
3. Add validation logic
```

### In Plugin Template
```markdown
## Creating a New Command

1. Copy the standard parsing pattern from docs/standards/COMMAND-ARGUMENT-SYNTAX.md
2. Customize for your command's flags
3. Add your command logic
4. Test with:
   - Single-word values
   - Multi-word values (with quotes)
   - Boolean flags
   - Equals syntax (should error)
```

### In Code Reviews
- Checklist: "Does parsing follow standard pattern?"
- Reference: Link to standard doc
- Suggest: "Use standard pattern from docs/standards/COMMAND-ARGUMENT-SYNTAX.md"

## Migration Strategy

### Phase 1: Update Standard (Immediate)
1. ✅ Document standard pattern in COMMAND-ARGUMENT-SYNTAX.md
2. ✅ Include copy-paste ready code
3. ✅ Add examples and customization guide

### Phase 2: Update Existing Commands (This Week)
1. Copy standard pattern into each command
2. Customize for command's specific flags
3. Test thoroughly
4. No shared script needed

### Phase 3: Future Enhancement (When Needed)
1. Create fractary-core plugin
2. Move shared code there
3. Update plugins to use fractary-core
4. Maintain both approaches during transition

## Conclusion

**Use inline parsing with standard pattern for immediate implementation.**

This provides:
- ✅ Immediate solution
- ✅ No architectural changes
- ✅ Self-contained plugins
- ✅ Consistent pattern
- ✅ Clear documentation
- ✅ Easy maintenance

**Future-proof:**
- Path to shared library when architecture supports it
- No technical debt - clean pattern now
- Easy migration later

**Recommendation:** Proceed with inline parsing approach using the standard pattern defined in docs/standards/COMMAND-ARGUMENT-SYNTAX.md
