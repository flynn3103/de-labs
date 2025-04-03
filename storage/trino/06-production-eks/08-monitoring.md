# Lab 8: Monitoring and Performance Analysis

This lab guides you through setting up comprehensive monitoring for your Trino cluster to ensure optimal performance and reliability.

## Theory: Trino Monitoring Architecture

Trino provides a robust monitoring architecture that exposes various metrics and diagnostic information through several mechanisms:

### Metrics Fundamentals

Metrics in Trino are organized in a hierarchical structure:

1. **System Metrics**: Cluster-wide metrics about resource usage and query execution
2. **Node Metrics**: Per-node metrics about CPU, memory, and I/O
3. **Query Metrics**: Per-query metrics about execution time, resource usage, and errors
4. **Catalog Metrics**: Metrics specific to connectors and data sources

### Exposure Mechanisms

Trino exposes metrics through multiple channels:

1. **JMX (Java Management Extensions)**: The primary metrics interface, exposing all Trino metrics as JMX MBeans
2. **Prometheus Endpoint**: HTTP endpoint exposing metrics in Prometheus format
3. **Event Listeners**: Customizable event listeners that can send metrics to external systems
4. **System Tables**: SQL-queryable tables containing metrics and diagnostic information

### Trino's Internal Monitoring Components

Trino's core monitoring capabilities include:

1. **Query Monitor**: Tracks execution of all queries throughout their lifecycle
2. **Memory Manager**: Monitors memory usage across the cluster
3. **Node Monitor**: Tracks node health and resource availability
4. **Failure Detector**: Identifies failed or unresponsive nodes
5. **Exchange Manager**: Monitors data exchange between nodes

## Theory: Key Metrics to Monitor

Understanding which metrics to monitor is crucial for effective performance analysis:

### Resource Utilization Metrics

1. **CPU Usage**: 
   - `os:cpu_load`: System CPU load
   - `trino.execution:cpu_time_rate`: CPU time used by Trino queries

2. **Memory Usage**:
   - `memory:heap_used`: JVM heap memory usage
   - `memory:heap_available`: Available heap memory
   - `trino.memory:general_pool_reserved`: Memory reserved by the general pool
   - `trino.memory:reserved_bytes`: Total memory reserved by Trino

3. **I/O and Network**:
   - `trino.execution:physical_input_bytes_rate`: Physical data read rate
   - `trino.execution:output_bytes_rate`: Data output rate
   - `trino.execution:queued_time`: Time queries spend in queue

### Query Performance Metrics

1. **Query Timing**:
   - `trino.execution:execution_time`: Time spent executing queries
   - `trino.execution:query_wall_time`: Wall clock time for query execution
   - `trino.execution:query_total_time`: Total time including queueing

2. **Query Volume**:
   - `trino.execution:active_queries`: Currently running queries
   - `trino.execution:queued_queries`: Queries waiting to be executed
   - `trino.execution:query_success`: Successfully completed queries
   - `trino.execution:query_failed`: Failed queries

3. **Execution Details**:
   - `trino.execution:total_splits`: Number of query splits
   - `trino.execution:completed_splits`: Completed query splits
   - `trino.execution:running_splits`: Currently running splits

### Connector-Specific Metrics

Different connectors expose metrics relevant to their operation:

1. **Hive Connector**:
   - `trino.hive:storage_footprint`: Data storage size
   - `trino.hive:file_count`: Number of files accessed
   - `trino.hive:metastore_calls`: Calls to the Hive metastore

2. **JDBC Connector**:
   - `trino.jdbc:connection_count`: Active database connections
   - `trino.jdbc:query_time`: Time spent in database queries

3. **Memory Connector**:
   - `trino.memory:rows`: Rows stored in memory tables
   - `trino.memory:active_node_count`: Nodes with memory tables

## Prerequisites

- A running Trino cluster (See Lab 2: Docker Setup)
- Basic understanding of monitoring concepts
- Kubernetes cluster (for production monitoring)

## Part 1: Setting Up Prometheus and Grafana

### Theory: Prometheus Architecture

Prometheus is a time-series database designed for monitoring. Its architecture includes:

1. **Data Collection**: Scrapes metrics from HTTP endpoints
2. **Storage**: Time-series database optimized for metrics
3. **Query Language (PromQL)**: Flexible language for querying metrics
4. **Alerting**: Rules-based alerting system

When monitoring Trino with Prometheus:
- Metrics are collected at regular intervals (typically 15s)
- Historical data is stored based on retention settings
- Downsampling can be used for long-term storage efficiency

### Step 1: Deploy Prometheus and Grafana with Docker Compose

Create a `monitoring` directory and add the following configuration files:

1. Create `prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'trino'
    static_configs:
      - targets: ['trino-coordinator:8080']
    metrics_path: '/metrics'
```

2. Create `docker-compose-monitoring.yml`:

```yaml
version: '3'
services:
  prometheus:
    image: prom/prometheus:v2.45.0
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    networks:
      - trino-network

  grafana:
    image: grafana/grafana:10.1.0
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    networks:
      - trino-network

volumes:
  prometheus_data:
  grafana_data:

networks:
  trino-network:
    external: true
```

3. Create directories for Grafana configuration:

```bash
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards
mkdir -p grafana/dashboards
```

4. Create `grafana/provisioning/datasources/datasource.yml`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
```

5. Create `grafana/provisioning/dashboards/dashboard.yml`:

```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
```

### Step 2: Start Prometheus and Grafana

```bash
docker-compose -f docker-compose-monitoring.yml up -d
```

### Step 3: Enable Trino Metrics

Ensure your Trino configuration has metrics enabled:

1. Modify your `config.properties` for the coordinator:

```properties
# In config.properties
http-server.http.port=8080
discovery.uri=http://trino-coordinator:8080
web-ui.enabled=true

# Enable Prometheus metrics
prometheus.metrics.enabled=true
```

## Part 2: Configuring Dashboards

### Theory: Data Visualization Principles

Effective monitoring dashboards follow these principles:

1. **Purpose-Oriented Design**: Design for specific use cases (operational, diagnostic, capacity planning)
2. **Visual Hierarchy**: Most critical metrics should be most visible
3. **Context and Comparisons**: Show normal ranges and historical trends
4. **Correlation**: Group related metrics to identify patterns
5. **Actionability**: Dashboards should guide toward action

### Step 1: Import the Trino Dashboard

1. Download the Trino dashboard JSON template:

```bash
curl -o grafana/dashboards/trino-dashboard.json https://raw.githubusercontent.com/trinodb/trino/master/core/docker/default/etc/grafana/dashboards/trino-overview.json
```

2. Access Grafana at http://localhost:3000 (username: admin, password: admin)

3. Navigate to Dashboards > Import and upload the Trino dashboard JSON

### Step 2: Customize the Dashboard

Create a custom dashboard with the following metrics:

1. **Cluster Overview Panel**:
   - Query success rate
   - Active queries
   - Queued queries
   - Cluster CPU usage

2. **Query Performance Panel**:
   - 95th percentile query time
   - Query time by user
   - Failed queries by type

3. **Resource Usage Panel**:
   - Memory usage per node
   - CPU usage per node
   - Query parallelism

Here's a sample PromQL query for query success rate:
```
sum(rate(trino_execution_query_success[5m])) / (sum(rate(trino_execution_query_success[5m])) + sum(rate(trino_execution_query_failed[5m])))
```

## Part 3: Setting Up Alerting

### Theory: Alert Design Principles

Effective alerting follows these key principles:

1. **Signal-to-Noise Ratio**: Alerts should indicate real issues requiring action
2. **Actionability**: Alert descriptions should guide toward resolution
3. **Timeliness**: Alert before users notice problems
4. **Severity Levels**: Distinguish between critical and non-critical issues
5. **Context**: Include relevant context with alerts

Common Trino alerting thresholds:
- CPU usage > 80% for 15 minutes
- Memory usage > 90% for 5 minutes
- Query failure rate > 10% for 5 minutes
- Coordinator node unavailable for > 1 minute

### Step 1: Configure Alerting Rules in Prometheus

Create `prometheus/alerts.yml`:

```yaml
groups:
- name: trino_alerts
  rules:
  - alert: TrinoHighCpuUsage
    expr: avg(rate(process_cpu_seconds_total{job="trino"}[5m]) * 100) > 80
    for: 15m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on Trino cluster"
      description: "Trino cluster CPU usage is above 80% for more than 15 minutes."

  - alert: TrinoHighMemoryUsage
    expr: max(jvm_memory_bytes_used{job="trino", area="heap"} / jvm_memory_bytes_max{job="trino", area="heap"} * 100) > 90
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage on Trino cluster"
      description: "Trino cluster memory usage is above 90% for more than 5 minutes."

  - alert: TrinoHighFailedQueries
    expr: sum(rate(trino_execution_query_failed[5m])) / (sum(rate(trino_execution_query_success[5m])) + sum(rate(trino_execution_query_failed[5m]))) > 0.1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High query failure rate"
      description: "Query failure rate is above 10% for more than 5 minutes."

  - alert: TrinoCoordinatorDown
    expr: up{job="trino"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Trino coordinator is down"
      description: "Trino coordinator instance has been down for more than 1 minute."
```

Update `prometheus.yml` to include alerts:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "/etc/prometheus/alerts.yml"

scrape_configs:
  - job_name: 'trino'
    static_configs:
      - targets: ['trino-coordinator:8080']
    metrics_path: '/metrics'
```

### Step 2: Set Up Alert Notifications

1. In Grafana, navigate to Alerting > Notification channels
2. Add a new notification channel (e.g., Email, Slack, PagerDuty)
3. Configure the channel with appropriate credentials

## Part 4: Production Monitoring with Kubernetes

### Theory: Kubernetes Monitoring Architecture

Monitoring in Kubernetes environments involves:

1. **Service Discovery**: Automatically find and monitor new pods/services
2. **Pod Metrics**: Monitor individual pod resource usage
3. **Node Metrics**: Monitor Kubernetes node health
4. **Service-Level Metrics**: Monitor service health and performance

The Prometheus Operator provides a declarative way to manage:
- Prometheus instances
- Service monitors (what to scrape)
- Alert rules
- Grafana dashboards

### Step 1: Install Prometheus Operator using Helm

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring

# Install Prometheus Operator
helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

### Step 2: Create ServiceMonitor for Trino

Create `trino-servicemonitor.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: trino-servicemonitor
  namespace: monitoring
  labels:
    release: prometheus-operator
spec:
  selector:
    matchLabels:
      app: trino
  namespaceSelector:
    matchNames:
      - trino
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

Apply the ServiceMonitor:

```bash
kubectl apply -f trino-servicemonitor.yaml
```

### Step 3: Configure Trino for Prometheus Metrics

Update your Trino Helm values to enable Prometheus metrics:

```yaml
server:
  config:
    coordinator: true
    node-scheduler.include-coordinator: false
    http-server.http.port: 8080
    discovery.uri: http://trino-coordinator:8080
    
    # Enable Prometheus metrics
    prometheus.metrics.enabled: true
    
  additionalJVMConfig:
    - "-javaagent:/usr/lib/trino/lib/jmx_prometheus_javaagent-0.17.0.jar=8081:/etc/trino/jmx-prometheus-config.yaml"
    
  additionalConfigFiles:
    jmx-prometheus-config.yaml: |
      ---
      startDelaySeconds: 0
      ssl: false
      lowercaseOutputName: false
      lowercaseOutputLabelNames: false
      
  additionalLabels:
    app: trino
```

### Step 4: Deploy Grafana Dashboards

Create a ConfigMap for the Trino dashboard:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-trino
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  trino-dashboard.json: |
    {
      ... [Trino dashboard JSON content] ...
    }
```

Apply the ConfigMap:

```bash
kubectl apply -f grafana-dashboard-configmap.yaml
```

## Part 5: Advanced Monitoring Techniques

### Theory: Distributed Tracing

Distributed tracing provides insights into request flows across distributed systems:

1. **Trace**: Represents an end-to-end request flow
2. **Span**: Individual operation within a trace
3. **Context Propagation**: Passing trace context between services

Trino supports distributed tracing via OpenTelemetry, allowing you to:
- Track query execution across nodes
- Identify bottlenecks in query processing
- Correlate Trino operations with external systems

### Step 1: Configure JMX Metrics for Advanced Analysis

For deeper analysis, enable JMX metrics:

```properties
# In jvm.config
-Dcom.sun.management.jmxremote=true
-Dcom.sun.management.jmxremote.port=9010
-Dcom.sun.management.jmxremote.local.only=false
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=false
```

### Step 2: Set Up Trino Event Listeners

Create a custom event listener to track query events:

1. Create a Java project for the custom event listener
2. Extend `EventListener` class
3. Implement methods to handle events:
   - `queryCreated`
   - `queryCompleted`
   - `splitCompleted`

Sample event listener code:

```java
public class MetricsEventListener implements EventListener {
    private final MeterRegistry registry;
    
    @Inject
    public MetricsEventListener(MeterRegistry registry) {
        this.registry = registry;
    }
    
    @Override
    public void queryCompleted(QueryCompletedEvent event) {
        QueryStats stats = event.getQueryStats();
        
        // Record query duration
        registry.timer("trino.query.duration")
                .record(stats.getEndTime().toEpochMilli() - 
                        stats.getCreateTime().toEpochMilli(), 
                        TimeUnit.MILLISECONDS);
        
        // Record CPU time
        registry.timer("trino.query.cpu")
                .record(stats.getTotalCpuTime().toMillis(), 
                        TimeUnit.MILLISECONDS);
                
        // Record whether query succeeded or failed
        if (event.getFailureInfo().isPresent()) {
            registry.counter("trino.query.failed").increment();
        } else {
            registry.counter("trino.query.success").increment();
        }
    }
}
```

### Step 3: Analyze Query Performance Using System Tables

Trino provides system tables for performance analysis:

1. Query runtime statistics:
```sql
SELECT 
    query_id,
    user,
    state,
    queued_time_ms,
    analysis_time_ms,
    planning_time_ms,
    execution_time_ms
FROM system.runtime.queries
ORDER BY query_start DESC
LIMIT 20;
```

2. Currently running queries:
```sql
SELECT 
    query_id, 
    user, 
    source, 
    query_type,
    state, 
    CAST(created AS VARCHAR) as created,
    FROM_UNIXTIME(CAST(started AS DOUBLE)/1000.0) as started,
    CAST(elapsed_time AS VARCHAR) as elapsed
FROM system.runtime.queries
WHERE state = 'RUNNING'
ORDER BY created;
```

3. Query resource usage:
```sql
SELECT 
    query_id,
    resource_group_id,
    user,
    total_cpu_time_ms,
    input_rows,
    output_rows,
    wall_time_ms
FROM system.runtime.queries
WHERE state = 'FINISHED'
ORDER BY total_cpu_time_ms DESC
LIMIT 10;
```

## Part 6: Analyzing Performance Problems

### Theory: Common Trino Performance Issues

Understanding common performance bottlenecks helps in troubleshooting:

1. **Memory Pressure**:
   - Symptoms: OOM errors, excessive GC, query failures
   - Causes: Insufficient memory configuration, large joins/aggregations
   - Solutions: Increase memory, optimize queries, use spill-to-disk

2. **CPU Bottlenecks**:
   - Symptoms: High CPU usage, slow query execution
   - Causes: Inefficient queries, insufficient parallelism
   - Solutions: Add workers, optimize queries, increase parallelism

3. **I/O Bottlenecks**:
   - Symptoms: High I/O wait times, slow data scan
   - Causes: Slow storage, inefficient data layout, large data scans
   - Solutions: Optimize storage, partition pruning, columnar formats

4. **Network Bottlenecks**:
   - Symptoms: High network utilization, slow data transfer
   - Causes: Cross-region queries, excessive data movement
   - Solutions: Co-locate compute and storage, optimize joins

### Step 1: Diagnose Memory Issues

Check memory usage across the cluster:

```sql
SELECT 
    node_id,
    CAST(general_pool_reserved_bytes AS DOUBLE) / 1024 / 1024 / 1024 AS general_pool_reserved_gb,
    CAST(general_pool_free_bytes AS DOUBLE) / 1024 / 1024 / 1024 AS general_pool_free_gb,
    CAST(general_pool_total_bytes AS DOUBLE) / 1024 / 1024 / 1024 AS general_pool_total_gb,
    CAST(reserved_system_memory_bytes AS DOUBLE) / 1024 / 1024 / 1024 AS reserved_system_memory_gb
FROM system.runtime.memory
ORDER BY general_pool_reserved_gb DESC;
```

### Step 2: Diagnose Slow Queries

Find slow-running queries:

```sql
SELECT 
    query_id,
    query_type,
    user,
    state,
    CAST(queued_time_ms AS DOUBLE) / 1000 as queued_time_seconds,
    CAST(execution_time_ms AS DOUBLE) / 1000 as execution_time_seconds,
    total_splits,
    completed_splits
FROM system.runtime.queries
WHERE state = 'RUNNING'
ORDER BY execution_time_ms DESC
LIMIT 10;
```

### Step 3: Analyze Query Details

Get detailed execution statistics for a specific query:

```sql
SELECT 
    operator_id,
    operator_type,
    CAST(input_rows AS DOUBLE) / 1000000 as input_rows_millions,
    CAST(input_bytes AS DOUBLE) / 1024 / 1024 / 1024 as input_gb,
    CAST(output_rows AS DOUBLE) / 1000000 as output_rows_millions,
    CAST(output_bytes AS DOUBLE) / 1024 / 1024 / 1024 as output_gb,
    CAST(wall_time_ms AS DOUBLE) / 1000 as wall_time_seconds,
    CAST(cpu_time_ms AS DOUBLE) / 1000 as cpu_time_seconds
FROM system.runtime.query_stats
WHERE query_id = '[QUERY_ID]'
ORDER BY wall_time_ms DESC;
```

### Step 4: Create a Performance Tuning Dashboard

Create a Grafana dashboard with these panels:

1. **Query Performance Overview**:
   - Average, p95, and p99 query execution time
   - Failed queries by error type
   - Queries by user and source

2. **Resource Usage**:
   - Memory usage by node
   - CPU usage by node
   - Network I/O by node

3. **Query Execution Details**:
   - Active queries
   - Pending tasks
   - Completed tasks per second

## Conclusion

Effective monitoring is essential for maintaining a healthy and performant Trino cluster. By combining the right tools (Prometheus, Grafana) with a solid understanding of Trino's metrics, you can:

1. Identify and resolve performance issues before they impact users
2. Plan capacity based on actual resource usage
3. Track query performance and optimize for better efficiency
4. Ensure high availability and reliability

In the next lab, we'll explore more advanced performance optimization techniques for Trino. 