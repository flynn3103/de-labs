#!/bin/bash

# Script to clean up all Trino cluster resources

echo "Starting cleanup of Trino cluster resources..."

# Delete the Helm release
echo "Deleting Helm release..."
helm uninstall trino-cluster -n trino

# Wait a moment for resources to begin cleaning up
sleep 5

# Check for any remaining pods
echo "Checking for remaining pods..."
kubectl get pods -n trino

# Delete any persistent volume claims that might remain
echo "Deleting any remaining PVCs..."
kubectl delete pvc --all -n trino

# Delete any persistent volumes that might remain
echo "Deleting any remaining PVs associated with the namespace..."
for pv in $(kubectl get pv | grep trino | awk '{print $1}'); do
  echo "Deleting PV $pv"
  kubectl delete pv $pv
done

# Optionally, delete the namespace if you want to start completely fresh
read -p "Do you want to delete the entire 'trino' namespace? (y/n): " answer
if [ "$answer" == "y" ]; then
  echo "Deleting namespace 'trino'..."
  kubectl delete namespace trino
  echo "Namespace deleted."
else
  echo "Namespace 'trino' preserved."
fi

echo "Cleanup completed!" 