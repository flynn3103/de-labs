.PHONY: deploy undeploy install-operators show-credentials clean-all check-cluster create-cluster delete-k3d-cluster

export MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
export APP := de-labs
export NAMESPACE := argocd
export VERSION := 7.3.4
export TOOLS_PATH := tools/k8s
export ENVIRONMENT := local
export SCRIPT_PATH := tools/scripts

# Install basic operators
init:
	@echo "Create namespace operators..."
	@kubectl create namespace de-labs 2>/dev/null || true
	@echo "Install krew..."
	@if ! command -v kubectl-krew >/dev/null 2>&1; then \
		echo "Installing krew..."; \
		cd "$(mktemp -d)" && \
		OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
		ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
		KREW="krew-${OS}_${ARCH}" && \
		curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" && \
		tar zxvf "${KREW}.tar.gz" && \
		./"${KREW}" install krew; \
		echo 'export PATH="${KREW_ROOT:-$$HOME/.krew}/bin:$$PATH"' >> ~/.bashrc; \
		echo 'export PATH="${KREW_ROOT:-$$HOME/.krew}/bin:$$PATH"' >> ~/.zshrc; \
	fi
	@echo "Done installing krew. Please restart your shell or source your shell config file."; \

# Deploy services
deploy:
	@echo "Starting deployment..."
	@if [ -z "$(svc)" ]; then \
		echo "Please specify services: make deploy svc=minio,spark,kafka,airflow,trino,mongodb,mysql,postgres,elasticsearch,harbor,argocd"; \
		exit 1; \
	fi
	@for service in $$(echo $(svc) | tr ',' ' '); do \
		case $$service in \
			minio) \
				echo "Deploying MinIO..."; \
				kubectl krew install minio; \
				kubectl minio init --namespace de-labs; \
				kubectl minio tenant create minio-tenant-1 --servers 1 --volumes 3 --capacity 1Gi --namespace de-labs; \
				kubectl apply -f "$(MAKEFILE_DIR)/k8s/minio/console-service.yaml";; \
			airflow) \
				echo "Deploying Airflow..."; \
				helm repo add airflow-stable https://airflow-helm.github.io/charts; \
				helm repo update airflow-stable; \
				helm install airflow airflow-stable/airflow --namespace de-labs \
					--values k8s/cluster2/helm/airflow/values.yaml --version "8.8.0";; \
			trino) \
				echo "Deploying Trino..."; \
				helm repo add trino https://trinodb.github.io/charts; \
				helm repo update trino; \
				helm install trino trino/trino --namespace de-labs \
					--values "$(MAKEFILE_DIR)/k8s/trino/values.yaml" --version 0.18.0;; \
			spark) \
				echo "Deploying Spark..."; \
				helm repo add bitnami https://charts.bitnami.com/bitnami; \
				helm install spark-operator bitnami/spark --namespace de-labs --create-namespace; \
				kubectl apply -f $(MAKEFILE_DIR)/k8s/spark/spark-uui-service.yaml -n de-labs;; \
			kafka) \
				echo "Deploying Kafka..."; \
				helm repo add strimzi https://strimzi.io/charts/; \
				helm install kafka-operator strimzi/strimzi-kafka-operator --namespace de-labs; \
				kubectl apply -f $(MAKEFILE_DIR)/k8s/kafka/kafka-cluster.yaml -n de-labs;; \
			*) \
				echo "Invalid service: $$service. Available services: minio,spark,kafka,airflow,trino,mongodb,mysql,postgres,elasticsearch,harbor,argocd";; \
		esac \
	done

# Update undeploy to match new services
undeploy:
	@echo "Starting undeployment..."
	@if [ -z "$(svc)" ]; then \
		echo "Please specify services: make undeploy svc=minio,spark,kafka,airflow,trino,mongodb,mysql,postgres,elasticsearch,harbor,argocd"; \
		exit 1; \
	fi
	@for service in $$(echo $(svc) | tr ',' ' '); do \
		case $$service in \
			argocd) \
				echo "Undeploying ArgoCD..."; \
				kubectl delete -f k8s/argocd/app.yaml -n argocd --ignore-not-found; \
				helm uninstall argocd -n argocd; \
				kubectl delete namespace argocd --ignore-not-found;; \
			minio) \
				echo "Undeploying MinIO..."; \
				kubectl minio tenant delete minio-tenant-1 --namespace de-labs;; \
			harbor) \
				echo "Undeploying Harbor..."; \
				helm uninstall harbor -n de-labs;; \
			airflow) \
				echo "Undeploying Airflow..."; \
				helm uninstall airflow -n de-labs;; \
			trino) \
				echo "Undeploying Trino..."; \
				helm uninstall trino -n de-labs;; \
			mongodb) \
				echo "Undeploying MongoDB..."; \
				helm uninstall mongodb-operator -n de-labs;; \
			mysql) \
				echo "Undeploying MySQL..."; \
				helm uninstall mysql -n de-labs;; \
			postgres) \
				echo "Undeploying PostgreSQL..."; \
				helm uninstall postgres -n de-labs;; \
			elasticsearch) \
				echo "Undeploying Elasticsearch..."; \
				helm uninstall elasticsearch -n de-labs;; \
			spark) \
				echo "Undeploying Spark..."; \
				helm uninstall spark -n de-labs;; \
			kafka) \
				echo "Undeploying Kafka..."; \
				helm uninstall kafka-operator -n de-labs;; \
			*) \
				echo "Invalid service: $$service. Available services: minio,spark,kafka";; \
		esac \
	done

# Update show-credentials to include new services
show-credentials:
	@echo "Fetching credentials..."
	@if kubectl get secret minio-tenant-1-user-1 -n de-labs >/dev/null 2>&1; then \
		echo "\nMinIO Credentials:"; \
		kubectl -n de-labs get secret minio-tenant-1-user-1 -o jsonpath='{.data.CONSOLE_ACCESS_KEY}' | base64 -d; \
		echo "/"; \
		kubectl -n de-labs get secret minio-tenant-1-user-1 -o jsonpath='{.data.CONSOLE_SECRET_KEY}' | base64 -d; \
		echo ""; \
	fi
	@if kubectl get secret mysql -n de-labs >/dev/null 2>&1; then \
		echo "\nMySQL root password: "; \
		kubectl -n de-labs get secret mysql -o jsonpath="{.data.mysql-root-password}" | base64 -d; \
		echo ""; \
	fi
	@if kubectl get secret postgres-postgresql -n de-labs >/dev/null 2>&1; then \
		echo "\nPostgres admin password: "; \
		kubectl -n de-labs get secret postgres-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d; \
		echo ""; \
	fi

# Clean all resources
clean-all:
	@echo "Cleaning all resources..."
	@kubectl delete namespace de-labs --ignore-not-found


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
		k3d cluster create de-labs \
			--servers 1 \
			--agents 1 \
			-p "80:80@loadbalancer" \
  			-p "443:443@loadbalancer" \
			--k3s-arg "--disable=servicelb@server:*"; \
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

# Configure MetalLB for k3d cluster
configure-metallb:
	@echo "Installing and configuring MetalLB..."
	@kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
	@echo "Generating MetalLB configuration..."
	@bash $(MAKEFILE_DIR)/k8s/metallb/generate_metallb_config.sh
	@echo "Waiting for MetalLB CRDs to be established..."
	@kubectl wait --for condition=established --timeout=90s crd/ipaddresspools.metallb.io
	@kubectl wait --for condition=established --timeout=90s crd/l2advertisements.metallb.io
	@echo "Waiting for MetalLB pods to be ready..."
	@kubectl wait --namespace metallb-system \
		--for=condition=ready pod \
		--selector=app=metallb \
		--timeout=90s
	@echo "Applying MetalLB configuration..."
	@kubectl apply -f $(MAKEFILE_DIR)/k8s/metallb/config.yaml