#!/bin/bash

# Script to deploy Trino on k3s
set -e

echo "Deploying Trino on k3s..."

# Check if namespace exists, create if not
if ! kubectl get namespace trino &> /dev/null; then
  echo "Creating Trino namespace..."
  kubectl create namespace trino
fi

# Add Trino Helm repo
echo "Adding Trino Helm repository..."
helm repo add trino https://trinodb.github.io/charts
helm repo update

# Deploy Trino
echo "Deploying Trino..."
helm upgrade --install trino trino/trino \
  -f $(dirname "$0")/helm/trino.yaml \
  -n trino

echo "Waiting for Trino pods to start..."

echo "Trino deployment completed!"
echo "To access Trino UI, run: kubectl port-forward -n trino svc/trino 8080:8080"
echo "Then open: http://localhost:8080" 