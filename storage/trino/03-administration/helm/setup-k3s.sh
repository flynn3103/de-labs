#!/bin/bash
set -e

echo "=== Installing K3s ==="
curl -sfL https://get.k3s.io | sh -
# Wait for k3s to be ready
sleep 30
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

echo "=== Adding Helm repositories ==="
helm repo add trino https://trinodb.github.io/charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

echo "=== Creating namespace ==="
kubectl create namespace trino-admin

echo "=== Installing the Trino Administration Helm chart ==="
helm dependency update ./trino-admin
helm install trino-admin ./trino-admin -n trino-admin

echo "=== Waiting for deployments to be ready ==="
kubectl rollout status deployment/trino-admin-coordinator -n trino-admin
kubectl rollout status deployment/trino-admin-worker -n trino-admin
kubectl rollout status deployment/trino-admin-prometheus-server -n trino-admin
kubectl rollout status deployment/trino-admin-grafana -n trino-admin
kubectl rollout status deployment/trino-admin-jaeger-query -n trino-admin
kubectl rollout status deployment/trino-admin-opentelemetry-collector -n trino-admin

echo "=== Adding hosts entries ==="
INGRESS_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
echo "Adding the following entries to /etc/hosts:"
echo "$INGRESS_IP trino.local grafana.local jaeger.local"
echo "Run the following command as root to add these entries:"
echo "echo \"$INGRESS_IP trino.local grafana.local jaeger.local\" >> /etc/hosts"

echo "=== Setup Complete ==="
echo "Trino UI: http://trino.local"
echo "Grafana: http://grafana.local (username: admin, password: admin)"
echo "Jaeger: http://jaeger.local" 