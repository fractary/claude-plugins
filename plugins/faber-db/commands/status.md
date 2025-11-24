Check FABER-DB plugin configuration and database status.

This command displays the current configuration, validates environment variables, checks database connectivity, and shows migration status across all configured environments.

## Usage

```bash
/faber-db:status [environment]
```

## Arguments

- `[environment]` (optional): Specific environment to check (dev, staging, production). If omitted, checks all environments.

## What It Does

1. **Configuration validation**
   - Checks if `.fractary/plugins/faber-db/config.json` exists
   - Validates JSON syntax
   - Shows database provider, hosting, and migration tool settings

2. **Environment validation**
   - Lists all configured environments
   - Checks if environment variables are set for each
   - Marks protected environments

3. **Database connectivity** (if environment specified)
   - Tests connection to database
   - Shows database existence status
   - Displays migration table status

4. **Migration status** (if environment specified)
   - Shows pending migrations
   - Shows applied migrations
   - Detects schema drift

5. **Safety settings**
   - Shows protected environments
   - Displays approval requirements
   - Shows backup settings

## Examples

### Check All Environments

```bash
/faber-db:status
```

Output:
```
═══════════════════════════════════════
  FABER-DB Plugin Status
═══════════════════════════════════════

Configuration: ✓ Valid
  Location: .fractary/plugins/faber-db/config.json
  Provider: postgresql
  Hosting: local
  Migration Tool: prisma

Environments:
  ✓ dev (local)
    Connection: DEV_DATABASE_URL [SET]
    Auto-migrate: true
    Backups: false

  ✓ staging (local)
    Connection: STAGING_DATABASE_URL [SET]
    Auto-migrate: false
    Backups: true

  ⚠ production (local) [PROTECTED]
    Connection: PROD_DATABASE_URL [NOT SET]
    Auto-migrate: false
    Backups: true
    Requires approval: true

Safety Settings:
  Protected Environments: production
  Approval Required For: migrate, rollback, seed
  Health Checks: enabled
  Max Rollback Attempts: 1

Integration:
  FABER-Cloud: fractary-faber-cloud
  Work Plugin: fractary-work
  Logs Plugin: fractary-logs

Status: ✓ Ready (dev)
        ⚠ Not configured (production)
```

### Check Specific Environment

```bash
/faber-db:status dev
```

Output:
```
═══════════════════════════════════════
  FABER-DB: Development Environment
═══════════════════════════════════════

Environment: dev
Provider: postgresql
Hosting: local
Migration Tool: prisma

Connection:
  ✓ DEV_DATABASE_URL is set
  ✓ Database exists: myapp_dev
  ✓ Connection successful
  ✓ Migration table exists: _prisma_migrations

Prisma Schema:
  ✓ Schema file: prisma/schema.prisma
  ✓ Models: 5 (User, Post, Comment, Tag, Category)
  ✓ Client generated: yes

Migration Status:
  Applied Migrations: 3
    ✓ 20250115120000_init
    ✓ 20250118150000_add_posts
    ✓ 20250120100000_add_comments

  Pending Migrations: 1
    ⚠ 20250124140000_add_tags (not applied)

  Schema Drift: None detected

Database Information:
  Database: myapp_dev
  Size: 2.4 MB
  Tables: 8
  Last Migration: 2025-01-20 10:00:00

Health: ✓ Healthy
Status: ⚠ Pending migrations (1)

Next Steps:
  Apply pending migration: /faber-db:migrate dev
```

### Check Production Environment

```bash
/faber-db:status production
```

Output (not configured):
```
═══════════════════════════════════════
  FABER-DB: Production Environment
═══════════════════════════════════════

Environment: production [PROTECTED]
Provider: postgresql
Hosting: aws-aurora
Migration Tool: prisma

Connection:
  ✗ PROD_DATABASE_URL is not set
  ✗ Cannot check database status

Configuration Required:
  1. Set connection string:
     export PROD_DATABASE_URL="postgresql://..."

  2. Create database infrastructure:
     /faber-cloud:provision database --env production

  3. Initialize database:
     /faber-db:db-create production

Status: ✗ Not Configured
```

## Output Fields

### Configuration Section
- **Location**: Path to config.json
- **Provider**: Database type (postgresql, mysql, etc.)
- **Hosting**: Where database is hosted (local, aws-aurora, etc.)
- **Migration Tool**: Tool used for migrations (prisma, typeorm, etc.)

### Environment Section
- **Connection**: Environment variable name and status (SET/NOT SET)
- **Auto-migrate**: Whether migrations apply automatically
- **Backups**: Whether backups are created before migrations
- **Requires approval**: Whether operations need manual approval

### Migration Status
- **Applied Migrations**: Migrations that have been run
- **Pending Migrations**: Migrations waiting to be applied
- **Schema Drift**: Differences between schema file and database

### Health Status
- ✓ **Healthy**: Database is accessible and in good state
- ⚠ **Warning**: Database accessible but has pending migrations or minor issues
- ✗ **Error**: Database not accessible or has critical issues

## Troubleshooting

**Configuration not found**:
```
Error: FABER-DB configuration not found
Run /faber-db:init to configure the plugin
```

**Environment variable not set**:
```
⚠ PROD_DATABASE_URL is not set
Set it with: export PROD_DATABASE_URL="postgresql://..."
```

**Database doesn't exist**:
```
✗ Database does not exist
Create it with: /faber-db:db-create production
```

**Connection failed**:
```
✗ Connection failed: Connection refused
Check:
  1. Database server is running
  2. Connection string is correct
  3. Firewall allows connection
```

**Pending migrations**:
```
⚠ Pending migrations: 2
Apply with: /faber-db:migrate dev
```

**Schema drift detected**:
```
⚠ Schema drift detected
Your Prisma schema differs from the database schema.
Options:
  1. Generate migration: /faber-db:generate-migration "sync schema"
  2. Pull schema from database: npx prisma db pull
```

## Integration with FABER Workflow

In FABER workflows, status checks can be added to validation phases:

```toml
[workflow.evaluate]
pre_evaluate = [
  "faber-db:status staging"  # Verify staging database is healthy
]
```

## Use Cases

### Pre-deployment Validation
Check production database status before deploying:
```bash
/faber-db:status production
```

### Debugging Connection Issues
When database operations fail, check status to diagnose:
```bash
/faber-db:status dev
```

### Configuration Audit
Review all environment configurations:
```bash
/faber-db:status
```

### Migration Planning
See what migrations are pending before deployment:
```bash
/faber-db:status staging
```

## Exit Codes

- **0**: All checks passed (healthy)
- **1**: Configuration errors or missing
- **2**: Environment not configured
- **3**: Connection failed
- **4**: Pending migrations or warnings

## See Also

Related commands:
- `/faber-db:init` - Configure plugin
- `/faber-db:db-create` - Create database
- `/faber-db:migrate` - Apply migrations
- `/faber-db:health-check` - Run detailed health checks

Documentation:
- `docs/README.md` - Plugin overview
- `docs/CONFIGURATION.md` - Configuration guide
- `docs/TROUBLESHOOTING.md` - Troubleshooting guide
