#!/bin/bash

# Get the directory where the script is located
WORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "WORK_DIR=$WORK_DIR"

echo "Deploying Spark operator..."

# Apply Kubernetes manifests
kubectl apply -f "${WORK_DIR}/manifests/01-namespace.yaml"
kubectl apply -f "${WORK_DIR}/manifests/02-rbac.yaml"
kubectl apply -f "${WORK_DIR}/manifests/03-operator.yaml"
kubectl apply -f "${WORK_DIR}/manifests/04-service.yaml"

echo "Spark operator deployment completed!"