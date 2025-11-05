---
title: "Runbook: Database Failover"
type: runbook
date: "2025-01-13"
status: approved
author: "Platform Team"
tags: ["database", "operations", "incident-response"]
related:
  - "../designs/database-architecture.md"
  - "../adrs/ADR-001-postgresql.md"
---

# Database Failover Runbook

## Purpose

This runbook provides step-by-step procedures for handling database failover scenarios in our PostgreSQL infrastructure. Use this guide during primary database failures, planned maintenance, or disaster recovery scenarios.

**Expected Time**: 15-30 minutes for automatic failover verification; 1-2 hours for manual failover

**Risk Level**: HIGH - Impacts all application functionality

## Prerequisites

### Access Requirements
- AWS Console access with RDS permissions
- Database admin credentials (from AWS Secrets Manager)
- PagerDuty escalation rights
- Kubernetes cluster access (for PgBouncer management)

### Knowledge Requirements
- Understanding of PostgreSQL replication
- Familiarity with AWS RDS Multi-AZ
- Basic PostgreSQL administration
- Application architecture knowledge

### Tools Required
```bash
# Install required CLI tools
aws --version        # AWS CLI v2
kubectl version      # Kubernetes CLI
psql --version       # PostgreSQL client 15+
```

## Scenarios

### Scenario 1: Automatic Multi-AZ Failover

**When**: Primary database instance fails, RDS automatically fails over to standby

**Detection**:
- CloudWatch alarm: "RDS-Primary-Unreachable"
- PagerDuty alert: "Database primary instance failure"
- Application logs: Connection timeout errors

**Steps**:

1. **Acknowledge Alert**
   ```bash
   # Acknowledge PagerDuty incident
   # Record incident start time
   INCIDENT_START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   echo "Incident started: $INCIDENT_START"
   ```

2. **Verify Automatic Failover**
   ```bash
   # Check RDS instance status
   aws rds describe-db-instances \
     --db-instance-identifier prod-postgres-primary \
     --query 'DBInstances[0].[DBInstanceStatus,AvailabilityZone,Endpoint.Address]' \
     --output table

   # Expected: Status "available", new AZ, same endpoint
   ```

3. **Monitor Replication Lag**
   ```bash
   # Connect to new primary and check replicas
   psql -h prod-postgres-primary.xxx.rds.amazonaws.com -U app_admin -d main

   # Check replication status
   SELECT
     client_addr,
     state,
     sync_state,
     EXTRACT(EPOCH FROM (NOW() - backend_start)) AS seconds_connected,
     pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes
   FROM pg_stat_replication;

   -- Expected: All replicas in 'streaming' state with lag_bytes < 1000000
   ```

4. **Verify Application Connectivity**
   ```bash
   # Check PgBouncer connection pool status
   kubectl exec -n production deployment/pgbouncer -- \
     psql -p 6432 -U pgbouncer pgbouncer -c "SHOW POOLS;"

   # Expected: cl_active and sv_active > 0, no connection errors
   ```

5. **Test Read/Write Operations**
   ```bash
   # Test write to primary
   psql -h prod-postgres-primary.xxx.rds.amazonaws.com -U app_user -d main -c \
     "INSERT INTO audit.health_check (check_time) VALUES (NOW()) RETURNING *;"

   # Test read from replica
   psql -h prod-postgres-replica-1.xxx.rds.amazonaws.com -U app_readonly -d main -c \
     "SELECT COUNT(*) FROM users.accounts;"
   ```

6. **Monitor Application Metrics**
   ```bash
   # Check error rates in Datadog/CloudWatch
   # Expected: Error rate returns to baseline within 5 minutes

   # Check transaction success rate
   # Expected: > 99.9% success rate
   ```

7. **Document Incident**
   ```bash
   # Create incident report
   cat > incident-report-$INCIDENT_START.md <<EOF
   # Database Failover Incident

   **Start Time**: $INCIDENT_START
   **End Time**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
   **Duration**: [calculated]
   **Impact**: [describe]
   **Root Cause**: Primary instance failure (automatic Multi-AZ failover)
   **Resolution**: Automatic failover completed successfully

   ## Timeline
   - [timestamp]: Alert triggered
   - [timestamp]: Failover initiated by RDS
   - [timestamp]: Failover completed
   - [timestamp]: Application connectivity verified
   - [timestamp]: Incident resolved

   ## Follow-up Actions
   - [ ] Review CloudWatch logs for root cause
   - [ ] Check for disk space or performance issues
   - [ ] Update monitoring thresholds if needed
   EOF
   ```

### Scenario 2: Manual Failover for Maintenance

**When**: Planned maintenance requires primary instance restart or update

**Detection**: Scheduled maintenance window

**Steps**:

1. **Pre-Maintenance Checklist**
   ```bash
   # Verify backup exists
   aws rds describe-db-snapshots \
     --db-instance-identifier prod-postgres-primary \
     --query 'DBSnapshots[0].[DBSnapshotIdentifier,SnapshotCreateTime,Status]'

   # Create manual backup if needed
   aws rds create-db-snapshot \
     --db-instance-identifier prod-postgres-primary \
     --db-snapshot-identifier manual-pre-maintenance-$(date +%Y%m%d-%H%M)
   ```

2. **Notify Stakeholders**
   ```bash
   # Post maintenance notification
   # Slack: #incidents channel
   # Status page: maintenance mode

   echo "MAINTENANCE WINDOW: Starting database failover at $(date)"
   ```

3. **Scale Up Application Retry Logic** (Optional)
   ```bash
   # Increase connection timeout and retry attempts
   kubectl set env deployment/api -n production \
     DB_CONNECT_TIMEOUT=30 \
     DB_MAX_RETRIES=5
   ```

4. **Initiate Failover**
   ```bash
   # Trigger manual failover
   aws rds reboot-db-instance \
     --db-instance-identifier prod-postgres-primary \
     --force-failover

   # Monitor status
   watch -n 5 'aws rds describe-db-instances \
     --db-instance-identifier prod-postgres-primary \
     --query "DBInstances[0].DBInstanceStatus"'
   ```

5. **Verify Failover Completion**
   ```bash
   # Wait for status: available
   # Check new primary AZ
   aws rds describe-db-instances \
     --db-instance-identifier prod-postgres-primary \
     --query 'DBInstances[0].[DBInstanceStatus,AvailabilityZone]'
   ```

6. **Restore Application Settings**
   ```bash
   # Restore original timeout settings
   kubectl set env deployment/api -n production \
     DB_CONNECT_TIMEOUT=10 \
     DB_MAX_RETRIES=3
   ```

7. **Post-Maintenance Verification**
   - Run health checks (see Scenario 1, steps 3-6)
   - Verify replication lag returned to normal
   - Confirm application metrics baseline
   - Close maintenance window notification

### Scenario 3: Regional Disaster Recovery

**When**: Entire AWS region is unavailable

**Detection**: Multiple CloudWatch alarms, complete service outage

**⚠️ CRITICAL**: This is a severe scenario. Escalate immediately to on-call architect.

**Steps**:

1. **Assess Situation**
   ```bash
   # Check AWS Service Health Dashboard
   open https://status.aws.amazon.com/

   # Verify region-wide outage
   aws ec2 describe-regions --region us-east-1
   # If this fails, region is likely down
   ```

2. **Activate Disaster Recovery Plan**
   ```bash
   # Initiate cross-region recovery (if configured)
   # OR restore from S3 WAL archive to new region

   # This is a complex procedure - follow detailed DR plan
   # Located at: docs/disaster-recovery/regional-failover.md
   ```

3. **Estimate Data Loss**
   ```bash
   # Check last S3 WAL archive timestamp
   aws s3 ls s3://prod-postgres-wal-archive/ \
     --recursive --region us-west-2 | tail -n 10

   # Calculate RPO
   # Expected data loss: < 5 minutes
   ```

4. **Restore Database**
   ```bash
   # Create new RDS instance in backup region
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier prod-postgres-primary \
     --target-db-instance-identifier prod-postgres-recovery \
     --restore-time $(date -u -d '5 minutes ago' +"%Y-%m-%dT%H:%M:%SZ") \
     --region us-west-2

   # Monitor restoration
   watch -n 10 'aws rds describe-db-instances \
     --db-instance-identifier prod-postgres-recovery \
     --region us-west-2 \
     --query "DBInstances[0].[DBInstanceStatus,PercentProgress]"'
   ```

5. **Update DNS/Load Balancers**
   ```bash
   # Update Route53 records to point to new region
   # This requires DNS change - coordinate with networking team

   # Update application configuration
   kubectl set env deployment/api -n production \
     DATABASE_HOST=prod-postgres-recovery.xxx.us-west-2.rds.amazonaws.com \
     DATABASE_REGION=us-west-2
   ```

6. **Rebuild Read Replicas**
   ```bash
   # Create new replicas in recovered region
   aws rds create-db-instance-read-replica \
     --db-instance-identifier prod-postgres-recovery-replica-1 \
     --source-db-instance-identifier prod-postgres-recovery \
     --region us-west-2
   ```

7. **Comprehensive Testing**
   - Full application smoke tests
   - Data integrity verification
   - Performance benchmarking
   - Security audit (credentials, encryption)

## Verification Checklist

After any failover scenario, verify:

- [ ] Primary database status: `available`
- [ ] Replication lag: < 100ms average
- [ ] Application error rate: < 0.1%
- [ ] Database connection pool: < 80% utilized
- [ ] Slow query count: baseline levels
- [ ] All read replicas: `replicating` status
- [ ] Backup job: completed successfully post-failover
- [ ] Monitoring alerts: cleared
- [ ] Application logs: no database connection errors

## Rollback

If failover causes issues:

1. **Immediate Rollback** (if possible)
   ```bash
   # Failback to original primary if still available
   aws rds reboot-db-instance \
     --db-instance-identifier prod-postgres-primary \
     --force-failover
   ```

2. **Database Restore** (if data corruption)
   ```bash
   # Restore from pre-failover snapshot
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier prod-postgres-restore \
     --db-snapshot-identifier manual-pre-maintenance-[timestamp]
   ```

3. **Application Rollback**
   ```bash
   # Revert application to previous configuration
   kubectl rollout undo deployment/api -n production
   ```

## Troubleshooting

### Issue: Replication Lag Not Decreasing

**Symptoms**: Lag stays > 5 seconds after failover

**Investigation**:
```bash
# Check replica queries
psql -h replica -U app_readonly -c \
  "SELECT pid, usename, application_name, state, query
   FROM pg_stat_activity
   WHERE state = 'active';"

# Check for long-running transactions on primary
psql -h primary -U app_admin -c \
  "SELECT pid, now() - xact_start AS duration, query
   FROM pg_stat_activity
   WHERE state = 'active' AND xact_start IS NOT NULL
   ORDER BY duration DESC LIMIT 10;"
```

**Resolution**:
- Kill long-running queries if safe
- Check for network issues between AZs
- Verify replica instance size sufficient

### Issue: Application Cannot Connect After Failover

**Symptoms**: Connection timeout errors persist

**Investigation**:
```bash
# Check security groups
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx

# Check PgBouncer health
kubectl logs -n production deployment/pgbouncer --tail=50

# Verify DNS resolution
dig prod-postgres-primary.xxx.rds.amazonaws.com
```

**Resolution**:
- Restart PgBouncer pods
- Verify security group rules
- Check application database credentials

### Issue: Failed Transactions After Failover

**Symptoms**: Database write errors, constraint violations

**Investigation**:
```bash
# Check for split-brain scenario
# Verify only one primary exists
aws rds describe-db-instances \
  --filters "Name=engine,Values=postgres" \
  --query 'DBInstances[?DBInstanceStatus==`available`].[DBInstanceIdentifier,Endpoint.Address]'

# Check application logs for duplicate key errors
kubectl logs -n production deployment/api --tail=100 | grep "duplicate key"
```

**Resolution**:
- Ensure old primary fully demoted
- Clear application-level caches
- Investigate application retry logic

## Monitoring

**Key Metrics to Watch**:
- RDS CloudWatch: `DatabaseConnections`, `ReplicaLag`, `CPUUtilization`
- Application: Error rate, response time, transaction throughput
- PgBouncer: Connection pool utilization, client wait time

**Alerts**:
- Replication lag > 5 seconds → Page on-call
- Connection pool > 90% → Alert platform team
- Primary instance unhealthy → Page on-call + escalate

## Post-Incident Review

Within 48 hours of any failover:

1. **Conduct Blameless Postmortem**
   - Timeline reconstruction
   - Root cause analysis
   - Impact assessment

2. **Identify Improvements**
   - Monitoring gaps
   - Runbook updates
   - Automation opportunities

3. **Create Action Items**
   - Assign owners
   - Set deadlines
   - Track in Jira

4. **Update Documentation**
   - This runbook
   - Architecture docs
   - Monitoring dashboards

## Prevention

**Proactive Measures**:
- Quarterly failover drills
- Weekly replication lag monitoring
- Monthly backup restore tests
- Continuous performance monitoring

**Recommended Improvements**:
- Implement automatic DNS failover
- Add cross-region read replicas
- Enhance monitoring coverage
- Automate failover verification

## References

- [Database Architecture](../designs/database-architecture.md)
- [ADR-001: PostgreSQL](../adrs/ADR-001-postgresql.md)
- [AWS RDS Multi-AZ Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)
- [PostgreSQL Replication](https://www.postgresql.org/docs/15/warm-standby.html)

## Contact Information

- **On-Call Engineer**: PagerDuty rotation
- **Database Team**: #team-platform on Slack
- **Escalation**: VP Engineering (see wiki)
- **AWS Support**: Enterprise support case

## Revision History

- **2025-01-13**: Initial version
- Last tested: [date of last drill]
- Next scheduled drill: [quarterly schedule]
