# Eliminating Wrapper Commands with Hooks

This guide demonstrates how the unified hook system eliminates the need for project-specific wrapper commands.

## The Problem: Wrapper Command Pattern

### Before Hooks (Old Pattern)

Many projects create lightweight wrapper commands to inject project-specific context:

**File**: `.claude/commands/build-feature.md`
```markdown
---
description: Build a feature following our project standards
---

Use the @agent-fractary-faber:workflow-manager agent to execute the FABER workflow for the given work item.

## Project Context

Follow these project-specific standards:

### Architecture Standards
- Use microservices pattern with clear service boundaries
- All services communicate via REST APIs
- Use PostgreSQL for persistence
- Use Redis for caching and sessions

### Coding Standards
- TypeScript with strict mode enabled
- ESLint configuration in `.eslintrc.js`
- Prettier for code formatting
- Jest for testing with 80% coverage minimum

### Testing Requirements
- Unit tests required for all business logic
- Integration tests required for API endpoints
- E2E tests required for critical user flows
- All tests must pass before release

### Release Process
- Follow semantic versioning
- Update CHANGELOG.md with all changes
- Ensure database migrations are backward compatible
- Update API documentation if endpoints changed

Now process work item: {issue_id}
```

**Problems with this approach**:
- ❌ **Duplication**: Standards documented in code AND in docs
- ❌ **Maintenance**: Must update command when standards change
- ❌ **Not reusable**: Each project needs its own wrapper
- ❌ **No selectivity**: All context included every time
- ❌ **Hard to test**: Command logic mixed with context

### After Hooks (New Pattern)

With hooks, the same customization is configuration-driven:

**File**: `.faber.config.toml`
```toml
[project]
name = "my-project"

# Architecture guidance for architect phase
[[hooks.architect.pre]]
type = "context"
name = "architecture-standards"
references = [
  { path = "docs/ARCHITECTURE.md", description = "Architecture standards" }
]

# Coding standards for build phase
[[hooks.build.pre]]
type = "context"
name = "coding-standards"
references = [
  { path = "docs/CODING_STANDARDS.md", description = "Coding standards" }
]

# Testing requirements for evaluate phase
[[hooks.evaluate.pre]]
type = "context"
name = "testing-requirements"
references = [
  { path = "docs/TESTING_GUIDE.md", description = "Testing requirements" }
]

# Release process for release phase
[[hooks.release.pre]]
type = "context"
name = "release-process"
references = [
  { path = "docs/RELEASE_PROCESS.md", description = "Release process" }
]
```

**Benefits**:
- ✅ **Single source of truth**: Standards in docs, referenced via config
- ✅ **Easy maintenance**: Update docs, config stays the same
- ✅ **Reusable**: Use standard `/faber` command
- ✅ **Selective**: Right context at right time (phase-specific)
- ✅ **Testable**: Pure configuration, no code

## Real-World Examples

### Example 1: E-commerce Application

#### Before: Wrapper Command

**File**: `.claude/commands/ecom-build.md`
```markdown
---
description: Build e-commerce feature
---

Build this feature following our e-commerce platform standards:

**Architecture**:
- Microservices: product-service, order-service, payment-service, user-service
- Message bus: RabbitMQ for async operations
- Databases: PostgreSQL for transactional data, MongoDB for product catalog
- Cache: Redis for cart and session management

**Payment Processing**:
- Use Stripe API (keys in environment variables)
- All payment operations must be idempotent
- Log all payment events to audit table
- Implement retry logic with exponential backoff

**Inventory Management**:
- Check inventory before order placement
- Reserve inventory during checkout (15-minute timeout)
- Handle race conditions with pessimistic locking

**Testing Requirements**:
- Mock all external API calls (Stripe, shipping providers)
- Test inventory race conditions
- Test payment failure scenarios
- E2E tests for complete purchase flow

Work item: {issue_id}
```

#### After: Hook Configuration

**File**: `.faber.config.toml`
```toml
# Architecture context (Architect phase)
[[hooks.architect.pre]]
type = "context"
name = "ecom-architecture"
prompt = "Design the solution following our e-commerce microservices architecture."
references = [
  { path = "docs/architecture/MICROSERVICES.md", description = "Microservices architecture" },
  { path = "docs/architecture/DATA_LAYER.md", description = "Database and cache patterns" },
  { path = "docs/architecture/MESSAGE_BUS.md", description = "Async messaging patterns" }
]
weight = "high"

# Domain-specific guidance (Architect phase)
[[hooks.architect.pre]]
type = "context"
name = "ecom-domains"
prompt = "Follow our domain-specific patterns for payments and inventory."
references = [
  {
    path = "docs/domains/PAYMENT_PROCESSING.md",
    description = "Payment processing patterns",
    sections = ["Idempotency", "Error Handling", "Audit Logging"]
  },
  {
    path = "docs/domains/INVENTORY_MANAGEMENT.md",
    description = "Inventory management patterns",
    sections = ["Reservation", "Concurrency Control"]
  }
]
weight = "high"

# Testing requirements (Evaluate phase)
[[hooks.evaluate.pre]]
type = "context"
name = "ecom-testing"
prompt = "Ensure comprehensive testing of payment and inventory flows."
references = [
  {
    path = "docs/testing/EXTERNAL_API_MOCKING.md",
    description = "External API mocking patterns"
  },
  {
    path = "docs/testing/ECOM_TEST_SCENARIOS.md",
    description = "E-commerce test scenarios",
    sections = ["Payment Flows", "Inventory Scenarios", "Race Conditions"]
  }
]
weight = "high"
```

**Usage**: Just run `/faber run 123` - context is automatically injected at the right phases!

### Example 2: Multi-Environment Infrastructure

#### Before: Multiple Wrapper Commands

**File**: `.claude/commands/deploy-dev.md`
```markdown
---
description: Deploy to dev environment
---

Deploy to **development** environment:
- AWS Profile: myapp-dev
- Region: us-west-2
- Environment: dev
- Auto-approve: yes
- Run smoke tests: no

Work item: {issue_id}
```

**File**: `.claude/commands/deploy-prod.md`
```markdown
---
description: Deploy to production
---

⚠️  PRODUCTION DEPLOYMENT ⚠️

Deploy to **production** environment:
- AWS Profile: myapp-prod
- Region: us-east-1
- Environment: prod
- Auto-approve: NO - require manual approval
- Run smoke tests: yes
- Requires: Database migration review, rollback plan

CRITICAL CHECKS:
- [ ] All tests pass in staging
- [ ] Database migrations are backward compatible
- [ ] Feature flags configured correctly
- [ ] Rollback plan documented
- [ ] Team notified in #deployments
- [ ] Scheduled during maintenance window

Work item: {issue_id}
```

#### After: Environment-Filtered Hooks

**File**: `.faber.config.toml`
```toml
# Standard release process (all environments)
[[hooks.release.pre]]
type = "context"
name = "release-standards"
references = [
  { path = "docs/RELEASE_CHECKLIST.md", description = "Release checklist" }
]

# Production-only critical warnings
[[hooks.release.pre]]
type = "prompt"
name = "production-warning"
content = """
⚠️  PRODUCTION DEPLOYMENT ⚠️

CRITICAL CHECKS REQUIRED:
✓ All tests pass in staging
✓ Database migrations reviewed and backward compatible
✓ Feature flags configured correctly
✓ Rollback plan documented
✓ Team notified in #deployments channel
✓ Deployment scheduled during maintenance window

Do not proceed until ALL items confirmed.
"""
weight = "critical"
environments = ["prod"]  # Only for production!

# Production-only validation
[[hooks.release.post]]
type = "skill"
name = "smoke-test-runner"
description = "Run smoke tests against production"
required = true
failureMode = "stop"
timeout = 600
environments = ["prod"]  # Only for production!
```

**Usage**:
- Dev: `/faber run 123 --env dev` → No extra warnings
- Prod: `/faber run 123 --env prod` → Shows critical warnings and runs smoke tests

### Example 3: Data Pipeline Project

#### Before: Wrapper Command

**File**: `.claude/commands/build-pipeline.md`
```markdown
---
description: Build data pipeline feature
---

Build this data pipeline feature following our standards:

**Data Architecture**:
- Data Lake: S3 with partitioned Parquet files
- Data Warehouse: Redshift for analytics
- Stream Processing: Apache Kafka + Flink
- Orchestration: Apache Airflow

**Data Quality**:
- Validate schema on ingestion
- Check data quality rules (completeness, accuracy, consistency)
- Log all validation failures to monitoring system
- Alert on quality threshold breaches

**Performance Requirements**:
- Batch jobs must complete within 4-hour window
- Streaming jobs must process within 1-minute latency
- Data warehouse queries must complete within 30 seconds

**Testing Requirements**:
- Unit tests for transformation logic
- Integration tests with sample datasets
- Performance tests with production-scale data
- Data quality validation tests

Work item: {issue_id}
```

#### After: Hook Configuration

**File**: `.faber.config.toml`
```toml
# Data architecture (Architect phase)
[[hooks.architect.pre]]
type = "context"
name = "data-architecture"
prompt = "Design the pipeline following our data platform architecture."
references = [
  { path = "docs/data/ARCHITECTURE.md", description = "Data platform architecture" },
  { path = "docs/data/STORAGE_PATTERNS.md", description = "Data storage patterns" },
  { path = "docs/data/ORCHESTRATION.md", description = "Pipeline orchestration" }
]
weight = "high"

# Data quality requirements (Architect phase)
[[hooks.architect.pre]]
type = "context"
name = "data-quality"
prompt = "Implement data quality checks following our standards."
references = [
  {
    path = "docs/data/DATA_QUALITY.md",
    description = "Data quality standards",
    sections = ["Validation Rules", "Monitoring", "Alerting"]
  }
]
weight = "high"

# Performance requirements (Architect phase)
[[hooks.architect.pre]]
type = "prompt"
name = "performance-requirements"
content = """
Performance Requirements:
- Batch Processing: Complete within 4-hour window
- Streaming Processing: < 1 minute end-to-end latency
- Data Warehouse Queries: < 30 seconds for 95th percentile
- Data Quality Checks: < 5% overhead on throughput
"""
weight = "high"

# Data testing requirements (Evaluate phase)
[[hooks.evaluate.pre]]
type = "context"
name = "data-testing"
prompt = "Ensure comprehensive testing with production-scale datasets."
references = [
  {
    path = "docs/data/TESTING_GUIDE.md",
    description = "Data pipeline testing guide",
    sections = ["Unit Testing", "Integration Testing", "Performance Testing", "Data Quality Testing"]
  }
]
weight = "high"

# Performance validation (Evaluate phase)
[[hooks.evaluate.post]]
type = "skill"
name = "performance-validator"
description = "Validate pipeline performance meets requirements"
required = true
failureMode = "stop"
timeout = 1800
```

**Usage**: `/faber run 123` - data-specific context injected automatically!

## Migration Guide

### Step 1: Identify Wrapper Command Context

Review your wrapper commands and identify:
- **Architecture guidance** → `hooks.architect.pre` with type "context"
- **Technology constraints** → `hooks.architect.pre` with type "prompt"
- **Coding standards** → `hooks.build.pre` with type "context"
- **Testing requirements** → `hooks.evaluate.pre` with type "context"
- **Release procedures** → `hooks.release.pre` with type "context"
- **Environment warnings** → `hooks.*.pre` with type "prompt" and `environments` filter

### Step 2: Extract Context to Documentation

If context isn't already in docs:
1. Create documentation files (e.g., `docs/ARCHITECTURE.md`)
2. Move standards/patterns from wrapper command to docs
3. Keep docs as single source of truth

### Step 3: Configure Hooks

Create `.faber.config.toml` and add hooks:
```toml
[[hooks.<phase>.<timing>]]
type = "context" | "prompt"
name = "descriptive-name"
# For context hooks:
references = [{ path = "docs/FILE.md", description = "..." }]
# For prompt hooks:
content = "..."
```

### Step 4: Test Configuration

```bash
# Test with dry-run mode
/faber run 123 --autonomy dry-run

# Verify hooks are executed
# Check context is injected at right phases
```

### Step 5: Remove Wrapper Command

Once hooks work correctly:
```bash
# Remove old wrapper command
rm .claude/commands/old-wrapper.md

# Use standard command
/faber run 123
```

## Best Practices

### 1. Use Context Hooks for Documentation

**Do**:
```toml
[[hooks.build.pre]]
type = "context"
references = [{ path = "docs/CODING_STANDARDS.md", description = "..." }]
```

**Don't**:
```toml
[[hooks.build.pre]]
type = "prompt"
content = """
[... paste entire coding standards document ...]
"""
```

**Why**: Context hooks reference living documentation; prompt hooks are for short reminders.

### 2. Use Prompt Hooks for Environment-Specific Warnings

**Do**:
```toml
[[hooks.release.pre]]
type = "prompt"
content = "⚠️  PRODUCTION DEPLOYMENT - Extra caution required"
weight = "critical"
environments = ["prod"]
```

**Why**: Short, urgent messages that should always be visible.

### 3. Extract Documentation Sections

**Do**:
```toml
[[hooks.architect.pre]]
type = "context"
references = [
  {
    path = "docs/ARCHITECTURE.md",
    sections = ["API Design", "Database Patterns"]  # Only relevant sections
  }
]
```

**Why**: Reduces context usage, focuses attention on relevant content.

### 4. Use Weight Appropriately

**Critical**: Must never be ignored (production warnings)
**High**: Important standards (architecture, security)
**Medium**: Standard guidance (default)
**Low**: Nice-to-have context (may be pruned if context budget tight)

### 5. Organize Hooks by Phase

Match hook timing to when context is needed:
- **frame.pre**: Work classification, environment setup
- **architect.pre**: Architecture, design standards, technology constraints
- **build.pre**: Coding standards, testing patterns, build requirements
- **evaluate.pre**: Quality gates, testing requirements
- **release.pre**: Release checklist, deployment procedures, warnings

## Troubleshooting

### "Context hook not showing in output"

**Check**:
1. Hook weight (low-weight hooks may be pruned)
2. Environment filter (hook may not apply to current environment)
3. File path in references (must be relative to project root)

### "Prompt hook seems ignored"

**Check**:
1. Weight setting (use "high" or "critical" for important prompts)
2. Environment filter
3. Hook is in correct phase (e.g., architect.pre, not architect.post)

### "Too much context in prompt"

**Solution**:
1. Use `sections` to extract only relevant parts of docs
2. Lower weight of less critical hooks
3. Split large docs into smaller, focused files
4. Use prompt hooks for summaries, context hooks for details

### "Hook not executing"

**Check**:
1. TOML syntax (use `[[hooks.phase.timing]]` for arrays)
2. Required fields (type, name, and type-specific fields)
3. File paths (must exist and be readable)
4. Hook configuration loaded (check with `/faber:config` or similar)

## Summary

The unified hook system eliminates wrapper commands by making baseline plugins fully customizable via configuration:

**Before**: Wrapper command → Inline context → Standard agent
**After**: Standard command → Hook configuration → Context injection → Standard agent

**Benefits**:
- ✅ No duplicate code
- ✅ Single source of truth (docs)
- ✅ Easy maintenance
- ✅ Phase-specific context
- ✅ Environment-specific behavior
- ✅ Reusable across projects

**Next Steps**:
1. Review your wrapper commands
2. Extract context to documentation
3. Configure hooks in `.faber.config.toml`
4. Test with dry-run mode
5. Remove wrapper commands
