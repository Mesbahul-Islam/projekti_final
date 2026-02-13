#!/bin/bash

# Build Docker images
echo "Building images..."
docker build -t local/hello_tx:1 hello_tx/
docker build -t local/hello_rx:1 hello_rx/
docker build -t local/hello_tx2:1 hello_tx2/
docker build -t local/hello_rx2:1 hello_rx2/

echo "Build complete."