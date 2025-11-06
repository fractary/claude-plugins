---
title: "ADR-001: Use PostgreSQL for Primary Database"
type: adr
number: 1
date: "2025-01-10"
status: accepted
author: "Engineering Team"
tags: ["database", "infrastructure"]
related:
  - "../designs/database-architecture.md"
---

# ADR-001: Use PostgreSQL for Primary Database

## Status

**Accepted** - January 10, 2025

## Context

We need to select a primary database for our application. The system requirements include:

- ACID compliance for financial transactions
- Complex querying capabilities
- Good performance at scale (expected 100k+ users)
- Strong community support and ecosystem
- Cloud-native deployment options

Key considerations:
- Must support relational data modeling
- Need for JSON document storage capabilities
- Requirement for full-text search
- Team has mixed experience with SQL databases

## Decision

We will use **PostgreSQL** as our primary database system.

PostgreSQL 15+ will be deployed using managed services (AWS RDS) in production, with local Docker containers for development.

## Consequences

### Positive

- **ACID Compliance**: PostgreSQL provides strong ACID guarantees for our financial transactions
- **JSON Support**: Native JSONB type allows flexible schema alongside relational data
- **Performance**: Proven performance characteristics at our expected scale
- **Ecosystem**: Rich extension ecosystem (PostGIS, pg_trgm for search, TimescaleDB for time-series)
- **Team Knowledge**: Several team members have PostgreSQL experience
- **Cloud Support**: Excellent managed service options (RDS, Cloud SQL, Azure Database)

### Negative

- **Learning Curve**: Team members familiar with MySQL will need to learn PostgreSQL-specific features
- **Operational Complexity**: More complex to tune and optimize compared to simpler databases
- **Resource Usage**: Higher memory requirements than some alternatives
- **Vendor Lock-in**: Using RDS-specific features could create cloud provider lock-in

### Risks

- **Scaling Challenges**: May need to implement read replicas and connection pooling at scale
- **Migration Complexity**: Schema migrations require careful planning and testing
- **Backup/Recovery**: Need robust backup strategy and tested recovery procedures

## Alternatives Considered

### MySQL
- **Pros**: Team familiarity, simpler operations, slightly faster for simple queries
- **Cons**: Weaker JSON support, fewer advanced features, less consistent behavior across storage engines
- **Rejected**: PostgreSQL's feature set better matches our needs

### MongoDB
- **Pros**: Schema flexibility, horizontal scaling, document model
- **Cons**: No ACID transactions across documents (in older versions), eventual consistency challenges, different query paradigm
- **Rejected**: Financial transactions require strong ACID guarantees

### Amazon Aurora
- **Pros**: AWS-native, auto-scaling, excellent performance
- **Cons**: Vendor lock-in, higher cost, PostgreSQL compatibility layer has quirks
- **Deferred**: Considered for future optimization, not for initial launch

## Implementation

This decision will be implemented through:

1. Database architecture design (see [Database Architecture](../designs/database-architecture.md))
2. Development environment setup with Docker Compose
3. RDS instance provisioning in production
4. Schema migration strategy using Flyway
5. Connection pooling configuration (PgBouncer)

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [AWS RDS for PostgreSQL](https://aws.amazon.com/rds/postgresql/)
- Database Architecture Design Document (linked above)

## Review Notes

- Reviewed by: Architecture Team
- Approved by: CTO
- Implementation tracked in: JIRA-123
