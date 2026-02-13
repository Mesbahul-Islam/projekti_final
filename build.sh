#!/bin/bash

# Build Docker images
echo "Building images..."
docker build -t local/task1:1 hello_tx/
docker build -t local/task2:1 hello_rx/
docker build -t local/task3:1 hello_tx2/
docker build -t local/task4:1 hello_rx2/

echo "Build complete."