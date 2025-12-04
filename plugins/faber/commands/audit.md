---
model: claude-haiku-4-5
---

# /fractary-faber:audit

Validate FABER workflow configuration and report issues.

## What This Does

Performs comprehensive validation of `.fractary/plugins/faber/config.json`:
- ✅ File existence and valid JSON
- ✅ Required fields present
- ✅ All 5 FABER phases defined
- ✅ Phase structure validation (steps, validation criteria)
- ✅ Hook configuration (10 phase-level hooks)
- ✅ Plugin integration references
- ✅ Configuration completeness score

**Features**:
- 🔍 Deep validation of configuration structure
- 📊 Configuration completeness score (0-100%)
- 💡 Actionable suggestions for improvements
- ⚠️ Warning and error reporting
- 🎯 Best practice recommendations

## Usage

```bash
# Validate current configuration
/fractary-faber:audit

# Validate with detailed output
/fractary-faber:audit --verbose

# Validate and auto-fix simple issues
/fractary-faber:audit --fix

# Check specific aspect
/fractary-faber:audit --check phases
/fractary-faber:audit --check hooks
/fractary-faber:audit --check integrations
```

## What Gets Validated

### 1. Configuration File
- ✅ File exists at `.fractary/plugins/faber/config.json`
- ✅ Valid JSON syntax
- ✅ Schema version is "2.0"

### 2. Workflows Array
- ✅ `workflows` array exists and is not empty
- ✅ At least one workflow defined (typically "default")
- ✅ Each workflow has required fields: `id`, `description`, `phases`, `hooks`, `autonomy`
- ✅ Workflow IDs are unique

### 3. Workflow Validation (for each workflow)

#### Phases (All 5 Required)
- ✅ **Frame** phase defined with steps
- ✅ **Architect** phase defined with steps
- ✅ **Build** phase defined with steps
- ✅ **Evaluate** phase defined with steps (max_retries configured)
- ✅ **Release** phase defined with steps (require_approval configured)

For each phase:
- ✅ `enabled` field present
- ✅ `description` field present
- ✅ `steps` array with at least one step
- ✅ `validation` criteria defined

#### Hooks (10 Phase-Level Hooks)
- ✅ `pre_frame` array present
- ✅ `post_frame` array present
- ✅ `pre_architect` array present
- ✅ `post_architect` array present
- ✅ `pre_build` array present
- ✅ `post_build` array present
- ✅ `pre_evaluate` array present
- ✅ `post_evaluate` array present
- ✅ `pre_release` array present
- ✅ `post_release` array present

For each hook:
- ✅ Valid type (document, skill, script)
- ✅ Required fields present (name, description)
- ✅ Referenced files/skills exist

#### Autonomy Configuration
- ✅ `autonomy.level` valid (dry-run, assist, guarded, autonomous)
- ✅ `autonomy.pause_before_release` defined
- ✅ `autonomy.require_approval_for` array present

### 4. Global Configuration

#### Logging Configuration
- ✅ `logging.use_logs_plugin` is true
- ✅ `logging.log_type` is "workflow"
- ✅ `logging.log_level` valid

#### Integrations
- ✅ `integrations.work_plugin` configured
- ✅ `integrations.repo_plugin` configured
- ✅ `integrations.spec_plugin` configured
- ✅ `integrations.logs_plugin` configured
- ✅ Referenced plugins are installed

#### Safety Configuration
- ✅ `safety.protected_paths` defined
- ✅ `safety.require_confirm_for` defined

## Validation Levels

**ERROR** (Must fix):
- Missing required fields
- Invalid JSON syntax
- Missing phase definitions
- Invalid autonomy level

**WARNING** (Should fix):
- Missing hook definitions
- Missing validation criteria
- Plugin integrations not found
- Deprecated configuration options

**INFO** (Nice to have):
- Missing optional fields
- Best practice recommendations
- Performance suggestions

## Output Format

```
🔍 FABER Configuration Audit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Configuration Completeness: 95/100

✅ PASSED (15)
  ✓ Configuration file exists
  ✓ Valid JSON syntax
  ✓ All 5 phases defined
  ✓ All 10 hooks present
  ✓ Autonomy level configured
  ... (10 more)

⚠️  WARNINGS (2)
  ! Hook 'pre_architect' references missing file: docs/architecture/STANDARDS.md
  ! Plugin 'fractary-docs' not found in .fractary/plugins/

💡 SUGGESTIONS (3)
  → Consider adding validation criteria for build phase
  → Add safety confirmation for deployment steps
  → Consider using 'guarded' autonomy level for production

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next: Fix warnings with /fractary-faber:audit --fix
```

## Auto-Fix Capabilities

When using `--fix` flag, the command can automatically:
- Add missing hook arrays (empty arrays)
- Set default values for optional fields
- Fix common typos in field names
- Add missing validation criteria arrays

**Manual fixes required for**:
- Invalid JSON syntax
- Missing required values
- Wrong autonomy levels
- Missing phase definitions

## Implementation

This command should:
1. Check configuration file exists
2. Parse JSON and validate syntax
3. Validate each configuration section
4. Check plugin integrations
5. Verify hook and skill references
6. Calculate completeness score
7. Generate actionable report
8. Apply auto-fixes if requested

## Exit Codes

- **0**: All validations passed (100% complete)
- **1**: Warnings present (>80% complete)
- **2**: Errors present (<80% complete)
- **3**: Configuration file not found
- **4**: Invalid JSON syntax

## Use Cases

**When to use audit:**
- After manual configuration changes
- Before running first FABER workflow
- After upgrading FABER version
- Troubleshooting workflow issues
- CI/CD configuration validation
- Pre-commit hook validation

## See Also

- `/fractary-faber:init` - Initialize configuration
- `/fractary-faber:status` - Check workflow status
- Config templates: `plugins/faber/config/templates/`
- Example config: `plugins/faber/config/faber.example.json`
