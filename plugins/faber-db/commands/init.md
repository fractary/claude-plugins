---
model: claude-haiku-4-5
---

Initialize FABER-DB plugin configuration.

This command sets up the database management plugin for your project by creating a configuration file that defines database settings, environments, safety rules, and integrations.

## Usage

```bash
/faber-db:init [options]
```

## Options

- `--provider <type>`: Database provider (postgresql, mysql, mongodb) - default: postgresql
- `--hosting <type>`: Hosting platform (aws-aurora, aws-rds, gcp-sql, azure-sql, local) - default: aws-aurora
- `--migration-tool <tool>`: Migration tool (prisma, typeorm, sequelize, knex) - default: prisma
- `--yes`: Skip prompts and use defaults
- `--force`: Overwrite existing configuration

## What It Does

1. **Checks for existing configuration**
   - Looks for `.fractary/plugins/faber-db/config.json`
   - If exists and `--force` not provided, asks for confirmation

2. **Prompts for configuration** (unless `--yes` provided)
   - Database provider (PostgreSQL, MySQL, MongoDB)
   - Hosting platform (AWS Aurora, AWS RDS, GCP SQL, Azure SQL, Local)
   - Migration tool (Prisma, TypeORM, Sequelize, Knex)
   - Environment setup (dev, staging, production)
   - Safety settings (approval requirements, backup settings)

3. **Creates configuration file**
   - Generates `.fractary/plugins/faber-db/config.json`
   - Uses template from `config/faber-db.example.json`
   - Customizes based on user responses

4. **Validates configuration**
   - Checks required environment variables
   - Validates database connectivity (optional)
   - Ensures migration tool is installed

5. **Provides next steps**
   - Instructions for setting environment variables
   - Commands to create database infrastructure
   - Migration workflow overview

## Examples

### Interactive Setup (Recommended)

```bash
/faber-db:init
```

Prompts for all configuration options interactively.

### Quick Setup with Defaults

```bash
/faber-db:init --yes
```

Uses default settings (PostgreSQL, AWS Aurora, Prisma).

### Custom Setup

```bash
/faber-db:init --provider mysql --hosting aws-rds --migration-tool typeorm
```

Specifies provider, hosting, and migration tool.

### Reconfigure Existing

```bash
/faber-db:init --force
```

Overwrites existing configuration with new settings.

## Configuration Created

The command creates `.fractary/plugins/faber-db/config.json`:

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
    "timeout_seconds": 300
  },
  "safety": {
    "protected_environments": ["production"],
    "require_approval_for": ["migrate", "rollback", "seed"],
    "max_auto_rollback_attempts": 1,
    "health_check_before_deploy": true
  },
  "backup": {
    "provider": "aws-rds-snapshot",
    "retention_days": 30,
    "backup_before_destructive_ops": true
  },
  "integration": {
    "cloud_plugin": "fractary-faber-cloud",
    "work_plugin": "fractary-work",
    "logs_plugin": "fractary-logs"
  }
}
```

## Environment Variables Required

After initialization, you'll need to set these environment variables:

**Development**:
```bash
export DEV_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_dev"
```

**Staging**:
```bash
export STAGING_DATABASE_URL="postgresql://user:password@staging-db.example.com:5432/myapp_staging"
```

**Production**:
```bash
export PROD_DATABASE_URL="postgresql://user:password@prod-db.example.com:5432/myapp_prod"
```

**AWS Credentials** (if using AWS hosting):
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

## Next Steps

After initialization:

1. **Set environment variables** (see above)

2. **Install migration tool** (if not already installed):
   ```bash
   # For Prisma
   npm install -D prisma @prisma/client

   # For TypeORM
   npm install typeorm reflect-metadata
   ```

3. **Create database infrastructure** (if using cloud hosting):
   ```bash
   /faber-db:db-create dev
   /faber-db:db-create staging
   /faber-db:db-create production
   ```

4. **Initialize database schema**:
   ```bash
   # Generate initial migration
   /faber-db:generate-migration "initial schema"

   # Apply to dev
   /faber-db:migrate dev
   ```

5. **Review configuration**:
   - Edit `.fractary/plugins/faber-db/config.json` to customize
   - See `/docs/CONFIGURATION.md` for detailed options

## Interactive Prompts

When running without `--yes`, you'll see:

```
🔧 FABER-DB Plugin Initialization

Let's configure database management for your project.

1. Database Provider
   Choose your database type:
   1. PostgreSQL (recommended for production)
   2. MySQL
   3. MongoDB

   Selection [1]:

2. Hosting Platform
   Where will your database be hosted?
   1. AWS Aurora (serverless, auto-scaling)
   2. AWS RDS (traditional managed database)
   3. GCP Cloud SQL
   4. Azure SQL Database
   5. Local (development only)

   Selection [1]:

3. Migration Tool
   Which migration tool do you want to use?
   1. Prisma (recommended, best DX)
   2. TypeORM
   3. Sequelize
   4. Knex

   Selection [1]:

4. Environments
   Configure environments (using defaults: dev, staging, production)

   ✓ Development: Auto-migrate enabled, no backups
   ✓ Staging: Manual migrate, with backups
   ✓ Production: Manual migrate, with backups, requires approval

5. Safety Settings
   ✓ Production requires approval for: migrate, rollback, seed
   ✓ Backups before destructive operations
   ✓ Health checks before deployment
   ✓ Max auto-rollback attempts: 1

Configuration complete!

Next steps:
1. Set environment variables for database connections
2. Install migration tool: npm install -D prisma @prisma/client
3. Create database infrastructure: /faber-db:db-create dev
4. Generate initial migration: /faber-db:generate-migration "initial schema"

See docs/CONFIGURATION.md for more details.
```

## Troubleshooting

**Configuration already exists**:
```
Error: Configuration already exists at .fractary/plugins/faber-db/config.json
Use --force to overwrite, or edit the file manually
```

**Migration tool not found**:
```
Warning: Prisma not found in project
Install with: npm install -D prisma @prisma/client
Or choose a different migration tool with --migration-tool
```

**Invalid provider**:
```
Error: Invalid provider 'postgres'. Valid options: postgresql, mysql, mongodb
```

## See Also

Related commands:
- `/faber-db:db-create` - Create database infrastructure
- `/faber-db:migrate` - Run migrations
- `/faber-db:status` - Check configuration and database status
- `/faber-db:backup` - Create database backup

Documentation:
- `docs/README.md` - Plugin overview
- `docs/CONFIGURATION.md` - Detailed configuration guide
- `docs/MIGRATION-GUIDE.md` - Migration workflow guide
