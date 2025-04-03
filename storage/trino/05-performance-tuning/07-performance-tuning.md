# Lab 7: Trino Performance Optimization

This lab guides you through techniques and best practices for optimizing the performance of your Trino cluster.

## Prerequisites

- A running Trino cluster (from previous labs)
- Basic understanding of SQL optimization concepts
- Monitoring set up for your Trino cluster (from Lab 6)

## Part 1: Query Optimization Techniques

### Step 1: Using EXPLAIN to Analyze Queries

Trino's EXPLAIN statement helps you understand query execution plans:

```sql
-- Basic EXPLAIN
EXPLAIN SELECT * FROM mysql.example.customers;

-- Detailed EXPLAIN with statistics
EXPLAIN ANALYZE SELECT * FROM mysql.example.customers;
```

Output interpretation:
- Fragment distribution (SINGLE, HASH, ROUND_ROBIN)
- Joins and their order
- Predicates and filters
- Exchange operations (data movement between nodes)

### Step 2: Common Query Optimization Patterns

#### a. Predicate Pushdown

Push filters as close to the data source as possible:

```sql
-- Inefficient: Filter applied after data is loaded
SELECT * FROM mysql.example.customers WHERE region = 'EMEA';

-- Better: Push predicate to connector
SELECT * FROM mysql.example.customers WHERE region = 'EMEA';
```

Trino automatically attempts predicate pushdown, but some connectors have limitations.

#### b. Join Optimization

Order your joins from smallest to largest tables:

```sql
-- Inefficient: Large table first
SELECT * FROM large_table l JOIN small_table s ON l.id = s.id;

-- Better: Small table first
SELECT * FROM small_table s JOIN large_table l ON s.id = l.id;
```

#### c. Limit Early

Apply LIMIT early to reduce data transfer:

```sql
-- Inefficient: Late limit
SELECT * FROM large_table ORDER BY timestamp DESC LIMIT 10;

-- Better: Early limit with subquery
SELECT * FROM (
  SELECT * FROM large_table ORDER BY timestamp DESC LIMIT 10
) t;
```

#### d. Use Approximate Functions

For aggregations where precision isn't critical:

```sql
-- Expensive exact count distinct
SELECT COUNT(DISTINCT user_id) FROM events;

-- Faster approximate count distinct
SELECT approx_distinct(user_id) FROM events;
```

## Part 2: JVM Tuning

### Step 1: Memory Configuration

Trino's memory usage is controlled by multiple settings:

```properties
# Coordinator memory settings
query.max-memory=10GB
query.max-memory-per-node=2GB
query.max-total-memory-per-node=3GB

# JVM heap settings (in jvm.config)
-Xmx16G
-XX:+UseG1GC
-XX:G1HeapRegionSize=32M
-XX:+ExplicitGCInvokesConcurrent
-XX:+HeapDumpOnOutOfMemoryError
```

Guidelines:
- Set JVM heap (Xmx) to ~70% of available RAM
- Set query.max-memory to ~50% of total cluster memory
- Set query.max-memory-per-node to ~60% of JVM heap

### Step 2: GC Tuning

For large heaps, adjust G1GC settings:

```properties
-XX:+UseG1GC
-XX:G1HeapRegionSize=32M
-XX:+ExplicitGCInvokesConcurrent
-XX:MaxGCPauseMillis=200
-XX:ConcGCThreads=2
-XX:InitiatingHeapOccupancyPercent=45
```

## Part 3: Scaling and Resource Management

### Step 1: Worker Scaling

Scale workers based on workload:

```bash
# Kubernetes scaling
kubectl scale deployment trino-worker -n trino --replicas=5

# Helm scaling
helm upgrade trino trino/trino -n trino --set server.workers=5
```

Choose worker size based on:
- Query complexity
- Data size
- Concurrency requirements

### Step 2: Resource Groups

Resource groups help manage concurrent queries and resource allocation.

Create a file named `resource-groups.properties`:

```properties
resource-groups.config-file=/etc/trino/resource-groups.json
```

Create a file named `resource-groups.json`:

```json
{
  "rootGroups": [
    {
      "name": "global",
      "softMemoryLimit": "80%",
      "hardConcurrencyLimit": 100,
      "maxQueued": 1000,
      "subGroups": [
        {
          "name": "admin",
          "softMemoryLimit": "40%",
          "hardConcurrencyLimit": 20,
          "maxQueued": 100
        },
        {
          "name": "analytics",
          "softMemoryLimit": "30%",
          "hardConcurrencyLimit": 50,
          "maxQueued": 500
        },
        {
          "name": "etl",
          "softMemoryLimit": "30%",
          "hardConcurrencyLimit": 30,
          "maxQueued": 400
        }
      ]
    }
  ],
  "selectors": [
    {
      "user": "admin",
      "group": "admin"
    },
    {
      "source": ".*-analytics-.*",
      "group": "analytics"
    },
    {
      "source": ".*-etl-.*",
      "group": "etl"
    }
  ]
}
```

### Step 3: Query Prioritization

You can prioritize queries using queueing rules:

```json
{
  "name": "analytics",
  "softMemoryLimit": "30%",
  "hardConcurrencyLimit": 50,
  "maxQueued": 500,
  "schedulingPolicy": "weighted",
  "schedulingWeight": 1,
  "subGroups": [
    {
      "name": "high_priority",
      "softMemoryLimit": "50%",
      "hardConcurrencyLimit": 10,
      "maxQueued": 100,
      "schedulingWeight": 10
    },
    {
      "name": "normal_priority",
      "softMemoryLimit": "50%",
      "hardConcurrencyLimit": 40,
      "maxQueued": 400,
      "schedulingWeight": 1
    }
  ]
}
```

## Part 4: Connector-Specific Optimizations

### Step 1: Hive/HDFS Connector

For the Hive connector, optimize:

```properties
hive.max-split-size=128MB
hive.max-partitions-per-scan=100000
hive.parquet.use-column-names=true
hive.orc.use-column-names=true
hive.compression-codec=SNAPPY
```

Key techniques:
- Use columnar formats (Parquet or ORC)
- Partition data appropriately
- Use bucketing for join-heavy workloads
- Configure the proper split size

### Step 2: RDBMS Connectors (MySQL, PostgreSQL)

For JDBC-based connectors:

```properties
mysql.connection-pool.max-connections=100
mysql.remarks-reporting=false
mysql.connection-timeout=3m
```

Key techniques:
- Use connection pooling
- Create appropriate indexes in the source database
- Push down computations where possible

### Step 3: Memory Connector

For the memory connector:

```properties
memory.max-data-per-node=2GB
```

## Part 5: Production Deployment Best Practices

### Step 1: Infrastructure Considerations

- **Network**: Low-latency, high-throughput network between nodes
- **Storage**: Use SSD/NVMe for spill operations
- **CPU**: High clock speed, multiple cores for parallelism

### Step 2: Node Sizing

- **Coordinator**: CPU-heavy, moderate memory (8-16 cores, 32-64GB RAM)
- **Workers**: Memory-heavy, high CPU (16-32 cores, 64-128GB RAM)
- **Scale Out vs Up**: Prefer more moderate-sized nodes over fewer large nodes

### Step 3: Isolation Strategies

- Separate catalog connections from underlying data services
- Isolate Trino from other applications
- Use separate coordinators for different workloads (if needed)

### Step 4: High Availability

For production deployments:

```yaml
server:
  workers: 5
  coordinator: true
  coordinators: 2  # Multiple coordinators for HA
  
  etc:
    node.properties: |
      node.environment=production
      node.data-dir=/data/trino
      spiller-spill-path=/data/spill
      
    config.properties: |
      coordinator=true
      discovery-server.enabled=true
      discovery.uri=http://trino-discovery:8080
      http-server.http.port=8080
      
discovery:
  enabled: true
  image: trinodb/trino:latest
  replicas: 3
```

## Part 6: Workload-Specific Optimizations

### Step 1: Interactive Queries

For interactive BI workloads:

```properties
# In resource group config
{
  "name": "bi_interactive",
  "softMemoryLimit": "30%",
  "hardConcurrencyLimit": 30,
  "maxQueued": 100,
  "queryType": "INTERACTIVE"
}
```

### Step 2: ETL/Batch Jobs

For ETL workloads:

```properties
# In resource group config
{
  "name": "etl_batch",
  "softMemoryLimit": "50%",
  "hardConcurrencyLimit": 10,
  "maxQueued": 20,
  "queryType": "DATA_DEFINITION"
}
```

### Step 3: Mixed Workloads

For environments with mixed workloads:

```properties
# In system config
task.concurrency=4
task.max-worker-threads=8
node-scheduler.max-splits-per-node=100
query.max-memory-per-node=4GB
```

## Conclusion

Performance optimization in Trino requires a holistic approach considering query patterns, data characteristics, infrastructure, and workload management. By monitoring key metrics and applying the appropriate optimizations, you can achieve significant performance improvements.