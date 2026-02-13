#!/bin/bash

# Build Docker images
echo "Building images..."
docker build -t local/task1 hello_tx/
docker build -t local/task2 hello_rx/
docker build -t local/task3 hello_tx2/
docker build -t local/task4 hello_rx2/

echo "Build complete."