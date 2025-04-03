# Lab 11: High Availability and Fault Tolerance in Trino

This lab guides you through implementing high availability and fault tolerance for Trino in a production environment.

## Theory: High Availability Fundamentals

High availability (HA) is the ability of a system to remain operational despite component failures. In distributed systems like Trino, achieving high availability requires addressing several key principles:

### Redundancy

Redundancy involves having multiple copies of components to eliminate single points of failure. In Trino, this means:

- **Coordinator Redundancy**: Multiple coordinator nodes that can serve client requests
- **Worker Redundancy**: Extra worker capacity to handle node failures
- **Service Redundancy**: Replicated discovery and metadata services

### Fault Detection

Systems need to quickly detect failures to trigger recovery mechanisms:

- **Health Checks**: Regular monitoring of node status
- **Timeout Detection**: Identifying when components stop responding
- **Resource Monitoring**: Detecting resource exhaustion and performance degradation

### Fault Recovery

Once a failure is detected, the system must recover gracefully:

- **Task Rescheduling**: Moving failed tasks to healthy workers
- **Query Retry**: Automatically retrying failed queries
- **Node Replacement**: Adding new nodes to replace failed ones

### Statelessness

Minimizing state dependencies makes recovery easier:

- **Shared-Nothing Architecture**: Nodes operate independently
- **Distributed State**: Critical state is replicated across multiple nodes
- **External State Stores**: Reliable external systems for persistent state

## Theory: Trino's High Availability Architecture

Trino's architecture provides several features that support high availability:

### Coordinator High Availability

The coordinator is a potential single point of failure in a Trino cluster. To address this:

1. **Multiple Coordinators**: Trino supports deploying multiple coordinator nodes
2. **Discovery Service**: Coordinates communication between nodes
3. **Load Balancing**: Distributes client connections across coordinators

When operating with multiple coordinators:
- Each coordinator operates independently
- All coordinators share the same view of the cluster
- If one coordinator fails, clients can connect to another

### Worker Fault Tolerance

Trino can handle worker failures during query execution:

1. **Task Redundancy**: Some operations can be repeated if a worker fails
2. **Task Retries**: Failed tasks can be retried on other workers
3. **Graceful Degradation**: The system continues operating with reduced capacity

### Query Execution Resilience

Trino's execution model supports fault tolerance:

1. **Split Processing**: Queries are divided into splits processed independently
2. **Exchange Deduplication**: Prevents duplicate results during retries
3. **Checkpoint/Resume**: Some operations can be resumed from checkpoints

## Prerequisites

- Completion of Lab 9 (AWS EKS Deployment)
- Basic understanding of high availability concepts
- Familiarity with Kubernetes StatefulSets and networking

## Part 1: Understanding Trino Availability Requirements

### Key Components for Availability

1. **Coordinator Availability**: Critical for query acceptance and management
2. **Worker Availability**: Needed for query execution
3. **Catalog Availability**: Access to underlying data sources
4. **State Management**: Metadata and coordinator state
5. **Network Reliability**: Between components and external systems

### Availability Targets

Depending on your requirements, define your availability targets:

| Availability Level | Uptime | Downtime Per Year | Common Use Cases |
|-------------------|--------|-------------------|-----------------|
| 99% (two nines) | 3.65 days | Analytical workloads with flexible SLAs |
| 99.9% (three nines) | 8.76 hours | Business intelligence applications |
| 99.95% (high availability) | 4.38 hours | Business-critical reporting |
| 99.99% (four nines) | 52.56 minutes | Mission-critical applications |

### Theory: Availability Design Decisions

When designing for high availability, you must make several key decisions:

1. **Recovery Time Objective (RTO)**: How quickly must the system recover from failures?
   - Seconds: For critical real-time applications
   - Minutes: For most interactive analytics
   - Hours: For batch processing

2. **Recovery Point Objective (RPO)**: How much data loss is acceptable?
   - Zero: No data loss tolerated
   - Query-level: Only current queries affected
   - Session-level: User sessions might be lost

3. **Reliability vs. Cost**: Higher availability requires more resources
   - 99.9%: Typically requires multiple AZs
   - 99.99%: Typically requires multiple regions
   - 99.999%: Requires significant engineering effort and cost

## Part 2: Multi-Coordinator Setup

Trino supports running multiple coordinators in an active-active configuration.

### Theory: Discovery Service Architecture

The discovery service is a crucial component for multi-coordinator setups:

1. **Purpose**: Enables nodes to discover each other dynamically
2. **Implementation**: Runs as separate service or embedded in Trino nodes
3. **Consistency**: Maintains consistent view of cluster topology

The discovery service protocol ensures:
- Coordinators know about all workers
- Workers know which coordinators are available
- Failed nodes are detected and removed

### Step 1: Update Helm Values for Multiple Coordinators

```yaml
# In trino-values.yaml
server:
  coordinators: 2  # Run 2 coordinator instances
  
  # Must configure discovery service for multiple coordinators
  etc:
    config.properties: |
      coordinator=true
      node-scheduler.include-coordinator=false
      discovery-server.enabled=true
      discovery.uri=http://trino-discovery:8080
      
# Add discovery service configuration
discovery:
  enabled: true
  image: "trinodb/trino"
  tag: "396"
  replicas: 3  # Run discovery service with 3 replicas for HA
```

**Configuration Explained**:
- `coordinators: 2`: Deploys two coordinator nodes instead of one
- `discovery-server.enabled=true`: Enables the discovery server component
- `discovery.uri=http://trino-discovery:8080`: Points to the discovery service endpoint
- `replicas: 3`: Runs the discovery service in a 3-node configuration for quorum-based consensus

### Step 2: Deploy the Updated Configuration

```bash
helm upgrade trino trino/trino -n trino -f trino-values.yaml
```

### Step 3: Verify the Multi-Coordinator Setup

```bash
# Check all pods are running
kubectl get pods -n trino

# Should see multiple coordinator pods and discovery service pods
```

## Theory: Worker Fault Tolerance in Trino

Trino's architecture allows for worker node failures without causing query failures through several mechanisms:

1. **Task Distribution**: Each worker executes tasks independently
2. **Task Retries**: Failed tasks can be retried on other workers
3. **Exchange Fault Tolerance**: Data exchange between workers can handle failures
4. **Backpressure**: Prevents overwhelmed workers from affecting others

These mechanisms allow Trino to continue processing queries even when some workers fail.

## Part 3: Worker Fault Tolerance

### Step 1: Configure Worker Redundancy and Anti-affinity

Update the Helm values to ensure workers are distributed across nodes:

```yaml
# In trino-values.yaml
server:
  workers: 5  # Minimum workers for redundancy
  
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - trino
            - key: component
              operator: In
              values:
              - worker
          topologyKey: kubernetes.io/hostname
```

**Configuration Explained**:
- `workers: 5`: Maintains a minimum of 5 worker nodes to handle worker failures gracefully
- `podAntiAffinity`: Kubernetes scheduling constraint that tries to place worker pods on different physical nodes
- `preferredDuringSchedulingIgnoredDuringExecution`: A soft constraint that Kubernetes will try to satisfy
- `topologyKey: kubernetes.io/hostname`: Distributes pods across different physical hosts

### Theory: Pod Disruption Budgets

In Kubernetes, Pod Disruption Budgets (PDBs) are a critical tool for maintaining high availability during planned maintenance:

1. **Purpose**: Limits voluntary disruptions to maintain service availability
2. **Mechanism**: Prevents too many pods from being down simultaneously
3. **Application**: Essential for node drains, upgrades, and scaling operations

### Step 2: Configure Pod Disruption Budgets

Create a PDB to ensure minimum worker availability during node maintenance:

```yaml
# trino-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: trino-worker-pdb
  namespace: trino
spec:
  minAvailable: 3  # Always keep at least 3 workers running
  selector:
    matchLabels:
      app: trino
      component: worker
```

**Configuration Explained**:
- `minAvailable: 3`: Ensures at least 3 worker pods remain available during disruptions
- Instead of `minAvailable`, you could use `maxUnavailable` to specify the maximum number of pods that can be unavailable

Apply the PDB:

```bash
kubectl apply -f trino-pdb.yaml
```

## Part 4: Resilient Query Execution

### Theory: Query Fault Tolerance

Trino's query execution model includes several fault tolerance features:

1. **Retry Policies**: Determine how and when to retry failed tasks or stages
2. **Fault-Tolerant Execution**: Mechanisms to handle failures during query execution
3. **Graceful Shutdown**: Proper handling of in-progress queries during node shutdown

### Step 1: Configure Query Retry Policies

```properties
# In coordinator config.properties
retry-policy=TASK
query.max-execution-time=4h
retry.max-attempts=3
```

**Configuration Explained**:
- `retry-policy=TASK`: Retries individual tasks rather than entire stages when failures occur
- `query.max-execution-time=4h`: Sets a maximum query runtime of 4 hours
- `retry.max-attempts=3`: Allows up to 3 retry attempts for failed tasks

### Step 2: Configure Fault-Tolerant Execution

```properties
# In coordinator config.properties
fault-tolerant-execution-target-task-input-size=10MB
fault-tolerant-execution-task-descriptors-batch-size=30
fault-tolerant-execution-min-task-duration=10s
exchange.deduplication-buffer-size=20MB
```

**Configuration Explained**:
- `fault-tolerant-execution-target-task-input-size`: Target size for task inputs to balance performance and retry overhead
- `fault-tolerant-execution-task-descriptors-batch-size`: Number of tasks to process in a batch
- `fault-tolerant-execution-min-task-duration`: Minimum task duration for retry eligibility
- `exchange.deduplication-buffer-size`: Buffer size for deduplicating exchange data during retries

### Step 3: Configure Graceful Shutdown

```properties
# In coordinator and worker config.properties
shutdown.grace-period=2m
```

**Configuration Explained**:
- `shutdown.grace-period=2m`: Gives running queries up to 2 minutes to complete before forced termination during shutdown

## Part 5: Network and Infrastructure Resilience

### Theory: Multi-AZ Deployment Benefits

Deploying across multiple Availability Zones (AZs) provides several resilience benefits:

1. **Physical Isolation**: AZs are physically separated data centers
2. **Independent Failures**: AZ failures are generally independent events
3. **Network Separation**: Network paths between AZs are separate
4. **Power Independence**: Each AZ has independent power sources

For Trino, a multi-AZ deployment ensures that the failure of a single AZ doesn't bring down the entire cluster.

### Step 1: Configure Multi-AZ Deployment

Ensure your Kubernetes nodes span multiple availability zones:

```hcl
# In eks.tf
module "eks" {
  # ...
  
  eks_managed_node_groups = {
    trino_workers = {
      min_size     = 3
      max_size     = 10
      desired_size = 5
      
      instance_types = ["r5.2xlarge"]
      capacity_type  = "ON_DEMAND"
      
      # Distribute across all available AZs
      subnet_ids = module.vpc.private_subnets
    }
  }
}
```

**Configuration Explained**:
- `subnet_ids = module.vpc.private_subnets`: Distributes nodes across all private subnets, which span multiple AZs
- `min_size = 3`: Ensures at least one node in each AZ (assuming 3 AZs)

### Theory: Service Mesh Benefits

A service mesh provides several advantages for high availability:

1. **Intelligent Routing**: Directs traffic away from failing instances
2. **Circuit Breaking**: Prevents cascading failures from overloaded services
3. **Retries and Timeouts**: Automatically retries failed requests
4. **Observability**: Provides detailed metrics on service health

### Step 2: Set Up a Resilient Service Mesh (Optional)

For advanced network reliability, deploy Istio:

```bash
# Install Istio
istioctl install --set profile=default -y

# Enable Istio sidecar injection for Trino namespace
kubectl label namespace trino istio-injection=enabled
```

Add Istio configuration for circuit breaking and retry:

```yaml
# trino-istio.yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: trino-destination
  namespace: trino
spec:
  host: trino-headless
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
        connectTimeout: 30ms
      http:
        maxRequestsPerConnection: 10
        maxRetries: 3
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
```

**Configuration Explained**:
- `connectionPool`: Limits the maximum number of connections to prevent overload
- `maxRetries: 3`: Allows up to 3 retries for failed HTTP requests
- `outlierDetection`: Automatically ejects failing hosts from the load balancing pool
  - `consecutive5xxErrors: 5`: Considers a host unhealthy after 5 consecutive errors
  - `baseEjectionTime: 30s`: Removes unhealthy hosts for 30 seconds

Apply the Istio configuration:

```bash
kubectl apply -f trino-istio.yaml
```

## Part 6: Catalog and Storage Resilience

### Theory: Metastore High Availability

The Hive metastore is a critical component for data lake access:

1. **Purpose**: Stores metadata about tables, partitions, and schemas
2. **Failure Impact**: If the metastore is unavailable, queries against Hive tables fail
3. **HA Design**: Requires redundant metastore services and a replicated database

### Step 1: Highly Available Hive Metastore

If using Hive connector, deploy a highly available metastore:

```yaml
# hive-metastore.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: hive-metastore
  namespace: trino
spec:
  serviceName: hive-metastore-headless
  replicas: 2
  selector:
    matchLabels:
      app: hive-metastore
  template:
    metadata:
      labels:
        app: hive-metastore
    spec:
      containers:
      - name: hive-metastore
        image: apache/hive:3.1.2
        command:
        - "/bin/bash"
        - "-c"
        - "/opt/hive/bin/hive --service metastore"
        ports:
        - containerPort: 9083
          name: metastore
        env:
        - name: DB_DRIVER
          value: "org.mariadb.jdbc.Driver"
        - name: DB_URL
          value: "jdbc:mysql://hive-metastore-mysql:3306/metastore"
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: hive-metastore-secrets
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: hive-metastore-secrets
              key: password
```

**Configuration Explained**:
- `StatefulSet`: Provides stable network identities and persistent storage
- `replicas: 2`: Deploys two instances of the metastore service for redundancy
- `serviceName: hive-metastore-headless`: Creates a headless service for direct pod access

### Theory: Database Replication

For critical metadata, database replication provides:

1. **Redundancy**: Multiple database instances with identical data
2. **Failover**: Automatic switching to a standby instance on failure
3. **Consistency Models**: Synchronous or asynchronous replication with different consistency guarantees

### Step 2: Resilient Database for Metastore

Deploy MySQL with replication for the Hive Metastore database:

```yaml
# metastore-mysql.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: hive-metastore-mysql
  namespace: trino
spec:
  serviceName: hive-metastore-mysql
  replicas: 2
  selector:
    matchLabels:
      app: hive-metastore-mysql
  template:
    metadata:
      labels:
        app: hive-metastore-mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: hive-metastore-secrets
              key: root-password
        - name: MYSQL_DATABASE
          value: "metastore"
        - name: MYSQL_USER
          valueFrom:
            secretKeyRef:
              name: hive-metastore-secrets
              key: username
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: hive-metastore-secrets
              key: password
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "gp3"
      resources:
        requests:
          storage: 20Gi
```

**Configuration Explained**:
- `replicas: 2`: Creates a primary and replica MySQL instance
- `volumeClaimTemplates`: Provisions persistent storage for each MySQL instance
- `storageClassName: "gp3"`: Uses AWS EBS gp3 volumes for better performance

## Part 7: Disaster Recovery Planning

### Theory: Disaster Recovery Principles

A comprehensive DR plan includes:

1. **Definition of Disaster Scenarios**: What constitutes a disaster
2. **Recovery Team Roles**: Who does what during recovery
3. **Runbooks**: Step-by-step procedures for each recovery scenario
4. **Communication Plan**: How to communicate during an outage
5. **Testing**: Regular tests of recovery procedures

### Step 1: Configure Regular State Backups

Implement automated backups of critical state:

1. Metastore database backup:
```bash
kubectl create cronjob hive-metastore-backup --image=mysql:8.0 --schedule="0 2 * * *" --namespace=trino -- /bin/sh -c 'mysqldump -h hive-metastore-mysql -u$MYSQL_USER -p$MYSQL_PASSWORD metastore | gzip > /backup/metastore-$(date +%Y%m%d).sql.gz && aws s3 cp /backup/metastore-$(date +%Y%m%d).sql.gz s3://trino-backup/metastore/'
```

**Configuration Explained**:
- `--schedule="0 2 * * *"`: Runs daily at 2:00 AM
- `mysqldump`: Creates a SQL dump of the entire metastore database
- `aws s3 cp`: Copies the backup to S3 for durable storage

2. EBS snapshot backups (using AWS Backup):

```hcl
# In terraform
resource "aws_backup_plan" "trino_backup" {
  name = "trino-backup-plan"

  rule {
    rule_name         = "trino-daily-backup"
    target_vault_name = aws_backup_vault.trino_backup.name
    schedule          = "cron(0 5 ? * * *)"
    
    lifecycle {
      delete_after = 30
    }
  }
}

resource "aws_backup_selection" "trino_selection" {
  name         = "trino-backup-selection"
  plan_id      = aws_backup_plan.trino_backup.id
  iam_role_arn = aws_iam_role.backup_role.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }
}
```

**Configuration Explained**:
- `schedule = "cron(0 5 ? * * *)"`: Daily backups at 5:00 AM
- `delete_after = 30`: Retains backups for 30 days
- `selection_tag`: Selects resources to back up based on tags

### Theory: Disaster Recovery Procedures

A comprehensive DR plan includes:

1. **Restore Infrastructure**:
   ```bash
   terraform apply -var-file=prod.tfvars
   ```

2. **Restore Metastore Database**:
   ```bash
   # Create a temporary pod to restore the database
   kubectl run -n trino mysql-restore --image=mysql:8.0 --rm -i --tty -- bash
   # Inside the pod
   aws s3 cp s3://trino-backup/metastore/metastore-YYYYMMDD.sql.gz .
   gunzip metastore-YYYYMMDD.sql.gz
   mysql -h hive-metastore-mysql -u$MYSQL_USER -p$MYSQL_PASSWORD metastore < metastore-YYYYMMDD.sql
   ```

3. **Restore Services**:
   ```bash
   # Apply base configurations
   kubectl apply -f trino-namespace.yaml
   
   # Deploy services
   helm install trino trino/trino -n trino -f trino-values.yaml
   ```

4. **Verify Restoration**:
   ```bash
   # Verify all pods are running
   kubectl get pods -n trino
   
   # Run a test query
   kubectl exec -it -n trino trino-coordinator-0 -- trino-cli --execute "SHOW CATALOGS"
   ```

## Part 8: Testing Fault Tolerance

### Theory: Chaos Engineering

Chaos engineering is the practice of intentionally introducing failures to verify system resilience:

1. **Purpose**: Validates that fault tolerance mechanisms work as expected
2. **Methodology**:
   - Start small and in controlled environments
   - Define steady-state behavior
   - Introduce realistic failures
   - Observe system response
   - Fix issues found
3. **Common Experiments**:
   - Instance termination
   - Network degradation
   - Resource exhaustion
   - Region or AZ failures

### Step 1: Chaos Testing with Chaos Mesh

Install Chaos Mesh for controlled failure testing:

```bash
# Install Chaos Mesh
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-mesh --create-namespace
```

### Step 2: Simulate Worker Node Failure

Create a pod-kill experiment:

```yaml
# trino-chaos.yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: trino-worker-failure
  namespace: chaos-mesh
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces:
      - trino
    labelSelectors:
      'app': 'trino'
      'component': 'worker'
  scheduler:
    cron: '@every 10m'
```

**Configuration Explained**:
- `action: pod-kill`: Terminates pods to simulate node failures
- `mode: one`: Kills one pod at a time
- `cron: '@every 10m'`: Runs the experiment every 10 minutes
- `labelSelectors`: Targets only Trino worker pods

Apply the chaos experiment:

```bash
kubectl apply -f trino-chaos.yaml
```

### Step 3: Monitoring During Failure Testing

Monitor system behavior during chaos testing:

1. Check for query failures:
   ```bash
   kubectl port-forward -n monitoring svc/grafana 3000:80
   ```
   
   Access Grafana dashboard to monitor:
   - Query success rate
   - Query latency during failures
   - Worker recovery time

2. Check logs for fault tolerance messages:
   ```bash
   kubectl logs -n trino -l app=trino,component=coordinator | grep "retry"
   ```

## Theory: Measuring High Availability

To evaluate the effectiveness of your HA implementation, track these metrics:

1. **Availability Percentage**: Actual uptime divided by planned uptime
   - Formula: (Total Time - Downtime) / Total Time × 100%

2. **Mean Time Between Failures (MTBF)**: Average time between system failures
   - Formula: Total Operational Time / Number of Failures

3. **Mean Time To Recovery (MTTR)**: Average time to restore service after a failure
   - Formula: Total Downtime / Number of Failures

4. **Error Budget**: Allowable downtime based on SLA
   - Example: With a 99.9% SLA, you have an error budget of 43.8 minutes per month

## Conclusion

A properly configured high availability Trino deployment can achieve 99.9% or higher availability. By implementing redundancy at multiple levels (coordinators, workers, network, and storage), you create a resilient system that can withstand various types of failures.

Remember that high availability is not a single feature but a collection of configurations and practices that together create a fault-tolerant system. 