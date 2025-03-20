# Patch Traefik service to LoadBalancer
kubectl patch svc traefik -n kube-system -p '{"spec": {"type": "LoadBalancer"}}'

# Verify the setup
echo "Waiting for Traefik to get an external IP..."
sleep 5
kubectl get svc -n kube-system