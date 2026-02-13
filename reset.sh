#!/bin/bash

echo "Resetting k3s setup..."

# Remove the deployments
kubectl delete -f hello-k3s.yml
sleep 10  # Wait for removal

# Stop and remove all containers (if any)
docker stop $(docker ps -q) || true
docker rm $(docker ps -aq) || true

# Remove the local images
docker rmi local/task1 local/task2 local/task3 local/task4 || true

echo "Reset complete. Now restarting..."

# Build images
docker build -t local/task1 hello_tx/
docker build -t local/task2 hello_rx/
docker build -t local/task3 hello_tx2/
docker build -t local/task4 hello_rx2/

# Deploy the stack
kubectl apply -f hello-k3s.yml

echo "Restart complete."