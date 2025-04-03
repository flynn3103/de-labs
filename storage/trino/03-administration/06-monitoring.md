# Lab 6: Monitoring Trino

This lab guides you through setting up comprehensive monitoring for your Trino deployment.

## Prerequisites

- A running Trino cluster (from previous labs)
- Basic understanding of monitoring concepts
- Access to your Kubernetes cluster (if using k8s deployment)

## Part 1: Trino Metrics Overview

Trino exposes various metrics through JMX which can be collected for monitoring:

- **Query Metrics**: Success rate, execution time, CPU time
- **Memory Metrics**: Memory usage, GC statistics
- **Connector Metrics**: Data read/written, connection counts
- **JVM Metrics**: Heap usage, GC pauses, thread counts

## Part 2: Setting Up Prometheus and Grafana

### Step 1: Deploy Prometheus and Grafana using Helm

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus with values to scrape Trino
cat > prometheus-values.yaml << EOF
server:
  persistentVolume:
    size: 20Gi
  
alertmanager:
  enabled: true
  
prometheus-pushgateway:
  enabled: false

prometheus-node-exporter:
  enabled: true

extraScrapeConfigs: |
  - job_name: 'trino'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - trino
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: trino
      - source_labels: [__address__]
        action: replace
        regex: ([^:]+)(:\d+)?
        replacement: \$1:8080
        target_label: __address__
      - source_labels: [__meta_kubernetes_pod_label_component]
        action: replace
        target_label: component
EOF

# Install Prometheus
helm install prometheus prometheus-community/prometheus \
  -n monitoring \
  -f prometheus-values.yaml

# Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Grafana
cat > grafana-values.yaml << EOF
persistence:
  enabled: true
  size: 10Gi

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.monitoring.svc.cluster.local
      access: proxy
      isDefault: true

dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /var/lib/grafana/dashboards/default
EOF

helm install grafana grafana/grafana \
  -n monitoring \
  -f grafana-values.yaml
```

### Step 2: Configure JMX Exporter for Trino

To expose JMX metrics to Prometheus, we need to add the JMX exporter to Trino:

Update your `trino-values.yaml` file:

```yaml
server:
  # ... previous configuration ...
  
  jvmExtraOptions: "-javaagent:/opt/trino/jmx_exporter/jmx_prometheus_javaagent.jar=8081:/opt/trino/jmx_exporter/config.yaml"
  
  additionalVolumes:
    # ... previous volumes ...
    - name: jmx-exporter
      emptyDir: {}
  
  additionalVolumeMounts:
    # ... previous mounts ...
    - name: jmx-exporter
      mountPath: /opt/trino/jmx_exporter
  
  initContainers:
    - name: jmx-exporter-downloader
      image: curlimages/curl
      command:
        - sh
        - -c
        - |
          mkdir -p /tmp/jmx_exporter
          curl -L https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.16.1/jmx_prometheus_javaagent-0.16.1.jar -o /tmp/jmx_exporter/jmx_prometheus_javaagent.jar
          cat > /tmp/jmx_exporter/config.yaml << 'EOF'
          ---
          lowercaseOutputName: true
          lowercaseOutputLabelNames: true
          rules:
          - pattern: ".*"
          EOF
          cp -r /tmp/jmx_exporter/* /jmx-exporter/
      volumeMounts:
        - name: jmx-exporter
          mountPath: /jmx-exporter
```

Apply the changes:

```bash
helm upgrade trino trino/trino -n trino -f trino-values.yaml
```

### Step 3: Import Trino Dashboard into Grafana

Get the Grafana admin password:

```bash
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

Forward the Grafana port:

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
```

Access Grafana at http://localhost:3000 and import a Trino dashboard.

Here's a sample dashboard JSON that you can import:

```json
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "custom": {}
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.2.0",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "sum(rate(trino_queries_total[5m]))",
          "interval": "",
          "legendFormat": "Queries",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Query Rate",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "custom": {}
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 4,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.2.0",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "sum(jvm_memory_bytes_used{area=\"heap\"})",
          "interval": "",
          "legendFormat": "Used",
          "refId": "A"
        },
        {
          "expr": "sum(jvm_memory_bytes_max{area=\"heap\"})",
          "interval": "",
          "legendFormat": "Max",
          "refId": "B"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "JVM Heap Usage",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "bytes",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
  ],
  "schemaVersion": 26,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "Trino Monitoring",
  "uid": "trino-monitoring",
  "version": 1
}
```

## Part 3: Using Trino's Built-in UI for Monitoring

Trino's web UI provides real-time monitoring capabilities:

1. **Overview Page**: Shows active, queued, and completed queries
2. **Query Page**: Details about specific queries, including execution time and resources used
3. **Worker Page**: Information about worker nodes, including memory usage and CPU time

Access the UI by port-forwarding:

```bash
kubectl port-forward -n trino svc/trino 8080:8080
```

Navigate to http://localhost:8080 in your browser.

## Part 4: Setting Up Alerts

### Step 1: Configure Alertmanager for Prometheus

Create a file named `alertmanager-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
      slack_api_url: 'https://hooks.slack.com/services/YOUR_SLACK_WEBHOOK_URL'

    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 1h
      receiver: 'slack-notifications'
      routes:
      - match:
          severity: critical
        receiver: 'slack-notifications'

    receivers:
    - name: 'slack-notifications'
      slack_configs:
      - channel: '#trino-alerts'
        send_resolved: true
        title: |-
          [{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .CommonLabels.alertname }}
        text: >-
          {{ range .Alerts }}
            *Alert:* {{ .Annotations.summary }}
            *Description:* {{ .Annotations.description }}
            *Graph:* <{{ .GeneratorURL }}|🔗>
            *Details:*
            {{ range .Labels.SortedPairs }} • *{{ .Name }}:* `{{ .Value }}`
            {{ end }}
          {{ end }}
```

Apply the ConfigMap:

```bash
kubectl apply -f alertmanager-config.yaml
```

### Step 2: Create Prometheus Alert Rules

Create a file named `prometheus-rules.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-server-alerts
  namespace: monitoring
  labels:
    app: prometheus
    component: server
data:
  trino.rules: |
    groups:
    - name: trino.rules
      rules:
      - alert: TrinoHighQueryFailureRate
        expr: rate(trino_execution_query_failures[5m]) / rate(trino_execution_query_success[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High query failure rate"
          description: "Trino is experiencing a high query failure rate (> 10%)"
      
      - alert: TrinoHighMemoryUsage
        expr: sum(jvm_memory_bytes_used{area="heap"}) / sum(jvm_memory_bytes_max{area="heap"}) > 0.9
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High JVM memory usage"
          description: "Trino is using more than 90% of available heap memory"
      
      - alert: TrinoCoordinatorDown
        expr: absent(up{component="coordinator"})
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Trino coordinator is down"
          description: "The Trino coordinator has been down for more than 1 minute"
```

Apply the ConfigMap:

```bash
kubectl apply -f prometheus-rules.yaml
```

## Part 5: Logging and Debugging

### Step 1: Configure Trino Logging

Trino uses Log4j for logging. Update your `etc/log.properties` file:

```properties
# Global logging level
com.facebook.presto=INFO

# Enable debug logging for specific components
#com.facebook.presto.execution=DEBUG
#com.facebook.presto.sql=DEBUG
```

### Step 2: Integrate with the ELK Stack (optional)

For a complete logging solution, you can set up Elasticsearch, Logstash, and Kibana:

```bash
# Add Elastic Helm repository
helm repo add elastic https://helm.elastic.co
helm repo update

# Install Elasticsearch
helm install elasticsearch elastic/elasticsearch -n monitoring

# Install Kibana
helm install kibana elastic/kibana -n monitoring \
  --set service.type=ClusterIP

# Install Filebeat for log collection
helm install filebeat elastic/filebeat -n monitoring \
  --set filebeatConfig.filebeat.yml.filebeat.inputs='[{"type":"container","paths":["/var/log/containers/trino*.log"],"processors":[{"add_kubernetes_metadata":{"host":"${NODE_NAME}","matchers":[{"logs_path":{"logs_path":"/var/log/containers/trino*.log"}}]}}]}]'
```

Port-forward Kibana:

```bash
kubectl port-forward -n monitoring svc/kibana-kibana 5601:5601
```

## Part 6: Performance Tuning

### Key Metrics to Monitor for Performance

1. **Query Success Rate**: Track failed queries and their causes
2. **Query Execution Time**: Monitor long-running queries
3. **Memory Usage**: Track JVM heap usage and garbage collection
4. **CPU Usage**: Monitor CPU utilization across workers
5. **I/O Rates**: Monitor read/write throughput for connectors

### Best Practices for Performance Tuning

1. **Adjust JVM Settings**: Tune heap size based on workload
2. **Optimize Query Planning**: Use EXPLAIN to identify bottlenecks
3. **Scale Worker Nodes**: Add more workers for parallelism
4. **Connector Tuning**: Optimize connector-specific parameters
5. **Resource Groups**: Use resource groups to manage workloads

## Next Steps

In the next lab, you'll learn about performance optimization and best practices for Trino. 