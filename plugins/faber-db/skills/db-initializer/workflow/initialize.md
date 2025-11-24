# Workflow: Initialize Database

This workflow describes the detailed steps for initializing a new database infrastructure.

## Overview

**Purpose**: Create database infrastructure and initialize schema for a new environment.
**Coordination**: Works with FABER-Cloud for infrastructure, migration tool handler for schema.
**Safety**: Validates environment, checks for existing databases, requires confirmation for production.

## Step 1: Validate Parameters

Check that required parameters are present:
- **environment** (required): Must be one of configured environments (dev, staging, production)
- **database_name** (optional): If not provided, generate from project name + environment

If validation fails, return error response.

## Step 2: Set Working Directory Context

If `working_directory` parameter provided:
```bash
export CLAUDE_DB_CWD="<working_directory>"
```

This ensures all scripts load configuration from the correct project directory.

## Step 3: Load Configuration

Load plugin configuration from `.fractary/plugins/faber-db/config.json`:
- If `CLAUDE_DB_CWD` is set, use it as base directory
- Otherwise, use current directory or git root

Extract configuration:
- Database provider (postgresql, mysql, etc.)
- Hosting platform (aws-aurora, local, etc.)
- Migration tool (prisma, typeorm, etc.)
- Environment settings for specified environment
- Integration settings (cloud_plugin, etc.)

If configuration not found, return error suggesting `/faber-db:init`.

## Step 4: Validate Environment Configuration

Check that the specified environment exists in configuration:
```json
{
  "environments": {
    "dev": { ... },  // ✓ exists
    "staging": { ... },  // ✓ exists
    "production": { ... }  // ✓ exists
  }
}
```

If environment not found, return error.

Extract environment settings:
- `connection_string_env` - Name of environment variable with connection string
- `require_approval` - Whether approval is needed (production typically true)

## Step 5: Verify Environment Variable

Check that the connection string environment variable is set:
```bash
if [ -z "${PROD_DATABASE_URL}" ]; then
  echo "Error: PROD_DATABASE_URL environment variable not set"
  exit 1
fi
```

If not set, return error with instructions to set it.

## Step 6: Production Safety Check

If environment is protected (in `safety.protected_environments`):
1. Display warning message
2. Prompt for confirmation
3. If user declines, return cancelled status

**Example prompt**:
```
⚠️  PRODUCTION OPERATION REQUIRES APPROVAL

Operation: Create Database
Environment: production
Database: myapp-production

This will create a new production database.

Proceed with production database creation?
1. Yes, proceed
2. No, cancel operation

Enter choice:
```

## Step 7: Determine Hosting Type

Check `database.hosting` from configuration:
- **Cloud** (aws-aurora, aws-rds, gcp-sql, azure-sql): Requires infrastructure provisioning
- **Local** (local, localhost): Direct database creation

## Step 8: Check Infrastructure Existence (Cloud Only)

For cloud hosting:
1. Check if database infrastructure already exists
2. Use cloud provider CLI or API (AWS CLI, gcloud, etc.)

**Example for AWS**:
```bash
aws rds describe-db-instances \
  --db-instance-identifier myapp-production \
  --region us-east-1
```

If infrastructure exists:
- Log: "Infrastructure already exists"
- Skip to Step 10 (Schema Initialization)

If infrastructure doesn't exist:
- Continue to Step 9 (Provision Infrastructure)

## Step 9: Provision Infrastructure (Cloud Only, If Needed)

For cloud hosting when infrastructure doesn't exist:

1. **Check FABER-Cloud Plugin**
   - Verify `integration.cloud_plugin` is configured
   - Check if FABER-Cloud plugin is available

2. **Invoke FABER-Cloud**
   ```
   Use FABER-Cloud plugin to provision database infrastructure
   ```

3. **Wait for Infrastructure**
   - Poll for infrastructure readiness
   - Timeout after configured time (default: 10 minutes)

4. **Verify Creation**
   - Check infrastructure is accessible
   - Verify connection endpoint is available

If FABER-Cloud not available or provisioning fails:
- Return error with recovery suggestions
- Suggest manual infrastructure provisioning

## Step 10: Determine Database Name

If `database_name` parameter provided:
- Use provided name

If not provided:
- Generate from project name + environment
- Example: "myapp_dev", "myapp_staging", "myapp_prod"

**Generation logic**:
```bash
PROJECT_NAME=$(basename "$PWD")
DB_NAME="${PROJECT_NAME}_${ENVIRONMENT}"
```

## Step 11: Check Database Existence

Connect to database server and check if database already exists:

**PostgreSQL**:
```bash
psql "$DATABASE_URL" -t -c "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1
```

If database exists:
- Return error: "Database already exists"
- Suggest using existing database or dropping first

If database doesn't exist:
- Continue to Step 12 (Create Database)

## Step 12: Create Database

Invoke migration tool handler to create database:

**Route to handler based on configuration**:
- Prisma: `handler-db-prisma`
- TypeORM: `handler-db-typeorm` (future)
- Sequelize: `handler-db-sequelize` (future)

**Example for Prisma**:
```json
{
  "skill": "handler-db-prisma",
  "operation": "create-database",
  "parameters": {
    "database_name": "myapp_dev",
    "database_url_env": "DEV_DATABASE_URL"
  }
}
```

Handler creates:
- Database schema
- Migration tracking table (e.g., `_prisma_migrations`)
- Initial system tables if needed

## Step 13: Initialize Schema

Run initial schema setup:
1. Create migration directory if doesn't exist
2. Create migration tracking table
3. Record baseline migration (if applicable)

**Example for Prisma**:
```bash
npx prisma migrate dev --name init --skip-generate
```

This creates:
- `prisma/migrations/{timestamp}_init/` directory
- Migration SQL files
- Entry in migration tracking table

## Step 14: Verify Connectivity

Test database connection and basic operations:
```bash
# Test query
psql "$DATABASE_URL" -t -c "SELECT 1"

# Verify migration table exists
psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM _prisma_migrations"
```

If connectivity fails:
- Return error with connection details
- Suggest troubleshooting steps

## Step 15: Health Check

Run basic health checks:
- **Connectivity**: Can connect to database
- **Schema**: Migration table exists and is accessible
- **Permissions**: Can create tables and run queries
- **Disk Space**: Sufficient space available

Record health check results.

## Step 16: Log Operation

If `integration.logs_plugin` is configured:
```json
{
  "log_type": "database_operation",
  "operation": "initialize-database",
  "environment": "dev",
  "database_name": "myapp_dev",
  "status": "success",
  "timestamp": "2025-01-24T10:30:00Z"
}
```

## Step 17: Return Success Response

Return structured JSON with creation results:
```json
{
  "status": "success",
  "operation": "initialize-database",
  "result": {
    "environment": "dev",
    "database_name": "myapp_dev",
    "provider": "postgresql",
    "hosting": "local",
    "infrastructure": "existing",
    "schema_initialized": true,
    "migration_table_created": true,
    "connectivity": "verified",
    "health_check": "passed"
  },
  "message": "Database myapp_dev initialized successfully",
  "next_steps": [
    "Generate initial migration: /faber-db:generate-migration 'initial schema'",
    "Apply migration: /faber-db:migrate dev"
  ]
}
```

## Error Recovery

At each step, if error occurs:
1. Log detailed error information
2. Determine if recoverable
3. Provide specific recovery suggestions
4. Return structured error response
5. Clean up partial changes if possible

## Example Execution

### Success Case (Local Development)

```
Input:
  environment: dev
  database_name: myapp_dev
  working_directory: /mnt/c/GitHub/myorg/myproject

Steps:
  1. ✓ Parameters validated
  2. ✓ Working directory set: CLAUDE_DB_CWD=/mnt/c/GitHub/myorg/myproject
  3. ✓ Configuration loaded from .fractary/plugins/faber-db/config.json
  4. ✓ Environment 'dev' found in configuration
  5. ✓ DEV_DATABASE_URL environment variable exists
  6. ✗ Skip approval (dev not protected)
  7. ✓ Hosting type: local
  8. ✗ Skip infrastructure check (local hosting)
  9. ✗ Skip infrastructure provisioning (local hosting)
  10. ✓ Database name: myapp_dev
  11. ✓ Database doesn't exist
  12. ✓ Database created via handler-db-prisma
  13. ✓ Schema initialized, migration table created
  14. ✓ Connectivity verified
  15. ✓ Health check passed
  16. ✓ Operation logged
  17. ✓ Success response returned

Output:
  {
    "status": "success",
    "result": {
      "database_name": "myapp_dev",
      "environment": "dev",
      "schema_initialized": true
    }
  }
```

### Success Case (Cloud Production)

```
Input:
  environment: production
  working_directory: /mnt/c/GitHub/myorg/myproject

Steps:
  1. ✓ Parameters validated
  2. ✓ Working directory context set
  3. ✓ Configuration loaded
  4. ✓ Environment 'production' found
  5. ✓ PROD_DATABASE_URL exists
  6. ✓ Approval prompted and confirmed
  7. ✓ Hosting type: aws-aurora
  8. ✓ Infrastructure check: Not found
  9. ✓ FABER-Cloud invoked to provision Aurora instance
  10. ✓ Infrastructure ready (waited 5 minutes)
  11. ✓ Database name: myapp_prod
  12. ✓ Database doesn't exist
  13. ✓ Database created via handler-db-prisma
  14. ✓ Schema initialized
  15. ✓ Connectivity verified
  16. ✓ Health check passed
  17. ✓ Operation logged
  18. ✓ Success response returned
```

### Error Case (Infrastructure Missing)

```
Input:
  environment: production

Steps:
  1. ✓ Parameters validated
  2. ✓ Working directory context set
  3. ✓ Configuration loaded
  4. ✓ Environment 'production' found
  5. ✓ PROD_DATABASE_URL exists
  6. ✓ Approval confirmed
  7. ✓ Hosting type: aws-aurora
  8. ✗ Infrastructure check: Not found
  9. ✗ FABER-Cloud plugin not configured
  10. ❌ Cannot provision infrastructure

Error Response:
  {
    "status": "error",
    "error": "Database infrastructure not found and cannot be provisioned",
    "recovery": {
      "suggestions": [
        "Install FABER-Cloud plugin",
        "Configure cloud_plugin in .fractary/plugins/faber-db/config.json",
        "Or manually provision AWS Aurora instance",
        "Or use manual connection to existing infrastructure"
      ]
    }
  }
```
