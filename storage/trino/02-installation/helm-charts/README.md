# Trino Cluster Helm Chart

This Helm chart deploys a Trino cluster with supporting services on Kubernetes (K3s).

## Components

- Trino Coordinator
- PostgreSQL Database
- MongoDB
- MinIO Object Storage
- Hive Metastore (with PostgreSQL backend)

## Requirements

- Kubernetes cluster (K3s)
- Helm v3+
- kubectl configured to connect to your cluster

## Installation

```bash
# Create namespace
kubectl create namespace trino

# Install the chart
helm install trino-cluster ./helm-charts --namespace trino
```

Alternatively, use the provided deployment script:

```bash
./deploy-to-k3s.sh
```

## Configuration

Edit the `values.yaml` file to customize the deployment. Key configuration options:

- Image versions
- Resource requests and limits
- Service types and ports
- Storage sizes
- Environment variables

## Accessing Services

After deployment, services can be accessed within the cluster using their service names:

- Trino: `trino-cluster-trino:8080`
- PostgreSQL: `trino-cluster-postgres:5432`
- MongoDB: `trino-cluster-mongodb:27017`
- MinIO API: `trino-cluster-minio:9000`
- MinIO Console: `trino-cluster-minio:9001`
- Hive Metastore: `trino-cluster-hive-metastore:9083`

To access services from outside the cluster, consider using port-forwarding or Ingress resources. 