Create database infrastructure for a new environment.

This command initializes database infrastructure by coordinating with FABER-Cloud (for cloud hosting) or directly creating the database (for local hosting), then initializing the schema and migration tracking table.

## Usage

```bash
/faber-db:db-create <environment> [options]
```

## Arguments

- `<environment>` (required): Environment name (dev, staging, production)

## Options

- `--database-name <name>`: Custom database name (default: project-name_environment)
- `--force`: Skip confirmation prompts (use with caution)

## What It Does

1. **Validates environment**
   - Checks environment is configured in `.fractary/plugins/faber-db/config.json`
   - Verifies connection string environment variable is set

2. **Safety checks**
   - For protected environments (production), prompts for approval
   - Checks if database already exists to prevent accidental recreation

3. **Infrastructure provisioning** (cloud hosting only)
   - Checks if database infrastructure exists
   - If not, coordinates with FABER-Cloud plugin to provision
   - Waits for infrastructure to be ready

4. **Schema initialization**
   - Creates database (if doesn't exist)
   - Initializes migration tracking table
   - Sets up schema baseline

5. **Verification**
   - Tests database connectivity
   - Verifies migration table is accessible
   - Runs basic health check

6. **Reports results**
   - Database creation status
   - Connection details (non-sensitive)
   - Next steps for adding schema

## Examples

### Create Development Database (Local)

```bash
/faber-db:db-create dev
```

Creates local development database, typically on localhost.

### Create Staging Database (Cloud)

```bash
/faber-db:db-create staging
```

Creates staging database on configured cloud provider (e.g., AWS Aurora).

### Create Production Database (Cloud, with Approval)

```bash
/faber-db:db-create production
```

Prompts for approval before creating production infrastructure:

```
⚠️  PRODUCTION OPERATION REQUIRES APPROVAL

Operation: Create Database
Environment: production
Provider: AWS Aurora PostgreSQL
Region: us-east-1

This will create production database infrastructure.

Estimated costs:
  - Aurora Serverless v2: ~$0.12/hr (~$90/month)
  - Storage: $0.10/GB/month
  - Backups: $0.02/GB/month

Proceed with production database creation?
1. Yes, proceed
2. No, cancel operation
3. Show estimated costs breakdown

Enter choice:
```

### Custom Database Name

```bash
/faber-db:db-create dev --database-name myapp_dev_custom
```

Creates database with custom name instead of default.

### Force Creation (Skip Prompts)

```bash
/faber-db:db-create dev --force
```

Skips all confirmation prompts (not recommended for production).

## Output

### Success Output

```
🎯 STARTING: Database Creation
Environment: dev
Database Name: myapp_dev
───────────────────────────────────────

✓ Configuration loaded
✓ Environment validated: dev
✓ Connection string found: DEV_DATABASE_URL
✓ Infrastructure check: local (no provisioning needed)
✓ Database doesn't exist (will create)
✓ Creating database: myapp_dev
✓ Initializing migration table: _prisma_migrations
✓ Connectivity verified
✓ Health check passed

✅ COMPLETED: Database Creation
Database: myapp_dev
Environment: dev
Provider: PostgreSQL
Hosting: local
Status: Ready for migrations
───────────────────────────────────────

Next steps:
1. Define your schema (e.g., prisma/schema.prisma)
2. Generate initial migration: /faber-db:generate-migration "initial schema"
3. Apply migration: /faber-db:migrate dev
```

### Error Output

```
❌ FAILED: Database Creation
Environment: production
Error: Database infrastructure not found

The database server doesn't exist yet.

Recovery steps:
1. Provision infrastructure first:
   /faber-cloud:provision database --env production --type aurora-postgresql

2. Or configure FABER-Cloud plugin:
   /faber-cloud:init

3. Then retry database creation:
   /faber-db:db-create production

For local development, use: /faber-db:db-create dev
```

## Environment Variables Required

Before creating a database, set the connection string environment variable:

```bash
# Development
export DEV_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_dev"

# Staging
export STAGING_DATABASE_URL="postgresql://user:password@staging-db.example.com:5432/myapp_staging"

# Production
export PROD_DATABASE_URL="postgresql://user:password@prod-db.example.com:5432/myapp_prod"
```

## Database Already Exists

If the database already exists:

```
⚠️  Database Already Exists

Database: myapp_dev
Environment: dev

The database 'myapp_dev' already exists.

Options:
1. Use existing database (apply migrations to it)
2. Drop and recreate (WARNING: data loss)
3. Cancel operation

Enter choice:
```

## Cloud Hosting Workflow

For cloud-hosted databases (AWS Aurora, AWS RDS, etc.):

1. **Infrastructure Check**
   - Checks if database server exists using cloud provider API

2. **Provision Infrastructure** (if needed)
   - Invokes FABER-Cloud plugin
   - Provisions database server (Aurora, RDS, etc.)
   - Configures networking, security groups, backups
   - Waits for server to be ready (may take 5-10 minutes)

3. **Schema Initialization**
   - Connects to provisioned server
   - Creates database schema
   - Initializes migration tracking

## Troubleshooting

**Environment not configured**:
```
Error: Environment 'staging' not found in configuration
Solution: Edit .fractary/plugins/faber-db/config.json to add staging environment
```

**Connection string not set**:
```
Error: DEV_DATABASE_URL environment variable not set
Solution: export DEV_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_dev"
```

**Database already exists**:
```
Error: Database 'myapp_dev' already exists
Solution: Use /faber-db:migrate dev to apply migrations to existing database
```

**Infrastructure provisioning failed**:
```
Error: Failed to provision Aurora database - insufficient permissions
Solution: Verify AWS credentials have RDS permissions (rds:CreateDBInstance, etc.)
```

**Connection failed**:
```
Error: Connection refused to localhost:5432
Solution: Ensure PostgreSQL server is running: brew services start postgresql
```

## Integration with FABER Workflow

In FABER workflows, database creation typically happens in the Frame phase:

```toml
[workflow.frame]
post_frame = [
  "faber-db:db-create dev"  # Create dev database if doesn't exist
]
```

## See Also

Related commands:
- `/faber-db:init` - Configure plugin
- `/faber-db:migrate` - Apply migrations
- `/faber-db:status` - Check database status
- `/faber-db:backup` - Create database backup
- `/faber-cloud:provision` - Provision cloud infrastructure

Documentation:
- `docs/README.md` - Plugin overview
- `docs/CONFIGURATION.md` - Configuration guide
- `docs/TROUBLESHOOTING.md` - Troubleshooting guide
