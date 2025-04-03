# Trino Terraform Deployment

This directory contains Terraform configurations for deploying Trino on Amazon EKS (Elastic Kubernetes Service).

## Architecture Overview

The deployment follows a multi-tier architecture with the following components:

### Network Architecture
```mermaid
graph TD
    subgraph VPC["VPC (10.0.0.0/16)"]
        subgraph PublicSubnets["Public Subnets (3)"]
            PublicSubnet1["10.0.101.0/24 (AZ-a)"]
            PublicSubnet2["10.0.102.0/24 (AZ-b)"]
            PublicSubnet3["10.0.103.0/24 (AZ-c)"]
            NAT["NAT Gateways"]
        end
        
        subgraph PrivateSubnets["Private Subnets (3)"]
            PrivateSubnet1["10.0.1.0/24 (AZ-a)"]
            PrivateSubnet2["10.0.2.0/24 (AZ-b)"]
            PrivateSubnet3["10.0.3.0/24 (AZ-c)"]
            EKSNodes["EKS Cluster Nodes"]
        end
        
        subgraph SecurityGroups["Security Groups"]
            EKSSG["EKS Control Plane"]
            NodeSG["EKS Node Group"]
            BastionSG["Bastion Host"]
        end
        
        subgraph RouteTables["Route Tables"]
            PublicRT["Public (IGW)"]
            PrivateRT["Private (NAT)"]
        end
    end
```

### EKS and Trino Components
```mermaid
graph TD
    subgraph EKSCluster["EKS Cluster"]
        ControlPlane["Control Plane (AWS-managed)"]
        NodeGroups["Node Groups (On-demand)"]
        KarpenterNodes["Karpenter Nodes (Auto-provisioned)"]
        
        subgraph K8sAddons["Kubernetes Add-ons"]
            AWSLB["AWS LB Controller"]
            Karpenter["Karpenter"]
            KEDA["KEDA"]
            MetricsServer["Metrics Server"]
            CoreDNS["CoreDNS"]
            Fluentbit["Fluentbit"]
            Prometheus["Prometheus"]
        end
        
        subgraph TrinoDeployment["Trino Deployment"]
            Coordinator["Coordinator Pod"]
            Workers["Workers (Autoscaled by KEDA)"]
        end
    end
```

### AWS Service Integration
```mermaid
graph TD
    subgraph AWSServices["AWS Services"]
        subgraph S3Buckets["S3 Buckets"]
            DataBucket["Data"]
            ExchangeBucket["Exchange"]
            LogsBucket["Logs"]
        end
        
        subgraph IAMRoles["IAM Roles"]
            EKSIRSA["EKS IRSA"]
            KarpenterRole["Karpenter"]
            AddonsRole["Add-ons"]
        end
        
        subgraph Glue["AWS Glue"]
            Catalog["Metadata Catalog"]
            Tables["Tables"]
            Schemas["Schemas"]
        end
        
        subgraph CloudWatch["CloudWatch"]
            Logs["Logs"]
            Metrics["Metrics"]
        end
        
        subgraph AMP["AWS Managed Prometheus"]
            Monitoring["Monitoring"]
        end
        
        subgraph ECR["Amazon ECR"]
            Images["Container Images"]
        end
    end
```

## Infrastructure Components

The Terraform configuration creates the following resources:

- **EKS Cluster**: 
  - Managed Kubernetes cluster on AWS (v1.28)
  - Control plane managed by AWS
  - Worker nodes run in private subnets
  - API server endpoints can be private or public

- **VPC and Networking**: 
  - Dedicated VPC with public and private subnets
  - 3 Availability Zones for high availability
  - NAT Gateways for outbound internet access from private subnets
  - Security groups for controlling traffic flow
  - Network ACLs for subnet-level security

- **S3 Buckets**: 
  - Data bucket for Trino (stores table data)
  - Exchange bucket for Trino's exchange manager (facilitates query distribution)
  - Event logs bucket (captures operational logs)
  - All buckets configured with server-side encryption (AES-256)
  - Lifecycle policies for cost optimization

- **IAM Roles and Policies**: 
  - EKS IRSA (IAM Roles for Service Accounts) for fine-grained permissions
  - Policies for S3 access (read/write)
  - Glue catalog access permissions
  - Least privilege principle enforced

- **Karpenter**: 
  - Kubernetes node autoscaler for dynamic scaling
  - Provisions nodes based on pod resource requirements
  - Supports multiple instance types
  - Consolidation for cost optimization

- **Kubernetes Add-ons**: 
  - AWS Load Balancer Controller for managing ALBs/NLBs
  - Metrics Server for resource metrics
  - CoreDNS for DNS resolution
  - Prometheus for monitoring
  - Fluentbit for log collection
  - KEDA for pod-based autoscaling

## Deployment Workflow

The deployment process follows this sequence:

```mermaid
graph TD
    A["1. Infrastructure Provisioning"] --> B["2. EKS Add-ons Installation"]
    B --> C["3. Karpenter Setup"]
    C --> D["4. Trino Deployment"]
    D --> E["5. Post-Deployment Configuration"]
    
    subgraph "Step 1"
    A1["VPC and network resources created"]
    A2["EKS cluster provisioned"]
    A3["IAM roles and policies established"]
    end
    
    subgraph "Step 2"
    B1["Core add-ons (CoreDNS, kube-proxy, VPC CNI)"]
    B2["Additional add-ons (Metrics Server, Load Balancer Controller)"]
    B3["Monitoring stack (Prometheus, Grafana)"]
    end
    
    subgraph "Step 3"
    C1["Provisioner configuration"]
    C2["Node templates"]
    C3["Scaling profiles"]
    end
    
    subgraph "Step 4"
    D1["S3 buckets created"]
    D2["IAM policies for Trino attached"]
    D3["Helm chart deployed with configured values"]
    D4["Service accounts with IRSA configured"]
    end
    
    subgraph "Step 5"
    E1["Kubernetes configuration updated"]
    E2["Connection details output"]
    end
    
    A --> A1 & A2 & A3
    B --> B1 & B2 & B3
    C --> C1 & C2 & C3
    D --> D1 & D2 & D3 & D4
    E --> E1 & E2
```

## Network Traffic Flow

The network traffic flows as follows:

```mermaid
graph LR
    Client["Client"] -->|"1. Inbound Query Traffic"| IGW["Internet Gateway"]
    IGW --> ELB["EKS Load Balancer"]
    ELB --> Coordinator["Trino Coordinator"]
    
    Coordinator -->|"2. Worker Communication"| Workers["Trino Workers"]
    Workers -->|"Exchange data"| Workers
    
    Coordinator -->|"3. Data Access"| Glue["AWS Glue (metadata)"]
    Workers -->|"3. Data Access"| S3["S3 (data read/write)"]
    
    subgraph "4. Monitoring and Logging"
    Nodes["Nodes"] --> CloudWatch["CloudWatch (logs)"]
    Prometheus["Prometheus"] --> AMP["AMP (metrics)"]
    Nodes --> Prometheus
    end
```

## Key Files

- **main.tf**: Main Terraform configuration file that sets up providers and locals
- **variables.tf**: Variable definitions for the Terraform configuration
- **trino.tf**: Trino-specific resources including S3 buckets and IAM policies
- **eks.tf**: EKS cluster configuration
- **karpenter.tf**: Node autoscaler configuration
- **addons.tf**: Kubernetes add-ons configuration
- **vpc.tf**: Networking configuration
- **outputs.tf**: Output variables from the Terraform deployment
- **versions.tf**: Terraform and provider version constraints

## Detailed Configuration Parameters

### Network Configuration

- `vpc_cidr`: CIDR block for the VPC (default: 10.0.0.0/16)
- `private_subnets`: List of private subnet CIDRs (default: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
- `public_subnets`: List of public subnet CIDRs (default: 10.0.101.0/24, 10.0.102.0/24, 10.0.103.0/24)
- `azs`: List of availability zones to use (varies by region)
- `enable_nat_gateway`: Enables NAT gateways for private subnets
- `single_nat_gateway`: Whether to use a single NAT gateway for all private subnets

### EKS Configuration

- `cluster_name`: Name of the EKS cluster
- `cluster_version`: Kubernetes version (default: 1.28)
- `cluster_endpoint_public_access`: Whether the API server is publicly accessible
- `cluster_endpoint_private_access`: Whether the API server is accessible from within the VPC

### Node Configuration

- `instance_types`: EC2 instance types for worker nodes (default: m5.large, m5a.large, m5n.large)
- `capacity_type`: Type of capacity to use (ON_DEMAND or SPOT)
- `min_size`: Minimum number of nodes (default: 3)
- `max_size`: Maximum number of nodes (default: 10)
- `desired_size`: Initial desired number of nodes (default: 3)

### Karpenter Configuration

- `karpenter_instance_types`: List of EC2 instance types Karpenter can provision
- `karpenter_capacity_type`: Type of capacity Karpenter should use (ON_DEMAND or SPOT)
- `karpenter_ttl_seconds_after_empty`: Time to live for empty nodes

### Trino Configuration

- S3 bucket configurations for data storage and exchange management
- IAM roles and policies for AWS Glue and S3 access
- Helm chart values for Trino deployment
- KEDA scaling configuration

## Security Considerations

- All worker nodes run in private subnets
- IAM roles follow the principle of least privilege
- S3 buckets are encrypted with SSE
- Network security groups restrict traffic flow
- Kubernetes RBAC enforced for API access
- Service accounts use IRSA for AWS resource access

## Usage

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (version specified in versions.tf)
- kubectl installed

### Deployment

To deploy the infrastructure:

```bash
./_install.sh
```

This script will:
1. Initialize Terraform
2. Apply the Terraform configuration
3. Configure kubectl to communicate with the EKS cluster

### Cleanup

To destroy all created resources:

```bash
./_cleanup.sh
```

## Resource Customization

To customize the deployment, you can modify:

- **variables.tf**: Change default values or provide a tfvars file
- **trino.tf**: Adjust S3 bucket configurations and IAM policies
- **helm-values/trino.yaml**: Modify Trino configuration parameters

## Output Values

After deployment, the following outputs are available:

- `configure_kubectl`: Command to configure kubectl to access the EKS cluster
- `cluster_endpoint`: The EKS cluster endpoint
- `data_bucket`: The name of the S3 bucket for Trino data storage 