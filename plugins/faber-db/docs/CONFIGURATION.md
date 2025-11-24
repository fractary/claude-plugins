# FABER-DB Configuration Guide

Complete guide to configuring the FABER-DB plugin for database management.

## Configuration File Location

**Project Configuration**: `.fractary/plugins/faber-db/config.json`

This file is created by running `/faber-db:init` and should be committed to version control (credentials are stored in environment variables, making it safe to commit).

## Configuration Schema

### Overview

```json
{
  "schema_version": "1.0",
  "database": { ... },
  "environments": { ... },
  "migrations": { ... },
  "safety": { ... },
  "backup": { ... },
  "integration": { ... }
}
```

## Database Settings

### `database` Object

Defines the database type, hosting platform, and migration tool.

```json
{
  "database": {
    "provider": "postgresql",
    "hosting": "aws-aurora",
    "migration_tool": "prisma"
  }
}
```

#### `provider` (string, required)

Database type:
- `"postgresql"` - PostgreSQL (recommended for production)
- `"mysql"` - MySQL/MariaDB
- `"mongodb"` - MongoDB (future support)
- `"sqlite"` - SQLite (development only)

**Default**: `"postgresql"`

#### `hosting` (string, required)

Where the database is hosted:
- `"aws-aurora"` - AWS Aurora Serverless (auto-scaling, serverless)
- `"aws-rds"` - AWS RDS (traditional managed database)
- `"gcp-sql"` - Google Cloud SQL
- `"azure-sql"` - Azure SQL Database
- `"local"` - Local development database

**Default**: `"aws-aurora"`

**Notes**:
- `aws-aurora` and `aws-rds` require FABER-Cloud plugin for infrastructure provisioning
- `local` should only be used for development environments

#### `migration_tool` (string, required)

Migration tool to use:
- `"prisma"` - Prisma (recommended, best DX)
- `"typeorm"` - TypeORM (future support)
- `"sequelize"` - Sequelize (future support)
- `"knex"` - Knex.js (future support)

**Default**: `"prisma"`

**Handler Mapping**:
- `prisma` → `handler-db-prisma` skill
- `typeorm` → `handler-db-typeorm` skill (future)

## Environment Settings

### `environments` Object

Define environment-specific configurations. Common environments: `dev`, `staging`, `production`.

```json
{
  "environments": {
    "dev": {
      "connection_string_env": "DEV_DATABASE_URL",
      "auto_migrate": true,
      "backup_before_migrate": false,
      "require_approval": false
    },
    "staging": {
      "connection_string_env": "STAGING_DATABASE_URL",
      "auto_migrate": false,
      "backup_before_migrate": true,
      "require_approval": false
    },
    "production": {
      "connection_string_env": "PROD_DATABASE_URL",
      "auto_migrate": false,
      "backup_before_migrate": true,
      "require_approval": true
    }
  }
}
```

### Environment Configuration Options

#### `connection_string_env` (string, required)

Environment variable name containing database connection string.

**Example**:
```bash
export DEV_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_dev"
export STAGING_DATABASE_URL="postgresql://user:password@staging-db:5432/myapp_staging"
export PROD_DATABASE_URL="postgresql://user:password@prod-db:5432/myapp_prod"
```

**Connection String Format** (PostgreSQL):
```
postgresql://[user[:password]@][host][:port][/database][?param1=value1&...]
```

**SSL/TLS Parameters** (recommended for production):
```
postgresql://user:password@prod-db:5432/myapp_prod?sslmode=require&sslrootcert=/path/to/ca.pem
```

#### `auto_migrate` (boolean, optional)

Automatically apply migrations on deployment (dev only recommended).

**Default**: `false`

**Best Practices**:
- `true` for `dev` - Fast iteration
- `false` for `staging` and `production` - Manual control

#### `backup_before_migrate` (boolean, optional)

Create automatic backup before applying migrations.

**Default**: `true` for staging and production, `false` for dev

**Notes**:
- Requires backup provider configured (e.g., AWS RDS snapshots)
- Adds time to migration process but provides safety net
- Recommended for all non-dev environments

#### `require_approval` (boolean, optional)

Require manual approval before destructive operations.

**Default**: `true` for production, `false` for dev/staging

**Approval Required For**:
- Migrations (schema changes)
- Rollbacks (reverting changes)
- Seed operations (data modifications)

**User Experience**:
```
⚠️  PRODUCTION OPERATION REQUIRES APPROVAL

Operation: migrate
Environment: production

Proceed? [1. Yes / 2. No / 3. Dry-run]
```

## Migration Settings

### `migrations` Object

Configure migration storage and behavior.

```json
{
  "migrations": {
    "directory": "prisma/migrations",
    "table": "_prisma_migrations",
    "timeout_seconds": 300,
    "lock_timeout_seconds": 60
  }
}
```

#### `directory` (string, required)

Path to migrations directory (relative to project root).

**Examples**:
- Prisma: `"prisma/migrations"`
- TypeORM: `"src/migrations"`
- Knex: `"database/migrations"`

#### `table` (string, required)

Database table for tracking migration history.

**Examples**:
- Prisma: `"_prisma_migrations"`
- TypeORM: `"typeorm_migrations"`
- Knex: `"knex_migrations"`

#### `timeout_seconds` (integer, optional)

Maximum time allowed for migration execution (seconds).

**Default**: `300` (5 minutes)

**Recommendations**:
- Small schemas: 60-120 seconds
- Large schemas: 300-600 seconds
- Complex migrations: 600+ seconds

#### `lock_timeout_seconds` (integer, optional)

Maximum time to wait for migration lock (prevents concurrent migrations).

**Default**: `60` seconds

**Notes**:
- Prevents multiple instances from migrating simultaneously
- If exceeded, migration fails with lock timeout error

## Safety Settings

### `safety` Object

Production safety controls and guardrails.

```json
{
  "safety": {
    "protected_environments": ["production"],
    "require_approval_for": ["migrate", "rollback", "seed"],
    "max_auto_rollback_attempts": 1,
    "health_check_before_deploy": true,
    "health_check_after_deploy": true,
    "rollback_on_health_check_failure": true
  }
}
```

#### `protected_environments` (array of strings, required)

Environments that require extra safety measures.

**Default**: `["production"]`

**Effect**:
- Approval prompts enabled
- Automatic backups enforced
- Health checks required
- Audit logging enabled

#### `require_approval_for` (array of strings, required)

Operations requiring manual approval in protected environments.

**Options**:
- `"migrate"` - Schema migrations
- `"rollback"` - Rollback operations
- `"seed"` - Database seeding
- `"reset"` - Database reset (drop all)
- `"restore"` - Restore from backup

**Default**: `["migrate", "rollback", "seed"]`

**Best Practice**: Include all destructive operations.

#### `max_auto_rollback_attempts` (integer, optional)

Maximum automatic rollback attempts on migration failure.

**Default**: `1`

**Behavior**:
- On migration failure, automatically rollback
- If rollback also fails, stop and alert user
- Prevents cascade failures

**Recommendations**:
- `0` - No automatic rollback (manual only)
- `1` - Single rollback attempt (recommended)
- `2+` - Multiple attempts (use with caution)

#### `health_check_before_deploy` (boolean, optional)

Run health check before deploying migrations.

**Default**: `true`

**Checks**:
- Database connectivity
- Schema validity
- Migration table accessibility
- Disk space availability

**Behavior**:
- If health check fails, migration is aborted
- Prevents deploying to unhealthy database

#### `health_check_after_deploy` (boolean, optional)

Run health check after deploying migrations.

**Default**: `true`

**Checks**:
- Database still accessible
- Schema is valid
- Application can connect
- No obvious corruption

#### `rollback_on_health_check_failure` (boolean, optional)

Automatically rollback if post-deployment health check fails.

**Default**: `true`

**Behavior**:
- If post-migration health check fails, immediately rollback
- Attempts to restore previous working state
- Logs failure details for debugging

## Backup Settings

### `backup` Object

Configure backup strategy and retention.

```json
{
  "backup": {
    "provider": "aws-rds-snapshot",
    "retention_days": 30,
    "backup_before_destructive_ops": true,
    "auto_cleanup": true,
    "storage_location": "s3://myapp-db-backups",
    "encrypt_backups": true
  }
}
```

#### `provider` (string, required)

Backup provider/method:
- `"aws-rds-snapshot"` - AWS RDS automated snapshots
- `"aws-aurora-backup"` - AWS Aurora backups
- `"pg_dump"` - PostgreSQL native dump
- `"mysqldump"` - MySQL native dump
- `"custom"` - Custom backup script

**Default**: `"aws-rds-snapshot"` (if hosting is aws-*)

#### `retention_days` (integer, optional)

Number of days to retain backups.

**Default**: `30` days

**Recommendations**:
- Development: 7 days
- Staging: 14 days
- Production: 30-90 days

**Notes**:
- Longer retention increases storage costs
- Check compliance requirements (GDPR, etc.)

#### `backup_before_destructive_ops` (boolean, optional)

Automatically create backup before destructive operations.

**Default**: `true`

**Applies to**:
- Migrations in staging/production
- Rollback operations
- Database reset operations
- Data seeding in production

#### `auto_cleanup` (boolean, optional)

Automatically delete backups older than `retention_days`.

**Default**: `true`

**Notes**:
- Reduces storage costs
- Cannot recover deleted backups
- Disable if you have external backup archival

#### `storage_location` (string, optional)

Location for backup storage (provider-dependent).

**Examples**:
- S3: `"s3://bucket-name/backups"`
- GCS: `"gs://bucket-name/backups"`
- Local: `"/var/backups/database"`

#### `encrypt_backups` (boolean, optional)

Encrypt backups at rest.

**Default**: `true`

**Providers**:
- AWS: Uses KMS encryption
- GCS: Uses CMEK encryption
- Local: Uses GPG encryption

## Integration Settings

### `integration` Object

Configure integration with other plugins.

```json
{
  "integration": {
    "cloud_plugin": "fractary-faber-cloud",
    "work_plugin": "fractary-work",
    "logs_plugin": "fractary-logs",
    "notify_on_failure": true,
    "log_all_operations": true
  }
}
```

#### `cloud_plugin` (string, optional)

Name of cloud infrastructure plugin.

**Default**: `"fractary-faber-cloud"`

**Purpose**:
- Provision database infrastructure (Aurora, RDS, etc.)
- Coordinate infrastructure and schema management
- Ensure infrastructure exists before migrations

#### `work_plugin` (string, optional)

Name of work tracking plugin.

**Default**: `"fractary-work"`

**Purpose**:
- Link migrations to work items
- Update issue status after deployment
- Track database changes in issue comments

#### `logs_plugin` (string, optional)

Name of logging plugin.

**Default**: `"fractary-logs"`

**Purpose**:
- Audit trail of all database operations
- Track migration history
- Monitor failures and rollbacks

#### `notify_on_failure` (boolean, optional)

Send notifications on operation failures.

**Default**: `true`

**Notification Methods**:
- Claude Code UI
- Work plugin (issue comments)
- External integrations (Slack, PagerDuty, etc. - future)

#### `log_all_operations` (boolean, optional)

Log all database operations (not just failures).

**Default**: `true`

**Logged Operations**:
- Migrations (applied, failed, rolled back)
- Backups (created, deleted, restored)
- Health checks (passed, failed)
- Configuration changes

## Configuration Examples

### Minimal Configuration (Development Only)

```json
{
  "schema_version": "1.0",
  "database": {
    "provider": "postgresql",
    "hosting": "local",
    "migration_tool": "prisma"
  },
  "environments": {
    "dev": {
      "connection_string_env": "DATABASE_URL",
      "auto_migrate": true
    }
  },
  "migrations": {
    "directory": "prisma/migrations",
    "table": "_prisma_migrations"
  }
}
```

### Production-Ready Configuration

```json
{
  "schema_version": "1.0",
  "database": {
    "provider": "postgresql",
    "hosting": "aws-aurora",
    "migration_tool": "prisma"
  },
  "environments": {
    "dev": {
      "connection_string_env": "DEV_DATABASE_URL",
      "auto_migrate": true,
      "backup_before_migrate": false
    },
    "staging": {
      "connection_string_env": "STAGING_DATABASE_URL",
      "auto_migrate": false,
      "backup_before_migrate": true
    },
    "production": {
      "connection_string_env": "PROD_DATABASE_URL",
      "auto_migrate": false,
      "backup_before_migrate": true,
      "require_approval": true
    }
  },
  "migrations": {
    "directory": "prisma/migrations",
    "table": "_prisma_migrations",
    "timeout_seconds": 300,
    "lock_timeout_seconds": 60
  },
  "safety": {
    "protected_environments": ["production"],
    "require_approval_for": ["migrate", "rollback", "seed"],
    "max_auto_rollback_attempts": 1,
    "health_check_before_deploy": true,
    "health_check_after_deploy": true,
    "rollback_on_health_check_failure": true
  },
  "backup": {
    "provider": "aws-rds-snapshot",
    "retention_days": 30,
    "backup_before_destructive_ops": true,
    "auto_cleanup": true,
    "encrypt_backups": true
  },
  "integration": {
    "cloud_plugin": "fractary-faber-cloud",
    "work_plugin": "fractary-work",
    "logs_plugin": "fractary-logs",
    "notify_on_failure": true,
    "log_all_operations": true
  }
}
```

### Multi-Region Configuration

```json
{
  "schema_version": "1.0",
  "database": {
    "provider": "postgresql",
    "hosting": "aws-aurora",
    "migration_tool": "prisma"
  },
  "environments": {
    "production-us-east": {
      "connection_string_env": "PROD_US_EAST_DATABASE_URL",
      "auto_migrate": false,
      "backup_before_migrate": true,
      "require_approval": true,
      "region": "us-east-1"
    },
    "production-eu-west": {
      "connection_string_env": "PROD_EU_WEST_DATABASE_URL",
      "auto_migrate": false,
      "backup_before_migrate": true,
      "require_approval": true,
      "region": "eu-west-1"
    }
  },
  "safety": {
    "protected_environments": ["production-us-east", "production-eu-west"],
    "require_approval_for": ["migrate", "rollback"],
    "health_check_before_deploy": true
  }
}
```

## Environment Variables

### Required Variables

Set these environment variables for each environment:

```bash
# Development
export DEV_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_dev"

# Staging
export STAGING_DATABASE_URL="postgresql://user:password@staging-db.example.com:5432/myapp_staging?sslmode=require"

# Production
export PROD_DATABASE_URL="postgresql://user:password@prod-db.example.com:5432/myapp_prod?sslmode=require"
```

### AWS Credentials (if using AWS hosting)

```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_REGION="us-east-1"
```

### Optional Variables

```bash
# Override default config location
export FABER_DB_CONFIG="/path/to/custom/config.json"

# Enable debug logging
export FABER_DB_DEBUG="true"

# Disable safety checks (NOT recommended for production)
export FABER_DB_SKIP_SAFETY_CHECKS="false"
```

## Validation

### Validate Configuration

Run validation to check configuration:

```bash
/faber-db:status

# Output:
Configuration: ✓ Valid
  Provider: postgresql
  Hosting: aws-aurora
  Migration Tool: prisma

Environments:
  ✓ dev (local)
  ✓ staging (configured)
  ✓ production (configured, protected)

Safety Checks:
  ✓ Approval required for production
  ✓ Backups enabled before destructive ops
  ✓ Health checks enabled
```

### Common Validation Errors

**Missing environment variable**:
```
Error: Environment variable 'PROD_DATABASE_URL' not set
Solution: export PROD_DATABASE_URL="postgresql://..."
```

**Invalid provider**:
```
Error: Invalid provider 'postgres' (must be 'postgresql')
Solution: Edit config.json, change "postgres" to "postgresql"
```

**Migration tool not installed**:
```
Warning: Prisma CLI not found
Solution: npm install -D prisma @prisma/client
```

## Best Practices

1. **Version Control**: Commit configuration file (safe - no credentials)
2. **Environment Variables**: Never commit `.env` files with credentials
3. **Separate Environments**: Use distinct databases for dev/staging/production
4. **Enable Safety**: Always use approval + backups for production
5. **Test Migrations**: Always test in dev/staging before production
6. **Monitor Health**: Enable health checks for early problem detection
7. **Retain Backups**: Keep backups for at least 30 days
8. **Audit Logs**: Enable logging for compliance and debugging
9. **Use SSL/TLS**: Always use encrypted connections in production
10. **Rotate Credentials**: Regularly update database passwords

## Troubleshooting

See main [README.md](./README.md#troubleshooting) for common issues and solutions.

## See Also

- [README.md](./README.md) - Plugin overview and quick start
- [MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md) - Migration workflows
- [ROLLBACK-PROCEDURES.md](./ROLLBACK-PROCEDURES.md) - Rollback procedures
- [HANDLERS.md](./HANDLERS.md) - Database tool handlers
