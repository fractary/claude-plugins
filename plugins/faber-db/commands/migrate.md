Apply database migrations to an environment.

This command deploys pending migrations to the specified environment, with support for dry-run previews, automatic backups (production), and health checks before/after deployment.

## Usage

```bash
/faber-db:migrate <environment> [options]
```

## Arguments

- `<environment>` (required): Environment name (dev, staging, production)

## Options

- `--dry-run`: Preview migrations without applying them
- `--force`: Skip confirmation prompts (use with caution)
- `--skip-backup`: Skip automatic backup (not recommended for production)
- `--skip-health-check`: Skip health checks (not recommended)

## What It Does

1. **Validates environment**
   - Checks environment is configured
   - Verifies connection string is set
   - Validates database exists

2. **Safety checks**
   - For protected environments (production), prompts for approval
   - Creates automatic backup before applying (if configured)
   - Runs health check before deployment

3. **Migration preview** (if --dry-run)
   - Shows pending migrations
   - Displays SQL that would be executed
   - No changes applied to database

4. **Deploys migrations**
   - Applies pending migrations in order
   - Uses `prisma migrate deploy` for production
   - Uses `prisma migrate dev` for development
   - Tracks migration history

5. **Post-deployment validation**
   - Runs health check after deployment
   - Verifies all migrations applied successfully
   - Checks for schema drift

6. **Reports results**
   - Number of migrations applied
   - Duration of deployment
   - Database health status
   - Next steps

## Examples

### Apply Migrations to Development

```bash
/faber-db:migrate dev
```

Output:
```
═══════════════════════════════════════
  FABER-DB: Migration Deployment
═══════════════════════════════════════

Environment: dev
Database: myapp_dev
Provider: PostgreSQL

Step 1: Loading Configuration
✓ Configuration loaded
✓ Environment validated: dev
✓ Connection string found: DEV_DATABASE_URL

Step 2: Pre-Deployment Health Check
✓ Database connection: healthy
✓ Migration table exists: _prisma_migrations
✓ Schema is valid

Step 3: Checking Pending Migrations
Found 2 pending migrations:
  1. 20250124140000_add_user_profiles
  2. 20250124150000_add_posts_table

Step 4: Applying Migrations
✓ Applying: 20250124140000_add_user_profiles... (1.2s)
✓ Applying: 20250124150000_add_posts_table... (0.8s)

Step 5: Post-Deployment Health Check
✓ Database connection: healthy
✓ All migrations applied successfully
✓ No schema drift detected

✅ COMPLETED: Migration Deployment
Migrations Applied: 2
Duration: 2.3 seconds
Database: myapp_dev
Status: ✓ Healthy

Next steps:
  1. Verify application works with new schema
  2. Run tests: npm test
  3. Deploy to staging: /faber-db:migrate staging
```

### Preview Migrations (Dry-Run)

```bash
/faber-db:migrate production --dry-run
```

Output:
```
═══════════════════════════════════════
  FABER-DB: Migration Preview (Dry-Run)
═══════════════════════════════════════

Environment: production [PROTECTED]
Database: myapp_prod

Pending Migrations: 2

1. 20250124140000_add_user_profiles
   ├─ CREATE TABLE "UserProfile" (
   │    "id" TEXT NOT NULL,
   │    "userId" TEXT NOT NULL,
   │    "bio" TEXT,
   │    "avatar" TEXT,
   │    PRIMARY KEY ("id")
   │  );
   └─ Duration estimate: ~1.5s

2. 20250124150000_add_posts_table
   ├─ CREATE TABLE "Post" (
   │    "id" TEXT NOT NULL,
   │    "title" TEXT NOT NULL,
   │    "content" TEXT,
   │    "authorId" TEXT NOT NULL,
   │    PRIMARY KEY ("id")
   │  );
   └─ Duration estimate: ~1.2s

Total Estimated Duration: ~3.0 seconds

⚠️  This is a preview only. No changes have been applied.

To apply these migrations:
  /faber-db:migrate production
```

### Apply Migrations to Production (with Approval)

```bash
/faber-db:migrate production
```

Output:
```
═══════════════════════════════════════
  ⚠️  PRODUCTION MIGRATION DEPLOYMENT
═══════════════════════════════════════

Environment: production [PROTECTED]
Database: myapp_prod
Pending Migrations: 2

Migrations to apply:
  1. 20250124140000_add_user_profiles
  2. 20250124150000_add_posts_table

Safeguards:
✓ Backup will be created automatically
✓ Health check will run before deployment
✓ Post-deployment validation enabled
✓ Rollback capability available

Estimated duration: ~3.0 seconds

Proceed with production migration?
1. Yes, proceed (creates backup first)
2. No, cancel operation
3. Dry-run first (show SQL)

Enter choice: 1

Creating automatic backup...
✓ Backup created: backup-20250124-103000

Applying migrations...
✓ Applying: 20250124140000_add_user_profiles... (1.4s)
✓ Applying: 20250124150000_add_posts_table... (1.1s)

Post-deployment health check...
✓ Database connection: healthy
✓ All migrations applied successfully
✓ Application tests: passed

✅ COMPLETED: Production Migration
Migrations Applied: 2
Duration: 2.8 seconds
Backup ID: backup-20250124-103000
Database: myapp_prod
Status: ✓ Healthy

Rollback available:
  /faber-db:rollback production --to backup-20250124-103000
```

### Force Apply (Skip Prompts)

```bash
/faber-db:migrate staging --force
```

Applies migrations without approval prompts (use with caution).

## Migration Modes

### Development Mode (dev, test environments)
- Uses `prisma migrate dev`
- Interactive mode if needed
- Can generate migrations if schema changed
- Auto-applies migrations

### Production Mode (staging, production environments)
- Uses `prisma migrate deploy`
- Non-interactive
- Only applies existing migrations
- Requires migrations to be committed to git
- Creates backup before applying (if configured)

## Safety Features

### Protected Environments
Environments marked as protected require:
- Manual approval before deployment
- Automatic backup creation
- Pre/post-deployment health checks
- Detailed logging

### Automatic Backups
For protected environments with `backup_before_migrate: true`:
- Backup created automatically before applying migrations
- Backup ID returned for rollback reference
- Configurable retention period

### Health Checks
Before and after deployment:
- Database connectivity verified
- Schema validity checked
- Migration table accessible
- No unexpected schema drift

## Error Handling

### Migration Failure

If a migration fails:

```
❌ FAILED: Migration Deployment
Migration: 20250124140000_add_user_profiles
Error: duplicate column name "email"

Automatic rollback initiated...
✓ Rolled back to previous state
✓ Database restored from backup: backup-20250124-103000

Recovery:
1. Review migration file:
   prisma/migrations/20250124140000_add_user_profiles/migration.sql

2. Fix the migration:
   - Check for conflicting changes
   - Verify column doesn't already exist
   - Update migration file

3. Retry deployment:
   /faber-db:migrate production

4. Or rollback completely:
   /faber-db:rollback production

Backup available: backup-20250124-103000
```

### Connection Issues

```
✗ Database connection failed
Error: Connection refused

Troubleshooting:
1. Verify database is running
2. Check connection string: PROD_DATABASE_URL
3. Test connection: psql $PROD_DATABASE_URL
4. Check firewall rules
5. Verify VPN/network access

Retry when issue is resolved:
  /faber-db:migrate production
```

### No Pending Migrations

```
✓ No pending migrations

All migrations are already applied.

Migration Status:
  Applied: 5 migrations
  Pending: 0 migrations
  Last migration: 20250120100000_add_comments
  Database: ✓ Up to date

To generate a new migration:
  /faber-db:generate-migration "describe your changes"
```

## Integration with FABER Workflow

In FABER workflows, migrations are typically applied in multiple phases:

```toml
[workflow.build]
post_build = [
  "faber-db:migrate dev"  # Apply to dev after code changes
]

[workflow.evaluate]
pre_evaluate = [
  "faber-db:migrate staging"  # Deploy to staging before tests
]

[workflow.release]
pre_release = [
  "faber-db:migrate production --dry-run",  # Preview first
  "faber-db:migrate production"  # Then apply with approval
]
```

## Best Practices

### Development Workflow
1. Make schema changes in `prisma/schema.prisma`
2. Generate migration: `/faber-db:generate-migration "describe change"`
3. Review generated SQL in migration file
4. Apply to dev: `/faber-db:migrate dev`
5. Test thoroughly
6. Commit migration to git

### Staging Deployment
1. Pull latest code with migrations
2. Review pending migrations: `/faber-db:status staging`
3. Preview: `/faber-db:migrate staging --dry-run`
4. Apply: `/faber-db:migrate staging`
5. Run integration tests
6. Validate application works

### Production Deployment
1. Ensure staging is stable
2. Review production status: `/faber-db:status production`
3. Preview migrations: `/faber-db:migrate production --dry-run`
4. Schedule maintenance window (if needed)
5. Apply with approval: `/faber-db:migrate production`
6. Monitor application health
7. Keep backup ID for potential rollback

## Troubleshooting

**Schema drift detected**:
```
⚠ Schema drift detected
Your database schema differs from Prisma schema.

This usually means:
1. Manual database changes were made
2. Migrations weren't applied
3. Schema file was modified without migration

Solutions:
1. Generate migration to sync: /faber-db:generate-migration "sync schema"
2. Pull schema from database: npx prisma db pull
3. Reset database (WARNING: data loss): npx prisma migrate reset
```

**Migration already applied**:
```
⚠ Migration 20250124140000_add_user_profiles already applied
Skipping this migration.

This is normal if migrations were applied manually or by another process.
```

**Failed migration rollback**:
```
❌ Migration failed and automatic rollback also failed

This is a critical situation. Manual intervention required.

Recovery steps:
1. Restore from backup manually:
   /faber-db:restore production --backup backup-20250124-103000

2. Or fix database manually:
   psql $PROD_DATABASE_URL
   -- Review and fix migration issues

3. Contact database administrator if needed

Backup ID: backup-20250124-103000
```

## Exit Codes

- **0**: All migrations applied successfully
- **1**: Configuration or validation errors
- **2**: Migration deployment failed
- **3**: Health check failed
- **4**: User cancelled operation

## See Also

Related commands:
- `/faber-db:generate-migration` - Generate new migration
- `/faber-db:status` - Check migration status
- `/faber-db:rollback` - Rollback migrations
- `/faber-db:backup` - Create database backup

Documentation:
- `docs/README.md` - Plugin overview
- `docs/MIGRATION-GUIDE.md` - Migration workflows
- `docs/TROUBLESHOOTING.md` - Troubleshooting guide
