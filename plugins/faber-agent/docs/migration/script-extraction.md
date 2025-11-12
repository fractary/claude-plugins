# Migration Guide: Script Extraction - Moving Logic from Agent/Skill to Scripts

## Overview

**Anti-pattern**: Bash commands and data processing in agent/skill markdown
**Correct pattern**: Deterministic operations in executable shell scripts

This guide shows how to extract bash operations from agents and skills into dedicated scripts.

---

## The Problem: Inline Bash Operations

### Why Inline Bash is Anti-pattern

**Context Cost:**
```markdown
## Phase 1: Deploy
Run bash:
```bash
terraform init
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
terraform output -json > output.json
```

Parse output.json:
- Extract resource IDs
- Validate deployment
- Check health status
```

**Cost**: ~500 tokens for bash commands + parsing logic

**Better**:
```markdown
## Phase 1: Deploy
Execute: `scripts/deploy-terraform.sh`
```

**Cost**: ~50 tokens (90% reduction)

**The script content (500 tokens) is executed by bash, never enters LLM context.**

### Additional Problems

**Inconsistency:**
- Same bash logic duplicated across multiple agents
- Changes require updating multiple files
- No single source of truth

**Testability:**
- Can't test bash logic without invoking agent
- Can't unit test individual operations
- Hard to debug failures

**Maintainability:**
- Bash syntax errors in markdown
- No syntax highlighting
- No shellcheck validation
- Difficult to version control changes

**Security:**
- Harder to audit embedded commands
- Variables not validated before use
- No input sanitization

---

## The Solution: Executable Scripts

### Script Structure

```
skills/skill-name/
├── SKILL.md                    # Skill definition (calls scripts)
└── scripts/                    # Executable scripts directory
    ├── operation-1.sh          # Script for operation 1
    ├── operation-2.sh          # Script for operation 2
    └── lib/                    # Shared utilities
        ├── common.sh           # Common functions
        └── validators.sh       # Input validators
```

### Script Template

```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# operation-name.sh
# Description: What this script does

# Input validation
PARAM_1="${1:?Error: param_1 required}"
PARAM_2="${2:?Error: param_2 required}"
PARAM_3="${3:-default_value}"  # Optional with default

# Load common functions (if applicable)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Validate inputs
validate_directory "$PARAM_1"
validate_file "$PARAM_2"

# Main operation
main() {
  # Step 1: Do work
  result=$(do_work "$PARAM_1" "$PARAM_2")

  # Step 2: Process result
  processed=$(process_result "$result")

  # Step 3: Output structured JSON
  cat <<EOF
{
  "status": "success",
  "operation": {
    "param_1": "$PARAM_1",
    "param_2": "$PARAM_2",
    "result": "$processed",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
}

# Error handler
error_handler() {
  local line_no=$1
  cat <<EOF
{
  "status": "error",
  "error": "Script failed at line $line_no",
  "operation": "operation-name"
}
EOF
  exit 1
}

trap 'error_handler $LINENO' ERR

# Run main
main
```

---

## Extraction Process

### Step 1: Identify Bash Operations

Mark all bash operations in agent/skill:

**Example Agent:**
```markdown
## Phase 1: Build Application

1. Install dependencies:
```bash
cd {{PROJECT_DIR}}
npm ci
```                                    # ← EXTRACT

2. Run build:
```bash
npm run build
```                                    # ← EXTRACT

3. Check build output:
```bash
if [ -d "dist" ]; then
  file_count=$(ls dist | wc -l)
  echo "Build created $file_count files"
fi
```                                    # ← EXTRACT

4. Store build info in state          # ← KEEP (orchestration)
```

### Step 2: Group Related Operations

**Group by logical operation:**

Operation 1: **build-application**
- Install dependencies (npm ci)
- Run build (npm run build)
- Check output (verify dist/ directory)

Operation 2: **verify-build**
- Count files
- Check bundle size
- Validate artifacts

**Create scripts:**
- `scripts/build-application.sh`
- `scripts/verify-build.sh`

### Step 3: Create Script Files

**scripts/build-application.sh:**
```bash
#!/bin/bash
set -euo pipefail

# build-application.sh
# Builds application and returns build info

PROJECT_DIR="${1:?Error: Project directory required}"

# Validate project directory exists
if [[ ! -d "$PROJECT_DIR" ]]; then
  cat <<EOF
{
  "status": "error",
  "error": "project_not_found",
  "project_dir": "$PROJECT_DIR"
}
EOF
  exit 1
fi

cd "$PROJECT_DIR"

# Install dependencies
echo "Installing dependencies..." >&2
npm ci --silent

# Run build
echo "Building application..." >&2
npm run build

# Check build output
if [[ ! -d "dist" ]]; then
  cat <<EOF
{
  "status": "error",
  "error": "build_failed",
  "message": "dist/ directory not created"
}
EOF
  exit 1
fi

# Count files
FILE_COUNT=$(find dist -type f | wc -l)

# Calculate total size
TOTAL_SIZE=$(du -sb dist | cut -f1)

# Output structured JSON
cat <<EOF
{
  "status": "success",
  "build": {
    "project_dir": "$PROJECT_DIR",
    "output_dir": "dist",
    "file_count": $FILE_COUNT,
    "total_size_bytes": $TOTAL_SIZE,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
```

**scripts/verify-build.sh:**
```bash
#!/bin/bash
set -euo pipefail

# verify-build.sh
# Verifies build artifacts meet requirements

BUILD_DIR="${1:?Error: Build directory required}"
MAX_SIZE_MB="${2:-10}"  # Default 10MB max

# Validate build directory exists
if [[ ! -d "$BUILD_DIR" ]]; then
  cat <<EOF
{
  "status": "error",
  "error": "build_dir_not_found",
  "build_dir": "$BUILD_DIR"
}
EOF
  exit 1
fi

# Check bundle.js exists
if [[ ! -f "$BUILD_DIR/bundle.js" ]]; then
  cat <<EOF
{
  "status": "error",
  "error": "bundle_not_found",
  "expected": "$BUILD_DIR/bundle.js"
}
EOF
  exit 1
fi

# Get bundle size
BUNDLE_SIZE=$(stat -f%z "$BUILD_DIR/bundle.js" 2>/dev/null || stat -c%s "$BUILD_DIR/bundle.js")
BUNDLE_SIZE_MB=$((BUNDLE_SIZE / 1024 / 1024))

# Check size limit
SIZE_OK=true
if [[ $BUNDLE_SIZE_MB -gt $MAX_SIZE_MB ]]; then
  SIZE_OK=false
fi

# Output verification results
cat <<EOF
{
  "status": "success",
  "verification": {
    "build_dir": "$BUILD_DIR",
    "bundle_exists": true,
    "bundle_size_bytes": $BUNDLE_SIZE,
    "bundle_size_mb": $BUNDLE_SIZE_MB,
    "max_size_mb": $MAX_SIZE_MB,
    "size_ok": $SIZE_OK,
    "passed": $SIZE_OK
  }
}
EOF
```

### Step 4: Update Skill to Use Scripts

**Before (Inline Bash):**
```markdown
## build-application

**Process:**
1. Change to project directory
2. Run npm ci
3. Run npm run build
4. Check dist/ directory exists
5. Count output files
6. Return build info
```

**After (Script Execution):**
```markdown
## build-application

**Input:**
- `project_dir`: Path to project directory

**Process:**
1. Execute: `scripts/build-application.sh "$project_dir"`
2. Parse script output (JSON)
3. Return build info

**Output:**
```json
{
  "status": "success",
  "build": {
    "project_dir": "/path/to/project",
    "output_dir": "dist",
    "file_count": 12,
    "total_size_bytes": 4523891,
    "timestamp": "2025-01-11T16:30:00Z"
  }
}
```

**On Error:**
```json
{
  "status": "error",
  "error": "build_failed",
  "message": "dist/ directory not created"
}
```
```

### Step 5: Make Scripts Executable

```bash
chmod +x skills/*/scripts/*.sh
```

**Verify:**
```bash
find skills -name "*.sh" -exec test -x {} \; -print
```

---

## Script Best Practices

### Input Validation

**Always validate required inputs:**
```bash
PROJECT_DIR="${1:?Error: Project directory required}"
ENV="${2:?Error: Environment required}"
REGION="${3:-us-east-1}"  # Optional with default

# Validate directory exists
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo '{"status": "error", "error": "directory_not_found"}' >&2
  exit 1
fi

# Validate environment is valid
if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  echo '{"status": "error", "error": "invalid_environment"}' >&2
  exit 1
fi
```

### Error Handling

**Use trap for consistent error handling:**
```bash
#!/bin/bash
set -euo pipefail

error_handler() {
  local line_no=$1
  local exit_code=$2
  cat <<EOF
{
  "status": "error",
  "error": "script_error",
  "line": $line_no,
  "exit_code": $exit_code,
  "script": "${BASH_SOURCE[0]}"
}
EOF
}

trap 'error_handler $LINENO $?' ERR
```

**Explicit error returns:**
```bash
if ! terraform apply -auto-approve; then
  cat <<EOF
{
  "status": "error",
  "error": "terraform_apply_failed",
  "operation": "infrastructure_deployment"
}
EOF
  exit 1
fi
```

### Structured Output

**Always return JSON:**
```bash
# Success case
cat <<EOF
{
  "status": "success",
  "operation": {
    "key": "value",
    "count": 42
  }
}
EOF

# Error case
cat <<EOF
{
  "status": "error",
  "error": "error_code",
  "message": "Human readable error message"
}
EOF
```

**Avoid plain text output** (hard for skills to parse):
```bash
# ❌ Don't do this
echo "Build completed successfully"
echo "Files created: 12"

# ✓ Do this
cat <<EOF
{
  "status": "success",
  "message": "Build completed successfully",
  "file_count": 12
}
EOF
```

### Logging vs Output

**stderr for logs, stdout for structured output:**
```bash
# Logs go to stderr (not captured by skill)
echo "Starting deployment..." >&2
echo "Applying terraform..." >&2

# Structured result goes to stdout (captured by skill)
cat <<EOF
{
  "status": "success",
  "deployment": {
    "resources_created": 5
  }
}
EOF
```

### Idempotency

**Scripts should be idempotent (safe to run multiple times):**

```bash
# ❌ Not idempotent
mkdir /tmp/build
cp files/* /tmp/build/

# ✓ Idempotent
mkdir -p /tmp/build  # -p: no error if exists
rsync -a files/ /tmp/build/  # rsync handles overwrites
```

```bash
# ❌ Not idempotent
aws s3 mb s3://my-bucket  # Fails if bucket exists

# ✓ Idempotent
if ! aws s3 ls s3://my-bucket 2>/dev/null; then
  aws s3 mb s3://my-bucket
fi
```

### Common Functions Library

**Create reusable functions in scripts/lib/common.sh:**

```bash
#!/bin/bash
# common.sh - Shared utility functions

# Validate directory exists
validate_directory() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "{\"status\": \"error\", \"error\": \"directory_not_found\", \"dir\": \"$dir\"}"
    exit 1
  fi
}

# Validate file exists
validate_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "{\"status\": \"error\", \"error\": \"file_not_found\", \"file\": \"$file\"}"
    exit 1
  fi
}

# Check command exists
require_command() {
  local cmd="$1"
  if ! command -v "$cmd" &> /dev/null; then
    echo "{\"status\": \"error\", \"error\": \"command_not_found\", \"command\": \"$cmd\"}"
    exit 1
  fi
}

# Parse JSON field
json_field() {
  local json="$1"
  local field="$2"
  echo "$json" | jq -r ".$field"
}

# Success output template
output_success() {
  local operation="$1"
  local data="$2"
  cat <<EOF
{
  "status": "success",
  "$operation": $data
}
EOF
}

# Error output template
output_error() {
  local error_code="$1"
  local message="$2"
  cat <<EOF
{
  "status": "error",
  "error": "$error_code",
  "message": "$message"
}
EOF
}
```

**Use in scripts:**
```bash
#!/bin/bash
set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PROJECT_DIR="${1:?Error: Project directory required}"

# Use common validation
validate_directory "$PROJECT_DIR"
require_command "npm"

# Do work...

# Use common output template
output_success "build" '{
  "project_dir": "'"$PROJECT_DIR"'",
  "file_count": 12
}'
```

---

## Complete Example: Before & After

### Before (Inline Bash in Skill)

**skills/deployer/SKILL.md:**
```markdown
## deploy-infrastructure

**Process:**
1. Initialize Terraform:
```bash
cd {{INFRA_DIR}}
terraform init
```

2. Plan deployment:
```bash
terraform plan -out=plan.tfplan
```

3. Apply deployment:
```bash
terraform apply plan.tfplan
```

4. Get outputs:
```bash
terraform output -json > /tmp/tf-output.json
```

5. Parse outputs:
```bash
INSTANCE_ID=$(jq -r '.instance_id.value' /tmp/tf-output.json)
PUBLIC_IP=$(jq -r '.public_ip.value' /tmp/tf-output.json)
```

6. Return deployment info:
```json
{
  "status": "success",
  "deployment": {
    "instance_id": "{{INSTANCE_ID}}",
    "public_ip": "{{PUBLIC_IP}}"
  }
}
```
```

**Problems:**
- 200+ tokens for bash commands
- Hard to test
- Duplicated across skills
- No error handling
- No validation

### After (Script Extraction)

**skills/deployer/SKILL.md:**
```markdown
## deploy-infrastructure

**Input:**
- `infra_dir`: Path to infrastructure directory

**Process:**
1. Execute: `scripts/deploy-terraform.sh "$infra_dir"`
2. Parse script output
3. Return deployment info

**Output:**
```json
{
  "status": "success",
  "deployment": {
    "instance_id": "i-1234567890abcdef0",
    "public_ip": "203.0.113.42",
    "resources_created": 5,
    "deployment_time_seconds": 120,
    "timestamp": "2025-01-11T16:30:00Z"
  }
}
```
```

**Skill markdown**: ~50 tokens (75% reduction)

**skills/deployer/scripts/deploy-terraform.sh:**
```bash
#!/bin/bash
set -euo pipefail

# deploy-terraform.sh
# Deploy infrastructure using Terraform

INFRA_DIR="${1:?Error: Infrastructure directory required}"

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Validate inputs
validate_directory "$INFRA_DIR"
require_command "terraform"
require_command "jq"

# Start timer
START_TIME=$(date +%s)

# Change to infrastructure directory
cd "$INFRA_DIR"

# Initialize Terraform
echo "Initializing Terraform..." >&2
terraform init -input=false

# Plan deployment
echo "Planning deployment..." >&2
terraform plan -out=plan.tfplan -input=false

# Apply deployment
echo "Applying deployment..." >&2
if ! terraform apply plan.tfplan; then
  output_error "terraform_apply_failed" "Terraform apply failed"
  exit 1
fi

# Get outputs
terraform output -json > /tmp/tf-output.json

# Parse outputs
INSTANCE_ID=$(jq -r '.instance_id.value' /tmp/tf-output.json)
PUBLIC_IP=$(jq -r '.public_ip.value' /tmp/tf-output.json)

# Count resources created
RESOURCE_COUNT=$(terraform state list | wc -l)

# Calculate deployment time
END_TIME=$(date +%s)
DEPLOYMENT_TIME=$((END_TIME - START_TIME))

# Output structured result
cat <<EOF
{
  "status": "success",
  "deployment": {
    "instance_id": "$INSTANCE_ID",
    "public_ip": "$PUBLIC_IP",
    "resources_created": $RESOURCE_COUNT,
    "deployment_time_seconds": $DEPLOYMENT_TIME,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF

# Cleanup
rm -f plan.tfplan /tmp/tf-output.json
```

**Script**: Not in LLM context (0 tokens)

**Benefits:**
- ✓ Testable independently: `./deploy-terraform.sh /path/to/infra`
- ✓ Error handling with trap
- ✓ Input validation
- ✓ Structured JSON output
- ✓ Logging to stderr
- ✓ Idempotent terraform operations
- ✓ Reusable across skills

---

## Extraction Checklist

### Identification

- [ ] List all bash commands in agent/skill files
- [ ] Group related commands into logical operations
- [ ] Identify common patterns (can be extracted to lib/common.sh)
- [ ] Mark dependencies between operations

### Script Creation

- [ ] Create scripts/ directory in skill
- [ ] Create lib/ subdirectory for common functions
- [ ] Write lib/common.sh with reusable functions
- [ ] For each operation:
  - [ ] Create operation-name.sh
  - [ ] Add shebang and set -euo pipefail
  - [ ] Add input validation
  - [ ] Add error handling (trap)
  - [ ] Add logging to stderr
  - [ ] Output structured JSON to stdout
  - [ ] Make executable (chmod +x)

### Skill Updates

- [ ] Replace bash blocks with script calls
- [ ] Document script inputs in operation descriptions
- [ ] Document expected JSON output format
- [ ] Document error cases
- [ ] Remove inline bash from skill markdown

### Validation

- [ ] Test each script independently
- [ ] Test error cases (missing inputs, invalid inputs)
- [ ] Verify JSON output is valid
- [ ] Verify scripts are executable
- [ ] Run workflow-validator on skill
- [ ] Test complete workflow end-to-end

---

## Common Mistakes

### Mistake 1: Keeping "Simple" Bash Inline

**Wrong:**
```markdown
## Phase 1
Run bash: mkdir -p /tmp/build  # "It's just one line"
```

**Correct:**
```markdown
## Phase 1
Execute: `scripts/prepare-build-dir.sh`
```

**Why?** Consistency. One-liners become multi-liners.

### Mistake 2: Plain Text Output

**Wrong (scripts/build.sh):**
```bash
echo "Build completed"
echo "Files: 12"
```

**Correct:**
```bash
cat <<EOF
{
  "status": "success",
  "message": "Build completed",
  "file_count": 12
}
EOF
```

### Mistake 3: No Error Handling

**Wrong:**
```bash
terraform apply plan.tfplan
echo '{"status": "success"}'  # What if terraform failed?
```

**Correct:**
```bash
if ! terraform apply plan.tfplan; then
  output_error "terraform_failed" "Terraform apply failed"
  exit 1
fi
output_success "deployment" '{"resources": 5}'
```

### Mistake 4: Not Making Scripts Executable

```bash
# ❌ Don't forget
ls -l scripts/*.sh
# -rw-r--r-- (not executable)

# ✓ Make executable
chmod +x scripts/*.sh
ls -l scripts/*.sh
# -rwxr-xr-x (executable)
```

---

## Results

**Context Reduction**: 50-70% typical reduction
**Testability**: Scripts can be tested independently
**Maintainability**: Single source of truth for operations
**Reusability**: Scripts can be shared across skills
**Debugging**: Easier to debug bash logic
**Security**: Centralized input validation

---

## Next Steps

After extracting scripts:

1. Test all scripts independently
2. Add script integration tests
3. Document script dependencies (required commands, env vars)
4. Review scripts with shellcheck for best practices
5. Create lib/common.sh for reusable functions
6. Update skill documentation with script examples
