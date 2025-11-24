# FABER-DB Workflow Integration

This directory contains FABER workflow configurations with FABER-DB integration examples.

## Available Workflows

### `faber-db-integrated.json`

Complete FABER workflow with database management integration at all phases.

**Use this workflow when**:
- Work involves database schema changes
- Migrations need to be generated and deployed
- Database health validation is required
- Production database deployment needed

## How to Use

### 1. Copy Workflow to Your Project

```bash
# Copy to your project's FABER workflows directory
cp plugins/faber-db/config/workflows/faber-db-integrated.json \
   .fractary/plugins/faber/workflows/database.json
```

### 2. Reference in FABER Config

Update `.fractary/plugins/faber/config.json`:

```json
{
  "workflows": [
    {
      "id": "default",
      "file": "./workflows/default.json",
      "description": "Standard FABER workflow"
    },
    {
      "id": "database",
      "file": "./workflows/database.json",
      "description": "Database-focused FABER workflow with migration management"
    }
  ],
  "workflow_inference": {
    "label_mapping": {
      "database": "database",
      "db": "database",
      "schema": "database",
      "migration": "database"
    }
  }
}
```

### 3. Run FABER with Database Workflow

```bash
# Explicitly specify workflow
/faber run 123 --workflow database

# Or use label-based inference (if issue has "database" label)
/faber run 123
```

## Workflow Phases

### Frame Phase (Post-Frame Hook)

**Hook**: `post_frame`
**Coordinator Operation**: `detect-database-needs`

Automatically detects if the work item requires database changes by analyzing:
- Title keywords (table, schema, migration, database)
- Issue labels (database, db, migration)
- Description content

**Output**:
```
Database Work Detected: YES
Indicators:
  • Title mentions: "table"
  • Labels include: "database"

Recommendations:
  1. Generate specification with database schema
  2. Migration will be generated automatically after architect phase
```

### Architect Phase (Post-Architect Hook)

**Hook**: `post_architect`
**Coordinator Operation**: `coordinate-architect`

Generates database migrations from the specification if database schema is included.

**Actions**:
1. Parses specification for database schema
2. Invokes `migration-generator` skill
3. Creates migration file
4. Validates migration syntax

**Output**:
```
Migration Generated: 20250124160000_add_user_profiles
File: prisma/migrations/20250124160000_add_user_profiles/migration.sql
Status: Ready for dev deployment
```

### Build Phase (Pre-Build Hook)

**Hook**: `pre_build`
**Coordinator Operation**: `coordinate-build`

Applies migrations to the development environment before implementation begins.

**Actions**:
1. Checks for pending migrations
2. Invokes `migration-deployer` for dev
3. Applies migrations automatically
4. Runs health check
5. Verifies database ready

**Output**:
```
Environment: dev
Migrations Applied: 1 new migration
Health Status: Healthy
Database ready for implementation
```

### Evaluate Phase (Pre-Evaluate Hook)

**Hook**: `pre_evaluate`
**Coordinator Operation**: `coordinate-evaluate`

Deploys migrations to staging and validates health before testing.

**Actions**:
1. Invokes `migration-deployer` for staging
2. Applies migrations with safety checks
3. Runs comprehensive health check
4. Validates schema integrity

**Output**:
```
Environment: staging
Migrations Deployed: 1 migration
Health Status: Healthy
  - Connectivity: 28ms
  - Migrations: 25 applied, 0 pending
  - Schema: No drift

Ready for testing
```

### Release Phase (Pre-Release Hook)

**Hook**: `pre_release`
**Coordinator Operation**: `coordinate-release`

Production deployment with complete safety validation.

**Actions**:
1. Creates production backup
2. Analyzes migration safety
3. Deploys migrations (requires approval)
4. Runs post-deployment health check
5. Verifies production database healthy

**Output**:
```
Backup: backup-20250124-160000 ✅
Safety Analysis: MEDIUM risk (DROP COLUMN)
Deployment: Requires approval ⚠️

[User approval]

Deployment: SUCCESS ✅
Health Status: Healthy
Production database updated successfully
```

## Integration Architecture

```
FABER Workflow
   ↓
Phase Hooks
   ↓
faber-coordinator (Phase 8 - THIS!)
   ↓
FABER-DB Skills
   ├─ migration-generator (Phase 4)
   ├─ migration-deployer (Phase 4)
   ├─ backup-manager (Phase 5)
   ├─ safety-validator (Phase 6)
   └─ health-checker (Phase 7)
   ↓
Prisma Handler (Phase 3)
   ↓
Database Operations
```

## Safety Guarantees

### Development Environment
- ✅ Automatic migration application
- ✅ Health check after deployment
- ⚠️ No backup required (dev data)

### Staging Environment
- ✅ Manual migration deployment
- ✅ Health check before/after
- ✅ Safety validation
- ⚠️ Backup recommended

### Production Environment
- ✅ Manual migration deployment
- ✅ Automatic backup before deployment
- ✅ Comprehensive safety validation
- ✅ Health check before/after
- ✅ User approval required
- ✅ Rollback capability available

## Configuration

### FABER-DB Integration Settings

`.fractary/plugins/faber-db/config.json`:

```json
{
  "faber_integration": {
    "enabled": true,
    "auto_detect_database_work": true,
    "auto_generate_migrations": true,
    "auto_deploy_dev": true,
    "environments": {
      "dev": {
        "auto_migrate": true,
        "health_check_after": true
      },
      "staging": {
        "auto_migrate": false,
        "require_approval": true,
        "health_check_before": true,
        "health_check_after": true
      },
      "production": {
        "auto_migrate": false,
        "require_approval": true,
        "require_backup": true,
        "validate_safety": true,
        "health_check_before": true,
        "health_check_after": true
      }
    }
  }
}
```

## Autonomy Levels

### Dry-Run
```bash
/faber run 123 --workflow database --autonomy dry-run
```
- Detects database needs
- Reports what would be done
- No actual database operations

### Assist
```bash
/faber run 123 --workflow database --autonomy assist
```
- Auto-deploys to dev
- Manual approval for staging
- Stops before production release

### Guarded (Recommended)
```bash
/faber run 123 --workflow database --autonomy guarded
```
- Auto-deploys through staging
- Pauses before production release
- User approval for release phase

### Autonomous (Use with Caution)
```bash
/faber run 123 --workflow database --autonomy autonomous
```
- Fully automatic
- Only for trusted environments
- Production safety still enforced

## Examples

### Example 1: New Feature with Database Changes

**Issue #123**: "Add user profiles table"

```bash
# Run FABER with database workflow
/faber run 123 --workflow database --autonomy guarded
```

**Workflow**:
1. **Frame**: Detects "table" in title → Database work detected
2. **Architect**: Generates spec with schema → Migration created
3. **Build**: Applies to dev → Implementation proceeds
4. **Evaluate**: Deploys to staging → Tests run
5. **Release**: [Pauses for approval]
   - User reviews changes
   - Approves production deployment
   - Backup created → Migration deployed → Health validated

### Example 2: Schema Change (Destructive)

**Issue #456**: "Remove deprecated user columns"

```bash
/faber run 456 --workflow database --autonomy guarded
```

**Workflow**:
1. **Frame**: Database work detected
2. **Architect**: Migration with DROP COLUMN
3. **Build**: Applied to dev
4. **Evaluate**: Deployed to staging, validated
5. **Release**: [Pauses for approval]
   - Safety validator: HIGH RISK (DROP COLUMN)
   - Enhanced approval prompt shown
   - Backup created automatically
   - User confirms → Migration deployed

### Example 3: Performance Optimization (Non-Destructive)

**Issue #789**: "Add indexes for faster queries"

```bash
/faber run 789 --workflow database --autonomy guarded
```

**Workflow**:
1. **Frame**: Database work detected
2. **Architect**: Migration with CREATE INDEX
3. **Build**: Applied to dev
4. **Evaluate**: Deployed to staging, performance validated
5. **Release**: [Pauses for approval]
   - Safety validator: LOW RISK (CREATE INDEX)
   - Standard approval
   - Quick deployment

## Troubleshooting

### Database Not Detected

If FABER-DB doesn't detect database work:

1. Add "database" label to issue
2. Include database keywords in title/description
3. Manually specify workflow: `--workflow database`

### Migration Generation Fails

```
Error: Migration generation failed
```

**Solutions**:
1. Verify specification includes database schema
2. Check Prisma schema syntax
3. Generate manually: `/faber-db:generate-migration "description"`

### Health Check Fails

```
Health Status: DEGRADED
Issue: Schema drift detected
```

**Solutions**:
1. Review drift details: `/faber-db:health-check staging`
2. Sync schema: `npx prisma db pull`
3. Create migration: `/faber-db:generate-migration "sync schema"`

### Production Deployment Blocked

```
Error: Production health check failed
```

**Solutions**:
1. Run manual health check: `/faber-db:health-check production`
2. Fix connectivity issues
3. Resolve migration conflicts
4. Try again after fixes

## Best Practices

1. **Always use guarded mode** for database workflows
2. **Review migrations** before production deployment
3. **Test thoroughly** in staging
4. **Monitor health checks** at each phase
5. **Keep backups** for production
6. **Document schema changes** in PR descriptions
7. **Use descriptive migration names**
8. **Validate safety** for destructive operations

## See Also

- [FABER-DB Plugin README](../../docs/README.md)
- [FABER Configuration Guide](../../../faber/docs/CONFIGURATION.md)
- [Phase 8 Implementation Summary](../../../../specs/WORK-00170-phase-8-summary.md)
