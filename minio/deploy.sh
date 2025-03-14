#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Apply manifests with absolute paths
kubectl apply -f "${SCRIPT_DIR}/manifests/01-namespace.yaml"
kubectl apply -f "${SCRIPT_DIR}/manifests/02-storage.yaml"
kubectl apply -f "${SCRIPT_DIR}/manifests/03-minio.yaml"

echo "Waiting for MinIO to be ready..."
kubectl wait --for=condition=ready pod -l app=minio -n de-labs --timeout=300s

echo "MinIO deployment completed!"