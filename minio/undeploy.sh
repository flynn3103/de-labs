#!/bin/bash
# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Delete all resources
kubectl delete -f "${SCRIPT_DIR}/manifests/03-minio.yaml"
kubectl delete -f "${SCRIPT_DIR}/manifests/02-storage.yaml"
kubectl delete -f "${SCRIPT_DIR}/manifests/01-namespace.yaml"

echo "Minio environment cleanup completed!"