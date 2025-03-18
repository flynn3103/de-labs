Find the Correct Kubernetes API Server Address

Since the kubernetes service isn’t showing up in kube-system, let’s check the default namespace:

```bash
kubectl get svc -n default
Look for a service named kubernetes. It should look like:
```

```bash
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.43.0.1    <none>        443/TCP   87m
```
If it exists, the internal API server address is https://kubernetes.default.svc.cluster.local:443.

Test
```bash
kubectl run -it --rm test --image=curlimages/curl --restart=Never -- curl -k https://kubernetes.default.svc.cluster.local:443
```


2. Service DNS Resolution
Kubernetes uses an internal DNS system (powered by CoreDNS, visible as kube-dns in your kube-system namespace) to resolve service names to their ClusterIP. The fully qualified domain name (FQDN) for a service follows this pattern:

```bash
<service-name>.<namespace>.svc.<cluster-domain>
```

- `<service-name>`: kubernetes (the name of the service).
- `<namespace>`: default (the namespace where the kubernetes service resides).
- `<cluster-domain>`: cluster.local (the default cluster domain in most Kubernetes setups, including k3d).