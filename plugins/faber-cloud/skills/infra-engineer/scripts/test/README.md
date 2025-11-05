# Infrastructure Engineer Script Tests

This directory contains integration tests for the infrastructure engineer scripts.

## Test Files

- `test-parse-input.sh` - Tests for parse-input.sh (input parsing and validation)
- `test-load-context.sh` - Tests for load-context.sh (context loading and requirements extraction)
- `test-validate-terraform.sh` - Tests for validate-terraform.sh (Terraform validation)

## Running Tests

### Run All Tests

```bash
cd plugins/faber-cloud/skills/infra-engineer/scripts/test
./run-all-tests.sh
```

### Run Individual Tests

```bash
# Test parse-input
./test-parse-input.sh

# Test load-context
./test-load-context.sh

# Test validate-terraform
./test-validate-terraform.sh
```

## Test Coverage

### parse-input.sh Tests

- ✅ Simple design file reference
- ✅ FABER spec reference
- ✅ Direct instructions (no file)
- ✅ Mixed context (file + additional instructions)
- ✅ Empty input (latest design fallback)
- ✅ Natural language with filename
- ✅ Path traversal attempt (security - should fail)
- ✅ Input too long (should fail)
- ✅ Full design path
- ✅ Special characters in filename

### load-context.sh Tests

- ✅ Load design file
- ✅ Load FABER spec
- ✅ Direct instructions
- ✅ Requirements extraction with word boundaries
- ✅ Empty file detection
- ✅ Invalid JSON config handling
- ✅ Missing config fallback

### validate-terraform.sh Tests

- ✅ Valid Terraform code
- ✅ Invalid Terraform syntax
- ✅ Terraform fmt failures
- ✅ Missing main.tf
- ✅ Hardcoded values detection
- ✅ Missing tags detection
- ✅ S3 encryption check
- ✅ Validation error reporting

## Test Data

Test data is created in temporary directories for each test run to avoid polluting the codebase.

## CI Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run infra-engineer script tests
  run: |
    cd plugins/faber-cloud/skills/infra-engineer/scripts/test
    ./run-all-tests.sh
```

## Adding New Tests

To add new tests:

1. Add test case to appropriate test file
2. Use `assert_success` for expected successes
3. Use `assert_failure` for expected failures
4. Update this README with new test coverage

## Known Limitations

- Tests require `jq`, `realpath`, and `terraform` to be installed
- Some tests create temporary files/directories
- Tests assume they're run from the test directory
