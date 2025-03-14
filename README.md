# Data Engineering Labs

This repository provides a development environment for data engineering labs.

## Prerequisites

- Python 3.12 or higher
- k3d (for local Kubernetes cluster)
- kubectl (for Kubernetes cluster management)
- uv (Python package installer)

## Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd de-labs
   ```

2. Create a virtual environment and install dependencies using uv:
   ```bash
   uv venv
   source .venv/bin/activate  # On Unix/macOS
   # OR
   .venv\Scripts\activate  # On Windows
   
   uv pip install .
   ```

## Cluster Setup

1. Create a local Kubernetes cluster:
   ```bash
   make create-k3d-cluster
   ```
   This will create a k3d cluster with 1 server and 2 agent nodes.

2. Initialize the namespace:
   ```bash
   make init-namespace
   ```

## Deploying Services

### Deploy All Services
```bash
make deploy svc=minio,spark
```

### Deploy Individual Services
```bash
# Deploy MinIO only
make deploy svc=minio

# Deploy Spark only
make deploy svc=spark
```

## Undeploying Services

### Undeploy All Services
```bash
make undeploy svc=minio,spark
```

### Undeploy Individual Services
```bash
# Undeploy MinIO only
make undeploy svc=minio

# Undeploy Spark only
make undeploy svc=spark
```

## Cleaning Up

1. Remove all resources from the current namespace:
   ```bash
   make clean-all
   ```

2. Delete the k3d cluster:
   ```bash
   make delete-k3d-cluster
   ```

## Troubleshooting

1. If you encounter issues with the cluster context, ensure you're using the correct kubectl context:
   ```bash
   kubectl config use-context k3d-de-labs
   ```

2. To verify the cluster status:
   ```bash
   make check-k3d-cluster
   ```