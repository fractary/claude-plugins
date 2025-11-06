---
title: "Runbook: Database Maintenance"
type: runbook
date: "2025-01-14"
status: approved
author: "Platform Team"
tags: ["database", "operations", "maintenance"]
related:
  - "../designs/database-architecture.md"
  - "./database-failover.md"
---

# Database Maintenance Runbook

## Purpose

Regular maintenance procedures for PostgreSQL databases to ensure optimal performance, reliability, and disk space management.

**Frequency**: Weekly (automated) and Monthly (manual tasks)

**Expected Time**: 15-30 minutes for weekly; 1-2 hours for monthly

**Risk Level**: LOW (during maintenance window)

## Prerequisites

### Access Requirements
- Database admin credentials
- AWS RDS console access
- Monitoring dashboard access

### Tools
```bash
psql --version      # PostgreSQL client 15+
aws --version       # AWS CLI v2
```

## Weekly Maintenance (Automated)

These tasks run automatically via cron jobs but should be verified:

### 1. Vacuum and Analyze

**What it does**: Reclaims space and updates statistics

**Schedule**: Sunday 02:00 UTC

**Verification**:
```bash
# Check last vacuum times
psql -h prod-postgres-primary.xxx.rds.amazonaws.com -U app_admin -d main -c "
  SELECT
    schemaname,
    tablename,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
  FROM pg_stat_user_tables
  WHERE schemaname IN ('users', 'finance', 'content')
  ORDER BY last_autovacuum DESC NULLS LAST
  LIMIT 20;
"
```

**Expected**: All tables vacuumed within last 7 days

### 2. Index Maintenance

**What it does**: Updates index statistics

**Verification**:
```bash
# Check index usage
psql -h prod-postgres-primary.xxx.rds.amazonaws.com -U app_admin -d main -c "
  SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
  FROM pg_stat_user_indexes
  WHERE schemaname IN ('users', 'finance', 'content')
  ORDER BY idx_scan DESC
  LIMIT 20;
"
```

### 3. Slow Query Review

**What it does**: Identifies queries needing optimization

**Check logs**:
```bash
# Review CloudWatch Logs Insights
# Query: fields @timestamp, @message | filter @message like /duration/ | sort @timestamp desc | limit 20

# Or via RDS CLI
aws rds download-db-log-file-portion \
  --db-instance-identifier prod-postgres-primary \
  --log-file-name error/postgresql.log.2025-01-14-00 \
  --output text | grep "duration:" | sort -t: -k2 -nr | head -20
```

**Action**: Document slow queries for optimization

## Monthly Maintenance (Manual)

### 1. Disk Space Check

**Schedule**: First Monday of month

```bash
# Check database size
psql -h prod-postgres-primary.xxx.rds.amazonaws.com -U app_admin -d main -c "
  SELECT
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
  FROM pg_database
  ORDER BY pg_database_size(pg_database.datname) DESC;
"

# Check table sizes
psql -h prod-postgres-primary.xxx.rds.amazonaws.com -U app_admin -d main -c "
  SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) -
                   pg_relation_size(schemaname||'.'||tablename)) AS index_size
  FROM pg_tables
  WHERE schemaname IN ('users', 'finance', 'content')
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
  LIMIT 20;
"
```

**Threshold**: Alert if disk usage > 70%

### 2. Connection Pool Health

```bash
# Check PgBouncer stats
kubectl exec -n production deployment/pgbouncer -- \
  psql -p 6432 -U pgbouncer pgbouncer -c "
    SHOW STATS;
  "

# Check for connection leaks
psql -h prod-postgres-primary.xxx.rds.amazonaws.com -U app_admin -d main -c "
  SELECT
    datname,
    usename,
    application_name,
    COUNT(*) as connection_count,
    MAX(state) as state
  FROM pg_stat_activity
  GROUP BY datname, usename, application_name
  ORDER BY connection_count DESC;
"
```

**Expected**: No single app instance > 50 connections

### 3. Replication Health

```bash
# Check replication lag
psql -h prod-postgres-primary.xxx.rds.amazonaws.com -U app_admin -d main -c "
  SELECT
    application_name,
    client_addr,
    state,
    sync_state,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes,
    EXTRACT(EPOCH FROM (NOW() - pg_last_xact_replay_timestamp())) AS lag_seconds
  FROM pg_stat_replication;
"
```

**Threshold**: Alert if lag > 10MB or 5 seconds

### 4. Backup Verification

```bash
# Check recent backups
aws rds describe-db-snapshots \
  --db-instance-identifier prod-postgres-primary \
  --query 'DBSnapshots[?SnapshotCreateTime>=`2025-01-01`].[DBSnapshotIdentifier,SnapshotCreateTime,Status,PercentProgress]' \
  --output table

# Verify S3 WAL archives
aws s3 ls s3://prod-postgres-wal-archive/ \
  --recursive | tail -20
```

**Action**: Confirm daily backups completing successfully

### 5. Security Review

```bash
# Check user permissions
psql -h prod-postgres-primary.xxx.rds.amazonaws.com -U app_admin -d main -c "
  SELECT
    grantee,
    table_schema,
    table_name,
    STRING_AGG(privilege_type, ', ') as privileges
  FROM information_schema.table_privileges
  WHERE table_schema IN ('users', 'finance', 'content')
  GROUP BY grantee, table_schema, table_name
  ORDER BY grantee, table_schema, table_name;
"

# Review password age (from Secrets Manager)
aws secretsmanager describe-secret \
  --secret-id prod/postgres/app_user \
  --query '[SecretName,LastChangedDate]' \
  --output table
```

**Action**: Rotate credentials if > 90 days old

## Quarterly Tasks

### 1. Major Index Rebuild

**When**: Last Sunday of quarter, 02:00 UTC

```bash
# Rebuild indexes on large tables
psql -h prod-postgres-primary.xxx.rds.amazonaws.com -U app_admin -d main -c "
  REINDEX TABLE CONCURRENTLY users.accounts;
  REINDEX TABLE CONCURRENTLY finance.transactions;
  REINDEX TABLE CONCURRENTLY content.posts;
"
```

### 2. Performance Benchmark

```bash
# Run pgbench
pgbench -h prod-postgres-primary.xxx.rds.amazonaws.com \
  -U app_user -d main \
  -c 10 -j 2 -T 60 -S

# Record results for trending
```

### 3. Capacity Planning Review

- Review growth trends
- Forecast 6-month capacity needs
- Plan scaling actions if needed

## Monitoring Dashboards

Access dashboards:
- **CloudWatch**: RDS Performance Insights
- **Datadog**: Database Overview
- **Custom**: Grafana PostgreSQL Dashboard

**Key Metrics**:
- CPU utilization: Target < 70%
- Connection count: Target < 250
- Replication lag: Target < 100ms
- Disk IOPS: Monitor burst balance
- Cache hit ratio: Target > 99%

## Troubleshooting

### High Connection Count

```bash
# Identify connection sources
psql -h prod-postgres-primary.xxx.rds.amazonaws.com -U app_admin -d main -c "
  SELECT
    client_addr,
    usename,
    datname,
    COUNT(*) as connections,
    array_agg(DISTINCT state) as states
  FROM pg_stat_activity
  WHERE state != 'idle'
  GROUP BY client_addr, usename, datname
  ORDER BY connections DESC;
"

# Action: Scale PgBouncer or kill idle connections
```

### Table Bloat

```bash
# Check for bloat
psql -h prod-postgres-primary.xxx.rds.amazonaws.com -U app_admin -d main -c "
  SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    n_dead_tup,
    n_live_tup,
    ROUND(100 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) as dead_ratio
  FROM pg_stat_user_tables
  WHERE n_dead_tup > 1000
  ORDER BY n_dead_tup DESC;
"

# Action: Manual VACUUM FULL during maintenance window if dead_ratio > 20%
```

## Emergency Contacts

- **On-Call Engineer**: PagerDuty
- **Database Team**: #team-platform
- **AWS Support**: Enterprise ticket

## References

- [Database Architecture](../designs/database-architecture.md)
- [Database Failover Runbook](./database-failover.md)
- [PostgreSQL Maintenance Guide](https://www.postgresql.org/docs/15/maintenance.html)

## Revision History

- **2025-01-14**: Initial version
- Last maintenance run: [auto-updated]
