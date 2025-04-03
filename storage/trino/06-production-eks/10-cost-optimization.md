# Lab 10: Cost Optimization and Capacity Planning for Trino

This lab guides you through understanding the cost factors for running Trino on AWS and provides strategies for optimizing costs while maintaining performance.

## Prerequisites

- Completion of Lab 9 (AWS EKS Deployment)
- Access to AWS Cost Explorer (for production environments)
- Basic understanding of AWS pricing

## Part 1: Understanding Cost Components

When running Trino on AWS EKS, several cost components contribute to the total cost:

### 1. Compute Costs

- **EKS Cluster**: $0.10 per hour per cluster
- **EC2 Instances**: Costs vary by instance type
  - Coordinator node(s): Typically smaller but more CPU-focused (e.g., c5.2xlarge)
  - Worker nodes: Memory-optimized for query processing (e.g., r5.2xlarge, r5.4xlarge)

### 2. Storage Costs

- **EBS Volumes**: For persistent storage
- **S3**: For data lake storage (if using Hive/Iceberg connectors)
- **RDS/Aurora**: If using these as data sources

### 3. Data Transfer Costs

- **Data Transfer between AZs**: $0.01 per GB
- **Data Transfer to Internet**: Starts at $0.09 per GB, decreases with volume
- **Data Transfer within same AZ**: Free

### 4. Other Costs

- **NAT Gateway**: $0.045 per hour + data processing charges
- **Load Balancer**: If exposing Trino externally
- **CloudWatch**: For logging and monitoring

## Part 2: Analyzing a Sample Trino Deployment Cost

Let's analyze a typical medium-sized Trino deployment:

| Component | Configuration | Monthly Cost (Estimated) |
|-----------|---------------|--------------------------|
| EKS Cluster | 1 cluster | $73 |
| Coordinator | 1 × c5.2xlarge (on-demand) | $250 |
| Workers | 5 × r5.4xlarge (on-demand) | $2,640 |
| EBS Storage | 100 GB per node | $60 |
| NAT Gateway | 1 gateway | $32 + data processing |
| Load Balancer | 1 NLB | $16 + data processing |
| S3 Storage | 1 TB | $23 |
| CloudWatch | Logs & monitoring | $50 |
| **Total** | | **~$3,144** |

## Part 3: Cost Optimization Strategies

### Strategy 1: Right-sizing Instances

Analyze your workload to determine the right instance types:

```bash
# Get memory and CPU usage metrics from Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
```

Query to determine memory usage patterns:
```
max_over_time(jvm_memory_bytes_used{area="heap"}[1d]) / max_over_time(jvm_memory_bytes_max{area="heap"}[1d])
```

Query to determine CPU usage patterns:
```
max_over_time(container_cpu_usage_seconds_total{pod=~"trino-worker.*"}[1d]) / max_over_time(container_cpu_limit{pod=~"trino-worker.*"}[1d])
```

Based on the metrics, you can right-size your instances:
- If memory usage is consistently < 50%, consider downgrading instance size
- If CPU usage is consistently high, consider compute-optimized instances

### Strategy 2: Leveraging AWS Spot Instances

For worker nodes, use Spot instances to achieve up to 90% cost savings:

```hcl
# In eks.tf or karpenter.tf
resource "aws_eks_node_group" "trino_workers_spot" {
  cluster_name    = module.eks.cluster_id
  node_group_name = "trino-workers-spot"
  node_role_arn   = module.eks.worker_iam_role_arn
  subnet_ids      = module.vpc.private_subnets
  
  scaling_config {
    desired_size = 3
    max_size     = 10
    min_size     = 1
  }
  
  capacity_type  = "SPOT"
  instance_types = ["r5.2xlarge", "r5a.2xlarge", "r5d.2xlarge", "r4.2xlarge"]
}
```

With Karpenter, configure spot instance provisioning:

```yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: trino-spot
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["spot"]
    - key: node.kubernetes.io/instance-type
      operator: In
      values: ["r5.2xlarge", "r5a.2xlarge", "r5d.2xlarge"]
  limits:
    resources:
      cpu: 100
      memory: 400Gi
  provider:
    subnetSelector:
      karpenter.sh/discovery: ${cluster_name}
    securityGroupSelector:
      karpenter.sh/discovery: ${cluster_name}
  ttlSecondsAfterEmpty: 30
```

### Strategy 3: Implementing Auto-scaling

Configure aggressive downscaling during off-hours:

```yaml
# In trino-values.yaml
server:
  autoscaling:
    enabled: true
    minReplicas: 1   # Scale down to 1 worker during off-hours
    maxReplicas: 10  # Scale up to 10 workers during peak hours
    targetCPUUtilizationPercentage: 70
```

Use KEDA for more precise scaling based on Trino-specific metrics:

```yaml
# In trino-keda.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: trino-worker-scaledobject
  namespace: trino
spec:
  scaleTargetRef:
    name: trino-worker
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-operated.monitoring.svc.cluster.local:9090
      metricName: trino_running_queries
      threshold: "5"
      query: sum(trino_running_queries)
  - type: cron
    metadata:
      timezone: UTC
      start: 30 8 * * 1-5    # Scale up at 8:30 AM UTC weekdays
      end: 30 18 * * 1-5     # Scale down at 6:30 PM UTC weekdays
      desiredReplicas: "5"
```

### Strategy 4: Optimizing Storage Costs

1. **Use S3 Intelligent Tiering for data lakes**
   - Automatically moves data between frequent and infrequent access tiers

2. **Implement S3 lifecycle policies for old data**
   ```json
   {
     "Rules": [
       {
         "Status": "Enabled",
         "Prefix": "trino-data/",
         "Transition": {
           "Days": 90,
           "StorageClass": "GLACIER"
         }
       }
     ]
   }
   ```

3. **Use EBS gp3 volumes instead of gp2**
   - gp3 offers better price/performance ratio
   ```yaml
   # In trino-values.yaml
   volumeClaimTemplates:
     - metadata:
         name: data
       spec:
         accessModes: [ "ReadWriteOnce" ]
         storageClassName: gp3
         resources:
           requests:
             storage: 100Gi
   ```

### Strategy 5: Savings Plans and Reserved Instances

For production environments with predictable usage:

1. **Compute Savings Plans**: Commit to a consistent amount of compute usage
   - Can save up to 66% compared to on-demand pricing
   - Applies to EC2, Lambda, and Fargate

2. **EC2 Reserved Instances**: Reserve capacity for 1 or 3 years
   - Up to 72% discount compared to on-demand
   - Good for coordinator nodes that run continuously

## Part 4: Capacity Planning

### Step 1: Estimating Resources Based on Data Volume

Use this formula to estimate memory requirements:

```
Total Memory Needed = (Peak Concurrent Queries × Avg Query Memory) + Overhead
```

For example:
- 20 concurrent queries
- Average query using 4GB memory
- 25% overhead for system processes

Total Memory = (20 × 4GB) × 1.25 = 100GB

### Step 2: Sizing for Different Data Volumes

| Data Volume | Concurrent Queries | Recommended Configuration |
|-------------|--------------------|-----------------------------|
| < 1 TB | 5-10 | 1 coordinator (c5.2xlarge), 2-3 workers (r5.2xlarge) |
| 1-10 TB | 10-20 | 1 coordinator (c5.4xlarge), 3-5 workers (r5.4xlarge) |
| 10-100 TB | 20-50 | 1-2 coordinators (c5.4xlarge), 5-10 workers (r5.4xlarge) |
| > 100 TB | 50+ | 2+ coordinators (c5.9xlarge), 10+ workers (r5.12xlarge) |

### Step 3: Scaling for Query Complexity

Complex queries require more memory and CPU:

- **Simple Queries** (filtering, basic aggregations):
  - ~2-4GB memory per query
  - More CPU-bound than memory-bound

- **Medium Complexity** (joins between multiple tables, window functions):
  - ~4-8GB memory per query
  - Balance between CPU and memory

- **Complex Queries** (multiple joins, complex aggregations, large shuffles):
  - ~8-16GB memory per query
  - More memory-bound than CPU-bound

Adjust your worker node sizing based on your query complexity profile.

## Part 5: Implementing Cost Monitoring

### Step 1: Set Up AWS Cost Explorer Tags

Add resource tags for cost allocation:

```hcl
# In main.tf
locals {
  tags = {
    Environment = var.environment
    Project     = "trino"
    ManagedBy   = "terraform"
    CostCenter  = "data-analytics"
  }
}
```

### Step 2: Configure AWS Budgets

Set up AWS Budgets to monitor and alert on costs:

```hcl
resource "aws_budgets_budget" "trino" {
  name              = "trino-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "3000"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["alerts@yourdomain.com"]
  }
  
  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Project$trino"
    ]
  }
}
```

### Step 3: Set Up Prometheus Cost Metrics

Deploy OpenCost to get Kubernetes cost visibility:

```bash
# Add OpenCost Helm repository
helm repo add opencost https://opencost.github.io/opencost-helm-chart
helm repo update

# Install OpenCost
helm install opencost opencost/opencost -n monitoring --set opencost.ui.enabled=true
```

## Conclusion

By implementing these cost optimization strategies and right-sizing your Trino deployment, you can achieve a significant reduction in AWS costs while maintaining the performance required for your data analytics workloads. Remember that cost optimization is an ongoing process - continually monitor your usage patterns and adjust your resources accordingly. 