Create a backup of a database environment.

This command creates a complete backup of the database, including schema and data. Backups are essential for safe production deployments and provide rollback capability if migrations fail.

## Usage

```bash
/faber-db:backup <environment> [options]
```

## Arguments

- `<environment>` (required): Environment name (dev, staging, production)

## Options

- `--label <label>`: Custom label for backup (default: auto-generated from timestamp)
- `--reason <reason>`: Reason for backup (e.g., "pre-migration", "manual")
- `--retention <days>`: Retention period in days (default: from config)
- `--format <format>`: Backup format (sql, custom, directory) - default: sql
- `--compression`: Enable compression (gzip)

## What It Does

1. **Validates environment**
   - Checks environment is configured
   - Verifies connection string is set
   - Validates database exists and is accessible

2. **Checks backup prerequisites**
   - Verifies backup tool is installed (pg_dump, mysqldump)
   - Ensures sufficient disk space
   - Validates backup directory exists

3. **Creates backup**
   - Exports complete database (schema + data)
   - Stores in `.fractary/plugins/faber-db/backups/<environment>/`
   - Generates unique backup ID
   - Records metadata (timestamp, migrations, size)

4. **Verifies backup**
   - Validates backup file integrity
   - Records backup size
   - Tests backup file can be read

5. **Updates metadata**
   - Records backup in `backups.json`
   - Stores migration state at backup time
   - Tracks retention period

6. **Reports results**
   - Backup ID for future reference
   - Backup size and location
   - Retention expiration date
   - Restoration command

## Examples

### Create Development Backup

```bash
/faber-db:backup dev
```

Output:
```
═══════════════════════════════════════
  FABER-DB: Database Backup
═══════════════════════════════════════

Environment: dev
Database: myapp_dev
Provider: PostgreSQL

Step 1: Loading Configuration
✓ Configuration loaded
✓ Environment validated: dev
✓ Connection string found: DEV_DATABASE_URL

Step 2: Pre-Backup Checks
✓ pg_dump found: version 15.4
✓ Disk space available: 10.2 GB
✓ Backup directory: .fractary/plugins/faber-db/backups/dev

Step 3: Creating Backup
Creating database backup...
✓ Backing up schema...
✓ Backing up data...
✓ Backup created: backup-20250124-140000

Backup Details:
  File: backup-20250124-140000.sql
  Size: 2.3 MB
  Migrations: 5 applied
  Duration: 1.8 seconds

Step 4: Verifying Backup
✓ Backup file integrity: valid
✓ Backup file readable: yes
✓ Metadata recorded

✅ COMPLETED: Database Backup
Backup ID: backup-20250124-140000
Location: .fractary/plugins/faber-db/backups/dev/backup-20250124-140000.sql
Size: 2.3 MB
Retention: 30 days (expires: 2025-02-23)

To restore from this backup:
  /faber-db:restore dev --from backup-20250124-140000
```

### Create Production Backup with Label

```bash
/faber-db:backup production --label "pre-v2-migration" --reason "before major schema changes"
```

Output:
```
═══════════════════════════════════════
  FABER-DB: Database Backup (Production)
═══════════════════════════════════════

Environment: production [PROTECTED]
Database: myapp_prod
Label: pre-v2-migration
Reason: before major schema changes

⚠️  Production Backup Notice
This will create a backup of the production database.

Backup Details:
  Database: myapp_prod
  Current Size: 45.6 GB
  Estimated Backup Size: ~48 GB (with compression)
  Estimated Duration: ~5-8 minutes
  Storage Location: .fractary/plugins/faber-db/backups/production/

Proceed with production backup? (yes/no): yes

Creating production backup...
✓ Exporting schema...
✓ Exporting data... (45.6 GB)
✓ Compressing backup...
✓ Backup created: backup-20250124-140000-pre-v2-migration

✅ COMPLETED: Production Backup
Backup ID: backup-20250124-140000-pre-v2-migration
Label: pre-v2-migration
Location: .fractary/plugins/faber-db/backups/production/backup-20250124-140000-pre-v2-migration.sql.gz
Size: 12.3 GB (compressed from 48 GB)
Retention: 90 days (expires: 2025-04-24)

Backup includes:
  Schema: ✓ All tables, indexes, constraints
  Data: ✓ All rows (45.6 GB)
  Migrations: ✓ 24 applied migrations
  Migration State: 20250120150000_add_api_keys

To restore from this backup:
  /faber-db:restore production --from backup-20250124-140000-pre-v2-migration
```

### Create Backup with Compression

```bash
/faber-db:backup staging --compression
```

Output:
```
Creating backup with gzip compression...
✓ Backup created: backup-20250124-150000.sql.gz
Size: 450 MB (compressed from 2.1 GB)
Compression ratio: 78.6%
```

### List Available Backups

```bash
/faber-db:backup dev --list
```

Output:
```
Available Backups for 'dev':

1. backup-20250124-140000
   Created: 2025-01-24 14:00:00
   Size: 2.3 MB
   Migrations: 5 applied
   Last Migration: 20250124120000_add_user_profiles
   Retention: 29 days remaining
   Status: ✓ Valid

2. backup-20250123-100000
   Created: 2025-01-23 10:00:00
   Size: 2.1 MB
   Migrations: 4 applied
   Last Migration: 20250123090000_add_posts
   Retention: 28 days remaining
   Status: ✓ Valid

3. backup-20250122-150000
   Created: 2025-01-22 15:00:00
   Size: 1.9 MB
   Migrations: 3 applied
   Last Migration: 20250122140000_initial_schema
   Retention: 27 days remaining
   Status: ✓ Valid

Total: 3 backups (6.3 MB)
```

## Backup Storage

### Local Storage

Backups are stored in:
```
.fractary/plugins/faber-db/backups/
├── dev/
│   ├── backup-20250124-140000.sql
│   ├── backup-20250123-100000.sql
│   └── backup-20250122-150000.sql
├── staging/
│   └── backup-20250124-130000.sql.gz
├── production/
│   └── backup-20250124-140000-pre-v2-migration.sql.gz
└── backups.json  # Metadata
```

### Backup Metadata

`backups.json` structure:
```json
{
  "backups": [
    {
      "id": "backup-20250124-140000",
      "environment": "dev",
      "database": "myapp_dev",
      "timestamp": "2025-01-24T14:00:00Z",
      "label": null,
      "reason": "manual",
      "file": "backup-20250124-140000.sql",
      "size_bytes": 2411520,
      "compressed": false,
      "format": "sql",
      "migrations": {
        "applied_count": 5,
        "last_migration": "20250124120000_add_user_profiles",
        "migrations_list": [
          "20250120100000_initial_schema",
          "...",
          "20250124120000_add_user_profiles"
        ]
      },
      "retention_days": 30,
      "expires_at": "2025-02-23T14:00:00Z",
      "status": "valid",
      "verification": {
        "integrity_check": "passed",
        "file_readable": true,
        "verified_at": "2025-01-24T14:00:05Z"
      }
    }
  ]
}
```

## Backup Formats

### SQL Format (Default)

Plain SQL dump:
- **Pros**: Human-readable, portable, easy to inspect
- **Cons**: Larger file size, slower for large databases
- **Use case**: Development, staging, small databases

```bash
/faber-db:backup dev --format sql
```

### Custom Format (PostgreSQL only)

PostgreSQL custom format:
- **Pros**: Compressed, faster restore, parallel restore support
- **Cons**: PostgreSQL-specific, not human-readable
- **Use case**: Large production databases

```bash
/faber-db:backup production --format custom
```

### Directory Format (PostgreSQL only)

Directory of files:
- **Pros**: Parallel dump/restore, flexible restore options
- **Cons**: Multiple files, more complex
- **Use case**: Very large databases

```bash
/faber-db:backup production --format directory
```

## Backup Tool Behavior

### PostgreSQL (pg_dump)

Uses `pg_dump` with appropriate flags:
```bash
# SQL format
pg_dump -Fp --no-owner --no-acl -f backup.sql $DATABASE_URL

# Custom format
pg_dump -Fc -f backup.dump $DATABASE_URL

# Directory format
pg_dump -Fd -j 4 -f backup-dir $DATABASE_URL
```

### MySQL (mysqldump)

Uses `mysqldump` with appropriate flags:
```bash
# SQL format
mysqldump --single-transaction --routines --triggers -r backup.sql $DATABASE

# Compressed
mysqldump --single-transaction --routines --triggers $DATABASE | gzip > backup.sql.gz
```

### SQLite (sqlite3)

Uses SQLite backup:
```bash
sqlite3 $DATABASE ".backup backup.db"
```

## Automatic Backups

### Pre-Migration Backups

Automatic backups before production migrations:
```json
// .fractary/plugins/faber-db/config.json
{
  "environments": {
    "production": {
      "backup_before_migrate": true,
      "backup_retention_days": 90
    }
  }
}
```

When configured, backups are created automatically:
```bash
# This will create automatic backup first
/faber-db:migrate production

# Output:
# Step 1: Pre-Migration Backup
# ✓ Creating automatic backup...
# ✓ Backup created: backup-20250124-140000-pre-migration
# Step 2: Deploying Migrations...
```

### Scheduled Backups (Future)

Configure scheduled backups:
```json
{
  "environments": {
    "production": {
      "backup_schedule": "0 2 * * *",  // Daily at 2 AM
      "backup_retention_days": 90
    }
  }
}
```

## Retention and Cleanup

### Automatic Cleanup

Backups are automatically cleaned up based on retention:
- **Development**: 30 days (default)
- **Staging**: 60 days (default)
- **Production**: 90 days (default)

Override retention:
```bash
/faber-db:backup production --retention 180
```

### Manual Cleanup

Remove old backups:
```bash
# Remove expired backups
/faber-db:cleanup-backups --expired

# Remove backups older than N days
/faber-db:cleanup-backups --older-than 60

# Remove specific backup
/faber-db:delete-backup backup-20250124-140000
```

## Cloud Backups (Future)

### AWS RDS Snapshots

For RDS databases:
```bash
/faber-db:backup production --cloud aws

# Uses AWS RDS snapshots instead of pg_dump
# Faster for large databases
# Managed by AWS
```

Configuration:
```json
{
  "environments": {
    "production": {
      "hosting": "aws-rds",
      "backup_method": "rds-snapshot",
      "rds_instance_id": "myapp-prod-db"
    }
  }
}
```

### S3 Storage

Store backups in S3:
```json
{
  "backup": {
    "storage": "s3",
    "s3_bucket": "myapp-db-backups",
    "s3_prefix": "faber-db/"
  }
}
```

## Error Handling

### Insufficient Disk Space

```
✗ Insufficient disk space for backup

Required: 50 GB
Available: 25 GB

Solutions:
1. Free up disk space
2. Use compression: /faber-db:backup production --compression
3. Clean up old backups: /faber-db:cleanup-backups --expired
4. Use cloud storage: Configure S3 in config.json
```

### Backup Tool Not Found

```
✗ pg_dump not found

PostgreSQL client tools are required for backups.

Installation:
  Ubuntu/Debian: sudo apt-get install postgresql-client
  macOS: brew install postgresql
  Windows: Download from postgresql.org

After installation, retry:
  /faber-db:backup dev
```

### Connection Failed

```
✗ Cannot connect to database

Error: Connection refused at localhost:5432

Troubleshooting:
1. Verify database is running
2. Check connection string: echo $PROD_DATABASE_URL
3. Test connection: psql $PROD_DATABASE_URL
4. Verify VPN/network access
```

### Backup Verification Failed

```
✗ Backup verification failed

The backup file may be corrupted or incomplete.

What to do:
1. Delete corrupted backup
2. Retry backup creation
3. If problem persists, check:
   - Disk space during backup
   - Database connection stability
   - Backup tool version
```

## Integration with FABER Workflow

### Release Phase Integration

```toml
[workflow.release]
pre_release = [
  "faber-db:backup production --label pre-release",
  "faber-db:migrate production"
]
```

### Automatic Rollback on Failure

```toml
[workflow.release]
on_failure = [
  "faber-db:rollback production"  # Uses latest backup
]
```

## Best Practices

### 1. Always Backup Before Production Changes

```bash
# Manual backup before important changes
/faber-db:backup production --label "before-v2-launch"

# Then deploy
/faber-db:migrate production
```

### 2. Label Important Backups

```bash
/faber-db:backup production --label "pre-major-refactor" --reason "before removing legacy tables"
```

### 3. Test Backup Restoration

Regularly test that backups can be restored:
```bash
# Restore to staging to verify
/faber-db:restore staging --from <prod-backup-id>
```

### 4. Monitor Backup Size

Track backup growth over time:
```bash
/faber-db:backup dev --list

# If backups growing too fast:
# - Archive old data
# - Clean up unused tables
# - Consider partitioning
```

### 5. Verify Backup Integrity

After critical backups:
```bash
/faber-db:verify-backup backup-20250124-140000
```

## Exit Codes

- **0**: Backup created successfully
- **1**: Configuration or validation errors
- **2**: Insufficient disk space
- **3**: Database connection failed
- **4**: Backup tool not found
- **5**: Backup verification failed

## See Also

Related commands:
- `/faber-db:restore` - Restore database from backup
- `/faber-db:rollback` - Rollback migrations using backup
- `/faber-db:list-backups` - List available backups
- `/faber-db:cleanup-backups` - Remove old backups

Documentation:
- `docs/README.md` - Plugin overview
- `docs/BACKUP-GUIDE.md` - Backup and restore procedures
- `docs/ROLLBACK-PROCEDURES.md` - Rollback strategies
