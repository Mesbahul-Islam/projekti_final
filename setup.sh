#!/bin/bash
set -euo pipefail

# Single script to setup K3s peer/server, build multi-arch images, and deploy tasks
# Run on each machine with env vars:
# - For server: IMAGE_REGISTRY=<registry> (e.g., docker.io/user)
# - For peer: K3S_SERVER_IP=<ip> K3S_TOKEN=<token> IMAGE_REGISTRY=<registry>

IMAGE_REGISTRY="${IMAGE_REGISTRY:-local}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Function to build images
build_images() {
    if [[ -z "${K3S_SERVER_IP:-}" ]]; then
        # Server: build multi-arch and push to registry
        echo "Building and pushing multi-arch images to registry..."
        docker buildx build --platform linux/amd64,linux/arm64 -t "${IMAGE_REGISTRY}/task1:${IMAGE_TAG}" --push hello_tx/
        docker buildx build --platform linux/amd64,linux/arm64 -t "${IMAGE_REGISTRY}/task2:${IMAGE_TAG}" --push hello_rx/
        docker buildx build --platform linux/amd64,linux/arm64 -t "${IMAGE_REGISTRY}/task3:${IMAGE_TAG}" --push hello_tx2/
        docker buildx build --platform linux/amd64,linux/arm64 -t "${IMAGE_REGISTRY}/task4:${IMAGE_TAG}" --push hello_rx2/
        echo "Push complete."
        # Pull locally for import
        echo "Pulling images locally..."
        docker pull "${IMAGE_REGISTRY}/task1:${IMAGE_TAG}"
        docker pull "${IMAGE_REGISTRY}/task2:${IMAGE_TAG}"
        docker pull "${IMAGE_REGISTRY}/task3:${IMAGE_TAG}"
        docker pull "${IMAGE_REGISTRY}/task4:${IMAGE_TAG}"
        echo "Pull complete."
    else
        # Peer: pull from registry
        echo "Pulling images from registry..."
        docker pull "${IMAGE_REGISTRY}/task1:${IMAGE_TAG}"
        docker pull "${IMAGE_REGISTRY}/task2:${IMAGE_TAG}"
        docker pull "${IMAGE_REGISTRY}/task3:${IMAGE_TAG}"
        docker pull "${IMAGE_REGISTRY}/task4:${IMAGE_TAG}"
        echo "Pull complete."
    fi
}

# Function to import images to K3s
import_images() {
    echo "Importing images to K3s..."
    for i in 1 2 3 4; do
        docker save "${IMAGE_REGISTRY}/task${i}:${IMAGE_TAG}" | sudo k3s ctr images import -
    done
    echo "Import complete."
}

# Function to deploy tasks
deploy_tasks() {
    echo "Waiting for K3s API server to be ready..."
    while ! sudo k3s kubectl cluster-info >/dev/null 2>&1; do
        echo "Waiting..."
        sleep 5
    done
    echo "API server ready."

    echo "Deploying tasks..."
    sudo k3s kubectl apply -f hello-k3s.yml
    sudo k3s kubectl set image deployment/hello-task1 task1="${IMAGE_REGISTRY}/task1:${IMAGE_TAG}"
    sudo k3s kubectl set image deployment/hello-task2 task2="${IMAGE_REGISTRY}/task2:${IMAGE_TAG}"
    sudo k3s kubectl set image deployment/hello-task3 task3="${IMAGE_REGISTRY}/task3:${IMAGE_TAG}"
    sudo k3s kubectl set image deployment/hello-task4 task4="${IMAGE_REGISTRY}/task4:${IMAGE_TAG}"
    echo "Deploy complete."
}

# Main logic
if [[ -z "${K3S_SERVER_IP:-}" ]]; then
    # Start as server
    echo "Starting K3s server..."
    curl -sfL https://get.k3s.io | sh -
    echo "Server started. Token: $(sudo cat /var/lib/rancher/k3s/server/node-token)"
    build_images
else
    # Join as peer
    echo "Joining as peer to $K3S_SERVER_IP..."
    export K3S_URL="https://${K3S_SERVER_IP}:6443"
    curl -sfL https://get.k3s.io | K3S_URL="$K3S_URL" K3S_TOKEN="$K3S_TOKEN" sh -s - server
    echo "Joined as peer."
    build_images
fi

import_images
deploy_tasks

echo "Setup complete. Check with: sudo k3s kubectl get pods -o wide"