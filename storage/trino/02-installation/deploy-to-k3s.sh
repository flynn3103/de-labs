#!/bin/bash

# Deploy Trino Cluster to K3s
echo "Deploying Trino Cluster to K3s..."

# Create namespace if it doesn't exist
kubectl create namespace trino 2>/dev/null || true
echo "Namespace 'trino' ready"

# Deploy Helm Chart
echo "Deploying Helm Chart..."
helm upgrade --install trino-cluster ./helm-charts \
  --namespace trino \
  --wait \
  --timeout 10m

echo "Deployment completed!"

# Show pods status
echo "Checking pods status..."
kubectl get pods -n trino

# Show services
echo "Available services:"
kubectl get services -n trino 