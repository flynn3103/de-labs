# Makefile for Trino Lab 2: Installation
# Provides targets for both Docker and K3s setup

# Variables
DOCKER_COMPOSE = docker-compose
K3S_NAMESPACE = trino

.PHONY: help docker-setup docker-start docker-stop docker-clean k3s-setup k3s-deploy k3s-verify k3s-port-forward k3s-clean k3s-exec all clean

help:
	@echo "Trino Lab 2 Installation Makefile"
	@echo ""
	@echo "Docker Targets:"
	@echo "  docker-setup    - Create Trino configuration directories and files for Docker"
	@echo "  docker-start    - Start Trino using Docker Compose"
	@echo "  docker-stop     - Stop Trino containers"
	@echo "  docker-clean    - Stop and remove Trino containers, networks, and volumes"
	@echo ""
	@echo "K3s Targets:"
	@echo "  k3s-setup       - Create namespace and prepare for Trino deployment on K3s"
	@echo "  k3s-deploy      - Deploy Trino on K3s using Helm"
	@echo "  k3s-verify      - Verify Trino deployment on K3s"
	@echo "  k3s-port-forward - Forward port to access Trino UI"
	@echo "  k3s-exec        - Execute shell in the Trino coordinator pod"
	@echo "  k3s-clean       - Remove Trino deployment from K3s"
	@echo ""
	@echo "Other Targets:"
	@echo "  all             - Set up and start Trino using Docker (default)"
	@echo "  clean           - Clean up both Docker and K3s deployments"

# Docker targets
docker-setup:
	@echo "Creating directories for Trino configuration..."
	mkdir -p etc/catalog
	
	@echo "Creating node.properties..."
	echo "node.environment=development" > etc/node.properties
	echo "node.id=trino-dev-node" >> etc/node.properties
	
	@echo "Creating config.properties..."
	echo "coordinator=true" > etc/config.properties
	echo "node-scheduler.include-coordinator=true" >> etc/config.properties
	echo "http-server.http.port=8080" >> etc/config.properties
	echo "discovery.uri=http://localhost:8080" >> etc/config.properties
	
	@echo "Creating jvm.config..."
	echo "-server" > etc/jvm.config
	echo "-Xmx4G" >> etc/jvm.config
	echo "-XX:+UseG1GC" >> etc/jvm.config
	echo "-XX:G1HeapRegionSize=32M" >> etc/jvm.config
	echo "-XX:+ExplicitGCInvokesConcurrent" >> etc/jvm.config
	echo "-XX:+HeapDumpOnOutOfMemoryError" >> etc/jvm.config
	echo "-XX:+ExitOnOutOfMemoryError" >> etc/jvm.config
	
	@echo "Creating catalog files..."
	echo "connector.name=memory" > etc/catalog/memory.properties
	echo "connector.name=tpch" > etc/catalog/tpch.properties
	
	@echo "Trino configuration for Docker setup complete"

docker-start: docker-setup
	@echo "Starting Trino using Docker Compose..."
	$(DOCKER_COMPOSE) up -d
	@echo "Trino is starting at http://localhost:8080"

docker-stop:
	@echo "Stopping Trino containers..."
	$(DOCKER_COMPOSE) stop

docker-clean:
	@echo "Cleaning up Trino Docker deployment..."
	$(DOCKER_COMPOSE) down -v
	rm -rf etc

# K3s targets
k3s-setup:
	@echo "Setting up Trino namespace on K3s..."
	kubectl create namespace $(K3S_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	
	@echo "Creating Trino catalog ConfigMap..."
	cat > trino-catalogs-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: trino-catalogs
  namespace: $(K3S_NAMESPACE)
data:
  memory.properties: |
    connector.name=memory
    memory.max-data-per-node=1GB
  
  tpch.properties: |
    connector.name=tpch
    tpch.scaling-factor=1
EOF
	kubectl apply -f trino-catalogs-configmap.yaml
	
	@echo "Creating values.yaml for Helm..."
	cat > trino-values.yaml << EOF
server:
  workers: 2
  coordinatorExtraConfig:
    query.max-memory: 4GB
    query.max-memory-per-node: 1GB
    query.max-total-memory-per-node: 2GB
  
  workerExtraConfig:
    query.max-memory-per-node: 1GB
    query.max-total-memory-per-node: 2GB

  catalogConfigMap:
    configMapName: trino-catalogs

  additionalVolumes:
    - name: trino-catalog-volume
      configMap:
        name: trino-catalogs

  additionalVolumeMounts:
    - name: trino-catalog-volume
      mountPath: /etc/trino/catalog

resources:
  server:
    jvm:
      maxHeapSize: "4G"
    resources:
      requests:
        memory: "4Gi"
        cpu: "1"
      limits:
        memory: "4Gi"
        cpu: "2"

securityContext:
  server:
    runAsUser: 1000
    runAsGroup: 1000
EOF
	
	@echo "Adding Helm repository for Trino..."
	helm repo add trino https://trinodb.github.io/charts || true
	helm repo update

k3s-deploy: k3s-setup
	@echo "Deploying Trino on K3s using Helm..."
	helm install trino trino/trino -n $(K3S_NAMESPACE) -f trino-values.yaml

k3s-verify:
	@echo "Verifying Trino deployment on K3s..."
	kubectl get pods -n $(K3S_NAMESPACE)
	kubectl get svc -n $(K3S_NAMESPACE)

k3s-port-forward:
	@echo "Port forwarding Trino service to localhost:8080..."
	kubectl port-forward -n $(K3S_NAMESPACE) svc/trino 8080:8080

k3s-exec:
	@echo "Executing shell in Trino coordinator pod..."
	kubectl exec -it -n $(K3S_NAMESPACE) $$(kubectl get pods -n $(K3S_NAMESPACE) -l "app=trino,component=coordinator" -o jsonpath="{.items[0].metadata.name}") -- /bin/bash

k3s-clean:
	@echo "Cleaning up Trino K3s deployment..."
	helm uninstall trino -n $(K3S_NAMESPACE) || true
	kubectl delete configmap trino-catalogs -n $(K3S_NAMESPACE) || true
	rm -f trino-catalogs-configmap.yaml trino-values.yaml

# Default targets
all: docker-start

clean: docker-clean k3s-clean
	@echo "All Trino deployments cleaned up" 