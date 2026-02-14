#!/bin/bash
set -euo pipefail

# Script to join a new server node as a peer in the K3s multi-server cluster
# Set environment variables before running:
# export K3S_SERVER_IP=<EXISTING_SERVER_IP>
# export K3S_TOKEN=<NODE_TOKEN>
# Then run: ./join-server.sh

if [[ -z "${K3S_SERVER_IP:-}" ]]; then
    echo "Error: K3S_SERVER_IP environment variable not set."
    echo "Set it with: export K3S_SERVER_IP=<EXISTING_SERVER_IP>"
    exit 1
fi

if [[ -z "${K3S_TOKEN:-}" ]]; then
    echo "Error: K3S_TOKEN environment variable not set."
    echo "Set it with: export K3S_TOKEN=<NODE_TOKEN>"
    exit 1
fi

echo "Joining K3s multi-server cluster as peer..."
echo "Existing server IP: $K3S_SERVER_IP"
echo "Node token: ${K3S_TOKEN:0:10}..."

# Set environment variables for K3s
export K3S_URL="https://${K3S_SERVER_IP}:6443"

# Install K3s as server (peer)
curl -sfL https://get.k3s.io | K3S_URL="$K3S_URL" K3S_TOKEN="$K3S_TOKEN" sh -s - server

echo "Peer server joined successfully."
echo "Verify with: sudo k3s kubectl get nodes"