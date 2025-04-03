# Lab 4: Deploying Trino on Kubernetes (k3s)

This lab guides you through deploying Trino on Kubernetes using k3s, a lightweight Kubernetes distribution.

## Prerequisites

- Basic understanding of Kubernetes concepts
- k3s installed on your machine or a k3s cluster available
- kubectl configured to access your k3s cluster
- Helm v3 installed

## Step 1: Set Up k3s (if not already installed)

```bash
# Install k3s
curl -sfL https://get.k3s.io | sh -

# Copy the kubeconfig to the default location
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

# Verify the cluster is running
kubectl get nodes
```

## Step 2: Create Namespace for Trino

```bash
kubectl create namespace trino
```

## Step 3: Deploy Trino Using Helm

We'll use the Helm chart for Trino deployment.

### a. Add the Trino Helm repository

```bash
helm repo add trino https://trinodb.github.io/charts
helm repo update
```

### b. Create a values.yaml file for customization

Create a file named `trino-values.yaml`:

```yaml
server:
  workers: 2
  coordinatorExtraConfig:
    query.max-memory: 4GB
    query.max-memory-per-node: 1GB
    query.max-total-memory-per-node: 2GB
  
  workerExtraConfig:
    query.max-memory-per-node: 1GB
    query.max-total-memory-per-node: 2GB

  catalogConfigMap:
    configMapName: trino-catalogs
  
  additionalVolumes:
    - name: trino-catalog-volume
      configMap:
        name: trino-catalogs

  additionalVolumeMounts:
    - name: trino-catalog-volume
      mountPath: /etc/trino/catalog

resources:
  server:
    jvm:
      maxHeapSize: "4G"
    resources:
      requests:
        memory: "4Gi"
        cpu: "1"
      limits:
        memory: "4Gi"
        cpu: "2"

securityContext:
  server:
    runAsUser: 1000
    runAsGroup: 1000
```

### c. Create ConfigMap for catalog configuration

Create a file named `trino-catalogs-configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: trino-catalogs
  namespace: trino
data:
  memory.properties: |
    connector.name=memory
    memory.max-data-per-node=1GB
  
  tpch.properties: |
    connector.name=tpch
    tpch.scaling-factor=1
```

Apply the ConfigMap:

```bash
kubectl apply -f trino-catalogs-configmap.yaml
```

### d. Install Trino using Helm

```bash
helm install trino trino/trino -n trino -f trino-values.yaml
```

## Step 4: Verify the Deployment

```bash
# Check if the pods are running
kubectl get pods -n trino

# Check the services
kubectl get svc -n trino
```

## Step 5: Access Trino

### a. Port forward the Trino service to access the UI

```bash
kubectl port-forward -n trino svc/trino 8080:8080
```

Now you can access the Trino UI at http://localhost:8080

### b. Using the Trino CLI from within the cluster

```bash
# Get into the coordinator pod
kubectl exec -it -n trino $(kubectl get pods -n trino -l "app=trino,component=coordinator" -o jsonpath="{.items[0].metadata.name}") -- /bin/bash

# Run the Trino CLI
trino
```

## Step 6: Adding Resources to Your Trino Deployment

### a. Adding more connectors

To add more connectors, update the `trino-catalogs-configmap.yaml` file:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: trino-catalogs
  namespace: trino
data:
  memory.properties: |
    connector.name=memory
    memory.max-data-per-node=1GB
  
  tpch.properties: |
    connector.name=tpch
    tpch.scaling-factor=1

  mysql.properties: |
    connector.name=mysql
    connection-url=jdbc:mysql://mysql.default.svc.cluster.local:3306/example
    connection-user=root
    connection-password=password
```

Apply the updated ConfigMap:

```bash
kubectl apply -f trino-catalogs-configmap.yaml
```

Restart the Trino pods to pick up the new configuration:

```bash
kubectl rollout restart deployment -n trino
```

## Step 7: Scaling Trino

To scale the number of worker nodes:

```bash
# Using Helm
helm upgrade trino trino/trino -n trino --set server.workers=3 -f trino-values.yaml

# Using kubectl
kubectl scale deployment trino-worker -n trino --replicas=3
```

## Step 8: Clean Up

When you're done, you can delete the Trino deployment:

```bash
helm uninstall trino -n trino
kubectl delete namespace trino
```

## Next Steps

In the next lab, you'll learn about security and governance in Trino. 