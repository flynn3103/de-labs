# Lab 9: Deploying Trino on AWS EKS

This lab guides you through deploying Trino on Amazon EKS for production workloads, using Terraform for infrastructure provisioning and Helm for Kubernetes deployments.

## Theory: Why Kubernetes for Trino?

Trino's distributed architecture makes it an ideal candidate for deployment on Kubernetes. Here's why Kubernetes is a great platform for Trino:

1. **Dynamic Scaling**: Kubernetes allows for automatic scaling of Trino workers based on workload demands, optimizing resource utilization.
2. **High Availability**: Kubernetes provides self-healing capabilities, automatically replacing failed pods and distributing workloads across nodes.
3. **Resource Isolation**: Containers provide consistent environments and resource isolation for Trino components.
4. **Declarative Configuration**: Infrastructure-as-code approaches allow for reproducible, version-controlled deployments.

## Theory: AWS EKS Architecture for Trino

Before we dive into the hands-on portion, let's understand the recommended architecture for Trino on EKS:

### Core Components

1. **VPC and Network Design**
   - Private subnets for Trino pods (improved security)
   - Public subnets for load balancers and NAT gateways
   - Multi-AZ deployment for high availability

2. **EKS Cluster**
   - Managed control plane (AWS-maintained)
   - Self-managed worker nodes (flexibility in instance types)
   - Auto-scaling for cost optimization

3. **Trino Deployment Model**
   - Coordinator: Stateless but requires stable endpoint
   - Workers: Horizontal scaling based on query load
   - Discovery service: For coordinator HA (optional)

4. **Storage Architecture**
   - Worker nodes: Memory-optimized instances
   - Catalog connections: Direct to data sources
   - Spill-to-disk: EBS volumes for memory-intensive queries

### Recommended Instance Types

- **Coordinator**: CPU-optimized (c5.2xlarge, c5.4xlarge)
- **Workers**: Memory-optimized (r5.2xlarge, r5.4xlarge, r6g.2xlarge)
- **Discovery Service**: General purpose (m5.large)

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured locally
- Terraform installed (v1.0+)
- kubectl configured
- helm installed (v3+)
- Basic understanding of AWS services and Kubernetes

## Part 1: Setting Up EKS with Terraform

### Step 1: Clone the Terraform Configuration

The terraform configuration provided contains everything needed to set up a production-ready EKS cluster for Trino:

```bash
# Clone or navigate to your terraform directory
cd terraform/
```

### Step 2: Understand the Terraform Files

Let's examine the key files:

- `main.tf`: Contains provider configurations and locals
- `vpc.tf`: Defines networking components
- `eks.tf`: Creates the EKS cluster
- `trino.tf`: Sets up Trino-specific configurations
- `karpenter.tf`: Configures Karpenter for auto-scaling
- `addons.tf`: Adds necessary EKS add-ons
- `variables.tf`: Defines configurable input variables

#### Key Configuration: AWS Provider

```hcl
provider "aws" {
  region = var.region
}
```

This specifies the AWS region where your infrastructure will be deployed. Choose a region closest to your users or data sources to minimize latency.

#### Key Configuration: EKS Module

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
  
  cluster_name    = local.name
  cluster_version = "1.26"
}
```

The EKS module creates the Kubernetes control plane. Version selection is important:
- EKS 1.26+ supports Kubernetes features required for advanced Trino deployment
- Newer versions provide better security and performance features

### Step 3: Initialize and Apply Terraform

```bash
# Initialize terraform
terraform init

# See what changes will be made
terraform plan

# Apply the configuration
terraform apply
```

Or use the provided installation script:

```bash
./terraform/_install.sh
```

This will provision:
- A VPC with public and private subnets
- An EKS cluster
- Node groups for Trino workers
- Karpenter for auto-scaling
- Addon services like EBS CSI Driver, Metrics Server, etc.

### Theory: Understanding VPC Design for Trino

The VPC configuration is critical for security, performance, and high availability:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"
  
  name = local.name
  cidr = "10.0.0.0/16"
  
  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  
  # Tagging for EKS auto-discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = local.name
  }
}
```

- **CIDR Block (10.0.0.0/16)**: Provides up to 65,536 IP addresses
- **Multiple AZs**: For high availability and fault tolerance
- **Private Subnets**: For Trino pods (more secure)
- **Public Subnets**: For load balancers and NAT gateways
- **NAT Gateway**: Allows private instances to access the internet
- **Subnet Tagging**: Essential for EKS to discover subnets and provision load balancers

### Theory: EKS Node Groups and Karpenter

In this deployment, we use a combination of EKS Managed Node Groups and Karpenter for autoscaling:

```hcl
module "eks" {
  # ...
  
  eks_managed_node_groups = {
    initial = {
      instance_types = ["m5.large"]
      min_size     = 2
      max_size     = 10
      desired_size = 2
    }
  }
}
```

**Managed Node Groups**:
- Provide initial capacity
- Automatically apply security patches and updates
- Support Auto Scaling Groups

**Karpenter**:
- Provides faster scaling (seconds vs. minutes)
- Supports diverse instance types (cost optimization)
- Bin-packing capability for better resource utilization

## Part 2: Understanding the AWS Architecture

The terraform configuration creates a production-grade architecture:

### EKS Cluster Configuration

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
  
  cluster_name    = local.name
  cluster_version = "1.26"
  
  cluster_endpoint_public_access = true
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  # Managed node groups for initial capacity
  eks_managed_node_groups = {
    initial = {
      instance_types = ["m5.large"]
      min_size     = 2
      max_size     = 10
      desired_size = 2
    }
  }
}
```

**Key Parameters Explained**:

- `cluster_endpoint_public_access`: Enables access to the Kubernetes API server from outside the VPC. For production, you might want to restrict this with CIDR blocks.
- `vpc_id` and `subnet_ids`: Places the EKS cluster in the private subnets of our VPC for security
- `instance_types`: m5.large provides a balanced compute-to-memory ratio for initial nodes
- `min_size` and `max_size`: Controls the scaling boundaries for the worker nodes

## Part 3: Deploying Trino using Helm

### Theory: Helm Charts for Trino

Helm uses charts to define, install, and upgrade Kubernetes applications. The Trino Helm chart abstracts many of the complex Kubernetes configurations needed:

1. **StatefulSets**: For coordinator and workers with stable network identities
2. **ConfigMaps**: For storing Trino configurations
3. **Services**: For internal and external access to Trino
4. **Secrets**: For storing sensitive information
5. **Volumes**: For persistent storage

### Step 1: Review Helm Values Configuration

Examine the `trino.yaml` file which contains the values for the Trino Helm chart:

```yaml
image:
  repository: "trinodb/trino"
  tag: "396"
  pullPolicy: "IfNotPresent"

server:
  workers: 2
  
  coordinatorExtraConfig:
    http-server.http.port: 8080
    discovery.uri: http://trino-headless:8080
    
  workerExtraConfig:
    http-server.http.port: 8080
    discovery.uri: http://trino-headless:8080
    
  resources:
    requests:
      memory: "8Gi"
      cpu: "2"
    limits:
      memory: "8Gi"
      cpu: "4"
      
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
```

**Configuration Parameters Explained**:

- `image.tag`: "396" refers to Trino version 396. Choose a stable version for production.
- `server.workers`: Initial number of worker nodes. Start with 2 for testing, scale based on workload.
- `discovery.uri`: Points to the headless service for coordinator discovery. Critical for multi-coordinator setups.
- `resources`: 
  - Memory requests and limits are equal to prevent OOM issues 
  - CPU limits are higher than requests to allow for burst capacity
- `autoscaling`: HPA configuration to scale workers based on CPU utilization
  - `targetCPUUtilizationPercentage: 80`: Triggers scaling when CPU usage reaches 80%

### Step 2: Deploy Trino with Helm

After provisioning the EKS cluster, deploy Trino using Helm:

```bash
# Create namespace
kubectl create namespace trino

# Deploy Trino
helm repo add trino https://trinodb.github.io/charts
helm install trino trino/trino -n trino -f trino.yaml
```

Or use the provided script:

```bash
./helm/_deploy.sh
```

### Step 3: Verify the Deployment

```bash
# Check the pods
kubectl get pods -n trino

# Check the services
kubectl get svc -n trino
```

## Part 4: Production-Ready Features

### Theory: High Availability in Kubernetes

Kubernetes provides several mechanisms to ensure high availability:

1. **Pod Anti-Affinity**: Distributes pods across nodes to avoid single points of failure
2. **Pod Disruption Budgets**: Ensures minimum available pods during voluntary disruptions
3. **Horizontal Pod Autoscaling**: Adjusts resources based on load
4. **Topology Spread Constraints**: Distributes pods across failure domains

### Step 1: High Availability Configuration

The terraform and helm configurations include high availability features:

1. **Multi-AZ Deployment**: EKS cluster spans multiple availability zones
2. **Worker Redundancy**: Multiple Trino workers for query processing
3. **Auto-scaling**: Karpenter and HPA for dynamic scaling
4. **Pod Disruption Budgets**: Protect against disruption during maintenance

### Theory: Monitoring Architecture for Trino

A comprehensive monitoring stack is essential for production Trino deployments:

1. **Metrics Collection**: Prometheus scrapes metrics from Trino JMX exporter
2. **Metric Storage**: Prometheus time-series database 
3. **Visualization**: Grafana dashboards
4. **Alerting**: Prometheus AlertManager

### Step 2: Monitoring and Observability

1. **Metrics Server**: For basic Kubernetes metrics
2. **Prometheus and Grafana**: For more comprehensive monitoring (configured in `kube-prometheus.yaml`)

```bash
# Deploy the monitoring stack
kubectl apply -f kube-prometheus.yaml
```

### Theory: Logging Architecture

Centralized logging is critical for troubleshooting and auditability:

1. **Log Collection**: FluentBit collects container logs
2. **Log Destination**: AWS CloudWatch Logs provides durable storage
3. **Log Aggregation**: CloudWatch Log Insights for searching and analysis

### Step 3: Logging

The configuration includes AWS for FluentBit setup for centralized logging to CloudWatch:

```yaml
# From aws-for-fluentbit-values.yaml
cloudWatch:
  enabled: true
  region: "us-west-2"
  logGroupName: "/aws/eks/trino-cluster/logs"
  logStreamPrefix: "fluentbit-"
```

Key configuration parameters:
- `logGroupName`: Organizes logs by cluster
- `logStreamPrefix`: Makes it easier to filter logs by source

```bash
# Deploy FluentBit
helm install aws-for-fluentbit eks/aws-for-fluentbit -n kube-system -f aws-for-fluentbit-values.yaml
```

## Part 5: Trino-Specific Production Considerations

### Theory: Memory Management in Trino

Trino is memory-intensive, requiring specific considerations:

1. **JVM Heap Size**: Typically 70-80% of container memory
2. **Query Memory Limits**: Prevents single queries from consuming all resources
3. **Spill to Disk**: Allows memory-intensive operations to use disk when memory is limited

### Step 1: Persistent Storage for Spill Files

Configure storage for spill files when memory is insufficient:

```yaml
server:
  additionalVolumes:
    - name: trino-spill
      emptyDir: {}
      
  additionalVolumeMounts:
    - name: trino-spill
      mountPath: /tmp/spill
      
  config:
    spiller-spill-path: /tmp/spill
```

**Configuration Explained**:
- `emptyDir`: Provides ephemeral storage tied to pod lifecycle
- `spiller-spill-path`: Tells Trino where to write spill files when memory limits are reached
- For production, consider using EBS volumes instead of emptyDir for better performance

### Theory: Advanced Scaling with KEDA

KEDA (Kubernetes Event-driven Autoscaling) provides more sophisticated scaling than HPA:

1. **Custom Metrics**: Scales based on Trino-specific metrics
2. **Scheduled Scaling**: Handles predictable workload patterns
3. **Multiple Triggers**: Combines different scaling criteria

### Step 2: Resource Management with KEDA

For better autoscaling based on Trino metrics, KEDA is configured in `trino-keda.yaml`:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: trino-worker-scaledobject
  namespace: trino
spec:
  scaleTargetRef:
    name: trino-worker
  minReplicaCount: 2
  maxReplicaCount: 15
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-operated.monitoring.svc.cluster.local:9090
      metricName: trino_active_queries
      threshold: "10"
      query: sum(trino_active_queries)
```

**Configuration Explained**:
- `minReplicaCount` and `maxReplicaCount`: Define the scaling boundaries
- `metricName` and `query`: Scale based on the number of active Trino queries
- `threshold: "10"`: Adds one worker for every 10 active queries

```bash
# Apply KEDA configuration
kubectl apply -f trino-keda.yaml
```

## Part 6: Cleaning Up

When you're done with the lab, clean up resources to avoid unnecessary charges:

```bash
# Destroy terraform-created resources
terraform destroy
```

Or use the cleanup script:

```bash
./terraform/_cleanup.sh
```

## Theory: Design Considerations for Production

When moving beyond this lab to a full production deployment, consider:

1. **Network Access Controls**:
   - Private cluster endpoints
   - Network policies for pod-to-pod communication
   - Service mesh for advanced traffic management

2. **Security Hardening**:
   - Pod security policies
   - Image vulnerability scanning
   - Secrets management with AWS Secrets Manager

3. **Backup and Recovery**:
   - Regular EBS snapshots
   - Disaster recovery procedures
   - Cross-region replication for critical metadata

4. **Optimization**:
   - Custom instance type selection
   - Spot instance integration
   - Cluster autoscaler tuning

## Next Steps

In the next lab, you'll learn about cost optimization and capacity planning for Trino on AWS. 