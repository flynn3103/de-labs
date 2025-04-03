# Lab 8: Troubleshooting Trino

This lab guides you through common Trino issues and debugging techniques.

## Prerequisites

- A running Trino cluster (from previous labs)
- Basic understanding of Trino architecture
- Monitoring set up for your Trino cluster (from Lab 6)

## Part 1: Query Failures

### Step 1: Understanding Error Messages

Trino provides detailed error messages for query failures. Here are common errors and their meanings:

#### a. Memory Errors

```
Query exceeded per-node memory limit of 1GB [Allocated: 1.2GB, Used: 1.1GB]
```

This indicates a query required more memory than allowed by the `query.max-memory-per-node` setting.

#### b. Execution Errors

```
com.facebook.presto.spi.PrestoException: value exceeds MAX_LONG
```

This indicates a numeric overflow during query execution.

#### c. Connector Errors

```
com.facebook.presto.spi.PrestoException: Failed to connect to MySQL
```

This indicates an issue with the underlying data source.

### Step 2: Diagnosing Query Failures

1. Check the query details in the Trino UI
2. Look for the specific error message in the UI or logs
3. Examine the query execution plan with EXPLAIN
4. Identify potential bottlenecks:
   - Memory pressure
   - Resource contention
   - Data source issues

### Step 3: Common Resolution Approaches

#### a. For Memory Errors

```properties
# Increase memory limits in config.properties
query.max-memory=10GB
query.max-memory-per-node=2GB
query.max-total-memory-per-node=3GB
```

Or modify the query to reduce memory usage:
- Break down complex queries
- Use approximation functions
- Apply filters earlier

#### b. For Execution Errors

- Fix data type issues in the query
- Use appropriate casting
- Apply validations to input data

#### c. For Connector Errors

- Verify connector configuration
- Check permissions and credentials
- Confirm the data source is accessible

## Part 2: Performance Issues

### Step 1: Identifying Slow Queries

Use the Trino UI or monitoring tools to identify slow queries:

1. Look for queries with unusually long execution times
2. Check for queries consuming high CPU or memory
3. Identify patterns in slow queries (e.g., specific tables, connectors, or users)

### Step 2: Analyzing Query Plans

Use EXPLAIN to understand the query execution plan:

```sql
EXPLAIN (TYPE DISTRIBUTED) SELECT * FROM large_table WHERE complex_condition;
```

Look for:
- Lack of predicate pushdown
- Inefficient join strategies
- Excessive data transfer between nodes

### Step 3: Performance Optimization Techniques

- Apply query rewrites (see Lab 7)
- Tune connector properties
- Adjust resource allocation

## Part 3: Cluster Health Issues

### Step 1: Identifying Node Problems

Check for signs of unhealthy nodes:

1. Node missing from the Trino UI
2. High CPU/memory usage on specific nodes
3. Connectivity issues between nodes

### Step 2: Diagnosing Worker Issues

```bash
# Check worker logs 
kubectl logs -n trino -l app=trino,component=worker

# Check resource usage
kubectl top pod -n trino
```

### Step 3: Coordinator Failures

Symptoms of coordinator issues:
- UI not accessible
- All queries failing to start
- Discovery service errors

```bash
# Check coordinator logs
kubectl logs -n trino -l app=trino,component=coordinator

# Verify coordinator pod status
kubectl describe pod -n trino -l app=trino,component=coordinator
```

### Step 4: Resolution Approaches

- Restart unhealthy nodes
- Scale resources if needed
- Check for network connectivity issues
- Verify configuration consistency

## Part 4: Analyzing Logs

### Step 1: Understanding Trino Logs

Trino logs provide important diagnostic information:

#### a. Log Levels

```properties
# In log.properties
com.facebook.presto=INFO
com.facebook.presto.server=DEBUG
```

#### b. Key Log Patterns

```
INFO  -- Starting query 20220103_123456_00001_ab123
WARN  -- Query 20220103_123456_00001_ab123 exceeded memory limit
ERROR -- Query 20220103_123456_00001_ab123 failed: XXXX
```

### Step 2: Collecting Logs in Kubernetes

```bash
# Collect coordinator logs
kubectl logs -n trino -l app=trino,component=coordinator > coordinator.log

# Collect worker logs
kubectl logs -n trino -l app=trino,component=worker -c trino > workers.log

# For all logs with context
kubectl logs -n trino -l app=trino --all-containers=true --prefix=true > all_trino_logs.log
```

### Step 3: Using Logs for Debugging

Key patterns to look for:
1. Exception stacktraces
2. Memory warnings
3. GC pause logs
4. Connectivity errors
5. Authentication failures

## Part 5: Debugging Connectivity Issues

### Step 1: Network Connectivity Testing

```bash
# Test connectivity from within a Trino pod
kubectl exec -it -n trino $(kubectl get pods -n trino -l "app=trino,component=coordinator" -o jsonpath="{.items[0].metadata.name}") -- /bin/bash

# Check DNS resolution
nslookup mysql.default.svc.cluster.local

# Check TCP connectivity
nc -zv mysql.default.svc.cluster.local 3306
```

### Step 2: Common Network Issues

1. DNS resolution problems
2. Firewall or security group restrictions
3. Network policy constraints in Kubernetes
4. Service misconfigurations

### Step 3: Resolution Approaches

- Verify Kubernetes service definitions
- Check network policies
- Ensure proper DNS configuration
- Verify connector host/port settings

## Part 6: Connector-Specific Troubleshooting

### Step 1: MySQL/PostgreSQL Issues

Common issues:
1. Connection timeouts
2. Authentication failures
3. Missing permissions
4. Performance issues with large datasets

Troubleshooting:
```bash
# Test direct connection to MySQL
kubectl run mysql-client --image=mysql:8.0 -i --rm --restart=Never -- mysql -h mysql -u root -ppassword -e "SELECT 1"

# Verify connector configuration
kubectl exec -it -n trino $(kubectl get pods -n trino -l "app=trino,component=coordinator" -o jsonpath="{.items[0].metadata.name}") -- cat /etc/trino/catalog/mysql.properties
```

### Step 2: Hive/HDFS Issues

Common issues:
1. Metastore connectivity
2. S3 permissions
3. Schema evolution problems
4. Partition management issues

Troubleshooting:
```bash
# Check Hive metastore connection
kubectl exec -it -n trino $(kubectl get pods -n trino -l "app=trino,component=coordinator" -o jsonpath="{.items[0].metadata.name}") -- nc -zv hive-metastore 9083

# Verify S3 connectivity
kubectl exec -it -n trino $(kubectl get pods -n trino -l "app=trino,component=coordinator" -o jsonpath="{.items[0].metadata.name}") -- curl -s http://minio:9000
```

## Part 7: JVM and System Troubleshooting

### Step 1: JVM Issues

Common JVM problems:
1. Out of Memory errors
2. GC overhead limit exceeded
3. Long GC pauses
4. Memory leaks

Troubleshooting:
```bash
# Get a heap dump (when OOM occurs)
kubectl exec -it -n trino $(kubectl get pods -n trino -l "app=trino,component=coordinator" -o jsonpath="{.items[0].metadata.name}") -- jmap -dump:format=b,file=/tmp/heap.hprof 1

# Analyze GC logs
kubectl exec -it -n trino $(kubectl get pods -n trino -l "app=trino,component=coordinator" -o jsonpath="{.items[0].metadata.name}") -- cat /var/log/trino/gc.log
```

### Step 2: System Resource Issues

```bash
# Check system resources in a pod
kubectl exec -it -n trino $(kubectl get pods -n trino -l "app=trino,component=coordinator" -o jsonpath="{.items[0].metadata.name}") -- top

# Check disk space
kubectl exec -it -n trino $(kubectl get pods -n trino -l "app=trino,component=coordinator" -o jsonpath="{.items[0].metadata.name}") -- df -h
```

## Part 8: Creating a Troubleshooting Workflow

### Step 1: Proactive Monitoring

Set up alerts for:
1. Query failure rate exceeding threshold
2. High memory usage
3. Node health issues
4. Slow query patterns

### Step 2: Incident Response Plan

Create a troubleshooting workflow:
1. Identify affected users/queries
2. Check Trino UI for immediate issues
3. Review monitoring dashboards
4. Examine recent configuration changes
5. Analyze logs for errors
6. Execute targeted diagnostic queries
7. Apply appropriate resolution

### Step 3: Post-Incident Analysis

After resolving an issue:
1. Document root cause
2. Implement preventive measures
3. Update monitoring/alerting if needed
4. Share lessons learned with the team

## Conclusion

Effective troubleshooting in Trino combines understanding query patterns, resource usage, network connectivity, and connector-specific issues. By systematically analyzing the problem and checking logs and metrics, you can quickly isolate and resolve most Trino issues. 