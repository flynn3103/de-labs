#!/bin/bash

# Get k3d network subnet
NETWORK_NAME="k3d-de-labs"
SUBNET=$(docker network inspect $NETWORK_NAME -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' | cut -d'/' -f1)

# Calculate the IP range (using .200 to .250 from the subnet)
BASE_IP=$(echo $SUBNET | cut -d'.' -f1-3)
START_IP="${BASE_IP}.200"
END_IP="${BASE_IP}.250"

# Generate MetalLB config
# Get the directory path dynamically
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cat > "${DIR}/config.yaml" << EOF
# Issue with k3s: https://metallb.universe.tf/configuration/k3s/
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  # Automatically generated IP range from k3d network
  addresses:
  - ${START_IP}-${END_IP}  # IP range within k3d network subnet
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
EOF