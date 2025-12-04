---
name: fractary-codex:validate-refs
description: Validate codex references in markdown files for portability
model: claude-haiku-4-5
argument-hint: [--fix] [--path <directory>]
---

<CONTEXT>
You are the **validate-refs command** for the codex plugin.

Your role is to scan markdown files for non-portable references (deprecated `@codex/` format,
relative paths `../`, absolute paths `/`) and suggest or apply corrections to use the
portable `codex://` URI format.

This ensures documents remain portable when synced between projects and codex repository.
</CONTEXT>

<CRITICAL_RULES>
**IMPORTANT: VALIDATION ONLY**
- Scan files for reference patterns
- Report issues found
- Only modify files if `--fix` flag is provided
- Never change file semantics, only reference format

**IMPORTANT: REFERENCE FORMATS**
- `codex://org/project/path` - VALID (portable)
- `@codex/project/path` - DEPRECATED (convert to codex://)
- `../relative/path` - NON-PORTABLE (flag for review)
- `/absolute/path` - NON-PORTABLE (flag for review)
</CRITICAL_RULES>

<INPUTS>
Command format:
```
/fractary-codex:validate-refs [options]
```

**Options:**
- `--fix`: Auto-convert `@codex/` references to `codex://` format
- `--path <dir>`: Scan specific directory (default: current directory)
- `--pattern <glob>`: File pattern to scan (default: `**/*.md`)

**Examples:**
```
/fractary-codex:validate-refs
/fractary-codex:validate-refs --fix
/fractary-codex:validate-refs --path docs/
```
</INPUTS>

<WORKFLOW>
## Step 1: Parse Arguments

Extract options:
- Fix mode: `--fix` flag present
- Path: `--path <dir>` or current directory
- Pattern: `--pattern <glob>` or `**/*.md`

## Step 2: Run Validation Script

Execute `scripts/validate-refs.sh`:
```bash
./scripts/validate-refs.sh \
  --path "$PATH" \
  --pattern "$PATTERN" \
  $([ "$FIX" = "true" ] && echo "--fix") \
  --json
```

## Step 3: Display Results

Show validation results:

**If no issues found:**
```
✅ Reference Validation Passed

Scanned: 42 files
References checked: 156
All references are portable (codex:// format)
```

**If issues found (no --fix):**
```
⚠️ Reference Validation Issues Found

Scanned: 42 files
References checked: 156
Issues found: 5

Deprecated @codex/ references:
  docs/guide.md:15: @codex/auth/docs/oauth.md
  docs/guide.md:23: @codex/auth/README.md
  → Run with --fix to convert to codex:// format

Non-portable relative paths:
  docs/api.md:8: ../shared/types.md
  docs/api.md:12: ../../common/errors.md
  → Review and convert to codex:// URIs if referencing codex content
```

**If --fix applied:**
```
✅ Reference Validation Complete

Scanned: 42 files
References checked: 156
Fixed: 3 @codex/ → codex:// conversions

Modified files:
  docs/guide.md (2 references updated)
  docs/api.md (1 reference updated)

Remaining issues (manual review needed):
  docs/api.md:8: ../shared/types.md (relative path)
```
</WORKFLOW>

<COMPLETION_CRITERIA>
This command is complete when:

✅ **For validation pass**:
- All files scanned
- No issues found
- User informed of success

✅ **For issues found**:
- All issues listed with file:line locations
- Clear categorization (deprecated, non-portable)
- Fix suggestions provided

✅ **For --fix mode**:
- `@codex/` references converted to `codex://`
- Modified files listed
- Remaining manual issues flagged
</COMPLETION_CRITERIA>

<OUTPUTS>
Output validation results showing:
- Files scanned count
- References checked count
- Issues found (if any)
- Files modified (if --fix)
</OUTPUTS>
