# Test Suite

This directory contains tests for the linter and other development tools.

## Automated Tests

**Note:** The automated test suite (`test-lint-frontmatter.sh`) currently has a known issue with subprocess buffering that causes it to hang on some systems. This is a test framework issue, not an issue with the linter itself.

### Manual Testing (Recommended)

Until the subprocess issue is resolved, use these manual tests:

```bash
# Test 1: Valid files should pass
./scripts/lint-command-frontmatter.sh --quiet tests/fixtures/valid/
# Expected: Exit code 0, "✓ All checks passed!"

# Test 2: Invalid files should fail
./scripts/lint-command-frontmatter.sh --quiet tests/fixtures/invalid/
# Expected: Exit code 1, "✗ Found 3 error(s) that must be fixed"

# Test 3: Leading slash error message
./scripts/lint-command-frontmatter.sh tests/fixtures/invalid/commands/leading-slash.md | grep "leading slash"
# Expected: Finds error message

# Test 4: Missing name error message
./scripts/lint-command-frontmatter.sh tests/fixtures/invalid/commands/missing-name.md | grep "Missing required field"
# Expected: Finds error message

# Test 5: Multi-line YAML support
./scripts/lint-command-frontmatter.sh --quiet tests/fixtures/valid/commands/multiline-description.md
# Expected: Exit code 0

# Test 6: --fix flag
cp tests/fixtures/invalid/commands/leading-slash.md /tmp/test-fix.md
./scripts/lint-command-frontmatter.sh --fix /tmp/test-fix.md
grep "^name: test-plugin:leading-slash" /tmp/test-fix.md
# Expected: Name field no longer has leading slash

# Test 7: --verbose flag
./scripts/lint-command-frontmatter.sh --verbose tests/fixtures/valid/ | grep "✓.*simple-command.md"
# Expected: Shows passing files

# Test 8: --quiet flag
./scripts/lint-command-frontmatter.sh --quiet tests/fixtures/valid/ | grep -c "File:"
# Expected: 0 (no file-by-file output)

# Test 9: --help flag
./scripts/lint-command-frontmatter.sh --help
# Expected: Shows usage information
```

## Test Fixtures

### Valid Fixtures (`tests/fixtures/valid/commands/`)
- `simple-command.md` - Minimal valid frontmatter
- `with-examples.md` - With examples and argument-hint
- `multiline-description.md` - Multi-line YAML description using `>`

### Invalid Fixtures (`tests/fixtures/invalid/commands/`)
- `leading-slash.md` - Name has leading slash (auto-fixable)
- `missing-name.md` - Missing required name field
- `no-frontmatter.md` - No frontmatter structure
- `invalid-pattern.md` - Name doesn't follow pattern (warning only)

## Adding New Tests

When adding new validation rules to the linter:

1. Add test fixtures to `tests/fixtures/valid/commands/` or `tests/fixtures/invalid/commands/`
2. Add manual test commands to this README
3. Test the linter against the new fixtures

## CI/CD Testing

The GitHub Actions workflow (`.github/workflows/lint-frontmatter.yml`) runs the linter automatically on PRs that modify command files. This provides automated validation without needing the test framework to work.
