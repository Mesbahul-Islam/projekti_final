#!/bin/bash

# Deploy the stack
echo "Deploying stack..."
docker stack deploy -c hello-stack.yml hello

echo "Deploy complete."