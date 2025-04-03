.PHONY: init clean-all check-cluster cluster-up cluster-down add-repo deploy undeploy deploy-all undeploy-all check-docker pull-charts setup test status

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
NAMESPACE := de-labs
VERSION := 25.3.0
svc ?= all

# Check if Docker is running
check-docker:
	@echo "Checking if Docker is running..."
	@if ! docker info > /dev/null 2>&1; then \
		echo "Error: Docker is not running. Please start Docker first!"; \
		exit 1; \
	else \
		echo "Docker is running ✓"; \
	fi

# Install basic operators
init: check-cluster
	@echo "Create namespace operators..."
	@kubectl create namespace $(NAMESPACE) 2>/dev/null || true

# Clean all resources
clean-all: check-cluster
	@echo "Cleaning all resources..."
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found

# Check if the k3d cluster exists and is running
check-cluster:
	@echo "Checking k3d cluster..."
	@if ! k3d cluster list 2>/dev/null | grep -q "de-labs"; then \
		echo "Error: de-labs cluster not found"; \
		echo "Please run 'make cluster-up' first to create the cluster"; \
		exit 1; \
	fi
	@echo "Checking kubectl connection..."
	@if ! kubectl get nodes > /dev/null 2>&1; then \
		echo "Error: Cannot connect to Kubernetes cluster"; \
		echo "Please ensure the cluster is running and properly configured"; \
		exit 1; \
	fi
	@echo "Kubernetes cluster is accessible ✓"

# Create a new k3d cluster if it doesn't exist
# Configures 1 server and 1 agent node
cluster-up: check-docker
	@echo "Creating k3d-de-labs cluster..."
	@if ! k3d cluster list 2>/dev/null | grep -q "de-labs"; then \
		k3d cluster create de-labs \
			--servers 1 \
			--agents 1 \
			--port "8080:80@loadbalancer" \
			--wait; \
	else \
		echo "k3d-de-labs cluster already exists"; \
	fi
	@echo "Waiting for cluster to be ready..."
	@sleep 5
	@echo "Validating kubectl context..."
	@kubectl config use-context k3d-de-labs
	@kubectl cluster-info
	@kubectl get nodes

# Delete the k3d cluster if it exists
cluster-down: check-docker
	@echo "Deleting k3d-de-labs cluster..."
	@if k3d cluster list 2>/dev/null | grep -q "de-labs"; then \
		k3d cluster delete de-labs; \
		echo "k3d-de-labs cluster deleted"; \
	else \
		echo "k3d-de-labs cluster not found"; \
	fi

# Setup full environment
setup: check-docker cluster-up init
	@echo "Setup complete! Charts are downloaded and you can now deploy services with 'make deploy'"

# Test deployment
test: check-cluster
	@echo "Testing deployment..."
	@kubectl get pods -n $(NAMESPACE)
	@echo "Checking operator status..."
	@for op in commons-operator secret-operator listener-operator zookeeper-operator kafka-operator spark-k8s-operator airflow-operator trino-operator superset-operator; do \
		echo "Checking $$op status:"; \
		kubectl get deployment $$op -n $(NAMESPACE) -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "Not deployed"; \
		echo ""; \
	done
