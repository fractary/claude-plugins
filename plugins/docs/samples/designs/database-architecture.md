---
title: "Design: Database Architecture"
type: design
date: "2025-01-12"
updated: "2025-01-15"
status: approved
author: "Platform Team"
tags: ["database", "architecture", "postgresql"]
related:
  - "../adrs/ADR-001-postgresql.md"
  - "../runbooks/database-maintenance.md"
  - "../runbooks/database-failover.md"
---

# Database Architecture

## Overview

This document describes the database architecture for our application, implementing the decision to use PostgreSQL (see [ADR-001](../adrs/ADR-001-postgresql.md)).

**Key Design Goals**:
- High availability (99.9% uptime)
- Horizontal read scalability
- Disaster recovery capability
- Zero-downtime migrations
- Multi-region support (future)

## Architecture

### High-Level Diagram

```
                    ┌─────────────────┐
                    │  Application    │
                    │    Servers      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   PgBouncer     │
                    │ (Connection     │
                    │   Pooling)      │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
       ┌────▼─────┐    ┌────▼─────┐    ┌────▼─────┐
       │ Primary  │    │ Replica  │    │ Replica  │
       │   (RW)   │───▶│   (RO)   │    │   (RO)   │
       └──────────┘    └──────────┘    └──────────┘
            │
       ┌────▼─────┐
       │  S3 WAL  │
       │  Archive │
       └──────────┘
```

### Components

#### Primary Database
- **Type**: PostgreSQL 15.4 on AWS RDS
- **Instance**: db.r6g.xlarge (4 vCPU, 32 GB RAM)
- **Storage**: 500 GB GP3 SSD (3000 IOPS)
- **Availability**: Multi-AZ deployment for automatic failover
- **Purpose**: Handles all write operations and consistent reads

#### Read Replicas
- **Count**: 2 replicas across availability zones
- **Instance**: db.r6g.large (2 vCPU, 16 GB RAM)
- **Replication**: Asynchronous streaming replication
- **Lag**: Target < 100ms average
- **Purpose**: Distributes read load, provides read-after-write consistency

#### Connection Pooler (PgBouncer)
- **Deployment**: Kubernetes deployment (3 replicas)
- **Mode**: Transaction pooling
- **Max Connections**: 100 per instance (300 total)
- **Purpose**: Manages connection overhead, enables more application connections than database can handle

#### WAL Archiving
- **Storage**: S3 bucket with lifecycle policies
- **Retention**: 30 days
- **Purpose**: Point-in-time recovery (PITR)

## Database Schema

### Core Schema Organization

```sql
-- Application schemas
CREATE SCHEMA users;      -- User accounts and authentication
CREATE SCHEMA finance;    -- Financial transactions and accounts
CREATE SCHEMA content;    -- User-generated content
CREATE SCHEMA analytics;  -- Reporting and analytics

-- System schemas
CREATE SCHEMA audit;      -- Audit logging
CREATE SCHEMA jobs;       -- Background job queue
```

### Key Tables

#### users.accounts
```sql
CREATE TABLE users.accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_accounts_email ON users.accounts(email);
CREATE INDEX idx_accounts_metadata ON users.accounts USING GIN(metadata);
```

#### finance.transactions
```sql
CREATE TABLE finance.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES users.accounts(id),
  amount DECIMAL(19, 4) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  type VARCHAR(50) NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_transactions_account ON finance.transactions(account_id);
CREATE INDEX idx_transactions_status ON finance.transactions(status) WHERE status != 'completed';
CREATE INDEX idx_transactions_created ON finance.transactions(created_at DESC);
```

### Schema Conventions

- **Primary Keys**: UUID v4 by default
- **Timestamps**: All tables include `created_at` and `updated_at` (TIMESTAMPTZ)
- **Soft Deletes**: Use `deleted_at TIMESTAMPTZ` for soft deletion
- **Metadata**: JSONB column for extensibility
- **Naming**: snake_case for all identifiers

## Data Management

### Migrations

**Tool**: Flyway

**Process**:
1. Migrations versioned as `V{version}__{description}.sql`
2. All migrations must be reversible (provide rollback script)
3. Migrations run automatically on deployment
4. Large migrations use online schema change tools (pg_repack)

**Example**:
```
migrations/
├── V001__create_users_schema.sql
├── V002__create_finance_schema.sql
├── V003__add_user_preferences.sql
└── rollback/
    ├── R001__drop_users_schema.sql
    └── R003__remove_user_preferences.sql
```

### Backups

**Automated Backups**:
- Full backup: Daily at 03:00 UTC
- WAL archiving: Continuous
- Retention: 30 days
- Storage: Encrypted S3 bucket

**Manual Backups**:
- Before major releases
- Before large data operations
- On-demand via runbook

**Recovery Time Objective (RTO)**: 1 hour
**Recovery Point Objective (RPO)**: 5 minutes

See [Database Failover Runbook](../runbooks/database-failover.md) for recovery procedures.

### Monitoring

**Metrics Collected**:
- Connection count and pool utilization
- Query performance (slow query log)
- Replication lag
- Disk I/O and space utilization
- Cache hit ratio
- Active queries and locks

**Alerting Thresholds**:
- Replication lag > 5 seconds
- Connection pool > 80% utilized
- Disk space > 85% used
- Slow queries > 5 seconds
- Failed connections spike

## Performance Optimization

### Indexing Strategy

**Guidelines**:
- Index foreign keys
- Index columns in WHERE clauses for frequent queries
- Use partial indexes for filtered queries
- Compound indexes for multi-column lookups
- GIN indexes for JSONB and full-text search

**Index Maintenance**:
- REINDEX on large tables monthly
- Analyze statistics weekly
- Monitor index bloat

### Query Optimization

**Connection Pooling**:
- PgBouncer in transaction mode
- Application connection pool: 20 connections per instance
- Database max connections: 300

**Read/Write Splitting**:
```python
# Application code pattern
@read_only
def get_user(user_id):
    # Routes to read replica
    return db.replica.query(...)

@transactional
def update_user(user_id, data):
    # Routes to primary
    return db.primary.query(...)
```

**Caching**:
- Redis cache for frequently accessed data
- Cache TTL: 5 minutes for volatile data, 1 hour for stable data
- Cache-aside pattern with read-through

### Query Performance

**Optimization Techniques**:
- Use `EXPLAIN ANALYZE` for slow queries
- Avoid N+1 queries with joins or batching
- Use CTEs for complex queries
- Limit result sets with pagination
- Materialized views for expensive aggregations

## Security

### Access Control

**Roles**:
```sql
-- Application role (limited privileges)
CREATE ROLE app_user WITH LOGIN PASSWORD '...';
GRANT CONNECT ON DATABASE main TO app_user;
GRANT USAGE ON SCHEMA users, finance, content TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA users TO app_user;

-- Read-only role (analytics)
CREATE ROLE app_readonly WITH LOGIN PASSWORD '...';
GRANT CONNECT ON DATABASE main TO app_readonly;
GRANT USAGE ON SCHEMA users, finance, content, analytics TO app_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA users, finance, content TO app_readonly;

-- Admin role (migrations and maintenance)
CREATE ROLE app_admin WITH LOGIN PASSWORD '...';
GRANT ALL PRIVILEGES ON DATABASE main TO app_admin;
```

### Encryption

- **At Rest**: AWS RDS encryption enabled (AES-256)
- **In Transit**: SSL/TLS required for all connections
- **Credentials**: Stored in AWS Secrets Manager, rotated every 90 days

### Audit Logging

- All DML operations logged to `audit.audit_log` table
- Trigger-based audit trail for sensitive tables
- Logs retained for 1 year

## Disaster Recovery

### Failure Scenarios

**Primary Failure**:
1. RDS Multi-AZ automatic failover (< 2 minutes)
2. DNS update to new primary
3. Application reconnects automatically

**Region Failure**:
1. Manual failover to secondary region (planned for Phase 2)
2. Restore from S3 WAL archives
3. Data loss: < 5 minutes (RPO)

**Data Corruption**:
1. Point-in-time recovery from backups
2. Restore to temporary instance
3. Validate and migrate data

See [Database Failover Runbook](../runbooks/database-failover.md) for detailed procedures.

## Scalability Plan

### Current Capacity

- **Write Throughput**: ~5,000 transactions/second
- **Read Throughput**: ~20,000 queries/second (across replicas)
- **Storage**: 500 GB provisioned, ~100 GB used
- **Headroom**: 5x current load

### Scaling Strategy

**Vertical Scaling** (short-term):
- Upgrade instance types (db.r6g.2xlarge)
- Increase IOPS allocation

**Horizontal Scaling** (medium-term):
- Add more read replicas (up to 5)
- Implement read/write splitting at application layer

**Sharding** (long-term, if needed):
- Shard by user_id or tenant_id
- Use Citus or manual sharding
- Implement at 80% capacity threshold

## Testing Strategy

### Performance Testing
- Load testing with 10x expected traffic
- Chaos engineering with instance failures
- Replication lag testing under load

### Disaster Recovery Testing
- Quarterly failover drills
- Annual full recovery from backup test
- Document lessons learned

## Operational Runbooks

- [Database Maintenance](../runbooks/database-maintenance.md) - Regular maintenance tasks
- [Database Failover](../runbooks/database-failover.md) - Emergency failover procedures
- Database Backup Restore (TODO)
- Database Migration (TODO)

## Future Enhancements

- **Multi-region Replication**: Cross-region read replicas for global performance
- **Read Replica Auto-scaling**: Dynamic replica scaling based on load
- **Query Performance Insights**: Enhanced monitoring and recommendations
- **Logical Replication**: For multi-tenant data isolation
- **TimescaleDB Extension**: For time-series analytics workloads

## References

- [ADR-001: PostgreSQL Selection](../adrs/ADR-001-postgresql.md)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/15/)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [PgBouncer Documentation](https://www.pgbouncer.org/usage.html)

## Change History

- **2025-01-15**: Updated replication lag targets, added monitoring thresholds
- **2025-01-12**: Initial version based on ADR-001
