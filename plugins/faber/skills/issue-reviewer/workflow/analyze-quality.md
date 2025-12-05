# Analyze Code Quality

This workflow step reviews code changes for quality issues and improvement opportunities.

## Overview

Using the claude-opus-4-5 model, analyze:
1. Code quality and best practices
2. Potential bugs or edge cases
3. Error handling completeness
4. Test coverage
5. Documentation quality

## Prerequisites

- Context gathered from `gather-context.md`
- Specification compliance analyzed
- Code diff available
- Test files identified

## Steps

### 1. Analyze Code Quality

Review code for best practices and potential issues:

**Model Prompt (claude-opus-4-5):**
```
Role: Code Quality Reviewer

You are reviewing code changes for quality, best practices, and potential issues.

CODE CHANGES:
{code_diff}

FILES CHANGED:
{files_with_content}

PROJECT CONTEXT:
- Repository: {repo_name}
- Language/Framework: Markdown skills, Shell scripts
- Purpose: FABER workflow plugin for Claude Code

TASK:
Analyze the code changes for:

1. BEST PRACTICES
   - Does the code follow established patterns?
   - Is the code well-structured and readable?
   - Are naming conventions followed?

2. POTENTIAL BUGS
   - Edge cases not handled
   - Error conditions that could fail
   - Race conditions or timing issues

3. ERROR HANDLING
   - Are errors caught and handled gracefully?
   - Are error messages helpful?
   - Is there appropriate fallback behavior?

4. SECURITY
   - Input validation
   - Command injection risks in shell scripts
   - Sensitive data exposure

5. IMPROVEMENT OPPORTUNITIES
   - Refactoring suggestions
   - Performance optimizations
   - Cleaner implementations

OUTPUT FORMAT (JSON):
{
  "quality_issues": [
    {
      "severity": "critical|major|minor",
      "category": "bug|error_handling|security|best_practice|performance",
      "file": "path/to/file.sh",
      "line": 45,
      "description": "Missing error handling for network timeout",
      "suggestion": "Add timeout wrapper with retry logic",
      "confidence": 0.9
    }
  ],
  "improvements": [
    {
      "priority": "high|medium|low",
      "category": "refactor|performance|readability|maintainability",
      "description": "Consider extracting repeated logic into shared function",
      "file": "path/to/file.sh",
      "lines": "30-50",
      "effort": "small|medium|large"
    }
  ],
  "positive_findings": [
    "Good error handling in gather-context workflow",
    "Clear separation of concerns in workflow steps"
  ],
  "summary": {
    "critical_issues": 0,
    "major_issues": 1,
    "minor_issues": 3,
    "improvements_suggested": 2
  }
}
```

---

### 2. Assess Test Coverage

Analyze test files and coverage:

**Check for Tests:**
```bash
# Find test files related to changes
for file in ${CHANGED_FILES[@]}; do
  base=$(basename "$file" .sh)
  base=${base%.md}

  # Look for corresponding test files
  find tests -name "*${base}*" -type f
done
```

**Test Coverage Analysis:**
```json
{
  "test_coverage": {
    "test_files_added": [
      "tests/issue-reviewer/gather-context.test.sh"
    ],
    "test_files_modified": [],
    "untested_files": [
      "scripts/generate-report.sh"
    ],
    "coverage_assessment": {
      "adequate": true,
      "percentage_estimate": 85,
      "reasoning": "Core functionality has tests, utility scripts partially covered"
    },
    "missing_test_scenarios": [
      "Test with missing specification",
      "Test with very large diff (>5000 lines)",
      "Test with network failure during issue fetch"
    ],
    "recommendations": [
      "Add edge case tests for empty issue body",
      "Add integration test with full FABER workflow"
    ]
  }
}
```

**Coverage Thresholds:**
| Coverage | Assessment |
|----------|------------|
| >= 85% | Adequate |
| 70-84% | Acceptable with notes |
| < 70% | Needs improvement |
| 0% | Flag as issue |

---

### 3. Evaluate Documentation

Check documentation quality:

**Documentation Checks:**
- [ ] SKILL.md exists and is complete
- [ ] Workflow files have clear explanations
- [ ] Scripts have usage comments
- [ ] Error handling documented
- [ ] Integration points documented

**Output:**
```json
{
  "documentation": {
    "adequate": true,
    "score": 90,
    "findings": {
      "present": [
        "SKILL.md with full specification",
        "Workflow files with step-by-step instructions",
        "Error handling section"
      ],
      "missing": [
        "Troubleshooting guide",
        "Configuration examples"
      ],
      "improvements": [
        "Add more inline comments to shell scripts",
        "Document return codes in scripts"
      ]
    }
  }
}
```

---

### 4. Categorize Issues by Severity

**Severity Definitions:**

| Severity | Definition | Examples |
|----------|------------|----------|
| **Critical** | Blocks functionality or causes data loss | Missing required function, security vulnerability |
| **Major** | Significant impact on quality or reliability | Poor error handling, missing tests for core logic |
| **Minor** | Small improvements or style issues | Naming conventions, code organization |

**Issue Categorization:**
```json
{
  "issues_by_severity": {
    "critical": [],
    "major": [
      {
        "file": "scripts/gather-issue-context.sh",
        "line": 45,
        "description": "No error handling for API rate limiting"
      }
    ],
    "minor": [
      {
        "file": "workflow/gather-context.md",
        "description": "Could use more specific variable names"
      }
    ]
  }
}
```

---

### 5. Generate Quality Report

Aggregate all quality findings:

```json
{
  "quality_analysis": {
    "timestamp": "2025-12-05T15:50:00Z",
    "model_used": "claude-opus-4-5",
    "issues": {
      "critical": 0,
      "major": 1,
      "minor": 3,
      "total": 4,
      "by_category": {
        "error_handling": 2,
        "best_practice": 1,
        "performance": 1
      }
    },
    "test_coverage": {
      "adequate": true,
      "percentage": 85,
      "missing_scenarios": [...]
    },
    "documentation": {
      "adequate": true,
      "score": 90
    },
    "improvements": [
      {
        "priority": "medium",
        "description": "Add progress indicator for long analyses"
      }
    ],
    "positive_findings": [
      "Clean separation of workflow steps",
      "Good use of JSON for structured output"
    ],
    "summary": "Code quality is good overall. One major issue (error handling) should be addressed."
  }
}
```

## Quality Impact on Status

**How Quality Affects Final Status:**

| Condition | Status Impact |
|-----------|---------------|
| Critical issues found | → "failure" |
| Major issues found | → "failure" (unless spec 100%) |
| Only minor issues | → "warning" |
| No issues | → Depends on coverage |
| Tests missing | → At least "warning" |
| Docs missing | → At least "warning" |

## Output

Pass quality analysis to determine-status step:

```json
{
  "code_quality": {
    "critical_issues": 0,
    "major_issues": 1,
    "minor_issues": 3,
    "test_coverage_adequate": true,
    "documentation_adequate": true,
    "details": {...}
  }
}
```
