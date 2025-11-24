# Workflow: Deploy Migrations

This workflow describes the detailed steps for deploying database migrations to an environment.

## Overview

**Purpose**: Apply pending migrations safely to database with pre/post validation
**Safety**: Health checks, backups, approval workflows for production
**Modes**: Development (interactive) vs Production (non-interactive)

## Step 1: Validate Parameters

Check that required parameters are present:
- **environment** (required): Must be configured environment (dev, staging, production)
- **dry_run** (optional): Boolean for preview mode
- **skip_backup** (optional): Boolean to skip backup
- **skip_health_check** (optional): Boolean to skip health checks

If validation fails, return error response.

## Step 2: Set Working Directory Context

If `working_directory` parameter provided:
```bash
export CLAUDE_DB_CWD="<working_directory>"
```

## Step 3: Load Configuration

Load plugin configuration and get environment settings.

Extract:
- Database provider, hosting, migration tool
- Environment connection string variable
- Auto-migrate setting
- Backup requirements
- Approval requirements

## Step 4: Determine Migration Mode

Based on environment type:
- **Development environments** (dev, test): Use `dev` mode
- **Production environments** (staging, production): Use `deploy` mode

```bash
if [[ "$ENVIRONMENT" == "dev" || "$ENVIRONMENT" == "test" ]]; then
  MIGRATION_MODE="dev"
else
  MIGRATION_MODE="deploy"
fi
```

**Mode differences**:
- `dev`: Interactive, can generate migrations, can reset database
- `deploy`: Non-interactive, only applies committed migrations, fails on schema mismatch

## Step 5: Pre-Deployment Health Check

If `skip_health_check` is false (default):
1. Check database connectivity
2. Verify migration table exists
3. Check schema is valid
4. Verify database has sufficient disk space

If health check fails, stop and return error.

## Step 6: Create Backup (Production Only)

If environment requires backup (`backup_before_migrate: true`) and `skip_backup` is false:

1. Invoke backup-manager skill
2. Wait for backup completion
3. Store backup_id for potential rollback
4. If backup fails, stop and return error (unless --skip-backup)

**Skip for**:
- Development environments (backup not required)
- When explicitly skipped (--skip-backup flag)

## Step 7: Check Pending Migrations

Invoke migration tool handler to check migration status:
- Get list of pending migrations
- Get list of applied migrations
- Calculate number of migrations to apply

If no pending migrations:
- Log: "No pending migrations"
- Return success with migrations_applied: 0
- Exit

## Step 8: Preview Migrations (Dry-Run Mode)

If `dry_run` is true:
1. Get SQL for each pending migration
2. Calculate estimated duration
3. Format preview output
4. Return preview results
5. Exit (no changes applied)

**Preview includes**:
- Migration names and timestamps
- SQL statements to be executed
- Estimated duration per migration
- Total estimated duration

## Step 9: Production Approval Prompt

If environment is protected and requires approval:
1. Display migration summary
2. Show safeguards (backup, health checks, rollback capability)
3. Prompt user for confirmation
4. Wait for user input
5. If cancelled, return cancelled status and exit

**Example prompt**:
```
⚠️  PRODUCTION MIGRATION DEPLOYMENT

Environment: production
Pending Migrations: 2

Safeguards:
✓ Backup will be created automatically
✓ Health check will run before deployment
✓ Post-deployment validation enabled
✓ Rollback capability available

Proceed? (yes/no):
```

## Step 10: Deploy Migrations

Invoke migration tool handler to apply migrations:

**For Prisma**:
```json
{
  "skill": "handler-db-prisma",
  "operation": "apply-migration",
  "parameters": {
    "environment": "production",
    "mode": "deploy",
    "database_url_env": "PROD_DATABASE_URL",
    "working_directory": "/path/to/project"
  }
}
```

Handler applies migrations in order and returns:
- List of migrations applied
- Duration per migration
- Success/failure status

**If migration fails**:
- Stop immediately (don't apply remaining migrations)
- Log failure details
- Trigger automatic rollback (if configured)
- Return error with recovery steps

## Step 11: Post-Deployment Health Check

If `skip_health_check` is false:
1. Check database connectivity
2. Verify all migrations applied
3. Check for schema drift
4. Verify application can connect

If health check fails:
- Trigger automatic rollback (if configured)
- Log failure details
- Return error with rollback info

## Step 12: Verify All Migrations Applied

Query migration table to verify:
1. All expected migrations are in migration history
2. No migrations failed mid-application
3. Migration table is consistent

If verification fails:
- Log inconsistency
- Suggest manual verification
- May trigger rollback depending on issue

## Step 13: Log Operation

If logs plugin is configured:
```json
{
  "log_type": "database_operation",
  "operation": "deploy-migrations",
  "environment": "production",
  "migrations_applied": 2,
  "duration_seconds": 2.3,
  "backup_id": "backup-20250124-103000",
  "status": "success",
  "timestamp": "2025-01-24T10:30:00Z"
}
```

## Step 14: Return Success Response

Return structured JSON with:
- Status: success
- Migrations applied (count and list)
- Duration
- Backup ID (if created)
- Health check results
- Next steps suggestions

## Error Recovery

At each step, if error occurs:

### Pre-Deployment Failure
- No changes made to database
- Safe to retry after fixing issue
- No rollback needed

### Mid-Deployment Failure
- Some migrations may have applied
- Automatic rollback initiated (if configured and backup exists)
- Return error with:
  - Which migration failed
  - Backup ID for manual rollback
  - Suggestions for recovery

### Post-Deployment Failure
- All migrations applied but validation failed
- May trigger automatic rollback
- Return error with health check details
- Suggest monitoring and potential rollback

## Automatic Rollback Logic

When to trigger automatic rollback:
1. Migration fails during application
2. Post-deployment health check fails
3. Configuration setting `rollback_on_health_check_failure: true`
4. Backup exists from pre-deployment

**Rollback process**:
1. Invoke rollback-manager skill
2. Restore from backup (backup_id)
3. Verify restoration successful
4. Return error with rollback confirmation

**When NOT to rollback automatically**:
- No backup available
- Rollback disabled in configuration
- Pre-deployment failure (nothing to rollback)

## Example Execution Flow

### Success Case (Production)

```
Input:
  environment: production
  dry_run: false
  skip_backup: false
  skip_health_check: false

Steps:
  1. ✓ Parameters validated
  2. ✓ Working directory set
  3. ✓ Configuration loaded
  4. ✓ Migration mode: deploy (production)
  5. ✓ Pre-deployment health check: passed
  6. ✓ Backup created: backup-20250124-103000
  7. ✓ Pending migrations: 2 found
  8. ✗ Skip preview (not dry-run)
  9. ✓ Approval confirmed by user
  10. ✓ Migrations applied:
      - 20250124140000_add_user_profiles (1.2s) ✓
      - 20250124150000_add_posts (0.8s) ✓
  11. ✓ Post-deployment health check: passed
  12. ✓ Verification: All 2 migrations applied
  13. ✓ Operation logged
  14. ✓ Success response returned

Output:
  {
    "status": "success",
    "migrations_applied": 2,
    "duration_seconds": 2.3,
    "backup_id": "backup-20250124-103000"
  }
```

### Preview Case (Dry-Run)

```
Input:
  environment: production
  dry_run: true

Steps:
  1-7. (same as above through checking pending migrations)
  8. ✓ Preview mode: Show migration SQL
     - 20250124140000_add_user_profiles
       CREATE TABLE "UserProfile" (...)
     - 20250124150000_add_posts
       CREATE TABLE "Post" (...)
  9-14. ✗ Skip (dry-run exits after preview)

Output:
  {
    "status": "success",
    "operation": "preview-migrations",
    "pending_migrations": 2,
    "migrations": [...],
    "estimated_duration": 2.5
  }
```

### Failure Case (Migration Error)

```
Input:
  environment: production
  dry_run: false

Steps:
  1-9. (same as success case through approval)
  10. ✗ Migration failed:
      - 20250124140000_add_user_profiles: FAILED (duplicate column "email")
      - 20250124150000_add_posts: NOT ATTEMPTED
  11. ✓ Automatic rollback initiated
      - Restore from backup-20250124-103000
      - Rollback successful
  12-14. ✗ Skip (early exit on failure)

Output:
  {
    "status": "error",
    "error": "Migration failed: duplicate column name",
    "failed_migration": "20250124140000_add_user_profiles",
    "backup_id": "backup-20250124-103000",
    "rollback_status": "success",
    "recovery": {
      "suggestions": [...]
    }
  }
```

## Migration Modes Detailed

### Development Mode (`migrate dev`)

**When**: Development and test environments

**Behavior**:
- Interactive prompts allowed
- Can generate new migrations if schema changed
- Can reset database if needed
- Immediately applies migrations
- Updates Prisma Client automatically

**Command**: `npx prisma migrate dev`

**Use cases**:
- Local development
- Testing migrations
- Rapid iteration

### Production Mode (`migrate deploy`)

**When**: Staging and production environments

**Behavior**:
- Non-interactive (no prompts)
- Only applies existing migrations from git
- Fails if schema doesn't match migrations
- Requires migrations to be committed
- Does not generate Prisma Client

**Command**: `npx prisma migrate deploy`

**Use cases**:
- CI/CD pipelines
- Production deployments
- Staging deployments

## Safety Checks Summary

**Before Deployment**:
- ✓ Configuration valid
- ✓ Environment configured
- ✓ Connection string set
- ✓ Database exists
- ✓ Database healthy
- ✓ Backup created (production)
- ✓ Approval confirmed (production)

**During Deployment**:
- ✓ Migrations applied in order
- ✓ Each migration tracked
- ✓ Failures caught immediately

**After Deployment**:
- ✓ Database still healthy
- ✓ All migrations verified
- ✓ No schema drift
- ✓ Operation logged

**On Failure**:
- ✓ Automatic rollback (if configured)
- ✓ Error details logged
- ✓ Recovery steps provided
- ✓ Backup preserved for manual rollback
