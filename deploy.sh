#!/bin/bash
set -euo pipefail

# Script to join a new server node as a peer in the K3s multi-server cluster
# Usage: ./deploy.sh <SERVER_IP> <NODE_TOKEN>

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <EXISTING_SERVER_IP> <NODE_TOKEN>"
    echo "Example: $0 192.168.1.100 K107...your-token..."
    exit 1
fi

EXISTING_SERVER_IP="$1"
NODE_TOKEN="$2"

echo "Joining K3s multi-server cluster as peer..."
echo "Existing server IP: $EXISTING_SERVER_IP"
echo "Node token: ${NODE_TOKEN:0:10}..."

# Set environment variables for K3s
export K3S_URL="https://${EXISTING_SERVER_IP}:6443"
export K3S_TOKEN="$NODE_TOKEN"

# Install K3s as server (peer)
curl -sfL https://get.k3s.io | K3S_URL="$K3S_URL" K3S_TOKEN="$K3S_TOKEN" sh -s - server

echo "Peer server joined successfully."
echo "Verify with: sudo k3s kubectl get nodes"