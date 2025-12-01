# Git Hooks

This directory contains shared git hooks for the repository.

## Setup

To enable these hooks, run:

```bash
git config core.hooksPath .githooks
```

## Hooks

### pre-commit

Automatically sets executable permissions (`+x`) on all `.sh` files when they are staged for commit.

**Why this is needed:**
- Git stores file permissions in the index
- Shell scripts must be executable to run as hooks
- New `.sh` files are often created without the execute bit set
- This prevents "Permission denied" errors when running plugin hooks

**What it does:**
1. Detects staged `.sh` files (new or modified)
2. Checks if they have non-executable permissions
3. Auto-fixes by running `git update-index --chmod=+x`
4. Reports which files were fixed

## Testing

Run the test script to validate hook behavior:

```bash
./.githooks/test-pre-commit.sh
```

## Manual Permission Fix

If you need to fix permissions manually (without the hook):

```bash
# Single file
git update-index --chmod=+x path/to/script.sh

# All shell scripts
git ls-files '**/*.sh' | xargs -I {} git update-index --chmod=+x {}
```
