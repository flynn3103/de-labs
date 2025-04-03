# Trino Administration Lab with k3s

This lab demonstrates how to set up Trino with:
- Web UI with authentication
- Log collection and monitoring using Prometheus and Grafana
- Observability with OpenTelemetry and Jaeger

## Prerequisites

- A Linux server with at least 8GB RAM and 4 CPU cores
- sudo access
- Helm (v3+)
- kubectl

## Setup Instructions

### Option 1: Automated Setup

1. Navigate to the Helm directory:

```bash
cd helm
```

2. Make the setup script executable:

```bash
chmod +x setup-k3s.sh
```

3. Run the setup script:

```bash
./setup-k3s.sh
```

4. Add the required entries to your /etc/hosts file as prompted by the script.

### Option 2: Manual Setup

#### 1. Install k3s

```bash
curl -sfL https://get.k3s.io | sh -
```

Configure kubectl:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config
```

#### 2. Add Helm repositories

```bash
helm repo add trino https://trinodb.github.io/charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

#### 3. Create namespace

```bash
kubectl create namespace trino-admin
```

#### 4. Deploy Trino Administration Helm chart

```bash
cd helm
helm dependency update ./trino-admin
helm install trino-admin ./trino-admin -n trino-admin
```

#### 5. Update /etc/hosts

Get the node IP:

```bash
INGRESS_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
echo "$INGRESS_IP trino.local grafana.local jaeger.local"
```

Add the output to your /etc/hosts file:

```bash
sudo sh -c "echo '$INGRESS_IP trino.local grafana.local jaeger.local' >> /etc/hosts"
```

## Accessing the Components

### Trino Web UI

The Trino Web UI is accessible at: http://trino.local

Login credentials:
- Username: admin
- Password: admin

### Grafana (Metrics Visualization)

Grafana is accessible at: http://grafana.local

Login credentials:
- Username: admin
- Password: admin

A Trino dashboard is pre-configured and available under the "Trino" folder.

### Jaeger (Trace Visualization)

Jaeger UI is accessible at: http://jaeger.local

To view traces:
1. Select "trino" from the Service dropdown
2. Click "Find Traces"

## Running Test Queries

Connect to Trino using the CLI from the coordinator pod:

```bash
kubectl exec -it deploy/trino-admin-coordinator -n trino-admin -- trino --server localhost:8080 --user admin
```

Or run a sample query:

```bash
kubectl exec -it deploy/trino-admin-coordinator -n trino-admin -- trino --server localhost:8080 --user admin --execute "SELECT * FROM tpch.tiny.nation LIMIT 5"
```

## Monitoring Trino

### Metrics in Prometheus

Access Prometheus directly:

```bash
kubectl port-forward svc/trino-admin-prometheus-server -n trino-admin 9090:80
```

Then open http://localhost:9090 in your browser.

### Logs and Traces

View Trino logs:

```bash
kubectl logs deploy/trino-admin-coordinator -n trino-admin
```

## Architecture

This setup includes the following components:

1. **Trino** (Coordinator and Workers):
   - Web UI with form authentication
   - OpenTelemetry instrumentation for metrics and tracing

2. **Prometheus**:
   - Collects metrics from Trino and OpenTelemetry Collector
   - Used as a data source in Grafana

3. **Grafana**:
   - Provides dashboards for visualizing Trino metrics
   - Pre-configured with a Trino overview dashboard

4. **OpenTelemetry Collector**:
   - Receives traces from Trino
   - Forwards traces to Jaeger
   - Exposes metrics for Prometheus

5. **Jaeger**:
   - Stores and visualizes distributed traces
   - Allows debugging request flows across Trino components

## Shutting Down

To uninstall the Helm chart:

```bash
helm uninstall trino-admin -n trino-admin
```

To delete the namespace:

```bash
kubectl delete namespace trino-admin
```

To stop k3s:

```bash
sudo systemctl stop k3s
``` 