---
model: claude-haiku-4-5
---

Rollback database to a previous state using a backup.

This command restores a database from a backup, effectively rolling back migrations and data changes. Since Prisma doesn't support down migrations natively, rollback works by restoring from a database backup.

## Usage

```bash
/faber-db:rollback <environment> [options]
```

## Arguments

- `<environment>` (required): Environment name (dev, staging, production)

## Options

- `--from <backup-id>`: Specific backup to restore from (default: latest)
- `--to <migration>`: Rollback to specific migration state
- `--dry-run`: Preview what would be rolled back without making changes
- `--force`: Skip confirmation prompts (use with caution)
- `--verify`: Run verification after rollback

## What It Does

1. **Validates environment**
   - Checks environment is configured
   - Verifies rollback is allowed for environment
   - Validates backup exists

2. **Identifies rollback target**
   - Finds appropriate backup (latest or specified)
   - Determines migration state at backup time
   - Calculates migrations to rollback

3. **Pre-rollback safety**
   - Creates safety backup of current state
   - Displays changes that will be made
   - Prompts for confirmation (production)

4. **Performs rollback**
   - Drops current database (or replaces data)
   - Restores from backup file
   - Updates migration table state
   - Regenerates Prisma Client

5. **Post-rollback verification**
   - Verifies database is accessible
   - Checks migration state matches expected
   - Validates schema integrity
   - Tests basic queries

6. **Reports results**
   - Migrations rolled back
   - Database state after rollback
   - Data loss warnings
   - Next steps

## Examples

### Rollback to Latest Backup

```bash
/faber-db:rollback dev
```

Output:
```
═══════════════════════════════════════
  FABER-DB: Database Rollback
═══════════════════════════════════════

Environment: dev
Database: myapp_dev

Step 1: Loading Configuration
✓ Configuration loaded
✓ Environment validated: dev
✓ Rollback allowed for environment

Step 2: Identifying Rollback Target
Looking for latest backup...
✓ Found backup: backup-20250124-140000
  Created: 2025-01-24 14:00:00
  Size: 2.3 MB
  Migrations: 5 applied
  Last migration: 20250124120000_add_user_profiles

Current database state:
  Migrations: 7 applied
  Last migration: 20250124160000_add_api_endpoints

Rollback will:
  ✓ Restore database to backup-20250124-140000 state
  ⚠️  Remove 2 migrations:
      - 20250124150000_add_comments
      - 20250124160000_add_api_endpoints
  ⚠️  Data loss: Any data changes since backup will be lost

Step 3: Pre-Rollback Safety
Creating safety backup of current state...
✓ Safety backup created: backup-20250124-170000-pre-rollback

Proceed with rollback? (yes/no): yes

Step 4: Performing Rollback
Restoring from backup...
✓ Dropping current database...
✓ Restoring schema from backup...
✓ Restoring data from backup...
✓ Updating migration table...
✓ Generating Prisma Client...

Step 5: Post-Rollback Verification
✓ Database connection: healthy
✓ Migration state: matches backup (5 migrations)
✓ Schema integrity: valid
✓ Test queries: passed

✅ COMPLETED: Database Rollback
Environment: dev
Backup Used: backup-20250124-140000
Migrations Rolled Back: 2
Current State: 5 migrations applied
Last Migration: 20250124120000_add_user_profiles

⚠️  Important Notes:
- All data changes since backup were lost
- Rolled back migrations can be reapplied: /faber-db:migrate dev
- Safety backup available: backup-20250124-170000-pre-rollback

Next steps:
  1. Verify application works with rolled-back schema
  2. If rollback was in error, restore from safety backup
  3. If intentional, fix migration issues and redeploy
```

### Rollback to Specific Backup

```bash
/faber-db:rollback production --from backup-20250123-100000
```

Output:
```
═══════════════════════════════════════
  ⚠️  PRODUCTION DATABASE ROLLBACK
═══════════════════════════════════════

Environment: production [PROTECTED]
Database: myapp_prod

Target Backup: backup-20250123-100000
  Created: 2025-01-23 10:00:00
  Label: pre-major-refactor
  Size: 12.1 GB
  Migrations: 20 applied
  Last migration: 20250123090000_add_user_verification

Current database state:
  Migrations: 24 applied
  Last migration: 20250124150000_refactor_complete

⚠️  CRITICAL: This will rollback 4 migrations

Migrations to be rolled back:
  1. 20250124150000_refactor_complete
  2. 20250124140000_migrate_user_data
  3. 20250124100000_drop_legacy_tables
  4. 20250123110000_add_new_indexes

⚠️  Data Loss Warning:
- All data changes since 2025-01-23 10:00:00 will be lost
- Affected tables: users, posts, comments, notifications
- Estimated data loss: ~5,000 new records

Safety measures:
✓ Safety backup will be created before rollback
✓ Post-rollback verification will run
✓ Safety backup retention: 90 days

This is a DESTRUCTIVE operation. Type 'rollback-production' to confirm: rollback-production

Creating safety backup...
✓ Safety backup created: backup-20250124-170000-pre-rollback

Performing rollback...
[Restoration progress bar]
✓ Database restored from backup-20250123-100000

✅ COMPLETED: Production Rollback
Migrations Rolled Back: 4
Current State: 20 migrations applied

Safety backup: backup-20250124-170000-pre-rollback
Retention: 90 days

⚠️  POST-ROLLBACK ACTIONS REQUIRED:
1. Notify team of rollback
2. Redeploy application to match rolled-back schema
3. Investigate and fix migration issues
4. Monitor application for issues

To re-apply migrations:
  /faber-db:migrate production
```

### Preview Rollback (Dry-Run)

```bash
/faber-db:rollback staging --dry-run
```

Output:
```
═══════════════════════════════════════
  FABER-DB: Rollback Preview (Dry-Run)
═══════════════════════════════════════

Environment: staging
Database: myapp_staging

Latest backup: backup-20250124-130000
  Created: 2025-01-24 13:00:00
  Migrations: 6 applied
  Last migration: 20250124120000_add_user_profiles

Current state: 7 migrations applied

Rollback would:
  ✓ Restore from: backup-20250124-130000
  ⚠️  Remove 1 migration:
      - 20250124150000_add_comments
  ⚠️  Data changes since 13:00:00 would be lost

Affected tables:
  - comments (1,250 rows would be lost)
  - posts (23 rows modified since backup)

⚠️  This is a preview only. No changes have been made.

To perform this rollback:
  /faber-db:rollback staging
```

### Rollback to Specific Migration

```bash
/faber-db:rollback dev --to 20250124120000_add_user_profiles
```

Output:
```
Rolling back to migration: 20250124120000_add_user_profiles

Finding appropriate backup...
✓ Found backup with matching migration state: backup-20250124-140000

Proceeding with rollback using backup-20250124-140000...
```

## Rollback Strategy

Since Prisma doesn't support down migrations, rollback works by:

1. **Identify appropriate backup** with desired migration state
2. **Create safety backup** of current state (in case rollback is mistaken)
3. **Drop and restore database** from backup file
4. **Update migration table** to reflect rolled-back state
5. **Verify database** health and integrity

### Migration State Tracking

The `_prisma_migrations` table tracks applied migrations:
```sql
SELECT * FROM _prisma_migrations ORDER BY finished_at DESC;
```

During rollback:
1. Current migration state is saved
2. Database is restored from backup
3. Migration table reflects backup's migration state
4. Prisma Client is regenerated for new state

## Safety Features

### Automatic Safety Backup

Before every rollback, a safety backup is created:
```
✓ Safety backup created: backup-20250124-170000-pre-rollback
```

This allows you to undo a rollback if it was done in error:
```bash
/faber-db:restore dev --from backup-20250124-170000-pre-rollback
```

### Production Confirmation

Production rollbacks require typing the environment name:
```
Type 'rollback-production' to confirm: _
```

This prevents accidental production rollbacks.

### Data Loss Warnings

Clear warnings about data that will be lost:
```
⚠️  Data Loss Warning:
- All data changes since 2025-01-24 14:00:00 will be lost
- Affected tables: comments (1,250 rows)
- New records created: will be deleted
- Updated records: will revert to backup values
```

## Error Handling

### No Backup Available

```
✗ No backup available for rollback

Cannot rollback without a backup.

Solutions:
1. Check available backups: /faber-db:list-backups dev
2. If no backups exist, rollback is not possible
3. For Prisma projects, create backups regularly: /faber-db:backup dev
4. Future: Consider migration tools with down migrations (TypeORM, Sequelize)
```

### Backup Not Found

```
✗ Backup not found: backup-20250124-140000

Available backups:
  - backup-20250124-150000 (latest)
  - backup-20250123-100000
  - backup-20250122-090000

Use one of the available backups:
  /faber-db:rollback dev --from backup-20250124-150000
```

### Restore Failed

```
✗ Database restore failed

Error: Syntax error in backup file at line 1523

This can happen if:
1. Backup file is corrupted
2. Backup file format doesn't match database version
3. Disk space ran out during restore

Recovery:
1. Try different backup: /faber-db:rollback dev --from <other-backup-id>
2. Check disk space: df -h
3. Verify backup integrity: /faber-db:verify-backup <backup-id>
4. If all backups fail, may need manual recovery
```

### Migration Table Mismatch

```
⚠️  Migration table state doesn't match backup

After restore, migration table shows:
  Expected: 5 migrations
  Found: 7 migrations

This usually means:
1. Backup file is out of sync with metadata
2. Migration table was manually modified
3. Backup was created during active migration

Actions:
1. Re-running restore with --force to override
2. Manually fix migration table if needed
3. Contact support if issue persists
```

## Rollback vs Restore

### Rollback
- Purpose: Undo migrations, return to previous schema state
- Uses: Latest backup (or specified backup)
- Creates: Safety backup before operation
- Updates: Migration table to reflect rolled-back state
- Common use: Migrations failed, need to undo changes

```bash
/faber-db:rollback production
```

### Restore
- Purpose: Recover from data corruption or loss
- Uses: Specific backup by ID
- Creates: Optional safety backup
- Updates: Entire database (schema + data)
- Common use: Data corruption, accidental deletion

```bash
/faber-db:restore production --from backup-20250124-140000
```

## Integration with Migration Workflow

### Automatic Rollback on Migration Failure

Configure automatic rollback:
```json
{
  "environments": {
    "production": {
      "rollback_on_migration_failure": true
    }
  }
}
```

When enabled:
```bash
/faber-db:migrate production

# If migration fails:
# ✗ Migration failed: 20250124150000_add_comments
# ✓ Automatic rollback initiated...
# ✓ Rolled back to: backup-20250124-140000-pre-migration
```

### Manual Rollback After Failed Deployment

```bash
# Migration deployment
/faber-db:migrate production

# If issues discovered later
/faber-db:rollback production --from backup-20250124-140000-pre-migration
```

## Alternative: Down Migrations (Future)

For tools that support down migrations (TypeORM, Sequelize):

```bash
# Rollback last migration
/faber-db:rollback dev --count 1

# Rollback to specific migration
/faber-db:rollback dev --to 20250124120000

# Uses down migration files instead of backup restore
```

This will be available when TypeORM/Sequelize handlers are implemented.

## Best Practices

### 1. Always Create Backups Before Major Changes

```bash
# Before risky migration
/faber-db:backup production --label "pre-major-refactor"

# Deploy migration
/faber-db:migrate production

# If issues, rollback
/faber-db:rollback production --from backup-*-pre-major-refactor
```

### 2. Test Rollback in Staging First

```bash
# Test rollback process in staging
/faber-db:rollback staging --dry-run

# Verify the process works
/faber-db:rollback staging

# Then safe to rollback production if needed
```

### 3. Coordinate with Application Deployment

When rolling back database:
```bash
# 1. Rollback database
/faber-db:rollback production

# 2. Rollback application deployment
git revert <commit>
git push

# 3. Redeploy application
# (Application now matches rolled-back schema)
```

### 4. Communicate with Team

Before production rollback:
```
1. Notify team in Slack/chat
2. Put application in maintenance mode
3. Perform rollback
4. Redeploy matching application version
5. Remove maintenance mode
6. Monitor for issues
```

### 5. Keep Safety Backups

Don't delete safety backups immediately:
```bash
# Safety backups are kept for 90 days (production)
# Don't delete manually unless certain rollback was correct
```

## Monitoring After Rollback

After rollback, monitor:

1. **Application Health**
   ```bash
   # Check application logs
   kubectl logs -f deployment/myapp

   # Monitor error rates
   # Check APM dashboards
   ```

2. **Database Health**
   ```bash
   /faber-db:status production

   # Check for schema drift
   # Verify migration state
   ```

3. **User Impact**
   - Monitor user reports
   - Check support tickets
   - Review analytics for anomalies

## Exit Codes

- **0**: Rollback successful
- **1**: Configuration or validation errors
- **2**: No backup available
- **3**: Backup not found
- **4**: Restore failed
- **5**: Post-rollback verification failed
- **6**: User cancelled operation

## See Also

Related commands:
- `/faber-db:backup` - Create database backup
- `/faber-db:restore` - Restore from backup
- `/faber-db:list-backups` - List available backups
- `/faber-db:migrate` - Deploy migrations

Documentation:
- `docs/README.md` - Plugin overview
- `docs/ROLLBACK-PROCEDURES.md` - Detailed rollback procedures
- `docs/BACKUP-GUIDE.md` - Backup strategies
- `docs/DISASTER-RECOVERY.md` - Recovery procedures
