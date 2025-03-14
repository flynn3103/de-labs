kubectl port-forward svc/minio -n de-labs 30900:9000 30901:9001

kubectl exec -n de-labs deploy/minio -c minio -- mc alias set local http://localhost:9000 minioadmin minioadmin

kubectl exec -n de-labs deploy/minio -c minio -- mc mb local/spark-data