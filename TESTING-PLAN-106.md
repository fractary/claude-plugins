# Testing Plan: Issue #106 - Type-Specific Documentation Skills

**Issue**: [#106](https://github.com/fractary/claude-plugins/issues/106)
**Branch**: `feat/106-expand-doc-types-custom-skills`
**Date**: 2025-11-13
**Status**: Ready for Testing

## Overview

This document outlines the comprehensive testing plan for validating all 5 new type-specific documentation skills and their supporting infrastructure.

## Test Categories

### 1. Unit Tests (Skill-Level)
### 2. Integration Tests (Workflow-Level)
### 3. System Tests (End-to-End)
### 4. Performance Tests
### 5. Migration Tests

---

## 1. Unit Tests - Skill-Level Validation

### 1.1 docs-manage-architecture-adr Skill

**Test ID**: ADR-001
**Objective**: Verify 5-digit ADR generation with auto-numbering

**Test Steps**:
```bash
# Test 1: Generate first ADR with auto-number
/fractary-docs:generate adr "Use PostgreSQL for data storage"

# Expected:
# - File created: docs/architecture/ADR/ADR-00001-use-postgresql-for-data-storage.md
# - Frontmatter includes: number: 00001, type: adr, status: proposed
# - README.md index updated with new entry

# Test 2: Generate second ADR to verify sequential numbering
/fractary-docs:generate adr "Implement caching strategy"

# Expected:
# - File created: ADR-00002-implement-caching-strategy.md
# - Sequential numbering works correctly

# Test 3: Generate ADR with specific number
/fractary-docs:generate adr "API versioning approach" --number 00010

# Expected:
# - File created: ADR-00010-api-versioning-approach.md
# - Number override works correctly

# Test 4: Verify index auto-update
cat docs/architecture/ADR/README.md

# Expected:
# - All 3 ADRs listed in index
# - Sorted by number (00001, 00002, 00010)
# - Status shown for each
```

**Validation Checklist**:
- [ ] Files created with correct 5-digit format
- [ ] Auto-numbering increments correctly
- [ ] Manual number assignment works
- [ ] README.md index auto-updates
- [ ] Frontmatter complete and valid
- [ ] No file conflicts or overwrites

---

**Test ID**: ADR-002
**Objective**: Verify ADR migration script

**Test Steps**:
```bash
# Setup: Create test directory with 3-digit ADRs
mkdir -p /tmp/test-adrs
cd /tmp/test-adrs
echo "---\ntitle: Test\nnumber: 001\n---\n# ADR-001-test" > ADR-001-test.md
echo "---\ntitle: Test2\nnumber: 002\n---\n# ADR-002-test2" > ADR-002-test2.md

# Test: Run migration in dry-run mode
bash plugins/docs/skills/docs-manage-architecture-adr/scripts/migrate-adrs.sh \
  --source /tmp/test-adrs \
  --destination /tmp/test-adrs-migrated \
  --dry-run

# Expected:
# - Shows planned migrations: 001 → 00001, 002 → 00002
# - No files actually changed
# - Cross-reference updates identified

# Test: Run actual migration
bash plugins/docs/skills/docs-manage-architecture-adr/scripts/migrate-adrs.sh \
  --source /tmp/test-adrs \
  --destination /tmp/test-adrs-migrated

# Expected:
# - Files renamed to 5-digit format
# - Frontmatter updated
# - Cross-references updated
# - Git history preserved (if in git repo)
```

**Validation Checklist**:
- [ ] Dry-run shows correct plan
- [ ] Actual migration renames files correctly
- [ ] Frontmatter updated
- [ ] Cross-references updated
- [ ] Git history preserved

---

### 1.2 docs-manage-architecture Skill

**Test ID**: ARCH-001
**Objective**: Verify architecture overview generation

**Test Steps**:
```bash
# Test 1: Generate architecture overview
/fractary-docs:generate architecture "System Architecture Overview" --status draft

# Expected:
# - File created: docs/architecture/system-architecture-overview.md
# - Sections: Overview, System Context, Components, Patterns, Technology Stack
# - README.md index updated

# Test 2: Generate component documentation
/fractary-docs:generate architecture "Authentication Service" --tags security,component

# Expected:
# - File created: docs/architecture/authentication-service.md
# - Component-specific sections included
# - Tags in frontmatter

# Test 3: Verify hierarchical index organization
cat docs/architecture/README.md

# Expected:
# - Overviews listed first
# - Components grouped together
# - Diagrams listed separately (if any)
```

**Validation Checklist**:
- [ ] Overview template generates correctly
- [ ] Component template generates correctly
- [ ] README.md index auto-updates
- [ ] Hierarchical organization works
- [ ] Tags and metadata correct

---

### 1.3 docs-manage-guides Skill

**Test ID**: GUIDE-001
**Objective**: Verify audience-specific guide generation

**Test Steps**:
```bash
# Test 1: Generate developer guide
/fractary-docs:generate guide "Getting Started for Developers" --status published

# Expected:
# - File created: docs/guides/getting-started-for-developers.md
# - Audience: developer detected from title
# - Sections: Purpose, Prerequisites, Steps, Troubleshooting

# Test 2: Generate user guide
/fractary-docs:generate guide "User Manual" --status draft

# Expected:
# - File created: docs/guides/user-manual.md
# - Audience: user
# - Lower technical level in template

# Test 3: Verify audience-organized index
cat docs/guides/README.md

# Expected:
# - Guides organized by audience (Developer, User, Admin, Contributor)
# - Each guide under appropriate heading
```

**Validation Checklist**:
- [ ] Guide template generates correctly
- [ ] Audience detection/assignment works
- [ ] README.md organized by audience
- [ ] Step-by-step format included
- [ ] Status tracking works

---

### 1.4 docs-manage-schema Skill

**Test ID**: SCHEMA-001
**Objective**: Verify dual-format schema generation

**Test Steps**:
```bash
# Test 1: Generate schema documentation
/fractary-docs:generate schema "User Profile Schema" --tags user,data

# Expected:
# - Two files created:
#   1. docs/schema/user-profile/README.md (human-readable)
#   2. docs/schema/user-profile/schema.json (JSON Schema)
# - Both files have consistent data
# - README.md index updated

# Test 2: Verify README.md content
cat docs/schema/user-profile/README.md

# Expected:
# - Overview section
# - Schema Format section
# - Fields documentation
# - Validation Rules
# - Examples
# - Version information

# Test 3: Verify schema.json validity
jq . docs/schema/user-profile/schema.json

# Expected:
# - Valid JSON
# - JSON Schema Draft 7 format
# - All required fields present
# - Version matches README.md

# Test 4: Verify hierarchical schema support
/fractary-docs:generate schema "User Profile Address" --tags user,data

# Expected:
# - File created: docs/schema/user-profile-address/README.md
# - Nested under user-profile in hierarchy
```

**Validation Checklist**:
- [ ] Both files (README.md + schema.json) generated
- [ ] Content consistent between both formats
- [ ] JSON Schema Draft 7 compliant
- [ ] README.md human-readable and complete
- [ ] Semantic versioning applied
- [ ] Index updated correctly
- [ ] Hierarchical organization works

---

### 1.5 docs-manage-api Skill

**Test ID**: API-001
**Objective**: Verify dual-format API endpoint generation

**Test Steps**:
```bash
# Test 1: Generate API endpoint documentation
/fractary-docs:generate api "POST /api/users" --tags api,users

# Expected:
# - Two files created:
#   1. docs/api/post-api-users/README.md
#   2. docs/api/post-api-users/endpoint.json (OpenAPI 3.0)
# - Both files consistent
# - README.md index updated

# Test 2: Verify README.md content
cat docs/api/post-api-users/README.md

# Expected:
# - Overview section
# - Authentication documentation
# - Request parameters
# - Request body specification
# - Response codes and bodies
# - Examples
# - Error codes

# Test 3: Verify OpenAPI 3.0 compliance
cat docs/api/post-api-users/endpoint.json | jq .

# Expected:
# - Valid JSON
# - OpenAPI 3.0.3 structure
# - Paths defined
# - Responses defined
# - Security schemes if applicable

# Test 4: Verify service-organized index
/fractary-docs:generate api "GET /api/users/:id" --tags api,users

# Expected:
# - README.md index organizes by service (users)
# - Related endpoints grouped together
```

**Validation Checklist**:
- [ ] Both files (README.md + endpoint.json) generated
- [ ] OpenAPI 3.0.3 compliant
- [ ] HTTP methods supported (GET, POST, PUT, PATCH, DELETE)
- [ ] README.md complete and human-readable
- [ ] Service-organized index works
- [ ] Authentication documented

---

### 1.6 docs-manage-standards Skill

**Test ID**: STANDARD-001
**Objective**: Verify scope-based standards generation

**Test Steps**:
```bash
# Test 1: Generate plugin-scope standard
/fractary-docs:generate standard "Plugin Naming Conventions" --status active

# Expected:
# - File created: docs/standards/plugin-naming-conventions.md
# - Scope: plugin
# - Status: active
# - Sections: Purpose, Standards, Enforcement, Examples

# Test 2: Verify standards structure
cat docs/standards/plugin-naming-conventions.md

# Expected:
# - Each rule has requirement level (must/should/may)
# - Rationale provided for each rule
# - Enforcement methods documented (automated + manual)
# - Examples of compliant and non-compliant cases
# - Tools recommended

# Test 3: Generate repo-scope standard
/fractary-docs:generate standard "Commit Message Standards" --status active

# Expected:
# - File created: docs/standards/repo-commit-message-standards.md
# - Scope: repo
# - Machine-readable format

# Test 4: Verify scope-organized index
cat docs/standards/README.md

# Expected:
# - Standards organized by scope (Plugin, Repo, Org, Team)
# - Each standard under appropriate scope heading
# - Status shown for each
```

**Validation Checklist**:
- [ ] Standard template generates correctly
- [ ] Scope assignment works (plugin/repo/org/team)
- [ ] RFC 2119 requirement levels present
- [ ] Enforcement section complete
- [ ] Examples section complete
- [ ] Machine-readable format maintained
- [ ] README.md organized by scope

---

## 2. Integration Tests - Workflow-Level

### 2.1 Automatic Index Updates

**Test ID**: INDEX-001
**Objective**: Verify index-updater.sh works across all doc types

**Test Steps**:
```bash
# Setup: Generate multiple documents of same type
/fractary-docs:generate adr "Decision 1"
/fractary-docs:generate adr "Decision 2"
/fractary-docs:generate adr "Decision 3"

# Test 1: Verify index updates after each generation
cat docs/architecture/ADR/README.md

# Expected:
# - All 3 ADRs listed
# - Sorted correctly
# - Metadata displayed

# Test 2: Generate document, delete it, regenerate index
rm docs/architecture/ADR/ADR-00003-decision-3.md
# Manually trigger reindex (via skill)

# Expected:
# - Index no longer shows deleted ADR
# - No broken links

# Test 3: Test concurrent updates
# (Run 2 skills simultaneously to test atomic writes)

# Expected:
# - No corrupted index
# - All documents listed
# - No race conditions
```

**Validation Checklist**:
- [ ] Index updates after each document operation
- [ ] Atomic writes prevent corruption
- [ ] Deleted documents removed from index
- [ ] Concurrent updates handled safely
- [ ] Index format consistent

---

### 2.2 Dual-Format Generation

**Test ID**: DUAL-001
**Objective**: Verify dual-format-generator.sh consistency

**Test Steps**:
```bash
# Test 1: Generate schema and verify both files
/fractary-docs:generate schema "Test Schema" --tags test

# Test: Extract data from both files and compare
README_TITLE=$(grep "^# " docs/schema/test-schema/README.md | head -1 | sed 's/# //')
JSON_TITLE=$(jq -r '.title' docs/schema/test-schema/schema.json)

echo "README Title: $README_TITLE"
echo "JSON Title: $JSON_TITLE"

# Expected:
# - Titles match
# - Version numbers match
# - Field definitions consistent

# Test 2: Generate API endpoint and verify OpenAPI
/fractary-docs:generate api "GET /api/test" --tags test

# Test: Validate OpenAPI structure
jq '.openapi' docs/api/get-api-test/endpoint.json

# Expected:
# - OpenAPI version is "3.0.3"
# - Paths match README.md
# - Responses match README.md
```

**Validation Checklist**:
- [ ] Both formats generated simultaneously
- [ ] Data consistency between formats
- [ ] Version numbers match
- [ ] Field definitions match
- [ ] Validation passes for both formats

---

### 2.3 Command Routing

**Test ID**: ROUTE-001
**Objective**: Verify /fractary-docs:generate routes correctly

**Test Steps**:
```bash
# Test: Generate each doc type and verify correct skill invoked

# Type-specific skills
/fractary-docs:generate adr "Test ADR"
# Should invoke: docs-manage-architecture-adr

/fractary-docs:generate architecture "Test Architecture"
# Should invoke: docs-manage-architecture

/fractary-docs:generate guide "Test Guide"
# Should invoke: docs-manage-guides

/fractary-docs:generate schema "Test Schema"
# Should invoke: docs-manage-schema

/fractary-docs:generate api "GET /test"
# Should invoke: docs-manage-api

/fractary-docs:generate standard "Test Standard"
# Should invoke: docs-manage-standards

# Legacy fallback
/fractary-docs:generate design "Test Design"
# Should invoke: doc-generator

# Verification: Check generated files match expected skill patterns
```

**Validation Checklist**:
- [ ] Each type routes to correct skill
- [ ] Type-specific skills invoked first
- [ ] Legacy types fall back to doc-generator
- [ ] No routing errors
- [ ] Output matches expected skill format

---

## 3. System Tests - End-to-End

### 3.1 Complete Documentation Lifecycle

**Test ID**: E2E-001
**Objective**: Full workflow from init to validation

**Test Steps**:
```bash
# Step 1: Initialize new project
mkdir /tmp/test-docs-project
cd /tmp/test-docs-project
git init

# Step 2: Initialize docs plugin
/fractary-docs:init

# Expected:
# - Config created: .fractary/plugins/docs/config.json
# - Directory structure created
# - Initial README.md created

# Step 3: Generate documentation of each type
/fractary-docs:generate adr "Use TypeScript"
/fractary-docs:generate architecture "System Overview"
/fractary-docs:generate guide "Developer Setup"
/fractary-docs:generate schema "User Schema"
/fractary-docs:generate api "POST /users"
/fractary-docs:generate standard "Code Style"

# Step 4: Verify all files created
find docs -type f -name "*.md" | wc -l
# Expected: 6 README.md files + 6 generated docs = 12 files minimum

# Step 5: Verify dual-format files
ls docs/schema/*/schema.json
ls docs/api/*/endpoint.json
# Expected: 2 files total

# Step 6: Validate all documentation
/fractary-docs:validate

# Expected:
# - All documents pass validation
# - No broken links
# - All frontmatter valid

# Step 7: Check all indices
cat docs/architecture/ADR/README.md
cat docs/architecture/README.md
cat docs/guides/README.md
cat docs/schema/README.md
cat docs/api/README.md
cat docs/standards/README.md

# Expected:
# - All indices contain generated documents
# - Proper organization
# - No broken links
```

**Validation Checklist**:
- [ ] Init creates proper structure
- [ ] All doc types generate successfully
- [ ] Dual-format files created
- [ ] All indices updated
- [ ] Validation passes
- [ ] No errors in workflow

---

## 4. Performance Tests

### 4.1 Index Update Performance

**Test ID**: PERF-001
**Objective**: Verify index updates complete in < 1 second

**Test Steps**:
```bash
# Setup: Create directory with 100 ADRs
mkdir -p /tmp/perf-test/docs/architecture/ADR
cd /tmp/perf-test/docs/architecture/ADR

# Generate 100 ADR files
for i in $(seq -w 1 100); do
  cat > "ADR-000${i}-test-adr-${i}.md" <<EOF
---
title: Test ADR ${i}
number: 000${i}
status: proposed
---
# Test ADR ${i}
EOF
done

# Test: Time index regeneration
time bash /path/to/index-updater.sh /tmp/perf-test/docs/architecture/ADR adr

# Expected:
# - Completion time < 1 second
# - README.md contains all 100 entries
# - Sorted correctly
```

**Validation Checklist**:
- [ ] Index update < 1 second for 100 documents
- [ ] All documents listed
- [ ] No performance degradation
- [ ] Memory usage acceptable

---

### 4.2 Dual-Format Generation Performance

**Test ID**: PERF-002
**Objective**: Verify dual-format generation is efficient

**Test Steps**:
```bash
# Test: Time dual-format generation
time /fractary-docs:generate schema "Large Schema with Many Fields"

# Expected:
# - Both files generated
# - Completion time < 5 seconds
# - Files correctly formatted
```

**Validation Checklist**:
- [ ] Generation completes quickly
- [ ] Both formats created
- [ ] No performance issues
- [ ] Memory efficient

---

## 5. Migration Tests

### 5.1 3-Digit to 5-Digit ADR Migration

**Test ID**: MIGRATE-001
**Objective**: Verify complete migration workflow

**Test Steps**:
```bash
# Setup: Create repository with 3-digit ADRs
mkdir -p /tmp/migration-test/docs/architecture/adrs
cd /tmp/migration-test
git init

# Create 10 ADRs in old format
for i in $(seq 1 10); do
  num=$(printf "%03d" $i)
  cat > "docs/architecture/adrs/ADR-${num}-test.md" <<EOF
---
title: Test ADR ${i}
number: ${num}
---
# ADR-${num} Test
References: ADR-001, ADR-002
EOF
  git add docs/architecture/adrs/ADR-${num}-test.md
  git commit -m "Add ADR-${num}"
done

# Test 1: Dry run
bash plugins/docs/skills/docs-manage-architecture-adr/scripts/migrate-adrs.sh \
  --source docs/architecture/adrs \
  --destination docs/architecture/ADR \
  --dry-run

# Expected:
# - Shows 10 migrations planned
# - Lists cross-reference updates
# - No files changed

# Test 2: Run migration
bash plugins/docs/skills/docs-manage-architecture-adr/scripts/migrate-adrs.sh \
  --source docs/architecture/adrs \
  --destination docs/architecture/ADR

# Expected:
# - 10 files migrated
# - Numbers: 001 → 00001, 002 → 00002, etc.
# - Cross-references updated
# - Git history preserved

# Test 3: Verify migration results
ls docs/architecture/ADR/
cat docs/architecture/ADR/ADR-00001-test.md

# Expected:
# - File named ADR-00001-test.md
# - Frontmatter: number: 00001
# - Cross-references: ADR-00001, ADR-00002
```

**Validation Checklist**:
- [ ] Dry run accurate
- [ ] Files renamed correctly
- [ ] Frontmatter updated
- [ ] Cross-references updated
- [ ] Git history preserved
- [ ] No data loss

---

## Test Execution Summary

### Execution Plan

**Phase 1: Unit Tests** (Estimated: 2 hours)
- Run all skill-level tests
- Validate each skill independently
- Fix any issues found

**Phase 2: Integration Tests** (Estimated: 1 hour)
- Test skill interactions
- Verify shared infrastructure
- Validate command routing

**Phase 3: System Tests** (Estimated: 1 hour)
- End-to-end workflows
- Real-world scenarios
- Complete lifecycle testing

**Phase 4: Performance Tests** (Estimated: 30 minutes)
- Index update performance
- Dual-format generation speed
- Scalability validation

**Phase 5: Migration Tests** (Estimated: 30 minutes)
- ADR migration scenarios
- Backward compatibility
- Data integrity

**Total Estimated Time**: 5 hours

### Success Criteria

**All tests must pass with**:
- ✅ 100% of unit tests passing
- ✅ 100% of integration tests passing
- ✅ 100% of system tests passing
- ✅ Performance targets met (< 1s index updates)
- ✅ Migration tests successful with data integrity

### Test Reporting

Create test report document:
- `TEST-REPORT-106.md`
- Include all test results
- Document any issues found
- List recommendations

---

## Next Steps After Testing

1. **Document Test Results**: Create comprehensive test report
2. **Fix Issues**: Address any failures found during testing
3. **Update Documentation**: Add test results to implementation docs
4. **Create Pull Request**: With test report attached
5. **Request Review**: Tag reviewers and provide context

---

**Last Updated**: 2025-11-13
**Test Plan Status**: Ready for Execution
**Estimated Execution Time**: 5 hours
