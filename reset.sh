#!/bin/bash

echo "Resetting Docker setup..."

# Remove the stack
docker stack rm hello
sleep 10  # Wait for stack removal

# Stop and remove all containers
docker stop $(docker ps -q) || true
docker rm $(docker ps -aq) || true

# Remove the local images
docker rmi local/hello_tx:1 local/hello_rx:1 local/hello_tx2:1 local/hello_rx2:1 || true

echo "Reset complete. Now restarting..."

# Build images
docker build -t local/hello_tx:1 hello_tx/
docker build -t local/hello_rx:1 hello_rx/
docker build -t local/hello_tx2:1 hello_tx2/
docker build -t local/hello_rx2:1 hello_rx2/

# Deploy the stack
docker stack deploy -c hello-stack.yml hello

echo "Restart complete."