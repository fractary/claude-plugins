Check database health and detect issues.

This command runs comprehensive health checks on a database environment, including connectivity, migration status, schema drift detection, and basic performance metrics.

## Usage

```bash
/faber-db:health-check <environment> [options]
```

## Arguments

- `<environment>` (required): Environment name (dev, staging, production)

## Options

- `--checks <checks>`: Specific checks to run (comma-separated)
  - `connectivity` - Database connection test
  - `migrations` - Migration status verification
  - `schema` - Schema drift detection
  - `performance` - Basic performance metrics
  - `all` - Run all checks (default)
- `--timeout <seconds>`: Check timeout in seconds (default: 30)
- `--json`: Output results in JSON format

## What It Does

1. **Connectivity Check**
   - Tests database connection
   - Measures latency
   - Verifies credentials
   - Checks network accessibility

2. **Migration Status Check**
   - Verifies migration table exists
   - Counts applied migrations
   - Counts pending migrations
   - Detects failed migrations

3. **Schema Drift Check**
   - Compares Prisma schema with database
   - Detects manual database changes
   - Identifies missing/extra tables
   - Identifies missing/extra columns

4. **Performance Check** (Basic)
   - Average query time
   - Connection pool usage
   - Active connections
   - Identifies slow queries

5. **Reports Results**
   - Overall health status (healthy/degraded/unhealthy)
   - Individual check results
   - Issues found with severity
   - Actionable recommendations

## Examples

### Check All Health Metrics

```bash
/faber-db:health-check production
```

Output:
```
═══════════════════════════════════════
  FABER-DB: Database Health Check
═══════════════════════════════════════

Environment: production
Database: myapp_prod
Provider: PostgreSQL

Running Health Checks...

✓ Connectivity Check
  Status: Healthy
  Latency: 25ms
  Connection: Successful

✓ Migration Status Check
  Status: Healthy
  Applied: 24 migrations
  Pending: 0 migrations
  Last Migration: 20250124130000_add_api_keys

✓ Schema Drift Check
  Status: Healthy
  Drift Detected: No
  Schema Matches Database: Yes

✓ Performance Check
  Status: Healthy
  Avg Query Time: 15ms
  Connection Pool: 45% utilized
  Active Connections: 18/40

═══════════════════════════════════════
✅ OVERALL STATUS: HEALTHY

All checks passed. Database is operating normally.
═══════════════════════════════════════
```

### Check Specific Metrics

```bash
/faber-db:health-check production --checks connectivity,migrations
```

Output:
```
Running Health Checks: connectivity, migrations

✓ Connectivity: Healthy (25ms)
✓ Migrations: Healthy (24 applied, 0 pending)

✅ OVERALL STATUS: HEALTHY
```

### Degraded Database (Schema Drift)

```bash
/faber-db:health-check production
```

Output:
```
Running Health Checks...

✓ Connectivity Check
  Status: Healthy
  Latency: 28ms

✓ Migration Status Check
  Status: Healthy
  Applied: 24 migrations
  Pending: 0 migrations

⚠️  Schema Drift Check
  Status: Degraded
  Drift Detected: Yes

  Issues Found:
    • Manual column added: users.last_login_ip
      Database has column not in Prisma schema

    • Missing column: posts.featured
      Prisma schema has column not in database

═══════════════════════════════════════
⚠️  OVERALL STATUS: DEGRADED

Issues Detected: 2 warnings

Recommendations:
  1. Sync Prisma schema with database:
     npx prisma db pull

  2. Or create migration to sync schema:
     /faber-db:generate-migration "sync schema"

  3. Review manual database changes and update schema
═══════════════════════════════════════
```

### Unhealthy Database (Connection Failed)

```bash
/faber-db:health-check production
```

Output:
```
Running Health Checks...

✗ Connectivity Check
  Status: Unhealthy
  Error: Connection refused
  Details: Cannot connect to prod-db:5432

⚠️  Migration Status Check
  Status: Not Checked
  Reason: No database connection

⚠️  Schema Drift Check
  Status: Not Checked
  Reason: No database connection

═══════════════════════════════════════
✗ OVERALL STATUS: UNHEALTHY

Critical Issues: 1

Issue: Cannot connect to database
  Error: Connection refused at prod-db:5432

Recommendations:
  1. Verify database is running:
     docker ps | grep postgres

  2. Check connection string:
     echo $PROD_DATABASE_URL

  3. Test manual connection:
     psql $PROD_DATABASE_URL

  4. Check firewall rules and VPN access

  5. Verify network connectivity:
     ping prod-db
═══════════════════════════════════════
```

### Pending Migrations Warning

```bash
/faber-db:health-check staging
```

Output:
```
Running Health Checks...

✓ Connectivity: Healthy (32ms)

⚠️  Migration Status Check
  Status: Degraded
  Applied: 22 migrations
  Pending: 2 migrations

  Pending Migrations:
    1. 20250124140000_add_user_profiles
    2. 20250124150000_add_posts_table

⚠️  OVERALL STATUS: DEGRADED

Recommendations:
  1. Review pending migrations
  2. Apply migrations: /faber-db:migrate staging
  3. Or preview first: /faber-db:migrate staging --dry-run
```

### JSON Output

```bash
/faber-db:health-check production --json
```

Output:
```json
{
  "status": "success",
  "environment": "production",
  "overall_status": "healthy",
  "checks": {
    "connectivity": {
      "status": "healthy",
      "latency_ms": 25,
      "message": "Database connection successful"
    },
    "migrations": {
      "status": "healthy",
      "applied": 24,
      "pending": 0,
      "last_migration": "20250124130000_add_api_keys"
    },
    "schema": {
      "status": "healthy",
      "drift_detected": false
    },
    "performance": {
      "status": "healthy",
      "avg_query_time_ms": 15,
      "connection_pool_usage": "45%"
    }
  },
  "issues": [],
  "recommendations": []
}
```

## Health Status Levels

### Healthy ✅
- All checks passed
- No issues detected
- Database operating normally
- Safe to deploy migrations

### Degraded ⚠️
- Minor issues detected
- Operations can proceed with caution
- Examples:
  - Schema drift detected
  - Pending migrations
  - High latency (but connected)
  - Performance degradation

### Unhealthy ✗
- Critical issues detected
- Operations should not proceed
- Examples:
  - Database unreachable
  - Connection failed
  - Migration table corrupted
  - Critical performance issues

## Check Details

### Connectivity Check

Tests database connection and measures latency.

**Healthy**: Connection successful, latency < 100ms
**Degraded**: Connection successful, latency 100-500ms
**Unhealthy**: Connection failed or latency > 500ms

### Migration Status Check

Verifies migration table and counts applied/pending migrations.

**Healthy**: Migration table accessible, no pending migrations
**Degraded**: Pending migrations exist (warning)
**Unhealthy**: Migration table corrupted or inaccessible

### Schema Drift Check

Compares Prisma schema definition with actual database schema.

**Healthy**: Schema matches database exactly
**Degraded**: Minor drift detected (extra/missing columns)
**Unhealthy**: Major drift detected (missing tables, type mismatches)

### Performance Check

Basic performance metrics and connection pool status.

**Healthy**: Avg query time < 50ms, pool < 80%
**Degraded**: Avg query time 50-200ms, pool 80-95%
**Unhealthy**: Avg query time > 200ms, pool > 95%

## Integration with Operations

### Pre-Migration Health Check

Automatically runs before migration deployment:

```bash
/faber-db:migrate production

# Internally:
# 1. health-checker: check connectivity + migrations
# 2. If unhealthy: block deployment
# 3. If degraded: warn user
# 4. If healthy: proceed with migration
```

### Post-Migration Health Check

Automatically runs after migration deployment:

```bash
# After successful migration:
# 1. health-checker: check connectivity + migrations + schema
# 2. If unhealthy: trigger rollback (if configured)
# 3. If degraded: warn user
# 4. If healthy: deployment successful
```

### Pre-Rollback Health Check

Before rollback operation:

```bash
/faber-db:rollback production

# Internally:
# 1. health-checker: verify backup exists
# 2. health-checker: check current database state
# 3. If unhealthy: warn about rollback risks
```

## Scheduled Health Checks (Future)

Configure periodic health checks:

```json
{
  "health_checks": {
    "schedule": "*/30 * * * *",  // Every 30 minutes
    "notify_on": ["degraded", "unhealthy"],
    "notification_channels": ["slack", "email"]
  }
}
```

## Troubleshooting

### Connection Timeout

```
✗ Connectivity: Connection timeout after 30s

Solutions:
  1. Increase timeout: /faber-db:health-check dev --timeout 60
  2. Check database is running
  3. Verify network connectivity
```

### Schema Drift Confusion

```
⚠️  Schema drift detected but unsure why

What to do:
  1. Compare schema manually:
     npx prisma migrate diff \
       --from-schema-datamodel prisma/schema.prisma \
       --to-schema-datasource prisma/schema.prisma

  2. Pull current database schema:
     npx prisma db pull

  3. Review differences and decide:
     - Keep database changes: Update Prisma schema
     - Keep Prisma changes: Create migration
```

### High Latency

```
⚠️  Performance degraded: avg query time 150ms

Solutions:
  1. Check for long-running queries
  2. Analyze slow query log
  3. Consider adding indexes
  4. Review connection pool settings
  5. Check database server resources
```

## Exit Codes

- **0**: Healthy - all checks passed
- **1**: Configuration errors
- **2**: Degraded - warnings detected
- **3**: Unhealthy - critical issues detected

## See Also

Related commands:
- `/faber-db:status` - Check configuration and setup
- `/faber-db:migrate` - Deploy migrations (with health checks)
- `/faber-db:rollback` - Rollback migrations (with health checks)

Documentation:
- `docs/README.md` - Plugin overview
- `docs/MONITORING.md` - Monitoring and alerting guide
- `docs/TROUBLESHOOTING.md` - Troubleshooting procedures
