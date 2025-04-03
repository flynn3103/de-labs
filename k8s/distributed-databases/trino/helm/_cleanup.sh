#!/bin/bash

# Script to cleanup Trino from k3s
set -e

echo "Removing Trino from k3s..."

# Uninstall Trino Helm release
if helm list -n trino | grep -q trino; then
  echo "Uninstalling Trino Helm release..."
  helm uninstall trino -n trino
fi

# Delete namespace if it exists
if kubectl get namespace trino &> /dev/null; then
  echo "Deleting Trino namespace..."
  kubectl delete namespace trino
fi

echo "Trino cleanup completed!"