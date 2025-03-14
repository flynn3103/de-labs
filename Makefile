# Define phony targets (targets that don't represent files)
.PHONY: deploy undeploy clean-all check-cluster create-cluster

# Get the directory of the Makefile for relative path resolution
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Initialize Kubernetes namespace for the project
init-namespace:
	@echo "Initializing..."
	@kubectl create namespace de-labs

# Deploy specified services (minio or spark)
# Usage: make deploy svc=minio,spark
deploy:
	@echo "Starting deployment..."
	@if [ -z "$(svc)" ]; then \
		echo "Please specify svc=[minio,spark] or single service svc=minio"; \
		exit 1; \
	fi
	@for service in $$(echo $(svc) | tr ',' ' '); do \
		if [ "$$service" = "minio" ] || [ "$$service" = "spark" ]; then \
			echo "Deploying $$service..."; \
			bash "$(MAKEFILE_DIR)$$service/deploy.sh"; \
		else \
			echo "Invalid service: $$service. Skipping..."; \
		fi \
	done

# Undeploy specified services (minio or spark)
# Usage: make undeploy svc=minio,spark
undeploy:
	@echo "Starting undeployment..."
	@if [ -z "$(svc)" ]; then \
		echo "Please specify svc=[minio,spark] or single service svc=minio"; \
		exit 1; \
	fi
	@for service in $$(echo $(svc) | tr ',' ' '); do \
		if [ "$$service" = "minio" ] || [ "$$service" = "spark" ]; then \
			echo "Undeploying $$service..."; \
			bash "$(MAKEFILE_DIR)$$service/undeploy.sh"; \
		else \
			echo "Invalid service: $$service. Skipping..."; \
		fi \
	done

# Remove all Kubernetes resources from the current namespace
clean-all:
	@echo "Deleting all resources..."
	@kubectl delete all --all

# Check if the k3d cluster exists
check-k3d-cluster:
	@echo "Checking k3d cluster..."
	@if k3d cluster list | grep -q "de-labs"; then \
		echo "de-labs cluster exists"; \
	else \
		echo "k3d-de-labs cluster not found"; \
		exit 1; \
	fi

# Create a new k3d cluster if it doesn't exist
# Configures 1 server and 2 agent nodes
create-k3d-cluster:
	@echo "Creating k3d-de-labs cluster..."
	@if ! k3d cluster list | grep -q "de-labs"; then \
		k3d cluster create de-labs --servers 1 --agents 2; \
	else \
		echo "k3d-de-labs cluster already exists"; \
	fi
	@echo "Validating kubectl context..."
	@if ! kubectl config current-context | grep -q "k3d-de-labs"; then \
		echo "Error: Wrong kubectl context. Please switch to de-labs cluster"; \
		echo "You can switch using: kubectl config use-context de-labs"; \
		exit 1; \
	else \
		echo "You are in k3d-de-labs context ✓✓✓"; \
	fi

# Delete the k3d cluster if it exists
delete-k3d-cluster:
	@echo "Deleting k3d-de-labs cluster..."
	@if k3d cluster list | grep -q "de-labs"; then \
		k3d cluster delete de-labs; \
	else \
		echo "k3d-de-labs cluster not found"; \
	fi