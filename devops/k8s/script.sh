kubectl config current-context

kubectl scale deployment --all --replicas=0 

kubectl delete service --all --all-namespaces

kubectl delete deployment,statefulset,daemonset --all --all-namespaces
kubectl delete pod --force --grace-period=0 --all-namespaces