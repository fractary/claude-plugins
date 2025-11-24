# FABER-DB Plugin

**Production-grade database management for FABER workflows**

The FABER-DB plugin provides safe, automated database management across multiple environments (dev, staging, production). It handles schema migrations, rollbacks, backups, and monitoring with built-in production safety guarantees.

## Overview

Managing databases properly in production is complex:
- Schema changes must be tested across environments
- Production deployments require backups and approvals
- Rollback capability is essential for recovery
- Data integrity must be maintained at all times

FABER-DB solves these challenges by providing:
- ✅ **Multi-environment support** - Dev, staging, production with environment-specific settings
- ✅ **Production safety** - Automatic backups, approval workflows, health checks
- ✅ **Migration management** - Generate, deploy, and rollback schema changes safely
- ✅ **Tool abstraction** - Works with Prisma, TypeORM, Sequelize, Knex (via handlers)
- ✅ **FABER integration** - Seamless integration with FABER workflow phases
- ✅ **Cloud integration** - Coordinates with FABER-Cloud for infrastructure provisioning

## Key Features

### Production Safety First

- **Automatic backups** before destructive operations
- **Approval prompts** for production changes
- **Health checks** before and after deployments
- **Rollback capability** for failed migrations
- **Audit trail** of all database operations

### Multi-Environment Workflow

```
Dev → Staging → Production
 ↓       ↓          ↓
Test  Validate  Deploy (with approval)
```

- **Development**: Fast iteration, auto-migrations, no backups
- **Staging**: Production-like testing, backups enabled, manual control
- **Production**: Maximum safety, required approvals, automatic backups

### Migration Management

- Generate migrations from schema changes
- Preview migrations before deployment (dry-run mode)
- Deploy migrations with automatic validation
- Rollback to previous state or specific migration
- Track migration history and status

### Tool Abstraction

Support for multiple migration tools via handler pattern:
- **Prisma** (primary, recommended)
- **TypeORM** (future)
- **Sequelize** (future)
- **Knex** (future)

Choose the tool that fits your stack, FABER-DB adapts.

## Quick Start

### 1. Initialize Plugin

```bash
/faber-db:init
```

This creates `.fractary/plugins/faber-db/config.json` with your database configuration.

### 2. Set Environment Variables

```bash
export DEV_DATABASE_URL="postgresql://user:password@localhost:5432/myapp_dev"
export STAGING_DATABASE_URL="postgresql://user:password@staging-db:5432/myapp_staging"
export PROD_DATABASE_URL="postgresql://user:password@prod-db:5432/myapp_prod"
```

### 3. Install Migration Tool

```bash
# For Prisma (recommended)
npm install -D prisma @prisma/client
npx prisma init
```

### 4. Create Database Infrastructure

```bash
# Create development database
/faber-db:db-create dev

# Create staging database
/faber-db:db-create staging

# Create production database (requires FABER-Cloud)
/faber-db:db-create production
```

### 5. Generate and Deploy Migrations

```bash
# Generate migration from schema changes
/faber-db:generate-migration "initial schema"

# Deploy to dev (automatic)
/faber-db:migrate dev

# Deploy to staging (manual)
/faber-db:migrate staging

# Deploy to production (requires approval)
/faber-db:migrate production
```

## Architecture

### Three-Layer Architecture

```
Commands (Entry Points)
   ↓
Agent (db-manager - Orchestration)
   ↓
Skills (Execution)
   ↓
Scripts (Deterministic Operations)
   ↓
Handlers (Tool-Specific - Prisma, TypeORM, etc.)
```

### Components

**Commands** (`commands/`):
- `/faber-db:init` - Initialize configuration
- `/faber-db:db-create` - Create database infrastructure
- `/faber-db:migrate` - Deploy migrations
- `/faber-db:rollback` - Rollback migrations
- `/faber-db:backup` - Create database backup
- `/faber-db:status` - Check database status

**Agent** (`agents/db-manager.md`):
- Pure router for database operations
- Enforces production safety rules
- Coordinates backups and health checks
- Routes to appropriate skills

**Skills** (`skills/`):
- `db-initializer` - Create database infrastructure
- `migration-generator` - Generate migration files
- `migration-deployer` - Deploy migrations safely
- `rollback-manager` - Handle rollback operations
- `backup-manager` - Create and restore backups
- `health-checker` - Monitor database health
- `handler-db-prisma` - Prisma-specific operations

**Configuration** (`.fractary/plugins/faber-db/config.json`):
- Database provider and hosting settings
- Environment-specific configurations
- Safety rules and approval requirements
- Integration with other plugins

## Usage

### Development Workflow

```bash
# Make schema changes (e.g., edit prisma/schema.prisma)

# Generate migration
/faber-db:generate-migration "add user profiles table"

# Apply to dev (auto-applies)
/faber-db:migrate dev

# Test the changes
npm test

# If tests pass, deploy to staging
/faber-db:migrate staging
```

### Production Deployment

```bash
# Preview changes first
/faber-db:migrate production --dry-run

# Deploy with approval (creates backup automatically)
/faber-db:migrate production
```

You'll see:
```
⚠️  PRODUCTION OPERATION REQUIRES APPROVAL

Operation: migrate
Environment: production
Database: myapp-production

Safeguards:
✓ Backup will be created automatically
✓ Health check will run before deployment
✓ Rollback capability available

Proceed with production migration?
1. Yes, proceed (creates backup first)
2. No, cancel operation
3. Dry-run first (show what would change)
```

### Rollback Operations

```bash
# Rollback last migration
/faber-db:rollback production

# Rollback multiple migrations
/faber-db:rollback production --steps 3

# Rollback to specific migration
/faber-db:rollback production --to 20250120_initial_schema

# Restore from backup
/faber-db:restore production --backup backup-20250124-103000
```

### Backup Management

```bash
# Create manual backup
/faber-db:backup production

# List available backups
/faber-db:backup list production

# Restore from specific backup
/faber-db:restore production --backup backup-20250124-103000
```

### Status and Health

```bash
# Check all environments
/faber-db:status

# Check specific environment
/faber-db:status production

# Run health check
/faber-db:health-check production
```

## Configuration

### Basic Configuration

`.fractary/plugins/faber-db/config.json`:

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
    "production": {
      "connection_string_env": "PROD_DATABASE_URL",
      "auto_migrate": false,
      "backup_before_migrate": true,
      "require_approval": true
    }
  },
  "safety": {
    "protected_environments": ["production"],
    "require_approval_for": ["migrate", "rollback", "seed"],
    "health_check_before_deploy": true
  }
}
```

See [CONFIGURATION.md](./CONFIGURATION.md) for complete configuration options.

## FABER Integration

FABER-DB integrates seamlessly with FABER workflow phases:

### Build Phase
- Generate migrations from code changes
- Apply migrations to dev environment
- Run unit tests against new schema

### Evaluate Phase
- Deploy migrations to staging
- Run integration tests
- Validate data integrity

### Release Phase
- Deploy migrations to production (with approval)
- Create automatic backups
- Monitor health post-deployment
- Update documentation

### Example FABER Configuration

```toml
[workflow.build]
pre_build = ["faber-db:generate-migration auto"]
post_build = ["faber-db:migrate dev"]

[workflow.evaluate]
pre_evaluate = ["faber-db:migrate staging"]

[workflow.release]
pre_release = ["faber-db:migrate production"]
```

## Integration with Other Plugins

### FABER-Cloud Integration

For infrastructure provisioning:
- FABER-Cloud creates database instances (Aurora, RDS)
- FABER-DB manages schema and migrations
- Clear separation: infrastructure vs. data

```bash
# FABER-Cloud creates the database server
/faber-cloud:provision database --env production

# FABER-DB manages the schema
/faber-db:migrate production
```

### Fractary-Work Integration

Link database changes to work items:

```bash
# Create issue for database work
/work:issue-create "Add user profiles table" --type feature

# Generate migration linked to issue
/faber-db:generate-migration "add user profiles" --work-id 123

# Migration includes work item reference in metadata
```

### Fractary-Logs Integration

Complete audit trail of database operations:
- All migrations logged with timestamps
- Backup creation and restoration tracked
- Rollback operations recorded
- Health check results stored

## Security Best Practices

1. **Never commit database credentials**
   - Use environment variables exclusively
   - Add `.env` to `.gitignore`
   - Use secret management services (AWS Secrets Manager, etc.)

2. **Protect production environment**
   - Enable `require_approval` for production
   - Use `protected_environments` setting
   - Require manual backups before destructive ops

3. **Use SSL/TLS connections**
   - Always use `sslmode=require` in connection strings
   - Verify SSL certificates
   - Use VPN or private networks for database access

4. **Implement least privilege**
   - Database user should have minimal necessary permissions
   - Separate users for migrations vs. application runtime
   - Rotate credentials regularly

5. **Audit and monitor**
   - Enable audit logging in database
   - Monitor failed login attempts
   - Track schema changes via logs plugin

## Troubleshooting

### Common Issues

**Configuration not found**:
```bash
Error: FABER-DB plugin not configured
Solution: Run /faber-db:init to create configuration
```

**Connection refused**:
```bash
Error: Database health check failed - connection refused
Solution: Verify DATABASE_URL environment variable is set and database is running
```

**Migration failed**:
```bash
Error: Migration failed - duplicate key constraint
Solution: Review migration file, check for data conflicts, rollback if needed
```

**Backup creation failed**:
```bash
Error: Failed to create backup - insufficient permissions
Solution: Verify AWS credentials have RDS snapshot permissions
```

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for detailed solutions.

## Development

### Adding New Features

Follow the three-layer architecture:
1. Add command in `commands/`
2. Add routing logic in `agents/db-manager.md`
3. Create skill in `skills/{skill-name}/`
4. Implement scripts in `skills/{skill-name}/scripts/`

### Adding New Database Tool

Create a new handler:
1. Create `skills/handler-db-{tool}/` directory
2. Implement SKILL.md with tool-specific operations
3. Create scripts for tool CLI integration
4. Update configuration to support new tool

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for development guidelines.

## Roadmap

### v0.5 (Current - Phases 1-5 Complete)
**Phase 1: Core Structure** ✅ COMPLETE
- ✅ Core plugin structure (directory layout, manifest)
- ✅ Configuration management (config.json schema)
- ✅ db-manager agent with comprehensive routing
- ✅ Init command with interactive setup

**Phase 2: Database Initialization** ✅ COMPLETE
- ✅ db-create command for database creation
- ✅ db-initializer skill with full workflow
- ✅ Config-loader utility for shared configuration
- ✅ Environment validation and safety checks
- ✅ Production approval workflows

**Phase 3: Prisma Integration** ✅ COMPLETE
- ✅ handler-db-prisma skill implementation
- ✅ Prisma CLI integration (create-database script)
- ✅ Schema initialization and migration table setup
- ✅ Prisma Client generation

**Phase 4: Migration Deployment** ✅ COMPLETE
- ✅ migration-deployer skill with comprehensive workflow
- ✅ migrate command with dry-run support
- ✅ generate-migration command for schema changes
- ✅ Prisma apply-migration script (dev and deploy modes)
- ✅ Prisma generate-migration script with preview
- ✅ Pre/post-deployment health check hooks
- ✅ Migration preview (dry-run mode)
- ✅ Production approval workflows
- ✅ Automatic backup coordination

**Phase 5: Backup and Rollback** ✅ COMPLETE
- ✅ backup command for creating database backups
- ✅ rollback command for restoring from backups
- ✅ backup-manager skill for backup orchestration
- ✅ Prisma create-backup script (pg_dump, mysqldump, sqlite3)
- ✅ Prisma restore-backup script with verification
- ✅ Backup metadata tracking (backups.json)
- ✅ Compression support (gzip)
- ✅ Multiple backup formats (SQL, custom, directory)
- ✅ Safety backups before rollback operations
- ✅ Retention management

**Phase 7: Monitoring (Partial)** ✅ COMPLETE
- ✅ Status command for configuration and database checking

**Current Capabilities**:
- Initialize and configure plugin
- Create local development databases
- Initialize Prisma schemas
- Generate migrations from schema changes
- Deploy migrations with safety checks (dev, staging, production)
- Preview migrations before deployment (dry-run)
- **Create database backups (local, compressed)**
- **Rollback migrations using backups**
- **Automatic backups before production migrations**
- **Safety backups before rollback operations**
- Check configuration and database status
- Environment-specific settings (dev, staging, production)
- Production safety (approval prompts, protected environments)

### v0.6 (Next - Phase 6)
**Phase 6: Production Safety** 📋 PLANNED
- 📋 Enhanced approval workflows
- 📋 Automatic backup enforcement
- 📋 Destructive operation detection
- 📋 Audit trail integration

### v0.7 (Planned - Phase 7)
**Phase 7: Complete Monitoring** 📋 PLANNED
- 📋 health-checker skill
- 📋 health-check command
- 📋 Schema drift detection
- 📋 Performance monitoring

### v0.8 (Planned - Phase 8)
**Phase 8: FABER Integration** 📋 PLANNED
- 📋 FABER phase hooks
- 📋 Build phase integration
- 📋 Evaluate phase integration
- 📋 Release phase integration

### v1.0 (Milestone)
**First Stable Release** 🎯 TARGET
- All 8 phases complete
- Production-tested
- Complete documentation
- Migration guides
- Full FABER integration

### v2.0 (Future)
- TypeORM handler
- Sequelize handler
- Knex handler
- Database branching support
- Advanced schema drift handling
- Multi-database support
- Advanced rollback strategies
- Blue-green deployment support

## Resources

- [Configuration Guide](./CONFIGURATION.md) - Detailed configuration options
- [Migration Guide](./MIGRATION-GUIDE.md) - Step-by-step migration workflows
- [Rollback Procedures](./ROLLBACK-PROCEDURES.md) - Recovery procedures
- [Handlers Guide](./HANDLERS.md) - Creating database tool handlers
- [FABER Integration](../../faber/docs/INTEGRATION.md) - FABER workflow integration

## Support

- **Issues**: [GitHub Issues](https://github.com/fractary/claude-plugins/issues)
- **Discussions**: [GitHub Discussions](https://github.com/fractary/claude-plugins/discussions)
- **Documentation**: [Plugin Docs](./README.md)

## License

Part of the Fractary Claude Code Plugins repository.

## Credits

Created as part of the FABER (Frame → Architect → Build → Evaluate → Release) workflow framework for AI-assisted development.
