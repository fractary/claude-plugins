# Specification: Automatic Issue Review during Evaluate Phase

**Issue**: #233  
**Title**: Automatic process during evaluate phase to ensure issue/spec actually resolved  
**Work ID**: WORK-00233  
**Created**: 2025-12-05  
**Status**: Active  
**Phase**: 1 - Core Skill Implementation  

---

## Executive Summary

This specification defines the implementation of an **automatic issue-review skill** for the FABER plugin that ensures code changes actually resolve the work item and specification as requested. The skill runs automatically as the first step in the **evaluate phase** without requiring configuration, providing an extra layer of review to catch missed requirements and identify improvement opportunities.

**Problem Statement**: Development teams frequently find that completed work doesn't fully implement the specification, especially with large issues and limited context windows. A structured review process is needed to catch these gaps before release.

**Solution**: An automated skill that analyzes code changes against the specification and returns a detailed summary with a status code indicating success, warnings, or failure.

---

## Requirements

### Functional Requirements

#### FR-1: Automatic Invocation
- **Description**: The skill must run automatically as the first step in the evaluate phase
- **Acceptance Criteria**:
  - No configuration entry required in workflow files
  - Skill invokes before any other evaluate phase steps
  - Works with all FABER autonomy levels (dry-run, assist, guarded, full)

#### FR-2: Input Gathering
- **Description**: The skill must gather all necessary context to perform review
- **Acceptance Criteria**:
  - Fetches issue details (work-id, title, description, all comments)
  - Retrieves all related specifications (including multi-phase specs)
  - Gathers code changes from branch since issue start
  - Retrieves PR details if PR exists
  - Collects test files and coverage metrics

#### FR-3: Specification Analysis
- **Description**: The skill must analyze whether code changes implement the specification
- **Acceptance Criteria**:
  - Parses all requirements from specification
  - Verifies each requirement has corresponding implementation
  - Checks acceptance criteria are met
  - Identifies gaps in requirement coverage
  - Maps spec sections to code changes

#### FR-4: Code Quality Analysis
- **Description**: The skill must identify code quality and improvement opportunities
- **Acceptance Criteria**:
  - Analyzes code for best practices
  - Identifies potential bugs or edge cases
  - Suggests refactoring opportunities
  - Checks test coverage completeness
  - Evaluates documentation quality

#### FR-5: Status Determination
- **Description**: The skill must classify implementation completeness into three status codes
- **Acceptance Criteria**:
  - **success**: Issue/spec implemented as requested, no major issues
  - **warning**: Issue/spec implemented as requested, but minor issues or improvement opportunities identified
  - **failure**: Issue/spec not implemented as requested OR medium/major/critical issues identified
  - Status determination logic is clear and repeatable

#### FR-6: Detailed Output Report
- **Description**: The skill must return comprehensive analysis summary
- **Acceptance Criteria**:
  - Lists all requirements with implementation status
  - Documents acceptance criteria verification
  - Lists code quality issues by severity
  - Suggests specific improvements
  - Provides confidence level for each finding

#### FR-7: Model Specification
- **Description**: The skill must use claude-opus-4-5 for analysis
- **Acceptance Criteria**:
  - Requests explicitly use model: claude-opus-4-5
  - Falls back gracefully if model unavailable (with warning)
  - Provides reasoning for model choice (supports complex analysis)

#### FR-8: Integration with FABER Phase System
- **Description**: The skill must integrate seamlessly with FABER workflow phases
- **Acceptance Criteria**:
  - Executes in evaluate phase context
  - Has access to work-id from previous phases
  - Returns status to faber-manager for phase handling
  - Supports retry logic if evaluation fails
  - Works with all result-handling strategies

### Non-Functional Requirements

#### NFR-1: Performance
- **Description**: Analysis must complete within reasonable timeframe
- **Acceptance Criteria**:
  - Analysis completes within 60 seconds for typical issues (< 5 files, < 500 lines)
  - Handles large changes (20+ files, 2000+ lines) within 120 seconds
  - Provides progress feedback for longer analyses

#### NFR-2: Context Efficiency
- **Description**: Skill must minimize context usage
- **Acceptance Criteria**:
  - Uses summarization for large code diffs
  - Includes only relevant code excerpts in analysis
  - Leverages specification text without full duplication
  - Tracks token usage and logs warnings if excessive

#### NFR-3: Error Handling
- **Description**: Skill must handle missing inputs gracefully
- **Acceptance Criteria**:
  - Operates even if specification is missing (reviews against issue description)
  - Handles private/archived specifications
  - Reports missing context and continues with available data
  - Never blocks workflow due to review issues

#### NFR-4: Auditability
- **Description**: Review analysis must be auditable and traceable
- **Acceptance Criteria**:
  - Saves analysis report to local file
  - Comments on GitHub issue with summary findings
  - Maintains audit trail in FABER state
  - Includes model used and analysis timestamp

---

## Detailed Design

### Architecture

#### Components

```
skill: issue-reviewer
├── workflow/
│   ├── gather-context.md       # Issue, spec, PR, code changes
│   ├── analyze-specification.md # Requirement verification
│   ├── analyze-code-quality.md  # Code quality review
│   └── determine-status.md      # Classification logic
└── scripts/
    ├── gather-issue-context.sh      # Fetch issue + comments
    ├── gather-spec-context.sh       # Fetch specifications
    ├── gather-code-changes.sh       # Diff analysis
    ├── analyze-requirements.sh      # Spec compliance
    ├── analyze-quality.sh           # Code quality
    └── generate-report.sh           # Report formatting
```

#### Data Flow

```
FABER Manager
    ↓
evaluate phase entry (automatic)
    ↓
issue-reviewer skill
    ├─ Gather Context
    │  ├─ Issue details (work plugin)
    │  ├─ Specifications (spec plugin)
    │  ├─ Code changes (repo plugin)
    │  └─ PR details (repo plugin)
    ├─ Analyze Specification
    │  └─ claude-opus-4-5 model
    ├─ Analyze Code Quality
    │  └─ claude-opus-4-5 model
    ├─ Determine Status
    │  └─ Local classification logic
    └─ Generate Report
       ├─ Local file
       └─ GitHub comment
    ↓
Return {status, summary, findings}
    ↓
FABER Manager (continue or retry)
```

### Workflow Steps

#### Step 1: Gather Context

**Inputs**: work_id from FABER state

**Process**:
1. Fetch issue details via work plugin
   - Title, description, assignees, labels
   - All comments in chronological order
2. Fetch related specifications via spec plugin
   - Find all specs for this issue
   - Include specification text
   - Handle multi-phase specifications
3. Fetch code changes
   - Get branch name from FABER state
   - Diff against main/base branch
   - Summarize file changes
   - Gather test files
4. Fetch PR details if PR created
   - PR number, description, reviewers
   - PR discussion/comments

**Outputs**:
```json
{
  "work_id": "233",
  "issue": {
    "title": "...",
    "body": "...",
    "comments": [...]
  },
  "specifications": [...],
  "code_changes": {
    "files": [...],
    "added_lines": 245,
    "deleted_lines": 18,
    "test_files": [...]
  },
  "pr": {...}
}
```

#### Step 2: Analyze Specification Compliance

**Inputs**: Context from Step 1, code changes

**Process**:
1. Extract all requirements from specification
2. For each requirement:
   - Identify corresponding code changes
   - Verify implementation exists
   - Check acceptance criteria
3. Extract improvement opportunities from spec
4. Build requirement coverage matrix

**Model Call** (claude-opus-4-5):
```
Role: Code spec reviewer
Task: Analyze code changes against specification
Inputs:
- Specification text
- Code diff
- Issue description
Analyze:
1. Which requirements are implemented?
2. Which requirements are missing?
3. Which acceptance criteria are met?
4. What gaps exist?
Output JSON: {
  "requirements": [
    {"text": "...", "implemented": true, "evidence": "file:line", "gaps": []}
  ],
  "acceptance_criteria": [
    {"text": "...", "met": true, "gaps": []}
  ],
  "coverage_percentage": 95,
  "missing_requirements": [],
  "critical_gaps": []
}
```

**Outputs**:
```json
{
  "coverage_percentage": 95,
  "requirements": [
    {
      "requirement": "Automatic skill invocation at evaluate phase start",
      "implemented": true,
      "evidence": "faber-manager.md:1247-1289"
    },
    {
      "requirement": "No configuration required",
      "implemented": false,
      "gap": "Still requires phase hook configuration"
    }
  ],
  "acceptance_criteria_met": [true, true, true, false],
  "critical_gaps": ["PR merge handling not implemented"],
  "gaps_summary": "3 minor, 1 critical"
}
```

#### Step 3: Analyze Code Quality

**Inputs**: Code changes, test files, documentation changes

**Process**:
1. Analyze code for quality issues:
   - Best practices
   - Potential bugs
   - Edge cases
   - Error handling
2. Check test coverage:
   - Test files added/modified
   - Coverage metrics
   - Missing test scenarios
3. Review documentation:
   - Spec updated
   - API documentation
   - Comments in code

**Model Call** (claude-opus-4-5):
```
Role: Code quality reviewer
Task: Identify code quality issues and improvements
Inputs:
- Code changes (diff)
- Test files added
- Documentation changes
Analyze:
1. Code quality issues (categorize by severity)
2. Missing tests
3. Documentation gaps
4. Improvement opportunities
Output JSON: {
  "issues": [
    {"severity": "critical|major|minor", "category": "...", "description": "...", "location": "file:line", "suggestion": "..."}
  ],
  "test_coverage": {
    "adequate": true/false,
    "missing_scenarios": [...],
    "coverage_percentage": 85
  },
  "documentation": {
    "adequate": true/false,
    "gaps": [...]
  },
  "improvement_opportunities": [...]
}
```

**Outputs**:
```json
{
  "quality_issues": [
    {
      "severity": "minor",
      "category": "error_handling",
      "description": "Missing error handling for network timeout",
      "file": "skills/issue-reviewer/scripts/gather-issue-context.sh",
      "line": 45,
      "suggestion": "Add timeout wrapper with retry logic"
    }
  ],
  "test_coverage": {
    "adequate": true,
    "coverage_percentage": 92,
    "missing_scenarios": ["Large issue (1000+ comments)", "Private repository"]
  },
  "documentation": {
    "adequate": false,
    "gaps": ["Configuration migration guide", "Troubleshooting section"]
  },
  "improvements": [
    {
      "priority": "medium",
      "description": "Add progress indicator for long analyses",
      "rationale": "UX improvement for transparency"
    }
  ]
}
```

#### Step 4: Determine Status

**Inputs**: Specification compliance, code quality analysis

**Process**:
```
IF spec coverage == 100% AND
   NO critical/major issues AND
   test coverage >= 85% AND
   documentation adequate
   THEN status = "success"

ELSE IF spec coverage >= 95% AND
        ONLY minor issues/opportunities AND
        test coverage >= 80%
        THEN status = "warning"

ELSE
   status = "failure"
```

**Outputs**:
```json
{
  "status": "success|warning|failure",
  "reasons": [...],
  "confidence": 0.95,
  "recommendation": "Ready for release" | "Address issues before release" | "Do not release"
}
```

### Integration with FABER

#### Automatic Invocation

The issue-reviewer skill is **automatically invoked** at evaluate phase start through the faber-manager:

**Location**: `faber-manager.md` evaluate phase handler

```
At evaluate phase entry:
  IF phase == "evaluate" AND first_step == true
    INVOKE issue-reviewer skill with work_id
    
Status handling:
  IF issue_reviewer.status == "failure"
    Mark phase as REQUIRES_REVIEW
    RETURN to user with findings
    
  ELSE IF issue_reviewer.status == "warning"
    Log warnings
    CONTINUE to next step
    
  ELSE (success)
    Continue normally
```

#### Configuration

**No configuration required**. The skill:
- Auto-detects work_id from FABER state
- Auto-detects branch from FABER state
- Automatically fetches issue and spec
- Automatically runs at evaluate phase start

#### Phase Lifecycle

```
evaluate phase
  ├─ [AUTOMATIC] issue-reviewer skill → returns status
  ├─ IF status == failure
  │  └─ phase marked for manual review (REQUIRES_REVIEW)
  ├─ ELSE
  │  ├─ actual evaluate phase steps
  │  ├─ tests
  │  └─ manual review (if configured)
  └─ ...continue to release
```

---

## Specification Template Requirements

### Code Changes Requirement
The skill must verify that:
- **Spec requirement**: "Code changes must implement stated requirements"
- **Evidence**: Modified files contain implementation code for each requirement
- **Success**: 100% of requirements have corresponding code changes

### Test Coverage Requirement
The skill must verify that:
- **Spec requirement**: "Tests validate implementation completeness"
- **Evidence**: Test files modified or added covering requirements
- **Success**: >= 80% code coverage for changed files

### Documentation Requirement
The skill must verify that:
- **Spec requirement**: "Documentation updated for completed work"
- **Evidence**: Spec file marked as completed, API docs updated if applicable
- **Success**: Spec status updated, user-facing docs updated

### Acceptance Criteria Requirement
The skill must verify that:
- **Spec requirement**: "All acceptance criteria from issue/spec are met"
- **Evidence**: Each acceptance criterion has corresponding implementation
- **Success**: 100% of acceptance criteria satisfied by code changes

---

## Acceptance Criteria

### AC-1: Skill Exists and Runs
- [ ] Skill file created: `plugins/faber/skills/issue-reviewer/SKILL.md`
- [ ] Workflow files created in `skills/issue-reviewer/workflow/`
- [ ] Scripts created in `skills/issue-reviewer/scripts/`
- [ ] Skill runs automatically at evaluate phase start

### AC-2: Context Gathering Works
- [ ] Fetches issue details via work plugin
- [ ] Fetches specifications via spec plugin
- [ ] Gathers code changes via repo plugin
- [ ] Handles missing context gracefully
- [ ] Works with issues that have no spec

### AC-3: Specification Analysis Works
- [ ] Parses requirements from spec
- [ ] Matches code changes to requirements
- [ ] Verifies acceptance criteria
- [ ] Generates requirement coverage report

### AC-4: Code Quality Analysis Works
- [ ] Identifies quality issues by severity
- [ ] Assesses test coverage
- [ ] Evaluates documentation
- [ ] Suggests improvements

### AC-5: Status Determination Works
- [ ] Returns "success" for complete, quality work
- [ ] Returns "warning" for complete work with minor issues
- [ ] Returns "failure" for incomplete or major-issue work
- [ ] Classification logic is clear and repeatable

### AC-6: Output Report Generated
- [ ] Saves analysis to local file: `.fractary/plugins/faber/reviews/{issue_number}-{timestamp}.md`
- [ ] Comments on GitHub issue with summary
- [ ] Includes model used and timestamp
- [ ] Report is clear and actionable

### AC-7: FABER Integration Works
- [ ] Skill receives work_id from FABER state
- [ ] Failure status blocks release or requires review
- [ ] Warning status allows continuation with logging
- [ ] Success status allows normal workflow

### AC-8: Model Specification
- [ ] Uses claude-opus-4-5 for analysis
- [ ] Handles model unavailability gracefully
- [ ] All model calls are explicit and logged

### AC-9: Tests Pass
- [ ] Unit tests for each workflow step
- [ ] Integration test with FABER workflow
- [ ] Test with missing specification
- [ ] Test with large code changes
- [ ] Test with multi-phase specifications

### AC-10: Documentation Complete
- [ ] Skill documentation in SKILL.md
- [ ] Workflow documentation in each workflow file
- [ ] Configuration guide updated
- [ ] Examples provided
- [ ] Troubleshooting guide included

---

## Testing Strategy

### Unit Tests

**Test Suite 1: Context Gathering**
- [ ] Successfully fetch issue details
- [ ] Handle missing issue (error)
- [ ] Fetch specifications for issue
- [ ] Handle missing specs (graceful)
- [ ] Gather code changes (diff analysis)
- [ ] Handle large diffs (summarization)

**Test Suite 2: Specification Analysis**
- [ ] Parse requirements from spec
- [ ] Match code changes to requirements
- [ ] Calculate coverage percentage
- [ ] Identify gaps
- [ ] Handle missing spec section

**Test Suite 3: Code Quality Analysis**
- [ ] Identify quality issues
- [ ] Assess test coverage
- [ ] Evaluate documentation
- [ ] Suggest improvements

**Test Suite 4: Status Determination**
- [ ] Return "success" for complete work
- [ ] Return "warning" for minor issues
- [ ] Return "failure" for major issues
- [ ] Classification logic correctness

### Integration Tests

**Integration Test 1: Full Workflow**
- [ ] FABER calls issue-reviewer at evaluate phase start
- [ ] Skill receives work_id and branch
- [ ] Analysis completes successfully
- [ ] Report generated and commented

**Integration Test 2: Phase Handling**
- [ ] "failure" status blocks release
- [ ] "warning" status logs and continues
- [ ] "success" status allows normal flow

**Integration Test 3: Failure Scenarios**
- [ ] Handle network errors
- [ ] Handle missing issue
- [ ] Handle private repositories
- [ ] Graceful degradation

---

## Files to Modify/Create

### New Files to Create

```
plugins/faber/skills/issue-reviewer/
├── SKILL.md                              # Skill documentation
├── workflow/
│   ├── gather-context.md                # Step 1: Gather context
│   ├── analyze-specification.md          # Step 2: Analyze spec compliance
│   ├── analyze-quality.md                # Step 3: Analyze code quality
│   └── determine-status.md               # Step 4: Determine status
└── scripts/
    ├── gather-issue-context.sh          # Fetch issue + comments
    ├── gather-spec-context.sh           # Fetch specifications
    ├── gather-code-changes.sh           # Diff analysis
    ├── analyze-requirements.sh          # Spec compliance analysis
    ├── analyze-quality.sh               # Code quality analysis
    └── generate-report.sh               # Report formatting

tests/
├── issue-reviewer/
│   ├── gather-context.test.sh           # Context gathering tests
│   ├── specification-analysis.test.sh   # Spec analysis tests
│   ├── code-quality-analysis.test.sh    # Code quality tests
│   ├── status-determination.test.sh     # Status logic tests
│   └── integration.test.sh              # Full workflow tests
```

### Files to Modify

```
plugins/faber/agents/faber-manager.md
  - Add automatic skill invocation at evaluate phase start
  - Add status handling (failure → requires review)

plugins/faber/skills/skill-registry.json (or manifest)
  - Register issue-reviewer skill
  - Mark as automatic (runs without config)

plugins/faber/docs/CONFIGURATION.md
  - Document automatic invocation
  - Explain status codes

plugins/faber/docs/HOOKS.md
  - Document evaluate phase entry hook

.claude-plugin/plugin.json
  - Register skills directory if needed
```

---

## Dependencies

### Plugin Dependencies
- **fractary-work**: Work item fetching (issues, comments)
- **fractary-repo**: Code change analysis (diffs, PR details)
- **fractary-spec**: Specification fetching and parsing

### External Dependencies
- **claude-opus-4-5 model**: Required for analysis
- **Git**: For diff generation
- **GitHub API**: For issue, PR, and comment data

### Data Dependencies
- Issue #233 with description and requirements
- Related specifications (if exist)
- Code repository with branch history
- GitHub access token (for API calls)

---

## Success Metrics

1. **Correctness**: Issue-reviewer skill correctly identifies gaps in 95%+ of test cases
2. **Performance**: Analysis completes within 60 seconds for 95%+ of issues
3. **Integration**: Skill auto-invokes at evaluate phase start with 100% reliability
4. **Usability**: Generated reports are clear and actionable (measured by user feedback)
5. **Coverage**: Skill handles edge cases (missing spec, large changes, etc.)

---

## Future Enhancements

### Phase 2 Enhancements
- Interactive refinement mode (ask Claude to fix issues)
- Automated fixes for minor issues
- Custom review criteria per project
- Result webhooks for external systems

### Phase 3 Enhancements
- Machine learning model for issue classification
- Cross-issue pattern detection
- Team metrics and trends
- Predictive quality scoring

---

## Questions and Assumptions

### Assumptions
1. Issue #233 represents a real pain point in current workflow
2. claude-opus-4-5 will be available and performant for this use case
3. Specifications follow a consistent format (requirement + acceptance criteria)
4. Code changes are available via git diff
5. GitHub API will have necessary permissions

### Clarifications Needed
1. Should analysis be optional (configurable) or always automatic?
2. Should failure status block phase or only flag for review?
3. What's the maximum acceptable analysis time?
4. Should analysis be cached if issue hasn't changed?
5. Should report be visible only to faber-manager or also to user?

---

## Sign-Off

**Specification Status**: Ready for Implementation  
**Reviewed By**: Work Request #233  
**Approval**: Pending Code Review  
**Last Updated**: 2025-12-05  

