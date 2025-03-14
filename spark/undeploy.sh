#!/bin/bash
set -e

# Uninstall Spark operator
echo "Uninstalling Spark operator..."
helm uninstall my-spark-operator --namespace de-labs 2>/dev/null || true

echo "Spark environment cleanup completed!"